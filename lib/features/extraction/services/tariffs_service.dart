import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class TariffsService {
  String get _baseUrl {
    final fromEnv = (dotenv.env['BACKEND_BASE_URL'] ?? '').trim();
    if (fromEnv.isEmpty) {
      throw StateError(
        'BACKEND_BASE_URL is not set. Please set it in your .env to your deployed server URL.',
      );
    }
    return fromEnv;
  }

  Future<List<Map<String, dynamic>>> fetchTariffs({
    String? clientId,
    String? roleId,
  }) async {
    final params = <String, String>{};
    if (clientId != null && clientId.isNotEmpty) params['clientId'] = clientId;
    if (roleId != null && roleId.isNotEmpty) params['roleId'] = roleId;
    final uri = Uri.parse(
      '$_baseUrl/tariffs',
    ).replace(queryParameters: params.isEmpty ? null : params);
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
      'Failed to load tariffs (${response.statusCode}): ${response.body}',
    );
  }

  Future<Map<String, dynamic>> upsertTariff({
    required String clientId,
    required String roleId,
    required double rate,
    String currency = 'USD',
  }) async {
    final uri = Uri.parse('$_baseUrl/tariffs');
    final response = await http.post(
      uri,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'clientId': clientId,
        'roleId': roleId,
        'rate': rate,
        'currency': currency,
      }),
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception(
      'Failed to save tariff (${response.statusCode}): ${response.body}',
    );
  }

  Future<void> deleteTariff(String id) async {
    final uri = Uri.parse('$_baseUrl/tariffs/$id');
    final response = await http.delete(uri);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Failed to delete tariff (${response.statusCode}): ${response.body}',
      );
    }
  }
}
