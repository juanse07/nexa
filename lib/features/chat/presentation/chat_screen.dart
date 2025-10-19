import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/services/chat_service.dart';
import '../domain/entities/chat_message.dart';
import 'widgets/event_invitation_card.dart';
import 'dialogs/send_event_invitation_dialog.dart';
import '../../../features/extraction/services/event_service.dart';

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
  StreamSubscription<Map<String, dynamic>>? _invitationResponseSubscription;
  String? _conversationId; // Track conversation ID dynamically

  @override
  void initState() {
    super.initState();
    print('[CHAT SCREEN] initState called');
    print('[CHAT SCREEN] widget.targetId: ${widget.targetId}');
    print('[CHAT SCREEN] widget.targetName: ${widget.targetName}');
    print('[CHAT SCREEN] widget.conversationId: ${widget.conversationId}');

    // In manager app, current user is always a manager
    _currentUserType = SenderType.manager;
    _conversationId = widget.conversationId; // Initialize from widget

    // Call _loadMessages with error handling
    _loadMessages().catchError((e) {
      print('[CHAT SCREEN ERROR] Failed to load messages in initState: $e');
    });

    _listenToNewMessages();
    _listenToTypingIndicators();
    _listenToInvitationResponses();
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

  void _listenToInvitationResponses() {
    _invitationResponseSubscription = _chatService.invitationResponseStream.listen((data) {
      final receivedAt = DateTime.now();
      print('[INVITATION_ANALYTICS] invitation_responded event received');
      print('[INVITATION_ANALYTICS] rawData: $data');

      // Update the specific message with the new status
      final messageId = data['messageId'] as String?;
      final status = data['status'] as String?;
      final respondedAt = data['respondedAt'] as String?;
      final userId = data['userId'] as String?;
      final userName = data['userName'] as String?;
      final eventId = data['eventId'] as String?;
      final roleId = data['roleId'] as String?;

      print('[INVITATION_ANALYTICS] messageId: $messageId');
      print('[INVITATION_ANALYTICS] status: $status');
      print('[INVITATION_ANALYTICS] userId: $userId');
      print('[INVITATION_ANALYTICS] userName: $userName');
      print('[INVITATION_ANALYTICS] eventId: $eventId');
      print('[INVITATION_ANALYTICS] roleId: $roleId');

      if (messageId != null && status != null) {
        // Calculate response time
        final messageIndex = _messages.indexWhere((m) => m.id == messageId);
        if (messageIndex != -1) {
          final originalMessage = _messages[messageIndex];
          final sentAt = originalMessage.createdAt;
          final responseTimeMinutes = receivedAt.difference(sentAt).inMinutes;

          print('[INVITATION_ANALYTICS] responseTimeMinutes: $responseTimeMinutes');
          print('[INVITATION_ANALYTICS] accepted: ${status == 'accepted'}');
        }

        setState(() {
          final index = _messages.indexWhere((m) => m.id == messageId);
          if (index != -1) {
            // Update the message metadata
            final message = _messages[index];
            final updatedMetadata = Map<String, dynamic>.from(message.metadata ?? {});
            updatedMetadata['status'] = status;
            if (respondedAt != null) {
              updatedMetadata['respondedAt'] = respondedAt;
            }

            // Create updated message (since ChatMessage is immutable, we need to reload)
            print('[CHAT] Message status updated to: $status');
          }
        });

        // Reload messages to get the updated version
        _loadMessages();

        // Show notification to manager
        if (mounted) {
          final targetUserName = widget.targetName;
          final accepted = status == 'accepted';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                accepted
                    ? '$targetUserName accepted the invitation!'
                    : '$targetUserName declined the invitation',
              ),
              backgroundColor: accepted ? Colors.green : Colors.grey.shade600,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    });
  }

  Future<void> _loadMessages() async {
    print('[CHAT] _loadMessages called');
    print('[CHAT] _conversationId at start: $_conversationId');
    print('[CHAT] widget.targetId: ${widget.targetId}');

    // If we don't have a conversationId, try to find it from the conversations list
    if (_conversationId == null) {
      try {
        print('[CHAT] No conversationId, fetching conversations to find match for targetId: ${widget.targetId}');
        setState(() {
          _loading = true;
          _error = null;
        });

        print('[CHAT] About to call _chatService.fetchConversations()...');
        final conversations = await _chatService.fetchConversations();
        print('[CHAT] Fetched ${conversations.length} conversations');

        final matchingList = conversations.where((c) {
          // For managers, match by userKey
          print('[CHAT] Checking conversation: userKey=${c.userKey}, managerId=${c.managerId}');
          return c.userKey == widget.targetId;
        }).toList();

        print('[CHAT] Found ${matchingList.length} matching conversations');
        final matchingConv = matchingList.isNotEmpty ? matchingList.first : null;

        if (matchingConv != null) {
          _conversationId = matchingConv.id;
          print('[CHAT] Found conversationId: $_conversationId');
        } else {
          // No conversation exists yet
          print('[CHAT] No matching conversation found, showing empty state');
          setState(() {
            _loading = false;
          });
          return;
        }
      } catch (e, stack) {
        print('[CHAT ERROR] Failed to fetch conversations: $e');
        print('[CHAT ERROR] Stack: $stack');
        setState(() {
          _error = e.toString();
          _loading = false;
        });
        return;
      }
    }

    try {
      print('[CHAT] Loading messages for conversationId: $_conversationId');
      setState(() {
        _loading = true;
        _error = null;
      });

      final messages = await _chatService.fetchMessages(_conversationId!);
      print('[CHAT] Loaded ${messages.length} messages');

      setState(() {
        _messages
          ..clear()
          ..addAll(messages);
        _loading = false;
      });

      _scrollToBottom();
    } catch (e, stack) {
      print('[CHAT ERROR] Failed to load messages: $e');
      print('[CHAT ERROR] Stack: $stack');
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

  Future<void> _showSendInvitationDialog() async {
    await showDialog<void>(
      context: context,
      builder: (context) => SendEventInvitationDialog(
        targetName: widget.targetName,
        onSendInvitation: _sendEventInvitation,
      ),
    );
  }

  Future<void> _sendEventInvitation(
    String eventId,
    String roleId,
    Map<String, dynamic> eventData,
  ) async {
    final startTime = DateTime.now();

    try {
      print('[INVITATION_ANALYTICS] invitation_sent event started');
      print('[INVITATION_ANALYTICS] eventId: $eventId');
      print('[INVITATION_ANALYTICS] roleId: $roleId');
      print('[INVITATION_ANALYTICS] targetId: ${widget.targetId}');
      print('[INVITATION_ANALYTICS] eventName: ${eventData['title']}');

      final sentMessage = await _chatService.sendEventInvitation(
        targetId: widget.targetId,
        eventId: eventId,
        roleId: roleId,
        eventData: eventData,
      );

      final duration = DateTime.now().difference(startTime);
      print('[INVITATION_ANALYTICS] invitation_sent success');
      print('[INVITATION_ANALYTICS] messageId: ${sentMessage.id}');
      print('[INVITATION_ANALYTICS] conversationId: ${sentMessage.conversationId}');
      print('[INVITATION_ANALYTICS] sendDuration: ${duration.inMilliseconds}ms');

      // Immediately add the invitation to UI
      setState(() {
        _conversationId ??= sentMessage.conversationId;
        _messages.add(sentMessage);
      });

      _scrollToBottom();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Event invitation sent!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      final duration = DateTime.now().difference(startTime);
      print('[INVITATION_ANALYTICS] invitation_error');
      print('[INVITATION_ANALYTICS] error: $e');
      print('[INVITATION_ANALYTICS] eventId: $eventId');
      print('[INVITATION_ANALYTICS] targetId: ${widget.targetId}');
      print('[INVITATION_ANALYTICS] step: send');
      print('[INVITATION_ANALYTICS] duration: ${duration.inMilliseconds}ms');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send invitation: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      rethrow;
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _typingTimer?.cancel();
    _messageSubscription?.cancel();
    _typingSubscription?.cancel();
    _invitationResponseSubscription?.cancel();
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
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showSendInvitationDialog,
            tooltip: 'Send Event Invitation',
          ),
        ],
        elevation: 0.5,
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
            // Check if it's an invitation card or regular message
            message.messageType == 'eventInvitation'
                ? _buildInvitationCard(message)
                : _MessageBubble(
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

  Widget _buildInvitationCard(ChatMessage message) {
    final metadata = message.metadata ?? {};
    final eventId = metadata['eventId'] as String?;
    final roleId = metadata['roleId'] as String?;
    final status = metadata['status'] as String?;
    final respondedAt = metadata['respondedAt'] != null
        ? DateTime.parse(metadata['respondedAt'] as String)
        : null;

    if (eventId == null || roleId == null) {
      return const SizedBox.shrink();
    }

    // Fetch event data from the service
    return FutureBuilder<Map<String, dynamic>>(
      future: EventService().fetchEvents().then((events) {
        try {
          return events.firstWhere(
            (e) => (e['_id'] ?? e['id']) == eventId,
            orElse: () => <String, dynamic>{},
          );
        } catch (e) {
          return <String, dynamic>{};
        }
      }),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Event not found'),
          );
        }

        final eventData = snapshot.data!;
        final roles = eventData['roles'] as List<dynamic>? ?? [];
        final role = roles.cast<Map<String, dynamic>>().firstWhere(
          (r) => (r['_id'] ?? r['role_id']) == roleId,
          orElse: () => <String, dynamic>{},
        );

        final eventName = eventData['title'] as String? ?? 'Event';
        final roleName = role['role_name'] as String? ?? 'Role';
        final clientName = eventData['client_name'] as String? ?? 'Client';
        final venueName = eventData['venue_name'] as String?;
        final rate = role['rate'] as num?;
        final startDate = eventData['start_date'] != null
            ? DateTime.parse(eventData['start_date'] as String)
            : DateTime.now();
        final endDate = eventData['end_date'] != null
            ? DateTime.parse(eventData['end_date'] as String)
            : startDate.add(const Duration(hours: 4));

        return EventInvitationCard(
          eventName: eventName,
          roleName: roleName,
          clientName: clientName,
          startDate: startDate,
          endDate: endDate,
          venueName: venueName,
          rate: rate?.toDouble(),
          status: status,
          respondedAt: respondedAt,
          isManager: true, // Manager view - can't respond
        );
      },
    );
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
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFFFFD700), // Light gold
                    Color(0xFFFFB700), // Medium gold
                    Color(0xFFFFA000), // Darker gold
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFFD700).withOpacity(0.5),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                    spreadRadius: 1,
                  ),
                  BoxShadow(
                    color: const Color(0xFFFFA000).withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                    spreadRadius: 0,
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
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
                      : const Icon(Icons.send, color: Colors.white, size: 22),
                  onPressed: _sending ? null : _sendMessage,
                ),
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
