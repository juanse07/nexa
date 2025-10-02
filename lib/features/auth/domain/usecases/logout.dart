import 'package:dartz/dartz.dart';
import 'package:nexa/core/domain/usecase.dart';
import 'package:nexa/core/errors/failures.dart';
import 'package:nexa/features/auth/domain/repositories/auth_repository.dart';

/// Use case for logging out the current user.
class Logout implements UseCase<void, NoParams> {
  /// Creates a [Logout] use case.
  const Logout(this.repository);

  /// The authentication repository
  final AuthRepository repository;

  @override
  Future<Either<Failure, void>> call(NoParams params) async {
    return repository.logout();
  }
}
