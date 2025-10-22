import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../services/chat_event_service.dart';
import '../services/pending_events_service.dart';
import '../widgets/chat_message_widget.dart';
import '../widgets/chat_input_widget.dart';

class AIChatScreen extends StatefulWidget {
  final bool startNewConversation;

  const AIChatScreen({
    super.key,
    this.startNewConversation = false,
  });

  @override
  State<AIChatScreen> createState() => _AIChatScreenState();
}

class _AIChatScreenState extends State<AIChatScreen> {
  final ChatEventService _aiChatService = ChatEventService();
  final PendingEventsService _pendingService = PendingEventsService();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Start new conversation if requested (e.g., from chat section)
    if (widget.startNewConversation) {
      _aiChatService.startNewConversation();
      _loadGreeting();
    } else if (_aiChatService.conversationHistory.isEmpty) {
      // Load greeting if conversation is empty
      _loadGreeting();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadGreeting() async {
    await _aiChatService.getGreeting();
    setState(() {
      // Greeting is already added by getGreeting()
    });
  }

  void _scrollToBottom({bool animated = false}) {
    if (!_scrollController.hasClients) return;

    if (animated) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } else {
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    }
  }

  @override
  Widget build(BuildContext context) {
    final messages = _aiChatService.conversationHistory;
    final currentData = _aiChatService.currentEventData;
    final hasEventData = currentData.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'AI Chat',
          style: TextStyle(
            color: Color(0xFF1F2937),
            fontSize: 24,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF1F2937)),
        actions: [
          // AI Provider toggle - only on web
          if (kIsWeb)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Container(
                decoration: BoxDecoration(
                  color: _aiChatService.aiProvider == 'openai'
                      ? Colors.black
                      : Colors.orange,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () {
                      setState(() {
                        final newProvider = _aiChatService.aiProvider == 'openai'
                            ? 'claude'
                            : 'openai';
                        _aiChatService.setAiProvider(newProvider);
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Using ${_aiChatService.aiProvider == 'openai' ? 'OpenAI' : 'Claude'} AI',
                          ),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Icon(
                        _aiChatService.aiProvider == 'openai'
                            ? Icons.psychology
                            : Icons.hub,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          // Clear conversation button
          if (messages.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Clear chat',
              onPressed: () {
                showDialog<void>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Clear Chat?'),
                    content: const Text(
                      'This will delete the current conversation and any unsaved event data.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          setState(() {
                            _aiChatService.startNewConversation();
                          });
                          _loadGreeting();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Chat cleared'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                        child: const Text(
                          'Clear',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
      body: Column(
        children: [
          // Info banner - conversations not saved (privacy feature)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.08),
              border: Border(
                bottom: BorderSide(
                  color: const Color(0xFF10B981).withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.privacy_tip_outlined,
                  size: 16,
                  color: Color(0xFF059669),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'AI chats aren\'t saved. Only final events are kept.',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF065F46),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Event data banner (if event is being created)
          if (hasEventData)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.event, color: Colors.white, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          currentData['event_name']?.toString() ?? 'Creating event...',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          // Messages list
          Expanded(
            child: messages.isEmpty
                ? const Center(
                    child: CircularProgressIndicator(),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final message = messages[index];
                      return ChatMessageWidget(
                        key: ValueKey('msg-$index'),
                        message: message,
                      );
                    },
                  ),
          ),
          // Loading indicator
          if (_isLoading)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.grey[400],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'AI is thinking...',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          // Input area
          if (messages.isNotEmpty)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: ChatInputWidget(
                key: const ValueKey('chat-input'),
                onSendMessage: (message) async {
                  setState(() {
                    _isLoading = true;
                  });

                  try {
                    await _aiChatService.sendMessage(message);

                    // Auto-save if event is complete
                    if (_aiChatService.eventComplete && _aiChatService.currentEventData.isNotEmpty) {
                      print('[AIChatScreen] Event complete detected - auto-saving...');
                      try {
                        final currentData = Map<String, dynamic>.from(_aiChatService.currentEventData);
                        await _pendingService.saveDraft(currentData);

                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Event saved to Pending!'),
                              backgroundColor: Color(0xFF059669),
                              duration: Duration(seconds: 2),
                            ),
                          );

                          // Clear conversation after auto-save
                          setState(() {
                            _aiChatService.startNewConversation();
                          });
                          _loadGreeting();
                        }

                        print('[AIChatScreen] ✓ Event auto-saved successfully');
                      } catch (e) {
                        print('[AIChatScreen] ✗ Failed to auto-save event: $e');
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Failed to save: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    }

                    // Scroll to bottom after message
                    _scrollToBottom(animated: true);
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: ${e.toString()}'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  } finally {
                    if (mounted) {
                      setState(() {
                        _isLoading = false;
                      });
                    }
                  }
                },
                isLoading: _isLoading,
              ),
            ),
        ],
      ),
    );
  }
}
