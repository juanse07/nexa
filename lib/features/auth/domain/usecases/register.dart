import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:nexa/core/domain/usecase.dart';
import 'package:nexa/core/errors/failures.dart';
import 'package:nexa/features/auth/domain/entities/auth_user.dart';
import 'package:nexa/features/auth/domain/repositories/auth_repository.dart';

/// Use case for registering a new user.
class Register implements UseCase<AuthUser, RegisterParams> {
  /// Creates a [Register] use case.
  const Register(this.repository);

  /// The authentication repository
  final AuthRepository repository;

  @override
  Future<Either<Failure, AuthUser>> call(RegisterParams params) async {
    // Validate registration data
    final validationFailure = _validateRegistration(params);
    if (validationFailure != null) {
      return Left(validationFailure);
    }

    return repository.register(
      email: params.email,
      password: params.password,
      displayName: params.displayName,
    );
  }

  /// Validates the registration data.
  ValidationFailure? _validateRegistration(RegisterParams params) {
    final errors = <String, List<String>>{};

    if (params.email.trim().isEmpty) {
      errors['email'] = ['Email is required'];
    } else if (!_isValidEmail(params.email)) {
      errors['email'] = ['Invalid email format'];
    }

    if (params.password.isEmpty) {
      errors['password'] = ['Password is required'];
    } else if (params.password.length < 8) {
      errors['password'] = ['Password must be at least 8 characters'];
    }

    if (errors.isNotEmpty) {
      return ValidationFailure('Invalid registration data', errors);
    }

    return null;
  }

  /// Validates email format.
  bool _isValidEmail(String email) {
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    return emailRegex.hasMatch(email);
  }
}

/// Parameters for the [Register] use case.
class RegisterParams extends Equatable {
  /// Creates [RegisterParams].
  const RegisterParams({
    required this.email,
    required this.password,
    this.displayName,
  });

  /// User's email address
  final String email;

  /// User's password
  final String password;

  /// Optional display name
  final String? displayName;

  @override
  List<Object?> get props => [email, password, displayName];
}
