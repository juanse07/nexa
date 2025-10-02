import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:nexa/core/domain/usecase.dart';
import 'package:nexa/core/errors/failures.dart';
import 'package:nexa/features/users/domain/repositories/user_repository.dart';

/// Use case for deleting a user.
class DeleteUser implements UseCase<void, DeleteUserParams> {
  /// Creates a [DeleteUser] use case.
  const DeleteUser(this.repository);

  /// The user repository
  final UserRepository repository;

  @override
  Future<Either<Failure, void>> call(DeleteUserParams params) async {
    if (params.id.isEmpty) {
      return const Left(
        ValidationFailure('User ID cannot be empty'),
      );
    }
    return repository.deleteUser(params.id);
  }
}

/// Parameters for the [DeleteUser] use case.
class DeleteUserParams extends Equatable {
  /// Creates [DeleteUserParams].
  const DeleteUserParams({required this.id});

  /// The unique identifier of the user to delete
  final String id;

  @override
  List<Object?> get props => [id];
}
