import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../../../../core/config/environment.dart';
import '../../../../core/constants/storage_keys.dart';
import '../models/statistics_models.dart';

/// Service for statistics and export API calls
class StatisticsService {
  static final _storage = const FlutterSecureStorage();
  static String get _baseUrl => Environment.instance.getOrDefault('API_BASE_URL', 'https://api.nexapymesoft.com');
  static String get _apiUrl => '$_baseUrl/api';

  /// Get auth headers for API requests
  static Future<Map<String, String>> _getHeaders() async {
    final token = await _storage.read(key: StorageKeys.accessToken);
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Get manager statistics summary
  static Future<ManagerStatistics> getManagerSummary({
    String period = 'month',
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      debugPrint('[StatisticsService] getManagerSummary called, period: $period');

      final headers = await _getHeaders();
      final queryParams = <String, String>{'period': period};

      if (period == 'custom' && startDate != null && endDate != null) {
        queryParams['startDate'] = startDate.toIso8601String();
        queryParams['endDate'] = endDate.toIso8601String();
      }

      final uri = Uri.parse('$_apiUrl/statistics/manager/summary')
          .replace(queryParameters: queryParams);

      debugPrint('[StatisticsService] Requesting: $uri');

      final response = await http.get(uri, headers: headers);

      debugPrint('[StatisticsService] Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return ManagerStatistics.fromJson(data);
      }

      debugPrint('[StatisticsService] getManagerSummary failed: ${response.statusCode}');
      return ManagerStatistics.empty;
    } catch (e) {
      debugPrint('[StatisticsService] getManagerSummary error: $e');
      return ManagerStatistics.empty;
    }
  }

  /// Get payroll report
  static Future<PayrollReport> getPayrollReport({
    String period = 'month',
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      debugPrint('[StatisticsService] getPayrollReport called, period: $period');

      final headers = await _getHeaders();
      final queryParams = <String, String>{'period': period};

      if (period == 'custom' && startDate != null && endDate != null) {
        queryParams['startDate'] = startDate.toIso8601String();
        queryParams['endDate'] = endDate.toIso8601String();
      }

      final uri = Uri.parse('$_apiUrl/statistics/manager/payroll')
          .replace(queryParameters: queryParams);

      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return PayrollReport.fromJson(data);
      }

      debugPrint('[StatisticsService] getPayrollReport failed: ${response.statusCode}');
      return PayrollReport.empty;
    } catch (e) {
      debugPrint('[StatisticsService] getPayrollReport error: $e');
      return PayrollReport.empty;
    }
  }

