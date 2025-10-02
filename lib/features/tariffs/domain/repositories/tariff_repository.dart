import 'package:dartz/dartz.dart';
import 'package:nexa/core/errors/failures.dart';
import 'package:nexa/features/tariffs/domain/entities/tariff.dart';

/// Repository interface for tariff data operations.
///
/// This abstract class defines the contract for tariff data access.
/// Implementations should handle data fetching from remote APIs,
/// local caching, and error handling.
abstract class TariffRepository {
  /// Retrieves all tariffs from the data source.
  ///
  /// Parameters:
  /// - [clientId]: Optional filter by client ID
  /// - [roleId]: Optional filter by role ID
  ///
  /// Returns a list of tariffs or a [Failure] if the operation fails.
  Future<Either<Failure, List<Tariff>>> getTariffs({
    String? clientId,
    String? roleId,
  });

  /// Retrieves a single tariff by its ID.
  ///
  /// Parameters:
  /// - [id]: The unique identifier of the tariff
  ///
  /// Returns the tariff or a [NotFoundFailure] if not found.
  Future<Either<Failure, Tariff>> getTariffById(String id);

  /// Creates a new tariff.
  ///
  /// Parameters:
  /// - [tariff]: The tariff entity to create
  ///
  /// Returns the created tariff with server-assigned ID and timestamps.
  Future<Either<Failure, Tariff>> createTariff(Tariff tariff);

  /// Updates an existing tariff.
  ///
  /// Parameters:
  /// - [id]: The unique identifier of the tariff to update
  /// - [tariff]: The updated tariff data
  ///
  /// Returns the updated tariff or a [NotFoundFailure] if not found.
  Future<Either<Failure, Tariff>> updateTariff(String id, Tariff tariff);

  /// Deletes a tariff by its ID.
  ///
  /// Parameters:
  /// - [id]: The unique identifier of the tariff to delete
  ///
  /// Returns void on success or a [Failure] on error.
  Future<Either<Failure, void>> deleteTariff(String id);

  /// Retrieves tariffs for a specific client.
  ///
  /// Parameters:
  /// - [clientId]: The client identifier
  ///
  /// Returns a list of tariffs for the specified client.
  Future<Either<Failure, List<Tariff>>> getTariffsByClient(String clientId);

  /// Retrieves tariffs for a specific role.
  ///
  /// Parameters:
  /// - [roleId]: The role identifier
  ///
  /// Returns a list of tariffs for the specified role.
  Future<Either<Failure, List<Tariff>>> getTariffsByRole(String roleId);

  /// Retrieves the tariff for a specific client and role combination.
  ///
  /// Parameters:
  /// - [clientId]: The client identifier
  /// - [roleId]: The role identifier
  ///
  /// Returns the tariff if found, or a [NotFoundFailure] if not found.
  Future<Either<Failure, Tariff>> getTariffByClientAndRole(
    String clientId,
    String roleId,
  );

  /// Retrieves only active tariffs.
  ///
  /// Returns a list of active tariffs.
  Future<Either<Failure, List<Tariff>>> getActiveTariffs();

  /// Upserts (creates or updates) a tariff.
  ///
  /// If a tariff exists for the client-role combination, it updates it;
  /// otherwise, it creates a new one.
  ///
  /// Parameters:
  /// - [tariff]: The tariff to upsert
  ///
  /// Returns the created or updated tariff.
  Future<Either<Failure, Tariff>> upsertTariff(Tariff tariff);
}
