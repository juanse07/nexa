import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:nexa/core/domain/usecase.dart';
import 'package:nexa/core/errors/failures.dart';
import 'package:nexa/features/tariffs/domain/entities/tariff.dart';
import 'package:nexa/features/tariffs/domain/repositories/tariff_repository.dart';

/// Use case for retrieving a single tariff by its ID.
class GetTariffById implements UseCase<Tariff, GetTariffByIdParams> {
  /// Creates a [GetTariffById] use case.
  const GetTariffById(this.repository);

  /// The tariff repository
  final TariffRepository repository;

  @override
  Future<Either<Failure, Tariff>> call(GetTariffByIdParams params) async {
    if (params.id.isEmpty) {
      return const Left(
        ValidationFailure('Tariff ID cannot be empty'),
      );
    }
    return repository.getTariffById(params.id);
  }
}

/// Parameters for the [GetTariffById] use case.
class GetTariffByIdParams extends Equatable {
  /// Creates [GetTariffByIdParams].
  const GetTariffByIdParams({required this.id});

  /// The unique identifier of the tariff
  final String id;

  @override
  List<Object?> get props => [id];
}