  /// Get top performers
  static Future<TopPerformersReport> getTopPerformers({
    String period = 'month',
    int limit = 10,
  }) async {
    try {
      debugPrint('[StatisticsService] getTopPerformers called, period: $period');

      final headers = await _getHeaders();
      final queryParams = <String, String>{
        'period': period,
        'limit': limit.toString(),
      };

      final uri = Uri.parse('$_apiUrl/statistics/manager/top-performers')
          .replace(queryParameters: queryParams);

      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return TopPerformersReport.fromJson(data);
      }

      debugPrint('[StatisticsService] getTopPerformers failed: ${response.statusCode}');
      return TopPerformersReport.empty;
    } catch (e) {
      debugPrint('[StatisticsService] getTopPerformers error: $e');
      return TopPerformersReport.empty;
    }
  }

  /// Export team report as CSV
  static Future<String?> exportTeamReportCsv({
    String reportType = 'payroll',
    String period = 'month',
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      debugPrint('[StatisticsService] exportTeamReportCsv called');

      final headers = await _getHeaders();
      final queryParams = <String, String>{
        'format': 'csv',
        'reportType': reportType,
        'period': period,
      };

      if (period == 'custom' && startDate != null && endDate != null) {
        queryParams['startDate'] = startDate.toIso8601String();
        queryParams['endDate'] = endDate.toIso8601String();
      }

      final uri = Uri.parse('$_apiUrl/exports/team-report')
          .replace(queryParameters: queryParams);

      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        return response.body; // CSV content as string
      }

      debugPrint('[StatisticsService] exportTeamReportCsv failed: ${response.statusCode}');
      return null;
    } catch (e) {
      debugPrint('[StatisticsService] exportTeamReportCsv error: $e');
      return null;
    }
  }

  /// Get export data for PDF generation
  static Future<ExportData?> getExportDataForPdf({
    String reportType = 'payroll',
    String period = 'month',
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      debugPrint('[StatisticsService] getExportDataForPdf called');

      final headers = await _getHeaders();
      final queryParams = <String, String>{
        'format': 'pdf',
        'reportType': reportType,
        'period': period,
      };

      if (period == 'custom' && startDate != null && endDate != null) {
        queryParams['startDate'] = startDate.toIso8601String();
        queryParams['endDate'] = endDate.toIso8601String();
      }

      final uri = Uri.parse('$_apiUrl/exports/team-report')
          .replace(queryParameters: queryParams);

      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return ExportData.fromJson(data);
      }

      debugPrint('[StatisticsService] getExportDataForPdf failed: ${response.statusCode}');
      return null;
    } catch (e) {
      debugPrint('[StatisticsService] getExportDataForPdf error: $e');
      return null;
    }
  }

  /// Request AI analysis of statistics data via the AI chat endpoint.
  /// Sends a structured summary of the loaded stats and returns the AI response.
  static Future<String> getAIAnalysis({
    required ManagerStatistics statistics,
    required PayrollReport payroll,
    required TopPerformersReport topPerformers,
  }) async {
    final headers = await _getHeaders();

    // Build a structured data summary for the AI
    final s = statistics.summary;
    final p = payroll.summary;
    final periodLabel = statistics.period.label;

    final topPerformersList = topPerformers.topPerformers
        .take(5)
        .map((tp) =>
            '  - ${tp.name}: ${tp.shiftsCompleted} shifts, ${tp.hoursWorked}h, \$${tp.earnings.toStringAsFixed(2)}, punctuality ${tp.punctualityScore}%')
        .join('\n');

    final payrollBreakdown = payroll.entries
        .take(10)
        .map((e) =>
            '  - ${e.name}: ${e.shifts} shifts, ${e.hours}h, \$${e.earnings.toStringAsFixed(2)} (avg \$${e.averageRate.toStringAsFixed(2)}/h), roles: ${e.roles.join(", ")}')
        .join('\n');

    final complianceInfo = statistics.compliance.flagsByType.entries
        .map((e) => '  - ${e.key}: ${e.value}')
        .join('\n');

    final dataBlock = '''
Period: $periodLabel

TEAM SUMMARY:
- Total Events: ${s.totalEvents}
- Completed: ${s.completedEvents}
- Cancelled: ${s.cancelledEvents}
- Total Staff Hours: ${s.totalStaffHours}
- Total Payroll: \$${s.totalPayroll.toStringAsFixed(2)}
- Average Event Size: ${s.averageEventSize} staff
- Fulfillment Rate: ${s.fulfillmentRate}%

PAYROLL SUMMARY:
- Staff Count: ${p.staffCount}
- Total Hours: ${p.totalHours}
- Total Payroll: \$${p.totalPayroll.toStringAsFixed(2)}
- Average Per Staff: \$${p.averagePerStaff.toStringAsFixed(2)}

PAYROLL BY STAFF (top 10):
$payrollBreakdown

TOP PERFORMERS:
$topPerformersList

COMPLIANCE:
- Pending Flags: ${statistics.compliance.pendingFlags}
${complianceInfo.isNotEmpty ? 'Flags by Type:\n$complianceInfo' : '- No flags this period'}
''';

    final messages = [
      {
        'role': 'system',
        'content':
            'You are a business analytics assistant for a catering/event staffing company. '
            'Analyze the following team statistics and provide actionable insights. '
            'Use markdown formatting with headers, bullet points, and bold for emphasis. '
            'Keep it concise (under 400 words). Focus on: key highlights, trends, areas of concern, and recommendations.',
      },
      {
        'role': 'user',
        'content': 'Analyze my team stats for this period:\n\n$dataBlock',
      },
    ];

    final body = jsonEncode({
      'messages': messages,
      'temperature': 0.7,
      'maxTokens': 800,
      'provider': 'groq',
    });

    debugPrint('[StatisticsService] Requesting AI analysis...');

    final response = await http.post(
      Uri.parse('$_apiUrl/ai/chat/message'),
      headers: headers,
      body: body,
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['content'] as String? ?? 'No analysis generated.';
    }

    final errMsg = jsonDecode(response.body)['message'] ?? 'Unknown error';
    throw Exception('AI analysis failed: $errMsg');
  }

  /// Generate a PDF or DOCX document from the AI analysis text.
  /// Returns a presigned download URL.
  static Future<String> generateAnalysisDoc({
    required String analysis,
    required ManagerStatistics statistics,
    String format = 'pdf',
  }) async {
    final headers = await _getHeaders();
    final s = statistics.summary;

    final body = jsonEncode({
      'analysis': analysis,
      'format': format,
      'period': {
        'start': statistics.period.start.toIso8601String(),
        'end': statistics.period.end.toIso8601String(),
        'label': statistics.period.label,
      },
      'summary': {
        'totalEvents': s.totalEvents,
        'totalStaffHours': s.totalStaffHours,
        'totalPayroll': s.totalPayroll,
        'fulfillmentRate': s.fulfillmentRate,
      },
    });

    debugPrint('[StatisticsService] Generating AI analysis $format...');

    final response = await http.post(
      Uri.parse('$_apiUrl/statistics/manager/ai-analysis-doc'),
      headers: headers,
      body: body,
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final url = data['url'] as String?;
      if (url == null) throw Exception('No download URL returned');
      return url;
    }

    final errMsg = jsonDecode(response.body)['message'] ?? 'Unknown error';
    throw Exception('Document generation failed: $errMsg');
  }
}
