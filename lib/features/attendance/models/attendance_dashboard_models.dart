import 'package:flutter/material.dart';

/// Represents a staff member currently clocked in
class ClockedInStaff {
  final String userKey;
  final String name;
  final String? picture;
  final String? role;
  final String? email;
  final String eventId;
  final String eventName;
  final String? venueAddress;
  final DateTime clockInTime;
  final Duration elapsed;
  final String elapsedFormatted;
  final ClockInLocation? clockInLocation;

  const ClockedInStaff({
    required this.userKey,
    required this.name,
    this.picture,
    this.role,
    this.email,
    required this.eventId,
    required this.eventName,
    this.venueAddress,
    required this.clockInTime,
    required this.elapsed,
    required this.elapsedFormatted,
    this.clockInLocation,
  });

  factory ClockedInStaff.fromJson(Map<String, dynamic> json) {
    return ClockedInStaff(
      userKey: json['userKey'] as String? ?? '',
      name: json['name'] as String? ?? 'Unknown',
      picture: json['picture'] as String?,
      role: json['role'] as String?,
      email: json['email'] as String?,
      eventId: json['eventId'] as String? ?? '',
      eventName: json['eventName'] as String? ?? '',
      venueAddress: json['venueAddress'] as String?,
      clockInTime: json['clockInTime'] != null
          ? DateTime.parse(json['clockInTime'] as String)
          : DateTime.now(),
      elapsed: Duration(milliseconds: (json['elapsedMs'] as num?)?.toInt() ?? 0),
      elapsedFormatted: json['elapsedFormatted'] as String? ?? '',
      clockInLocation: json['clockInLocation'] != null
          ? ClockInLocation.fromJson(json['clockInLocation'] as Map<String, dynamic>)
          : null,
    );
  }

  /// Get initials for avatar fallback
  String get initials {
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }
}

/// Location data for clock-in
class ClockInLocation {
  final double latitude;
  final double longitude;
  final double? accuracy;
  final String? source;

  const ClockInLocation({
    required this.latitude,
    required this.longitude,
    this.accuracy,
    this.source,
  });

  factory ClockInLocation.fromJson(Map<String, dynamic> json) {
    return ClockInLocation(
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
      accuracy: (json['accuracy'] as num?)?.toDouble(),
      source: json['source'] as String?,
    );
  }
}

/// Daily hours data for the weekly chart
class DailyHours {
  final String date;
  final double hours;
  final String dayOfWeek;

  const DailyHours({
    required this.date,
    required this.hours,
    required this.dayOfWeek,
  });

  factory DailyHours.fromJson(Map<String, dynamic> json) {
    return DailyHours(
      date: json['date'] as String? ?? '',
      hours: (json['hours'] as num?)?.toDouble() ?? 0,
      dayOfWeek: json['dayOfWeek'] as String? ?? '',
    );
  }
}

/// Analytics data for the hero header
class AttendanceAnalytics {
  final int currentlyWorking;
  final double todayTotalHours;
  final int pendingFlags;
  final List<DailyHours> weeklyHours;
  final DateTimeRange? dateRange;

  const AttendanceAnalytics({
    required this.currentlyWorking,
    required this.todayTotalHours,
    required this.pendingFlags,
    required this.weeklyHours,
    this.dateRange,
  });

  factory AttendanceAnalytics.fromJson(Map<String, dynamic> json) {
    final weeklyHoursJson = json['weeklyHours'] as List<dynamic>? ?? [];
    final dateRangeJson = json['dateRange'] as Map<String, dynamic>?;

    return AttendanceAnalytics(
      currentlyWorking: (json['currentlyWorking'] as num?)?.toInt() ?? 0,
      todayTotalHours: (json['todayTotalHours'] as num?)?.toDouble() ?? 0,
      pendingFlags: (json['pendingFlags'] as num?)?.toInt() ?? 0,
      weeklyHours: weeklyHoursJson
          .map((e) => DailyHours.fromJson(e as Map<String, dynamic>))
          .toList(),
      dateRange: dateRangeJson != null
          ? DateTimeRange(
              start: DateTime.parse(dateRangeJson['start'] as String),
              end: DateTime.parse(dateRangeJson['end'] as String),
            )
          : null,
    );
  }

  /// Empty analytics for loading state
  static AttendanceAnalytics get empty => const AttendanceAnalytics(
        currentlyWorking: 0,
        todayTotalHours: 0,
        pendingFlags: 0,
        weeklyHours: [],
      );
}

/// Filters for the attendance dashboard
class AttendanceFilters {
  final DateTimeRange? dateRange;
  final String? eventId;
  final List<String> staffUserKeys;
  final AttendanceStatus status;

  const AttendanceFilters({
    this.dateRange,
    this.eventId,
    this.staffUserKeys = const [],
    this.status = AttendanceStatus.all,
  });

