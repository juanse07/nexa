import 'dart:async';

import 'package:dio/dio.dart';
import 'package:nexa/core/network/api_client.dart';
import 'package:nexa/core/network/socket_manager.dart';
import 'package:nexa/core/di/injection.dart';

/// Result of fetching events with delta sync support
class EventFetchResult {
  EventFetchResult({
    required this.events,
    this.serverTimestamp,
    this.isDeltaSync = false,
    this.changeCount,
  });

  final List<Map<String, dynamic>> events;
  final String? serverTimestamp;
  final bool isDeltaSync;
  final int? changeCount;

  bool get hasChanges => events.isNotEmpty;

  @override
  String toString() {
    if (isDeltaSync) {
      return 'EventFetchResult(delta: $changeCount changes, timestamp: $serverTimestamp)';
    }
    return 'EventFetchResult(full: ${events.length} items, timestamp: $serverTimestamp)';
  }
}

class EventService {
  EventService() : _apiClient = getIt<ApiClient>() {
    _setupSocketListeners();
  }

  final ApiClient _apiClient;
  String? _lastSyncTimestamp;

  // Stream controllers for event status changes
  final StreamController<Map<String, dynamic>> _eventFulfilledController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _eventReopenedController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get eventFulfilledStream =>
      _eventFulfilledController.stream;
  Stream<Map<String, dynamic>> get eventReopenedStream =>
      _eventReopenedController.stream;

  void _setupSocketListeners() {
    SocketManager.instance.events.listen((event) {
      if (event.event == 'event:fulfilled') {
        print('[EventService] Event fulfilled: ${event.data}');
        _eventFulfilledController.add(event.data as Map<String, dynamic>);
      } else if (event.event == 'event:reopened') {
        print('[EventService] Event reopened: ${event.data}');
        _eventReopenedController.add(event.data as Map<String, dynamic>);
      }
    });
  }

  void dispose() {
    _eventFulfilledController.close();
    _eventReopenedController.close();
  }

  /// Gets the last sync timestamp
  String? get lastSyncTimestamp => _lastSyncTimestamp;

  /// Clears the last sync timestamp (forces full sync on next fetch)
  void clearLastSyncTimestamp() {
    _lastSyncTimestamp = null;
    print('[EventService] Cleared last sync timestamp - next fetch will be full sync');
  }

  /// Legacy method for backwards compatibility - fetches events without delta sync metadata
  Future<List<Map<String, dynamic>>> fetchEvents({String? userKey}) async {
    final result = await fetchEventsWithSync(userKey: userKey, useDeltaSync: false);
    return result.events;
  }

  /// Fetches events with delta sync support
  ///
  /// If [useDeltaSync] is true and a last sync timestamp exists, only changed events are returned.
  /// Returns both the events and sync metadata for tracking.
  Future<EventFetchResult> fetchEventsWithSync({
    String? userKey,
    bool useDeltaSync = true,
  }) async {
    try {
      final options = Options(headers: <String, String>{'Accept': 'application/json'});

      if (userKey != null && userKey.trim().isNotEmpty) {
        options.headers!['x-user-key'] = userKey.trim();
      }

      // Build query parameters
      final queryParams = <String, dynamic>{};
      if (useDeltaSync && _lastSyncTimestamp != null) {
        queryParams['lastSync'] = _lastSyncTimestamp;
        print('[EventService] Delta sync - fetching changes since $_lastSyncTimestamp');
      } else {
        print('[EventService] Full sync - fetching all events');
      }

      final response = await _apiClient.get(
        '/events',
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
        options: options,
      );

      if (response.statusCode != null &&
          response.statusCode! >= 200 &&
          response.statusCode! < 300) {
        final dynamic decoded = response.data;

        List<Map<String, dynamic>> events;
        String? serverTimestamp;
        bool isDelta = false;

        // Support two shapes:
        // 1) Legacy: top-level array of events
        // 2) Current: object { events: [...], serverTimestamp, deltaSync }
        if (decoded is List) {
          events = decoded
              .whereType<Map<String, dynamic>>()
              .map((e) => e)
              .toList(growable: false);
          // Use current time as timestamp for legacy format
          serverTimestamp = DateTime.now().toIso8601String();
        } else if (decoded is Map<String, dynamic>) {
          final dynamic eventsField = decoded['events'];
          if (eventsField is List) {
            events = eventsField
                .whereType<Map<String, dynamic>>()
                .map((e) => e)
                .toList(growable: false);
          } else {
            events = const <Map<String, dynamic>>[];
          }
          serverTimestamp = decoded['serverTimestamp'] as String?;
          isDelta = decoded['deltaSync'] == true;
        } else {
          // Unknown shape
          events = const <Map<String, dynamic>>[];
          serverTimestamp = DateTime.now().toIso8601String();
        }

        // Save the server timestamp for next sync
        if (serverTimestamp != null) {
          _lastSyncTimestamp = serverTimestamp;
        }

        final result = EventFetchResult(
          events: events,
          serverTimestamp: serverTimestamp,
          isDeltaSync: isDelta,
          changeCount: isDelta ? events.length : null,
        );

        print('[EventService] Fetched: $result');
        return result;
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
        // Clear last sync to force fresh sync on next fetch
        clearLastSyncTimestamp();
        return response.data as Map<String, dynamic>;
      }
      throw Exception(
        'Failed to save event (${response.statusCode}): ${response.data}',
      );
    } on DioException catch (e) {
      throw Exception('Failed to save event: ${e.message}');
    }
  }

