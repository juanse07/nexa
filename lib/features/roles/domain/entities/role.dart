import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:nexa/core/domain/entity.dart';

part 'role.freezed.dart';

/// Represents a job role in the staffing system.
///
/// Roles define the types of positions available for events
/// (e.g., server, bartender, chef, captain).
@freezed
class Role with _$Role implements Entity {
  /// Creates a [Role] instance.
  const factory Role({
    /// Unique identifier for the role
    required String id,

    /// Role name (e.g., "Server", "Bartender")
    required String name,

    /// Detailed description of the role
    String? description,

    /// Category for grouping roles (e.g., "Front of House", "Back of House")
    String? category,

    /// Required skills or qualifications
    @Default([]) List<String> requiredSkills,

    /// Certifications needed for this role
    @Default([]) List<String> requiredCertifications,

    /// Whether the role is currently active
    @Default(true) bool isActive,

    /// Default hourly rate for this role (can be overridden by tariffs)
    double? defaultRate,

    /// Currency code for the default rate
    String? currency,

    /// Priority/ranking for display order
    int? displayOrder,

    /// Color code for UI representation (hex format)
    String? colorCode,

    /// Icon identifier for UI representation
    String? iconName,

    /// When the role was created
    DateTime? createdAt,

    /// When the role was last updated
    DateTime? updatedAt,

    /// Additional metadata
    @Default({}) Map<String, dynamic> metadata,
  }) = _Role;

  const Role._();

  /// Returns true if the role has required skills.
  bool get hasRequiredSkills => requiredSkills.isNotEmpty;

  /// Returns true if the role requires certifications.
  bool get requiresCertifications => requiredCertifications.isNotEmpty;

  /// Returns true if the role has a default rate.
  bool get hasDefaultRate => defaultRate != null && defaultRate! > 0;

  /// Returns the display name for the role.
  String get displayName => name;

  /// Returns a formatted string with category and name.
  String get fullDisplayName {
    if (category != null && category!.isNotEmpty) {
      return '$category - $name';
    }
    return name;
  }
}
