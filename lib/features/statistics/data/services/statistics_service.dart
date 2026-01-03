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
}
