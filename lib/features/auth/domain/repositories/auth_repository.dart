import 'package:dartz/dartz.dart';
import 'package:nexa/core/errors/failures.dart';
import 'package:nexa/features/auth/domain/entities/auth_credentials.dart';
import 'package:nexa/features/auth/domain/entities/auth_user.dart';

/// Repository interface for authentication operations.
///
/// This abstract class defines the contract for authentication data access.
/// Implementations should handle various authentication methods including
/// email/password, OAuth, and token refresh.
abstract class AuthRepository {
  /// Logs in a user with the provided credentials.
  ///
  /// Parameters:
  /// - [credentials]: The authentication credentials
  ///
  /// Returns the authenticated user or a [Failure] if login fails.
  Future<Either<Failure, AuthUser>> login(AuthCredentials credentials);

  /// Logs out the current user.
  ///
  /// Returns void on success or a [Failure] on error.
  Future<Either<Failure, void>> logout();

  /// Registers a new user with email and password.
  ///
  /// Parameters:
  /// - [email]: User's email address
  /// - [password]: User's password
  /// - [displayName]: Optional display name
  ///
  /// Returns the newly created user or a [Failure] if registration fails.
  Future<Either<Failure, AuthUser>> register({
    required String email,
    required String password,
    String? displayName,
  });

  /// Refreshes the authentication token.
  ///
  /// Parameters:
  /// - [refreshToken]: The refresh token
  ///
  /// Returns the updated user with new token or a [Failure] on error.
  Future<Either<Failure, AuthUser>> refreshToken(String refreshToken);

  /// Gets the currently authenticated user.
  ///
  /// Returns the current user or a [Failure] if no user is authenticated.
  Future<Either<Failure, AuthUser>> getCurrentUser();

  /// Checks if a user is currently authenticated.
  ///
  /// Returns true if authenticated, false otherwise.
  Future<Either<Failure, bool>> isAuthenticated();

  /// Sends a password reset email.
  ///
  /// Parameters:
  /// - [email]: The user's email address
  ///
  /// Returns void on success or a [Failure] on error.
  Future<Either<Failure, void>> sendPasswordResetEmail(String email);

  /// Resets the user's password.
  ///
  /// Parameters:
  /// - [resetCode]: The password reset code
  /// - [newPassword]: The new password
  ///
  /// Returns void on success or a [Failure] on error.
  Future<Either<Failure, void>> resetPassword({
    required String resetCode,
    required String newPassword,
  });

  /// Changes the current user's password.
  ///
  /// Parameters:
  /// - [currentPassword]: The current password
  /// - [newPassword]: The new password
  ///
  /// Returns void on success or a [Failure] on error.
  Future<Either<Failure, void>> changePassword({
    required String currentPassword,
    required String newPassword,
  });

  /// Verifies the user's email address.
  ///
  /// Parameters:
  /// - [verificationCode]: The email verification code
  ///
  /// Returns void on success or a [Failure] on error.
  Future<Either<Failure, void>> verifyEmail(String verificationCode);

  /// Sends an email verification code.
  ///
  /// Returns void on success or a [Failure] on error.
  Future<Either<Failure, void>> sendEmailVerification();

  /// Updates the current user's profile.
  ///
  /// Parameters:
  /// - [displayName]: Optional new display name
  /// - [photoUrl]: Optional new photo URL
  ///
  /// Returns the updated user or a [Failure] on error.
  Future<Either<Failure, AuthUser>> updateProfile({
    String? displayName,
    String? photoUrl,
  });

  /// Deletes the current user's account.
  ///
  /// Returns void on success or a [Failure] on error.
  Future<Either<Failure, void>> deleteAccount();
}
