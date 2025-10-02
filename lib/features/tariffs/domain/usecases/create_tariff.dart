import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:nexa/core/domain/usecase.dart';
import 'package:nexa/core/errors/failures.dart';
import 'package:nexa/features/tariffs/domain/entities/tariff.dart';
import 'package:nexa/features/tariffs/domain/repositories/tariff_repository.dart';

/// Use case for creating a new tariff.
class CreateTariff implements UseCase<Tariff, CreateTariffParams> {
  /// Creates a [CreateTariff] use case.
  const CreateTariff(this.repository);

  /// The tariff repository
  final TariffRepository repository;

  @override
  Future<Either<Failure, Tariff>> call(CreateTariffParams params) async {
    // Validate tariff data
    final validationFailure = _validateTariff(params.tariff);
    if (validationFailure != null) {
      return Left(validationFailure);
    }

    return repository.createTariff(params.tariff);
  }

  /// Validates the tariff data before creation.
  ValidationFailure? _validateTariff(Tariff tariff) {
    final errors = <String, List<String>>{};

    if (tariff.clientId.trim().isEmpty) {
      errors['clientId'] = ['Client is required'];
    }

    if (tariff.roleId.trim().isEmpty) {
      errors['roleId'] = ['Role is required'];
    }

    if (tariff.rate <= 0) {
      errors['rate'] = ['Rate must be greater than zero'];
    }

    if (tariff.effectiveFrom != null && tariff.effectiveTo != null) {
      if (tariff.effectiveTo!.isBefore(tariff.effectiveFrom!)) {
        errors['effectiveTo'] = ['End date must be after start date'];
      }
    }

    if (errors.isNotEmpty) {
      return ValidationFailure('Invalid tariff data', errors);
    }

    return null;
  }
}

/// Parameters for the [CreateTariff] use case.
class CreateTariffParams extends Equatable {
  /// Creates [CreateTariffParams].
  const CreateTariffParams({required this.tariff});

  /// The tariff to create
  final Tariff tariff;

  @override
  List<Object?> get props => [tariff];
}
