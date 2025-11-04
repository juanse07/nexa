import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/chat_event_service.dart';

/// Widget to display a single chat message bubble
class ChatMessageWidget extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';
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
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.asset(
                  'assets/logo_padded_small.png',
                  fit: BoxFit.cover,
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
                              Color(0xFF7C3AED), // Light purple
                              Color(0xFF6366F1), // Medium purple
                              Color(0xFF4F46E5), // Darker purple
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
                  child: _buildMessageContent(isUser),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      timeFormat.format(message.timestamp),
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 11,
                      ),
                    ),
                    // Show AI provider badge for assistant messages
                    if (!isUser && message.provider != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: message.provider == AIProvider.claude
                              ? Colors.orange.shade100
                              : message.provider == AIProvider.groq
                                  ? Colors.yellow.shade100
                                  : Colors.blue.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          message.provider == AIProvider.claude
                              ? 'Claude'
                              : message.provider == AIProvider.groq
                                  ? 'Valerio'
                                  : 'GPT-4',
                          style: TextStyle(
                            color: message.provider == AIProvider.claude
                                ? Colors.orange.shade900
                                : message.provider == AIProvider.groq
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
                color: const Color(0xFF6366F1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: userProfilePicture != null && userProfilePicture!.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(
                        userProfilePicture!,
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
    final content = message.content;
    final linkPattern = RegExp(r'\[LINK:([^\]]+)\]');
    final match = linkPattern.firstMatch(content);

    // If no link found, return simple text
    if (match == null) {
      return Text(
        content,
        style: TextStyle(
          color: isUser ? Colors.white : const Color(0xFF0F172A),
          fontSize: 15,
          height: 1.4,
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
              color: isUser ? Colors.white : const Color(0xFF0F172A),
              fontSize: 15,
              height: 1.4,
            ),
          ),
        // Clickable link
        GestureDetector(
          onTap: () => onLinkTap?.call(linkText),
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
        // Text after link
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
