import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../../core/config/app_config.dart';
import '../../auth/data/services/auth_service.dart';

/// Service for handling audio recording and transcription
class AudioTranscriptionService {
  final AudioRecorder _audioRecorder = AudioRecorder();
  String? _currentRecordingPath;
  bool _isRecording = false;

  bool get isRecording => _isRecording;

  /// Start recording audio
  /// Returns true if recording started successfully, false otherwise
  Future<bool> startRecording() async {
    try {
      print('[AudioTranscriptionService] Attempting to start recording...');

      // On web, we need to try starting the recording directly in response to user gesture
      // The browser will automatically prompt for permission if not already granted
      if (kIsWeb) {
        try {
          print('[AudioTranscriptionService] Web: Attempting to start recording (will prompt for permission if needed)...');

          // Try to start recording - this will trigger permission prompt if needed
          await _audioRecorder.start(
            const RecordConfig(
              encoder: AudioEncoder.opus, // Opus works better for web
              bitRate: 128000, // 128 kbps
              sampleRate: 44100, // 44.1 kHz
            ),
            path: '', // Empty path for web - recording is stored in memory
          );

          _currentRecordingPath = null; // Web returns blob URL later
          _isRecording = true;
          print('[AudioTranscriptionService] Web recording started successfully');
          return true;
        } catch (e) {
          // If starting fails, it's likely due to permission denial
          print('[AudioTranscriptionService] Web recording failed to start: $e');
          print('[AudioTranscriptionService] This usually means permission was denied or browser blocked access');
          _isRecording = false;
          return false;
        }
      } else {
        // For mobile/desktop, check permission first
        final hasPermission = await _audioRecorder.hasPermission();
        print('[AudioTranscriptionService] Mobile permission check result: $hasPermission');

        if (hasPermission) {
          // Mobile/Desktop needs a file path
          final tempDir = await getTemporaryDirectory();
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          _currentRecordingPath = '${tempDir.path}/voice_input_$timestamp.m4a';
          print('[AudioTranscriptionService] Starting mobile recording to: $_currentRecordingPath');

          await _audioRecorder.start(
            const RecordConfig(
              encoder: AudioEncoder.aacLc, // AAC format for mobile
              bitRate: 128000, // 128 kbps
              sampleRate: 44100, // 44.1 kHz
            ),
            path: _currentRecordingPath!,
          );

          _isRecording = true;
          print('[AudioTranscriptionService] Mobile recording started successfully: $_currentRecordingPath');
          return true;
        } else {
          print('[AudioTranscriptionService] No permission to record audio on mobile');
          _isRecording = false;
          return false;
        }
      }
    } catch (e, stackTrace) {
      print('[AudioTranscriptionService] Failed to start recording: $e');
      print('[AudioTranscriptionService] Stack trace: $stackTrace');
      _isRecording = false;
      return false;
    }
  }

  /// Stop recording and return the path to the recorded file
  /// Returns null if recording failed or wasn't started
  Future<String?> stopRecording() async {
    try {
      print('[AudioTranscriptionService] stopRecording called, _isRecording: $_isRecording');

      if (!_isRecording) {
        print('[AudioTranscriptionService] Not currently recording - cannot stop');
        return null;
      }

      print('[AudioTranscriptionService] Stopping recording...');
      final path = await _audioRecorder.stop();
      _isRecording = false;

      if (path == null || path.isEmpty) {
        print('[AudioTranscriptionService] Recording path is empty or null');
        return null;
      }

      print('[AudioTranscriptionService] Recording stopped successfully: $path');
      return path;
    } catch (e, stackTrace) {
      print('[AudioTranscriptionService] Failed to stop recording: $e');
      print('[AudioTranscriptionService] Stack trace: $stackTrace');
      _isRecording = false;
      return null;
    }
  }

  /// Cancel the current recording and delete the file
  Future<void> cancelRecording() async {
    try {
      if (_isRecording) {
        await _audioRecorder.stop();
        _isRecording = false;
      }

      // Only delete files on non-web platforms
      if (!kIsWeb && _currentRecordingPath != null) {
        final file = File(_currentRecordingPath!);
        if (await file.exists()) {
          await file.delete();
          print('[AudioTranscriptionService] Recording deleted: $_currentRecordingPath');
        }
        _currentRecordingPath = null;
      }
    } catch (e) {
      print('[AudioTranscriptionService] Failed to cancel recording: $e');
    }
  }

