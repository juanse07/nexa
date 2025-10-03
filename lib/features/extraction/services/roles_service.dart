import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class RolesService {
  String get _baseUrl {
    final apiBase = dotenv.env['API_BASE_URL'];
    final pathPrefix = dotenv.env['API_PATH_PREFIX'] ?? '';

    if (apiBase == null || apiBase.trim().isEmpty) {
      throw StateError(
        'API_BASE_URL is not set. Please set it in your .env to your deployed server URL.',
      );
    }

    return pathPrefix.isNotEmpty ? '$apiBase$pathPrefix' : apiBase;
  }

  Future<List<Map<String, dynamic>>> fetchRoles() async {
    final uri = Uri.parse('$_baseUrl/roles');
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
      'Failed to load roles (${response.statusCode}): ${response.body}',
    );
  }

  Future<Map<String, dynamic>> createRole(String name) async {
    final uri = Uri.parse('$_baseUrl/roles');
    final response = await http.post(
      uri,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'name': name}),
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception(
      'Failed to create role (${response.statusCode}): ${response.body}',
    );
  }

  Future<void> renameRole(String id, String name) async {
    final uri = Uri.parse('$_baseUrl/roles/$id');
    final response = await http.patch(
      uri,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'name': name}),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Failed to rename role (${response.statusCode}): ${response.body}',
      );
    }
  }

  Future<void> deleteRole(String id) async {
    final uri = Uri.parse('$_baseUrl/roles/$id');
    final response = await http.delete(uri);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Failed to delete role (${response.statusCode}): ${response.body}',
      );
    }
  }
}
