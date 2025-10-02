import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:nexa/core/domain/usecase.dart';
import 'package:nexa/core/errors/failures.dart';
import 'package:nexa/features/clients/domain/entities/client.dart';
import 'package:nexa/features/clients/domain/repositories/client_repository.dart';

/// Use case for updating an existing client.
class UpdateClient implements UseCase<Client, UpdateClientParams> {
  /// Creates an [UpdateClient] use case.
  const UpdateClient(this.repository);

  /// The client repository
  final ClientRepository repository;

  @override
  Future<Either<Failure, Client>> call(UpdateClientParams params) async {
    // Validate client ID
    if (params.id.isEmpty) {
      return const Left(
        ValidationFailure('Client ID cannot be empty'),
      );
    }

    // Validate client data
    final validationFailure = _validateClient(params.client);
    if (validationFailure != null) {
      return Left(validationFailure);
    }

    return repository.updateClient(params.id, params.client);
  }

  /// Validates the client data before update.
  ValidationFailure? _validateClient(Client client) {
    final errors = <String, List<String>>{};

    if (client.name.trim().isEmpty) {
      errors['name'] = ['Client name is required'];
    }

    if (errors.isNotEmpty) {
      return ValidationFailure('Invalid client data', errors);
    }

    return null;
  }
}

/// Parameters for the [UpdateClient] use case.
class UpdateClientParams extends Equatable {
  /// Creates [UpdateClientParams].
  const UpdateClientParams({
    required this.id,
    required this.client,
  });

  /// The unique identifier of the client to update
  final String id;

  /// The updated client data
  final Client client;

  @override
  List<Object?> get props => [id, client];
}
