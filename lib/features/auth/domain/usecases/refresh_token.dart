import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:nexa/core/domain/usecase.dart';
import 'package:nexa/core/errors/failures.dart';
import 'package:nexa/features/auth/domain/entities/auth_user.dart';
import 'package:nexa/features/auth/domain/repositories/auth_repository.dart';

/// Use case for refreshing the authentication token.
class RefreshToken implements UseCase<AuthUser, RefreshTokenParams> {
  /// Creates a [RefreshToken] use case.
  const RefreshToken(this.repository);

  /// The authentication repository
  final AuthRepository repository;

  @override
  Future<Either<Failure, AuthUser>> call(RefreshTokenParams params) async {
    if (params.refreshToken.isEmpty) {
      return const Left(
        ValidationFailure('Refresh token cannot be empty'),
      );
    }
    return repository.refreshToken(params.refreshToken);
  }
}

/// Parameters for the [RefreshToken] use case.
class RefreshTokenParams extends Equatable {
  /// Creates [RefreshTokenParams].
  const RefreshTokenParams({required this.refreshToken});

  /// The refresh token
  final String refreshToken;

  @override
  List<Object?> get props => [refreshToken];
}
