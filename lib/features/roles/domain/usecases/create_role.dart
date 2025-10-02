import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:nexa/core/domain/usecase.dart';
import 'package:nexa/core/errors/failures.dart';
import 'package:nexa/features/roles/domain/entities/role.dart';
import 'package:nexa/features/roles/domain/repositories/role_repository.dart';

/// Use case for creating a new role.
class CreateRole implements UseCase<Role, CreateRoleParams> {
  /// Creates a [CreateRole] use case.
  const CreateRole(this.repository);

  /// The role repository
  final RoleRepository repository;

  @override
  Future<Either<Failure, Role>> call(CreateRoleParams params) async {
    // Validate role data
    final validationFailure = _validateRole(params.role);
    if (validationFailure != null) {
      return Left(validationFailure);
    }

    return repository.createRole(params.role);
  }

  /// Validates the role data before creation.
  ValidationFailure? _validateRole(Role role) {
    final errors = <String, List<String>>{};

    if (role.name.trim().isEmpty) {
      errors['name'] = ['Role name is required'];
    }

    if (errors.isNotEmpty) {
      return ValidationFailure('Invalid role data', errors);
    }

    return null;
  }
}

/// Parameters for the [CreateRole] use case.
class CreateRoleParams extends Equatable {
  /// Creates [CreateRoleParams].
  const CreateRoleParams({required this.role});

  /// The role to create
  final Role role;

  @override
  List<Object?> get props => [role];
}
