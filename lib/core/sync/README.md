# Delta Sync Implementation

This directory contains the delta sync implementation that reduces data transfer costs by only fetching changed documents.

## How it Works

### Backend (Node.js/Express)
1. **Timestamp-based queries**: The `/api/events?lastSync=<timestamp>` endpoint filters documents by `updatedAt > lastSync`
2. **Change Streams**: The `/api/sync/stream` endpoint provides real-time updates via Server-Sent Events
3. **Response format**: Returns `{ events: [], serverTimestamp: "...", deltaSync: true/false }`

### Flutter Client
1. **DeltaSyncService**: Manages sync timestamps and coordinates delta fetches
2. **Storage**: Uses SharedPreferences to store last sync timestamps per collection
3. **Automatic**: Automatically appends `?lastSync=` parameter when available

## Usage Example

### Basic Delta Sync

```dart
// In your repository or service class
import 'package:nexa/core/sync/delta_sync_service.dart';

class EventsService {
  final DeltaSyncService _syncService;
  final Dio _dio;

  Future<List<Event>> fetchEvents() async {
    final result = await _syncService.fetch<Event>(
      endpoint: '/api/events',
      collection: 'events',
      fromJson: (json) => Event.fromJson(json),
    );

    if (result.isDeltaSync) {
      print('Delta sync: ${result.changeCount} changes');
      // Merge changes with local cache
      return _mergeWithCache(result.items);
    } else {
      print('Full sync: ${result.items.length} items');
      // Replace cache with full data
      return result.items;
    }
  }
}
```

### Registering the Service (Dependency Injection)

```dart
// In lib/core/di/injection.dart
@module
abstract class AppModule {
  @lazySingleton
  DeltaSyncService deltaSyncService(
    Dio dio,
    SharedPreferences prefs,
    Logger logger,
  ) {
    return DeltaSyncService(
      dio: dio,
      prefs: prefs,
      logger: logger,
    );
  }
}
```

### Using in a BLoC

```dart
class EventsBloc extends Bloc<EventsEvent, EventsState> {
  final DeltaSyncService _syncService;

  Future<void> _onRefreshEvents(
    RefreshEvents event,
    Emitter<EventsState> emit,
  ) async {
    final result = await _syncService.fetch<Event>(
      endpoint: '/api/events',
      collection: 'events',
      fromJson: Event.fromJson,
    );

    emit(EventsLoaded(
      events: result.items,
      isDeltaSync: result.isDeltaSync,
    ));
  }
}
```

## Benefits

### Data Transfer Reduction
- **First sync**: Fetches all documents (100%)
- **Subsequent syncs**: Only fetches changed documents (~5-10% typically)
- **Savings**: 90-95% reduction in data transfer after initial sync

### Example Savings
```
Full sync: 1000 events × 5KB = 5MB
Delta sync: 50 changed events × 5KB = 250KB
Savings: 95% (4.75MB saved)
```

### Cost Impact
If your MongoDB Atlas data transfer costs $0.09/GB:
- Before: 5MB × 100 syncs/day = 500MB/day = $0.045/day = $13.50/month
- After: 5MB + (0.25MB × 99) = 29.75MB/day = $0.0027/day = $0.81/month
- **Savings: ~$12.69/month** (94% reduction)

## Real-time Updates (Optional)

For real-time updates, you can listen to Change Streams:

```dart
// Start listening to changes
await _syncService.startRealtimeSync();

// Listen to change stream
_syncService.changes.listen((change) {
  if (change.collection == 'events') {
    if (change.isUpdate) {
      // Update local cache
    } else if (change.isInsert) {
      // Add to local cache
    } else if (change.isDelete) {
      // Remove from local cache
    }
  }
});

// Stop listening when done
await _syncService.stopRealtimeSync();
```

## Manual Sync Control

```dart
// Force full sync (clears timestamp)
await _syncService.clearLastSyncTimestamp('events');

// Reset all collections
await _syncService.resetAllSyncTimestamps();

// Check last sync time
final lastSync = _syncService.getLastSyncTimestamp('events');
print('Last synced: $lastSync');
```

## Collections Supported

- `events`
- `users`
- `clients`
- `roles`
- `tariffs`

## Important Notes

1. **MongoDB Replica Set Required**: Change Streams require MongoDB to be running as a replica set. MongoDB Atlas automatically provides this.

2. **Network Considerations**: SSE connections work best with good network connectivity. Consider implementing reconnection logic.

3. **Cache Management**: Delta sync requires you to maintain a local cache and merge changes. Consider using Hive, Isar, or SQLite for local storage.

4. **Error Handling**: Always handle network failures gracefully and fall back to full sync if needed.

## Migration Path

1. ✅ Backend updated with delta sync endpoints
2. ✅ DeltaSyncService created
3. ⏳ Update repositories to use DeltaSyncService
4. ⏳ Implement local caching strategy
5. ⏳ Add real-time sync (optional)
6. ⏳ Test and measure data savings
