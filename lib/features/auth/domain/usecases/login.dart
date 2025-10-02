import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:nexa/core/domain/usecase.dart';
import 'package:nexa/core/errors/failures.dart';
import 'package:nexa/features/auth/domain/entities/auth_credentials.dart';
import 'package:nexa/features/auth/domain/entities/auth_user.dart';
import 'package:nexa/features/auth/domain/repositories/auth_repository.dart';

/// Use case for logging in a user.
class Login implements UseCase<AuthUser, LoginParams> {
  /// Creates a [Login] use case.
  const Login(this.repository);

  /// The authentication repository
  final AuthRepository repository;

  @override
  Future<Either<Failure, AuthUser>> call(LoginParams params) async {
    return repository.login(params.credentials);
  }
}

/// Parameters for the [Login] use case.
class LoginParams extends Equatable {
  /// Creates [LoginParams].
  const LoginParams({required this.credentials});

  /// The authentication credentials
  final AuthCredentials credentials;

  @override
  List<Object?> get props => [credentials];
}
