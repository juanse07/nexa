import 'dart:convert';
import 'dart:io';

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
      // Get temporary directory first
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _currentRecordingPath = '${tempDir.path}/voice_input_$timestamp.m4a';

      print('[AudioTranscriptionService] Attempting to start recording...');

      // Start recording - the record package will request permission if needed
      // iOS will show the permission dialog automatically on first use
      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc, // AAC format for best compatibility
          bitRate: 128000, // 128 kbps
          sampleRate: 44100, // 44.1 kHz
        ),
        path: _currentRecordingPath!,
      );

      _isRecording = true;
      print('[AudioTranscriptionService] Recording started: $_currentRecordingPath');
      return true;
    } catch (e) {
      print('[AudioTranscriptionService] Failed to start recording: $e');
      _isRecording = false;
      return false;
    }
  }

  /// Stop recording and return the path to the recorded file
  /// Returns null if recording failed or wasn't started
  Future<String?> stopRecording() async {
    try {
      if (!_isRecording) {
        print('[AudioTranscriptionService] Not currently recording');
        return null;
      }

      final path = await _audioRecorder.stop();
      _isRecording = false;

      if (path == null || path.isEmpty) {
        print('[AudioTranscriptionService] Recording path is empty');
        return null;
      }

      print('[AudioTranscriptionService] Recording stopped: $path');
      return path;
    } catch (e) {
      print('[AudioTranscriptionService] Failed to stop recording: $e');
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

      if (_currentRecordingPath != null) {
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
  Future<String?> transcribeAudio(String audioFilePath) async {
    try {
      final token = await AuthService.getJwt();
      if (token == null) {
        throw Exception('Not authenticated');
      }

      final baseUrl = AppConfig.instance.baseUrl;
      final uri = Uri.parse('$baseUrl/ai/transcribe');

      print('[AudioTranscriptionService] Transcribing audio: $audioFilePath');

      // Create multipart request
      final request = http.MultipartRequest('POST', uri);
      request.headers['Authorization'] = 'Bearer $token';

      // Add audio file
      final file = File(audioFilePath);
      if (!await file.exists()) {
        throw Exception('Audio file not found: $audioFilePath');
      }

      final fileSize = await file.length();
      print('[AudioTranscriptionService] File size: ${(fileSize / 1024).toStringAsFixed(2)} KB');

      request.files.add(
        await http.MultipartFile.fromPath(
          'audio',
          audioFilePath,
          filename: 'voice_input.m4a',
        ),
      );

      // Send request
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text = data['text'] as String?;

        if (text != null && text.isNotEmpty) {
          print('[AudioTranscriptionService] Transcription successful: ${text.substring(0, text.length > 50 ? 50 : text.length)}...');

          // Clean up the audio file after successful transcription
          try {
            await file.delete();
            print('[AudioTranscriptionService] Audio file deleted after transcription');
          } catch (e) {
            print('[AudioTranscriptionService] Failed to delete audio file: $e');
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
