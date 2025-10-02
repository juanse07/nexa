import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:nexa/core/domain/entity.dart';

part 'event_role.freezed.dart';

/// Represents a role assignment within an event.
///
/// This entity links a role to an event with specific staffing requirements
/// including quantity needed, confirmed staff, and timing details.
@freezed
class EventRole with _$EventRole implements Entity {
  /// Creates an [EventRole] instance.
  const factory EventRole({
    /// Unique identifier for this event role assignment
    String? id,

    /// Reference to the role type (e.g., "server", "bartender")
    required String roleId,

    /// Name of the role for display purposes
    String? roleName,

    /// Reference to the applicable tariff/rate
    String? tariffId,

    /// Number of staff needed for this role
    required int quantity,

    /// List of user IDs who are confirmed for this role
    @Default([]) List<String> confirmedUserIds,

    /// Call time for this specific role (may differ from event start time)
    DateTime? callTime,

    /// Notes specific to this role assignment
    String? notes,

    /// Pay rate for this role (may override tariff)
    double? rate,

    /// Currency code (e.g., "USD", "EUR")
    String? currency,
  }) = _EventRole;

  const EventRole._();

  /// Returns the number of confirmed staff for this role.
  int get confirmedCount => confirmedUserIds.length;

  /// Returns the number of staff positions still needed.
  int get remainingCount => quantity - confirmedCount;

  /// Returns true if all positions for this role are filled.
  bool get isFullyStaffed => confirmedCount >= quantity;

  /// Returns true if this role is partially staffed.
  bool get isPartiallyStaffed =>
      confirmedCount > 0 && confirmedCount < quantity;

  /// Returns true if no staff are confirmed for this role.
  bool get hasNoStaff => confirmedCount == 0;

  /// Returns the staffing status as a percentage (0.0 to 1.0).
  double get staffingProgress => quantity > 0 ? confirmedCount / quantity : 0.0;
}
