import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:nexa/core/domain/usecase.dart';
import 'package:nexa/core/errors/failures.dart';
import 'package:nexa/features/clients/domain/entities/client.dart';
import 'package:nexa/features/clients/domain/repositories/client_repository.dart';

/// Use case for searching clients by name.
class SearchClients implements UseCase<List<Client>, SearchClientsParams> {
  /// Creates a [SearchClients] use case.
  const SearchClients(this.repository);

  /// The client repository
  final ClientRepository repository;

  @override
  Future<Either<Failure, List<Client>>> call(
    SearchClientsParams params,
  ) async {
    if (params.query.trim().isEmpty) {
      return const Left(
        ValidationFailure('Search query cannot be empty'),
      );
    }
    return repository.searchClients(params.query);
  }
}

/// Parameters for the [SearchClients] use case.
class SearchClientsParams extends Equatable {
  /// Creates [SearchClientsParams].
  const SearchClientsParams({required this.query});

  /// The search query string
  final String query;

  @override
  List<Object?> get props => [query];
}
