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
  final bool showAvatar; // Only show avatar on last message of consecutive group

  const AnimatedChatMessageWidget({
    super.key,
    required this.message,
    this.onLinkTap,
    this.userProfilePicture,
    this.showTypingAnimation = false,
    this.onTypingTick,
    this.showAvatar = true,
  });

  @override
  State<AnimatedChatMessageWidget> createState() => _AnimatedChatMessageWidgetState();
}

class _AnimatedChatMessageWidgetState extends State<AnimatedChatMessageWidget>
    with TickerProviderStateMixin {
  /// Strips JSON command blocks from message content for display
  /// These blocks are used by the backend but shouldn't be shown to users
  String _stripJsonBlocks(String content) {
    // Pattern to match command blocks like:
    // EVENT_COMPLETE { ... }
    // TARIFF_CREATE { ... }
    // CLIENT_CREATE { ... }
    // EVENT_UPDATE { ... }
    final commandPattern = RegExp(
      r'\n*(EVENT_COMPLETE|TARIFF_CREATE|CLIENT_CREATE|EVENT_UPDATE)\s*\{[\s\S]*?\}(?:\s*\})*',
      multiLine: true,
    );

    return content.replaceAll(commandPattern, '').trim();
  }

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

  // Reasoning expand/collapse state
  bool _reasoningExpanded = false;

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
    final duration = Duration(milliseconds: kIsWeb ? 12 : 20); // Slower for a more enjoyable reading pace

    _typewriterTimer = Timer.periodic(duration, (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        if (_currentCharIndex < text.length) {
          // Add 1 character at a time for a smooth, readable typing effect
          _displayedText = text.substring(0, _currentCharIndex + 1);
          _currentCharIndex += 1;

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
                if (widget.showAvatar)
                  _buildAiAvatar()
                else
                  const SizedBox(width: 32),
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
                                  AppColors.navySpaceCadet, // Navy blue
                                  AppColors.oceanBlue, // Ocean blue
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
                                ? AppColors.oceanBlue.withValues(alpha: 0.3)
                                : Colors.black.withValues(alpha: 0.08),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: _isTyping
                          ? _buildTypingIndicator()
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (!isUser) _buildReasoningSection(),
                                _buildMessageContent(isUser),
                              ],
                            ),
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
                if (widget.showAvatar)
                  _buildUserAvatar()
                else
                  const SizedBox(width: 32),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReasoningSection() {
    if (widget.message.reasoning == null || widget.message.reasoning!.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => setState(() => _reasoningExpanded = !_reasoningExpanded),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '\u{1F9E0}',
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(width: 4),
                Text(
                  'View reasoning',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  _reasoningExpanded ? Icons.expand_less : Icons.expand_more,
                  size: 16,
                  color: Colors.grey.shade600,
                ),
              ],
            ),
          ),
        ),
        if (_reasoningExpanded) ...[
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Text(
              widget.message.reasoning!,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
                height: 1.4,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
        const SizedBox(height: 8),
      ],
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
    return AnimatedScale(
      scale: _isTyping ? 1.1 : 1.0,
      duration: const Duration(milliseconds: 300),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: _isTyping ? 0.2 : 0.1),
              blurRadius: _isTyping ? 10 : 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipOval(
          child: Image.asset(
            'assets/ai_assistant_logo.png',
            fit: BoxFit.cover,
          ),
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
    // Strip JSON command blocks before displaying
    final rawContent = isUser ? widget.message.content : _displayedText;
    final content = _stripJsonBlocks(rawContent);
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
                      AppColors.navySpaceCadet, // Navy blue
                      AppColors.oceanBlue, // Ocean blue
                      AppColors.oceanBlue, // Ocean blue highlight peak
                      AppColors.oceanBlue, // Ocean blue
                      AppColors.navySpaceCadet, // Navy blue
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
                          AppColors.textDark, // Dark base
                          AppColors.navySpaceCadet, // Navy blue
                          AppColors.oceanBlue, // Ocean blue highlight
                          AppColors.navySpaceCadet, // Navy blue
                          AppColors.textDark, // Dark base
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
                        AppColors.navySpaceCadet, // Navy blue
                        AppColors.oceanBlue, // Ocean blue
                        AppColors.oceanBlue, // Ocean blue highlight peak
                        AppColors.oceanBlue, // Ocean blue
                        AppColors.navySpaceCadet, // Navy blue
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
