import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../services/chat_event_service.dart';
import '../services/event_service.dart';
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
  final EventService _eventService = EventService();
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
      ),
      body: Column(
        children: [
          // Info banner with AI provider toggle
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                // AI Provider toggle chip
                PopupMenuButton<String>(
                    onSelected: (value) {
                      setState(() {
                        _aiChatService.setAiProvider(value);
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Switched to ${value == 'openai' ? 'OpenAI GPT-4o' : 'Claude Sonnet 4.5'}',
                          ),
                          duration: const Duration(seconds: 2),
                          backgroundColor: value == 'openai' ? Colors.black : Colors.orange,
                        ),
                      );
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'openai',
                        child: Row(
                          children: [
                            Icon(
                              Icons.psychology,
                              size: 18,
                              color: _aiChatService.aiProvider == 'openai'
                                  ? Colors.black
                                  : Colors.grey,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'OpenAI GPT-4o',
                              style: TextStyle(
                                fontWeight: _aiChatService.aiProvider == 'openai'
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                            if (_aiChatService.aiProvider == 'openai')
                              const SizedBox(width: 8),
                            if (_aiChatService.aiProvider == 'openai')
                              const Icon(Icons.check, size: 16, color: Colors.black),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'claude',
                        child: Row(
                          children: [
                            Icon(
                              Icons.hub,
                              size: 18,
                              color: _aiChatService.aiProvider == 'claude'
                                  ? Colors.orange
                                  : Colors.grey,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Claude Sonnet 4.5',
                              style: TextStyle(
                                fontWeight: _aiChatService.aiProvider == 'claude'
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                            if (_aiChatService.aiProvider == 'claude')
                              const SizedBox(width: 8),
                            if (_aiChatService.aiProvider == 'claude')
                              const Icon(Icons.check, size: 16, color: Colors.orange),
                          ],
                        ),
                      ),
                    ],
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: _aiChatService.aiProvider == 'openai'
                            ? Colors.black.withValues(alpha: 0.08)
                            : Colors.orange.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _aiChatService.aiProvider == 'openai'
                              ? Colors.black.withValues(alpha: 0.2)
                              : Colors.orange.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _aiChatService.aiProvider == 'openai'
                                ? Icons.psychology
                                : Icons.hub,
                            size: 14,
                            color: _aiChatService.aiProvider == 'openai'
                                ? Colors.black
                                : Colors.orange.shade700,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _aiChatService.aiProvider == 'openai' ? 'GPT-4o' : 'Sonnet',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _aiChatService.aiProvider == 'openai'
                                  ? Colors.black
                                  : Colors.orange.shade700,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.arrow_drop_down,
                            size: 16,
                            color: _aiChatService.aiProvider == 'openai'
                                ? Colors.black
                                : Colors.orange.shade700,
                          ),
                        ],
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
                        onLinkTap: (linkText) {
                          if (linkText == 'Check Pending') {
                            // Clear conversation and navigate to Pending tab
                            _aiChatService.startNewConversation();
                            Navigator.pop(context, {'action': 'show_pending'});
                          }
                        },
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
                      print('[AIChatScreen] Event complete detected - auto-saving to database...');
                      try {
                        final currentData = Map<String, dynamic>.from(_aiChatService.currentEventData);

                        // Save to database as draft event (new architecture)
                        final eventData = {
                          ...currentData,
                          'status': 'draft', // Mark as draft so it appears in Pending tab
                        };

                        final createdEvent = await _eventService.createEvent(eventData);
                        final eventId = createdEvent['_id'] ?? createdEvent['id'] ?? '';

                        print('[AIChatScreen] ✓ Event saved to database as draft (ID: $eventId)');

                        // Build event summary message
                        final summaryMessage = _buildEventSummary(currentData);

                        // Add summary to chat history using the service method
                        final summaryMsg = ChatMessage(
                          role: 'assistant',
                          content: summaryMessage,
                        );

                        setState(() {
                          _aiChatService.addMessage(summaryMsg);
                        });

                        // Scroll to show summary
                        _scrollToBottom(animated: true);

                        // DON'T clear conversation automatically
                        // Let user read the summary and decide when to leave
                      } catch (e) {
                        print('[AIChatScreen] ✗ Failed to save event to database: $e');
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Failed to save event: $e'),
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

  /// Build a friendly summary of the created event for display in chat
  String _buildEventSummary(Map<String, dynamic> eventData) {
    final buffer = StringBuffer();

    buffer.writeln('✅ Event Created!\n');

    // Event name
    final eventName = eventData['event_name'] ?? 'Unnamed Event';
    buffer.writeln('📋 $eventName');

    // Date
    final date = eventData['date'];
    if (date != null) {
      final formattedDate = _formatDate(date.toString());
      buffer.writeln('📅 $formattedDate');
    }

    // Client
    final client = eventData['client_name'];
    if (client != null) {
      buffer.writeln('🏢 $client');
    }

    // Roles
    final roles = eventData['roles'];
    if (roles is List && roles.isNotEmpty) {
      buffer.writeln('\n👥 Staff Needed:');
      for (final role in roles) {
        if (role is! Map) continue;
        final roleName = role['role']?.toString() ?? 'Staff';
        final count = role['count'] as int? ?? 0;
        final callTime = role['call_time'];
        final timeStr =
            callTime != null ? ' (arrive at ${_formatTime(callTime.toString())})' : '';
        buffer.writeln(
            '  • $count ${_capitalize(roleName)}${count > 1 ? 's' : ''}$timeStr');
      }
    }

    // Venue
    final venueName = eventData['venue_name'];
    final venueAddress = eventData['venue_address'];
    if (venueName != null || venueAddress != null) {
      buffer.writeln('\n📍 Venue:');
      if (venueName != null) {
        buffer.writeln('   $venueName');
      }
      if (venueAddress != null) {
        buffer.writeln('   $venueAddress');
      }
    }

    // Event times (if provided)
    final startTime = eventData['start_time'];
    final endTime = eventData['end_time'];
    if (startTime != null || endTime != null) {
      buffer.write('\n⏰ Event Time: ');
      if (startTime != null) {
        buffer.write(_formatTime(startTime.toString()));
      }
      if (endTime != null) {
        buffer.write(' - ${_formatTime(endTime.toString())}');
      }
      buffer.writeln();
    }

    buffer.writeln('\nSaved to Pending - ready to publish!');
    buffer.writeln('\n[LINK:Check Pending]');

    return buffer.toString();
  }

  /// Format ISO date string to human-readable format
  String _formatDate(String isoDate) {
    try {
      final date = DateTime.parse(isoDate);
      final months = [
        'January',
        'February',
        'March',
        'April',
        'May',
        'June',
        'July',
        'August',
        'September',
        'October',
        'November',
        'December'
      ];
      return '${months[date.month - 1]} ${date.day}, ${date.year}';
    } catch (_) {
      return isoDate;
    }
  }

  /// Format 24-hour time to 12-hour format with AM/PM
  String _formatTime(String time24) {
    try {
      final parts = time24.split(':');
      final hour = int.parse(parts[0]);
      final minute = parts[1];
      final period = hour >= 12 ? 'PM' : 'AM';
      final hour12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
      return '$hour12:$minute $period';
    } catch (_) {
      return time24;
    }
  }

  /// Capitalize first letter of a string
  String _capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }
}
