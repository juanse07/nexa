import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:nexa/core/domain/usecase.dart';
import 'package:nexa/core/errors/failures.dart';
import 'package:nexa/features/auth/domain/repositories/auth_repository.dart';

/// Use case for changing the current user's password.
class ChangePassword implements UseCase<void, ChangePasswordParams> {
  /// Creates a [ChangePassword] use case.
  const ChangePassword(this.repository);

  /// The authentication repository
  final AuthRepository repository;

  @override
  Future<Either<Failure, void>> call(ChangePasswordParams params) async {
    // Validate password data
    final validationFailure = _validatePasswords(params);
    if (validationFailure != null) {
      return Left(validationFailure);
    }

    return repository.changePassword(
      currentPassword: params.currentPassword,
      newPassword: params.newPassword,
    );
  }

  /// Validates the password data.
  ValidationFailure? _validatePasswords(ChangePasswordParams params) {
    final errors = <String, List<String>>{};

    if (params.currentPassword.isEmpty) {
      errors['currentPassword'] = ['Current password is required'];
    }

    if (params.newPassword.isEmpty) {
      errors['newPassword'] = ['New password is required'];
    } else if (params.newPassword.length < 8) {
      errors['newPassword'] = ['Password must be at least 8 characters'];
    }

    if (params.currentPassword == params.newPassword) {
      errors['newPassword'] = ['New password must be different from current'];
    }

    if (errors.isNotEmpty) {
      return ValidationFailure('Invalid password data', errors);
    }

    return null;
  }
}

/// Parameters for the [ChangePassword] use case.
class ChangePasswordParams extends Equatable {
  /// Creates [ChangePasswordParams].
  const ChangePasswordParams({
    required this.currentPassword,
    required this.newPassword,
  });

  /// The current password
  final String currentPassword;

  /// The new password
  final String newPassword;

  @override
  List<Object?> get props => [currentPassword, newPassword];
}
