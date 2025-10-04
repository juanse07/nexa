# Delta Sync Architecture

## System Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                         Flutter App                              │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  ┌─────────────────┐         ┌──────────────────┐              │
│  │   Repository    │────────▶│  API Service     │              │
│  │  (BLoC/Cubit)   │         │ (with DeltaSync) │              │
│  └─────────────────┘         └──────────────────┘              │
│                                        │                         │
│                                        ▼                         │
│                              ┌──────────────────┐               │
│                              │ DeltaSyncService │               │
│                              │                  │               │
│                              │ • Timestamps     │               │
│                              │ • Delta fetch    │               │
│                              │ • SSE stream     │               │
│                              └──────────────────┘               │
│                                        │                         │
│                         ┌──────────────┴──────────────┐         │
│                         ▼                             ▼         │
│              ┌────────────────────┐        ┌─────────────────┐ │
│              │ SharedPreferences  │        │   API Client    │ │
│              │ (sync timestamps)  │        │   (Dio/HTTP)    │ │
│              └────────────────────┘        └─────────────────┘ │
│                                                      │           │
└──────────────────────────────────────────────────────┼──────────┘
                                                       │
                                                       ▼
┌─────────────────────────────────────────────────────────────────┐
│                      Express Backend                             │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │              REST API Endpoints                           │  │
│  │                                                            │  │
│  │  GET /api/events?lastSync=<timestamp>                     │  │
│  │  ├─ If lastSync provided: filter updatedAt > lastSync     │  │
│  │  ├─ Return changed documents + serverTimestamp            │  │
│  │  └─ Response: {events: [...], serverTimestamp, deltaSync} │  │
│  │                                                            │  │
│  │  GET /api/sync/stream (Server-Sent Events)                │  │
│  │  ├─ Opens SSE connection                                  │  │
│  │  ├─ Watches MongoDB Change Streams                        │  │
│  │  ├─ Sends: {type, collection, operationType, document}    │  │
│  │  └─ Heartbeat every 30s                                   │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                   │
│                              │                                    │
│                              ▼                                    │
│                    ┌──────────────────┐                          │
│                    │  Mongoose (ODM)  │                          │
│                    │  • EventModel    │                          │
│                    │  • UserModel     │                          │
│                    │  • ClientModel   │                          │
│                    └──────────────────┘                          │
│                              │                                    │
└──────────────────────────────┼───────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────────┐
│                      MongoDB Atlas                               │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  ┌──────────────────┐              ┌──────────────────┐         │
│  │   Collections    │              │  Change Streams  │         │
│  │                  │              │                  │         │
│  │  • events        │◀────watch────│  • Replica Set  │         │
│  │  • users         │              │  • Real-time     │         │
│  │  • clients       │              │  • Automatic     │         │
│  │  • roles         │              │                  │         │
│  │  • tariffs       │              └──────────────────┘         │
│  └──────────────────┘                                            │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
```

## Data Flow

### 1. First Sync (Full)

```
Flutter App              Backend                MongoDB
    │                      │                      │
    │  GET /api/events     │                      │
    ├─────────────────────▶│                      │
    │  (no lastSync)       │  find({})            │
    │                      ├─────────────────────▶│
    │                      │  [1000 events]       │
    │                      ◀──────────────────────┤
    │  {events: [1000],    │                      │
    │   serverTimestamp,   │                      │
    │   deltaSync: false}  │                      │
    ◀──────────────────────┤                      │
    │                      │                      │
    │ Save timestamp       │                      │
    │ "2025-01-15T10:00"   │                      │
    │                      │                      │
```

**Data Transfer:** 5MB (1000 events × 5KB)

### 2. Subsequent Sync (Delta)

```
Flutter App              Backend                MongoDB
    │                      │                      │
    │  GET /api/events?    │                      │
    │  lastSync=2025-..    │                      │
    ├─────────────────────▶│                      │
    │                      │  find({             │
    │                      │    updatedAt: {     │
    │                      │      $gt: lastSync  │
    │                      │    }                │
    │                      │  })                 │
    │                      ├─────────────────────▶│
    │                      │  [50 changed]       │
    │                      ◀──────────────────────┤
    │  {events: [50],      │                      │
    │   serverTimestamp,   │                      │
    │   deltaSync: true}   │                      │
    ◀──────────────────────┤                      │
    │                      │                      │
    │ Merge with cache     │                      │
    │ Save new timestamp   │                      │
    │ "2025-01-15T11:00"   │                      │
    │                      │                      │
```

**Data Transfer:** 250KB (50 events × 5KB)
**Savings:** 95% (4.75MB saved)

### 3. Real-time Updates (SSE)

```
Flutter App              Backend                MongoDB
    │                      │                      │
    │  GET /sync/stream    │                      │
    ├─────────────────────▶│  watch([])          │
    │  [SSE connection]    ├─────────────────────▶│
    │◀─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┤  [Change Stream]    │
    │  connected           │                      │
    │                      │                      │
    │                      │      Event updated   │
    │                      │◀─────────────────────┤
    │  change: {           │                      │
    │    type: "update",   │                      │
    │    collection:       │                      │
    │      "events",       │                      │
    │    documentId,       │                      │
    │    fullDocument      │                      │
    │  }                   │                      │
    │◀──────────────────────                      │
    │                      │                      │
    │ Update local cache   │                      │
    │                      │                      │
