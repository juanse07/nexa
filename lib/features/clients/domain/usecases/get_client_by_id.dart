import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:nexa/core/domain/usecase.dart';
import 'package:nexa/core/errors/failures.dart';
import 'package:nexa/features/clients/domain/entities/client.dart';
import 'package:nexa/features/clients/domain/repositories/client_repository.dart';

/// Use case for retrieving a single client by its ID.
class GetClientById implements UseCase<Client, GetClientByIdParams> {
  /// Creates a [GetClientById] use case.
  const GetClientById(this.repository);

  /// The client repository
  final ClientRepository repository;

  @override
  Future<Either<Failure, Client>> call(GetClientByIdParams params) async {
    if (params.id.isEmpty) {
      return const Left(
        ValidationFailure('Client ID cannot be empty'),
      );
    }
    return repository.getClientById(params.id);
  }
}

/// Parameters for the [GetClientById] use case.
class GetClientByIdParams extends Equatable {
  /// Creates [GetClientByIdParams].
  const GetClientByIdParams({required this.id});

  /// The unique identifier of the client
  final String id;

  @override
  List<Object?> get props => [id];
}
