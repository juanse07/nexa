import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../services/chat_event_service.dart';

/// Animated widget to display a single chat message bubble with typing effects
class AnimatedChatMessageWidget extends StatefulWidget {
  final ChatMessage message;
  final String? userProfilePicture;
  final void Function(String)? onLinkTap;
  final bool showTypingAnimation;

  const AnimatedChatMessageWidget({
    super.key,
    required this.message,
    this.onLinkTap,
    this.userProfilePicture,
    this.showTypingAnimation = false,
  });

  @override
  State<AnimatedChatMessageWidget> createState() => _AnimatedChatMessageWidgetState();
}

class _AnimatedChatMessageWidgetState extends State<AnimatedChatMessageWidget>
    with TickerProviderStateMixin {
  // Animation controllers
  late AnimationController _fadeInController;
  late AnimationController _slideInController;
  late AnimationController _typewriterController;
  late AnimationController _typingDotsController;

  // Animations
  late Animation<double> _fadeInAnimation;
  late Animation<Offset> _slideInAnimation;

  // Typewriter effect
  String _displayedText = '';
  Timer? _typewriterTimer;
  int _currentCharIndex = 0;

  // Typing indicator
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();

    // Initialize fade in animation (FASTER)
    _fadeInController = AnimationController(
      duration: const Duration(milliseconds: 250), // Was 500ms
      vsync: this,
    );
    _fadeInAnimation = CurvedAnimation(
      parent: _fadeInController,
      curve: Curves.easeOut,
    );

    // Initialize slide in animation (FASTER)
    _slideInController = AnimationController(
      duration: const Duration(milliseconds: 200), // Was 400ms
      vsync: this,
    );
    _slideInAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.2), // Reduced slide distance
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideInController,
      curve: Curves.easeOutQuart,
    ));

    // Initialize typewriter animation for AI responses
    _typewriterController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    // Initialize typing dots animation (FASTER)
    _typingDotsController = AnimationController(
      duration: const Duration(milliseconds: 600), // Was 1 second
      vsync: this,
    )..repeat();

    // Start animations
    _startAnimations();
  }

  void _startAnimations() {
    final isUser = widget.message.role == 'user';

    // Start fade and slide animations
    _fadeInController.forward();
    _slideInController.forward();

    // For AI messages, show typing indicator first, then typewriter effect
    if (!isUser && widget.showTypingAnimation) {
      _isTyping = true;

      // Show typing indicator for shorter time (FASTER)
      Future.delayed(Duration(milliseconds: 400 + (widget.message.content.length).clamp(0, 600)), () { // Was 800-2000ms
        if (mounted) {
          setState(() {
            _isTyping = false;
          });
          _startTypewriterEffect();
        }
      });
    } else if (!isUser) {
      // For AI messages without typing animation, just show the full text
      _displayedText = widget.message.content;
    } else {
      // For user messages, show full text immediately
      _displayedText = widget.message.content;
    }
  }

  void _startTypewriterEffect() {
    final text = widget.message.content;
    final duration = Duration(milliseconds: 30); // Speed of typing

    _typewriterTimer = Timer.periodic(duration, (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        if (_currentCharIndex < text.length) {
          _displayedText = text.substring(0, _currentCharIndex + 1);
          _currentCharIndex++;
        } else {
          timer.cancel();
          _typewriterController.forward();
        }
      });
    });
  }

  @override
  void dispose() {
    _fadeInController.dispose();
    _slideInController.dispose();
    _typewriterController.dispose();
    _typingDotsController.dispose();
    _typewriterTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isUser = widget.message.role == 'user';
    final timeFormat = DateFormat('HH:mm');

    return FadeTransition(
      opacity: _fadeInAnimation,
      child: SlideTransition(
        position: _slideInAnimation,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment:
                isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isUser) ...[
                _buildAiAvatar(),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Column(
                  crossAxisAlignment:
                      isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: isUser
                            ? const LinearGradient(
                                colors: [
                                  Color(0xFF7C3AED),
                                  Color(0xFF6366F1),
                                  Color(0xFF4F46E5),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : null,
                        color: isUser ? null : Colors.white,
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(16),
                          topRight: const Radius.circular(16),
                          bottomLeft: Radius.circular(isUser ? 16 : 4),
                          bottomRight: Radius.circular(isUser ? 4 : 16),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: isUser
                                ? const Color(0xFF7C3AED).withValues(alpha: 0.3)
                                : Colors.black.withValues(alpha: 0.08),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: _isTyping
                          ? _buildTypingIndicator()
                          : _buildMessageContent(isUser),
                    ),
                    if (!_isTyping) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            timeFormat.format(widget.message.timestamp),
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 11,
                            ),
                          ),
                          if (!isUser && widget.message.provider != null) ...[
                            const SizedBox(width: 6),
                            _buildProviderBadge(),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (isUser) ...[
                const SizedBox(width: 8),
                _buildUserAvatar(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return SizedBox(
      width: 50,
      height: 20,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(3, (index) {
          return AnimatedBuilder(
            animation: _typingDotsController,
            builder: (context, child) {
              final double value = _typingDotsController.value;
              final double delay = index * 0.2;
              final double adjustedValue = (value - delay) % 1.0;

              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                child: Transform.translate(
                  offset: Offset(
                    0,
                    -4 * (adjustedValue < 0.5
                      ? adjustedValue * 2
                      : 2 - adjustedValue * 2),
                  ),
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              );
            },
          );
        }),
      ),
    );
  }

  Widget _buildAiAvatar() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _isTyping
            ? [const Color(0xFF9061FC), const Color(0xFF7343E9)]
            : [const Color(0xFF7A3AFB), const Color(0xFF5B27D8)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7A3AFB).withValues(alpha: _isTyping ? 0.5 : 0.3),
            blurRadius: _isTyping ? 10 : 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            // AI icon (simplified for animation performance)
            AnimatedScale(
              scale: _isTyping ? 1.1 : 1.0,
              duration: const Duration(milliseconds: 300),
              child: const Icon(
                Icons.auto_awesome,
                color: Colors.white,
                size: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserAvatar() {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: const Color(0xFF6366F1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: widget.userProfilePicture != null && widget.userProfilePicture!.isNotEmpty
          ? ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                widget.userProfilePicture!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(
                    Icons.person,
                    size: 20,
                    color: Colors.white,
                  );
                },
              ),
            )
          : const Icon(
              Icons.person,
              size: 20,
              color: Colors.white,
            ),
    );
  }

  Widget _buildProviderBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 6,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: widget.message.provider == AIProvider.claude
            ? Colors.orange.shade100
            : widget.message.provider == AIProvider.groq
                ? Colors.yellow.shade100
                : Colors.blue.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        widget.message.provider == AIProvider.claude
            ? 'Claude'
            : widget.message.provider == AIProvider.groq
                ? 'Valerio'
                : 'GPT-4',
        style: TextStyle(
          color: widget.message.provider == AIProvider.claude
              ? Colors.orange.shade900
              : widget.message.provider == AIProvider.groq
                  ? Colors.yellow.shade900
                  : Colors.blue.shade900,
          fontSize: 9,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildMessageContent(bool isUser) {
    // For typewriter effect, show the displayed text instead of full content
    final content = isUser ? widget.message.content : _displayedText;
    final linkPattern = RegExp(r'\[LINK:([^\]]+)\]');
    final match = linkPattern.firstMatch(content);

    if (match == null) {
      // Use MarkdownBody to render markdown formatting
      return MarkdownBody(
        data: content,
        styleSheet: MarkdownStyleSheet(
          p: TextStyle(
            color: isUser ? Colors.white : const Color(0xFF0F172A),
            fontSize: 15,
            height: 1.4,
          ),
          strong: TextStyle(
            color: isUser ? Colors.white : const Color(0xFF0F172A),
            fontSize: 15,
            height: 1.4,
            fontWeight: FontWeight.bold,
          ),
          em: TextStyle(
            color: isUser ? Colors.white : const Color(0xFF0F172A),
            fontSize: 15,
            height: 1.4,
            fontStyle: FontStyle.italic,
          ),
          listBullet: TextStyle(
            color: isUser ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
      );
    }

    // Handle links (same as original)
    final beforeLink = content.substring(0, match.start);
    final linkText = match.group(1)!;
    final afterLink = content.substring(match.end);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (beforeLink.isNotEmpty)
          Text(
            beforeLink,
            style: TextStyle(
              color: isUser ? Colors.white : const Color(0xFF0F172A),
              fontSize: 15,
              height: 1.4,
            ),
          ),
        GestureDetector(
          onTap: () => widget.onLinkTap?.call(linkText),
          child: Text(
            linkText,
            style: TextStyle(
              color: isUser ? Colors.white : const Color(0xFF3B82F6),
              fontSize: 15,
              height: 1.4,
              decoration: TextDecoration.underline,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (afterLink.isNotEmpty)
          Text(
            afterLink,
            style: TextStyle(
              color: isUser ? Colors.white : const Color(0xFF0F172A),
              fontSize: 15,
              height: 1.4,
            ),
          ),
      ],
    );
  }
}