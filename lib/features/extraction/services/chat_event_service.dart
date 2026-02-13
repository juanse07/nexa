import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../../../core/config/app_config.dart';
import '../../auth/data/services/auth_service.dart';
import '../../teams/data/services/teams_service.dart';
import 'clients_service.dart';
import 'event_service.dart';
import 'roles_service.dart';
import 'tariffs_service.dart';

/// AI Provider enum
enum AIProvider { openai, claude, groq }

/// Message in a chat conversation
class ChatMessage {
  final String role; // 'user' or 'assistant'
  final String content;
  final DateTime timestamp;
  final AIProvider? provider;
  final String? reasoning;

  ChatMessage({
    required this.role,
    required this.content,
    DateTime? timestamp,
    this.provider,
    this.reasoning,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'role': role,
        'content': content,
      };

  Map<String, dynamic> toStorageJson() => {
        'role': role,
        'content': content,
        'timestamp': timestamp.toIso8601String(),
        if (reasoning != null) 'reasoning': reasoning,
      };

  factory ChatMessage.fromStorageJson(Map<String, dynamic> json) {
    return ChatMessage(
      role: json['role'] as String,
      content: json['content'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      reasoning: json['reasoning'] as String?,
    );
  }
}

/// Service for handling AI chat-powered shift creation
class ChatEventService {
  static String? _cachedInstructions;
  final ClientsService _clientsService = ClientsService();
  final EventService _eventService = EventService();
  final RolesService _rolesService = RolesService();
  final TariffsService _tariffsService = TariffsService();
  final TeamsService _teamsService = TeamsService();

  List<String> _existingClientNames = [];
  List<Map<String, dynamic>> _existingEvents = [];
  List<Map<String, dynamic>> _existingTeamMembers = [];
  List<Map<String, dynamic>> _membersAvailability = [];
  String? _preferredCity;
  List<Map<String, dynamic>> _venueList = [];

  // Cache timestamps for smart reloading
  DateTime? _clientsCacheTime;
  DateTime? _eventsCacheTime;
  DateTime? _teamMembersCacheTime;
  DateTime? _availabilityCacheTime;
  DateTime? _venuesCacheTime;
  static const Duration _cacheValidDuration = Duration(minutes: 5);

  /// Helper to check if cache timestamp is valid
  bool _isCacheValid(DateTime? cacheTime) {
    if (cacheTime == null) return false;
    return DateTime.now().difference(cacheTime) < _cacheValidDuration;
  }

  // Track created entities during chat
  final Map<String, dynamic> _createdEntities = {
    'clients': <Map<String, dynamic>>[],
    'roles': <Map<String, dynamic>>[],
    'tariffs': <Map<String, dynamic>>[],
  };

  // Track event update requests
  final List<Map<String, dynamic>> _pendingUpdates = [];

  Map<String, dynamic> get createdEntities => Map.unmodifiable(_createdEntities);
  List<Map<String, dynamic>> get pendingUpdates => List.unmodifiable(_pendingUpdates);
  List<Map<String, dynamic>> get existingEvents => List.unmodifiable(_existingEvents);

  static const String _fallbackPrompt = '''You are a friendly AI assistant helping create catering work assignment records. Your job is to collect details through conversation.

IMPORTANT: Use the terminology preference specified by the user (Jobs, Shifts, or Events). If no preference is specified, use "shifts" as default.

Ask for information ONE field at a time in a natural, conversational way. Required fields:
- client_name
- date (ISO 8601 format)
- start_time (HH:MM format - when staff arrives)
- at least ONE role (with count)

Optional fields (include if mentioned, don't ask):
- event_name (will be auto-generated if not provided)
- end_time (HH:MM format)

Optional fields:
- venue_name
- venue_address
- city
- state
- country
- contact_name
- contact_phone
- contact_email
- setup_time
- uniform
- notes
- headcount_total
- roles (list of {role, count, call_time})
- pay_rate_info

After collecting each piece of information:
1. Acknowledge what the user said
2. Ask for the next missing required field
3. When all required fields are collected, confirm the details and ask if they want to add optional information

When the user indicates they're done, respond with "EVENT_COMPLETE" followed by a JSON object with all collected data.

Be conversational and friendly. If the user provides multiple pieces of information at once, extract them all.''';

  final List<ChatMessage> _conversationHistory = [];
  final Map<String, dynamic> _currentEventData = {};
  bool _eventComplete = false;

  // Conversation tracking for summaries
  DateTime? _conversationStartTime;
  final List<String> _toolsUsedInConversation = [];
  int _toolCallCount = 0;
  String _inputSource = 'text'; // 'text', 'voice', 'image', 'pdf'
  String _aiModel = 'openai/gpt-oss-20b';
  String _aiProvider = 'groq';

  List<ChatMessage> get conversationHistory =>
      List.unmodifiable(_conversationHistory);
  Map<String, dynamic> get currentEventData =>
      Map.unmodifiable(_currentEventData);
  bool get eventComplete => _eventComplete;
  DateTime? get conversationStartTime => _conversationStartTime;
  List<String> get toolsUsed => List.unmodifiable(_toolsUsedInConversation);
  int get toolCallCount => _toolCallCount;
  String get inputSource => _inputSource;
  String get aiModel => _aiModel;

  /// Set the input source for conversation tracking
  void setInputSource(String source) {
    if (['text', 'voice', 'image', 'pdf'].contains(source)) {
      _inputSource = source;
      print('[ChatEventService] Input source set to: $_inputSource');
    }
  }

  /// Record a tool call for analytics tracking
  void recordToolCall(String toolName) {
    _toolCallCount++;
    if (!_toolsUsedInConversation.contains(toolName)) {
      _toolsUsedInConversation.add(toolName);
    }
    print('[ChatEventService] Tool call recorded: $toolName (total: $_toolCallCount)');
  }

  /// Export conversation data for saving to database
  Map<String, dynamic> exportConversationSummary({
    required String outcome,
    String? eventId,
    bool wasEdited = false,
    List<String>? editedFields,
    String? outcomeReason,
  }) {
    final now = DateTime.now();
    final durationMs = _conversationStartTime != null
        ? now.difference(_conversationStartTime!).inMilliseconds
        : 0;

    return {
      'messages': _conversationHistory.map((msg) => {
        'role': msg.role,
        'content': msg.content,
        'timestamp': msg.timestamp.toIso8601String(),
      }).toList(),
      'extractedEventData': Map<String, dynamic>.from(_currentEventData),
      'eventId': eventId,
      'outcome': outcome,
      'outcomeReason': outcomeReason,
      'durationMs': durationMs,
      'toolCallCount': _toolCallCount,
      'toolsUsed': _toolsUsedInConversation.toSet().toList(),
      'inputSource': _inputSource,
      'wasEdited': wasEdited,
      'editedFields': editedFields ?? [],
      'aiModel': _aiModel,
      'aiProvider': _aiProvider,
      'conversationStartedAt': _conversationStartTime?.toIso8601String() ?? now.toIso8601String(),
      'conversationEndedAt': now.toIso8601String(),
    };
  }

  /// Clear current event data and reset completion flag
  void clearCurrentEventData() {
    _currentEventData.clear();
    _eventComplete = false;
  }

  /// Load AI instructions from markdown file
  Future<String> _loadInstructions() async {
    if (_cachedInstructions != null) return _cachedInstructions!;

    try {
      _cachedInstructions = await rootBundle.loadString(
        'assets/extraction_chat_instructions.md',
      );
      return _cachedInstructions!;
    } catch (e) {
      print('Failed to load chat instructions: $e');
      return _fallbackPrompt;
    }
  }

  /// Load existing clients from the database with caching
  Future<void> _loadExistingClients({bool forceRefresh = false}) async {
    // OPTIMIZATION: Early return if cache is valid
    if (!forceRefresh && _isCacheValid(_clientsCacheTime) && _existingClientNames.isNotEmpty) {
      print('[ChatEventService] Using cached clients (${_existingClientNames.length} items)');
      return;
    }

    try {
      print('[ChatEventService] Fetching fresh clients from database...');
      final startTime = DateTime.now();

      // Add timeout to prevent blocking
      final clients = await _clientsService.fetchClients().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          print('[ChatEventService] Client loading timed out - using empty list');
          return [];
        },
      );

      _existingClientNames = clients
          .map((c) => (c['name'] as String?) ?? '')
          .where((name) => name.isNotEmpty)
          .toList();
      _clientsCacheTime = DateTime.now();

      final loadDuration = DateTime.now().difference(startTime).inMilliseconds;
      print('[ChatEventService] Loaded ${_existingClientNames.length} clients in ${loadDuration}ms');
    } catch (e) {
      print('[ChatEventService] Failed to load clients: $e - using empty list');
      _existingClientNames = [];
      // Still mark cache time to prevent repeated failures
      _clientsCacheTime = DateTime.now();
    }
  }

