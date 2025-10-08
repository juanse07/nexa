import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:nexa/core/config/app_config.dart';
import 'package:nexa/core/config/environment.dart';

class TimesheetExtractionService {
  final Environment _env = Environment.instance;

  String get _apiBaseUrl {
    final apiBase = _env.get('API_BASE_URL');
    final pathPrefix = _env.get('API_PATH_PREFIX') ?? '';
    if (apiBase != null) {
      return pathPrefix.isNotEmpty ? '$apiBase$pathPrefix' : apiBase;
    }
    return 'https://api.nexapymesoft.com/api';
  }

  /// Analyze sign-in sheet photo and extract staff hours using OpenAI
  Future<TimesheetAnalysisResult> analyzeSignInSheet({
    required String eventId,
    required String imageBase64,
  }) async {
    final openaiKey = AppConfig.instance.openAIKey;
    if (openaiKey.isEmpty) {
      throw Exception('OpenAI API key not configured');
    }

    try {
      final response = await http.post(
        Uri.parse('$_apiBaseUrl/events/$eventId/analyze-sheet'),
        headers: {
          HttpHeaders.contentTypeHeader: 'application/json',
        },
        body: jsonEncode({
          'imageBase64': imageBase64,
          'openaiApiKey': openaiKey,
        }),
      );

      if (response.statusCode >= 300) {
        throw Exception(
          'Failed to analyze sheet (${response.statusCode}): ${response.body}',
        );
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return TimesheetAnalysisResult.fromJson(data);
    } catch (e) {
      throw Exception('Failed to analyze sign-in sheet: $e');
    }
  }

  /// Submit hours from sign-in sheet to backend
  Future<SubmitHoursResult> submitHours({
    required String eventId,
    required List<StaffHours> staffHours,
    required String sheetPhotoUrl,
    required String submittedBy,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_apiBaseUrl/events/$eventId/submit-hours'),
        headers: {
          HttpHeaders.contentTypeHeader: 'application/json',
        },
        body: jsonEncode({
          'staffHours': staffHours.map((sh) => sh.toJson()).toList(),
          'sheetPhotoUrl': sheetPhotoUrl,
          'submittedBy': submittedBy,
        }),
      );

      if (response.statusCode >= 300) {
        throw Exception(
          'Failed to submit hours (${response.statusCode}): ${response.body}',
        );
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return SubmitHoursResult.fromJson(data);
    } catch (e) {
      throw Exception('Failed to submit hours: $e');
    }
  }

  /// Approve hours for individual staff member
  Future<void> approveHours({
    required String eventId,
    required String userKey,
    required double approvedHours,
    required String approvedBy,
    String? notes,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_apiBaseUrl/events/$eventId/approve-hours/$userKey'),
        headers: {
          HttpHeaders.contentTypeHeader: 'application/json',
        },
        body: jsonEncode({
          'approvedHours': approvedHours,
          'approvedBy': approvedBy,
          if (notes != null) 'notes': notes,
        }),
      );

      if (response.statusCode >= 300) {
        throw Exception(
          'Failed to approve hours (${response.statusCode}): ${response.body}',
        );
      }
    } catch (e) {
      throw Exception('Failed to approve hours: $e');
    }
  }

  /// Bulk approve all hours for an event
  Future<BulkApprovalResult> bulkApproveHours({
    required String eventId,
    required String approvedBy,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_apiBaseUrl/events/$eventId/bulk-approve-hours'),
        headers: {
          HttpHeaders.contentTypeHeader: 'application/json',
        },
        body: jsonEncode({
          'approvedBy': approvedBy,
        }),
      );

      if (response.statusCode >= 300) {
        throw Exception(
          'Failed to bulk approve (${response.statusCode}): ${response.body}',
        );
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return BulkApprovalResult(
        message: data['message'] as String? ?? 'Approved',
        approvedCount: data['approvedCount'] as int? ?? 0,
      );
    } catch (e) {
      throw Exception('Failed to bulk approve hours: $e');
    }
  }
}

class TimesheetAnalysisResult {
  final List<StaffHours> staffHours;

  TimesheetAnalysisResult({required this.staffHours});

