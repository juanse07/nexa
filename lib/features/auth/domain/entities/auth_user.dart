import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:nexa/core/domain/entity.dart';

part 'auth_user.freezed.dart';

/// Represents an authenticated user with credentials.
///
/// This entity contains authentication-specific information including
/// tokens, permissions, and user profile data.
@freezed
class AuthUser with _$AuthUser implements Entity {
  /// Creates an [AuthUser] instance.
  const factory AuthUser({
    /// Unique identifier for the user
    required String userId,

    /// User's email address
    required String email,

    /// User's full name
    String? displayName,

    /// Profile photo URL
    String? photoUrl,

    /// Authentication token (JWT or similar)
    required String token,

    /// Refresh token for obtaining new access tokens
    String? refreshToken,

    /// Token expiration timestamp
    DateTime? expiresAt,

    /// List of user roles (e.g., "admin", "manager", "staff")
    @Default([]) List<String> roles,

    /// List of permissions
    @Default([]) List<String> permissions,

    /// Provider used for authentication (e.g., "google", "email")
    String? provider,

    /// Whether the user's email is verified
    @Default(false) bool emailVerified,

    /// User's phone number
    String? phoneNumber,

    /// When the user account was created
    DateTime? createdAt,

    /// When the user last logged in
    DateTime? lastLoginAt,

    /// Additional metadata
    @Default({}) Map<String, dynamic> metadata,
  }) = _AuthUser;

  const AuthUser._();

  /// Returns true if the token is expired.
  bool get isTokenExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  /// Returns true if the token is about to expire (within 5 minutes).
  bool get isTokenExpiringSoon {
    if (expiresAt == null) return false;
    final fiveMinutesFromNow = DateTime.now().add(const Duration(minutes: 5));
    return fiveMinutesFromNow.isAfter(expiresAt!);
  }

  /// Returns true if the user needs to refresh their token.
  bool get needsTokenRefresh => isTokenExpired || isTokenExpiringSoon;

  /// Returns true if the user has a specific role.
  bool hasRole(String role) => roles.contains(role);

  /// Returns true if the user has a specific permission.
  bool hasPermission(String permission) => permissions.contains(permission);

  /// Returns true if the user has any of the specified roles.
  bool hasAnyRole(List<String> requiredRoles) {
    return requiredRoles.any((role) => roles.contains(role));
  }

  /// Returns true if the user has all of the specified roles.
  bool hasAllRoles(List<String> requiredRoles) {
    return requiredRoles.every((role) => roles.contains(role));
  }

  /// Returns true if the user is an admin.
  bool get isAdmin => hasRole('admin');

  /// Returns true if the user is a manager.
  bool get isManager => hasRole('manager');

  /// Returns the display name or email if name is not available.
  String get displayNameOrEmail => displayName ?? email;

  /// Returns the user's initials from the display name.
  String get initials {
    final name = displayNameOrEmail;
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else if (parts.isNotEmpty && parts[0].isNotEmpty) {
      return parts[0][0].toUpperCase();
    }
    return 'U';
  }
}
