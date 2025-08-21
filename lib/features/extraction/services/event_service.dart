import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class EventService {
  String get _baseUrl =>
      (dotenv.env['BACKEND_BASE_URL'] ?? 'http://localhost:4000/api').trim();

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
