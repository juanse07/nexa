import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../../core/config/app_config.dart';
import '../../../../core/network/socket_manager.dart';
import '../../../auth/data/services/auth_service.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/entities/conversation.dart';

class ChatService {
  factory ChatService() => _instance;
  ChatService._internal() {
    _setupSocketListeners();
  }

  static final ChatService _instance = ChatService._internal();

  final StreamController<ChatMessage> _messageController =
      StreamController<ChatMessage>.broadcast();
  final StreamController<Map<String, dynamic>> _typingController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _invitationResponseController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<ChatMessage> get messageStream => _messageController.stream;
  Stream<Map<String, dynamic>> get typingStream => _typingController.stream;
  Stream<Map<String, dynamic>> get invitationResponseStream =>
      _invitationResponseController.stream;

  void _setupSocketListeners() {
    SocketManager.instance.events.listen((event) {
      if (event.event == 'chat:message') {
        try {
          final message = ChatMessage.fromJson(
            event.data as Map<String, dynamic>,
          );
          _messageController.add(message);
        } catch (e) {
          print('Error parsing chat message: $e');
        }
      } else if (event.event == 'chat:typing') {
        try {
          _typingController.add(event.data as Map<String, dynamic>);
        } catch (e) {
          print('Error parsing typing indicator: $e');
        }
      } else if (event.event == 'invitation:responded') {
        try {
          print('[ChatService] Invitation response received: ${event.data}');
          _invitationResponseController.add(event.data as Map<String, dynamic>);
        } catch (e) {
          print('Error parsing invitation response: $e');
        }
      }
    });
  }