```

**Benefits:**
- Instant updates
- No polling needed
- Minimal bandwidth

## Timestamp Management

### Storage

```dart
SharedPreferences:
  key: "last_sync_time_events"
  value: "2025-01-15T10:30:00.000Z"

  key: "last_sync_time_users"
  value: "2025-01-15T10:25:00.000Z"

  // One timestamp per collection
```

### Lifecycle

```
┌──────────────┐
│ App Launch   │
└──────┬───────┘
       │
       ▼
┌──────────────────────────┐
│ Load sync timestamps     │
│ from SharedPreferences   │
└──────┬───────────────────┘
       │
       ▼
┌──────────────────────────┐     ┌─────────────────┐
│ First sync?              ├────▶│ Full sync       │
│ (no timestamp)           │ Yes │ (all documents) │
└──────┬───────────────────┘     └─────────┬───────┘
       │ No                               │
       ▼                                  │
┌──────────────────────────┐              │
│ Delta sync               │              │
│ (only changed since      │◀─────────────┘
│  last timestamp)         │
└──────┬───────────────────┘
       │
       ▼
┌──────────────────────────┐
│ Save new timestamp       │
│ from server response     │
└──────────────────────────┘
```

### Invalidation

```
User Action          Action                  Result
───────────────────────────────────────────────────────
Create event    ──▶  clearLastSync('events') ──▶  Next fetch is full sync
Update event    ──▶  clearLastSync('events') ──▶  Next fetch is full sync
Delete event    ──▶  clearLastSync('events') ──▶  Next fetch is full sync
Logout          ──▶  resetAllSyncTimestamps()──▶  All next fetches are full
Manual refresh  ──▶  clearLastSync('events') ──▶  Force fresh data
```

## Performance Comparison

### Without Delta Sync

```
User refreshes app (100 requests/day)
├─ Request 1: 5MB
├─ Request 2: 5MB
├─ Request 3: 5MB
├─ ...
└─ Request 100: 5MB

Total: 500MB/day
```

### With Delta Sync

```
User refreshes app (100 requests/day)
├─ Request 1: 5MB (full sync)
├─ Request 2: 250KB (delta: 50 changes)
├─ Request 3: 100KB (delta: 20 changes)
├─ Request 4: 0KB (delta: no changes)
├─ ...
└─ Request 100: 150KB (delta: 30 changes)

Total: ~30MB/day
Savings: 94%
```

## Error Handling

```
┌─────────────────┐
│ Fetch with      │
│ delta sync      │
└────────┬────────┘
         │
         ▼
    ┌────────┐
    │ Error? │
    └───┬────┘
        │
        ├─ Network error ──▶ Retry with backoff
        │                    Keep timestamp
        │
        ├─ 401/403 ─────────▶ Clear auth token
        │                    Clear all timestamps
        │
        ├─ Invalid data ────▶ Clear collection timestamp
        │                    Force full sync next time
        │
        └─ Server error ────▶ Retry with backoff
                             Keep timestamp
```

## Scalability

### Single User

```
Sync #   Data Transfer   Cumulative
────────────────────────────────────
1        5MB (full)      5MB
2        250KB           5.25MB
3        200KB           5.45MB
...
100      180KB           30MB

Average: 300KB/sync (vs 5MB without delta)
```

### 1,000 Users

```
Without Delta Sync:
  1000 users × 500MB/day = 500GB/day
  Cost: $45/day = $1,350/month

With Delta Sync:
  1000 users × 30MB/day = 30GB/day
  Cost: $2.70/day = $81/month

Savings: $1,269/month (94%)
```

## Best Practices

### ✅ Do

- Store timestamps per collection
- Use server-provided timestamps (not client time)
- Clear timestamps after mutations
- Implement cache merging for delta updates
- Log sync statistics for monitoring
- Handle offline mode gracefully

### ❌ Don't

- Use client timestamps (clock skew issues)
- Share timestamps across collections
- Forget to invalidate after mutations
- Ignore delta sync flag in response
- Store sensitive data in timestamps
- Poll SSE endpoint (it's push-based)

## Monitoring

### Metrics to Track

```dart
// In your app
analytics.track('delta_sync_performed', {
  'collection': 'events',
  'isDelta': result.isDeltaSync,
  'itemCount': result.items.length,
  'dataSize': responseSize,
  'duration': syncDuration,
});

// Aggregate metrics
- Average items per sync
- Delta sync hit rate (delta / total syncs)
- Average data saved per sync
- API response time
```

### Health Checks

```bash
# Backend monitoring
curl "$API_URL/api/events" | jq '.deltaSync'  # Should be false first time
curl "$API_URL/api/events?lastSync=2024-01-01" | jq '.deltaSync'  # Should be true

# SSE monitoring
curl -N "$API_URL/api/sync/stream" | head -n 5  # Should show connected
```

---

**This architecture reduces data transfer by 90-95% while maintaining data consistency and real-time capabilities.**
