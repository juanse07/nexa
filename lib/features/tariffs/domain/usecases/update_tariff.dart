import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:nexa/core/domain/usecase.dart';
import 'package:nexa/core/errors/failures.dart';
import 'package:nexa/features/tariffs/domain/entities/tariff.dart';
import 'package:nexa/features/tariffs/domain/repositories/tariff_repository.dart';

/// Use case for updating an existing tariff.
class UpdateTariff implements UseCase<Tariff, UpdateTariffParams> {
  /// Creates an [UpdateTariff] use case.
  const UpdateTariff(this.repository);

  /// The tariff repository
  final TariffRepository repository;

  @override
  Future<Either<Failure, Tariff>> call(UpdateTariffParams params) async {
    // Validate tariff ID
    if (params.id.isEmpty) {
      return const Left(
        ValidationFailure('Tariff ID cannot be empty'),
      );
    }

    // Validate tariff data
    final validationFailure = _validateTariff(params.tariff);
    if (validationFailure != null) {
      return Left(validationFailure);
    }

    return repository.updateTariff(params.id, params.tariff);
  }

  /// Validates the tariff data before update.
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

/// Parameters for the [UpdateTariff] use case.
class UpdateTariffParams extends Equatable {
  /// Creates [UpdateTariffParams].
  const UpdateTariffParams({
    required this.id,
    required this.tariff,
  });

  /// The unique identifier of the tariff to update
  final String id;

  /// The updated tariff data
  final Tariff tariff;

  @override
  List<Object?> get props => [id, tariff];
}
