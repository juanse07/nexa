import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:nexa/core/domain/usecase.dart';
import 'package:nexa/core/errors/failures.dart';
import 'package:nexa/features/clients/domain/entities/client.dart';
import 'package:nexa/features/clients/domain/repositories/client_repository.dart';

/// Use case for creating a new client.
class CreateClient implements UseCase<Client, CreateClientParams> {
  /// Creates a [CreateClient] use case.
  const CreateClient(this.repository);

  /// The client repository
  final ClientRepository repository;

  @override
  Future<Either<Failure, Client>> call(CreateClientParams params) async {
    // Validate client data
    final validationFailure = _validateClient(params.client);
    if (validationFailure != null) {
      return Left(validationFailure);
    }

    return repository.createClient(params.client);
  }

  /// Validates the client data before creation.
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

/// Parameters for the [CreateClient] use case.
class CreateClientParams extends Equatable {
  /// Creates [CreateClientParams].
  const CreateClientParams({required this.client});

  /// The client to create
  final Client client;

  @override
  List<Object?> get props => [client];
}
