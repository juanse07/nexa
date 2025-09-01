import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class UsersService {
  String get _baseUrl {
    final fromEnv = (dotenv.env['BACKEND_BASE_URL'] ?? '').trim();
    if (fromEnv.isEmpty) {
      throw StateError(
        'BACKEND_BASE_URL is not set. Please set it in your .env to your deployed server URL.',
      );
    }
    return fromEnv;
  }

  Future<Map<String, dynamic>> fetchUsers({
    String? q,
    String? cursor,
    int limit = 20,
  }) async {
    final params = <String, String>{'limit': '$limit'};
    if (q != null && q.trim().isNotEmpty) params['q'] = q.trim();
    if (cursor != null && cursor.isNotEmpty) params['cursor'] = cursor;
    final uri = Uri.parse('$_baseUrl/users').replace(queryParameters: params);
    final response = await http.get(
      uri,
      headers: const {'Accept': 'application/json'},
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      return decoded;
    }
    throw Exception(
      'Failed to load users (${response.statusCode}): ${response.body}',
    );
  }
}
