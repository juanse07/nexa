import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:nexa/core/domain/usecase.dart';
import 'package:nexa/core/errors/failures.dart';
import 'package:nexa/features/users/domain/entities/user.dart';
import 'package:nexa/features/users/domain/repositories/user_repository.dart';

/// Use case for retrieving a single user by their ID.
class GetUserById implements UseCase<User, GetUserByIdParams> {
  /// Creates a [GetUserById] use case.
  const GetUserById(this.repository);

  /// The user repository
  final UserRepository repository;

  @override
  Future<Either<Failure, User>> call(GetUserByIdParams params) async {
    if (params.id.isEmpty) {
      return const Left(
        ValidationFailure('User ID cannot be empty'),
      );
    }
    return repository.getUserById(params.id);
  }
}

/// Parameters for the [GetUserById] use case.
class GetUserByIdParams extends Equatable {
  /// Creates [GetUserByIdParams].
  const GetUserByIdParams({required this.id});

  /// The unique identifier of the user
  final String id;

  @override
  List<Object?> get props => [id];
}
