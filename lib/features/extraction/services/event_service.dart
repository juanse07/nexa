import 'package:dio/dio.dart';
import 'package:nexa/core/network/api_client.dart';
import 'package:nexa/core/di/injection.dart';

class EventService {
  EventService() : _apiClient = getIt<ApiClient>();

  final ApiClient _apiClient;

  Future<List<Map<String, dynamic>>> fetchEvents({String? userKey}) async {
    try {
      final options = Options(headers: <String, String>{'Accept': 'application/json'});

      if (userKey != null && userKey.trim().isNotEmpty) {
        options.headers!['x-user-key'] = userKey.trim();
      }

      final response = await _apiClient.get('/events', options: options);

      if (response.statusCode != null &&
          response.statusCode! >= 200 &&
          response.statusCode! < 300) {
        final dynamic decoded = response.data;
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
        'Failed to load events (${response.statusCode}): ${response.data}',
      );
    } on DioException catch (e) {
      throw Exception('Failed to load events: ${e.message}');
    }
  }

  Future<Map<String, dynamic>> createEvent(Map<String, dynamic> event) async {
    try {
      final response = await _apiClient.post(
        '/events',
        data: event,
      );

      if (response.statusCode != null &&
          response.statusCode! >= 200 &&
          response.statusCode! < 300) {
        return response.data as Map<String, dynamic>;
      }
      throw Exception(
        'Failed to save event (${response.statusCode}): ${response.data}',
      );
    } on DioException catch (e) {
      throw Exception('Failed to save event: ${e.message}');
    }
  }

  Future<Map<String, dynamic>> updateEvent(String eventId, Map<String, dynamic> updates) async {
    try {
      print('[EventService.updateEvent] Starting update...');
      print('[EventService.updateEvent] Event ID: "$eventId" (length: ${eventId.length})');
      print('[EventService.updateEvent] Updates: $updates');
      print('[EventService.updateEvent] Path: /events/$eventId');

      final response = await _apiClient.patch(
        '/events/$eventId',
        data: updates,
      );

      print('[EventService.updateEvent] Response status: ${response.statusCode}');
      print('[EventService.updateEvent] Response data: ${response.data}');

      if (response.statusCode != null &&
          response.statusCode! >= 200 &&
          response.statusCode! < 300) {
        print('[EventService.updateEvent] ✓ Update successful');
        return response.data as Map<String, dynamic>;
      }
      throw Exception(
        'Failed to update event (${response.statusCode}): ${response.data}',
      );
    } on DioException catch (e) {
      print('[EventService.updateEvent] ✗ DioException: ${e.message}');
      print('[EventService.updateEvent] ✗ Response: ${e.response?.data}');
      print('[EventService.updateEvent] ✗ Status code: ${e.response?.statusCode}');
      throw Exception('Failed to update event: ${e.message}');
    }
  }

  Future<Map<String, dynamic>> removeAcceptedStaff(String eventId, String userKey) async {
    try {
      final response = await _apiClient.delete('/events/$eventId/staff/$userKey');

      if (response.statusCode != null &&
          response.statusCode! >= 200 &&
          response.statusCode! < 300) {
        return response.data as Map<String, dynamic>;
      }
      throw Exception(
        'Failed to remove staff member (${response.statusCode}): ${response.data}',
      );
    } on DioException catch (e) {
      throw Exception('Failed to remove staff member: ${e.message}');
    }
  }

  Future<List<Map<String, dynamic>>> fetchUserEvents(String userKey) async {
    try {
      final options = Options(headers: <String, String>{'Accept': 'application/json'});
      final response = await _apiClient.get(
        '/events/user/$userKey',
        options: options,
      );

      if (response.statusCode != null &&
          response.statusCode! >= 200 &&
          response.statusCode! < 300) {
        final dynamic decoded = response.data;
        if (decoded is Map<String, dynamic>) {
          final dynamic eventsField = decoded['events'];
          if (eventsField is List) {
            return eventsField
                .whereType<Map<String, dynamic>>()
                .map((e) => e)
                .toList(growable: false);
          }
        }
        return const <Map<String, dynamic>>[];
      }
      throw Exception(
        'Failed to load user events (${response.statusCode}): ${response.data}',
      );
    } on DioException catch (e) {
      throw Exception('Failed to load user events: ${e.message}');
    }
  }
}
