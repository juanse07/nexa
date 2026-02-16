import 'dart:async';

import 'package:dio/dio.dart';
import 'package:logger/logger.dart';
import 'package:nexa/core/constants/storage_keys.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing delta synchronization with the backend
///
/// This service implements efficient data syncing by:
/// - Only fetching documents that changed since last sync
/// - Using server timestamps for accurate sync tracking
class DeltaSyncService {
  DeltaSyncService({
    required Dio dio,
    required SharedPreferences prefs,
    required Logger logger,
  })  : _dio = dio,
        _prefs = prefs,
        _logger = logger;

  final Dio _dio;
  final SharedPreferences _prefs;
  final Logger _logger;

  /// Gets the last sync timestamp for a collection
  String? getLastSyncTimestamp(String collection) {
    final key = _getSyncKey(collection);
    return _prefs.getString(key);
  }

  /// Saves the last sync timestamp for a collection
  Future<void> saveLastSyncTimestamp(
    String collection,
    String timestamp,
  ) async {
    final key = _getSyncKey(collection);
    await _prefs.setString(key, timestamp);
  }

  /// Clears the last sync timestamp (forces full sync on next fetch)
  Future<void> clearLastSyncTimestamp(String collection) async {
    final key = _getSyncKey(collection);
    await _prefs.remove(key);
  }

  /// Fetches data with delta sync support
  ///
  /// If a last sync timestamp exists, only changed documents are returned.
  /// Returns both the data and the new server timestamp for next sync.
  Future<DeltaSyncResult<T>> fetch<T>({
    required String endpoint,
    required String collection,
    required T Function(Map<String, dynamic>) fromJson,
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final lastSync = getLastSyncTimestamp(collection);
      final params = {...?queryParameters};

      if (lastSync != null) {
        params['lastSync'] = lastSync;
        _logger.d('Delta sync for $collection since $lastSync');
      } else {
        _logger.d('Full sync for $collection (first sync)');
      }

      final response = await _dio.get(endpoint, queryParameters: params);

      if (response.statusCode == 200) {
        final data = response.data;

        // Handle both legacy (array) and new (object with metadata) formats
        List<dynamic> items;
        String? serverTimestamp;
        bool isDelta = false;

        if (data is List) {
          // Legacy format: just an array
          items = data;
          serverTimestamp = DateTime.now().toIso8601String();
        } else if (data is Map) {
          // New format with metadata
          items = (data['events'] ?? data['items'] ?? data['data'] ?? []) as List;
          serverTimestamp = data['serverTimestamp'] as String?;
          isDelta = data['deltaSync'] == true;
        } else {
          throw Exception('Unexpected response format');
        }

        final parsedItems = items.map((item) => fromJson(item as Map<String, dynamic>)).toList();

        // Save the server timestamp for next sync
        if (serverTimestamp != null) {
          await saveLastSyncTimestamp(collection, serverTimestamp);
        }

        return DeltaSyncResult<T>(
          items: parsedItems,
          serverTimestamp: serverTimestamp,
          isDeltaSync: isDelta,
          changeCount: isDelta ? items.length : null,
        );
      } else {
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          error: 'Sync failed with status ${response.statusCode}',
        );
      }
    } catch (e) {
      _logger.e('Delta sync failed for $collection', error: e);
      rethrow;
    }
  }

  /// Clears all sync timestamps (forces full sync for all collections)
  Future<void> resetAllSyncTimestamps() async {
    final collections = [
      'events',
      'users',
      'clients',
      'roles',
      'tariffs',
    ];

    for (final collection in collections) {
      await clearLastSyncTimestamp(collection);
    }

    _logger.i('Reset all sync timestamps');
  }

  /// Disposes resources
  void dispose() {
    // No-op; retained for API compatibility
  }

  String _getSyncKey(String collection) =>
      '${StorageKeys.lastSyncTime}_$collection';
}

/// Result of a delta sync operation
class DeltaSyncResult<T> {
  DeltaSyncResult({
    required this.items,
    required this.serverTimestamp,
    required this.isDeltaSync,
    this.changeCount,
  });

  /// The synced items
  final List<T> items;

  /// Server timestamp for next sync
  final String? serverTimestamp;

  /// Whether this was a delta sync (vs full sync)
  final bool isDeltaSync;

  /// Number of changes (only set for delta syncs)
  final int? changeCount;

  /// Helper to check if any changes were received
  bool get hasChanges => items.isNotEmpty;

  @override
  String toString() {
    if (isDeltaSync) {
      return 'DeltaSyncResult(delta: $changeCount changes, timestamp: $serverTimestamp)';
    }
    return 'DeltaSyncResult(full: ${items.length} items, timestamp: $serverTimestamp)';
  }
}
