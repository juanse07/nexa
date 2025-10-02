import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:nexa/core/domain/entity.dart';

part 'auth_credentials.freezed.dart';

/// Represents authentication credentials for login.
@freezed
class AuthCredentials with _$AuthCredentials implements Entity {
  /// Creates an [AuthCredentials] instance for email/password login.
  const factory AuthCredentials.emailPassword({
    required String email,
    required String password,
  }) = EmailPasswordCredentials;

  /// Creates an [AuthCredentials] instance for OAuth login.
  const factory AuthCredentials.oauth({
    required String provider,
    required String accessToken,
    String? idToken,
  }) = OAuthCredentials;

  /// Creates an [AuthCredentials] instance for phone number login.
  const factory AuthCredentials.phone({
    required String phoneNumber,
    required String verificationCode,
  }) = PhoneCredentials;

  /// Creates an [AuthCredentials] instance for token refresh.
  const factory AuthCredentials.refreshToken({
    required String refreshToken,
  }) = RefreshTokenCredentials;
}
