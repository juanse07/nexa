import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:nexa/core/domain/usecase.dart';
import 'package:nexa/core/errors/failures.dart';
import 'package:nexa/features/users/domain/repositories/user_repository.dart';

/// Use case for retrieving users with pagination.
class GetUsers implements UseCase<PaginatedUsers, GetUsersParams> {
  /// Creates a [GetUsers] use case.
  const GetUsers(this.repository);

  /// The user repository
  final UserRepository repository;

  @override
  Future<Either<Failure, PaginatedUsers>> call(GetUsersParams params) async {
    return repository.getUsers(
      query: params.query,
      cursor: params.cursor,
      limit: params.limit,
    );
  }
}

/// Parameters for the [GetUsers] use case.
class GetUsersParams extends Equatable {
  /// Creates [GetUsersParams].
  const GetUsersParams({
    this.query,
    this.cursor,
    this.limit = 20,
  });

  /// Optional search query to filter users
  final String? query;

  /// Optional pagination cursor
  final String? cursor;

  /// Maximum number of users to return
  final int limit;

  @override
  List<Object?> get props => [query, cursor, limit];
}
