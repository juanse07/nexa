import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:nexa/core/domain/usecase.dart';
import 'package:nexa/core/errors/failures.dart';
import 'package:nexa/features/tariffs/domain/entities/tariff.dart';
import 'package:nexa/features/tariffs/domain/repositories/tariff_repository.dart';

/// Use case for retrieving tariffs with optional filtering.
class GetTariffs implements UseCase<List<Tariff>, GetTariffsParams> {
  /// Creates a [GetTariffs] use case.
  const GetTariffs(this.repository);

  /// The tariff repository
  final TariffRepository repository;

  @override
  Future<Either<Failure, List<Tariff>>> call(GetTariffsParams params) async {
    return repository.getTariffs(
      clientId: params.clientId,
      roleId: params.roleId,
    );
  }
}

/// Parameters for the [GetTariffs] use case.
class GetTariffsParams extends Equatable {
  /// Creates [GetTariffsParams].
  const GetTariffsParams({
    this.clientId,
    this.roleId,
  });

  /// Optional filter by client ID
  final String? clientId;

  /// Optional filter by role ID
  final String? roleId;

  @override
  List<Object?> get props => [clientId, roleId];
}
