import 'package:dartz/dartz.dart';
import 'package:nexa/core/domain/usecase.dart';
import 'package:nexa/core/errors/failures.dart';
import 'package:nexa/features/roles/domain/entities/role.dart';
import 'package:nexa/features/roles/domain/repositories/role_repository.dart';

/// Use case for retrieving all roles.
class GetRoles implements UseCase<List<Role>, NoParams> {
  /// Creates a [GetRoles] use case.
  const GetRoles(this.repository);

  /// The role repository
  final RoleRepository repository;

  @override
  Future<Either<Failure, List<Role>>> call(NoParams params) async {
    return repository.getRoles();
  }
}
