import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../../../core/config/environment.dart';
import '../../../core/constants/storage_keys.dart';
import '../models/attendance_dashboard_models.dart';

/// Service for attendance dashboard API calls
class AttendanceDashboardService {
  static final _storage = const FlutterSecureStorage();
  static String get _baseUrl => Environment.instance.getOrDefault('API_BASE_URL', 'https://api.nexapymesoft.com');
  static String get _apiUrl => '$_baseUrl/api';  // All API routes are under /api prefix

  /// Get auth headers for API requests
  static Future<Map<String, String>> _getHeaders() async {
    final token = await _storage.read(key: StorageKeys.accessToken);
    debugPrint('[AttendanceDashboardService] Token found: ${token != null ? 'YES (${token.length} chars)' : 'NO'}');
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Get all staff currently clocked in across all events
  static Future<List<ClockedInStaff>> getCurrentlyClockedIn() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$_apiUrl/events/currently-clocked-in'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final staffList = data['staff'] as List<dynamic>? ?? [];
        return staffList
            .map((e) => ClockedInStaff.fromJson(e as Map<String, dynamic>))
            .toList();
      }

      debugPrint('[AttendanceDashboardService] getCurrentlyClockedIn failed: ${response.statusCode}');
      return [];
    } catch (e) {
      debugPrint('[AttendanceDashboardService] getCurrentlyClockedIn error: $e');
      return [];
    }
  }

  /// Get attendance analytics for the hero header
  static Future<AttendanceAnalytics> getAnalytics({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      debugPrint('[AttendanceDashboardService] getAnalytics called');
      debugPrint('[AttendanceDashboardService] API_BASE_URL: $_baseUrl');
      debugPrint('[AttendanceDashboardService] Full API URL: $_apiUrl');

      final headers = await _getHeaders();
      debugPrint('[AttendanceDashboardService] Headers: $headers');

      final queryParams = <String, String>{};

      if (startDate != null) {
        queryParams['startDate'] = startDate.toIso8601String();
      }
      if (endDate != null) {
        queryParams['endDate'] = endDate.toIso8601String();
      }

      final uri = Uri.parse('$_apiUrl/events/attendance-analytics')
          .replace(queryParameters: queryParams.isEmpty ? null : queryParams);

      debugPrint('[AttendanceDashboardService] Requesting: $uri');

      final response = await http.get(uri, headers: headers);

      debugPrint('[AttendanceDashboardService] Response status: ${response.statusCode}');
      debugPrint('[AttendanceDashboardService] Response body: ${response.body.substring(0, response.body.length.clamp(0, 500))}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final analytics = AttendanceAnalytics.fromJson(data);
        debugPrint('[AttendanceDashboardService] Parsed analytics: working=${analytics.currentlyWorking}, hours=${analytics.todayTotalHours}, flags=${analytics.pendingFlags}');
        return analytics;
      }

      debugPrint('[AttendanceDashboardService] getAnalytics failed: ${response.statusCode}');
      return AttendanceAnalytics.empty;
    } catch (e, stack) {
      debugPrint('[AttendanceDashboardService] getAnalytics error: $e');
      debugPrint('[AttendanceDashboardService] Stack: $stack');
      return AttendanceAnalytics.empty;
    }
  }

  /// Get attendance report with optional filters
  static Future<List<AttendanceRecord>> getAttendanceReport({
    DateTime? startDate,
    DateTime? endDate,
    String? eventId,
  }) async {
    try {
      final headers = await _getHeaders();
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

      final uri = Uri.parse('$_apiUrl/events/attendance-report')
          .replace(queryParameters: queryParams.isEmpty ? null : queryParams);

      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final reportList = data['report'] as List<dynamic>? ?? [];
        return reportList
            .map((e) => AttendanceRecord.fromJson(e as Map<String, dynamic>))
            .toList();
      }

      debugPrint('[AttendanceDashboardService] getAttendanceReport failed: ${response.statusCode}');
      return [];
    } catch (e) {
      debugPrint('[AttendanceDashboardService] getAttendanceReport error: $e');
      return [];
    }
  }

  /// Force clock-out a staff member
  static Future<bool> forceClockOut({
    required String eventId,
    required String userKey,
    String? note,
  }) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$_apiUrl/events/$eventId/force-clock-out/$userKey'),
        headers: headers,
        body: jsonEncode({'note': note}),
      );

      if (response.statusCode == 200) {
        return true;
      }

      debugPrint('[AttendanceDashboardService] forceClockOut failed: ${response.statusCode}');
      return false;
    } catch (e) {
      debugPrint('[AttendanceDashboardService] forceClockOut error: $e');
      return false;
    }
  }

  /// Get flagged attendance entries
  static Future<List<Map<String, dynamic>>> getFlaggedAttendance({
    String? status,
  }) async {
    try {
      final headers = await _getHeaders();
      final queryParams = <String, String>{};

      if (status != null) {
        queryParams['status'] = status;
      }

      final uri = Uri.parse('$_apiUrl/events/flagged-attendance')
          .replace(queryParameters: queryParams.isEmpty ? null : queryParams);

      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final flagsList = data['flags'] as List<dynamic>? ?? [];
        return flagsList.cast<Map<String, dynamic>>();
      }

      debugPrint('[AttendanceDashboardService] getFlaggedAttendance failed: ${response.statusCode}');
      return [];
    } catch (e) {
      debugPrint('[AttendanceDashboardService] getFlaggedAttendance error: $e');
      return [];
    }
  }
}
