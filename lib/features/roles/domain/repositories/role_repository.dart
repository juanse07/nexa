import 'package:dartz/dartz.dart';
import 'package:nexa/core/errors/failures.dart';
import 'package:nexa/features/roles/domain/entities/role.dart';

/// Repository interface for role data operations.
///
/// This abstract class defines the contract for role data access.
/// Implementations should handle data fetching from remote APIs,
/// local caching, and error handling.
abstract class RoleRepository {
  /// Retrieves all roles from the data source.
  ///
  /// Returns a list of roles or a [Failure] if the operation fails.
  Future<Either<Failure, List<Role>>> getRoles();

  /// Retrieves a single role by its ID.
  ///
  /// Parameters:
  /// - [id]: The unique identifier of the role
  ///
  /// Returns the role or a [NotFoundFailure] if not found.
  Future<Either<Failure, Role>> getRoleById(String id);

  /// Creates a new role.
  ///
  /// Parameters:
  /// - [role]: The role entity to create
  ///
  /// Returns the created role with server-assigned ID and timestamps.
  Future<Either<Failure, Role>> createRole(Role role);

  /// Updates an existing role.
  ///
  /// Parameters:
  /// - [id]: The unique identifier of the role to update
  /// - [role]: The updated role data
  ///
  /// Returns the updated role or a [NotFoundFailure] if not found.
  Future<Either<Failure, Role>> updateRole(String id, Role role);

  /// Deletes a role by its ID.
  ///
  /// Parameters:
  /// - [id]: The unique identifier of the role to delete
  ///
  /// Returns void on success or a [Failure] on error.
  Future<Either<Failure, void>> deleteRole(String id);

  /// Retrieves active roles only.
  ///
  /// Returns a list of active roles.
  Future<Either<Failure, List<Role>>> getActiveRoles();

  /// Retrieves roles by category.
  ///
  /// Parameters:
  /// - [category]: The category to filter by
  ///
  /// Returns a list of roles in the specified category.
  Future<Either<Failure, List<Role>>> getRolesByCategory(String category);

  /// Searches for roles by name or description.
  ///
  /// Parameters:
  /// - [query]: The search query string
  ///
  /// Returns a list of roles matching the search query.
  Future<Either<Failure, List<Role>>> searchRoles(String query);

  /// Updates the active status of a role.
  ///
  /// Parameters:
  /// - [id]: The unique identifier of the role
  /// - [isActive]: The new active status
  ///
  /// Returns the updated role or a [Failure] on error.
  Future<Either<Failure, Role>> updateRoleStatus(
    String id,
    bool isActive,
  );
}
