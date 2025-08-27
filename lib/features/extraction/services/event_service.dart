import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class EventService {
  String get _baseUrl {
    final fromEnv = (dotenv.env['BACKEND_BASE_URL'] ?? '').trim();
    if (fromEnv.isEmpty) {
      throw StateError(
        'BACKEND_BASE_URL is not set. Please set it in your .env to your deployed server URL.',
      );
    }
    return fromEnv;
  }

  Future<List<Map<String, dynamic>>> fetchEvents() async {
    final uri = Uri.parse('$_baseUrl/events');
    final response = await http.get(
      uri,
      headers: const {'Accept': 'application/json'},
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final List<dynamic> decoded = jsonDecode(response.body) as List<dynamic>;
      return decoded
          .whereType<Map<String, dynamic>>()
          .map((e) => e)
          .toList(growable: false);
    }
    throw Exception(
      'Failed to load events (${response.statusCode}): ${response.body}',
    );
  }

  Future<Map<String, dynamic>> createEvent(Map<String, dynamic> event) async {
    final uri = Uri.parse('$_baseUrl/events');
    final response = await http.post(
      uri,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode(event),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception(
      'Failed to save event (${response.statusCode}): ${response.body}',
    );
  }
}
