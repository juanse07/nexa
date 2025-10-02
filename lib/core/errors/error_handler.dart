import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:nexa/core/constants/api_constants.dart';
import 'package:nexa/core/constants/error_messages.dart';
import 'package:nexa/core/errors/exceptions.dart';
import 'package:nexa/core/errors/failures.dart';

/// Error handler utility class
/// Converts exceptions to failures for consistent error handling
class ErrorHandler {
  ErrorHandler._();

  /// Handles errors and converts exceptions to failures
  static Failure handleError(Object error, [StackTrace? stackTrace]) {
    if (error is ServerException) {
      return ServerFailure(
        error.message ?? ErrorMessages.serverNotResponding,
        error.statusCode,
      );
    } else if (error is NetworkException) {
      return NetworkFailure(
        error.message ?? ErrorMessages.noInternetConnection,
      );
    } else if (error is CacheException) {
      return CacheFailure(
        error.message ?? ErrorMessages.cacheError,
      );
    } else if (error is ValidationException) {
      return ValidationFailure(
        error.message ?? ErrorMessages.invalidData,
        error.errors,
      );
    } else if (error is UnauthorizedException) {
      return UnauthorizedFailure(
        error.message ?? ErrorMessages.unauthorized,
      );
    } else if (error is ForbiddenException) {
      return ForbiddenFailure(
        error.message ?? ErrorMessages.unauthorized,
      );
    } else if (error is NotFoundException) {
      return NotFoundFailure(
        error.message ?? ErrorMessages.notFound,
      );
    } else if (error is ConflictException) {
      return ConflictFailure(
        error.message ?? ErrorMessages.conflictError,
      );
    } else if (error is TooManyRequestsException) {
      return const TooManyRequestsFailure();
    } else if (error is TimeoutException) {
      return TimeoutFailure(
        error.message ?? ErrorMessages.connectionTimeout,
      );
    } else if (error is CancelledException) {
      return CancelledFailure(
        error.message ?? ErrorMessages.requestCancelled,
      );
    } else if (error is ParseException) {
      return ParseFailure(
        error.message ?? ErrorMessages.invalidData,
      );
    } else if (error is FileException) {
      return FileFailure(
        error.message ?? ErrorMessages.fileNotFound,
      );
    } else if (error is PermissionException) {
      return PermissionFailure(
        error.message ?? ErrorMessages.permissionDenied,
      );
    } else if (error is DioException) {
      return handleDioError(error);
    } else if (error is SocketException) {
      return const NetworkFailure(ErrorMessages.noInternetConnection);
    } else if (error is FormatException) {
      return const ParseFailure(ErrorMessages.invalidData);
    } else {
      return UnexpectedFailure(
        error.toString(),
      );
    }
  }

  /// Handles Dio-specific errors
  static Failure handleDioError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const TimeoutFailure(ErrorMessages.connectionTimeout);

      case DioExceptionType.badResponse:
        return _handleStatusCode(error);

      case DioExceptionType.cancel:
        return const CancelledFailure(ErrorMessages.requestCancelled);

      case DioExceptionType.connectionError:
        return const NetworkFailure(ErrorMessages.noInternetConnection);

      case DioExceptionType.badCertificate:
        return const NetworkFailure('SSL certificate error');

      case DioExceptionType.unknown:
        if (error.error is SocketException) {
          return const NetworkFailure(ErrorMessages.noInternetConnection);
        }
        return UnexpectedFailure(
          error.message ?? ErrorMessages.unexpectedError,
        );
    }
  }

  /// Handles HTTP status codes from Dio responses
  static Failure _handleStatusCode(DioException error) {
    final statusCode = error.response?.statusCode;
    final message = _extractErrorMessage(error.response?.data);

    switch (statusCode) {
      case ApiConstants.statusBadRequest:
        return ValidationFailure(
          message ?? ErrorMessages.invalidData,
          _extractValidationErrors(error.response?.data),
        );

      case ApiConstants.statusUnauthorized:
        return UnauthorizedFailure(
          message ?? ErrorMessages.unauthorized,
        );

      case ApiConstants.statusForbidden:
        return ForbiddenFailure(
          message ?? ErrorMessages.unauthorized,
        );

      case ApiConstants.statusNotFound:
        return NotFoundFailure(
          message ?? ErrorMessages.notFound,
        );

      case ApiConstants.statusConflict:
        return ConflictFailure(
          message ?? ErrorMessages.conflictError,
        );

      case ApiConstants.statusUnprocessableEntity:
        return ValidationFailure(
          message ?? ErrorMessages.invalidData,
          _extractValidationErrors(error.response?.data),
        );

      case ApiConstants.statusTooManyRequests:
        return TooManyRequestsFailure(
          message ?? 'Too many requests. Please try again later.',
        );

      case ApiConstants.statusInternalServerError:
      case ApiConstants.statusBadGateway:
      case ApiConstants.statusServiceUnavailable:
      case ApiConstants.statusGatewayTimeout:
        return ServerFailure(
          message ?? ErrorMessages.serverNotResponding,
          statusCode,
        );

      default:
        return ServerFailure(
          message ?? ErrorMessages.unexpectedError,
          statusCode,
        );
    }
  }

  /// Extracts error message from response data
  static String? _extractErrorMessage(dynamic data) {
    if (data == null) return null;

    if (data is Map<String, dynamic>) {
      // Try different common error message keys
      if (data.containsKey(ApiConstants.messageKey)) {
        return data[ApiConstants.messageKey]?.toString();
      }
      if (data.containsKey(ApiConstants.errorKey)) {
        final error = data[ApiConstants.errorKey];
        if (error is String) return error;
        if (error is Map && error.containsKey(ApiConstants.messageKey)) {
          return error[ApiConstants.messageKey]?.toString();
        }
      }
    }

    return null;
  }

  /// Extracts validation errors from response data
  static Map<String, List<String>>? _extractValidationErrors(dynamic data) {
    if (data == null) return null;

    if (data is Map<String, dynamic>) {
      if (data.containsKey(ApiConstants.errorsKey)) {
        final errors = data[ApiConstants.errorsKey];
        if (errors is Map<String, dynamic>) {
          final Map<String, List<String>> result = {};
          errors.forEach((key, value) {
            if (value is List) {
              result[key] = value.map((e) => e.toString()).toList();
            } else if (value is String) {
              result[key] = [value];
            }
          });
          return result.isNotEmpty ? result : null;
        }
      }
    }

    return null;
  }

  /// Gets a user-friendly error message from a failure
  static String getUserFriendlyMessage(Failure failure) {
    if (failure is ValidationFailure && failure.errors != null) {
      final firstError = failure.errors!.values.first.first;
      return firstError;
    }
    return failure.message;
  }

  /// Wraps a function call in try-catch and converts to Either
  static Future<Either<Failure, T>> callApi<T>(
    Future<T> Function() apiCall,
  ) async {
    try {
      final result = await apiCall();
      return Right(result);
    } catch (error, stackTrace) {
      return Left(handleError(error, stackTrace));
    }
  }
}
