import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../../core/config/app_config.dart';
import '../../auth/data/services/auth_service.dart';

/// Service for managing attendance data and bulk operations
class AttendanceService {
  static http.Client get _http => AuthService.httpClient;
  static String get _apiBaseUrl => AppConfig.instance.baseUrl;

  /// Fetch attendance report for manager's events
  ///
  /// [startDate] - Start of date range (optional)
  /// [endDate] - End of date range (optional)
  /// [eventId] - Filter by specific event (optional)
  static Future<List<Map<String, dynamic>>> getAttendanceReport({
    DateTime? startDate,
    DateTime? endDate,
    String? eventId,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (startDate != null) {
        queryParams['startDate'] = startDate.toIso8601String();
      }
      if (endDate != null) {
        queryParams['endDate'] = endDate.toIso8601String();
      }
      if (eventId != null) {
        queryParams['eventId'] = eventId;
      }

      final uri = Uri.parse('$_apiBaseUrl/events/attendance-report')
          .replace(queryParameters: queryParams.isEmpty ? null : queryParams);

      final response = await _http.get(uri).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final report = data['report'] as List<dynamic>?;
        return report?.cast<Map<String, dynamic>>() ?? [];
      }
      return [];
    } catch (e) {
      print('[AttendanceService] getAttendanceReport error: $e');
      return [];
    }
  }

  /// Perform bulk clock-in for multiple staff members
  ///
  /// [eventId] - The event to clock staff into
  /// [userKeys] - List of user keys to clock in
  /// [note] - Optional note for the clock-in
  /// [timestamp] - Optional timestamp (defaults to now)
  static Future<Map<String, dynamic>?> bulkClockIn({
    required String eventId,
    required List<String> userKeys,
    String? note,
    DateTime? timestamp,
  }) async {
    try {
      final body = <String, dynamic>{
        'userKeys': userKeys,
      };
      if (note != null && note.isNotEmpty) {
        body['note'] = note;
      }
      if (timestamp != null) {
        body['timestamp'] = timestamp.toIso8601String();
      }

      final response = await _http
          .post(
            Uri.parse('$_apiBaseUrl/events/$eventId/bulk-clock-in'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(body),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('[AttendanceService] bulkClockIn error: $e');
      return null;
    }
  }

  /// Get flagged attendance entries that need review
  ///
  /// [status] - Optional filter: 'pending', 'approved', 'dismissed' (null returns all)
  static Future<List<Map<String, dynamic>>> getFlaggedAttendance({
    String? status,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (status != null) queryParams['status'] = status;

      final uri = Uri.parse('$_apiBaseUrl/events/flagged-attendance')
          .replace(queryParameters: queryParams.isEmpty ? null : queryParams);

      final response = await _http.get(uri).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final flagged = data['flagged'] as List<dynamic>?;
        return flagged?.cast<Map<String, dynamic>>() ?? [];
      }
      return [];
    } catch (e) {
      print('[AttendanceService] getFlaggedAttendance error: $e');
      return [];
    }
  }

  /// Review a flagged attendance entry
  ///
  /// [flagId] - The flagged attendance ID
  /// [status] - New status: 'approved', 'dismissed', 'investigating'
  /// [reviewNotes] - Optional notes about the review
  static Future<bool> reviewFlaggedAttendance({
    required String flagId,
    required String status,
    String? reviewNotes,
  }) async {
    try {
      final body = <String, dynamic>{
        'status': status,
      };
      if (reviewNotes != null && reviewNotes.isNotEmpty) {
        body['reviewNotes'] = reviewNotes;
      }

      final response = await _http
          .patch(
            Uri.parse('$_apiBaseUrl/events/flagged-attendance/$flagId'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(body),
          )
          .timeout(const Duration(seconds: 30));

      return response.statusCode == 200;
    } catch (e) {
      print('[AttendanceService] reviewFlaggedAttendance error: $e');
      return false;
    }
  }

  /// Get attendance for a specific event
  static Future<List<Map<String, dynamic>>> getEventAttendance(
      String eventId) async {
    try {
      final response = await _http.get(
        Uri.parse('$_apiBaseUrl/events/$eventId'),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final event = json.decode(response.body) as Map<String, dynamic>;
        final acceptedStaff = event['accepted_staff'] as List<dynamic>?;

        // Extract attendance data from each staff member
        final attendanceList = <Map<String, dynamic>>[];
        for (final staff in acceptedStaff ?? []) {
          final staffMap = staff as Map<String, dynamic>;
          final attendance = staffMap['attendance'] as List<dynamic>?;
          if (attendance != null && attendance.isNotEmpty) {
            for (final att in attendance) {
              attendanceList.add({
                'staffName': staffMap['name'] ??
                    '${staffMap['first_name'] ?? ''} ${staffMap['last_name'] ?? ''}'
                        .trim(),
                'userKey': staffMap['userKey'],
                'role': staffMap['role'],
                'email': staffMap['email'],
                'picture': staffMap['picture'],
                ...att as Map<String, dynamic>,
              });
            }
          }
        }
        return attendanceList;
      }
      return [];
    } catch (e) {
      print('[AttendanceService] getEventAttendance error: $e');
      return [];
    }
  }
}