  AttendanceFilters copyWith({
    DateTimeRange? dateRange,
    String? eventId,
    List<String>? staffUserKeys,
    AttendanceStatus? status,
    bool clearDateRange = false,
    bool clearEventId = false,
  }) {
    return AttendanceFilters(
      dateRange: clearDateRange ? null : (dateRange ?? this.dateRange),
      eventId: clearEventId ? null : (eventId ?? this.eventId),
      staffUserKeys: staffUserKeys ?? this.staffUserKeys,
      status: status ?? this.status,
    );
  }

  /// Check if any filters are active
  bool get hasActiveFilters =>
      dateRange != null ||
      eventId != null ||
      staffUserKeys.isNotEmpty ||
      status != AttendanceStatus.all;

  /// Get predefined date ranges
  static DateTimeRange get today {
    final now = DateTime.now();
    return DateTimeRange(
      start: DateTime(now.year, now.month, now.day),
      end: DateTime(now.year, now.month, now.day, 23, 59, 59),
    );
  }

  static DateTimeRange get yesterday {
    final now = DateTime.now();
    final yesterdayStart = DateTime(now.year, now.month, now.day - 1);
    return DateTimeRange(
      start: yesterdayStart,
      end: DateTime(yesterdayStart.year, yesterdayStart.month, yesterdayStart.day, 23, 59, 59),
    );
  }

  static DateTimeRange get thisWeek {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    return DateTimeRange(
      start: DateTime(weekStart.year, weekStart.month, weekStart.day),
      end: DateTime(now.year, now.month, now.day, 23, 59, 59),
    );
  }

  static DateTimeRange get last7Days {
    final now = DateTime.now();
    return DateTimeRange(
      start: DateTime(now.year, now.month, now.day - 6),
      end: DateTime(now.year, now.month, now.day, 23, 59, 59),
    );
  }
}

/// Attendance status filter options
enum AttendanceStatus {
  all('All'),
  working('Working'),
  completed('Completed'),
  flagged('Flagged'),
  noShow('No-show');

  final String label;
  const AttendanceStatus(this.label);
}

/// Attendance record from the report endpoint
class AttendanceRecord {
  final String eventId;
  final String eventName;
  final DateTime? eventDate;
  final String userKey;
  final String staffName;
  final String? role;
  final String? picture;
  final String? email;
  final DateTime clockInAt;
  final DateTime? clockOutAt;
  final double? hoursWorked;
  final bool autoClockOut;
  final ClockInLocation? clockInLocation;
  final ClockInLocation? clockOutLocation;
  final bool isFlagged;

  const AttendanceRecord({
    required this.eventId,
    required this.eventName,
    this.eventDate,
    required this.userKey,
    required this.staffName,
    this.role,
    this.picture,
    this.email,
    required this.clockInAt,
    this.clockOutAt,
    this.hoursWorked,
    this.autoClockOut = false,
    this.clockInLocation,
    this.clockOutLocation,
    this.isFlagged = false,
  });

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    return AttendanceRecord(
      eventId: json['eventId'] as String? ?? '',
      eventName: json['eventName'] as String? ?? '',
      eventDate: json['eventDate'] != null
          ? DateTime.parse(json['eventDate'] as String)
          : null,
      userKey: json['userKey'] as String? ?? '',
      staffName: json['staffName'] as String? ?? 'Unknown',
      role: json['role'] as String?,
      picture: json['picture'] as String?,
      email: json['email'] as String?,
      clockInAt: DateTime.parse(json['clockInAt'] as String),
      clockOutAt: json['clockOutAt'] != null
          ? DateTime.parse(json['clockOutAt'] as String)
          : null,
      hoursWorked: (json['hoursWorked'] as num?)?.toDouble(),
      autoClockOut: json['autoClockOut'] as bool? ?? false,
      clockInLocation: json['clockInLocation'] != null
          ? ClockInLocation.fromJson(json['clockInLocation'] as Map<String, dynamic>)
          : null,
      clockOutLocation: json['clockOutLocation'] != null
          ? ClockInLocation.fromJson(json['clockOutLocation'] as Map<String, dynamic>)
          : null,
    );
  }

  /// Check if currently working (clocked in but not out)
  bool get isWorking => clockOutAt == null;

  /// Get status for display
  AttendanceDisplayStatus get displayStatus {
    if (isFlagged) return AttendanceDisplayStatus.flagged;
    if (isWorking) return AttendanceDisplayStatus.working;
    return AttendanceDisplayStatus.completed;
  }

  /// Get initials for avatar fallback
  String get initials {
    final parts = staffName.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return staffName.isNotEmpty ? staffName[0].toUpperCase() : '?';
  }

  /// Format hours worked for display
  String get hoursWorkedFormatted {
    if (hoursWorked == null) return '--';
    final hours = hoursWorked!.floor();
    final minutes = ((hoursWorked! % 1) * 60).round();
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  /// Calculate current elapsed time if still working
  Duration get currentElapsed {
    if (clockOutAt != null) {
      return clockOutAt!.difference(clockInAt);
    }
    return DateTime.now().difference(clockInAt);
  }
}

/// Display status for attendance cards
enum AttendanceDisplayStatus {
  working,
  completed,
  flagged,
  noShow,
}
