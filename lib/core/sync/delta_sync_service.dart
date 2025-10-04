import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:logger/logger.dart';
import 'package:nexa/core/config/app_config.dart';
import 'package:nexa/core/constants/storage_keys.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing delta synchronization with the backend
///
/// This service implements efficient data syncing by:
/// - Only fetching documents that changed since last sync
/// - Using server timestamps for accurate sync tracking
/// - Supporting real-time updates via Server-Sent Events
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

  // SSE connection
  StreamSubscription<String>? _sseSubscription;
  final _changeController = StreamController<SyncChange>.broadcast();

  /// Stream of real-time changes from the server
  Stream<SyncChange> get changes => _changeController.stream;

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

  /// Starts listening to real-time changes via Server-Sent Events
  Future<void> startRealtimeSync() async {
    if (_sseSubscription != null) {
      _logger.w('Realtime sync already active');
      return;
    }

    try {
      final config = AppConfig.instance;
      final sseUrl = '${config.baseUrl}/api/sync/stream';

      _logger.i('Starting realtime sync: $sseUrl');

      // Note: Dio doesn't support SSE natively, so we'd need to use http package
      // or a specialized SSE library. For now, this is a placeholder structure.
      // In production, you'd use package:eventsource or similar.

      _logger.w('SSE implementation requires eventsource package');
      // TODO: Implement with eventsource package
    } catch (e) {
      _logger.e('Failed to start realtime sync', error: e);
      rethrow;
    }
  }

  /// Stops listening to real-time changes
  Future<void> stopRealtimeSync() async {
    await _sseSubscription?.cancel();
    _sseSubscription = null;
    _logger.i('Stopped realtime sync');
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
    _sseSubscription?.cancel();
    _changeController.close();
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

/// Represents a real-time change from the server
class SyncChange {
  SyncChange({
    required this.collection,
    required this.operationType,
    required this.documentId,
    this.fullDocument,
    required this.timestamp,
  });

  factory SyncChange.fromJson(Map<String, dynamic> json) {
    return SyncChange(
      collection: json['collection'] as String,
      operationType: json['operationType'] as String,
      documentId: json['documentId'] as String,
      fullDocument: json['fullDocument'] as Map<String, dynamic>?,
      timestamp: json['timestamp'] as String,
    );
  }

  final String collection;
  final String operationType; // 'insert', 'update', 'delete', 'replace'
  final String documentId;
  final Map<String, dynamic>? fullDocument;
  final String timestamp;

  bool get isInsert => operationType == 'insert';
  bool get isUpdate => operationType == 'update';
  bool get isDelete => operationType == 'delete';
  bool get isReplace => operationType == 'replace';
}
