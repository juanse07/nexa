import 'package:dartz/dartz.dart';
import 'package:nexa/core/errors/failures.dart';
import 'package:nexa/features/users/domain/entities/user.dart';

/// Repository interface for user data operations.
///
/// This abstract class defines the contract for user data access.
/// Implementations should handle data fetching from remote APIs,
/// local caching, and error handling.
abstract class UserRepository {
  /// Retrieves all users from the data source.
  ///
  /// Parameters:
  /// - [query]: Optional search query to filter users
  /// - [cursor]: Optional pagination cursor
  /// - [limit]: Maximum number of users to return
  ///
  /// Returns a paginated result with users or a [Failure] if the operation fails.
  Future<Either<Failure, PaginatedUsers>> getUsers({
    String? query,
    String? cursor,
    int limit = 20,
  });

  /// Retrieves a single user by their ID.
  ///
  /// Parameters:
  /// - [id]: The unique identifier of the user
  ///
  /// Returns the user or a [NotFoundFailure] if not found.
  Future<Either<Failure, User>> getUserById(String id);

  /// Creates a new user.
  ///
  /// Parameters:
  /// - [user]: The user entity to create
  ///
  /// Returns the created user with server-assigned ID and timestamps.
  Future<Either<Failure, User>> createUser(User user);

  /// Updates an existing user.
  ///
  /// Parameters:
  /// - [id]: The unique identifier of the user to update
  /// - [user]: The updated user data
  ///
  /// Returns the updated user or a [NotFoundFailure] if not found.
  Future<Either<Failure, User>> updateUser(String id, User user);

  /// Deletes a user by their ID.
  ///
  /// Parameters:
  /// - [id]: The unique identifier of the user to delete
  ///
  /// Returns void on success or a [Failure] on error.
  Future<Either<Failure, void>> deleteUser(String id);

  /// Searches for users by name or email.
  ///
  /// Parameters:
  /// - [query]: The search query string
  ///
  /// Returns a list of users matching the search query.
  Future<Either<Failure, List<User>>> searchUsers(String query);

  /// Retrieves active users only.
  ///
  /// Returns a list of active users.
  Future<Either<Failure, List<User>>> getActiveUsers();

  /// Retrieves users qualified for a specific role.
  ///
  /// Parameters:
  /// - [roleId]: The role identifier
  ///
  /// Returns a list of users qualified for the role.
  Future<Either<Failure, List<User>>> getUsersByRole(String roleId);

  /// Updates the status of a user.
  ///
  /// Parameters:
  /// - [id]: The unique identifier of the user
  /// - [status]: The new status
  ///
  /// Returns the updated user or a [Failure] on error.
  Future<Either<Failure, User>> updateUserStatus(
    String id,
    UserStatus status,
  );
}

/// Represents a paginated result of users.
class PaginatedUsers {
  /// Creates a [PaginatedUsers] instance.
  const PaginatedUsers({
    required this.users,
    this.nextCursor,
    this.hasMore = false,
  });

  /// The list of users
  final List<User> users;

  /// Cursor for the next page
  final String? nextCursor;

  /// Whether there are more results available
  final bool hasMore;
}
