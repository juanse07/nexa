import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:nexa/core/domain/usecase.dart';
import 'package:nexa/core/errors/failures.dart';
import 'package:nexa/features/roles/domain/repositories/role_repository.dart';

/// Use case for deleting a role.
class DeleteRole implements UseCase<void, DeleteRoleParams> {
  /// Creates a [DeleteRole] use case.
  const DeleteRole(this.repository);

  /// The role repository
  final RoleRepository repository;

  @override
  Future<Either<Failure, void>> call(DeleteRoleParams params) async {
    if (params.id.isEmpty) {
      return const Left(
        ValidationFailure('Role ID cannot be empty'),
      );
    }
    return repository.deleteRole(params.id);
  }
}

/// Parameters for the [DeleteRole] use case.
class DeleteRoleParams extends Equatable {
  /// Creates [DeleteRoleParams].
  const DeleteRoleParams({required this.id});

  /// The unique identifier of the role to delete
  final String id;

  @override
  List<Object?> get props => [id];
}
