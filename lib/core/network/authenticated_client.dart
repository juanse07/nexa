import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:nexa/features/auth/data/services/auth_service.dart';

/// HTTP client that automatically attaches Bearer auth and handles 401 responses.
///
/// Drop-in replacement for [http.Client] — services can use this instead of
/// manually assembling Authorization headers from AuthService.getJwt().
///
/// On 401: attempts a token refresh before falling back to forceLogout.
class AuthenticatedClient extends http.BaseClient {
  AuthenticatedClient({this.timeout = const Duration(seconds: 30)});

  final Duration timeout;

  final http.Client _inner = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    // Attach Bearer token from AuthService (cache-first).
    final token = await AuthService.getJwt();
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    final response = await _inner.send(request).timeout(timeout);

    // On 401: try refresh before logging out.
    if (response.statusCode == 401) {
      _log('401 from ${request.url.path} — attempting token refresh');

      final refreshed = await AuthService.refreshAccessToken();
      if (refreshed) {
        // Retry the original request with the new token.
        final newToken = await AuthService.getJwt();
        final retry = _cloneRequest(request, newToken);
        if (retry != null) {
          _log('Retrying ${request.url.path} with refreshed token');
          return _inner.send(retry).timeout(timeout);
        }
      }

      // Refresh failed — force logout.
      _log('Refresh failed — triggering forceLogout');
      await AuthService.forceLogout();
    }

    return response;
  }

  /// Clone a BaseRequest for retry with a new auth token.
  /// Returns null if the request type is unsupported.
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
      _log('Cannot clone ${original.runtimeType} for retry');
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

  static void _log(String message) {
    if (kDebugMode) {
      developer.log(message, name: 'AuthenticatedClient');
    }
  }
}
