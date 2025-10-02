import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logger/logger.dart';
import 'package:nexa/core/config/app_config.dart';
import 'package:nexa/core/constants/app_constants.dart';
import 'package:nexa/core/network/dio_interceptors.dart';

/// API client for making HTTP requests using Dio
class ApiClient {
  /// Creates an [ApiClient] with required dependencies
  ApiClient({
    required FlutterSecureStorage secureStorage,
    required Logger logger,
    Dio? dio,
  })  : _secureStorage = secureStorage,
        _logger = logger,
        _dio = dio ?? Dio() {
    _initializeDio();
  }

  final Dio _dio;
  final FlutterSecureStorage _secureStorage;
  final Logger _logger;

  /// Initializes Dio with base configuration and interceptors
  void _initializeDio() {
    final config = AppConfig.instance;

    _dio.options = BaseOptions(
      baseUrl: config.baseUrl,
      connectTimeout: const Duration(
        milliseconds: AppConstants.connectionTimeout,
      ),
      receiveTimeout: const Duration(
        milliseconds: AppConstants.receiveTimeout,
      ),
      sendTimeout: const Duration(
        milliseconds: AppConstants.sendTimeout,
      ),
      validateStatus: (status) {
        // Accept all status codes and let error handler deal with them
        return status != null && status < 500;
      },
    );

    // Add interceptors
    _dio.interceptors.addAll([
      ContentTypeInterceptor(),
      AuthInterceptor(_secureStorage),
      RequestIdInterceptor(),
      if (config.isDebugMode) LoggingInterceptor(_logger),
      ErrorInterceptor(_logger),
    ]);
  }

  /// Makes a GET request
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    void Function(int, int)? onReceiveProgress,
  }) async {
    try {
      final response = await _dio.get<T>(
        path,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
        onReceiveProgress: onReceiveProgress,
      );
      return response;
    } catch (e) {
      _logger.e('GET request failed: $path', error: e);
      rethrow;
    }
  }

  /// Makes a POST request
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    void Function(int, int)? onSendProgress,
    void Function(int, int)? onReceiveProgress,
  }) async {
    try {
      final response = await _dio.post<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
      );
      return response;
    } catch (e) {
      _logger.e('POST request failed: $path', error: e);
      rethrow;
    }
  }

  /// Makes a PUT request
  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    void Function(int, int)? onSendProgress,
    void Function(int, int)? onReceiveProgress,
  }) async {
    try {
      final response = await _dio.put<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
      );
      return response;
    } catch (e) {
      _logger.e('PUT request failed: $path', error: e);
      rethrow;
    }
  }

  /// Makes a PATCH request
  Future<Response<T>> patch<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    void Function(int, int)? onSendProgress,
    void Function(int, int)? onReceiveProgress,
  }) async {
    try {
      final response = await _dio.patch<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
      );
      return response;
    } catch (e) {
      _logger.e('PATCH request failed: $path', error: e);
      rethrow;
    }
  }

  /// Makes a DELETE request
  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.delete<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
      return response;
    } catch (e) {
      _logger.e('DELETE request failed: $path', error: e);
      rethrow;
    }
  }

  /// Downloads a file
  Future<Response<dynamic>> download(
    String urlPath,
    String savePath, {
    void Function(int, int)? onReceiveProgress,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
    bool deleteOnError = true,
    String lengthHeader = Headers.contentLengthHeader,
    Options? options,
  }) async {
    try {
      final response = await _dio.download(
        urlPath,
        savePath,
        onReceiveProgress: onReceiveProgress,
        queryParameters: queryParameters,
        cancelToken: cancelToken,
        deleteOnError: deleteOnError,
        lengthHeader: lengthHeader,
        options: options,
      );
      return response;
    } catch (e) {
      _logger.e('Download failed: $urlPath', error: e);
      rethrow;
    }
  }

  /// Updates the base URL
  void updateBaseUrl(String baseUrl) {
    _dio.options.baseUrl = baseUrl;
  }

  /// Adds a custom interceptor
  void addInterceptor(Interceptor interceptor) {
    _dio.interceptors.add(interceptor);
  }

  /// Removes an interceptor
  void removeInterceptor(Interceptor interceptor) {
    _dio.interceptors.remove(interceptor);
  }

  /// Clears all interceptors
  void clearInterceptors() {
    _dio.interceptors.clear();
  }

  /// Gets the underlying Dio instance
  Dio get dio => _dio;
}
