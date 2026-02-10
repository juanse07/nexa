import 'package:flutter/material.dart';

/// Sort modes available for the Jobs/Events list.
enum EventSortMode { dateAsc, dateDesc, lastCreated }

/// Pure-function utilities for sorting event maps.
///
/// Extracted from ExtractionScreen so the logic can be unit-tested
/// without mounting the full widget tree.
class EventSortUtils {
  const EventSortUtils._();

  /// Returns a new list sorted according to [mode].
  static List<Map<String, dynamic>> sortEvents(
    List<Map<String, dynamic>> events,
    EventSortMode mode,
  ) {
    final sorted = [...events];
    switch (mode) {
      case EventSortMode.dateAsc:
        sorted.sort(compareEventsAscending);
        break;
      case EventSortMode.dateDesc:
        sorted.sort(compareEventsDescending);
        break;
      case EventSortMode.lastCreated:
        sorted.sort((a, b) {
          final aId = (a['_id'] ?? a['createdAt'] ?? '').toString();
          final bId = (b['_id'] ?? b['createdAt'] ?? '').toString();
          return bId.compareTo(aId); // descending = newest first
        });
        break;
    }
    return sorted;
  }

  /// Ascending by job date, then by shift name as tiebreaker.
  static int compareEventsAscending(
    Map<String, dynamic> a,
    Map<String, dynamic> b,
  ) {
    final DateTime? aDate = eventDateTime(a);
    final DateTime? bDate = eventDateTime(b);
    if (aDate == null && bDate == null) {
      return (a['shift_name'] ?? '').toString().compareTo(
            (b['shift_name'] ?? '').toString(),
          );
    }
    if (aDate == null) return 1;
    if (bDate == null) return -1;
    final cmp = aDate.compareTo(bDate);
    if (cmp != 0) return cmp;
    return (a['shift_name'] ?? '').toString().compareTo(
          (b['shift_name'] ?? '').toString(),
        );
  }

  /// Descending by job date, then by shift name as tiebreaker.
  static int compareEventsDescending(
    Map<String, dynamic> a,
    Map<String, dynamic> b,
  ) {
    final DateTime? aDate = eventDateTime(a);
    final DateTime? bDate = eventDateTime(b);
    if (aDate == null && bDate == null) {
      return (a['shift_name'] ?? '').toString().compareTo(
            (b['shift_name'] ?? '').toString(),
          );
    }
    if (aDate == null) return 1;
    if (bDate == null) return -1;
    final cmp = bDate.compareTo(aDate);
    if (cmp != 0) return cmp;
    return (a['shift_name'] ?? '').toString().compareTo(
          (b['shift_name'] ?? '').toString(),
        );
  }

  /// Parse the event's date + start_time into a DateTime.
  static DateTime? eventDateTime(
    Map<String, dynamic> event, {
    bool useEnd = false,
  }) {
    final rawDate = event['date']?.toString();
    if (rawDate == null || rawDate.isEmpty) return null;
    try {
      final date = DateTime.parse(rawDate);
      final rawTime =
          (useEnd ? event['end_time'] : event['start_time'])?.toString() ?? '';
      final parsedTime = parseTimeOfDayString(rawTime);
      if (parsedTime != null) {
        return DateTime(
          date.year,
          date.month,
          date.day,
          parsedTime.hour,
          parsedTime.minute,
        );
      }
      return date;
    } catch (_) {
      return null;
    }
  }

  /// Parse a human-friendly time string like "3:30 PM" into a TimeOfDay.
  static TimeOfDay? parseTimeOfDayString(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return null;
    final lower = trimmed.toLowerCase();
    final match = RegExp(r'(\d{1,2})(?::(\d{2}))?').firstMatch(lower);
    if (match == null) return null;
    int hour = int.parse(match.group(1)!);
    final int minute = int.parse(match.group(2) ?? '0');
    if (lower.contains('pm') && hour < 12) {
      hour += 12;
    } else if (lower.contains('am') && hour == 12) {
      hour = 0;
    }
    if (hour >= 0 && hour < 24 && minute >= 0 && minute < 60) {
      return TimeOfDay(hour: hour, minute: minute);
    }
    return null;
  }
}
