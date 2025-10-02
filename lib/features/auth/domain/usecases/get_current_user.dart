import 'package:dartz/dartz.dart';
import 'package:nexa/core/domain/usecase.dart';
import 'package:nexa/core/errors/failures.dart';
import 'package:nexa/features/auth/domain/entities/auth_user.dart';
import 'package:nexa/features/auth/domain/repositories/auth_repository.dart';

/// Use case for getting the currently authenticated user.
class GetCurrentUser implements UseCase<AuthUser, NoParams> {
  /// Creates a [GetCurrentUser] use case.
  const GetCurrentUser(this.repository);

  /// The authentication repository
  final AuthRepository repository;

  @override
  Future<Either<Failure, AuthUser>> call(NoParams params) async {
    return repository.getCurrentUser();
  }
}
