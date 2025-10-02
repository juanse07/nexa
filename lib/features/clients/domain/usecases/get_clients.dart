import 'package:dartz/dartz.dart';
import 'package:nexa/core/domain/usecase.dart';
import 'package:nexa/core/errors/failures.dart';
import 'package:nexa/features/clients/domain/entities/client.dart';
import 'package:nexa/features/clients/domain/repositories/client_repository.dart';

/// Use case for retrieving all clients.
class GetClients implements UseCase<List<Client>, NoParams> {
  /// Creates a [GetClients] use case.
  const GetClients(this.repository);

  /// The client repository
  final ClientRepository repository;

  @override
  Future<Either<Failure, List<Client>>> call(NoParams params) async {
    return repository.getClients();
  }
}
