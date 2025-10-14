import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
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

  static String get _apiBaseUrl {
    // Support API_BASE_URL + API_PATH_PREFIX
    final env = Environment.instance;
    final apiBase = env.get('API_BASE_URL');
    final pathPrefix = env.getOrDefault('API_PATH_PREFIX', '');

    String raw;
    if (apiBase != null) {
      raw = pathPrefix.isNotEmpty ? '$apiBase$pathPrefix' : apiBase;
    } else {
      raw = 'http://127.0.0.1:4000';
    }

    if (!kIsWeb && Platform.isAndroid) {
      // Android emulator maps host loopback to 10.0.2.2
      if (raw.contains('127.0.0.1')) {
        return raw.replaceAll('127.0.0.1', '10.0.2.2');
      }
      if (raw.contains('localhost')) {
        return raw.replaceAll('localhost', '10.0.2.2');
      }
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
    try {
      await _googleSignIn().signOut();
    } catch (e) {
      _log('Error signing out from Google: $e', isError: true);
    }
  }

  /// Retrieves the stored JWT token
  static Future<String?> getJwt() => _storage.read(key: _jwtStorageKey);

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
          Uri.parse('$_apiBaseUrl/auth/google'),
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
      if (serverClientId != null && serverClientId.isNotEmpty) {
        return GoogleSignIn(
          scopes: const ['email', 'profile'],
          serverClientId: serverClientId,
        );
      }
    }

    return GoogleSignIn(scopes: const ['email', 'profile']);
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
          Uri.parse('$_apiBaseUrl/auth/apple'),
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
