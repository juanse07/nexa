import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nexa/l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/services/chat_service.dart';
import '../domain/entities/chat_message.dart';
import 'widgets/event_invitation_card.dart';
import 'dialogs/send_event_invitation_dialog.dart';
import '../../../features/extraction/services/event_service.dart';
import '../../../features/extraction/services/roles_service.dart';
import '../../../features/users/presentation/pages/user_events_screen.dart';
import 'package:nexa/shared/presentation/theme/app_colors.dart';

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

// Global cache to persist event data across widget rebuilds
final Map<String, Map<String, dynamic>> _globalEventCache = {};

class _ChatScreenState extends State<ChatScreen> {
  final ChatService _chatService = ChatService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = <ChatMessage>[];
  final RolesService _rolesService = RolesService();

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

  // Favorites functionality
  Set<String> _favoriteUsers = {};
  List<Map<String, dynamic>>? _roles;
  String? _visibleDate; // Tracks the currently visible date section

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
    _scrollController.addListener(_updateVisibleDate);

    // Load favorites and roles for menu
    _loadFavorites();
    _loadRoles();
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

          // Smooth scroll to bottom for new messages
          _scrollToBottom(animated: true);
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

    // Only show loading if we have no messages yet
    final isInitialLoad = _messages.isEmpty;

