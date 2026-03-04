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
  static const _refreshTokenKey = 'auth_refresh_token';
  static const _storage = FlutterSecureStorage();
  static const _requestTimeout = Duration(seconds: 30);

  /// Stream that emits when a forced logout occurs (e.g., 401 response).
  /// The root widget should listen to this and navigate to login.
  static final StreamController<void> _forcedLogoutController =
      StreamController<void>.broadcast();
  static Stream<void> get onForcedLogout => _forcedLogoutController.stream;

  static DateTime? _lastForcedLogout;

  /// Cached token for synchronous access by interceptors (avoids async reads).
  static String? _cachedToken;

  /// Cached refresh token (avoids hitting secure storage on every refresh).
  static String? _cachedRefreshToken;

  /// Completer mutex: ensures only one refresh is in-flight at a time.
  static Completer<bool>? _refreshCompleter;

  /// Lazy singleton HTTP client with auto-Bearer and 401 refresh+retry.
  /// Import `authenticated_client.dart` for the class.
  static http.Client? _httpClient;
  static http.Client get httpClient {
    // Late import to avoid circular dependency — AuthenticatedClient
    // lives in core/network and depends on AuthService.
    return _httpClient ??= _createHttpClient();
  }

  static http.Client _createHttpClient() {
    // We inline a lightweight BaseClient here so that AuthService has no
    // import-time dependency on authenticated_client.dart (avoids circularity).
    // The full AuthenticatedClient in core/network/ delegates to this same logic.
    return _AuthServiceHttpClient();
  }

  /// Synchronous accessor for the last-known JWT. Used by ErrorInterceptor
  /// to check token expiry without awaiting secure storage.
  static String? get lastKnownToken => _cachedToken;

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
    _cachedToken = null;
    _cachedRefreshToken = null;
    await Future.wait([
      _storage.delete(key: _jwtStorageKey),
      _storage.delete(key: 'access_token'),
      _storage.delete(key: _refreshTokenKey),
    ].map((f) => f.catchError((_) {})));
    try {
      await _googleSignIn().signOut();
    } catch (e) {
      _log('Error signing out from Google: $e', isError: true);
    }
  }

  /// Retrieves the stored JWT token (cache-first for performance).
  static Future<String?> getJwt() async {
    // Return cached token immediately if available
    if (_cachedToken != null && _cachedToken!.isNotEmpty) {
      return _cachedToken;
    }

    final token = await _storage.read(key: _jwtStorageKey);

    // Validate token has managerId field (for manager app)
    if (token != null && token.isNotEmpty) {
      _cachedToken = token; // Keep sync copy for interceptors
      try {
        final parts = token.split('.');
        if (parts.length == 3) {
          final payload = json.decode(
            utf8.decode(base64Url.decode(_normalizeBase64(parts[1])))
          ) as Map<String, dynamic>;

          if (!payload.containsKey('managerId')) {
            _log('Token missing managerId field - clearing old token', isError: true);
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
    _cachedToken = token; // Keep sync copy for interceptors
    await _storage.write(key: _jwtStorageKey, value: token);
    // For Dio-based client, mirror the token into the common access_token key
    try {
      await _storage.write(key: 'access_token', value: token);
    } catch (_) {}
  }

  /// Save both access token and refresh token atomically.
  /// Called by all sign-in methods after a successful backend response.
  static Future<void> saveTokenPair(String token, String refreshToken) async {
    _cachedToken = token;
    _cachedRefreshToken = refreshToken;
    await Future.wait([
      _storage.write(key: _jwtStorageKey, value: token),
      _storage.write(key: 'access_token', value: token),
      _storage.write(key: _refreshTokenKey, value: refreshToken),
    ]);
    _log('Token pair saved');
  }

  /// Read refresh token (cache-first).
  static Future<String?> _getRefreshToken() async {
    if (_cachedRefreshToken != null) return _cachedRefreshToken;
    final rt = await _storage.read(key: _refreshTokenKey);
    _cachedRefreshToken = rt;
    return rt;
  }

  /// Attempt to refresh the access token using the stored refresh token.
  /// Returns true on success. Uses a Completer mutex so concurrent 401s
  /// only trigger a single refresh call.
  static Future<bool> refreshAccessToken() async {
    // If a refresh is already in-flight, piggyback on it.
    if (_refreshCompleter != null) {
      _log('Refresh already in-flight — waiting');
      return _refreshCompleter!.future;
    }

    _refreshCompleter = Completer<bool>();

    try {
      final refreshToken = await _getRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) {
        _log('No refresh token available', isError: true);
        _refreshCompleter!.complete(false);
        return false;
      }

      _log('Refreshing access token via /auth/refresh');
      final resp = await http.post(
        Uri.parse('$_apiBaseUrl/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refreshToken': refreshToken}),
      ).timeout(_requestTimeout);

      if (resp.statusCode == 200) {
        final body = json.decode(resp.body) as Map<String, dynamic>;
        final newToken = body['token']?.toString();
        final newRefreshToken = body['refreshToken']?.toString();

        if (newToken != null && newToken.isNotEmpty &&
            newRefreshToken != null && newRefreshToken.isNotEmpty) {
          await saveTokenPair(newToken, newRefreshToken);
          _log('Token refresh successful');
          _refreshCompleter!.complete(true);
          return true;
        }
      }

      _log('Token refresh failed: ${resp.statusCode}', isError: true);
      _refreshCompleter!.complete(false);
      return false;
    } catch (e) {
      _log('Token refresh error: $e', isError: true);
      _refreshCompleter!.complete(false);
      return false;
    } finally {
      _refreshCompleter = null;
    }
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
        final refreshToken = body['refreshToken']?.toString();
        if (token != null && token.isNotEmpty) {
          if (refreshToken != null && refreshToken.isNotEmpty) {
            await saveTokenPair(token, refreshToken);
          } else {
            await _saveJwt(token);
          }
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
        final refreshToken = body['refreshToken']?.toString();
        if (token != null && token.isNotEmpty) {
          if (refreshToken != null && refreshToken.isNotEmpty) {
            await saveTokenPair(token, refreshToken);
          } else {
            await _saveJwt(token);
          }
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
        final refreshToken = body['refreshToken']?.toString();
        if (token != null && token.isNotEmpty) {
          if (refreshToken != null && refreshToken.isNotEmpty) {
            await saveTokenPair(token, refreshToken);
          } else {
            await _saveJwt(token);
          }
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

/// Lightweight authenticated HTTP client used by [AuthService.httpClient].
/// Auto-attaches Bearer token and handles 401 with refresh+retry.
class _AuthServiceHttpClient extends http.BaseClient {
  final http.Client _inner = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    // Attach Bearer token.
    final token = await AuthService.getJwt();
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    final response = await _inner.send(request).timeout(
      const Duration(seconds: 30),
    );

    if (response.statusCode == 401) {
      final refreshed = await AuthService.refreshAccessToken();
      if (refreshed) {
        final newToken = await AuthService.getJwt();
        final retry = _cloneRequest(request, newToken);
        if (retry != null) {
          return _inner.send(retry).timeout(const Duration(seconds: 30));
        }
      }
      // Refresh failed — force logout.
      await AuthService.forceLogout();
    }

    return response;
  }

  http.BaseRequest? _cloneRequest(http.BaseRequest original, String? token) {
    final http.BaseRequest clone;
    if (original is http.Request) {
      clone = http.Request(original.method, original.url)
        ..headers.addAll(original.headers)
        ..bodyBytes = original.bodyBytes
        ..encoding = original.encoding;
    } else if (original is http.MultipartRequest) {
      clone = http.MultipartRequest(original.method, original.url)
        ..headers.addAll(original.headers)
        ..fields.addAll(original.fields)
        ..files.addAll(original.files);
    } else {
      return null;
    }
    if (token != null) {
      clone.headers['Authorization'] = 'Bearer $token';
    }
    return clone;
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }
}
