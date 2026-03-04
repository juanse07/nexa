import 'dart:async';
import 'dart:convert';
import 'dart:math' show max;

import 'package:flutter/material.dart';
import 'package:nexa/core/config/app_config.dart';
import 'package:nexa/features/auth/data/services/auth_service.dart';
import 'package:nexa/shared/presentation/theme/app_colors.dart';

/// Lightweight bottom sheet for per-event AI chat with Valerio.
/// Opens instantly with a status-aware greeting — no extraction flow.
class EventQuickChatSheet extends StatefulWidget {
  final Map<String, dynamic> event;

  const EventQuickChatSheet({super.key, required this.event});

  @override
  State<EventQuickChatSheet> createState() => _EventQuickChatSheetState();
}

class _EventQuickChatSheetState extends State<EventQuickChatSheet> {
  final List<({String role, String content})> _messages = [];
  bool _loading = true; // starts true — analysis fires immediately
  final _ctrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // Scroll to bottom when keyboard opens so the last message stays visible.
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) _scrollToBottom();
    });
    // Kick off AI analysis after first frame so the sheet renders with the
    // typing indicator before the network call starts.
    WidgetsBinding.instance.addPostFrameCallback((_) => _analyzeEvent());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scrollCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // ── Auto-analysis on open ────────────────────────────────────────────────────

  Future<void> _analyzeEvent() async {
    // The trigger prompt is sent to the API but NOT added to _messages,
    // so the chat thread opens with the AI's analysis as a natural first message.
    final triggerPrompt =
        'Analyze this event. Identify any missing or incomplete information '
        '(venue, time, roles, pay rate, notes, etc.) and list the actions I '
        'should take next based on its current status. '
        'Be concise — 2–4 bullet points, no fluff.';

    try {
      final apiMessages = [
        {'role': 'system', 'content': _systemPrompt()},
        {'role': 'user', 'content': triggerPrompt},
      ];

      final uri = Uri.parse('${AppConfig.instance.baseUrl}/ai/chat/message');
      final response = await AuthService.httpClient
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'messages': apiMessages,
              'temperature': 0.6,
              'maxTokens': 350,
              'provider': 'groq',
            }),
          )
          .timeout(const Duration(seconds: 90));

      if (!mounted) return;

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final reply = decoded['content'] as String? ?? _openingGreeting();

      setState(() {
        _messages.add((role: 'assistant', content: reply));
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      // Fall back to the static local greeting so the sheet is never blank.
      setState(() {
        _messages.add((role: 'assistant', content: _openingGreeting()));
        _loading = false;
      });
    }
    _scrollToBottom();
  }

  // ── Fallback greeting (used if analysis API call fails) ───────────────────────

  String _openingGreeting() {
    final status = widget.event['status'] as String? ?? 'draft';
    final name = widget.event['client_name'] as String? ?? 'this event';
    final accepted = (widget.event['accepted_staff'] as List?)?.length ?? 0;
    final total = (widget.event['roles'] as List?)
            ?.fold<int>(0, (s, r) => s + ((r['count'] as int?) ?? 0)) ??
        0;

    return switch (status) {
      'draft' =>
        'Hi! **$name** is still a pending draft — not visible to staff yet. Want to complete it or publish it?',
      'published' =>
        'Hi! **$name** is posted. $accepted of $total spots are filled. Anything you need?',
      'fulfilled' =>
        '**$name** is fully staffed ($accepted/$total) — great! How can I help?',
      'confirmed' =>
        '**$name** is confirmed and fully staffed. What do you need?',
      'in_progress' => '**$name** is happening right now. How can I assist?',
      'completed' =>
        '**$name** is completed. Need a summary or attendance help?',
      'cancelled' => '**$name** is cancelled. What can I help with?',
      _ => 'Hi! How can I help with **$name**?',
    };
  }

  // ── System prompt ────────────────────────────────────────────────────────────

  String _systemPrompt() {
    final e = widget.event;
    final status = e['status'] as String? ?? 'draft';
    final roles = (e['roles'] as List?)
            ?.map((r) => '${r['role']} x${r['count']}')
            .join(', ') ??
        'none';
    final accepted = (e['accepted_staff'] as List?)?.length ?? 0;
    final total = (e['roles'] as List?)
            ?.fold<int>(0, (s, r) => s + ((r['count'] as int?) ?? 0)) ??
        0;
    final notes = e['notes'] as String? ?? '';

    return '''You are Valerio, a concise AI assistant for FlowShift staffing managers.
You are helping with this specific event:
- Client: ${e['client_name'] ?? 'Unknown'}
- Date: ${e['date'] ?? 'Not set'}
- Time: ${e['start_time'] ?? '?'} – ${e['end_time'] ?? '?'}
- Venue: ${e['venue_name'] ?? e['venue_address'] ?? 'Not set'}
- Roles: $roles
- Staffing: $accepted/$total filled
- Status: $status (${_statusDescription(status)})${notes.isNotEmpty ? '\n- Notes: $notes' : ''}

Be brief and practical. Only answer based on information provided. Suggest relevant next steps.''';
  }

  String _statusDescription(String status) => switch (status) {
        'draft' => 'draft, not visible to staff',
        'published' => 'posted, staff can apply',
        'fulfilled' => 'all spots filled',
        'confirmed' => 'confirmed and fully staffed',
        'in_progress' => 'event is currently running',
        'completed' => 'event finished',
        'cancelled' => 'event cancelled',
        _ => status,
      };

  // ── Date / time helpers ───────────────────────────────────────────────────────

  String _formatDate(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    try {
      final dt = DateTime.parse(raw).toLocal();
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      final dow = days[dt.weekday - 1];
      return '$dow, ${months[dt.month - 1]} ${dt.day}';
    } catch (_) {
      return raw;
    }
  }

  String _formatTime(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    // Already formatted like "9:00 AM" — pass through.
    // Handle "HH:mm" 24h format → convert to 12h.
    final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(raw);
    if (match != null) {
      var h = int.parse(match.group(1)!);
      final m = match.group(2)!;
      final period = h >= 12 ? 'PM' : 'AM';
      if (h == 0) h = 12;
      if (h > 12) h -= 12;
      return '$h:$m $period';
    }
    return raw;
  }

  // ── Send message ─────────────────────────────────────────────────────────────

  Future<void> _sendMessage() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _loading) return;

    setState(() {
      _messages.add((role: 'user', content: text));
      _loading = true;
    });
    _ctrl.clear();
    _scrollToBottom();

    try {
      final apiMessages = [
        {'role': 'system', 'content': _systemPrompt()},
        ..._messages.map((m) => {'role': m.role, 'content': m.content}),
      ];

      final uri = Uri.parse('${AppConfig.instance.baseUrl}/ai/chat/message');
      final response = await AuthService.httpClient
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'messages': apiMessages,
              'temperature': 0.7,
              'maxTokens': 400,
              'provider': 'groq',
            }),
          )
          .timeout(const Duration(seconds: 90));

      if (!mounted) return;

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final reply =
          decoded['content'] as String? ?? 'Sorry, I had trouble responding.';

      setState(() {
        _messages.add((role: 'assistant', content: reply));
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add((
          role: 'assistant',
          content: 'Sorry, something went wrong. Please try again.',
        ));
        _loading = false;
      });
    }

    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── Status chip ──────────────────────────────────────────────────────────────

  ({String label, Color color}) _statusChip(String? status) => switch (status) {
        'draft' => (label: 'PENDING', color: AppColors.navySpaceCadet),
        'published' => (label: 'POSTED', color: AppColors.techBlue),
        'fulfilled' => (label: 'FULL', color: AppColors.success),
        'confirmed' => (label: 'FULL', color: AppColors.success),
        'in_progress' => (label: 'IN PROGRESS', color: AppColors.warning),
        'completed' => (label: 'COMPLETED', color: Colors.grey),
        'cancelled' => (label: 'CANCELLED', color: AppColors.errorDark),
        _ => (label: 'PENDING', color: AppColors.navySpaceCadet),
      };

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final keyboardHeight = mq.viewInsets.bottom;
    // Input bar only needs the home-indicator safe area — the sheet itself
    // is lifted above the keyboard by AnimatedPadding below.
    final safeAreaBottom = mq.padding.bottom;

    final e = widget.event;
    final status = e['status'] as String? ?? 'draft';
    final chip = _statusChip(status);
    final clientName = e['client_name'] as String? ?? 'Event';
    final dateStr = _formatDate(e['date'] as String?);
    final startTime = _formatTime(e['start_time'] as String?);
    final endTime = _formatTime(e['end_time'] as String?);
    final timeStr = [startTime, endTime].where((s) => s.isNotEmpty).join(' – ');
    final venueName = (e['venue_name'] as String? ?? '').trim();
    final venueAddress = (e['venue_address'] as String? ?? '').trim();
    final venueDisplay = venueName.isNotEmpty ? venueName : venueAddress;
    final accepted = (e['accepted_staff'] as List?)?.length ?? 0;
    final total = (e['roles'] as List?)
            ?.fold<int>(0, (s, r) => s + ((r['count'] as int?) ?? 0)) ??
        0;
    final rolesList = (e['roles'] as List?)
            ?.map((r) {
              final name = (r['role'] as String? ?? 'Staff');
              final count = r['count'] as int? ?? 1;
              return '$count $name';
            })
            .join(' · ') ??
        '';
    final notes = (e['notes'] as String? ?? '').trim();

    return AnimatedPadding(
      // Lifts the entire sheet above the keyboard as it slides in.
      padding: EdgeInsets.only(bottom: keyboardHeight),
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      child: DraggableScrollableSheet(
        initialChildSize: 0.72,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        expand: false,
        builder: (sheetCtx, sheetScrollCtrl) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // ── Drag handle ─────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 4),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // ── Header row ──────────────────────────────────────────────────
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Row(
                  children: [
                    Image.asset(
                      'assets/ai_assistant_logo.png',
                      width: 28,
                      height: 28,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Valerio',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: chip.color,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        chip.label,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => Navigator.of(sheetCtx).pop(),
                      child: const Icon(Icons.close,
                          size: 22, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),

              // ── Event info block — collapses when keyboard is open ───────────
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                clipBehavior: Clip.hardEdge,
                child: keyboardHeight > 0
                    ? const SizedBox.shrink()
                    : Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 2),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceLight,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.borderLight),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                clientName,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textDark,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 5),
                              if (dateStr.isNotEmpty || timeStr.isNotEmpty)
                                _InfoRow(
                                  icon: Icons.calendar_today_outlined,
                                  text: [dateStr, timeStr]
                                      .where((s) => s.isNotEmpty)
                                      .join('  ·  '),
                                ),
                              if (venueDisplay.isNotEmpty)
                                _InfoRow(
                                  icon: Icons.location_on_outlined,
                                  text: venueDisplay,
                                ),
                              if (rolesList.isNotEmpty)
                                _InfoRow(
                                  icon: Icons.people_outline,
                                  text: '$rolesList   ($accepted/$total filled)',
                                ),
                              if (notes.isNotEmpty)
                                _InfoRow(
                                  icon: Icons.notes_outlined,
                                  text: notes,
                                  maxLines: 2,
                                ),
                            ],
                          ),
                        ),
                      ),
              ),

              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                child: keyboardHeight > 0
                    ? const SizedBox.shrink()
                    : Divider(
                        height: 14,
                        thickness: 1,
                        color: Colors.grey.shade200,
                        indent: 16,
                        endIndent: 16,
                      ),
              ),

              // ── Message list ─────────────────────────────────────────────────
              Expanded(
                child: ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  itemCount: _messages.length + (_loading ? 1 : 0),
                  itemBuilder: (context, i) {
                    if (i == _messages.length) {
                      return const Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 6),
                          child: _TypingIndicator(),
                        ),
                      );
                    }
                    final msg = _messages[i];
                    return _MessageBubble(
                        content: msg.content, isUser: msg.role == 'user');
                  },
                ),
              ),

              // ── Input row — home indicator safe area only (keyboard handled above) ──
              Container(
                padding: EdgeInsets.fromLTRB(12, 8, 12, 8 + safeAreaBottom),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    top: BorderSide(color: Colors.grey.shade200),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _ctrl,
                        focusNode: _focusNode,
                        textCapitalization: TextCapitalization.sentences,
                        minLines: 1,
                        maxLines: 4,
                        decoration: InputDecoration(
                          hintText: 'Type a message...',
                          hintStyle: TextStyle(color: Colors.grey.shade400),
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _loading ? null : _sendMessage,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: _loading
                              ? Colors.grey.shade300
                              : AppColors.techBlue,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.send_rounded,
                          color: _loading ? Colors.grey : Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
      ),  // DraggableScrollableSheet
    );    // AnimatedPadding
  }
}

