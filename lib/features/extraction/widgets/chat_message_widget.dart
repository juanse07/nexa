import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../services/chat_event_service.dart';
import 'package:nexa/shared/presentation/theme/app_colors.dart';

/// Widget to display a single chat message bubble
class ChatMessageWidget extends StatefulWidget {
  final ChatMessage message;
  final String? userProfilePicture;
  final void Function(String)? onLinkTap;

  const ChatMessageWidget({
    super.key,
    required this.message,
    this.onLinkTap,
    this.userProfilePicture,
  });

  @override
  State<ChatMessageWidget> createState() => _ChatMessageWidgetState();
}

class _ChatMessageWidgetState extends State<ChatMessageWidget> {
  bool _reasoningExpanded = false;

  /// Strips JSON command blocks from message content for display
  /// These blocks are used by the backend but shouldn't be shown to users
  String _stripJsonBlocks(String content) {
    final commandPattern = RegExp(
      r'\n*(EVENT_COMPLETE|TARIFF_CREATE|CLIENT_CREATE|EVENT_UPDATE)\s*\{[\s\S]*?\}(?:\s*\})*',
      multiLine: true,
    );

    return content.replaceAll(commandPattern, '').trim();
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
                  'View thinking',
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

  @override
  Widget build(BuildContext context) {
    final isUser = widget.message.role == 'user';
    final timeFormat = DateFormat('HH:mm');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.tealInfo, AppColors.oceanBlue],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.tealInfo.withOpacity(0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Colors.white.withOpacity(0.4),
                          width: 1,
                        ),
                        shape: BoxShape.circle,
                      ),
                    ),
                    Transform.rotate(
                      angle: 0.785398,
                      child: Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 1,
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      top: 6,
                      child: Container(
                        width: 0.8,
                        height: 3.5,
                        color: Colors.white.withOpacity(0.6),
                      ),
                    ),
                    Positioned(
                      bottom: 6,
                      child: Container(
                        width: 0.8,
                        height: 3.5,
                        color: Colors.white.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ),
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
                              AppColors.navySpaceCadet,
                              AppColors.oceanBlue,
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!isUser) _buildReasoningSection(),
                      _buildMessageContent(isUser),
                    ],
                  ),
                ),
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
                      Container(
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
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            Container(
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
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
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
            ),
          ],
        ],
      ),
    );
  }

  /// Build message content with support for clickable links
  Widget _buildMessageContent(bool isUser) {
    // Strip JSON command blocks before displaying
    final content = _stripJsonBlocks(widget.message.content);
    final linkPattern = RegExp(r'\[LINK:([^\]]+)\]');
    final match = linkPattern.firstMatch(content);

    // If no link found, return markdown-rendered text
    if (match == null) {
      return MarkdownBody(
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
    }

    // Split content into parts: before link, link text, after link
    final beforeLink = content.substring(0, match.start);
    final linkText = match.group(1)!;
    final afterLink = content.substring(match.end);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Text before link
        if (beforeLink.isNotEmpty)
          Text(
            beforeLink,
            style: TextStyle(
              color: isUser ? Colors.white : AppColors.textDark,
              fontSize: 15,
              height: 1.4,
            ),
          ),
        // Clickable link
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
        // Text after link
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
