import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io' show Platform;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:nexa/core/config/app_config.dart';

/// State of phone authentication flow
enum PhoneAuthState {
  idle,
  sendingCode,
  codeSent,
  verifying,
  success,
  error,
}

/// Service for handling phone number authentication
class PhoneAuthService {
  static const _jwtStorageKey = 'auth_jwt';
  static const _storage = FlutterSecureStorage();
  static const _requestTimeout = Duration(seconds: 30);

  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  String? _verificationId;
  int? _resendToken;
  String? _lastPhoneNumber;

  /// Callback for state changes
  void Function(PhoneAuthState state, String? message)? onStateChanged;

  static String get _apiBaseUrl {
    final base = AppConfig.instance.baseUrl;
    var raw = base.isNotEmpty ? base : 'http://127.0.0.1:4000';

    // Android emulator needs special localhost mapping
    if (!kIsWeb && Platform.isAndroid) {
      if (raw.contains('127.0.0.1')) {
        raw = raw.replaceAll('127.0.0.1', '10.0.2.2');
      }
      if (raw.contains('localhost')) {
        raw = raw.replaceAll('localhost', '10.0.2.2');
      }
    }
    return raw;
  }

  static void _log(String message, {bool isError = false}) {
    if (kDebugMode) {
      developer.log(
        message,
        name: 'PhoneAuthService',
        error: isError ? message : null,
      );
    }
  }

