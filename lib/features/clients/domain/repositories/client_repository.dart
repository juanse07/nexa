import 'package:dartz/dartz.dart';
import 'package:nexa/core/errors/failures.dart';
import 'package:nexa/features/clients/domain/entities/client.dart';

/// Repository interface for client data operations.
///
/// This abstract class defines the contract for client data access.
/// Implementations should handle data fetching from remote APIs,
/// local caching, and error handling.
abstract class ClientRepository {
  /// Retrieves all clients from the data source.
  ///
  /// Returns a list of clients or a [Failure] if the operation fails.
  Future<Either<Failure, List<Client>>> getClients();

  /// Retrieves a single client by its ID.
  ///
  /// Parameters:
  /// - [id]: The unique identifier of the client
  ///
  /// Returns the client or a [NotFoundFailure] if not found.
  Future<Either<Failure, Client>> getClientById(String id);

  /// Creates a new client.
  ///
  /// Parameters:
  /// - [client]: The client entity to create
  ///
  /// Returns the created client with server-assigned ID and timestamps.
  Future<Either<Failure, Client>> createClient(Client client);

  /// Updates an existing client.
  ///
  /// Parameters:
  /// - [id]: The unique identifier of the client to update
  /// - [client]: The updated client data
  ///
  /// Returns the updated client or a [NotFoundFailure] if not found.
  Future<Either<Failure, Client>> updateClient(String id, Client client);

  /// Deletes a client by its ID.
  ///
  /// Parameters:
  /// - [id]: The unique identifier of the client to delete
  ///
  /// Returns void on success or a [Failure] on error.
  Future<Either<Failure, void>> deleteClient(String id);

  /// Searches for clients by name.
  ///
  /// Parameters:
  /// - [query]: The search query string
  ///
  /// Returns a list of clients matching the search query.
  Future<Either<Failure, List<Client>>> searchClients(String query);

  /// Retrieves active clients only.
  ///
  /// Returns a list of active clients.
  Future<Either<Failure, List<Client>>> getActiveClients();

  /// Updates the active status of a client.
  ///
  /// Parameters:
  /// - [id]: The unique identifier of the client
  /// - [isActive]: The new active status
  ///
  /// Returns the updated client or a [Failure] on error.
  Future<Either<Failure, Client>> updateClientStatus(
    String id,
    bool isActive,
  );
}
