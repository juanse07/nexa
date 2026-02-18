import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:nexa/core/config/app_config.dart';
import 'package:nexa/core/config/environment.dart';
import 'package:nexa/features/auth/data/services/apple_web_auth.dart';

/// Custom exceptions for authentication operations
class AuthException implements Exception {
  final String message;
  final int? statusCode;

  AuthException(this.message, [this.statusCode]);

  @override
  String toString() => 'AuthException: $message${statusCode != null ? ' (Status: $statusCode)' : ''}';
}

class NetworkException extends AuthException {
  NetworkException(super.message);
}

class InvalidTokenException extends AuthException {
  InvalidTokenException() : super('Invalid or missing authentication token');
}

/// Service for handling authentication and API requests
class AuthService {
  static const _jwtStorageKey = 'auth_jwt';
  static const _storage = FlutterSecureStorage();
  static const _requestTimeout = Duration(seconds: 30);

  /// Stream that emits when a forced logout occurs (e.g., 401 response).
  /// The root widget should listen to this and navigate to login.
  static final StreamController<void> _forcedLogoutController =
      StreamController<void>.broadcast();
  static Stream<void> get onForcedLogout => _forcedLogoutController.stream;

  static DateTime? _lastForcedLogout;

  /// Called by ErrorInterceptor on 401. Clears tokens and emits on the stream.
  /// Debounced to prevent multiple 401s from triggering multiple logouts.
  static Future<void> forceLogout() async {
    final now = DateTime.now();
    if (_lastForcedLogout != null &&
        now.difference(_lastForcedLogout!).inSeconds < 5) {
      return; // Debounce: ignore if last forced logout was <5s ago
    }
    _lastForcedLogout = now;
    _log('Forced logout triggered (401)');
    await signOut();
    _forcedLogoutController.add(null);
  }

  static String get _apiBaseUrl {
    final base = AppConfig.instance.baseUrl;

    // Use production URL as fallback (never localhost in release builds)
    var raw = base.isNotEmpty ? base : 'https://api.nexapymesoft.com';

    // Android emulator needs special localhost mapping (debug only)
    if (kDebugMode && !kIsWeb && Platform.isAndroid) {
      if (raw.contains('127.0.0.1')) {
        raw = raw.replaceAll('127.0.0.1', '10.0.2.2');
      }
      if (raw.contains('localhost')) {
        raw = raw.replaceAll('localhost', '10.0.2.2');
      }
    }

    if (kDebugMode) {
      developer.log('Resolved API base URL: $raw', name: 'AuthService');
    }

    return raw;
  }

  /// Logs a message if in debug mode
  static void _log(String message, {bool isError = false}) {
    if (kDebugMode) {
      if (isError) {
        developer.log(message, name: 'AuthService', error: message);
      } else {
        developer.log(message, name: 'AuthService');
      }
    }
  }

  /// Helper to make HTTP requests with timeout and error handling
  static Future<http.Response> _makeRequest({
    required Future<http.Response> Function() request,
    required String operation,
  }) async {
    try {
      _log('$operation: Starting request');
      final response = await request().timeout(_requestTimeout);
      _log('$operation: Response status ${response.statusCode}');
      return response;
    } on http.ClientException catch (e) {
      _log('$operation: Network error - $e', isError: true);
      throw NetworkException('Network error during $operation: ${e.message}');
    } catch (e) {
      _log('$operation: Unexpected error - $e', isError: true);
      throw AuthException('Failed to $operation: $e');
    }
  }

  /// Signs out the current user
  static Future<void> signOut() async {
    _log('Signing out user');
    await _storage.delete(key: _jwtStorageKey);
    // Also delete the mirrored access_token key
    try {
      await _storage.delete(key: 'access_token');
    } catch (_) {}
    try {
      await _googleSignIn().signOut();
    } catch (e) {
      _log('Error signing out from Google: $e', isError: true);
    }
  }

  /// Retrieves the stored JWT token
  static Future<String?> getJwt() async {
    final token = await _storage.read(key: _jwtStorageKey);

    // Validate token has managerId field (for manager app)
    if (token != null && token.isNotEmpty) {
      try {
        // Decode JWT payload
        final parts = token.split('.');
        if (parts.length == 3) {
          final payload = json.decode(
            utf8.decode(base64Url.decode(_normalizeBase64(parts[1])))
          ) as Map<String, dynamic>;

          // Check if token has managerId (required for manager app)
          if (!payload.containsKey('managerId')) {
            _log('Token missing managerId field - clearing old token', isError: true);
            // Clear the old token to force re-login
            await signOut();
            return null;
          }
        }
      } catch (e) {
        _log('Error validating token: $e', isError: true);
      }
    }

    return token;
  }

