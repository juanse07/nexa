import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:nexa/core/domain/usecase.dart';
import 'package:nexa/core/errors/failures.dart';
import 'package:nexa/features/clients/domain/repositories/client_repository.dart';

/// Use case for deleting a client.
class DeleteClient implements UseCase<void, DeleteClientParams> {
  /// Creates a [DeleteClient] use case.
  const DeleteClient(this.repository);

  /// The client repository
  final ClientRepository repository;

  @override
  Future<Either<Failure, void>> call(DeleteClientParams params) async {
    if (params.id.isEmpty) {
      return const Left(
        ValidationFailure('Client ID cannot be empty'),
      );
    }
    return repository.deleteClient(params.id);
  }
}

/// Parameters for the [DeleteClient] use case.
class DeleteClientParams extends Equatable {
  /// Creates [DeleteClientParams].
  const DeleteClientParams({required this.id});

  /// The unique identifier of the client to delete
  final String id;

  @override
  List<Object?> get props => [id];
}