  /// Create multiple events in batch
  Future<List<Map<String, dynamic>>> createBatchEvents(
    List<Map<String, dynamic>> events,
  ) async {
    try {
      print('[EventService.createBatchEvents] Creating ${events.length} events...');

      final response = await _apiClient.post(
        '/events/batch',
        data: {'events': events},
      );

      if (response.statusCode != null &&
          response.statusCode! >= 200 &&
          response.statusCode! < 300) {
        final data = response.data as Map<String, dynamic>;
        final eventsField = data['events'] as List?;

        if (eventsField == null) {
          throw Exception('Invalid response: missing events field');
        }

        print('[EventService.createBatchEvents] Successfully created ${eventsField.length} events');
        // Clear last sync to force fresh sync on next fetch
        clearLastSyncTimestamp();
        return eventsField.cast<Map<String, dynamic>>();
      }

      throw Exception(
        'Failed to create batch events (${response.statusCode}): ${response.data}',
      );
    } on DioException catch (e) {
      if (e.response != null) {
        final error = e.response?.data;
        if (error is Map<String, dynamic>) {
          final message = error['message'] ?? error['error'] ?? 'Unknown error';
          throw Exception('Batch creation failed: $message');
        }
      }
      throw Exception('Failed to create batch events: ${e.message}');
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
        // Clear last sync to force fresh sync on next fetch
        clearLastSyncTimestamp();
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

  Future<void> deleteEvent(String eventId) async {
    try {
      final response = await _apiClient.delete('/events/$eventId');

      if (response.statusCode != null &&
          response.statusCode! >= 200 &&
          response.statusCode! < 300) {
        // Clear last sync to force fresh sync on next fetch
        clearLastSyncTimestamp();
        return;
      }
      throw Exception(
        'Failed to delete event (${response.statusCode}): ${response.data}',
      );
    } on DioException catch (e) {
      throw Exception('Failed to delete event: ${e.message}');
    }
  }

  /// Publishes a draft event, making it visible to staff
  ///
  /// [eventId] - The ID of the draft event to publish
  /// [audienceUserKeys] - Optional list of specific user keys to target
  /// [audienceTeamIds] - Optional list of team IDs to target
  ///
  /// Returns the updated event with availability warnings if any staff are unavailable
  Future<Map<String, dynamic>> publishEvent(
    String eventId, {
    List<String>? audienceUserKeys,
    List<String>? audienceTeamIds,
    String? visibilityType,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (audienceUserKeys != null) {
        data['audience_user_keys'] = audienceUserKeys;
      }
      if (audienceTeamIds != null) {
        data['audience_team_ids'] = audienceTeamIds;
      }
      if (visibilityType != null) {
        data['visibilityType'] = visibilityType;
      }

      final response = await _apiClient.post(
        '/events/$eventId/publish',
        data: data,
      );

      if (response.statusCode != null &&
          response.statusCode! >= 200 &&
          response.statusCode! < 300) {
        return response.data as Map<String, dynamic>;
      }
      throw Exception(
        'Failed to publish event (${response.statusCode}): ${response.data}',
      );
    } on DioException catch (e) {
      throw Exception('Failed to publish event: ${e.message}');
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

  Future<Map<String, dynamic>> getEvent(String eventId) async {
    try {
      final response = await _apiClient.get('/events/$eventId');

      if (response.statusCode != null &&
          response.statusCode! >= 200 &&
          response.statusCode! < 300) {
        return response.data as Map<String, dynamic>;
      }
      throw Exception(
        'Failed to get event (${response.statusCode}): ${response.data}',
      );
    } on DioException catch (e) {
      throw Exception('Failed to get event: ${e.message}');
    }
  }

  Future<Map<String, dynamic>> unpublishEvent(String eventId) async {
    try {
      final response = await _apiClient.post('/events/$eventId/unpublish');

      if (response.statusCode != null &&
          response.statusCode! >= 200 &&
          response.statusCode! < 300) {
        return response.data as Map<String, dynamic>;
      }
      throw Exception(
        'Failed to unpublish event (${response.statusCode}): ${response.data}',
      );
    } on DioException catch (e) {
      throw Exception('Failed to unpublish event: ${e.message}');
    }
  }

  Future<Map<String, dynamic>> changeVisibility(
    String eventId, {
    required String visibilityType,
    List<String>? audienceTeamIds,
  }) async {
    try {
      final data = <String, dynamic>{
        'visibilityType': visibilityType,
      };
      if (audienceTeamIds != null) {
        data['audience_team_ids'] = audienceTeamIds;
      }

      final response = await _apiClient.patch(
        '/events/$eventId/visibility',
        data: data,
      );

      if (response.statusCode != null &&
          response.statusCode! >= 200 &&
          response.statusCode! < 300) {
        return response.data as Map<String, dynamic>;
      }
      throw Exception(
        'Failed to change visibility (${response.statusCode}): ${response.data}',
      );
    } on DioException catch (e) {
      throw Exception('Failed to change visibility: ${e.message}');
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
