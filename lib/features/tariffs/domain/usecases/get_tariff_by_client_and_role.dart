import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:nexa/core/domain/usecase.dart';
import 'package:nexa/core/errors/failures.dart';
import 'package:nexa/features/tariffs/domain/entities/tariff.dart';
import 'package:nexa/features/tariffs/domain/repositories/tariff_repository.dart';

/// Use case for retrieving a tariff by client and role combination.
class GetTariffByClientAndRole
    implements UseCase<Tariff, GetTariffByClientAndRoleParams> {
  /// Creates a [GetTariffByClientAndRole] use case.
  const GetTariffByClientAndRole(this.repository);

  /// The tariff repository
  final TariffRepository repository;

  @override
  Future<Either<Failure, Tariff>> call(
    GetTariffByClientAndRoleParams params,
  ) async {
    if (params.clientId.isEmpty) {
      return const Left(
        ValidationFailure('Client ID cannot be empty'),
      );
    }
    if (params.roleId.isEmpty) {
      return const Left(
        ValidationFailure('Role ID cannot be empty'),
      );
    }
    return repository.getTariffByClientAndRole(params.clientId, params.roleId);
  }
}

/// Parameters for the [GetTariffByClientAndRole] use case.
class GetTariffByClientAndRoleParams extends Equatable {
  /// Creates [GetTariffByClientAndRoleParams].
  const GetTariffByClientAndRoleParams({
    required this.clientId,
    required this.roleId,
  });

  /// The client identifier
  final String clientId;

  /// The role identifier
  final String roleId;

  @override
  List<Object?> get props => [clientId, roleId];
}