  /// Load existing events from the database with caching and optional filtering
  Future<void> _loadExistingEvents({
    bool forceRefresh = false,
    String? filterByClient,
    String? filterByMonth,
  }) async {
    // OPTIMIZATION: Early return if cache is valid and no filters applied
    final hasFilters = filterByClient != null || filterByMonth != null;
    if (!forceRefresh && !hasFilters && _isCacheValid(_eventsCacheTime) && _existingEvents.isNotEmpty) {
      print('[ChatEventService] Using cached events (${_existingEvents.length} items)');
      return;
    }

    try {
      print('[ChatEventService] Fetching fresh events from database...');
      final startTime = DateTime.now();

      final allEvents = await _eventService.fetchEvents().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          print('[ChatEventService] Event loading timed out - using empty list');
          return [];
        },
      );

      // Apply filters if specified
      List<Map<String, dynamic>> filteredEvents = allEvents;

      if (filterByClient != null) {
        filteredEvents = filteredEvents.where((event) {
          final clientName = (event['client_name'] as String?)?.toLowerCase() ?? '';
          return clientName.contains(filterByClient.toLowerCase());
        }).toList();
        print('[ChatEventService] Filtered to ${filteredEvents.length} events for client: $filterByClient');
      }

      if (filterByMonth != null) {
        filteredEvents = filteredEvents.where((event) {
          final dateStr = event['date'] as String?;
          if (dateStr == null) return false;
          return dateStr.contains(filterByMonth);
        }).toList();
        print('[ChatEventService] Filtered to ${filteredEvents.length} events for month: $filterByMonth');
      }

      _existingEvents = hasFilters ? filteredEvents : allEvents;

      // Only cache if no filters applied
      if (!hasFilters) {
        _eventsCacheTime = DateTime.now();
      }

