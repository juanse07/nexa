import 'package:dio/dio.dart';
import 'package:logger/logger.dart';
import 'package:nexa/core/network/api_client.dart';
import 'package:nexa/core/sync/delta_sync_service.dart';

/// API service for events with delta sync support
///
/// This service demonstrates how to use DeltaSyncService to reduce
/// data transfer by only fetching changed events.
class EventsApiService {
  EventsApiService({
    required ApiClient apiClient,
    required DeltaSyncService syncService,
    required Logger logger,
  })  : _apiClient = apiClient,
        _syncService = syncService,
        _logger = logger;

  final ApiClient _apiClient;
  final DeltaSyncService _syncService;
  final Logger _logger;

  /// Fetches events with delta sync support
  ///
  /// On first call: Fetches all events
  /// On subsequent calls: Only fetches events changed since last sync
  ///
  /// Returns both the events and sync metadata
  Future<DeltaSyncResult<Map<String, dynamic>>> fetchEvents({
    Map<String, dynamic>? filters,
  }) async {
    try {
      final result = await _syncService.fetch<Map<String, dynamic>>(
        endpoint: '/api/events',
        collection: 'events',
        fromJson: (json) => json,
        queryParameters: filters,
      );

      _logger.i(
        'Events fetch: ${result.isDeltaSync ? "Delta (${result.changeCount} changes)" : "Full (${result.items.length} items)"}',
      );

      return result;
    } catch (e) {
      _logger.e('Failed to fetch events with delta sync', error: e);
      rethrow;
    }
  }

  /// Fetches a single event by ID (no delta sync needed)
  Future<Map<String, dynamic>> fetchEventById(String id) async {
    try {
      final response = await _apiClient.get('/api/events/$id');
      return response.data as Map<String, dynamic>;
    } catch (e) {
      _logger.e('Failed to fetch event $id', error: e);
      rethrow;
    }
  }

  /// Creates a new event
  Future<Map<String, dynamic>> createEvent(
    Map<String, dynamic> eventData,
  ) async {
    try {
      final response = await _apiClient.post('/api/events', data: eventData);

      // Invalidate cache to force fresh sync
      await _syncService.clearLastSyncTimestamp('events');

      return response.data as Map<String, dynamic>;
    } catch (e) {
      _logger.e('Failed to create event', error: e);
      rethrow;
    }
  }

  /// Updates an existing event
  Future<Map<String, dynamic>> updateEvent(
    String id,
    Map<String, dynamic> eventData,
  ) async {
    try {
      final response = await _apiClient.put('/api/events/$id', data: eventData);

      // Invalidate cache to force fresh sync
      await _syncService.clearLastSyncTimestamp('events');

      return response.data as Map<String, dynamic>;
    } catch (e) {
      _logger.e('Failed to update event $id', error: e);
      rethrow;
    }
  }

  /// Deletes an event
  Future<void> deleteEvent(String id) async {
    try {
      await _apiClient.delete('/api/events/$id');

      // Invalidate cache to force fresh sync
      await _syncService.clearLastSyncTimestamp('events');
    } catch (e) {
      _logger.e('Failed to delete event $id', error: e);
      rethrow;
    }
  }

  /// Responds to an event (accept/decline)
  Future<Map<String, dynamic>> respondToEvent(
    String eventId, {
    required String response, // 'accept' or 'decline'
    String? role,
  }) async {
    try {
      final responseData = await _apiClient.post(
        '/api/events/$eventId/respond',
        data: {
          'response': response,
          if (role != null) 'role': role,
        },
      );

      // Invalidate cache to force fresh sync
      await _syncService.clearLastSyncTimestamp('events');

      return responseData.data as Map<String, dynamic>;
    } catch (e) {
      _logger.e('Failed to respond to event $eventId', error: e);
      rethrow;
    }
  }

  /// Forces a full sync on next fetch (clears delta sync timestamp)
  Future<void> forceFullSync() async {
    await _syncService.clearLastSyncTimestamp('events');
    _logger.i('Forced full sync for events');
  }

  /// Gets the last sync timestamp
  String? getLastSyncTime() {
    return _syncService.getLastSyncTimestamp('events');
  }
}
