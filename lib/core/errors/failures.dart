import 'package:equatable/equatable.dart';
import 'package:nexa/core/constants/error_messages.dart';

/// Base failure class for error handling using dartz
abstract class Failure extends Equatable {
  /// Creates a [Failure] with a message and optional properties
  const Failure(this.message, [this.properties = const <dynamic>[]]);

  /// The error message
  final String message;

  /// Additional properties for debugging
  final List<dynamic> properties;

  @override
  List<Object?> get props => [message, ...properties];

  @override
  String toString() => '$runtimeType: $message';
}

/// Failure for server-related errors
class ServerFailure extends Failure {
  /// Creates a [ServerFailure] with an optional message and status code
  const ServerFailure([
    String message = ErrorMessages.serverNotResponding,
    this.statusCode,
  ]) : super(message, [statusCode]);

  /// The HTTP status code
  final int? statusCode;

  @override
  List<Object?> get props => [message, statusCode];
}

/// Failure for network-related errors
class NetworkFailure extends Failure {
  /// Creates a [NetworkFailure] with an optional message
  const NetworkFailure([
    String message = ErrorMessages.noInternetConnection,
  ]) : super(message);
}

/// Failure for cache-related errors
class CacheFailure extends Failure {
  /// Creates a [CacheFailure] with an optional message
  const CacheFailure([
    String message = ErrorMessages.cacheError,
  ]) : super(message);
}

/// Failure for validation errors
class ValidationFailure extends Failure {
  /// Creates a [ValidationFailure] with an optional message and errors map
  const ValidationFailure([
    String message = ErrorMessages.invalidData,
    this.errors,
  ]) : super(message, [errors]);

  /// Map of field names to validation error messages
  final Map<String, List<String>>? errors;

  @override
  List<Object?> get props => [message, errors];

  /// Gets validation errors for a specific field
  List<String>? getFieldErrors(String field) => errors?[field];

  /// Checks if there are errors for a specific field
  bool hasFieldErrors(String field) =>
      errors != null && errors!.containsKey(field);
}

/// Failure for authentication errors
class UnauthorizedFailure extends Failure {
  /// Creates an [UnauthorizedFailure] with an optional message
  const UnauthorizedFailure([
    String message = ErrorMessages.unauthorized,
  ]) : super(message);
}

/// Failure for forbidden access errors
class ForbiddenFailure extends Failure {
  /// Creates a [ForbiddenFailure] with an optional message
  const ForbiddenFailure([
    String message = ErrorMessages.unauthorized,
  ]) : super(message);
}

/// Failure for resource not found errors
class NotFoundFailure extends Failure {
  /// Creates a [NotFoundFailure] with an optional message
  const NotFoundFailure([
    String message = ErrorMessages.notFound,
  ]) : super(message);
}

/// Failure for conflict errors
class ConflictFailure extends Failure {
  /// Creates a [ConflictFailure] with an optional message
  const ConflictFailure([
    String message = ErrorMessages.conflictError,
  ]) : super(message);
}

/// Failure for timeout errors
class TimeoutFailure extends Failure {
  /// Creates a [TimeoutFailure] with an optional message
  const TimeoutFailure([
    String message = ErrorMessages.connectionTimeout,
  ]) : super(message);
}

/// Failure for cancelled requests
class CancelledFailure extends Failure {
  /// Creates a [CancelledFailure] with an optional message
  const CancelledFailure([
    String message = ErrorMessages.requestCancelled,
  ]) : super(message);
}

/// Failure for parsing errors
class ParseFailure extends Failure {
  /// Creates a [ParseFailure] with an optional message
  const ParseFailure([
    String message = ErrorMessages.invalidData,
  ]) : super(message);
}

/// Failure for file operation errors
class FileFailure extends Failure {
  /// Creates a [FileFailure] with an optional message
  const FileFailure([
    String message = ErrorMessages.fileNotFound,
  ]) : super(message);
}

/// Failure for permission errors
class PermissionFailure extends Failure {
  /// Creates a [PermissionFailure] with an optional message
  const PermissionFailure([
    String message = ErrorMessages.permissionDenied,
  ]) : super(message);
}

/// Failure for too many requests errors
class TooManyRequestsFailure extends Failure {
  /// Creates a [TooManyRequestsFailure] with an optional message
  const TooManyRequestsFailure([
    String message = ErrorMessages.somethingWentWrong,
  ]) : super(message);
}

/// Generic failure for unexpected errors
class UnexpectedFailure extends Failure {
  /// Creates an [UnexpectedFailure] with an optional message
  const UnexpectedFailure([
    String message = ErrorMessages.unexpectedError,
  ]) : super(message);
}