      final loadDuration = DateTime.now().difference(startTime).inMilliseconds;
      print('[ChatEventService] Loaded ${_existingEvents.length} events in ${loadDuration}ms');
    } catch (e) {
      print('[ChatEventService] Failed to load events: $e');
      _existingEvents = [];
    }
  }

  /// Load existing team members from the database with caching
  Future<void> _loadExistingTeamMembers({bool forceRefresh = false}) async {
    // OPTIMIZATION: Early return if cache is valid
    if (!forceRefresh && _isCacheValid(_teamMembersCacheTime) && _existingTeamMembers.isNotEmpty) {
      print('[ChatEventService] Using cached team members (${_existingTeamMembers.length} members)');
      return;
    }

    try {
      print('[ChatEventService] Fetching fresh team members from database...');
      final startTime = DateTime.now();
      final teams = await _teamsService.fetchTeams();

      final List<Map<String, dynamic>> allMembers = [];

      // OPTIMIZATION: Parallelize fetching members from all teams
      // This reduces N+1 query pattern from sequential to concurrent
      final memberFutures = teams.map((team) async {
        final teamId = team['id'] as String?;
        final teamName = team['name'] as String? ?? 'Unknown Team';

        if (teamId == null) return <Map<String, dynamic>>[];

        try {
          final members = await _teamsService.fetchMembers(teamId);

          // Add team name to each member
          return members.map((member) => {
            ...member,
            'teamName': teamName,
          }).toList();
        } catch (e) {
          print('[ChatEventService] Failed to load members for team $teamName: $e');
          return <Map<String, dynamic>>[];
        }
      }).toList();

      // Wait for all member fetches to complete in parallel
      final membersLists = await Future.wait(memberFutures);

      // Flatten the results
      for (final membersList in membersLists) {
        allMembers.addAll(membersList);
      }

      _existingTeamMembers = allMembers;
      _teamMembersCacheTime = DateTime.now();

      final loadDuration = DateTime.now().difference(startTime).inMilliseconds;
      print('[ChatEventService] Loaded ${_existingTeamMembers.length} team members from ${teams.length} teams in ${loadDuration}ms');
    } catch (e) {
      print('[ChatEventService] Failed to load team members: $e');
      _existingTeamMembers = [];
    }
  }

  /// Load team members availability from the database with caching
  Future<void> _loadMembersAvailability({bool forceRefresh = false}) async {
    // OPTIMIZATION: Early return if cache is valid
    if (!forceRefresh && _isCacheValid(_availabilityCacheTime) && _membersAvailability.isNotEmpty) {
      print('[ChatEventService] Using cached availability (${_membersAvailability.length} records)');
      return;
    }

    try {
      print('[ChatEventService] Fetching fresh availability from database...');
      final startTime = DateTime.now();

      final availability = await _teamsService.fetchMembersAvailability().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          print('[ChatEventService] Availability loading timed out - using empty list');
          return [];
        },
      );

      _membersAvailability = availability;
      _availabilityCacheTime = DateTime.now();

      final loadDuration = DateTime.now().difference(startTime).inMilliseconds;
      print('[ChatEventService] Loaded ${_membersAvailability.length} availability records in ${loadDuration}ms');
    } catch (e) {
      print('[ChatEventService] Failed to load availability: $e');
      _membersAvailability = [];
    }
  }

  /// Load manager's personalized venue list with caching
  Future<void> _loadManagerVenues({bool forceRefresh = false}) async {
    // OPTIMIZATION: Early return if cache is valid
    if (!forceRefresh && _isCacheValid(_venuesCacheTime) && _venueList.isNotEmpty) {
      print('[ChatEventService] Using cached venues (${_venueList.length} venues in $_preferredCity)');
      return;
    }

    try {
      print('[ChatEventService] Fetching manager venue list from backend...');
      final startTime = DateTime.now();
      final token = await AuthService.getJwt();
      if (token == null) {
        print('[ChatEventService] Not authenticated');
        return;
      }

      final response = await http.get(
        Uri.parse('${AppConfig.instance.baseUrl}/managers/me'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          print('[ChatEventService] Venue loading timed out');
          return http.Response('{"venueList": []}', 408);
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _preferredCity = data['preferredCity'] as String?;
        final venueList = data['venueList'] as List?;
        _venueList = venueList?.cast<Map<String, dynamic>>() ?? [];
        _venuesCacheTime = DateTime.now();

        final loadDuration = DateTime.now().difference(startTime).inMilliseconds;
        print('[ChatEventService] Loaded ${_venueList.length} venues for ${_preferredCity ?? "unknown city"} in ${loadDuration}ms');
      } else {
        print('[ChatEventService] Failed to load venues: ${response.statusCode}');
        _venueList = [];
        _preferredCity = null;
      }
    } catch (e) {
      print('[ChatEventService] Failed to load venues: $e');
      _venueList = [];
      _preferredCity = null;
    }
  }

  /// Invalidate cache when data changes
  void _invalidateCache() {
    _clientsCacheTime = null;
    _eventsCacheTime = null;
    _teamMembersCacheTime = null;
    _availabilityCacheTime = null;
    _venuesCacheTime = null;
    print('Cache invalidated');
  }

  /// Smart context detection from user message
  Map<String, String?> _detectContextNeeds(String userMessage) {
    final lowerMsg = userMessage.toLowerCase();
    String? clientFilter;
    String? monthFilter;

    // Detect specific client mentions
    for (final clientName in _existingClientNames) {
      if (lowerMsg.contains(clientName.toLowerCase())) {
        clientFilter = clientName;
        break;
      }
    }

    // Detect month mentions
    final months = [
      'january', 'february', 'march', 'april', 'may', 'june',
      'july', 'august', 'september', 'october', 'november', 'december',
      'jan', 'feb', 'mar', 'apr', 'may', 'jun',
      'jul', 'aug', 'sep', 'oct', 'nov', 'dec'
    ];

    for (int i = 0; i < months.length; i++) {
      if (lowerMsg.contains(months[i])) {
        final monthNum = ((i % 12) + 1).toString().padLeft(2, '0');
        monthFilter = '-$monthNum-';
        break;
      }
    }

    return {
      'client': clientFilter,
      'month': monthFilter,
    };
  }

  /// Format events for AI context (concise summary)
  String _formatEventsForContext() {
    if (_existingEvents.isEmpty) {
      return 'No existing events in the system.';
    }

    final buffer = StringBuffer();
    buffer.writeln('DATABASE SNAPSHOT - ${_existingEvents.length} events:');
    buffer.writeln('(You have DIRECT ACCESS to this data - treat it as your database)');
    buffer.writeln('(When users ask about addresses, events, or locations, the information is RIGHT HERE below)');
    buffer.writeln('');

    for (final event in _existingEvents) {
      final id = event['_id'] ?? event['id'] ?? 'unknown';
      final name = event['event_name'] ?? event['name'] ?? 'Unnamed Event';
      final client = event['client_name'] ?? 'No Client';
      final date = event['date'] ?? 'No Date';

      print('[ChatEventService._formatEventsForContext] Event: id=$id, _id=${event['_id']}, id_field=${event['id']}, name=$name');

      // ENHANCED: Extract full address details explicitly
      final venueName = (event['venue_name'] as String?) ?? '';
      final venueAddress = (event['venue_address'] as String?) ?? '';
      final city = (event['city'] as String?) ?? '';
      final state = (event['state'] as String?) ?? '';
      final country = (event['country'] as String?) ?? '';

      // Build full address string
      final addressParts = <String>[];
      if (venueAddress.isNotEmpty) addressParts.add(venueAddress);
      if (city.isNotEmpty) addressParts.add(city);
      if (state.isNotEmpty) addressParts.add(state);
      if (country.isNotEmpty) addressParts.add(country);
      final fullAddress = addressParts.join(', ');

      // Extract roles summary
      final roles = event['roles'];
      String rolesText = 'No roles';
      if (roles is List && roles.isNotEmpty) {
        rolesText = roles.map((r) {
          final roleName = r['role'] ?? r['name'] ?? 'Unknown';
          final count = r['count'] ?? r['headcount'] ?? 0;
          return '$roleName($count)';
        }).join(', ');
      }

      buffer.writeln('Event ID: $id');
      buffer.writeln('  Name: "$name"');
      buffer.writeln('  Client: $client');
      buffer.writeln('  Date: $date');
      if (venueName.isNotEmpty) {
        buffer.writeln('  Venue: $venueName');
      }
      if (fullAddress.isNotEmpty) {
        buffer.writeln('  Address: $fullAddress'); // EXPLICIT address field
      }
      buffer.writeln('  Roles: $rolesText');
      buffer.writeln(''); // Blank line between events for readability
    }

    final contextText = buffer.toString();
    print('[ChatEventService._formatEventsForContext] Context:\n$contextText');
    return contextText;
  }

  /// Format team members list for AI context with availability
  String _formatTeamMembersForContext() {
    if (_existingTeamMembers.isEmpty) {
      return 'No team members in the system.';
    }

    final buffer = StringBuffer();
    buffer.writeln('Your team members (${_existingTeamMembers.length} total):');

    // Group members by team for better organization
    final Map<String, List<Map<String, dynamic>>> membersByTeam = {};

    for (final member in _existingTeamMembers) {
      final teamName = member['teamName'] as String? ?? 'Unknown Team';
      membersByTeam.putIfAbsent(teamName, () => []);
      membersByTeam[teamName]!.add(member);
    }

    // Format by team
    for (final teamEntry in membersByTeam.entries) {
      final teamName = teamEntry.key;
      final members = teamEntry.value;

      buffer.writeln('\n$teamName (${members.length} members):');

      for (final member in members) {
        final name = member['name'] as String? ?? 'Unknown';
        final email = member['email'] as String? ?? '';
        final status = member['status'] as String? ?? 'unknown';
        final provider = member['provider'] as String? ?? '';
        final subject = member['subject'] as String? ?? '';

        final emailPart = email.isNotEmpty ? ' ($email)' : '';
        final statusIcon = status == 'active' ? '✓' : status == 'pending' ? '⏳' : '○';

        // Get availability for this member
        final userKey = '$provider:$subject';
        final memberAvailability = _membersAvailability
            .where((avail) => avail['userKey'] == userKey)
            .toList();

        buffer.write('  $statusIcon $name$emailPart');

        if (memberAvailability.isNotEmpty) {
          // Show next available/unavailable slots (limit to next 3)
          final upcoming = memberAvailability.take(3).toList();
          final availSummary = upcoming.map((avail) {
            final date = avail['date'] as String? ?? '';
            final startTime = avail['startTime'] as String? ?? '';
            final endTime = avail['endTime'] as String? ?? '';
            final availStatus = avail['status'] as String? ?? 'available';

            final icon = availStatus == 'available' ? '✓' : '✗';
            return '$icon $date $startTime-$endTime';
          }).join(', ');

          buffer.write(' | Availability: $availSummary');
        } else {
          buffer.write(' | Availability: Not set');
        }

        buffer.writeln();
      }
    }

    return buffer.toString();
  }

  /// Format personalized venues for AI context
  String _formatVenuesForContext() {
    if (_venueList.isEmpty) {
      return '## Popular Venues\nNo personalized venue list available. Manager can set up venues in settings.';
    }

    final buffer = StringBuffer();
    buffer.writeln('## Popular Venues in $_preferredCity (${_venueList.length} total)');
    buffer.writeln('Use these venues to auto-complete addresses when users mention them:\n');

    for (final venue in _venueList) {
      final name = venue['name'] as String? ?? 'Unknown';
      final address = venue['address'] as String? ?? 'Unknown';
      final city = venue['city'] as String? ?? '';

      buffer.writeln('- **$name** - $address${city.isNotEmpty ? ", $city" : ""}');
    }

    return buffer.toString();
  }

  /// Build system prompt (lightweight, no auto-context injection)
  Future<String> _buildSystemPrompt({
    String? terminology,
  }) async {
    final instructions = await _loadInstructions();

    // Build terminology instructions
    final terminologyInstructions = terminology != null ? '''

## 🔑 CRITICAL: User's Terminology Preference

The user has chosen to use "${terminology}" terminology (not "Jobs", "Shifts", or "Events").

**YOU MUST:**
- Always use "${terminology.toLowerCase()}" when referring to work assignments
- Use the singular form "${_getSingularForm(terminology)}" for single items
- Replace any mention of "shift", "job", or "event" with "${terminology.toLowerCase()}" in your responses
- Use this terminology in all JSON responses, confirmations, and messages

**Examples:**
- ❌ "Let's create a shift for..."
- ✅ "Let's create a ${terminology.toLowerCase().substring(0, terminology.length - 1)} for..."
- ❌ "Your shift on Nov 24..."
- ✅ "Your ${terminology.toLowerCase().substring(0, terminology.length - 1)} on Nov 24..."

**IMPORTANT**: The markdown instructions below may say "shift" - IGNORE that and use "${terminology.toLowerCase()}" instead!
''' : '';

    // Build current event context if we're editing
    final currentEventContext = _currentEventData.isNotEmpty ? '''

## 🔄 EDITING MODE - Current Event Data

You are currently helping the user EDIT an existing event. Here is the COMPLETE current data:

```json
${jsonEncode(_currentEventData)}
```

**CRITICAL EDITING RULES:**
1. When the user requests changes, MERGE their changes with the existing data above
2. Your EVENT_COMPLETE response MUST include ALL fields - both unchanged AND changed
3. DO NOT lose any existing data - only update the fields the user mentions
4. If user says "change the date to Jan 15", keep ALL other fields and only update the date

**Example:** If user says "change the start time to 2pm":
- Keep: client_name, date, venue_name, roles, etc. (everything above)
- Change: start_time to "14:00"
- Return: Complete JSON with ALL fields, not just start_time
''' : '';

    return '''$terminologyInstructions

$instructions
${_preferredCity != null ? '\n## Manager\'s City\n$_preferredCity' : ''}
$currentEventContext

## Available Context Tools

You have access to these functions to get business context when needed:
- **get_clients_list()** - Get list of all clients
- **get_events_summary()** - Get upcoming and recent events (can filter by client)
- **get_team_members()** - Get team members list (can filter by role)
- **get_venues_history()** - Get venues from past events

**IMPORTANT:** Call these functions ONLY when you need the information. Don't call them on every message.

## Event Updates
If the user wants to modify an existing event, respond with "EVENT_UPDATE" followed by a JSON object:
{
  "eventId": "the event ID",
  "updates": {
    "field_name": "new_value",
    ...
  }
}
''';
  }

  /// Get singular form of terminology
  String _getSingularForm(String plural) {
    if (plural == 'Shifts') return 'shift';
    if (plural == 'Events') return 'event';
    if (plural == 'Jobs') return 'job';
    return plural.toLowerCase().substring(0, plural.length - 1); // fallback: remove 's'
  }

  /// Update current event data (e.g., from extraction)
  void updateEventData(Map<String, dynamic> data) {
    _currentEventData.clear();
    _currentEventData.addAll(data);
    print('[ChatEventService] Event data updated with ${data.keys.length} fields');
  }

  /// Start a new conversation
  void startNewConversation() {
    _conversationHistory.clear();
    _currentEventData.clear();
    _eventComplete = false;
    (_createdEntities['clients'] as List).clear();
    (_createdEntities['roles'] as List).clear();
    (_createdEntities['tariffs'] as List).clear();
    _pendingUpdates.clear();

    // Reset conversation tracking for summaries
    _conversationStartTime = DateTime.now();
    _toolsUsedInConversation.clear();
    _toolCallCount = 0;
    _inputSource = 'text';
    print('[ChatEventService] New conversation started at $_conversationStartTime');
  }

  /// Add a message to the conversation history
  void addMessage(ChatMessage message) {
    _conversationHistory.add(message);
  }

  /// Load an existing event for editing
  void loadEventForEditing(Map<String, dynamic> eventData) {
    _conversationHistory.clear();
    _currentEventData.clear();
    _currentEventData.addAll(eventData);
    _eventComplete = false;

    // Add system message explaining we're editing
    _conversationHistory.add(ChatMessage(
      role: 'assistant',
      content:
          'I can help you edit this event. What would you like to change?',
      provider: AIProvider.groq,
    ));
  }

  /// Load an event and auto-analyze it (for AI sparkle button on cards)
  Future<void> loadEventAndAnalyze(Map<String, dynamic> eventData) async {
    _conversationHistory.clear();
    _currentEventData.clear();
    _currentEventData.addAll(eventData);
    _eventComplete = false;

    // Pre-detect missing fields client-side to guide the AI
    final missing = <String>[];
    final data = eventData;
    if ((data['venue_name'] ?? '').toString().isEmpty &&
        (data['venue_address'] ?? '').toString().isEmpty) {
      missing.add('venue/address');
    }
    if ((data['date'] ?? '').toString().isEmpty) missing.add('date');
    if ((data['start_time'] ?? data['call_time'] ?? '').toString().isEmpty) {
      missing.add('start time');
    }
    if ((data['end_time'] ?? '').toString().isEmpty) missing.add('end time');
    final roles = data['roles'];
    if (roles == null || (roles is List && roles.isEmpty)) {
      missing.add('roles/staffing');
    }

    final missingHint = missing.isNotEmpty
        ? 'Missing fields: ${missing.join(", ")}.'
        : 'All key fields appear filled.';

    // Build a lean system prompt — skip the heavy 32KB instructions file.
    // Only include the event JSON and editing rules.
    final leanSystemPrompt = '''You are a helpful event management assistant. You are in EDITING MODE for an existing event.

Current event data:
```json
${jsonEncode(_currentEventData)}
```

When the user requests changes, respond with EVENT_UPDATE followed by JSON: {"eventId": "<id>", "updates": {"field": "value"}}.
Respond in the same language the user speaks. Be concise and conversational. Use natural date/time formats (e.g. "Saturday, Jan 25th" not "2025-01-25").''';

    final analysisPrompt =
        'Give a 2-3 sentence summary of this event, then note what needs attention. $missingHint Keep it brief and ask what they want to update.';

    final messages = [
      {'role': 'system', 'content': leanSystemPrompt},
      {'role': 'user', 'content': analysisPrompt},
    ];

    // Use the user's preferred model (keeps reasoning capability)
    // Lower token budget since analysis is brief, temperature slightly lower for consistency
    final aiResponse = await _callBackendAI(
      messages,
      maxTokensOverride: 300,
      temperatureOverride: 0.5,
    );

    // Add only the AI response to conversation history (no user message visible)
    _conversationHistory.add(ChatMessage(
      role: 'assistant',
      content: aiResponse.content,
      provider: AIProvider.groq,
      reasoning: aiResponse.reasoning,
    ));
  }

  /// Send a user message and get AI response
  Future<ChatMessage> sendMessage(String userMessage, {String? terminology}) async {
    // Add user message to history
    final userMsg = ChatMessage(role: 'user', content: userMessage);
    _conversationHistory.add(userMsg);

    // Build lightweight system prompt (context loaded on-demand via AI tools)
    final systemPrompt = await _buildSystemPrompt(
      terminology: terminology,
    );

    // Build messages for API call
    final messages = [
      {'role': 'system', 'content': systemPrompt},
      ..._conversationHistory.map((msg) => msg.toJson()),
    ];

    // Call backend API
    final aiResponse = await _callBackendAI(messages);

    // Parse response
    String content = aiResponse.content;
    final String? reasoning = aiResponse.reasoning;
    if (content.contains('EVENT_COMPLETE')) {
      _eventComplete = true;
      // Extract JSON from response
      final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(content);
      if (jsonMatch != null) {
        try {
          final extractedData = jsonDecode(jsonMatch.group(0)!) as Map<String, dynamic>;
          _currentEventData.addAll(extractedData);

          // Auto-create entities before saving to pending
          await _createEntitiesIfNeeded(extractedData);
          // Invalidate cache since we may have created new clients/roles
          _invalidateCache();
        } catch (e) {
          print('Failed to parse event JSON: $e');
        }
      }
    } else if (content.contains('EVENT_UPDATE')) {
      // Handle event update requests - auto-apply immediately
      print('[ChatEventService] EVENT_UPDATE detected in response');
      final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(content);
      if (jsonMatch != null) {
        Map<String, dynamic>? updateData;
        try {
          print('[ChatEventService] Raw JSON match: ${jsonMatch.group(0)}');
          updateData = jsonDecode(jsonMatch.group(0)!) as Map<String, dynamic>;
          print('[ChatEventService] Parsed update data: $updateData');
          print('[ChatEventService] Event ID: ${updateData['eventId']}');
          print('[ChatEventService] Updates: ${updateData['updates']}');

          // Auto-apply the update immediately instead of adding to pending list
          print('[ChatEventService] Auto-applying update...');
          await applyUpdate(updateData);
          print('[ChatEventService] ✓ Update applied successfully');

          // Refresh events to get the updated data
          await _loadExistingEvents(forceRefresh: true);
          print('[ChatEventService] ✓ Events refreshed');
        } catch (e) {
          print('[ChatEventService] ✗ Failed to auto-apply update: $e');
          // If auto-apply fails, add to pending updates as fallback
          if (updateData != null) {
            _pendingUpdates.add(updateData);
            print('[ChatEventService] Added to pending updates as fallback (total: ${_pendingUpdates.length})');
          }
        }
      } else {
        print('[ChatEventService] No JSON match found in EVENT_UPDATE response');
      }
    } else if (content.contains('CLIENT_CREATE')) {
      // Handle client creation requests
      final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(content);
      if (jsonMatch != null) {
        try {
          final clientData = jsonDecode(jsonMatch.group(0)!) as Map<String, dynamic>;
          final clientName = clientData['client_name'] as String?;
          if (clientName != null && clientName.isNotEmpty) {
            print('Creating client from chat: $clientName');
            final newClient = await _clientsService.createClient(clientName);
            (_createdEntities['clients'] as List).add(newClient);
            _existingClientNames.add(clientName);
            print('Client created: ${newClient['_id'] ?? newClient['id']}');
            // Invalidate cache
            _invalidateCache();
          }
        } catch (e) {
          print('Failed to create client from chat: $e');
        }
      }
    } else if (content.contains('TARIFF_CREATE')) {
      // Handle tariff creation requests
      print('[TARIFF_CREATE] Detected in response');
      print('[TARIFF_CREATE] Raw content: $content');

      final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(content);
      print('[TARIFF_CREATE] JSON match found: ${jsonMatch != null}');

      if (jsonMatch != null) {
        print('[TARIFF_CREATE] Matched JSON: ${jsonMatch.group(0)}');
        try {
          final tariffData = jsonDecode(jsonMatch.group(0)!) as Map<String, dynamic>;
          print('[TARIFF_CREATE] Parsed tariff data: $tariffData');

          final clientName = tariffData['client_name'] as String?;
          final roleName = tariffData['role_name'] as String?;
          final rate = tariffData['rate'] as num?;

          print('[TARIFF_CREATE] clientName=$clientName, roleName=$roleName, rate=$rate');

          if (clientName != null && roleName != null && rate != null) {
            print('[TARIFF_CREATE] Creating tariff: $clientName - $roleName at \$$rate/hr');

            // Get or create client ID
            final clients = await _clientsService.fetchClients();
            print('[TARIFF_CREATE] Fetched ${clients.length} clients');

            var client = clients.firstWhere(
              (c) => (c['name'] as String?)?.toLowerCase() == clientName.toLowerCase(),
              orElse: () => <String, dynamic>{},
            );
            print('[TARIFF_CREATE] Found existing client: ${client.isNotEmpty}');

            if (client.isEmpty) {
              print('[TARIFF_CREATE] Client not found by exact match, trying to create: $clientName');
              try {
                client = await _clientsService.createClient(clientName);
                (_createdEntities['clients'] as List).add(client);
                _existingClientNames.add(clientName);
                print('[TARIFF_CREATE] Client created: ${client['_id'] ?? client['id']}');
              } catch (e) {
                // Handle 409 "already exists" - client exists with different casing
                if (e.toString().contains('409') || e.toString().contains('already exists')) {
                  print('[TARIFF_CREATE] Client already exists (409), fetching again...');
                  final refreshedClients = await _clientsService.fetchClients();
                  client = refreshedClients.firstWhere(
                    (c) => (c['name'] as String?)?.toLowerCase() == clientName.toLowerCase(),
                    orElse: () => <String, dynamic>{},
                  );
                  if (client.isNotEmpty) {
                    print('[TARIFF_CREATE] Found existing client after refresh: ${client['_id'] ?? client['id']}');
                  } else {
                    print('[TARIFF_CREATE] ✗ Could not find client even after refresh');
                    rethrow;
                  }
                } else {
                  rethrow;
                }
              }
            }

            // Get or create role ID
            final roles = await _rolesService.fetchRoles();
            print('[TARIFF_CREATE] Fetched ${roles.length} roles');

            var role = roles.firstWhere(
              (r) => (r['name'] as String?)?.toLowerCase() == roleName.toLowerCase(),
              orElse: () => <String, dynamic>{},
            );
            print('[TARIFF_CREATE] Found existing role: ${role.isNotEmpty}');

            if (role.isEmpty) {
              print('[TARIFF_CREATE] Role not found by exact match, trying to create: $roleName');
              try {
                role = await _rolesService.createRole(roleName);
                (_createdEntities['roles'] as List).add(role);
                print('[TARIFF_CREATE] Role created: ${role['_id'] ?? role['id']}');
              } catch (e) {
                // Handle 409 "already exists" - role exists with different casing
                if (e.toString().contains('409') || e.toString().contains('already exists')) {
                  print('[TARIFF_CREATE] Role already exists (409), fetching again...');
                  // Re-fetch roles and find by case-insensitive match
                  final refreshedRoles = await _rolesService.fetchRoles();
                  role = refreshedRoles.firstWhere(
                    (r) => (r['name'] as String?)?.toLowerCase() == roleName.toLowerCase(),
                    orElse: () => <String, dynamic>{},
                  );
                  if (role.isNotEmpty) {
                    print('[TARIFF_CREATE] Found existing role after refresh: ${role['_id'] ?? role['id']}');
                  } else {
                    print('[TARIFF_CREATE] ✗ Could not find role even after refresh');
                    rethrow;
                  }
                } else {
                  rethrow;
                }
              }
            }

            // Create tariff
            final clientId = client['_id'] ?? client['id'];
            final roleId = role['_id'] ?? role['id'];
            print('[TARIFF_CREATE] clientId=$clientId, roleId=$roleId');

            if (clientId != null && roleId != null) {
              print('[TARIFF_CREATE] Calling upsertTariff...');
              final newTariff = await _tariffsService.upsertTariff(
                clientId: clientId.toString(),
                roleId: roleId.toString(),
                rate: rate.toDouble(),
              );
              (_createdEntities['tariffs'] as List).add(newTariff);
              print('[TARIFF_CREATE] ✓ Tariff created successfully: $newTariff');
              // Invalidate cache
              _invalidateCache();
            } else {
              print('[TARIFF_CREATE] ✗ Missing clientId or roleId - cannot create tariff');
            }
          } else {
            print('[TARIFF_CREATE] ✗ Missing required fields - clientName=$clientName, roleName=$roleName, rate=$rate');
          }
        } catch (e, stackTrace) {
          print('[TARIFF_CREATE] ✗ Failed to create tariff: $e');
          print('[TARIFF_CREATE] Stack trace: $stackTrace');
        }
      } else {
        print('[TARIFF_CREATE] ✗ No JSON found in response');
      }
    } else {
      // Try to extract any field values from the conversation
      _extractFieldsFromConversation(userMessage, content);
    }

    // Strip technical markers and JSON before showing to user
    final userFacingContent = _extractUserFriendlyMessage(content);

    // Add ONLY the friendly message to conversation history (not the JSON)
    final assistantMsg = ChatMessage(role: 'assistant', content: userFacingContent, provider: AIProvider.groq, reasoning: reasoning);
    _conversationHistory.add(assistantMsg);

    return assistantMsg;
  }

  /// Extract user-friendly message by removing technical markers and JSON
  /// This hides EVENT_COMPLETE, EVENT_UPDATE, CLIENT_CREATE, etc. from users
  /// while still processing the JSON in the background
  String _extractUserFriendlyMessage(String content) {
    // List of technical markers with their fallback messages
    final markersWithFallbacks = {
      'EVENT_COMPLETE': '🎉 Perfect! Your event is ready to save!',
      'EVENT_UPDATE': '✅ Done! I\'ve updated the event for you.',
      'CLIENT_CREATE': '✨ Got it! I\'ve added the new client.',
      'TARIFF_CREATE': '💰 Perfect! The pay rate has been set up.',
    };

    String cleaned = content;
    String? fallbackMessage;

    // Check if any marker exists in the response
    for (final entry in markersWithFallbacks.entries) {
      final marker = entry.key;
      if (cleaned.contains(marker)) {
        // Extract everything BEFORE the marker (the friendly message)
        final markerIndex = cleaned.indexOf(marker);
        cleaned = cleaned.substring(0, markerIndex).trim();
        fallbackMessage = entry.value;
        break;
      }
    }

    // If the friendly message is empty, use the fallback
    if (cleaned.isEmpty && fallbackMessage != null) {
      return fallbackMessage;
    }

    return cleaned;
  }

  /// Create clients, roles, and tariffs if they don't exist
  Future<void> _createEntitiesIfNeeded(Map<String, dynamic> eventData) async {
    try {
      // 1. Create client if needed
      final clientName = eventData['client_name'] as String?;
      if (clientName != null && clientName.isNotEmpty) {
        // Check if client exists in our loaded list
        if (!_existingClientNames.contains(clientName)) {
          try {
            print('Creating new client: $clientName');
            final newClient = await _clientsService.createClient(clientName);
            (_createdEntities['clients'] as List).add(newClient);
            _existingClientNames.add(clientName);
            print('Client created successfully: ${newClient['_id'] ?? newClient['id']}');
          } catch (e) {
            print('Failed to create client: $e');
          }
        }
      }

      // 2. Create roles if needed
      final roles = eventData['roles'];
      if (roles is List && roles.isNotEmpty) {
        // Get existing roles from service
        List<Map<String, dynamic>> existingRoles = [];
        try {
          existingRoles = await _rolesService.fetchRoles();
        } catch (e) {
          print('Failed to fetch roles: $e');
        }

        final existingRoleNames = existingRoles
            .map((r) => (r['name'] as String?) ?? '')
            .where((name) => name.isNotEmpty)
            .toList();

        for (final roleData in roles) {
          final roleNameDynamic = roleData['role'] ?? roleData['name'];
          final roleName = roleNameDynamic?.toString();
          if (roleName != null && roleName.isNotEmpty) {
            if (!existingRoleNames.contains(roleName)) {
              try {
                print('Creating new role: $roleName');
                final newRole = await _rolesService.createRole(roleName);
                (_createdEntities['roles'] as List).add(newRole);
                existingRoleNames.add(roleName);
                print('Role created successfully: ${newRole['_id'] ?? newRole['id']}');
              } catch (e) {
                print('Failed to create role: $e');
              }
            }
          }
        }
      }

      // 3. Create/update tariffs if pay rate info provided
      final payRateInfo = eventData['pay_rate_info'];
      if (payRateInfo != null && payRateInfo.toString().isNotEmpty) {
        // This would require parsing the pay rate info and creating tariffs
        // We'll implement this if the AI provides structured pay rate data
        print('Pay rate info detected: $payRateInfo');
        // TODO: Parse and create tariffs if client and role IDs are available
      }
    } catch (e) {
      print('Error creating entities: $e');
    }
  }

  /// Apply pending updates to events
  Future<void> applyUpdate(Map<String, dynamic> updateData) async {
    try {
      print('[ChatEventService.applyUpdate] Starting update...');
      print('[ChatEventService.applyUpdate] Update data: $updateData');

      final eventId = updateData['eventId'] as String?;
      final updates = updateData['updates'] as Map<String, dynamic>?;

      print('[ChatEventService.applyUpdate] Extracted eventId: $eventId');
      print('[ChatEventService.applyUpdate] Extracted updates: $updates');

      if (eventId == null || updates == null) {
        throw Exception('Invalid update data: eventId=$eventId, updates=$updates');
      }

      print('[ChatEventService.applyUpdate] Calling _eventService.updateEvent...');
      final result = await _eventService.updateEvent(eventId, updates);
      print('[ChatEventService.applyUpdate] Backend response: $result');

      // Remove from pending updates
      _pendingUpdates.removeWhere((u) => u['eventId'] == eventId);

      print('[ChatEventService.applyUpdate] Event updated successfully');
    } catch (e, stackTrace) {
      print('[ChatEventService.applyUpdate] ERROR: $e');
      print('[ChatEventService.applyUpdate] Stack trace: $stackTrace');
      throw Exception('Failed to apply update: $e');
    }
  }

  /// Clear pending updates
  void clearPendingUpdates() {
    _pendingUpdates.clear();
  }

  /// Remove a specific pending update
  void removePendingUpdate(Map<String, dynamic> update) {
    _pendingUpdates.remove(update);
  }

  /// Get current AI provider
  String get aiProviderName => _aiProvider;

  /// Call backend AI chat API.
  /// Model selection is handled server-side by the cascade router —
  /// the client does not send a model preference.
  Future<({String content, String? reasoning})> _callBackendAI(
    List<Map<String, dynamic>> messages, {
    int? maxTokensOverride,
    double? temperatureOverride,
  }) async {
    // Get auth token
    final token = await AuthService.getJwt();
    if (token == null) {
      throw Exception('Not authenticated');
    }

    final String baseUrl = AppConfig.instance.baseUrl;
    final Uri uri = Uri.parse('$baseUrl/ai/chat/message');

    final requestBody = {
      'messages': messages,
      'temperature': temperatureOverride ?? 0.7,
      'maxTokens': maxTokensOverride ?? 500,
      'provider': _aiProvider,
    };

    final headers = {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };

    print('Sending request to AI ($_aiProvider)...');

    final response = await http.post(
      uri,
      headers: headers,
      body: jsonEncode(requestBody),
    );

    if (response.statusCode >= 300) {
      if (response.statusCode == 429) {
        throw Exception(
          'AI chat rate limit reached. Please try again later.',
        );
      }
      throw Exception(
        'AI chat error (${response.statusCode}): ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    try {
      final content = decoded['content'] as String;
      final provider = decoded['provider'] as String?;
      final reasoning = decoded['reasoning'] as String?;
      final usage = decoded['usage'];

      print('Response from: ${provider ?? _aiProvider}');
      if (reasoning != null) {
        print('Reasoning received: ${reasoning.length} chars');
      }
      if (usage != null) {
        print('Token usage: $usage');
      }

      return (content: content, reasoning: reasoning);
    } catch (_) {
      throw Exception('Failed to parse AI response');
    }
  }

  /// Extract field values from conversation
  void _extractFieldsFromConversation(String userMsg, String aiResponse) {
    // Simple heuristic extraction - could be enhanced with more sophisticated parsing
    final lowerUser = userMsg.toLowerCase();
    final lowerAi = aiResponse.toLowerCase();

    // If AI asks about client
    if (lowerAi.contains('client') && lowerAi.contains('name')) {
      if (!_currentEventData.containsKey('client_name')) {
        _currentEventData['client_name'] = userMsg;
      }
    }

    // Date pattern matching
    final datePattern = RegExp(r'\d{4}-\d{2}-\d{2}');
    final dateMatch = datePattern.firstMatch(userMsg);
    if (dateMatch != null) {
      _currentEventData['date'] = dateMatch.group(0);
    }

    // Time pattern matching (HH:MM)
    final timePattern = RegExp(r'\d{1,2}:\d{2}');
    final timeMatches = timePattern.allMatches(userMsg).toList();
    if (timeMatches.isNotEmpty) {
      if (lowerUser.contains('start') || lowerAi.contains('start time')) {
        _currentEventData['start_time'] = timeMatches[0].group(0);
      } else if (lowerUser.contains('end') || lowerAi.contains('end time')) {
        _currentEventData['end_time'] = timeMatches[0].group(0);
      } else if (timeMatches.length >= 2) {
        _currentEventData['start_time'] = timeMatches[0].group(0);
        _currentEventData['end_time'] = timeMatches[1].group(0);
      }
    }
  }

  /// Get a greeting message to start the conversation
  /// Fetches current date/time from backend for contextual greeting
  Future<ChatMessage> getGreeting() async {
    // Initialize conversation start time if not already set
    _conversationStartTime ??= DateTime.now();

    String greetingContent = 'Hey! 👋 Let\'s create an event. Just tell me about it - I\'ll figure out what I need as we go.';

    try {
      // Fetch current date/time context from backend
      final token = await AuthService.getJwt();
      if (token == null) {
        throw Exception('Not authenticated');
      }

      final baseUrl = AppConfig.instance.baseUrl;
      final response = await http.get(
        Uri.parse('$baseUrl/ai/system-info'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final welcomeContext = data['welcomeContext'] as String?;

        if (welcomeContext != null) {
          greetingContent = 'Hey! 👋 It\'s $welcomeContext. Let\'s create an event - just tell me about it and I\'ll figure out what I need as we go.';
        }
      }
    } catch (e) {
      // If fetching date fails, use default greeting
      print('[ChatEventService] Failed to fetch system info: $e');
    }

    final greeting = ChatMessage(
      role: 'assistant',
      content: greetingContent,
      provider: AIProvider.groq,
    );
    _conversationHistory.add(greeting);
    return greeting;
  }

  /// Export conversation history to JSON (for persistence)
  List<Map<String, dynamic>> exportHistory() {
    return _conversationHistory.map((msg) => msg.toStorageJson()).toList();
  }

  /// Import conversation history from JSON
  void importHistory(List<Map<String, dynamic>> history) {
    _conversationHistory.clear();
    for (final msgJson in history) {
      _conversationHistory.add(ChatMessage.fromStorageJson(msgJson));
    }
  }
}
