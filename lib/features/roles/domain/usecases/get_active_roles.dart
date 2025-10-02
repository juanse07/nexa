import 'package:dartz/dartz.dart';
import 'package:nexa/core/domain/usecase.dart';
import 'package:nexa/core/errors/failures.dart';
import 'package:nexa/features/roles/domain/entities/role.dart';
import 'package:nexa/features/roles/domain/repositories/role_repository.dart';

/// Use case for retrieving active roles only.
class GetActiveRoles implements UseCase<List<Role>, NoParams> {
  /// Creates a [GetActiveRoles] use case.
  const GetActiveRoles(this.repository);

  /// The role repository
  final RoleRepository repository;

  @override
  Future<Either<Failure, List<Role>>> call(NoParams params) async {
    return repository.getActiveRoles();
  }
}