  /// Transcribe audio file to text using OpenAI Whisper API via backend
  /// Returns the transcribed text or null if transcription failed
  ///
  /// [audioPathOrUrl] Path to the audio file (mobile) or blob URL (web) to transcribe
  /// [terminology] Optional terminology preference (jobs, shifts, events) for better transcription context
  Future<String?> transcribeAudio(String audioPathOrUrl, {String? terminology}) async {
    try {
      final token = await AuthService.getJwt();
      if (token == null) {
        throw Exception('Not authenticated');
      }

      final baseUrl = AppConfig.instance.baseUrl;
      final uri = Uri.parse('$baseUrl/ai/transcribe');

      print('[AudioTranscriptionService] Transcribing audio: ${kIsWeb ? 'blob URL' : audioPathOrUrl}');
      if (terminology != null) {
        print('[AudioTranscriptionService] Using terminology: $terminology');
      }

      // Create multipart request
      final request = http.MultipartRequest('POST', uri);
      request.headers['Authorization'] = 'Bearer $token';

      // Add terminology if provided
      if (terminology != null) {
        request.fields['terminology'] = terminology.toLowerCase();
      }

      // Handle web vs mobile differently
      if (kIsWeb) {
        // For web, fetch the blob data from the URL
        print('[AudioTranscriptionService] Fetching audio blob from URL...');
        final blobResponse = await http.get(Uri.parse(audioPathOrUrl));

        if (blobResponse.statusCode == 200) {
          final bytes = blobResponse.bodyBytes;
          print('[AudioTranscriptionService] Blob size: ${(bytes.length / 1024).toStringAsFixed(2)} KB');

          request.files.add(
            http.MultipartFile.fromBytes(
              'audio',
              bytes,
              filename: 'voice_input.opus', // Opus format for web
            ),
          );
        } else {
          throw Exception('Failed to fetch audio blob');
        }
      } else {
        // For mobile, use file path
        final file = File(audioPathOrUrl);
        if (!await file.exists()) {
          throw Exception('Audio file not found: $audioPathOrUrl');
        }

        final fileSize = await file.length();
        print('[AudioTranscriptionService] File size: ${(fileSize / 1024).toStringAsFixed(2)} KB');

        request.files.add(
          await http.MultipartFile.fromPath(
            'audio',
            audioPathOrUrl,
            filename: 'voice_input.m4a',
          ),
        );
      }

      // Send request
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text = data['text'] as String?;

        if (text != null && text.isNotEmpty) {
          print('[AudioTranscriptionService] Transcription successful: ${text.substring(0, text.length > 50 ? 50 : text.length)}...');

          // Clean up the audio file after successful transcription (mobile only)
          if (!kIsWeb) {
            try {
              final file = File(audioPathOrUrl);
              await file.delete();
              print('[AudioTranscriptionService] Audio file deleted after transcription');
            } catch (e) {
              print('[AudioTranscriptionService] Failed to delete audio file: $e');
            }
          }

          return text;
        } else {
          print('[AudioTranscriptionService] Empty transcription result');
          return null;
        }
      } else {
        print('[AudioTranscriptionService] Transcription failed: ${response.statusCode}');
        print('[AudioTranscriptionService] Response: ${response.body}');

        // Try to extract error message
        try {
          final errorData = jsonDecode(response.body);
          final message = errorData['message'] ?? 'Transcription failed';
          throw Exception(message);
        } catch (e) {
          throw Exception('Transcription failed with status ${response.statusCode}');
        }
      }
    } catch (e) {
      print('[AudioTranscriptionService] Error transcribing audio: $e');
      return null;
    }
  }

  /// Record and transcribe audio in one step
  /// Returns the transcribed text or null if recording/transcription failed
  Future<String?> recordAndTranscribe() async {
    try {
      // Start recording
      final started = await startRecording();
      if (!started) {
        print('[AudioTranscriptionService] Failed to start recording');
        return null;
      }

      // Wait for user to finish speaking (this should be called from UI when user releases button)
      // For now, we'll just stop immediately for testing
      // In real usage, the UI should call stopRecording() when the user releases the button

      return null; // UI will handle the stop and transcribe steps
    } catch (e) {
      print('[AudioTranscriptionService] Error in recordAndTranscribe: $e');
      return null;
    }
  }

  /// Dispose of the audio recorder
  Future<void> dispose() async {
    try {
      if (_isRecording) {
        await cancelRecording();
      }
      await _audioRecorder.dispose();
    } catch (e) {
      print('[AudioTranscriptionService] Error disposing audio recorder: $e');
    }
  }
}
