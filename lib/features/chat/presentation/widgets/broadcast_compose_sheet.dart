import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../shared/presentation/theme/app_colors.dart';
import '../../../extraction/services/audio_transcription_service.dart';
import '../../data/services/chat_service.dart';

/// Bottom sheet for composing and sending broadcast messages to multiple staff.
///
/// Two AI modes:
/// - **Pencil (polish)**: fix grammar / professionalize the text inline
/// - **Sparkle (compose)**: describe what to say → AI writes the full message → preview card
class BroadcastComposeSheet extends StatefulWidget {
  const BroadcastComposeSheet({
    super.key,
    required this.broadcastType,
    required this.recipientCount,
    required this.scopeLabel,
    this.eventId,
    this.eventContext,
  });

  final String broadcastType; // 'event' or 'team'
  final int recipientCount;
  final String scopeLabel; // event title or "All teams"
  final String? eventId;

  /// Optional event details for AI context (name, date, startTime, endTime, location, clientName).
  final Map<String, dynamic>? eventContext;

  @override
  State<BroadcastComposeSheet> createState() => _BroadcastComposeSheetState();
}

enum _SheetState { idle, recording, transcribing, polishing, composing, previewing, sending }

class _BroadcastComposeSheetState extends State<BroadcastComposeSheet>
    with SingleTickerProviderStateMixin {
  final _textController = TextEditingController();
  final _chatService = ChatService();
  final _audioService = AudioTranscriptionService();
  final _focusNode = FocusNode();

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  _SheetState _state = _SheetState.idle;
  String? _aiPreviewText;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _textController.addListener(_onTextChanged);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _textController.removeListener(_onTextChanged);
    _textController.dispose();
    _focusNode.dispose();
    _pulseController.dispose();
    _audioService.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final hasText = _textController.text.trim().isNotEmpty;
    if (hasText != _hasText) {
      setState(() => _hasText = hasText);
    }
  }

  // ── Voice recording ──

  Future<void> _toggleRecording() async {
    if (_state == _SheetState.recording) {
      await _stopAndTranscribe();
    } else {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    final started = await _audioService.startRecording();
    if (started && mounted) {
      setState(() => _state = _SheetState.recording);
    }
  }

  Future<void> _stopAndTranscribe() async {
    setState(() => _state = _SheetState.transcribing);

    final path = await _audioService.stopRecording();
    if (path == null) {
      if (mounted) setState(() => _state = _SheetState.idle);
      return;
    }

    final transcription = await _audioService.transcribeAudio(path);
    if (mounted) {
      if (transcription != null && transcription.isNotEmpty) {
        _textController.text = _textController.text.isEmpty
            ? transcription
            : '${_textController.text} $transcription';
        _textController.selection = TextSelection.fromPosition(
          TextPosition(offset: _textController.text.length),
        );
      }
      setState(() => _state = _SheetState.idle);
    }
  }

  // ── AI Polish (pencil) — fix grammar, professionalize, replace inline ──

  Future<void> _aiPolish() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    setState(() => _state = _SheetState.polishing);

    try {
      final result = await _chatService.composeBroadcast(
        message: text,
        scenario: 'polish',
        eventContext: widget.eventContext,
      );

      if (mounted) {
        final polished = result['original'] as String?;
        if (polished != null && polished.isNotEmpty) {
          _textController.text = polished;
          _textController.selection = TextSelection.fromPosition(
            TextPosition(offset: _textController.text.length),
          );
        }
        setState(() => _state = _SheetState.idle);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _state = _SheetState.idle);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Polish failed: $e')),
        );
      }
    }
  }

  // ── AI Compose (sparkle) — describe → AI writes → preview card ──

  Future<void> _aiCompose() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _state = _SheetState.composing;
      _aiPreviewText = null;
    });

    try {
      final result = await _chatService.composeBroadcast(
        message: text,
        scenario: 'compose',
        eventContext: widget.eventContext,
      );

      if (mounted) {
        setState(() {
          _aiPreviewText = result['original'] as String?;
          _state = _SheetState.previewing;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _state = _SheetState.idle);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('AI compose failed: $e')),
        );
      }
    }
  }

  void _useAiSuggestion() {
    if (_aiPreviewText != null) {
      _textController.text = _aiPreviewText!;
      _textController.selection = TextSelection.fromPosition(
        TextPosition(offset: _textController.text.length),
      );
    }
    setState(() {
      _aiPreviewText = null;
      _state = _SheetState.idle;
    });
  }

  void _editAiSuggestion() {
    if (_aiPreviewText != null) {
      _textController.text = _aiPreviewText!;
      _textController.selection = TextSelection.fromPosition(
        TextPosition(offset: _textController.text.length),
      );
    }
    setState(() {
      _aiPreviewText = null;
      _state = _SheetState.idle;
    });
    _focusNode.requestFocus();
  }

  void _dismissAiPreview() {
    setState(() {
      _aiPreviewText = null;
      _state = _SheetState.idle;
    });
  }

  // ── Send broadcast ──

  Future<void> _sendBroadcast() async {
    final text = _textController.text.trim();
    final l10n = AppLocalizations.of(context)!;

    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.broadcastEmptyMessage)),
      );
      return;
    }

    setState(() => _state = _SheetState.sending);

    try {
      final result = await _chatService.sendBroadcast(
        message: text,
        broadcastType: widget.broadcastType,
        eventId: widget.eventId,
      );

      if (mounted) {
        final successCount = result['successCount'] as int? ?? 0;
        final totalCount = result['totalCount'] as int? ?? widget.recipientCount;

        Navigator.of(context).pop();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.broadcastSuccess(successCount, totalCount)),
            backgroundColor: Colors.green[700],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _state = _SheetState.idle);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.broadcastFailed),
            backgroundColor: Colors.red[700],
          ),
        );
      }
    }
  }

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.85,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF8FAFC),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Drag handle
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),

              // Header
              _buildHeader(),
              const SizedBox(height: 16),

              // Scrollable content
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    // AI preview card (compose result)
                    if (_state == _SheetState.previewing && _aiPreviewText != null)
                      _buildAiPreviewCard(),

                    // Composing indicator
                    if (_state == _SheetState.composing)
                      _buildComposingIndicator(),

                    const SizedBox(height: 8),

                    // Input row
                    _buildInputRow(),

                    const SizedBox(height: 20),

                    // Send button (the ONLY way to send)
                    _buildSendButton(),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    final l10n = AppLocalizations.of(context)!;
    final title = widget.broadcastType == 'event'
        ? l10n.broadcastDialogTitleEvent(widget.recipientCount)
        : l10n.broadcastDialogTitleTeam(widget.recipientCount);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          const Icon(Icons.campaign, color: AppColors.techBlue, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.scopeLabel,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAiPreviewCard() {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.techBlue.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.techBlue.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, size: 16, color: AppColors.techBlue),
              const SizedBox(width: 6),
              Text(
                'AI Suggestion',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.techBlue,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _dismissAiPreview,
                child: Icon(Icons.close, size: 18, color: Colors.grey[500]),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _aiPreviewText!,
            style: const TextStyle(fontSize: 14, height: 1.4),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _editAiSuggestion,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.techBlue,
                    side: BorderSide(color: AppColors.techBlue.withOpacity(0.4)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  child: Text(l10n.broadcastEdit),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: _useAiSuggestion,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.techBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  child: Text(l10n.broadcastUseThis),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildComposingIndicator() {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.techBlue.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.techBlue,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            l10n.broadcastAiPolishing,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.techBlue,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputRow() {
    final l10n = AppLocalizations.of(context)!;
    final isBusy = _state == _SheetState.sending ||
        _state == _SheetState.composing ||
        _state == _SheetState.polishing ||
        _state == _SheetState.transcribing;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Text field
        Expanded(
          child: TextField(
            controller: _textController,
            focusNode: _focusNode,
            maxLines: 5,
            minLines: 2,
            maxLength: 5000,
            enabled: !isBusy,
            decoration: InputDecoration(
              hintText: l10n.broadcastHint,
              hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
              filled: true,
              fillColor: Colors.white,
              counterText: '',
              contentPadding: const EdgeInsets.all(14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.techBlue, width: 1.5),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),

        // Action buttons column
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // When text is present: pencil (polish) + sparkle (compose)
            if (_hasText) ...[
              // Pencil — polish grammar inline
              _state == _SheetState.polishing
                  ? _buildSpinnerCircle()
                  : _buildIconButton(
                      icon: Icons.edit_note_rounded,
                      color: Colors.orange[700]!,
                      onTap: isBusy ? null : _aiPolish,
                      tooltip: 'Fix grammar',
                    ),
              const SizedBox(height: 6),
              // Sparkle — compose from instructions → preview
              _buildIconButton(
                icon: Icons.auto_awesome,
                color: AppColors.techBlue,
                onTap: isBusy ? null : _aiCompose,
                tooltip: 'AI compose',
              ),
            ],

            // When text is empty: mic button
            if (!_hasText) _buildRecordingButton(),
          ],
        ),
      ],
    );
  }

  Widget _buildRecordingButton() {
    if (_state == _SheetState.recording) {
      return AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return GestureDetector(
            onTap: _toggleRecording,
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.coralRed.withOpacity(_pulseAnimation.value),
                    AppColors.coralOrange.withOpacity(_pulseAnimation.value * 0.6),
                  ],
                ),
              ),
              child: const Icon(Icons.stop, color: Colors.white, size: 22),
            ),
          );
        },
      );
    }

    if (_state == _SheetState.transcribing) {
      return _buildSpinnerCircle();
    }

    return _buildIconButton(
      icon: Icons.mic_rounded,
      color: AppColors.coralRed,
      onTap: _toggleRecording,
      tooltip: 'Record voice',
    );
  }

  Widget _buildSpinnerCircle() {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.grey[200],
      ),
      child: const Padding(
        padding: EdgeInsets.all(10),
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
    String? tooltip,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(21),
        child: Tooltip(
          message: tooltip ?? '',
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: onTap != null ? color.withOpacity(0.1) : Colors.grey[100],
            ),
            child: Icon(
              icon,
              color: onTap != null ? color : Colors.grey[400],
              size: 22,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSendButton() {
    final l10n = AppLocalizations.of(context)!;
    final isSending = _state == _SheetState.sending;

    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        onPressed: isSending || !_hasText ? null : _sendBroadcast,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.techBlue,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey[300],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        icon: isSending
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.campaign, size: 20),
        label: Text(
          isSending ? l10n.broadcastSending : l10n.broadcastSendToAll,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

/// Show the broadcast compose bottom sheet.
Future<void> showBroadcastSheet(
  BuildContext context, {
  required String broadcastType,
  required int recipientCount,
  required String scopeLabel,
  String? eventId,
  Map<String, dynamic>? eventContext,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => BroadcastComposeSheet(
      broadcastType: broadcastType,
      recipientCount: recipientCount,
      scopeLabel: scopeLabel,
      eventId: eventId,
      eventContext: eventContext,
    ),
  );
}