  Future<List<Conversation>> fetchConversations() async {
    print('[ChatService] fetchConversations called');
    final token = await AuthService.getJwt();
    if (token == null) {
      print('[ChatService] ERROR: No token found');
      throw Exception('Not authenticated');
    }

    print('[ChatService] Token obtained (length: ${token.length})');
    final baseUrl = AppConfig.instance.baseUrl;
    final url = Uri.parse('$baseUrl/chat/conversations');
    print('[ChatService] Fetching from: $url');

    final response = await http.get(
      url,
      headers: <String, String>{
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    print('[ChatService] Response status: ${response.statusCode}');
    print('[ChatService] Response body: ${response.body}');

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      final conversations = (data['conversations'] as List<dynamic>)
          .map((e) => Conversation.fromJson(e as Map<String, dynamic>))
          .toList();
      print('[ChatService] Parsed ${conversations.length} conversations');
      return conversations;
    } else {
      throw Exception('Failed to fetch conversations: ${response.body}');
    }
  }

  Future<List<ChatMessage>> fetchMessages(
    String conversationId, {
    DateTime? before,
    int limit = 50,
  }) async {
    final token = await AuthService.getJwt();
    if (token == null) {
      throw Exception('Not authenticated');
    }

    final baseUrl = AppConfig.instance.baseUrl;
    final queryParams = <String, String>{
      'limit': limit.toString(),
      if (before != null) 'before': before.toIso8601String(),
    };

    final url = Uri.parse(
      '$baseUrl/chat/conversations/$conversationId/messages',
    ).replace(queryParameters: queryParams);

    final response = await http.get(
      url,
      headers: <String, String>{
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      final messages = (data['messages'] as List<dynamic>)
          .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
          .toList();
      return messages;
    } else {
      throw Exception('Failed to fetch messages: ${response.body}');
    }
  }

  Future<ChatMessage> sendMessage(String targetId, String message) async {
    print('[ChatService] sendMessage called. targetId: $targetId');

    final token = await AuthService.getJwt();
    if (token == null) {
      print('[ChatService] ERROR: Not authenticated');
      throw Exception('Not authenticated');
    }

    final baseUrl = AppConfig.instance.baseUrl;
    final url = Uri.parse('$baseUrl/chat/conversations/$targetId/messages');

    print('[ChatService] POST to: $url');
    print('[ChatService] Message: ${message.substring(0, message.length > 50 ? 50 : message.length)}...');

    final response = await http.post(
      url,
      headers: <String, String>{
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode(<String, dynamic>{
        'message': message,
      }),
    );

    print('[ChatService] Response status: ${response.statusCode}');
    print('[ChatService] Response body: ${response.body}');

    if (response.statusCode == 201) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      return ChatMessage.fromJson(data['message'] as Map<String, dynamic>);
    } else {
      throw Exception('Failed to send message: ${response.body}');
    }
  }

  Future<void> markAsRead(String conversationId) async {
    final token = await AuthService.getJwt();
    if (token == null) {
      throw Exception('Not authenticated');
    }

    final baseUrl = AppConfig.instance.baseUrl;
    final url = Uri.parse('$baseUrl/chat/conversations/$conversationId/read');

    final response = await http.patch(
      url,
      headers: <String, String>{
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to mark as read: ${response.body}');
    }
  }

  Future<List<Map<String, dynamic>>> fetchManagers() async {
    final token = await AuthService.getJwt();
    if (token == null) {
      throw Exception('Not authenticated');
    }

    final baseUrl = AppConfig.instance.baseUrl;
    final url = Uri.parse('$baseUrl/chat/managers');

    final response = await http.get(
      url,
      headers: <String, String>{
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      return (data['managers'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
    } else {
      throw Exception('Failed to fetch managers: ${response.body}');
    }
  }

  /// Fetch contacts (team members) for chat - FOR MANAGERS
  /// This replaces the need to call /users endpoint
  /// Returns team members with conversation status
  Future<List<Map<String, dynamic>>> fetchContacts({String? searchQuery}) async {
    print('[ChatService] fetchContacts called with query: $searchQuery');
    final token = await AuthService.getJwt();
    if (token == null) {
      print('[ChatService] ERROR: No token found');
      throw Exception('Not authenticated');
    }

    final baseUrl = AppConfig.instance.baseUrl;
    final queryParams = searchQuery != null && searchQuery.isNotEmpty
        ? {'q': searchQuery}
        : null;

    final url = Uri.parse('$baseUrl/chat/contacts').replace(
      queryParameters: queryParams,
    );

    print('[ChatService] Fetching from: $url');

    final response = await http.get(
      url,
      headers: <String, String>{
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    print('[ChatService] Response status: ${response.statusCode}');

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      final contacts = (data['contacts'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>();
      print('[ChatService] Parsed ${contacts.length} contacts');
      return contacts;
    } else if (response.statusCode == 403) {
      // Manager auth required
      print('[ChatService] ERROR 403: Manager authentication required');
      throw Exception('Manager authentication required. Please sign in using the manager app.');
    } else {
      print('[ChatService] ERROR: ${response.body}');
      throw Exception('Failed to fetch contacts: ${response.body}');
    }
  }

  /// Send an event invitation to a user
  Future<ChatMessage> sendEventInvitation({
    required String targetId,
    required String eventId,
    required String roleId,
    required Map<String, dynamic> eventData,
  }) async {
    print('[ChatService] sendEventInvitation called. targetId: $targetId, eventId: $eventId');

    final token = await AuthService.getJwt();
    if (token == null) {
      print('[ChatService] ERROR: Not authenticated');
      throw Exception('Not authenticated');
    }

    final baseUrl = AppConfig.instance.baseUrl;
    final url = Uri.parse('$baseUrl/chat/conversations/$targetId/messages');

    // Extract event details for the message
    final eventName = eventData['title'] as String? ?? eventData['event_name'] as String? ?? 'Event';
    final roles = eventData['roles'] as List<dynamic>? ?? [];
    final role = roles.cast<Map<String, dynamic>>().firstWhere(
      (r) => (r['_id'] ?? r['role_id'] ?? r['role']) == roleId,
      orElse: () => <String, dynamic>{},
    );
    final roleName = role['role_name'] as String? ?? role['role'] as String? ?? 'Role';

    final message = 'You\'ve been invited to $eventName as $roleName';

    print('[ChatService] POST to: $url');

    final response = await http.post(
      url,
      headers: <String, String>{
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode(<String, dynamic>{
        'message': message,
        'messageType': 'eventInvitation',
        'metadata': <String, dynamic>{
          'eventId': eventId,
          'roleId': roleId,
          'status': 'pending',
        },
      }),
    );

    print('[ChatService] Response status: ${response.statusCode}');
    print('[ChatService] Response body: ${response.body}');

    if (response.statusCode == 201) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      return ChatMessage.fromJson(data['message'] as Map<String, dynamic>);
    } else {
      throw Exception('Failed to send invitation: ${response.body}');
    }
  }

  /// Send bulk invitations to multiple users without publishing the event
  /// Event stays in 'draft' status - only invited users can see it
  Future<Map<String, dynamic>> sendBulkInvitations({
    required String eventId,
    required List<Map<String, dynamic>> userRoleAssignments,
  }) async {
    print('[ChatService] sendBulkInvitations called for event: $eventId');
    print('[ChatService] Sending to ${userRoleAssignments.length} users');

    final token = await AuthService.getJwt();
    if (token == null) {
      throw Exception('Not authenticated');
    }

    final baseUrl = AppConfig.instance.baseUrl;
    final url = Uri.parse('$baseUrl/chat/invitations/send-bulk');

    final response = await http.post(
      url,
      headers: <String, String>{
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode(<String, dynamic>{
        'eventId': eventId,
        'userRoleAssignments': userRoleAssignments,
      }),
    );

    print('[ChatService] sendBulkInvitations response status: ${response.statusCode}');
    print('[ChatService] sendBulkInvitations response body: ${response.body}');

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      return data;
    } else {
      final error = json.decode(response.body);
      throw Exception(error['error'] ?? 'Failed to send bulk invitations');
    }
  }

  /// Respond to an event invitation (accept or decline)
  Future<void> respondToInvitation({
    required String messageId,
    required String eventId,
    required String roleId,
    required bool accept,
  }) async {
    print('[ChatService] respondToInvitation called. messageId: $messageId, accept: $accept');

    final token = await AuthService.getJwt();
    if (token == null) {
      throw Exception('Not authenticated');
    }

    final baseUrl = AppConfig.instance.baseUrl;
    final url = Uri.parse('$baseUrl/chat/invitations/$messageId/respond');

    final response = await http.post(
      url,
      headers: <String, String>{
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode(<String, dynamic>{
        'accept': accept,
        'eventId': eventId,
        'roleId': roleId,
      }),
    );

    print('[ChatService] Response status: ${response.statusCode}');

    if (response.statusCode != 200) {
      throw Exception('Failed to respond to invitation: ${response.body}');
    }
  }

  void sendTypingIndicator(
    String conversationId,
    bool isTyping,
    SenderType senderType,
  ) {
    SocketManager.instance.socket?.emit('chat:typing', <String, dynamic>{
      'conversationId': conversationId,
      'isTyping': isTyping,
      'senderType': senderType == SenderType.manager ? 'manager' : 'user',
    });
  }

  void dispose() {
    _messageController.close();
    _typingController.close();
    _invitationResponseController.close();
  }
}
