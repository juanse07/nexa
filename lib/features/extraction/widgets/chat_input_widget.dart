import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../services/terminology_provider.dart';
import '../services/audio_transcription_service.dart';

/// Widget for chat input with text field, attachment, microphone, and send button
class ChatInputWidget extends StatefulWidget {
  final Function(String) onSendMessage;
  final VoidCallback? onAttachmentTap;
  final bool isLoading;

  const ChatInputWidget({
    super.key,
    required this.onSendMessage,
    this.onAttachmentTap,
    this.isLoading = false,
  });

  @override
  State<ChatInputWidget> createState() => _ChatInputWidgetState();
}

class _ChatInputWidgetState extends State<ChatInputWidget> with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final AudioTranscriptionService _audioService = AudioTranscriptionService();
  bool _hasText = false;
  bool _isRecording = false;
  bool _isTranscribing = false;
  bool _keyboardVisible = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
    _focusNode.addListener(_onFocusChanged);

    // Setup pulse animation for recording indicator
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Auto-focus keyboard on mobile (not web)
    if (!kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _focusNode.requestFocus();
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focusNode.dispose();
    _pulseController.dispose();
    _audioService.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    setState(() {
      _hasText = _controller.text.trim().isNotEmpty;
    });
  }

  void _onFocusChanged() {
    setState(() {
      _keyboardVisible = _focusNode.hasFocus;
    });
  }

  void _hideKeyboard() {
    _focusNode.unfocus();
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
          SnackBar(
            content: const Text('Please allow microphone access when prompted by your browser'),
            duration: const Duration(seconds: 4),
            backgroundColor: Colors.orange,
            action: SnackBarAction(
              label: 'Help',
              textColor: Colors.white,
              onPressed: () {
                // Show help dialog
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Microphone Access Required'),
                    content: const Text(
                      'To use voice input:\n\n'
                      '1. Click the microphone button\n'
                      '2. Allow microphone access in your browser prompt\n'
                      '3. If you blocked it, click the lock/info icon in your browser\'s address bar to change permissions\n\n'
                      'Note: Voice recording only works on secure (HTTPS) connections.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Got it'),
                      ),
                    ],
                  ),
                );
              },
            ),
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

      // Get user's terminology preference
      final terminology = context.read<TerminologyProvider>().plural.toLowerCase();

      // Transcribe the audio with terminology context
      final transcribedText = await _audioService.transcribeAudio(audioPath, terminology: terminology);

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

  /// Toggle recording on/off with a single tap
  Future<void> _toggleRecording() async {
    if (_isTranscribing || widget.isLoading) return;

    if (_isRecording) {
      // Stop recording and transcribe
      await _stopRecordingAndTranscribe();
    } else {
      // Start recording
      await _startRecording();
    }
  }

  @override
  Widget build(BuildContext context) {
    String hintText = 'Type your message...';
    if (widget.isLoading) {
      hintText = 'AI is thinking...';
    } else if (_isRecording) {
      hintText = 'Recording... Tap mic to stop';
    } else if (_isTranscribing) {
      hintText = 'Transcribing voice...';
    }

    return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), // Balanced padding
        child: Row(
          children: [
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                decoration: BoxDecoration(
                  color: _isRecording
                      ? Color(0xFFFFF5F5) // Very light coral background when recording
                      : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: _isRecording
                      ? Border.all(
                          color: Color(0xFFFF6B6B),
                          width: 2,
                        )
                      : Border.all(
                          color: Colors.grey.shade200,
                          width: 1,
                        ),
                  boxShadow: [
                    BoxShadow(
                      color: _isRecording
                          ? Color(0xFFFF6B6B).withOpacity(0.2)
                          : Colors.black.withValues(alpha: 0.08),
                      blurRadius: _isRecording ? 12 : 8,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
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
                      vertical: 6, // Reduced from 10 to 6
                    ),
                    // Attachment icon on the left
                    prefixIcon: widget.onAttachmentTap != null
                        ? IconButton(
                            icon: Icon(
                              Icons.attach_file,
                              color: Colors.grey.shade600,
                              size: 18,
                            ),
                            onPressed: widget.isLoading || _isRecording || _isTranscribing
                                ? null
                                : widget.onAttachmentTap,
                            tooltip: 'Attach image or document',
                          )
                        : null,
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
            ),
            const SizedBox(width: 4),
            // Keyboard hide button (when keyboard is visible)
            if (_keyboardVisible && !kIsWeb)
              Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFE0E7FF),  // Light indigo
                      Color(0xFFC7D2FE),  // Medium indigo
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: _hideKeyboard,
                    child: Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.keyboard_hide,
                        color: Color(0xFF4F46E5),
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),
            if (_keyboardVisible && !kIsWeb) const SizedBox(width: 4),
            // Microphone button - tap to toggle recording
            if (!_hasText && !_keyboardVisible)
              GestureDetector(
                onTap: _toggleRecording,
                child: AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Container(
                      decoration: BoxDecoration(
                        gradient: _isRecording
                            ? LinearGradient(
                                colors: [
                                  Color(0xFFFF6B6B),  // Bright coral red
                                  Color(0xFFFF8787),  // Light coral
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : _isTranscribing
                                ? LinearGradient(
                                    colors: [
                                      Color(0xFF4ECDC4),  // Teal
                                      Color(0xFF44A8A0),  // Darker teal
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  )
                                : LinearGradient(
                                    colors: [
                                      Color(0xFFFF9A8B),  // Soft coral pink
                                      Color(0xFFFECFB2),  // Peach
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                        shape: BoxShape.circle,
                        boxShadow: _isRecording
                            ? [
                                BoxShadow(
                                  color: Color(0xFFFF6B6B).withOpacity(0.5 * _pulseAnimation.value),
                                  blurRadius: 20 * _pulseAnimation.value,
                                  spreadRadius: 6 * _pulseAnimation.value,
                                ),
                              ]
                            : [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 8,
                                  offset: Offset(0, 2),
                                ),
                              ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          child: Container(
                            width: 36,
                            height: 36,
                            alignment: Alignment.center,
                            child: _isTranscribing
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : Icon(
                                    _isRecording ? Icons.mic : Icons.mic_none,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            if (!_hasText && !_keyboardVisible) const SizedBox(width: 4),
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
                  borderRadius: BorderRadius.circular(18),
                  onTap: _hasText && !widget.isLoading ? _sendMessage : null,
                  child: Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    child: widget.isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
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
                            size: 18,
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
  }
}
