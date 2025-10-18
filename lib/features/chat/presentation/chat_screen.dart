import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/services/chat_service.dart';
import '../domain/entities/chat_message.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    required this.targetId,
    required this.targetName,
    this.targetPicture,
    this.conversationId,
    super.key,
  });

  final String targetId;
  final String targetName;
  final String? targetPicture;
  final String? conversationId;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ChatService _chatService = ChatService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = <ChatMessage>[];

  bool _loading = true;
  String? _error;
  bool _sending = false;
  bool _isTyping = false;
  Timer? _typingTimer;
  SenderType? _currentUserType;
  StreamSubscription<ChatMessage>? _messageSubscription;
  StreamSubscription<Map<String, dynamic>>? _typingSubscription;
  String? _conversationId; // Track conversation ID dynamically

  @override
  void initState() {
    super.initState();
    // In manager app, current user is always a manager
    _currentUserType = SenderType.manager;
    _conversationId = widget.conversationId; // Initialize from widget
    _loadMessages();
    _listenToNewMessages();
    _listenToTypingIndicators();
    _markAsRead();
  }

  void _listenToNewMessages() {
    _messageSubscription = _chatService.messageStream.listen((message) {
      // Accept message if:
      // 1. We have a conversation ID and it matches, OR
      // 2. We don't have a conversation ID yet (first message from user)
      final shouldAccept = _conversationId != null
          ? message.conversationId == _conversationId
          : true; // Accept any message if no conversation yet

      if (shouldAccept) {
        // Check for duplicate message (by ID)
        final isDuplicate = _messages.any((m) => m.id == message.id);

        if (!isDuplicate) {
          setState(() {
            // Update conversation ID if we didn't have one
            _conversationId ??= message.conversationId;
            _messages.add(message);
          });
          _scrollToBottom();
          _markAsRead();
        }
      }
    });
  }

  void _listenToTypingIndicators() {
    _typingSubscription = _chatService.typingStream.listen((data) {
      if (data['conversationId'] == _conversationId) {
        final senderType = data['senderType'] as String;
        final isTyping = data['isTyping'] as bool;

        // Only show typing if it's from the other party
        if ((senderType == 'manager' && _currentUserType == SenderType.user) ||
            (senderType == 'user' && _currentUserType == SenderType.manager)) {
          setState(() {
            _isTyping = isTyping;
          });
        }
      }
    });
  }

  Future<void> _loadMessages() async {
    // If we don't have a conversationId, try to find it from the conversations list
    if (_conversationId == null) {
      try {
        setState(() {
          _loading = true;
          _error = null;
        });

        final conversations = await _chatService.fetchConversations();
        final matchingConv = conversations.where((c) {
          // For managers, match by userKey
          return c.userKey == widget.targetId;
        }).firstOrNull;

        if (matchingConv != null) {
          _conversationId = matchingConv.id;
        } else {
          // No conversation exists yet
          setState(() {
            _loading = false;
          });
          return;
        }
      } catch (e) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
        return;
      }
    }

    try {
      setState(() {
        _loading = true;
        _error = null;
      });

      final messages = await _chatService.fetchMessages(_conversationId!);

      setState(() {
        _messages
          ..clear()
          ..addAll(messages);
        _loading = false;
      });

      _scrollToBottom();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _markAsRead() async {
    if (_conversationId != null) {
      try {
        await _chatService.markAsRead(_conversationId!);
      } catch (e) {
        // Silently fail
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty || _sending) return;

    print('[CHAT DEBUG] Sending message. targetId: ${widget.targetId}, message length: ${message.length}');

    setState(() {
      _sending = true;
    });

    try {
      print('[CHAT DEBUG] Calling chatService.sendMessage...');
      final sentMessage = await _chatService.sendMessage(widget.targetId, message);
      print('[CHAT DEBUG] Message sent successfully');

      // Immediately add the sent message to UI
      setState(() {
        _conversationId ??= sentMessage.conversationId;
        _messages.add(sentMessage);
      });

      _messageController.clear();
      _stopTyping();
      _scrollToBottom();
    } catch (e) {
      print('[CHAT ERROR] Failed to send message: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send message: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _sending = false;
      });
    }
  }

  void _onTyping() {
    if (_conversationId == null || _currentUserType == null) return;

    _chatService.sendTypingIndicator(
      _conversationId!,
      true,
      _currentUserType!,
    );

    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), _stopTyping);
  }

  void _stopTyping() {
    if (_conversationId == null || _currentUserType == null) return;

    _chatService.sendTypingIndicator(
      _conversationId!,
      false,
      _currentUserType!,
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _typingTimer?.cancel();
    _messageSubscription?.cancel();
    _typingSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: <Widget>[
            CircleAvatar(
              radius: 18,
              backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
              backgroundImage: widget.targetPicture != null
                  ? NetworkImage(widget.targetPicture!)
                  : null,
              child: widget.targetPicture == null
                  ? Text(
                      _getInitials(widget.targetName),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).primaryColor,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    widget.targetName,
                    style: const TextStyle(fontSize: 16),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (_isTyping)
                    const Text(
                      'typing...',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        elevation: 1,
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: _buildMessageList(),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(Icons.error_outline, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text('Failed to load messages'),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _loadMessages,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(Icons.chat_outlined, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'No messages yet',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Send a message to start the conversation',
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        final isMe = _currentUserType == message.senderType;
        final showDate = index == 0 ||
            !_isSameDay(_messages[index - 1].createdAt, message.createdAt);

        return Column(
          children: <Widget>[
            if (showDate) _buildDateDivider(message.createdAt),
            _MessageBubble(
              message: message,
              isMe: isMe,
            ),
          ],
        );
      },
    );
  }

  Widget _buildDateDivider(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(date.year, date.month, date.day);

    String label;
    if (messageDate == today) {
      label = 'Today';
    } else if (messageDate == yesterday) {
      label = 'Yesterday';
    } else {
      label = DateFormat('MMM d, yyyy').format(date);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: <Widget>[
          const Expanded(child: Divider()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: <BoxShadow>[
          BoxShadow(
            offset: const Offset(0, -1),
            blurRadius: 4,
            color: Colors.black.withOpacity(0.05),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: <Widget>[
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: _messageController,
                  decoration: const InputDecoration(
                    hintText: 'Type a message...',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                  maxLines: null,
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: (_) => _onTyping(),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: _sending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.send, color: Colors.white),
                onPressed: _sending ? null : _sendMessage,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts[0].substring(0, 1).toUpperCase();
    }
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.isMe,
  });

  final ChatMessage message;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          if (!isMe) ...<Widget>[
            CircleAvatar(
              radius: 14,
              backgroundColor: theme.primaryColor.withOpacity(0.1),
              backgroundImage: message.senderPicture != null
                  ? NetworkImage(message.senderPicture!)
                  : null,
              child: message.senderPicture == null
                  ? Text(
                      (message.senderName ?? '?')[0].toUpperCase(),
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isMe ? theme.primaryColor : Colors.grey[200],
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isMe ? 20 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 20),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (!isMe && message.senderName != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        message.senderName!,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                  Text(
                    message.message,
                    style: TextStyle(
                      fontSize: 15,
                      color: isMe ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('h:mm a').format(message.createdAt),
                    style: TextStyle(
                      fontSize: 11,
                      color: isMe ? Colors.white70 : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isMe) const SizedBox(width: 8),
        ],
      ),
    );
  }
}
