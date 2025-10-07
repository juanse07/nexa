import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class EventService {
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

  Future<List<Map<String, dynamic>>> fetchEvents({String? userKey}) async {
    final uri = Uri.parse('$_baseUrl/events');
    final headers = <String, String>{'Accept': 'application/json'};
    final effectiveKey = (userKey ?? (dotenv.env['VIEWER_USER_KEY'] ?? ''))
        .trim();
    if (effectiveKey.isNotEmpty) headers['x-user-key'] = effectiveKey;
    final response = await http.get(uri, headers: headers);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final dynamic decoded = jsonDecode(response.body);
      // Support two shapes:
      // 1) Legacy: top-level array of events
      // 2) Current: object { events: [...], serverTimestamp, deltaSync }
      if (decoded is List) {
        return decoded
            .whereType<Map<String, dynamic>>()
            .map((e) => e)
            .toList(growable: false);
      }
      if (decoded is Map<String, dynamic>) {
        final dynamic eventsField = decoded['events'];
        if (eventsField is List) {
          return eventsField
              .whereType<Map<String, dynamic>>()
              .map((e) => e)
              .toList(growable: false);
        }
        // If backend returns an object without 'events', fallback to empty list
        return const <Map<String, dynamic>>[];
      }
      // Unknown shape
      return const <Map<String, dynamic>>[];
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

  Future<Map<String, dynamic>> updateEvent(String eventId, Map<String, dynamic> updates) async {
    final uri = Uri.parse('$_baseUrl/events/$eventId');
    print('DEBUG: Updating event at URL: $uri');
    print('DEBUG: Event ID: $eventId');

    final response = await http.patch(
      uri,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode(updates),
    );

    print('DEBUG: Response status: ${response.statusCode}');
    print('DEBUG: Response body: ${response.body}');

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception(
      'Failed to update event (${response.statusCode}): ${response.body}',
    );
  }

  Future<Map<String, dynamic>> removeAcceptedStaff(String eventId, String userKey) async {
    final uri = Uri.parse('$_baseUrl/events/$eventId/staff/$userKey');
    final response = await http.delete(uri);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception(
      'Failed to remove staff member (${response.statusCode}): ${response.body}',
    );
  }
}
