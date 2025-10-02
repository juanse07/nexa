import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:nexa/core/domain/usecase.dart';
import 'package:nexa/core/errors/failures.dart';
import 'package:nexa/features/tariffs/domain/repositories/tariff_repository.dart';

/// Use case for deleting a tariff.
class DeleteTariff implements UseCase<void, DeleteTariffParams> {
  /// Creates a [DeleteTariff] use case.
  const DeleteTariff(this.repository);

  /// The tariff repository
  final TariffRepository repository;

  @override
  Future<Either<Failure, void>> call(DeleteTariffParams params) async {
    if (params.id.isEmpty) {
      return const Left(
        ValidationFailure('Tariff ID cannot be empty'),
      );
    }
    return repository.deleteTariff(params.id);
  }
}

/// Parameters for the [DeleteTariff] use case.
class DeleteTariffParams extends Equatable {
  /// Creates [DeleteTariffParams].
  const DeleteTariffParams({required this.id});

  /// The unique identifier of the tariff to delete
  final String id;

  @override
  List<Object?> get props => [id];
}