// ── Info row ──────────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final int maxLines;

  const _InfoRow({
    required this.icon,
    required this.text,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 13, color: AppColors.textMuted),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textTertiary,
                height: 1.35,
              ),
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Message bubble ─────────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  final String content;
  final bool isUser;

  const _MessageBubble({required this.content, required this.isUser});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isUser ? AppColors.techBlue : Colors.grey.shade100,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
        ),
        child: _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    final style = TextStyle(
      fontSize: 14,
      color: isUser ? Colors.white : AppColors.textDark,
      height: 1.4,
    );
    final boldStyle = style.copyWith(fontWeight: FontWeight.w700);
    final parts = content.split('**');
    final spans = <TextSpan>[
      for (var i = 0; i < parts.length; i++)
        TextSpan(text: parts[i], style: i.isOdd ? boldStyle : style),
    ];
    return RichText(text: TextSpan(children: spans));
  }
}

// ── Typing indicator ───────────────────────────────────────────────────────────

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
          bottomRight: Radius.circular(16),
          bottomLeft: Radius.circular(4),
        ),
      ),
      child: AnimatedBuilder(
        animation: _anim,
        builder: (_, __) => Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final t = (_anim.value - i * 0.2).clamp(0.0, 1.0);
            final opacity = (t < 0.5 ? t * 2 : (1 - t) * 2).clamp(0.3, 1.0);
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: Colors.grey.shade500.withValues(alpha: opacity),
                shape: BoxShape.circle,
              ),
            );
          }),
        ),
      ),
    );
  }
}
