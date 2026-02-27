import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logger/logger.dart';
import 'package:nexa/core/constants/api_constants.dart';
import 'package:nexa/core/constants/storage_keys.dart';
import 'package:nexa/features/auth/data/services/auth_service.dart';

/// Logging interceptor for Dio requests and responses
class LoggingInterceptor extends Interceptor {
  /// Creates a [LoggingInterceptor] with a logger
  LoggingInterceptor(this._logger);

  final Logger _logger;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    _logger.d(
      'REQUEST[${options.method}] => PATH: ${options.uri}\n'
      'Headers: ${options.headers}\n'
      'Data: ${options.data}',
    );
    super.onRequest(options, handler);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    _logger.i(
      'RESPONSE[${response.statusCode}] => PATH: ${response.requestOptions.uri}\n'
      'Data: ${response.data}',
    );
    super.onResponse(response, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _logger.e(
      'ERROR[${err.response?.statusCode}] => PATH: ${err.requestOptions.uri}\n'
      'Message: ${err.message}\n'
      'Response: ${err.response?.data}',
    );
    super.onError(err, handler);
  }
}

/// Authentication interceptor for adding auth tokens to requests
class AuthInterceptor extends Interceptor {
  /// Creates an [AuthInterceptor] with secure storage
  AuthInterceptor(this._secureStorage);

  final FlutterSecureStorage _secureStorage;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Get access token from secure storage
    final token = await _secureStorage.read(key: StorageKeys.accessToken);

    if (token != null && token.isNotEmpty) {
      // Add authorization header
      options.headers[ApiConstants.authorization] =
          '${ApiConstants.bearerPrefix} $token';
    }

    super.onRequest(options, handler);
  }
}

/// Error interceptor for handling common errors.
///
/// On 401: checks if the JWT is genuinely expired before forcing logout.
/// Transient 401s (server restart, network glitch) won't kill the session.
class ErrorInterceptor extends Interceptor {
  /// Creates an [ErrorInterceptor] with a logger
  ErrorInterceptor(this._logger);

  final Logger _logger;

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    // validateStatus accepts < 500 so 401 arrives here, not in onError.
    if (response.statusCode == ApiConstants.statusUnauthorized) {
      _logger.w('401 response on ${response.requestOptions.path}');
      _handleUnauthorized(response.data);
    }
    super.onResponse(response, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _logger.e(
      'Error occurred: ${err.type}\n'
      'Status code: ${err.response?.statusCode}\n'
      'Message: ${err.message}\n'
      'Response: ${err.response?.data}',
    );

    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        _logger.w('Timeout error occurred');
        break;

      case DioExceptionType.badResponse:
        final statusCode = err.response?.statusCode;
        if (statusCode == ApiConstants.statusUnauthorized) {
          _logger.w('401 error on ${err.requestOptions.path}');
          _handleUnauthorized(err.response?.data);
        } else if (statusCode == ApiConstants.statusForbidden) {
          _logger.w('Forbidden error - insufficient permissions');
        } else if (statusCode == ApiConstants.statusNotFound) {
          _logger.w('Not found error');
        }
        break;

      case DioExceptionType.cancel:
        _logger.w('Request was cancelled');
        break;

      case DioExceptionType.connectionError:
        _logger.w('Connection error - check network connectivity');
        break;

      case DioExceptionType.badCertificate:
        _logger.w('SSL certificate error');
        break;

      case DioExceptionType.unknown:
        _logger.w('Unknown error occurred');
        break;
    }

    super.onError(err, handler);
  }

  /// Only force logout when the token is genuinely expired or invalid.
  /// Transient server errors that happen to return 401 won't nuke the session.
  void _handleUnauthorized(dynamic responseData) {
    // Check if backend explicitly says "expired" or "sign in again"
    final message = _extractMessage(responseData);
    final isExpiredMessage = message.contains('expired') ||
        message.contains('sign in again') ||
        message.contains('Authentication required');

    if (isExpiredMessage && _isTokenExpired()) {
      _logger.w('Token confirmed expired — forcing logout');
      AuthService.forceLogout();
    } else if (_isTokenExpired()) {
      _logger.w('Token exp claim is past — forcing logout');
      AuthService.forceLogout();
    } else {
      _logger.w('401 but token not expired — ignoring (transient server error)');
    }
  }

  String _extractMessage(dynamic data) {
    if (data is Map<String, dynamic>) {
      return ((data['message'] ?? data['error'] ?? '') as Object).toString().toLowerCase();
    }
    return '';
  }

  /// Decode the stored JWT and check if the exp claim is in the past.
  bool _isTokenExpired() {
    try {
      // Read token synchronously from the auth header we already attached.
      // Since we can't await in interceptor, decode from the stored constant.
      // Actually, we'll check the last-known token via a sync helper.
      final token = AuthService.lastKnownToken;
      if (token == null || token.isEmpty) return true;

      final parts = token.split('.');
      if (parts.length != 3) return true;

      final normalized = base64Url.normalize(parts[1]);
      final payload = json.decode(utf8.decode(base64Url.decode(normalized)))
          as Map<String, dynamic>;
      final exp = payload['exp'] as int?;
      if (exp == null) return true;

      final expiry = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
      return DateTime.now().isAfter(expiry);
    } catch (e) {
      _logger.e('Error checking token expiry: $e');
      return true; // If we can't decode, treat as expired
    }
  }
}

/// Request ID interceptor for adding unique IDs to requests
class RequestIdInterceptor extends Interceptor {
  /// Creates a [RequestIdInterceptor]
  RequestIdInterceptor();

  int _requestId = 0;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    _requestId++;
    options.headers[ApiConstants.xRequestId] = 'req_$_requestId';
    super.onRequest(options, handler);
  }
}

/// Content type interceptor for setting default content type
class ContentTypeInterceptor extends Interceptor {
  /// Creates a [ContentTypeInterceptor]
  ContentTypeInterceptor();

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // Skip content-type for FormData — Dio sets multipart/form-data automatically
    if (options.data is! FormData &&
        !options.headers.containsKey(ApiConstants.contentType)) {
      options.headers[ApiConstants.contentType] =
          ApiConstants.applicationJson;
    }

    // Set default accept header if not already set
    if (!options.headers.containsKey(ApiConstants.accept)) {
      options.headers[ApiConstants.accept] = ApiConstants.applicationJson;
    }

    super.onRequest(options, handler);
  }
}
