import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/config/app_config.dart';

class ExtractionService {
  Future<Map<String, dynamic>> extractStructuredData({
    required String input,
  }) async {
    final bool isImage = input.startsWith('[[IMAGE_BASE64]]:');
    final String actualInput = isImage
        ? input.substring('[[IMAGE_BASE64]]:'.length)
        : input;

    final Uri uri = _resolveEndpoint();

    // Request body for backend API
    final Map<String, dynamic> requestBody = {
      'input': actualInput,
      'isImage': isImage,
    };

    final Map<String, String> headers = {
      'Content-Type': 'application/json',
    };

    final http.Response httpResponse = await _postWithRetries(
      uri,
      headers,
      requestBody,
    );
    if (httpResponse.statusCode >= 300) {
      if (httpResponse.statusCode == 429) {
        throw Exception(
          'AI extraction rate limit reached. Please try again later.',
        );
      }
      throw Exception(
        'Extraction failed (${httpResponse.statusCode}): ${httpResponse.body}',
      );
    }

    // Backend returns the extracted JSON directly
    final Map<String, dynamic> decoded =
        jsonDecode(httpResponse.body) as Map<String, dynamic>;
    return decoded;
  }

  Future<http.Response> _postWithRetries(
    Uri uri,
    Map<String, String> headers,
    Map<String, dynamic> body,
  ) async {
    const int maxAttempts = 3;
    int attempt = 0;
    while (true) {
      attempt += 1;
      try {
        final response = await http.post(
          uri,
          headers: headers,
          body: jsonEncode(body),
        );
        if (response.statusCode == 429 || response.statusCode >= 500) {
          if (attempt < maxAttempts) {
            final int backoffSeconds = 1 << (attempt - 1);
            await Future.delayed(Duration(seconds: backoffSeconds));
            continue;
          }
        }
        return response;
      } catch (e) {
        if (attempt >= maxAttempts) rethrow;
        final int backoffSeconds = 1 << (attempt - 1);
        await Future.delayed(Duration(seconds: backoffSeconds));
      }
    }
  }

  Uri _resolveEndpoint() {
    final baseUrl = AppConfig.instance.baseUrl;
    return Uri.parse('$baseUrl/ai/extract');
  }
}
