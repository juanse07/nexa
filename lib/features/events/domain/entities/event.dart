import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:nexa/core/domain/entity.dart';
import 'package:nexa/features/events/domain/entities/address.dart';
import 'package:nexa/features/events/domain/entities/event_role.dart';
import 'package:nexa/features/events/domain/entities/event_status.dart';

part 'event.freezed.dart';

/// Represents a staffing event in the application.
///
/// An event is the core entity that represents a catering or hospitality
/// event that requires staff. It contains all information about the event
/// including timing, location, client, roles, and staffing details.
@freezed
class Event with _$Event implements Entity {
  /// Creates an [Event] instance.
  const factory Event({
    /// Unique identifier for the event
    required String id,

    /// Event title or name
    required String title,

    /// Reference to the client hosting this event
    required String clientId,

    /// Client name for display purposes
    String? clientName,

    /// Event start date and time
    required DateTime startDate,

    /// Event end date and time
    required DateTime endDate,

    /// Venue or location name
    String? venueName,

    /// Physical address of the event
    Address? address,

    /// Current status of the event
    @Default(EventStatus.draft) EventStatus status,

    /// List of roles needed for this event
    @Default([]) List<EventRole> roles,

    /// Additional notes or special instructions
    String? notes,

    /// Contact person name for the event
    String? contactName,

    /// Contact person phone number
    String? contactPhone,

    /// Contact person email address
    String? contactEmail,

    /// Setup time before the event starts
    DateTime? setupTime,

    /// Expected total headcount/attendance
    int? headcount,

    /// Dress code or uniform requirements
    String? uniform,

    /// Special requirements or instructions
    String? specialRequirements,

    /// When the event was created
    DateTime? createdAt,

    /// When the event was last updated
    DateTime? updatedAt,

    /// User key of the creator
    String? createdBy,

    /// Additional metadata as key-value pairs
    @Default({}) Map<String, dynamic> metadata,
  }) = _Event;

  const Event._();

  /// Returns the duration of the event in hours.
  double get durationInHours {
    final duration = endDate.difference(startDate);
    return duration.inMinutes / 60.0;
  }

  /// Returns true if the event is in the past.
  bool get isPast => endDate.isBefore(DateTime.now());

  /// Returns true if the event is in the future.
  bool get isFuture => startDate.isAfter(DateTime.now());

  /// Returns true if the event is currently happening.
  bool get isOngoing {
    final now = DateTime.now();
    return now.isAfter(startDate) && now.isBefore(endDate);
  }

  /// Returns true if the event is upcoming (within the next 7 days).
  bool get isUpcoming {
    final daysUntilStart = startDate.difference(DateTime.now()).inDays;
    return daysUntilStart >= 0 && daysUntilStart <= 7;
  }

  /// Returns the total number of staff positions needed.
  int get totalStaffNeeded {
    return roles.fold(0, (sum, role) => sum + role.quantity);
  }

  /// Returns the total number of confirmed staff.
  int get totalStaffConfirmed {
    return roles.fold(0, (sum, role) => sum + role.confirmedCount);
  }

  /// Returns the number of unfilled staff positions.
  int get totalStaffRemaining {
    return totalStaffNeeded - totalStaffConfirmed;
  }

  /// Returns true if all staff positions are filled.
  bool get isFullyStaffed => totalStaffRemaining == 0 && totalStaffNeeded > 0;

  /// Returns true if some but not all positions are filled.
  bool get isPartiallyStaffed =>
      totalStaffConfirmed > 0 && totalStaffRemaining > 0;

  /// Returns true if no positions are filled.
  bool get hasNoStaff => totalStaffConfirmed == 0;

  /// Returns the overall staffing progress as a percentage (0.0 to 1.0).
  double get staffingProgress =>
      totalStaffNeeded > 0 ? totalStaffConfirmed / totalStaffNeeded : 0.0;

  /// Returns true if the event has location information.
  bool get hasLocation => address != null && address!.hasData;

  /// Returns true if the event has contact information.
  bool get hasContact =>
      contactName != null || contactPhone != null || contactEmail != null;

  /// Returns the number of days until the event starts.
  int get daysUntilStart => startDate.difference(DateTime.now()).inDays;

  /// Returns the number of days since the event ended.
  int get daysSinceEnd => DateTime.now().difference(endDate).inDays;
}
