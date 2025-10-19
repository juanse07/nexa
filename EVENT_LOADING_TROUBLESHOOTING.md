# Event Loading Troubleshooting Guide

## Issue: Event Not Appearing in Invitation Dialog

### Why This Happens

The `SendEventInvitationDialog` only shows **upcoming events** (events in the future). This is intentional to prevent sending invitations for events that have already passed.

**Code Location:** `lib/features/chat/presentation/dialogs/send_event_invitation_dialog.dart` lines 54-61

```dart
// Filter only upcoming/future events
final now = DateTime.now();
final upcomingEvents = events.where((event) {
  if (event['start_date'] != null) {
    final startDate = DateTime.parse(event['start_date'] as String);
    return startDate.isAfter(now);  // ← Only shows future events
  }
  return false;  // ← Events without start_date are excluded
}).toList();
```

### Check Your Event Data

Your event will be **excluded** if:

1. **`start_date` is in the past**
   - Example: Event created on Oct 15 with start_date of Oct 10
   - Solution: Update the event's `start_date` to a future date

2. **`start_date` is null/missing**
   - Example: Event created without a `start_date` field
   - Solution: Add a valid `start_date` to the event

3. **`start_date` is not a valid ISO 8601 string**
   - Example: `start_date: "2025-10-25"` (missing time)
   - Should be: `start_date: "2025-10-25T18:00:00.000Z"`

### How to Debug

#### Option 1: Check Your Event in Database

Look at your event's `start_date` field:

```javascript
// MongoDB
db.events.findOne({ _id: ObjectId("your_event_id") })

// Should return something like:
{
  _id: ObjectId("..."),
  title: "Your Event",
  start_date: "2025-10-25T18:00:00.000Z",  // ← Must be in the FUTURE
  // ...
}
```

#### Option 2: Add Temporary Logging

Add this to `send_event_invitation_dialog.dart` line 52 to see what's happening:

```dart
final events = await _eventService.fetchEvents();

// Add debug logging
print('[DEBUG] Total events fetched: ${events.length}');
for (var event in events) {
  print('[DEBUG] Event: ${event['title']}');
  print('[DEBUG]   start_date: ${event['start_date']}');
  print('[DEBUG]   is future: ${event['start_date'] != null && DateTime.parse(event['start_date']).isAfter(DateTime.now())}');
}

// Filter only upcoming/future events
final now = DateTime.now();
// ...
```

Then run the app and check console output when you open the invitation dialog.

#### Option 3: Temporarily Show All Events

For testing, you can temporarily disable the future-only filter:

```dart
// BEFORE (lines 54-61):
final upcomingEvents = events.where((event) {
  if (event['start_date'] != null) {
    final startDate = DateTime.parse(event['start_date'] as String);
    return startDate.isAfter(now);
  }
  return false;
}).toList();

// AFTER (temporary - for debugging):
final upcomingEvents = events; // Show ALL events
```

**WARNING:** Remember to revert this change after testing! You don't want to send invitations for past events in production.

### Common Scenarios

#### Scenario 1: Created Event for Today
```dart
// Event start_date: 2025-10-19T09:00:00.000Z
// Current time:     2025-10-19T14:30:00.000Z

// Result: Event is EXCLUDED (start time has passed)
```

**Solution:** Set `start_date` to a future time:
```dart
start_date: "2025-10-20T18:00:00.000Z"  // Tomorrow at 6pm
```

#### Scenario 2: Event Missing start_date
```json
{
  "_id": "67123abc...",
  "title": "My Event",
  "client_name": "ACME Corp",
  // start_date is missing!
  "roles": [...]
}
```

**Solution:** Add a `start_date`:
```javascript
db.events.updateOne(
  { _id: ObjectId("67123abc...") },
  { $set: { start_date: new Date("2025-10-25T18:00:00.000Z") } }
)
```

#### Scenario 3: Wrong Date Format
```json
{
  "start_date": "10/25/2025"  // ❌ Wrong format
}
```

**Solution:** Use ISO 8601 format:
```json
{
  "start_date": "2025-10-25T18:00:00.000Z"  // ✅ Correct
}
```

### How the Event Creation Flow Works

When you create an event "the old way":

1. **POST /events** (via `EventService.createEvent()`)
   - Endpoint: `lib/features/extraction/services/event_service.dart` line 18
   - This is the CORRECT endpoint - no changes needed

2. **Event stored in database**
   - With whatever `start_date` you provided

3. **Invitation dialog fetches events**
   - Calls `GET /events` (same endpoint)
   - Filters to show only `start_date > now`

**The endpoint hasn't changed** - the invitation feature uses the same `/events` API you've always used.

### Quick Fix Checklist

- [ ] Check event's `start_date` in database
- [ ] Verify `start_date` is in ISO 8601 format
- [ ] Verify `start_date` is in the FUTURE (not past or today)
- [ ] Verify `start_date` is not null
- [ ] Try creating a new test event with future date
- [ ] Check console logs for errors when opening invitation dialog

### If Event Still Doesn't Appear

1. **Check API response:**
   ```bash
   # Look at what the API returns
   adb logcat | grep "EventService"
   ```

2. **Check network tab:**
   - Open invitation dialog
   - Look for `GET /events` request
   - Check if your event is in the response

3. **Verify event structure:**
   Your event must have these fields:
   ```json
   {
     "_id": "string",
     "title": "string",
     "start_date": "ISO 8601 string (future)",
     "roles": [
       {
         "_id": "string",
         "role_name": "string",
         // ... other role fields
       }
     ]
   }
   ```

### Need to Show Past Events?

If you genuinely need to send invitations for past events, edit this line:

**File:** `lib/features/chat/presentation/dialogs/send_event_invitation_dialog.dart`
**Line:** 58

```dart
// Change from:
return startDate.isAfter(now);

// To:
return true;  // Show all events regardless of date
```

---

## Related Files

- **Event loading:** `dialogs/send_event_invitation_dialog.dart:44-73`
- **Event service:** `services/event_service.dart:10-53`
- **API endpoint:** `/events` (no changes made to this)

---

**Last Updated:** 2025-10-19
**Issue:** Events not appearing in invitation dialog
**Root Cause:** Dialog filters to show only upcoming events (start_date > now)
