import 'dart:convert';
import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class ExtractionService {
  Future<Map<String, dynamic>> extractStructuredData({
    required String input,
    required String apiKey,
  }) async {
    if (apiKey.isEmpty) {
      throw Exception('Missing OpenAI API key.');
    }

    final bool isImage = input.startsWith('[[IMAGE_BASE64]]:');
    final String visionModel =
        dotenv.env['OPENAI_VISION_MODEL'] ?? 'gpt-4o-mini';
    final String textModel = dotenv.env['OPENAI_TEXT_MODEL'] ?? 'gpt-4o-mini';

    final Uri uri = Uri.parse(
      dotenv.env['OPENAI_BASE_URL'] ??
          'https://api.openai.com/v1/chat/completions',
    );

    const String systemPrompt =
        'You are a structured information extractor for catering event staffing. Extract fields: event_name, client_name, date (ISO 8601), start_time, end_time, venue_name, venue_address, city, state, country, contact_name, contact_phone, contact_email, setup_time, uniform, notes, headcount_total, roles (list of {role, count, call_time}), pay_rate_info. Return strict JSON.';

    Map<String, dynamic> requestBody;
    if (isImage) {
      final String base64Image = input.substring('[[IMAGE_BASE64]]:'.length);
      requestBody = {
        'model': visionModel,
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          {
            'role': 'user',
            'content': [
              {
                'type': 'text',
                'text':
                    'Extract structured event staffing info and return only JSON.',
              },
              {
                'type': 'image_url',
                'image_url': {'url': 'data:image/png;base64,$base64Image'},
              },
            ],
          },
        ],
        'temperature': 0,
        'max_tokens': 800,
      };
    } else {
      requestBody = {
        'model': textModel,
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          {
            'role': 'user',
            'content': 'Extract JSON from the following text:\n\n$input',
          },
        ],
        'temperature': 0,
        'max_tokens': 800,
      };
    }

    final Map<String, String> headers = {
      HttpHeaders.authorizationHeader: 'Bearer $apiKey',
      HttpHeaders.contentTypeHeader: 'application/json',
    };
    final String? orgId = dotenv.env['OPENAI_ORG_ID'];
    if (orgId != null && orgId.isNotEmpty) {
      headers['OpenAI-Organization'] = orgId;
    }

    final http.Response httpResponse = await _postWithRetries(
      uri,
      headers,
      requestBody,
    );
    if (httpResponse.statusCode >= 300) {
      if (httpResponse.statusCode == 429) {
        throw Exception(
          'OpenAI API error 429 (rate limit or quota). Add billing, slow down requests, or try later. Details: ${httpResponse.body}',
        );
      }
      throw Exception(
        'OpenAI API error (${httpResponse.statusCode}): ${httpResponse.body}',
      );
    }

    final Map<String, dynamic> decoded =
        jsonDecode(httpResponse.body) as Map<String, dynamic>;
    String content;
    try {
      content = decoded['choices'][0]['message']['content'] as String;
    } catch (_) {
      content = httpResponse.body;
    }

    final int start = content.indexOf('{');
    final int end = content.lastIndexOf('}');
    if (start != -1 && end != -1 && end > start) {
      final String jsonSlice = content.substring(start, end + 1);
      return jsonDecode(jsonSlice) as Map<String, dynamic>;
    }
    throw Exception('Failed to parse JSON from response: $content');
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
}
