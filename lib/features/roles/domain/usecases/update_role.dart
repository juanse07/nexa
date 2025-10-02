import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:nexa/core/domain/usecase.dart';
import 'package:nexa/core/errors/failures.dart';
import 'package:nexa/features/roles/domain/entities/role.dart';
import 'package:nexa/features/roles/domain/repositories/role_repository.dart';

/// Use case for updating an existing role.
class UpdateRole implements UseCase<Role, UpdateRoleParams> {
  /// Creates an [UpdateRole] use case.
  const UpdateRole(this.repository);

  /// The role repository
  final RoleRepository repository;

  @override
  Future<Either<Failure, Role>> call(UpdateRoleParams params) async {
    // Validate role ID
    if (params.id.isEmpty) {
      return const Left(
        ValidationFailure('Role ID cannot be empty'),
      );
    }

    // Validate role data
    final validationFailure = _validateRole(params.role);
    if (validationFailure != null) {
      return Left(validationFailure);
    }

    return repository.updateRole(params.id, params.role);
  }

  /// Validates the role data before update.
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

/// Parameters for the [UpdateRole] use case.
class UpdateRoleParams extends Equatable {
  /// Creates [UpdateRoleParams].
  const UpdateRoleParams({
    required this.id,
    required this.role,
  });

  /// The unique identifier of the role to update
  final String id;

  /// The updated role data
  final Role role;

  @override
  List<Object?> get props => [id, role];
}
