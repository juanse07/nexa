/// Base exception class for all custom exceptions
abstract class AppException implements Exception {
  /// Creates an [AppException] with an optional message and status code
  const AppException([this.message, this.statusCode]);

  /// The error message
  final String? message;

  /// The HTTP status code (if applicable)
  final int? statusCode;

  @override
  String toString() {
    if (message != null) {
      return 'AppException: $message${statusCode != null ? ' (Status: $statusCode)' : ''}';
    }
    return 'AppException${statusCode != null ? ' (Status: $statusCode)' : ''}';
  }
}

/// Exception thrown when a server error occurs
class ServerException extends AppException {
  /// Creates a [ServerException] with an optional message and status code
  const ServerException([super.message, super.statusCode]);

  @override
  String toString() {
    if (message != null) {
      return 'ServerException: $message${statusCode != null ? ' (Status: $statusCode)' : ''}';
    }
    return 'ServerException${statusCode != null ? ' (Status: $statusCode)' : ''}';
  }
}

/// Exception thrown when a network error occurs
class NetworkException extends AppException {
  /// Creates a [NetworkException] with an optional message
  const NetworkException([super.message]);

  @override
  String toString() {
    if (message != null) {
      return 'NetworkException: $message';
    }
    return 'NetworkException';
  }
}

/// Exception thrown when a cache operation fails
class CacheException extends AppException {
  /// Creates a [CacheException] with an optional message
  const CacheException([super.message]);

  @override
  String toString() {
    if (message != null) {
      return 'CacheException: $message';
    }
    return 'CacheException';
  }
}

/// Exception thrown when validation fails
class ValidationException extends AppException {
  /// Creates a [ValidationException] with an optional message and errors map
  const ValidationException([super.message, this.errors]);

  /// Map of field names to validation error messages
  final Map<String, List<String>>? errors;

  @override
  String toString() {
    if (message != null) {
      return 'ValidationException: $message${errors != null ? ' Errors: $errors' : ''}';
    }
    return 'ValidationException${errors != null ? ' Errors: $errors' : ''}';
  }
}

/// Exception thrown when authentication fails
class UnauthorizedException extends AppException {
  /// Creates an [UnauthorizedException] with an optional message
  const UnauthorizedException([String? message]) : super(message, 401);

  @override
  String toString() {
    if (message != null) {
      return 'UnauthorizedException: $message';
    }
    return 'UnauthorizedException';
  }
}

/// Exception thrown when access is forbidden
class ForbiddenException extends AppException {
  /// Creates a [ForbiddenException] with an optional message
  const ForbiddenException([String? message]) : super(message, 403);

  @override
  String toString() {
    if (message != null) {
      return 'ForbiddenException: $message';
    }
    return 'ForbiddenException';
  }
}

/// Exception thrown when a resource is not found
class NotFoundException extends AppException {
  /// Creates a [NotFoundException] with an optional message
  const NotFoundException([String? message]) : super(message, 404);

  @override
  String toString() {
    if (message != null) {
      return 'NotFoundException: $message';
    }
    return 'NotFoundException';
  }
}

/// Exception thrown when a conflict occurs
class ConflictException extends AppException {
  /// Creates a [ConflictException] with an optional message
  const ConflictException([String? message]) : super(message, 409);

  @override
  String toString() {
    if (message != null) {
      return 'ConflictException: $message';
    }
    return 'ConflictException';
  }
}

/// Exception thrown when too many requests are made
class TooManyRequestsException extends AppException {
  /// Creates a [TooManyRequestsException] with an optional message
  const TooManyRequestsException([String? message]) : super(message, 429);

  @override
  String toString() {
    if (message != null) {
      return 'TooManyRequestsException: $message';
    }
    return 'TooManyRequestsException';
  }
}

/// Exception thrown when a timeout occurs
class TimeoutException extends AppException {
  /// Creates a [TimeoutException] with an optional message
  const TimeoutException([super.message]);

  @override
  String toString() {
    if (message != null) {
      return 'TimeoutException: $message';
    }
    return 'TimeoutException';
  }
}

/// Exception thrown when a request is cancelled
class CancelledException extends AppException {
  /// Creates a [CancelledException] with an optional message
  const CancelledException([super.message]);

  @override
  String toString() {
    if (message != null) {
      return 'CancelledException: $message';
    }
    return 'CancelledException';
  }
}

/// Exception thrown when parsing fails
class ParseException extends AppException {
  /// Creates a [ParseException] with an optional message
  const ParseException([super.message]);

  @override
  String toString() {
    if (message != null) {
      return 'ParseException: $message';
    }
    return 'ParseException';
  }
}

/// Exception thrown when a file operation fails
class FileException extends AppException {
  /// Creates a [FileException] with an optional message
  const FileException([super.message]);

  @override
  String toString() {
    if (message != null) {
      return 'FileException: $message';
    }
    return 'FileException';
  }
}

/// Exception thrown when a permission is denied
class PermissionException extends AppException {
  /// Creates a [PermissionException] with an optional message
  const PermissionException([super.message]);

  @override
  String toString() {
    if (message != null) {
      return 'PermissionException: $message';
    }
    return 'PermissionException';
  }
}
