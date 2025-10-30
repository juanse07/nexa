import 'package:flutter/material.dart';

import '../services/audio_transcription_service.dart';

/// Widget for chat input with text field, microphone button, and send button
class ChatInputWidget extends StatefulWidget {
  final Function(String) onSendMessage;
  final bool isLoading;

  const ChatInputWidget({
    super.key,
    required this.onSendMessage,
    this.isLoading = false,
  });

  @override
  State<ChatInputWidget> createState() => _ChatInputWidgetState();
}

class _ChatInputWidgetState extends State<ChatInputWidget> with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final AudioTranscriptionService _audioService = AudioTranscriptionService();
  bool _hasText = false;
  bool _isRecording = false;
  bool _isTranscribing = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);

    // Setup pulse animation for recording indicator
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
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _pulseController.dispose();
    _audioService.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    setState(() {
      _hasText = _controller.text.trim().isNotEmpty;
    });
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty || widget.isLoading) return;

    widget.onSendMessage(text);
    _controller.clear();
  }

  /// Start recording audio
  Future<void> _startRecording() async {
    if (widget.isLoading || _isTranscribing) return;

    setState(() {
      _isRecording = true;
    });

    final started = await _audioService.startRecording();
    if (!started) {
      setState(() {
        _isRecording = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Microphone permission required for voice input'),
            duration: Duration(seconds: 3),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  /// Stop recording and transcribe audio
  Future<void> _stopRecordingAndTranscribe() async {
    if (!_isRecording) return;

    setState(() {
      _isRecording = false;
      _isTranscribing = true;
    });

    try {
      // Stop recording and get the file path
      final audioPath = await _audioService.stopRecording();

      if (audioPath == null) {
        throw Exception('Recording failed');
      }

      // Transcribe the audio
      final transcribedText = await _audioService.transcribeAudio(audioPath);

      if (transcribedText != null && transcribedText.isNotEmpty) {
        // Add transcribed text to the input field
        setState(() {
          _controller.text = transcribedText;
        });
      } else {
        throw Exception('No speech detected');
      }
    } catch (e) {
      print('[ChatInputWidget] Transcription error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Voice input failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isTranscribing = false;
        });
      }
    }
  }

  /// Cancel recording without transcribing
  Future<void> _cancelRecording() async {
    if (!_isRecording) return;

    setState(() {
      _isRecording = false;
    });

    await _audioService.cancelRecording();
  }

  @override
  Widget build(BuildContext context) {
    String hintText = 'Type your message...';
    if (widget.isLoading) {
      hintText = 'AI is thinking...';
    } else if (_isRecording) {
      hintText = 'Recording... Release to send';
    } else if (_isTranscribing) {
      hintText = 'Transcribing voice...';
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: _isRecording
                      ? Border.all(
                          color: Colors.red,
                          width: 2,
                        )
                      : null,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _controller,
                  enabled: !widget.isLoading && !_isRecording && !_isTranscribing,
                  maxLines: null,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: hintText,
                    hintStyle: TextStyle(
                      color: _isRecording
                          ? Colors.red.shade400
                          : Colors.grey.shade400,
                    ),
                    filled: true,
                    fillColor: Colors.transparent,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Microphone button
            if (!_hasText)
              GestureDetector(
                onLongPressStart: (_) => _startRecording(),
                onLongPressEnd: (_) => _stopRecordingAndTranscribe(),
                onLongPressCancel: () => _cancelRecording(),
                child: AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Container(
                      decoration: BoxDecoration(
                        color: _isRecording
                            ? Colors.red
                            : _isTranscribing
                                ? Colors.blue
                                : Colors.grey.shade300,
                        shape: BoxShape.circle,
                        boxShadow: _isRecording
                            ? [
                                BoxShadow(
                                  color: Colors.red.withOpacity(0.4 * _pulseAnimation.value),
                                  blurRadius: 16 * _pulseAnimation.value,
                                  spreadRadius: 4 * _pulseAnimation.value,
                                ),
                              ]
                            : [],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            width: 40,
                            height: 40,
                            alignment: Alignment.center,
                            child: _isTranscribing
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : Icon(
                                    _isRecording ? Icons.mic : Icons.mic_none,
                                    color: _isRecording
                                        ? Colors.white
                                        : Colors.grey.shade500,
                                    size: 20,
                                  ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            if (!_hasText) const SizedBox(width: 8),
            // Send button
            Container(
              decoration: BoxDecoration(
                gradient: _hasText && !widget.isLoading
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
                color: !_hasText || widget.isLoading ? Colors.grey.shade300 : null,
                shape: BoxShape.circle,
                boxShadow: _hasText && !widget.isLoading
                    ? [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                          spreadRadius: 0,
                        ),
                      ]
                    : [],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: _hasText && !widget.isLoading ? _sendMessage : null,
                  child: Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    child: widget.isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : Icon(
                            Icons.send,
                            color: _hasText ? const Color(0xFFB8860B) : Colors.grey.shade500,
                            size: 20,
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
