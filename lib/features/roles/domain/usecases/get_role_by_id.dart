import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:nexa/core/domain/usecase.dart';
import 'package:nexa/core/errors/failures.dart';
import 'package:nexa/features/roles/domain/entities/role.dart';
import 'package:nexa/features/roles/domain/repositories/role_repository.dart';

/// Use case for retrieving a single role by its ID.
class GetRoleById implements UseCase<Role, GetRoleByIdParams> {
  /// Creates a [GetRoleById] use case.
  const GetRoleById(this.repository);

  /// The role repository
  final RoleRepository repository;

  @override
  Future<Either<Failure, Role>> call(GetRoleByIdParams params) async {
    if (params.id.isEmpty) {
      return const Left(
        ValidationFailure('Role ID cannot be empty'),
      );
    }
    return repository.getRoleById(params.id);
  }
}

/// Parameters for the [GetRoleById] use case.
class GetRoleByIdParams extends Equatable {
  /// Creates [GetRoleByIdParams].
  const GetRoleByIdParams({required this.id});

  /// The unique identifier of the role
  final String id;

  @override
  List<Object?> get props => [id];
}
