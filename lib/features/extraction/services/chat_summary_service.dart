import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/config/app_config.dart';
import '../../auth/data/services/auth_service.dart';

/// Service for saving AI chat conversation summaries
/// Used for learning/analytics and context injection
class ChatSummaryService {
  /// Save a conversation summary to the database
  /// This is called fire-and-forget style (non-blocking)
  Future<void> saveSummary(Map<String, dynamic> summaryData) async {
    try {
      final token = await AuthService.getJwt();
      if (token == null) {
        print('[ChatSummaryService] Not authenticated - skipping save');
        return;
      }

      final baseUrl = AppConfig.instance.baseUrl;
      final url = '$baseUrl/ai/chat/summary';
      print('[ChatSummaryService] Saving summary to: $url');
      print('[ChatSummaryService] Payload keys: ${summaryData.keys.toList()}');

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(summaryData),
      );

      print('[ChatSummaryService] Response status: ${response.statusCode}');

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        print('[ChatSummaryService] Summary saved successfully: ${data['id']}');
      } else {
        print('[ChatSummaryService] Failed to save summary: ${response.statusCode} - ${response.body}');
      }
    } catch (e, stackTrace) {
      // Fire-and-forget: log error but don't throw
      print('[ChatSummaryService] Error saving summary: $e');
      print('[ChatSummaryService] Stack trace: $stackTrace');
    }
  }

  /// Fetch context examples for AI prompt injection
  Future<List<Map<String, dynamic>>> getContextExamples({int limit = 3}) async {
    try {
      final token = await AuthService.getJwt();
      if (token == null) {
        print('[ChatSummaryService] Not authenticated');
        return [];
      }

      final baseUrl = AppConfig.instance.baseUrl;
      final response = await http.get(
        Uri.parse('$baseUrl/ai/chat/context-examples?limit=$limit'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final examples = (data['examples'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        print('[ChatSummaryService] Fetched ${examples.length} context examples');
        return examples;
      } else {
        print('[ChatSummaryService] Failed to fetch examples: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('[ChatSummaryService] Error fetching examples: $e');
      return [];
    }
  }

  /// Fetch conversation analytics (for future dashboard)
  Future<Map<String, dynamic>?> getAnalytics({
    String? startDate,
    String? endDate,
    String groupBy = 'day',
  }) async {
    try {
      final token = await AuthService.getJwt();
      if (token == null) return null;

      final baseUrl = AppConfig.instance.baseUrl;
      final queryParams = <String, String>{
        'groupBy': groupBy,
      };
      if (startDate != null) queryParams['startDate'] = startDate;
      if (endDate != null) queryParams['endDate'] = endDate;

      final uri = Uri.parse('$baseUrl/ai/chat/analytics').replace(queryParameters: queryParams);
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('[ChatSummaryService] Error fetching analytics: $e');
      return null;
    }
  }
}
