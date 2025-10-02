import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:nexa/core/domain/usecase.dart';
import 'package:nexa/core/errors/failures.dart';
import 'package:nexa/features/auth/domain/repositories/auth_repository.dart';

/// Use case for sending a password reset email.
class SendPasswordResetEmail
    implements UseCase<void, SendPasswordResetEmailParams> {
  /// Creates a [SendPasswordResetEmail] use case.
  const SendPasswordResetEmail(this.repository);

  /// The authentication repository
  final AuthRepository repository;

  @override
  Future<Either<Failure, void>> call(
    SendPasswordResetEmailParams params,
  ) async {
    if (params.email.trim().isEmpty) {
      return const Left(
        ValidationFailure('Email cannot be empty'),
      );
    }
    if (!_isValidEmail(params.email)) {
      return const Left(
        ValidationFailure('Invalid email format'),
      );
    }
    return repository.sendPasswordResetEmail(params.email);
  }

  /// Validates email format.
  bool _isValidEmail(String email) {
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    return emailRegex.hasMatch(email);
  }
}

/// Parameters for the [SendPasswordResetEmail] use case.
class SendPasswordResetEmailParams extends Equatable {
  /// Creates [SendPasswordResetEmailParams].
  const SendPasswordResetEmailParams({required this.email});

  /// The user's email address
  final String email;

  @override
  List<Object?> get props => [email];
}
