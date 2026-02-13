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

/// Error interceptor for handling common errors
class ErrorInterceptor extends Interceptor {
  /// Creates an [ErrorInterceptor] with a logger
  ErrorInterceptor(this._logger);

  final Logger _logger;

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // Log the error
    _logger.e(
      'Error occurred: ${err.type}\n'
      'Status code: ${err.response?.statusCode}\n'
      'Message: ${err.message}\n'
      'Response: ${err.response?.data}',
    );

    // Handle specific error cases
    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        _logger.w('Timeout error occurred');
        break;

      case DioExceptionType.badResponse:
        final statusCode = err.response?.statusCode;
        if (statusCode == ApiConstants.statusUnauthorized) {
          _logger.w('Unauthorized error - token expired, forcing logout');
          AuthService.forceLogout();
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
