import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:nexa/core/domain/usecase.dart';
import 'package:nexa/core/errors/failures.dart';
import 'package:nexa/features/users/domain/entities/user.dart';
import 'package:nexa/features/users/domain/repositories/user_repository.dart';

/// Use case for searching users by name or email.
class SearchUsers implements UseCase<List<User>, SearchUsersParams> {
  /// Creates a [SearchUsers] use case.
  const SearchUsers(this.repository);

  /// The user repository
  final UserRepository repository;

  @override
  Future<Either<Failure, List<User>>> call(SearchUsersParams params) async {
    if (params.query.trim().isEmpty) {
      return const Left(
        ValidationFailure('Search query cannot be empty'),
      );
    }
    return repository.searchUsers(params.query);
  }
}

/// Parameters for the [SearchUsers] use case.
class SearchUsersParams extends Equatable {
  /// Creates [SearchUsersParams].
  const SearchUsersParams({required this.query});

  /// The search query string
  final String query;

  @override
  List<Object?> get props => [query];
}