  /// Saves JWT token to secure storage
  static Future<void> _saveJwt(String token) async {
    await _storage.write(key: _jwtStorageKey, value: token);
    // For Dio-based client, mirror the token into the common access_token key
    try {
      await _storage.write(key: 'access_token', value: token);
    } catch (_) {}
  }

  /// Signs in a user with Google OAuth
  /// Returns true if successful, false otherwise
  static Future<bool> signInWithGoogle({void Function(String message)? onError}) async {
    try {
      _log('Starting Google sign in');
      final googleSignIn = _googleSignIn();
      final account = await googleSignIn.signIn();
      if (account == null) {
        _log('Google sign in cancelled by user');
        onError?.call('Sign-in cancelled');
        return false;
      }

      final auth = await account.authentication;

      // On web, idToken might be null but accessToken should be available
      final idToken = auth.idToken;
      final accessToken = auth.accessToken;

      _log('Auth tokens - idToken: ${idToken != null ? "present" : "null"}, accessToken: ${accessToken != null ? "present" : "null"}');

      // For web, if we don't have an idToken, try using accessToken
      String? tokenToSend;
      String tokenType;

      if (idToken != null && idToken.isNotEmpty) {
        tokenToSend = idToken;
        tokenType = 'idToken';
      } else if (accessToken != null && accessToken.isNotEmpty) {
        tokenToSend = accessToken;
        tokenType = 'accessToken';
        _log('Using accessToken instead of idToken for web authentication');
      } else {
        _log('Failed to get any Google token', isError: true);
        onError?.call('No token returned by Google. Check OAuth configuration');
        return false;
      }

      // Debug: Log token info if it's an ID token
      if (tokenType == 'idToken') {
        try {
          final parts = tokenToSend!.split('.');
          if (parts.length == 3) {
            final payloadStr = utf8.decode(base64Url.decode(_normalizeBase64(parts[1])));
            final payload = json.decode(payloadStr) as Map<String, dynamic>;
            final aud = (payload['aud']?.toString() ?? '').replaceAll(RegExp(r'(^.{6}|.{6}$)'), '***');
            final iss = payload['iss']?.toString();
            final azp = payload['azp']?.toString();
            _log('Google idToken aud(masked)=$aud, iss=$iss, azp=$azp');
          }
        } catch (e) {
          _log('Failed to decode idToken payload: $e', isError: true);
        }
      }

      final resp = await _makeRequest(
        request: () => http.post(
          Uri.parse('$_apiBaseUrl/auth/manager/google'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            if (tokenType == 'idToken') 'idToken': tokenToSend,
            if (tokenType == 'accessToken') 'accessToken': tokenToSend,
          }),
        ),
        operation: 'Google sign in',
      );

      if (resp.statusCode == 200) {
        final body = json.decode(resp.body) as Map<String, dynamic>;
        final token = body['token']?.toString();
        if (token != null && token.isNotEmpty) {
          await _saveJwt(token);
          _log('Google sign in successful');
          return true;
        }
        _log('Invalid token received from server', isError: true);
        onError?.call('API returned invalid token payload');
      } else {
        _log('Google sign in failed with status ${resp.statusCode}', isError: true);
        final body = resp.body;
        onError?.call('API ${resp.statusCode}${body.isNotEmpty ? ': '+(body.length>120?body.substring(0,120)+'...':body) : ''}');
      }
      return false;
    } catch (e) {
      _log('Google sign in error: $e', isError: true);
      onError?.call('Exception: $e');
      return false;
    }
  }

  static String _normalizeBase64(String input) {
    final pad = input.length % 4;
    if (pad == 2) return '${input}==';
    if (pad == 3) return '${input}=';
    if (pad == 1) return '${input}===';
    return input;
  }

  static GoogleSignIn _googleSignIn() {
    final env = Environment.instance;

    // For web, use both clientId and serverClientId to get ID token
    if (kIsWeb) {
      final webClientId = env.get('GOOGLE_CLIENT_ID_WEB');
      final serverClientId = env.get('GOOGLE_SERVER_CLIENT_ID');

      if (webClientId != null && webClientId.isNotEmpty) {
        // For web: Use serverClientId as the main clientId parameter
        // This ensures we get an ID token suitable for backend verification
        return GoogleSignIn(
          scopes: const ['email', 'profile', 'openid'],
          clientId: serverClientId ?? webClientId,
        );
      }
    } else {
      // For mobile platforms, use serverClientId for backend verification
      final serverClientId = env.get('GOOGLE_SERVER_CLIENT_ID');
      // On iOS, pass clientId explicitly when available to override the
      // CLIENT_ID from GoogleService-Info.plist. Only pass it if it looks
      // like a real Google client ID (on-device builds may only have
      // placeholder values from .env.defaults).
      final iosClientId = env.get('GOOGLE_CLIENT_ID_IOS');
      final validIosClientId = (iosClientId != null &&
              iosClientId.contains('.apps.googleusercontent.com'))
          ? iosClientId
          : null;
      if (serverClientId != null && serverClientId.isNotEmpty) {
        return GoogleSignIn(
          scopes: const ['email', 'profile'],
          clientId: (!kIsWeb && Platform.isIOS) ? validIosClientId : null,
          serverClientId: serverClientId,
        );
      }
    }

    return GoogleSignIn(scopes: const ['email', 'profile']);
  }

  /// Signs in a manager with email and password (demo accounts)
  /// Returns true if successful, false otherwise
  static Future<bool> signInWithEmail({
    required String email,
    required String password,
    void Function(String message)? onError,
  }) async {
    try {
      _log('Starting email sign in');

      final resp = await _makeRequest(
        request: () => http.post(
          Uri.parse('$_apiBaseUrl/auth/manager/email'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': email, 'password': password}),
        ),
        operation: 'Email sign in',
      );

      if (resp.statusCode == 200) {
        final body = json.decode(resp.body) as Map<String, dynamic>;
        final token = body['token']?.toString();
        if (token != null && token.isNotEmpty) {
          await _saveJwt(token);
          _log('Email sign in successful');
          return true;
        }
        _log('Invalid token received from server', isError: true);
        onError?.call('Server returned an invalid token payload.');
      } else {
        _log('Email sign in failed with status ${resp.statusCode}', isError: true);
        try {
          final body = json.decode(resp.body) as Map<String, dynamic>;
          onError?.call(body['message']?.toString() ?? 'Invalid email or password');
        } catch (_) {
          onError?.call('Invalid email or password');
        }
      }
      return false;
    } catch (e) {
      _log('Email sign in error: $e', isError: true);
      onError?.call('Sign-in failed: $e');
      return false;
    }
  }

  /// Signs in a user with Apple Sign In
  /// Returns true if successful, false otherwise
  static Future<bool> signInWithApple({void Function(String message)? onError}) async {
    if (kIsWeb) {
      final env = Environment.instance;
      final clientId = env.get('APPLE_SERVICE_ID');
      final redirectUri = env.get('APPLE_REDIRECT_URI');
      if (clientId == null || redirectUri == null) {
        onError?.call('Apple sign-in for web is not configured.');
        return false;
      }

      final identityToken = await AppleWebAuth.signIn(
        clientId: clientId,
        redirectUri: redirectUri,
        onError: onError,
      );
      if (identityToken == null) {
        return false;
      }

      return _completeAppleLogin(identityToken, onError: onError);
    }

    try {
      _log('Starting Apple sign in');
      final available = await SignInWithApple.isAvailable();
      if (!available) {
        _log('Apple sign in not available on this device');
        onError?.call('Apple sign-in is not available on this device.');
        return false;
      }

      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );
      final identityToken = credential.identityToken;
      if (identityToken == null) {
        _log('Failed to get Apple identity token', isError: true);
        onError?.call('Apple did not return an identity token.');
        return false;
      }

      return _completeAppleLogin(identityToken, onError: onError);
    } catch (e) {
      _log('Apple sign in error: $e', isError: true);
      onError?.call('Apple sign-in failed: $e');
      return false;
    }
  }

  static Future<bool> _completeAppleLogin(
    String identityToken, {
    void Function(String message)? onError,
  }) async {
    try {
      final resp = await _makeRequest(
        request: () => http.post(
          Uri.parse('$_apiBaseUrl/auth/manager/apple'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'identityToken': identityToken}),
        ),
        operation: 'Apple sign in',
      );

      if (resp.statusCode == 200) {
        final body = json.decode(resp.body) as Map<String, dynamic>;
        final token = body['token']?.toString();
        if (token != null && token.isNotEmpty) {
          await _saveJwt(token);
          _log('Apple sign in successful');
          return true;
        }
        _log('Invalid token received from server', isError: true);
        onError?.call('Server returned an invalid token payload.');
      } else {
        _log('Apple sign in failed with status ${resp.statusCode}', isError: true);
        onError?.call('API ${resp.statusCode}: ${resp.body}');
      }
      return false;
    } catch (e) {
      _log('Apple sign in error: $e', isError: true);
      onError?.call('Apple sign-in request failed: $e');
      return false;
    }
  }
}
