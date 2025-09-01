import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class ClientsService {
  String get _baseUrl {
    final fromEnv = (dotenv.env['BACKEND_BASE_URL'] ?? '').trim();
    if (fromEnv.isEmpty) {
      throw StateError(
        'BACKEND_BASE_URL is not set. Please set it in your .env to your deployed server URL.',
      );
    }
    return fromEnv;
  }

  Future<List<Map<String, dynamic>>> fetchClients() async {
    final uri = Uri.parse('$_baseUrl/clients');
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
      'Failed to load clients (${response.statusCode}): ${response.body}',
    );
  }

  Future<Map<String, dynamic>> createClient(String name) async {
    final uri = Uri.parse('$_baseUrl/clients');
    final response = await http.post(
      uri,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'name': name}),
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception(
      'Failed to create client (${response.statusCode}): ${response.body}',
    );
  }

  Future<void> renameClient(String id, String name) async {
    final uri = Uri.parse('$_baseUrl/clients/$id');
    final response = await http.patch(
      uri,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'name': name}),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Failed to rename client (${response.statusCode}): ${response.body}',
      );
    }
  }

  Future<void> deleteClient(String id) async {
    final uri = Uri.parse('$_baseUrl/clients/$id');
    final response = await http.delete(uri);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Failed to delete client (${response.statusCode}): ${response.body}',
      );
    }
  }
}
