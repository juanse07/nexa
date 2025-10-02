import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:nexa/core/domain/usecase.dart';
import 'package:nexa/core/errors/failures.dart';
import 'package:nexa/features/users/domain/entities/user.dart';
import 'package:nexa/features/users/domain/repositories/user_repository.dart';

/// Use case for updating an existing user.
class UpdateUser implements UseCase<User, UpdateUserParams> {
  /// Creates an [UpdateUser] use case.
  const UpdateUser(this.repository);

  /// The user repository
  final UserRepository repository;

  @override
  Future<Either<Failure, User>> call(UpdateUserParams params) async {
    // Validate user ID
    if (params.id.isEmpty) {
      return const Left(
        ValidationFailure('User ID cannot be empty'),
      );
    }

    // Validate user data
    final validationFailure = _validateUser(params.user);
    if (validationFailure != null) {
      return Left(validationFailure);
    }

    return repository.updateUser(params.id, params.user);
  }

  /// Validates the user data before update.
  ValidationFailure? _validateUser(User user) {
    final errors = <String, List<String>>{};

    if (user.firstName.trim().isEmpty) {
      errors['firstName'] = ['First name is required'];
    }

    if (user.lastName.trim().isEmpty) {
      errors['lastName'] = ['Last name is required'];
    }

    if (user.email != null && user.email!.isNotEmpty) {
      if (!_isValidEmail(user.email!)) {
        errors['email'] = ['Invalid email format'];
      }
    }

    if (errors.isNotEmpty) {
      return ValidationFailure('Invalid user data', errors);
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

/// Parameters for the [UpdateUser] use case.
class UpdateUserParams extends Equatable {
  /// Creates [UpdateUserParams].
  const UpdateUserParams({
    required this.id,
    required this.user,
  });

  /// The unique identifier of the user to update
  final String id;

  /// The updated user data
  final User user;

  @override
  List<Object?> get props => [id, user];
}
