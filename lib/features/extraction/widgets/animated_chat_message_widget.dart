import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../services/chat_event_service.dart';
import 'package:nexa/shared/presentation/theme/app_colors.dart';

/// Animated widget to display a single chat message bubble with typing effects
class AnimatedChatMessageWidget extends StatefulWidget {
  final ChatMessage message;
  final String? userProfilePicture;
  final void Function(String)? onLinkTap;
  final bool showTypingAnimation;
  final VoidCallback? onTypingTick; // Callback when typing animation updates

  const AnimatedChatMessageWidget({
    super.key,
    required this.message,
    this.onLinkTap,
    this.userProfilePicture,
    this.showTypingAnimation = false,
    this.onTypingTick,
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
  late AnimationController _shimmerController;

  // Animations
  late Animation<double> _fadeInAnimation;
  late Animation<Offset> _slideInAnimation;
  late Animation<double> _shimmerAnimation;

  // Typewriter effect
  String _displayedText = '';
  Timer? _typewriterTimer;
  int _currentCharIndex = 0;

  // Typing indicator
  bool _isTyping = false;

  // Shimmer effect for typing animation
  bool _showShimmer = false;

  // Track if animation has already played
  static final Set<String> _animatedMessages = {};
  bool _hasAnimated = false;

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

    // Initialize shimmer animation for typing highlight
    _shimmerController = AnimationController(
      duration: Duration(milliseconds: kIsWeb ? 1000 : 1500), // Faster on web to sync with typing
      vsync: this,
    )..repeat();
    _shimmerAnimation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.linear),
    );

