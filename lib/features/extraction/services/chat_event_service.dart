import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../../../core/config/app_config.dart';
import 'clients_service.dart';

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
  List<String> _existingClientNames = [];

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

  /// Load existing clients from the database
  Future<void> _loadExistingClients() async {
    try {
      final clients = await _clientsService.fetchClients();
      _existingClientNames = clients
          .map((c) => (c['name'] as String?) ?? '')
          .where((name) => name.isNotEmpty)
          .toList();
    } catch (e) {
      print('Failed to load clients: $e');
      _existingClientNames = [];
    }
  }

  /// Build system prompt with current context
  Future<String> _buildSystemPrompt() async {
    final instructions = await _loadInstructions();
    await _loadExistingClients();

    final clientsList = _existingClientNames.isEmpty
        ? 'No existing clients in system.'
        : 'Existing clients: ${_existingClientNames.join(", ")}';

    final currentYear = DateTime.now().year;

    return '''$instructions

## Current Context
- Current year: $currentYear
- Current date: ${DateFormat('yyyy-MM-dd').format(DateTime.now())}
- $clientsList
''';
  }

  /// Start a new conversation
  void startNewConversation() {
    _conversationHistory.clear();
    _currentEventData.clear();
    _eventComplete = false;
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

    // Build system prompt with current context
    final systemPrompt = await _buildSystemPrompt();

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
        } catch (e) {
          print('Failed to parse event JSON: $e');
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

  /// Call backend AI chat API
  Future<String> _callBackendAI(
    List<Map<String, dynamic>> messages,
  ) async {
    final String baseUrl = AppConfig.instance.baseUrl;
    final Uri uri = Uri.parse('$baseUrl/ai/chat/message');

    final requestBody = {
      'messages': messages,
      'temperature': 0.7,
      'maxTokens': 500,
    };

    final headers = {
      'Content-Type': 'application/json',
    };

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
      return decoded['content'] as String;
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
