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

  Stream<ChatMessage> get messageStream => _messageController.stream;
  Stream<Map<String, dynamic>> get typingStream => _typingController.stream;

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
      }
    });
  }

  Future<List<Conversation>> fetchConversations() async {
    final token = await AuthService.getJwt();
    if (token == null) {
      throw Exception('Not authenticated');
    }

    final baseUrl = AppConfig.instance.baseUrl;
    final url = Uri.parse('$baseUrl/chat/conversations');

    final response = await http.get(
      url,
      headers: <String, String>{
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      final conversations = (data['conversations'] as List<dynamic>)
          .map((e) => Conversation.fromJson(e as Map<String, dynamic>))
          .toList();
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
  }
}
