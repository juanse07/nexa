import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:nexa/core/domain/entity.dart';

part 'user.freezed.dart';

/// Represents a user (staff member/employee) in the system.
///
/// Users are staff members who can be assigned to events
/// to fulfill various roles.
@freezed
class User with _$User implements Entity {
  /// Creates a [User] instance.
  const factory User({
    /// Unique identifier for the user
    required String id,

    /// First name
    required String firstName,

    /// Last name
    required String lastName,

    /// Email address
    String? email,

    /// Phone number
    String? phone,

    /// Profile photo URL
    String? photoUrl,

    /// List of role IDs the user is qualified for
    @Default([]) List<String> roleIds,

    /// User's employment status (active, inactive, on-leave, etc.)
    @Default(UserStatus.active) UserStatus status,

    /// Date of hire
    DateTime? hireDate,

    /// Date of birth
    DateTime? dateOfBirth,

    /// Emergency contact name
    String? emergencyContactName,

    /// Emergency contact phone
    String? emergencyContactPhone,

    /// User's certifications or qualifications
    @Default([]) List<String> certifications,

    /// Languages spoken
    @Default([]) List<String> languages,

    /// Availability notes
    String? availabilityNotes,

    /// Hourly rate or salary
    double? payRate,

    /// Currency code for pay rate
    String? currency,

    /// User notes or comments
    String? notes,

    /// When the user was added to the system
    DateTime? createdAt,

    /// When the user was last updated
    DateTime? updatedAt,

    /// Additional metadata
    @Default({}) Map<String, dynamic> metadata,
  }) = _User;

  const User._();

  /// Returns the user's full name.
  String get fullName => '$firstName $lastName';

  /// Returns the user's initials.
  String get initials {
    final first = firstName.isNotEmpty ? firstName[0].toUpperCase() : '';
    final last = lastName.isNotEmpty ? lastName[0].toUpperCase() : '';
    return '$first$last';
  }

  /// Returns true if the user has contact information.
  bool get hasContactInfo => email != null || phone != null;

  /// Returns true if the user is currently active.
  bool get isActive => status == UserStatus.active;

  /// Returns true if the user has emergency contact information.
  bool get hasEmergencyContact =>
      emergencyContactName != null && emergencyContactPhone != null;

  /// Returns true if the user is qualified for the given role.
  bool isQualifiedForRole(String roleId) => roleIds.contains(roleId);

  /// Returns the display name for the user.
  String get displayName {
    if (firstName.isEmpty && lastName.isEmpty) {
      return email ?? phone ?? 'Unknown User';
    }
    return fullName;
  }
}

/// Enumeration of user employment statuses.
enum UserStatus {
  /// User is actively working
  active,

  /// User is inactive/not currently working
  inactive,

  /// User is on leave
  onLeave,

  /// User has been terminated
  terminated;

  /// Returns a human-readable display name for the status.
  String get displayName {
    switch (this) {
      case UserStatus.active:
        return 'Active';
      case UserStatus.inactive:
        return 'Inactive';
      case UserStatus.onLeave:
        return 'On Leave';
      case UserStatus.terminated:
        return 'Terminated';
    }
  }
}