  /// Step 1: Request OTP to be sent to phone number
  /// Phone number should be in E.164 format (e.g., +1234567890)
  Future<void> sendOtp(String phoneNumber) async {
    _log('Sending OTP to $phoneNumber');
    _lastPhoneNumber = phoneNumber;
    onStateChanged?.call(PhoneAuthState.sendingCode, null);

    try {
      await _firebaseAuth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-verification on Android (instant verification)
          _log('Auto-verification completed');
          await _signInWithCredential(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          _log('Verification failed: ${e.code} - ${e.message}', isError: true);
          String message = 'Verification failed';
          if (e.code == 'invalid-phone-number') {
            message = 'Invalid phone number format. Use format: +1234567890';
          } else if (e.code == 'too-many-requests') {
            message = 'Too many attempts. Please try again later.';
          } else if (e.code == 'quota-exceeded') {
            message = 'SMS quota exceeded. Please try again later.';
          } else if (e.message != null) {
            message = e.message!;
          }
          onStateChanged?.call(PhoneAuthState.error, message);
        },
        codeSent: (String verificationId, int? resendToken) {
          _log('Code sent successfully');
          _verificationId = verificationId;
          _resendToken = resendToken;
          onStateChanged?.call(PhoneAuthState.codeSent, null);
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _log('Auto-retrieval timeout');
          _verificationId = verificationId;
        },
        forceResendingToken: _resendToken,
        timeout: const Duration(seconds: 60),
      );
    } catch (e) {
      _log('Send OTP error: $e', isError: true);
      onStateChanged?.call(PhoneAuthState.error, 'Failed to send verification code: $e');
    }
  }

  /// Resend OTP to the last phone number
  Future<void> resendOtp() async {
    if (_lastPhoneNumber != null) {
      await sendOtp(_lastPhoneNumber!);
    } else {
      onStateChanged?.call(PhoneAuthState.error, 'No phone number to resend to');
    }
  }

  /// Step 2: Verify OTP code entered by user
  Future<bool> verifyOtp(String otpCode) async {
    if (_verificationId == null) {
      onStateChanged?.call(PhoneAuthState.error, 'No verification in progress. Please request a new code.');
      return false;
    }

    _log('Verifying OTP code');
    onStateChanged?.call(PhoneAuthState.verifying, null);

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: otpCode,
      );

      return await _signInWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      _log('OTP verification error: ${e.code}', isError: true);
      String message = 'Verification failed';
      if (e.code == 'invalid-verification-code') {
        message = 'Invalid verification code. Please check and try again.';
      } else if (e.code == 'session-expired') {
        message = 'Code expired. Please request a new one.';
      } else if (e.message != null) {
        message = e.message!;
      }
      onStateChanged?.call(PhoneAuthState.error, message);
      return false;
    } catch (e) {
      _log('OTP verification error: $e', isError: true);
      onStateChanged?.call(PhoneAuthState.error, 'Verification failed: $e');
      return false;
    }
  }

  /// Sign in with Firebase credential and exchange for backend JWT
  Future<bool> _signInWithCredential(PhoneAuthCredential credential) async {
    try {
      _log('Signing in with Firebase credential');
      final userCredential = await _firebaseAuth.signInWithCredential(credential);
      final user = userCredential.user;

      if (user == null) {
        _log('No Firebase user returned', isError: true);
        onStateChanged?.call(PhoneAuthState.error, 'Failed to authenticate with phone number');
        return false;
      }

      _log('Firebase sign-in successful, getting ID token');

      // Get Firebase ID token
      final firebaseIdToken = await user.getIdToken();
      if (firebaseIdToken == null) {
        _log('Failed to get Firebase ID token', isError: true);
        onStateChanged?.call(PhoneAuthState.error, 'Failed to get authentication token');
        return false;
      }

      // Exchange Firebase token for backend JWT (manager endpoint)
      final success = await _exchangeTokenWithBackend(firebaseIdToken);

      // Sign out of Firebase (we use our own JWT)
      await _firebaseAuth.signOut();

      if (success) {
        _log('Phone authentication successful');
        onStateChanged?.call(PhoneAuthState.success, null);
        // Reset state
        _verificationId = null;
        _resendToken = null;
        _lastPhoneNumber = null;
      }

      return success;
    } catch (e) {
      _log('Credential sign-in error: $e', isError: true);
      onStateChanged?.call(PhoneAuthState.error, 'Authentication failed: $e');
      return false;
    }
  }

  /// Exchange Firebase token with backend for app JWT
  Future<bool> _exchangeTokenWithBackend(String firebaseIdToken) async {
    try {
      _log('Exchanging Firebase token with backend');

      final response = await http
          .post(
            Uri.parse('$_apiBaseUrl/auth/manager/phone'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'firebaseIdToken': firebaseIdToken}),
          )
          .timeout(_requestTimeout);

      _log('Backend response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final token = body['token']?.toString();

        if (token != null && token.isNotEmpty) {
          await _storage.write(key: _jwtStorageKey, value: token);
          // Mirror for Dio client compatibility
          await _storage.write(key: 'access_token', value: token);
          _log('JWT token saved successfully');
          return true;
        }
        _log('No token in response', isError: true);
        onStateChanged?.call(PhoneAuthState.error, 'Server returned invalid response');
      } else {
        final body = response.body;
        final message = _parseErrorMessage(body) ?? 'Authentication failed (${response.statusCode})';
        _log('Backend error: $message', isError: true);
        onStateChanged?.call(PhoneAuthState.error, message);
      }

      return false;
    } catch (e) {
      _log('Backend exchange error: $e', isError: true);
      onStateChanged?.call(PhoneAuthState.error, 'Failed to connect to server: $e');
      return false;
    }
  }

  String? _parseErrorMessage(String body) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      return json['message']?.toString();
    } catch (_) {
      return null;
    }
  }

  /// Link phone number to existing account
  /// Requires user to already be authenticated
  Future<bool> linkPhoneToAccount(String firebaseIdToken) async {
    try {
      _log('Linking phone to existing account');

      final existingToken = await _storage.read(key: _jwtStorageKey);
      if (existingToken == null) {
        onStateChanged?.call(PhoneAuthState.error, 'Not authenticated');
        return false;
      }

      final response = await http
          .post(
            Uri.parse('$_apiBaseUrl/auth/manager/link-phone'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $existingToken',
            },
            body: jsonEncode({'firebaseIdToken': firebaseIdToken}),
          )
          .timeout(_requestTimeout);

      if (response.statusCode == 200) {
        _log('Phone linked successfully');
        return true;
      } else if (response.statusCode == 409) {
        onStateChanged?.call(
          PhoneAuthState.error,
          'This phone number is already linked to another account',
        );
      } else {
        final message = _parseErrorMessage(response.body) ?? 'Failed to link phone number';
        onStateChanged?.call(PhoneAuthState.error, message);
      }
      return false;
    } catch (e) {
      _log('Link phone error: $e', isError: true);
      onStateChanged?.call(PhoneAuthState.error, 'Failed to link phone: $e');
      return false;
    }
  }

  /// Reset the auth flow state
  void reset() {
    _verificationId = null;
    _resendToken = null;
    _lastPhoneNumber = null;
    onStateChanged?.call(PhoneAuthState.idle, null);
  }

  /// Check if we're in the middle of a verification flow
  bool get hasActiveVerification => _verificationId != null;
}
