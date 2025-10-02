import 'package:dartz/dartz.dart';
import 'package:nexa/core/constants/app_constants.dart';
import 'package:nexa/core/constants/error_messages.dart';

/// Validation utilities for form fields
class Validators {
  Validators._();

  /// Validates that a field is not empty
  static Either<String, bool> required(String? value) {
    if (value == null || value.trim().isEmpty) {
      return const Left(ErrorMessages.requiredField);
    }
    return const Right(true);
  }

  /// Validates email format
  static Either<String, bool> email(String? value) {
    final requiredResult = required(value);
    if (requiredResult.isLeft()) {
      return requiredResult;
    }

    final emailRegex = RegExp(AppConstants.emailRegex);
    if (!emailRegex.hasMatch(value!)) {
      return const Left(ErrorMessages.invalidEmail);
    }

    return const Right(true);
  }

  /// Validates phone number format
  static Either<String, bool> phone(String? value) {
    final requiredResult = required(value);
    if (requiredResult.isLeft()) {
      return requiredResult;
    }

    final phoneRegex = RegExp(AppConstants.phoneRegex);
    if (!phoneRegex.hasMatch(value!)) {
      return const Left(ErrorMessages.invalidPhone);
    }

    return const Right(true);
  }

  /// Validates URL format
  static Either<String, bool> url(String? value) {
    final requiredResult = required(value);
    if (requiredResult.isLeft()) {
      return requiredResult;
    }

    final urlRegex = RegExp(AppConstants.urlRegex);
    if (!urlRegex.hasMatch(value!)) {
      return const Left(ErrorMessages.invalidUrl);
    }

    return const Right(true);
  }

  /// Validates minimum length
  static Either<String, bool> minLength(String? value, int length) {
    final requiredResult = required(value);
    if (requiredResult.isLeft()) {
      return requiredResult;
    }

    if (value!.length < length) {
      return Left('Must be at least $length characters long');
    }

    return const Right(true);
  }

  /// Validates maximum length
  static Either<String, bool> maxLength(String? value, int length) {
    final requiredResult = required(value);
    if (requiredResult.isLeft()) {
      return requiredResult;
    }

    if (value!.length > length) {
      return Left('Must be at most $length characters long');
    }

    return const Right(true);
  }

  /// Validates length range
  static Either<String, bool> lengthRange(
    String? value,
    int minLen,
    int maxLen,
  ) {
    final requiredResult = required(value);
    if (requiredResult.isLeft()) {
      return requiredResult;
    }

    if (value!.length < minLen) {
      return Left('Must be at least $minLen characters long');
    }

    if (value.length > maxLen) {
      return Left('Must be at most $maxLen characters long');
    }

    return const Right(true);
  }

  /// Validates password strength
  static Either<String, bool> password(String? value) {
    final lengthResult = minLength(value, AppConstants.minPasswordLength);
    if (lengthResult.isLeft()) {
      return const Left(ErrorMessages.passwordTooShort);
    }

    // Check for at least one uppercase letter
    if (!value!.contains(RegExp('[A-Z]'))) {
      return const Left(
        'Password must contain at least one uppercase letter',
      );
    }

    // Check for at least one lowercase letter
    if (!value.contains(RegExp('[a-z]'))) {
      return const Left(
        'Password must contain at least one lowercase letter',
      );
    }

    // Check for at least one digit
    if (!value.contains(RegExp('[0-9]'))) {
      return const Left('Password must contain at least one digit');
    }

    // Check for at least one special character
    if (!value.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
      return const Left(
        'Password must contain at least one special character',
      );
    }

    return const Right(true);
  }

  /// Validates that two values match
  static Either<String, bool> matches(String? value, String? matchValue) {
    final requiredResult = required(value);
    if (requiredResult.isLeft()) {
      return requiredResult;
    }

    if (value != matchValue) {
      return const Left('Values do not match');
    }

    return const Right(true);
  }

  /// Validates numeric value
  static Either<String, bool> numeric(String? value) {
    final requiredResult = required(value);
    if (requiredResult.isLeft()) {
      return requiredResult;
    }

    if (num.tryParse(value!) == null) {
      return const Left('Must be a valid number');
    }

    return const Right(true);
  }

  /// Validates integer value
  static Either<String, bool> integer(String? value) {
    final requiredResult = required(value);
    if (requiredResult.isLeft()) {
      return requiredResult;
    }

    if (int.tryParse(value!) == null) {
      return const Left('Must be a valid integer');
    }

    return const Right(true);
  }

  /// Validates minimum value
  static Either<String, bool> min(String? value, num minValue) {
    final numericResult = numeric(value);
    if (numericResult.isLeft()) {
      return numericResult;
    }

    final numValue = num.parse(value!);
    if (numValue < minValue) {
      return Left('Must be at least $minValue');
    }

    return const Right(true);
  }

  /// Validates maximum value
  static Either<String, bool> max(String? value, num maxValue) {
    final numericResult = numeric(value);
    if (numericResult.isLeft()) {
      return numericResult;
    }

    final numValue = num.parse(value!);
    if (numValue > maxValue) {
      return Left('Must be at most $maxValue');
    }

    return const Right(true);
  }

  /// Validates value range
  static Either<String, bool> range(
    String? value,
    num minValue,
    num maxValue,
  ) {
    final numericResult = numeric(value);
    if (numericResult.isLeft()) {
      return numericResult;
    }

    final numValue = num.parse(value!);
    if (numValue < minValue || numValue > maxValue) {
      return Left('Must be between $minValue and $maxValue');
    }

    return const Right(true);
  }

  /// Validates using a custom pattern
  static Either<String, bool> pattern(String? value, RegExp pattern) {
    final requiredResult = required(value);
    if (requiredResult.isLeft()) {
      return requiredResult;
    }

    if (!pattern.hasMatch(value!)) {
      return const Left(ErrorMessages.invalidFormat);
    }

    return const Right(true);
  }

  /// Combines multiple validators
  static Either<String, bool> combine(
    String? value,
    List<Either<String, bool> Function(String?)> validators,
  ) {
    for (final validator in validators) {
      final result = validator(value);
      if (result.isLeft()) {
        return result;
      }
    }
    return const Right(true);
  }

  /// Validates optional field (returns Right if null or empty)
  static Either<String, bool> optional(
    String? value,
    Either<String, bool> Function(String?) validator,
  ) {
    if (value == null || value.trim().isEmpty) {
      return const Right(true);
    }
    return validator(value);
  }
}
