import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../../../core/config/app_config.dart';
import '../../auth/data/services/auth_service.dart';
import 'clients_service.dart';
import 'event_service.dart';
import 'roles_service.dart';
import 'tariffs_service.dart';

/// Message in a chat conversation
class ChatMessage {
  final String role; // 'user' or 'assistant'
  final String content;
  final DateTime timestamp;

  ChatMessage({
    required this.role,
    required this.content,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'role': role,
        'content': content,
      };

  Map<String, dynamic> toStorageJson() => {
        'role': role,
        'content': content,
        'timestamp': timestamp.toIso8601String(),
      };

  factory ChatMessage.fromStorageJson(Map<String, dynamic> json) {
    return ChatMessage(
      role: json['role'] as String,
      content: json['content'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }
}

/// Service for handling AI chat-powered event creation
class ChatEventService {
  static String? _cachedInstructions;
  final ClientsService _clientsService = ClientsService();
  final EventService _eventService = EventService();
  final RolesService _rolesService = RolesService();
  final TariffsService _tariffsService = TariffsService();

  List<String> _existingClientNames = [];
  List<Map<String, dynamic>> _existingEvents = [];

  // Cache timestamps for smart reloading
  DateTime? _clientsCacheTime;
  DateTime? _eventsCacheTime;
  static const Duration _cacheValidDuration = Duration(minutes: 5);

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

  static const String _fallbackPrompt = '''You are a friendly AI assistant helping create catering event staffing records. Your job is to collect event details through conversation.

Ask for information ONE field at a time in a natural, conversational way. Required fields:
- event_name
- client_name
- date (ISO 8601 format)
- start_time (HH:MM format)
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

  List<ChatMessage> get conversationHistory =>
      List.unmodifiable(_conversationHistory);
  Map<String, dynamic> get currentEventData =>
      Map.unmodifiable(_currentEventData);
  bool get eventComplete => _eventComplete;

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
    // Check if cache is valid
    if (!forceRefresh &&
        _clientsCacheTime != null &&
        DateTime.now().difference(_clientsCacheTime!) < _cacheValidDuration &&
        _existingClientNames.isNotEmpty) {
      print('Using cached clients (${_existingClientNames.length} items)');
      return;
    }

    try {
      print('Fetching fresh clients from database...');
      final clients = await _clientsService.fetchClients();
      _existingClientNames = clients
          .map((c) => (c['name'] as String?) ?? '')
          .where((name) => name.isNotEmpty)
          .toList();
      _clientsCacheTime = DateTime.now();
      print('Loaded ${_existingClientNames.length} clients');
    } catch (e) {
      print('Failed to load clients: $e');
      _existingClientNames = [];
    }
  }

  /// Load existing events from the database with caching and optional filtering
  Future<void> _loadExistingEvents({
    bool forceRefresh = false,
    String? filterByClient,
    String? filterByMonth,
  }) async {
    // Check if cache is valid and no filters applied
    if (!forceRefresh &&
        filterByClient == null &&
        filterByMonth == null &&
        _eventsCacheTime != null &&
        DateTime.now().difference(_eventsCacheTime!) < _cacheValidDuration &&
        _existingEvents.isNotEmpty) {
      print('Using cached events (${_existingEvents.length} items)');
      return;
    }

    try {
      print('Fetching fresh events from database...');
      final allEvents = await _eventService.fetchEvents();

      // Apply filters if specified
      List<Map<String, dynamic>> filteredEvents = allEvents;

      if (filterByClient != null) {
        filteredEvents = filteredEvents.where((event) {
          final clientName = (event['client_name'] as String?)?.toLowerCase() ?? '';
          return clientName.contains(filterByClient.toLowerCase());
        }).toList();
        print('Filtered to ${filteredEvents.length} events for client: $filterByClient');
      }

      if (filterByMonth != null) {
        filteredEvents = filteredEvents.where((event) {
          final dateStr = event['date'] as String?;
          if (dateStr == null) return false;
          return dateStr.contains(filterByMonth);
        }).toList();
        print('Filtered to ${filteredEvents.length} events for month: $filterByMonth');
      }

      _existingEvents = filterByClient == null && filterByMonth == null
          ? allEvents
          : filteredEvents;

      if (filterByClient == null && filterByMonth == null) {
        _eventsCacheTime = DateTime.now();
      }

      print('Loaded ${_existingEvents.length} events');
    } catch (e) {
      print('Failed to load events: $e');
      _existingEvents = [];
    }
  }

  /// Invalidate cache when data changes
  void _invalidateCache() {
    _clientsCacheTime = null;
    _eventsCacheTime = null;
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
    buffer.writeln('Existing events (${_existingEvents.length} total):');

    for (final event in _existingEvents) {
      final id = event['_id'] ?? event['id'] ?? 'unknown';
      final name = event['event_name'] ?? event['name'] ?? 'Unnamed Event';
      final client = event['client_name'] ?? 'No Client';
      final date = event['date'] ?? 'No Date';

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

      buffer.writeln('  - ID: $id | "$name" | Client: $client | Date: $date | Roles: $rolesText');
    }

    return buffer.toString();
  }

  /// Build system prompt with current context (smart loading)
  Future<String> _buildSystemPrompt({
    String? userMessage,
  }) async {
    final instructions = await _loadInstructions();

    // Smart context detection
    Map<String, String?>? contextFilters;
    if (userMessage != null) {
      contextFilters = _detectContextNeeds(userMessage);
    }

    // Load with caching and smart filtering
    await _loadExistingClients();

    // Only load filtered events if user mentioned specific client/month
    await _loadExistingEvents(
      filterByClient: contextFilters?['client'],
      filterByMonth: contextFilters?['month'],
    );

    final clientsList = _existingClientNames.isEmpty
        ? 'No existing clients in system.'
        : 'Existing clients: ${_existingClientNames.join(", ")}';

    final eventsContext = _formatEventsForContext();

    final currentYear = DateTime.now().year;

    return '''$instructions

## Current Context
- Current year: $currentYear
- Current date: ${DateFormat('yyyy-MM-dd').format(DateTime.now())}
- $clientsList

## Existing Events
$eventsContext

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

  /// Start a new conversation
  void startNewConversation() {
    _conversationHistory.clear();
    _currentEventData.clear();
    _eventComplete = false;
    (_createdEntities['clients'] as List).clear();
    (_createdEntities['roles'] as List).clear();
    (_createdEntities['tariffs'] as List).clear();
    _pendingUpdates.clear();
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
    ));
  }

  /// Send a user message and get AI response
  Future<ChatMessage> sendMessage(String userMessage) async {
    // Add user message to history
    final userMsg = ChatMessage(role: 'user', content: userMessage);
    _conversationHistory.add(userMsg);

    // Build system prompt with smart context loading based on user message
    final systemPrompt = await _buildSystemPrompt(userMessage: userMessage);

    // Build messages for API call
    final messages = [
      {'role': 'system', 'content': systemPrompt},
      ..._conversationHistory.map((msg) => msg.toJson()),
    ];

    // Call backend API
    final response = await _callBackendAI(messages);

    // Parse response
    String content = response;
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
      // Handle event update requests
      final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(content);
      if (jsonMatch != null) {
        try {
          final updateData = jsonDecode(jsonMatch.group(0)!) as Map<String, dynamic>;
          _pendingUpdates.add(updateData);
        } catch (e) {
          print('Failed to parse event update JSON: $e');
        }
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
      final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(content);
      if (jsonMatch != null) {
        try {
          final tariffData = jsonDecode(jsonMatch.group(0)!) as Map<String, dynamic>;
          final clientName = tariffData['client_name'] as String?;
          final roleName = tariffData['role_name'] as String?;
          final rate = tariffData['rate'] as num?;

          if (clientName != null && roleName != null && rate != null) {
            print('Creating tariff: $clientName - $roleName at \$$rate/hr');
            // Get or create client ID
            final clients = await _clientsService.fetchClients();
            var client = clients.firstWhere(
              (c) => (c['name'] as String?) == clientName,
              orElse: () => <String, dynamic>{},
            );

            if (client.isEmpty) {
              print('Client not found, creating: $clientName');
              client = await _clientsService.createClient(clientName);
              (_createdEntities['clients'] as List).add(client);
              _existingClientNames.add(clientName);
            }

            // Get or create role ID
            final roles = await _rolesService.fetchRoles();
            var role = roles.firstWhere(
              (r) => (r['name'] as String?) == roleName,
              orElse: () => <String, dynamic>{},
            );

            if (role.isEmpty) {
              print('Role not found, creating: $roleName');
              role = await _rolesService.createRole(roleName);
              (_createdEntities['roles'] as List).add(role);
            }

            // Create tariff
            final clientId = client['_id'] ?? client['id'];
            final roleId = role['_id'] ?? role['id'];

            if (clientId != null && roleId != null) {
              final newTariff = await _tariffsService.upsertTariff(
                clientId: clientId.toString(),
                roleId: roleId.toString(),
                rate: rate.toDouble(),
              );
              (_createdEntities['tariffs'] as List).add(newTariff);
              print('Tariff created successfully');
              // Invalidate cache
              _invalidateCache();
            }
          }
        } catch (e) {
          print('Failed to create tariff from chat: $e');
        }
      }
    } else {
      // Try to extract any field values from the conversation
      _extractFieldsFromConversation(userMessage, content);
    }

    // Add assistant response to history
    final assistantMsg = ChatMessage(role: 'assistant', content: content);
    _conversationHistory.add(assistantMsg);

    return assistantMsg;
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
      final eventId = updateData['eventId'] as String?;
      final updates = updateData['updates'] as Map<String, dynamic>?;

      if (eventId == null || updates == null) {
        throw Exception('Invalid update data');
      }

      print('Applying update to event $eventId: $updates');
      await _eventService.updateEvent(eventId, updates);

      // Remove from pending updates
      _pendingUpdates.removeWhere((u) => u['eventId'] == eventId);

      print('Event updated successfully');
    } catch (e) {
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

  // AI provider preference ('openai' or 'claude')
  String _aiProvider = 'openai'; // Default to OpenAI

  /// Get current AI provider
  String get aiProvider => _aiProvider;

  /// Set AI provider
  void setAiProvider(String provider) {
    if (provider == 'openai' || provider == 'claude') {
      _aiProvider = provider;
      print('AI provider set to: $_aiProvider');
    }
  }

  /// Call backend AI chat API
  Future<String> _callBackendAI(
    List<Map<String, dynamic>> messages,
  ) async {
    // Get auth token
    final token = await AuthService.getJwt();
    if (token == null) {
      throw Exception('Not authenticated');
    }

    final String baseUrl = AppConfig.instance.baseUrl;
    final Uri uri = Uri.parse('$baseUrl/ai/chat/message');

    final requestBody = {
      'messages': messages,
      'temperature': 0.7,
      'maxTokens': 500,
      'provider': _aiProvider, // Include provider selection
    };

    final headers = {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };

    print('Sending request to AI ($aiProvider)...');

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
      final usage = decoded['usage'];

      print('Response from: ${provider ?? _aiProvider}');
      if (usage != null) {
        print('Token usage: $usage');
      }

      return content;
    } catch (_) {
      throw Exception('Failed to parse AI response');
    }
  }

  /// Extract field values from conversation
  void _extractFieldsFromConversation(String userMsg, String aiResponse) {
    // Simple heuristic extraction - could be enhanced with more sophisticated parsing
    final lowerUser = userMsg.toLowerCase();
    final lowerAi = aiResponse.toLowerCase();

    // If AI asks about event name and user hasn't been asked yet
    if (lowerAi.contains('event name') || lowerAi.contains('name of the event')) {
      if (!_currentEventData.containsKey('event_name')) {
        _currentEventData['event_name'] = userMsg;
      }
    }

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
  ChatMessage getGreeting() {
    final greeting = ChatMessage(
      role: 'assistant',
      content:
          'Hey! 👋 Let\'s create an event. Just tell me about it - I\'ll figure out what I need as we go.',
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
