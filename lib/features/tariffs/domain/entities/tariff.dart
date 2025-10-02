import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:nexa/core/domain/entity.dart';

part 'tariff.freezed.dart';

/// Represents a pricing tariff for a specific role and client combination.
///
/// Tariffs define the rates charged for different roles when working
/// for specific clients. They can override default role rates.
@freezed
class Tariff with _$Tariff implements Entity {
  /// Creates a [Tariff] instance.
  const factory Tariff({
    /// Unique identifier for the tariff
    required String id,

    /// Reference to the client this tariff applies to
    required String clientId,

    /// Client name for display purposes
    String? clientName,

    /// Reference to the role this tariff applies to
    required String roleId,

    /// Role name for display purposes
    String? roleName,

    /// Hourly rate for this tariff
    required double rate,

    /// Currency code (e.g., "USD", "EUR")
    @Default('USD') String currency,

    /// Billing type (hourly, daily, fixed)
    @Default(BillingType.hourly) BillingType billingType,

    /// Minimum billable hours (if applicable)
    double? minimumHours,

    /// Overtime rate multiplier (e.g., 1.5 for time-and-a-half)
    double? overtimeMultiplier,

    /// Hours after which overtime applies
    double? overtimeThreshold,

    /// Whether this tariff is currently active
    @Default(true) bool isActive,

    /// Effective start date for this tariff
    DateTime? effectiveFrom,

    /// Effective end date for this tariff
    DateTime? effectiveTo,

    /// Additional notes about the tariff
    String? notes,

    /// When the tariff was created
    DateTime? createdAt,

    /// When the tariff was last updated
    DateTime? updatedAt,

    /// Additional metadata
    @Default({}) Map<String, dynamic> metadata,
  }) = _Tariff;

  const Tariff._();

  /// Returns true if the tariff is currently in effect.
  bool get isCurrentlyEffective {
    final now = DateTime.now();

    if (effectiveFrom != null && now.isBefore(effectiveFrom!)) {
      return false;
    }

    if (effectiveTo != null && now.isAfter(effectiveTo!)) {
      return false;
    }

    return isActive;
  }

  /// Returns true if the tariff has an overtime rate.
  bool get hasOvertimeRate =>
      overtimeMultiplier != null && overtimeThreshold != null;

  /// Returns true if the tariff has a minimum billable hours requirement.
  bool get hasMinimumHours => minimumHours != null && minimumHours! > 0;

  /// Calculates the cost for a given number of hours.
  double calculateCost(double hours) {
    if (hours <= 0) return 0;

    double cost = 0;

    switch (billingType) {
      case BillingType.hourly:
        if (hasOvertimeRate && hours > overtimeThreshold!) {
          // Regular hours
          cost += overtimeThreshold! * rate;
          // Overtime hours
          final overtimeHours = hours - overtimeThreshold!;
          cost += overtimeHours * rate * overtimeMultiplier!;
        } else {
          cost = hours * rate;
        }

        // Apply minimum hours if set
        if (hasMinimumHours && hours < minimumHours!) {
          cost = minimumHours! * rate;
        }
        break;

      case BillingType.daily:
        cost = rate;
        break;

      case BillingType.fixed:
        cost = rate;
        break;
    }

    return cost;
  }

  /// Returns a display string for the rate.
  String get rateDisplayString {
    switch (billingType) {
      case BillingType.hourly:
        return '$currency ${rate.toStringAsFixed(2)}/hr';
      case BillingType.daily:
        return '$currency ${rate.toStringAsFixed(2)}/day';
      case BillingType.fixed:
        return '$currency ${rate.toStringAsFixed(2)}';
    }
  }
}

/// Enumeration of billing types for tariffs.
enum BillingType {
  /// Billed per hour
  hourly,

  /// Billed per day
  daily,

  /// Fixed rate regardless of duration
  fixed;

  /// Returns a human-readable display name for the billing type.
  String get displayName {
    switch (this) {
      case BillingType.hourly:
        return 'Hourly';
      case BillingType.daily:
        return 'Daily';
      case BillingType.fixed:
        return 'Fixed';
    }
  }
}