    // Start animations
    _startAnimations();
  }

  void _startAnimations() {
    final isUser = widget.message.role == 'user';
    // Use content hash as stable identifier (timestamp may change on rebuild)
    final messageId = '${widget.message.role}-${widget.message.content.hashCode}';

    // Check if this message has already been animated
    if (_animatedMessages.contains(messageId)) {
      _hasAnimated = true;
      _displayedText = widget.message.content; // Show full text immediately
      _fadeInController.value = 1.0; // Skip fade animation
      _slideInController.value = 1.0; // Skip slide animation
      return;
    }

    // Mark as animated AFTER first frame to avoid premature tracking (staff app pattern)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _animatedMessages.add(messageId);
    });
    _hasAnimated = true;

    // Start fade and slide animations
    _fadeInController.forward();
    _slideInController.forward();

    // For AI messages, show typing indicator first, then typewriter effect
    if (!isUser && widget.showTypingAnimation) {
      _isTyping = true;

      // Show typing indicator for shorter time (FASTER on web)
      final baseDelay = kIsWeb ? 200 : 400; // Faster base delay on web
      Future.delayed(Duration(milliseconds: baseDelay + (widget.message.content.length).clamp(0, 600)), () { // Was 800-2000ms
        if (mounted) {
          setState(() {
            _isTyping = false;
            _showShimmer = true; // Start shimmer effect
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
    final duration = Duration(milliseconds: kIsWeb ? 4 : 8); // 2x faster on web to compensate for browser overhead

    _typewriterTimer = Timer.periodic(duration, (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        if (_currentCharIndex < text.length) {
          // Add 2 characters at a time for even faster, smoother effect
          final charsToAdd = (_currentCharIndex + 2 <= text.length) ? 2 : 1;
          _displayedText = text.substring(0, _currentCharIndex + charsToAdd);
          _currentCharIndex += charsToAdd;

          // Notify parent to scroll to bottom
          widget.onTypingTick?.call();
        } else {
          timer.cancel();
          _showShimmer = false; // Stop shimmer when done
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
    _shimmerController.dispose();
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
                                  AppColors.yellow,
                                  AppColors.techBlue,
                                  AppColors.indigoPurple,
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
                                ? AppColors.yellow.withValues(alpha: 0.3)
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
                      color: AppColors.techBlue,
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
            ? [const Color(0xFF26C6DA), const Color(0xFF00838F)]
            : [AppColors.tealInfo, AppColors.oceanBlue],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.tealInfo.withValues(alpha: _isTyping ? 0.5 : 0.3),
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
        color: AppColors.techBlue,
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
      final textWidget = MarkdownBody(
        data: content,
        styleSheet: MarkdownStyleSheet(
          p: TextStyle(
            color: isUser ? Colors.white : AppColors.textDark,
            fontSize: 15,
            height: 1.4,
          ),
          strong: TextStyle(
            color: isUser ? Colors.white : AppColors.textDark,
            fontSize: 15,
            height: 1.4,
            fontWeight: FontWeight.bold,
          ),
          em: TextStyle(
            color: isUser ? Colors.white : AppColors.textDark,
            fontSize: 15,
            height: 1.4,
            fontStyle: FontStyle.italic,
          ),
          listBullet: TextStyle(
            color: isUser ? Colors.white : AppColors.textDark,
          ),
        ),
      );

      // Apply sophisticated multi-color shimmer with glow during AI typing
      if (!isUser && _showShimmer) {
        return AnimatedBuilder(
          animation: _shimmerAnimation,
          builder: (context, child) {
            // Use simpler, web-compatible shimmer on web browsers
            if (kIsWeb) {
              return ShaderMask(
                blendMode: BlendMode.srcIn, // Web-compatible blend mode
                shaderCallback: (bounds) {
                  return LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    stops: [
                      (_shimmerAnimation.value - 0.5).clamp(0.0, 1.0),
                      (_shimmerAnimation.value - 0.3).clamp(0.0, 1.0),
                      (_shimmerAnimation.value - 0.1).clamp(0.0, 1.0),
                      _shimmerAnimation.value.clamp(0.0, 1.0),
                      (_shimmerAnimation.value + 0.1).clamp(0.0, 1.0),
                      (_shimmerAnimation.value + 0.3).clamp(0.0, 1.0),
                      (_shimmerAnimation.value + 0.5).clamp(0.0, 1.0),
                    ],
                    colors: const [
                      AppColors.textDark, // Dark base
                      AppColors.techBlue, // Indigo
                      AppColors.yellow, // Purple
                      AppColors.pink, // Pink highlight peak
                      AppColors.yellow, // Purple
                      AppColors.techBlue, // Indigo
                      AppColors.textDark, // Dark base
                    ],
                  ).createShader(bounds);
                },
                child: child,
              );
            }

            // Mobile: Use fancy multi-layer shimmer with glow
            return Stack(
              children: [
                // Glow layer behind text
                Opacity(
                  opacity: 0.6,
                  child: ShaderMask(
                    blendMode: BlendMode.srcATop,
                    shaderCallback: (bounds) {
                      return LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        stops: [
                          (_shimmerAnimation.value - 0.4).clamp(0.0, 1.0),
                          (_shimmerAnimation.value - 0.2).clamp(0.0, 1.0),
                          _shimmerAnimation.value.clamp(0.0, 1.0),
                          (_shimmerAnimation.value + 0.2).clamp(0.0, 1.0),
                          (_shimmerAnimation.value + 0.4).clamp(0.0, 1.0),
                        ],
                        colors: const [
                          AppColors.textDark,
                          AppColors.yellow, // Soft violet
                          Color(0xFFC084FC), // Bright purple
                          AppColors.yellow, // Soft violet
                          AppColors.textDark,
                        ],
                      ).createShader(bounds);
                    },
                    child: child,
                  ),
                ),
                // Main text with shimmer
                ShaderMask(
                  blendMode: BlendMode.srcATop,
                  shaderCallback: (bounds) {
                    return LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      stops: [
                        (_shimmerAnimation.value - 0.5).clamp(0.0, 1.0),
                        (_shimmerAnimation.value - 0.3).clamp(0.0, 1.0),
                        (_shimmerAnimation.value - 0.1).clamp(0.0, 1.0),
                        _shimmerAnimation.value.clamp(0.0, 1.0),
                        (_shimmerAnimation.value + 0.1).clamp(0.0, 1.0),
                        (_shimmerAnimation.value + 0.3).clamp(0.0, 1.0),
                        (_shimmerAnimation.value + 0.5).clamp(0.0, 1.0),
                      ],
                      colors: const [
                        AppColors.textDark, // Dark base
                        AppColors.techBlue, // Indigo
                        AppColors.yellow, // Purple
                        AppColors.pink, // Pink highlight peak
                        AppColors.yellow, // Purple
                        AppColors.techBlue, // Indigo
                        AppColors.textDark, // Dark base
                      ],
                    ).createShader(bounds);
                  },
                  child: child,
                ),
              ],
            );
          },
          child: textWidget,
        );
      }

      return textWidget;
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
              color: isUser ? Colors.white : AppColors.textDark,
              fontSize: 15,
              height: 1.4,
            ),
          ),
        GestureDetector(
          onTap: () => widget.onLinkTap?.call(linkText),
          child: Text(
            linkText,
            style: TextStyle(
              color: isUser ? Colors.white : AppColors.techBlue,
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
              color: isUser ? Colors.white : AppColors.textDark,
              fontSize: 15,
              height: 1.4,
            ),
          ),
      ],
    );
  }
}