  factory TimesheetAnalysisResult.fromJson(Map<String, dynamic> json) {
    final staffList = json['staffHours'] as List<dynamic>? ?? [];
    return TimesheetAnalysisResult(
      staffHours: staffList
          .map((item) => StaffHours.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class StaffHours {
  final String name;
  final String role;
  final String? signInTime;
  final String? signOutTime;
  final double? approvedHours;
  final String? notes;

  StaffHours({
    required this.name,
    required this.role,
    this.signInTime,
    this.signOutTime,
    this.approvedHours,
    this.notes,
  });

  factory StaffHours.fromJson(Map<String, dynamic> json) {
    return StaffHours(
      name: json['name'] as String? ?? '',
      role: json['role'] as String? ?? '',
      signInTime: json['signInTime'] as String?,
      signOutTime: json['signOutTime'] as String?,
      approvedHours: (json['approvedHours'] as num?)?.toDouble(),
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'role': role,
      if (signInTime != null) 'signInTime': signInTime,
      if (signOutTime != null) 'signOutTime': signOutTime,
      if (approvedHours != null) 'approvedHours': approvedHours,
      if (notes != null) 'notes': notes,
    };
  }

  StaffHours copyWith({
    String? name,
    String? role,
    String? signInTime,
    String? signOutTime,
    double? approvedHours,
    String? notes,
  }) {
    return StaffHours(
      name: name ?? this.name,
      role: role ?? this.role,
      signInTime: signInTime ?? this.signInTime,
      signOutTime: signOutTime ?? this.signOutTime,
      approvedHours: approvedHours ?? this.approvedHours,
      notes: notes ?? this.notes,
    );
  }

  // Calculate hours from time strings
  double? calculateHours() {
    if (signInTime == null || signOutTime == null) return null;

    try {
      final inTime = _parseTime(signInTime!);
      final outTime = _parseTime(signOutTime!);

      if (inTime == null || outTime == null) return null;

      var diff = outTime.difference(inTime).inMinutes / 60.0;
      if (diff < 0) diff += 24; // Handle overnight shifts

      return double.parse(diff.toStringAsFixed(2));
    } catch (e) {
      return null;
    }
  }

  DateTime? _parseTime(String timeStr) {
    try {
      final regex = RegExp(r'(\d{1,2}):(\d{2})\s*(AM|PM)', caseSensitive: false);
      final match = regex.firstMatch(timeStr);

      if (match == null) return null;

      var hour = int.parse(match.group(1)!);
      final minute = int.parse(match.group(2)!);
      final period = match.group(3)!.toUpperCase();

      if (period == 'PM' && hour != 12) hour += 12;
      if (period == 'AM' && hour == 12) hour = 0;

      final now = DateTime.now();
      return DateTime(now.year, now.month, now.day, hour, minute);
    } catch (e) {
      return null;
    }
  }
}

class BulkApprovalResult {
  final String message;
  final int approvedCount;

  BulkApprovalResult({
    required this.message,
    required this.approvedCount,
  });
}

class SubmitHoursResult {
  final String message;
  final int processedCount;
  final int totalCount;
  final int unmatchedCount;
  final List<MatchResult> matchResults;

  SubmitHoursResult({
    required this.message,
    required this.processedCount,
    required this.totalCount,
    required this.unmatchedCount,
    required this.matchResults,
  });

  factory SubmitHoursResult.fromJson(Map<String, dynamic> json) {
    final matchList = json['matchResults'] as List<dynamic>? ?? [];
    return SubmitHoursResult(
      message: json['message'] as String? ?? '',
      processedCount: json['processedCount'] as int? ?? 0,
      totalCount: json['totalCount'] as int? ?? 0,
      unmatchedCount: json['unmatchedCount'] as int? ?? 0,
      matchResults: matchList
          .map((item) => MatchResult.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class MatchResult {
  final String extractedName;
  final String extractedRole;
  final bool matched;
  final String? matchedName;
  final String? matchedUserKey;
  final int? similarity;
  final String? reason;

  MatchResult({
    required this.extractedName,
    required this.extractedRole,
    required this.matched,
    this.matchedName,
    this.matchedUserKey,
    this.similarity,
    this.reason,
  });

  factory MatchResult.fromJson(Map<String, dynamic> json) {
    return MatchResult(
      extractedName: json['extractedName'] as String? ?? '',
      extractedRole: json['extractedRole'] as String? ?? '',
      matched: json['matched'] as bool? ?? false,
      matchedName: json['matchedName'] as String?,
      matchedUserKey: json['matchedUserKey'] as String?,
      similarity: json['similarity'] as int?,
      reason: json['reason'] as String?,
    );
  }
}