    // If we don't have a conversationId, try to find it from the conversations list
    if (_conversationId == null) {
      try {
        print('[CHAT] No conversationId, fetching conversations to find match for targetId: ${widget.targetId}');
        setState(() {
          if (isInitialLoad) _loading = true;
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
        if (isInitialLoad) _loading = true;
        _error = null;
      });

      final messages = await _chatService.fetchMessages(_conversationId!);
      print('[CHAT] Loaded ${messages.length} messages');

      setState(() {
        _messages
          ..clear()
          ..addAll(messages);
        _loading = false;

        // Set initial visible date to the latest message's date
        if (_messages.isNotEmpty) {
          _visibleDate = DateFormat('MMM d, yyyy').format(_messages.last.createdAt);
        }
      });

      // Scroll to bottom - instant on initial load, animated on refresh
      _scrollToBottom(animated: !isInitialLoad);
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

  void _scrollToBottom({bool animated = true}) {
    // With reverse: true, we scroll to 0 to reach the bottom
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        if (animated) {
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
          );
        } else {
          _scrollController.jumpTo(0);
        }
      }
    });
  }

  void _updateVisibleDate() {
    if (!_scrollController.hasClients || _messages.isEmpty) return;

    final scrollOffset = _scrollController.offset;
    final approximateIndex = (scrollOffset / 80).floor();
    final targetIndex = approximateIndex.clamp(0, _messages.length - 1);

    if (targetIndex < _messages.length) {
      // Reverse the index since ListView has reverse: true
      final message = _messages[_messages.length - 1 - targetIndex];
      final newDate = DateFormat('MMM d, yyyy').format(message.createdAt);

      if (_visibleDate != newDate) {
        setState(() {
          _visibleDate = newDate;
        });
      }
    }
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty || _sending) return;

    print('[CHAT DEBUG] Sending message. targetId: ${widget.targetId}, message length: ${message.length}');

    setState(() {
      _sending = true;
    });

    // Clear input immediately for better UX
    _messageController.clear();
    _stopTyping();

    try {
      print('[CHAT DEBUG] Calling chatService.sendMessage...');
      final sentMessage = await _chatService.sendMessage(widget.targetId, message);
      print('[CHAT DEBUG] Message sent successfully. ID: ${sentMessage.id}');

      // Check if message already exists (from socket)
      final isDuplicate = _messages.any((m) => m.id == sentMessage.id);

      if (!isDuplicate) {
        // Add message to UI immediately (socket might not have received it yet)
        setState(() {
          _conversationId ??= sentMessage.conversationId;
          _messages.add(sentMessage);
        });
        _scrollToBottom();
      } else {
        print('[CHAT DEBUG] Message already in list from socket, skipping duplicate');
        // Just update conversation ID
        setState(() {
          _conversationId ??= sentMessage.conversationId;
        });
      }
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

  Future<void> _initiateCall() async {
    // In a real app, you would fetch the user's phone number from the API
    // For now, we'll show a message
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Calling ${widget.targetName}...'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }

    // If you have the phone number, you can use:
    // final phoneNumber = 'tel:+1234567890'; // Replace with actual number
    // if (await canLaunchUrl(Uri.parse(phoneNumber))) {
    //   await launchUrl(Uri.parse(phoneNumber));
    // }
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

      // Check if message already exists (from socket)
      final isDuplicate = _messages.any((m) => m.id == sentMessage.id);

      if (!isDuplicate) {
        // Add invitation to UI immediately (socket might not have received it yet)
        setState(() {
          _conversationId ??= sentMessage.conversationId;
          _messages.add(sentMessage);
        });
        _scrollToBottom();
      } else {
        print('[INVITATION_ANALYTICS] Invitation already in list from socket, skipping duplicate');
        // Just update conversation ID
        setState(() {
          _conversationId ??= sentMessage.conversationId;
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.jobInvitationSent),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
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
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(65),
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF1E3A8A), // Ocean Blue
                Color(0xFF00838F), // Dark teal
                Color(0xFF00BCD4), // Medium teal
                Color(0xFF26C6DA), // Light teal
              ],
              stops: [0.05, 0.35, 0.75, 1.0],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.tealInfo.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Decorative shadow shapes
              Positioned(
                top: -20,
                right: -40,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.1),
                  ),
                ),
              ),
              Positioned(
                bottom: -30,
                left: -20,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withOpacity(0.1),
                  ),
                ),
              ),
              // AppBar content
              AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                title: Row(
                  children: <Widget>[
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 2.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 20,
                        backgroundColor: Colors.white,
                        backgroundImage: widget.targetPicture != null
                            ? NetworkImage(widget.targetPicture!)
                            : null,
                        child: widget.targetPicture == null
                            ? Text(
                                _getInitials(widget.targetName),
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.yellow,
                                  letterSpacing: 0.5,
                                ),
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Text(
                            widget.targetName,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: 0.3,
                              shadows: [
                                Shadow(
                                  color: Colors.black26,
                                  offset: Offset(0, 1),
                                  blurRadius: 2,
                                ),
                              ],
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (_isTyping)
                            Row(
                              children: [
                                Container(
                                  width: 7,
                                  height: 7,
                                  margin: const EdgeInsets.only(right: 6, top: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.successLight,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.successLight.withOpacity(0.5),
                                        blurRadius: 4,
                                        spreadRadius: 1,
                                      ),
                                    ],
                                  ),
                                ),
                                const Text(
                                  'typing...',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                actions: [
                  // Call button
                  Container(
                    margin: const EdgeInsets.only(right: 4),
                    child: IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: const Icon(
                          Icons.phone,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      onPressed: _initiateCall,
                    ),
                  ),
                  // Menu button
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    child: PopupMenuButton<String>(
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: const Icon(
                          Icons.more_vert,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 8,
                      offset: const Offset(0, 8),
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'view',
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Icon(Icons.event_rounded, color: AppColors.yellow, size: 22),
                                SizedBox(width: 14),
                                Text(
                                  AppLocalizations.of(context)!.viewJobs,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.charcoal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (_favoriteRoleOptions.isNotEmpty)
                          const PopupMenuDivider(height: 8),
                        ..._favoriteRoleOptions.map(
                          (role) => PopupMenuItem(
                            value: 'favorite:$role',
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  Icon(
                                    _isFavorite(widget.targetId, role)
                                        ? Icons.star_rounded
                                        : Icons.star_border_rounded,
                                    color: _isFavorite(widget.targetId, role)
                                        ? const Color(0xFFFBBF24)
                                        : AppColors.greyMedium,
                                    size: 22,
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Text(
                                      '${_isFavorite(widget.targetId, role) ? 'Remove from' : 'Add to'} $role',
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500,
                                        color: AppColors.charcoal,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                      onSelected: (value) {
                        if (value == 'view') {
                          // Parse targetId to create user object
                          final parts = widget.targetId.split(':');
                          final userMap = <String, dynamic>{
                            'provider': parts.isNotEmpty ? parts[0] : '',
                            'subject': parts.length > 1 ? parts.sublist(1).join(':') : '',
                            'name': widget.targetName,
                            'picture': widget.targetPicture,
                          };
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => UserEventsScreen(user: userMap),
                            ),
                          );
                        } else if (value.startsWith('favorite:')) {
                          final role = value.substring('favorite:'.length);
                          _toggleFavorite(widget.targetId, role);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      body: Stack(
        children: <Widget>[
          // Message list with extra bottom padding for input
          Padding(
            padding: const EdgeInsets.only(bottom: 80), // Space for input
            child: _buildMessageList(),
          ),
          // Fixed bottom input (no animation)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildMessageInput(),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    // Show error state
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

    // Show empty state only if not loading and truly empty
    if (_messages.isEmpty && !_loading) {
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

    // Show loading only on initial load when messages are empty
    if (_loading && _messages.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.yellow),
        ),
      );
    }

    // Build message list in reverse (latest at bottom, like all chat apps)
    return Stack(
      children: [
        ListView.builder(
          controller: _scrollController,
          reverse: true, // This makes latest messages stay at bottom
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: _messages.length,
          itemBuilder: (context, index) {
            // Reverse the index since we're using reverse: true
            final reversedIndex = _messages.length - 1 - index;
            final message = _messages[reversedIndex];
            final isMe = _currentUserType == message.senderType;

            // Check if we should show date (compare with next message in original order)
            final showDate = reversedIndex == 0 ||
                !_isSameDay(_messages[reversedIndex - 1].createdAt, message.createdAt);

            return Column(
              key: ValueKey(message.id), // Prevent unnecessary rebuilds
              children: <Widget>[
                // Check if it's an invitation card or regular message
                message.messageType == 'eventInvitation'
                    ? _buildInvitationCard(message)
                    : _MessageBubble(
                        key: ValueKey('bubble_${message.id}'),
                        message: message,
                        isMe: isMe,
                      ),
                // Add small spacing between messages
                const SizedBox(height: 4),
                if (showDate) _buildDateDivider(message.createdAt),
              ],
            );
          },
        ),
        // Floating date chip
        if (_visibleDate != null)
          Positioned(
            top: 12,
            left: 0,
            right: 0,
            child: Center(
              child: AnimatedOpacity(
                opacity: _visibleDate != null ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.yellow.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.12),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    _visibleDate!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
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

    // Check cache first
    if (_globalEventCache.containsKey(eventId)) {
      return _buildInvitationCardWidget(
        _globalEventCache[eventId]!,
        roleId,
        status,
        respondedAt,
        message.id,
      );
    }

    // Fetch event data from the service only if not cached
    return FutureBuilder<Map<String, dynamic>>(
      future: EventService().fetchEvents().then((events) {
        try {
          final eventData = events.firstWhere(
            (e) => (e['_id'] ?? e['id']) == eventId,
            orElse: () => <String, dynamic>{},
          );
          // Cache the result
          if (eventData.isNotEmpty) {
            _globalEventCache[eventId] = eventData;
          }
          return eventData;
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
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Text(AppLocalizations.of(context)!.jobNotFound),
          );
        }

        return _buildInvitationCardWidget(
          snapshot.data!,
          roleId,
          status,
          respondedAt,
          message.id,
        );
      },
    );
  }

  Widget _buildInvitationCardWidget(
    Map<String, dynamic> eventData,
    String roleId,
    String? status,
    DateTime? respondedAt,
    String messageId,
  ) {
    final roles = eventData['roles'] as List<dynamic>? ?? [];
    final role = roles.cast<Map<String, dynamic>>().firstWhere(
      (r) {
        final id = r['_id'] ?? r['role_id'];
        final name = r['role'] ?? r['name'] ?? r['role_name'];
        return id == roleId || name == roleId;
      },
      orElse: () => <String, dynamic>{},
    );

    // If role not found, use roleId as the role name for display
    final eventName = eventData['title'] as String? ?? eventData['shift_name'] as String? ?? 'Event';
    final roleName = role.isNotEmpty
        ? (role['role_name'] as String? ?? role['role'] as String? ?? role['name'] as String? ?? roleId)
        : roleId;
    final clientName = eventData['client_name'] as String? ?? 'Client';
    final venueName = eventData['venue_name'] as String?;
    final rate = role.isNotEmpty
        ? (role['rate'] as num? ?? (role['tariff'] as Map<String, dynamic>?)?['rate'] as num?)
        : null;

    // Parse event date and times
    final dateStr = eventData['start_date'] as String? ?? eventData['date'] as String?;
    final startTimeStr = eventData['start_time'] as String?;
    final endTimeStr = eventData['end_time'] as String?;

    DateTime startDate;
    DateTime endDate;

    if (dateStr != null && startTimeStr != null && startTimeStr.isNotEmpty) {
      // Combine date with start_time (e.g., "2025-10-31" + "09:00")
      final datePart = dateStr.contains('T') ? dateStr.split('T')[0] : dateStr;
      startDate = DateTime.parse('${datePart}T$startTimeStr:00.000Z');
    } else if (dateStr != null) {
      startDate = DateTime.parse(dateStr);
    } else {
      startDate = DateTime.now();
    }

    if (dateStr != null && endTimeStr != null && endTimeStr.isNotEmpty) {
      // Combine date with end_time (e.g., "2025-10-31" + "16:00")
      final datePart = dateStr.contains('T') ? dateStr.split('T')[0] : dateStr;
      endDate = DateTime.parse('${datePart}T$endTimeStr:00.000Z');
    } else if (eventData['end_date'] != null) {
      endDate = DateTime.parse(eventData['end_date'] as String);
    } else {
      endDate = startDate.add(const Duration(hours: 4));
    }

    return Align(
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width > 900 ? 600 : MediaQuery.of(context).size.width * 0.85,
        ),
        child: EventInvitationCard(
          key: ValueKey('invitation_$messageId'),
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
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    final screenWidth = MediaQuery.of(context).size.width;

    return Container(
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
        child: Align(
          alignment: Alignment.center,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: screenWidth > 900 ? 900 : screenWidth,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),  // Increased padding
              child: Row(
                children: <Widget>[
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.add, color: AppColors.techBlue, size: 24),
                      onPressed: _showSendInvitationDialog,
                      tooltip: 'Send Event Invitation',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TextField(
                        controller: _messageController,
                        decoration: InputDecoration(
                          hintText: AppLocalizations.of(context)!.typeMessage,
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,  // Reduced vertical padding
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
                          Color(0xFF00BCD4), // Teal
                          Color(0xFF00838F), // Dark teal
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                          spreadRadius: 0,
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
          ),
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

  // Favorites management
  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _favoriteUsers = prefs.getStringList('favorite_users')?.toSet() ?? {};
    });
  }

  Future<void> _saveFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('favorite_users', _favoriteUsers.toList());
  }

  Future<void> _toggleFavorite(String userId, String role) async {
    final key = '$userId:$role';
    setState(() {
      if (_favoriteUsers.contains(key)) {
        _favoriteUsers.remove(key);
      } else {
        _favoriteUsers.add(key);
      }
    });
    await _saveFavorites();
  }

  bool _isFavorite(String userId, String? role) {
    if (role == null) return false;
    return _favoriteUsers.contains('$userId:$role');
  }

  Future<void> _loadRoles() async {
    try {
      final roles = await _rolesService.fetchRoles();
      setState(() {
        _roles = roles;
      });
    } catch (e) {
      print('[CHAT SCREEN] Error loading roles: $e');
    }
  }

  List<String> get _favoriteRoleOptions {
    final roles = _roles ?? [];
    return roles
        .map((r) => (r['name'] ?? '').toString())
        .where((name) => name.isNotEmpty)
        .toList();
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
  });

  final ChatMessage message;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final maxBubbleWidth = screenWidth > 600 ? 500.0 : screenWidth * 0.75;

    return Align(
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: screenWidth > 900 ? 800 : screenWidth,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
          child: Row(
            mainAxisAlignment:
                isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              // Incoming message avatar
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

              // Message bubble
              Flexible(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxBubbleWidth),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: isMe
                          ? const LinearGradient(
                              colors: [
                                Color(0xFF26C6DA), // Light teal
                                Color(0xFF00BCD4), // Medium teal
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                      color: isMe ? null : Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(20),
                        topRight: const Radius.circular(20),
                        bottomLeft: Radius.circular(isMe ? 20 : 4),
                        bottomRight: Radius.circular(isMe ? 4 : 20),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isMe
                              ? AppColors.tealInfo.withValues(alpha: 0.3)
                              : Colors.black.withValues(alpha: 0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
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
              ),

              if (isMe) const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }
}
