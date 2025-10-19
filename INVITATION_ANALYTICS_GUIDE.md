# Event Invitation Analytics Guide

## Overview

This document describes the analytics events tracked throughout the event invitation flow. All events are logged with the `[INVITATION_ANALYTICS]` prefix for easy filtering and monitoring.

---

## Analytics Events

### 1. invitation_sent

**When:** Manager sends an event invitation to a staff member

**Logged in:** Manager app - `chat_screen.dart:343-360`

**Data Points:**
```dart
eventId: String          // The MongoDB ID of the event
roleId: String           // The MongoDB ID of the role within the event
targetId: String         // User ID of staff member receiving invitation
eventName: String        // Human-readable event title
messageId: String        // Chat message ID (available after success)
conversationId: String   // Chat conversation ID
sendDuration: int        // API call duration in milliseconds
```

**Sample Output:**
```
[INVITATION_ANALYTICS] invitation_sent event started
[INVITATION_ANALYTICS] eventId: 507f1f77bcf86cd799439011
[INVITATION_ANALYTICS] roleId: 507f1f77bcf86cd799439012
[INVITATION_ANALYTICS] targetId: user_123
[INVITATION_ANALYTICS] eventName: Summer Gala 2024
[INVITATION_ANALYTICS] invitation_sent success
[INVITATION_ANALYTICS] messageId: 507f1f77bcf86cd799439013
[INVITATION_ANALYTICS] conversationId: 507f1f77bcf86cd799439014
[INVITATION_ANALYTICS] sendDuration: 342ms
```

**Use Cases:**
- Track invitation send rate per manager
- Monitor API performance for sending invitations
- Identify most frequently invited events
- Correlate with acceptance rates

---

### 2. invitation_card_displayed

**When:** Invitation card is rendered in the UI (both manager and staff apps)

**Logged in:**
- Staff app - `chat_page.dart:338-343`
- Manager app - (similar location in `chat_screen.dart`)

**Data Points:**
```dart
messageId: String        // Chat message ID containing the invitation
eventId: String          // Event being invited to
roleId: String           // Role within the event
status: String?          // Current status: pending/accepted/declined
userRole: String         // User viewing the card: manager/staff
eventName: String        // Event title (logged after loading)
roleName: String         // Role name (logged after loading)
```

**Sample Output:**
```
[INVITATION_ANALYTICS] invitation_card_displayed
[INVITATION_ANALYTICS] messageId: 507f1f77bcf86cd799439013
[INVITATION_ANALYTICS] eventId: 507f1f77bcf86cd799439011
[INVITATION_ANALYTICS] roleId: 507f1f77bcf86cd799439012
[INVITATION_ANALYTICS] status: pending
[INVITATION_ANALYTICS] userRole: staff
[INVITATION_ANALYTICS] invitation_card_loaded successfully
[INVITATION_ANALYTICS] eventName: Summer Gala 2024
[INVITATION_ANALYTICS] roleName: Lead Server
```

**Use Cases:**
- Track how many invitations are viewed
- Measure time between receiving and viewing invitations
- Identify cards that fail to load

---

### 3. invitation_responded

**When:** Staff member accepts or declines an invitation

**Logged in:** Staff app - `chat_page.dart:446-465`

**Data Points:**
```dart
messageId: String             // Chat message ID
eventId: String               // Event ID
roleId: String                // Role ID
accept: bool                  // true = accepted, false = declined
responseTimeMinutes: int      // Minutes between send and response
managerId: String             // Manager who sent the invitation
apiCallDuration: int          // API call duration in milliseconds
accepted: bool                // Final status after success
```

**Sample Output:**
```
[INVITATION_ANALYTICS] invitation_responded event started
[INVITATION_ANALYTICS] messageId: 507f1f77bcf86cd799439013
[INVITATION_ANALYTICS] eventId: 507f1f77bcf86cd799439011
[INVITATION_ANALYTICS] roleId: 507f1f77bcf86cd799439012
[INVITATION_ANALYTICS] accept: true
[INVITATION_ANALYTICS] responseTimeMinutes: 15
[INVITATION_ANALYTICS] managerId: manager_456
[INVITATION_ANALYTICS] invitation_responded success
[INVITATION_ANALYTICS] apiCallDuration: 287ms
[INVITATION_ANALYTICS] accepted: true
```

**Use Cases:**
- Calculate acceptance rate (%)
- Measure average response time
- Identify fastest responders
- Track which events get highest acceptance
- Monitor API performance

---

### 4. invitation_responded (Manager Notification)

**When:** Manager receives socket notification that staff responded

**Logged in:** Manager app - `chat_screen.dart:115-144`

**Data Points:**
```dart
rawData: Map<String, dynamic>  // Complete socket payload
messageId: String               // Message ID
status: String                  // accepted/declined
userId: String                  // Staff member user ID
userName: String                // Staff member name
eventId: String                 // Event ID
roleId: String                  // Role ID
responseTimeMinutes: int        // Calculated from original message
accepted: bool                  // true/false
```

**Sample Output:**
```
[INVITATION_ANALYTICS] invitation_responded event received
[INVITATION_ANALYTICS] rawData: {messageId: 507f1f77..., status: accepted, ...}
[INVITATION_ANALYTICS] messageId: 507f1f77bcf86cd799439013
[INVITATION_ANALYTICS] status: accepted
[INVITATION_ANALYTICS] userId: user_123
[INVITATION_ANALYTICS] userName: Jane Smith
[INVITATION_ANALYTICS] eventId: 507f1f77bcf86cd799439011
[INVITATION_ANALYTICS] roleId: 507f1f77bcf86cd799439012
[INVITATION_ANALYTICS] responseTimeMinutes: 15
[INVITATION_ANALYTICS] accepted: true
```

**Use Cases:**
- Measure socket event delivery time
- Track manager engagement with notifications
- Verify real-time update functionality

---

### 5. invitation_error

**When:** Any error occurs during invitation flow

**Logged in:**
- Manager app send - `chat_screen.dart:379-386`
- Staff app response - `chat_page.dart:489-495`

**Data Points:**
```dart
error: String            // Error message/exception
eventId: String          // Event ID
targetId: String?        // User ID (manager app)
messageId: String?       // Message ID (staff app)
step: String             // Which step failed: send/respond
duration: int            // Time spent before error (ms)
```

**Sample Output (Manager):**
```
[INVITATION_ANALYTICS] invitation_error
[INVITATION_ANALYTICS] error: Failed to send invitation: Network error
[INVITATION_ANALYTICS] eventId: 507f1f77bcf86cd799439011
[INVITATION_ANALYTICS] targetId: user_123
[INVITATION_ANALYTICS] step: send
[INVITATION_ANALYTICS] duration: 5234ms
```

**Sample Output (Staff):**
```
[INVITATION_ANALYTICS] invitation_error
[INVITATION_ANALYTICS] error: Failed to respond to invitation: Event role full
[INVITATION_ANALYTICS] messageId: 507f1f77bcf86cd799439013
[INVITATION_ANALYTICS] eventId: 507f1f77bcf86cd799439011
[INVITATION_ANALYTICS] step: respond
[INVITATION_ANALYTICS] duration: 421ms
```

**Use Cases:**
- Monitor error rates
- Identify common failure points
- Track timeout issues (high duration)
- Prioritize bug fixes by error frequency

---

### 6. invitation_card_error

**When:** Invitation card fails to load event data

**Logged in:** Staff app - `chat_page.dart:346, 364-365`

**Data Points:**
```dart
reason: String           // Error reason (missing data, event not found)
messageId: String        // Message ID
eventId: String?         // Event ID if available
roleId: String?          // Role ID if available
```

**Sample Output:**
```
[INVITATION_ANALYTICS] invitation_card_error: missing eventId or roleId
[INVITATION_ANALYTICS] messageId: 507f1f77bcf86cd799439013

[INVITATION_ANALYTICS] invitation_card_error: event not found
[INVITATION_ANALYTICS] eventId: 507f1f77bcf86cd799439011
```

**Use Cases:**
- Track data integrity issues
- Identify deleted/invalid events
- Monitor FutureBuilder failures

---

## Implementing Analytics Collection

### Option 1: Parse Logs (Simple)

Use a log aggregation service to parse `[INVITATION_ANALYTICS]` prefixed logs:

```bash
# Filter invitation analytics from logs
adb logcat | grep "INVITATION_ANALYTICS"

# Count invitation sends
adb logcat | grep "INVITATION_ANALYTICS.*invitation_sent success" | wc -l

# Calculate acceptance rate
sent=$(grep "invitation_sent success" logs.txt | wc -l)
accepted=$(grep "accepted: true" logs.txt | wc -l)
rate=$((accepted * 100 / sent))
echo "Acceptance rate: ${rate}%"
```

### Option 2: Analytics Service Integration

Replace `print()` and `debugPrint()` with analytics SDK calls:

```dart
// Before:
print('[INVITATION_ANALYTICS] invitation_sent success');
print('[INVITATION_ANALYTICS] eventId: $eventId');

// After:
Analytics.track('invitation_sent', {
  'eventId': eventId,
  'roleId': roleId,
  'targetId': targetId,
  'sendDuration': duration.inMilliseconds,
  'status': 'success',
});
```

**Recommended SDKs:**
- Firebase Analytics
- Mixpanel
- Amplitude
- Segment

### Option 3: Custom Analytics Helper

Create a centralized helper:

```dart
// lib/core/analytics/invitation_analytics.dart
class InvitationAnalytics {
  static void trackSent({
    required String eventId,
    required String roleId,
    required String targetId,
    required String eventName,
    String? messageId,
    String? conversationId,
    Duration? duration,
  }) {
    // Log for debugging
    debugPrint('[INVITATION_ANALYTICS] invitation_sent');
    debugPrint('[INVITATION_ANALYTICS] eventId: $eventId');

    // Send to analytics service
    FirebaseAnalytics.instance.logEvent(
      name: 'invitation_sent',
      parameters: {
        'event_id': eventId,
        'role_id': roleId,
        'target_id': targetId,
        'event_name': eventName,
        if (messageId != null) 'message_id': messageId,
        if (conversationId != null) 'conversation_id': conversationId,
        if (duration != null) 'duration_ms': duration.inMilliseconds,
      },
    );
  }
}

// Usage:
InvitationAnalytics.trackSent(
  eventId: eventId,
  roleId: roleId,
  targetId: widget.targetId,
  eventName: eventData['title'],
  messageId: sentMessage.id,
  duration: duration,
);
```

---

## Key Metrics to Track

### Invitation Funnel
```
1. Invitations Sent
2. Invitations Viewed (card displayed)
3. Invitations Responded
4. Invitations Accepted
```

**Formula:**
- View Rate = (Viewed / Sent) × 100%
- Response Rate = (Responded / Viewed) × 100%
- Acceptance Rate = (Accepted / Responded) × 100%
- Overall Conversion = (Accepted / Sent) × 100%

### Performance Metrics
- Average send duration (ms)
- Average response API duration (ms)
- P95 and P99 latencies
- Error rate (errors / total operations)

### Behavioral Metrics
- Average response time (minutes)
- Median response time
- Fastest response time
- Time-to-first-view after receiving

### Event Insights
- Most invited events (by invitation count)
- Events with highest acceptance rate
- Events with fastest response times
- Most invited roles

### User Insights
- Most active managers (by invitation count)
- Most responsive staff (by avg response time)
- Staff with highest acceptance rate

---

## Sample Queries

### BigQuery (if using Firebase Analytics)

**Acceptance Rate:**
```sql
WITH sent AS (
  SELECT COUNT(*) as total_sent
  FROM events
  WHERE event_name = 'invitation_sent'
    AND event_timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)
),
accepted AS (
  SELECT COUNT(*) as total_accepted
  FROM events
  WHERE event_name = 'invitation_responded'
    AND event_params.key = 'accepted'
    AND event_params.value.int_value = 1
    AND event_timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)
)
SELECT
  sent.total_sent,
  accepted.total_accepted,
  ROUND(accepted.total_accepted * 100.0 / sent.total_sent, 2) as acceptance_rate
FROM sent, accepted;
```

**Average Response Time:**
```sql
SELECT
  AVG(
    (SELECT value.int_value
     FROM UNNEST(event_params)
     WHERE key = 'responseTimeMinutes')
  ) as avg_response_time_minutes
FROM events
WHERE event_name = 'invitation_responded'
  AND event_timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 30 DAY);
```

**Top Events by Acceptance Rate:**
```sql
WITH invitations AS (
  SELECT
    (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'event_id') as event_id,
    (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'event_name') as event_name,
    (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'accepted') as accepted
  FROM events
  WHERE event_name = 'invitation_responded'
)
SELECT
  event_name,
  COUNT(*) as total_invitations,
  SUM(CASE WHEN accepted = 1 THEN 1 ELSE 0 END) as total_accepted,
  ROUND(SUM(CASE WHEN accepted = 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) as acceptance_rate
FROM invitations
GROUP BY event_name
ORDER BY acceptance_rate DESC
LIMIT 10;
```

---

## Dashboard Recommendations

### Real-time Dashboard Widgets

1. **Invitation Overview (Today)**
   - Total invitations sent
   - Total accepted
   - Total declined
   - Acceptance rate (%)

2. **Performance Metrics**
   - Average send duration
   - Average response duration
   - Error rate

3. **Recent Activity Feed**
   - Last 10 invitations sent
   - Last 10 responses

4. **Leaderboards**
   - Top 5 managers by invitation count
   - Top 5 staff by fastest response time

### Weekly Reports

1. **Invitation Summary**
   - Total sent, accepted, declined
   - Week-over-week change
   - Acceptance rate trend

2. **Event Insights**
   - Most popular events
   - Events with best acceptance rates
   - Events with longest response times

3. **Error Analysis**
   - Total errors
   - Error breakdown by type
   - Most common error messages

---

## Testing Analytics

### Manual Testing

```dart
// Add temporary logging to verify events
@override
void initState() {
  super.initState();
  print('[TEST] ChatScreen initialized');
  // ... rest of init
}

Future<void> _sendEventInvitation(...) async {
  print('[TEST] Starting invitation send flow');
  // ... send logic
  print('[TEST] Invitation send completed');
}
```

### Automated Testing

```dart
testWidgets('Logs analytics on invitation send', (tester) async {
  final logs = <String>[];

  // Override print to capture logs
  final spec = ZoneSpecification(
    print: (self, parent, zone, message) {
      logs.add(message);
    },
  );

  await runZoned(() async {
    await tester.pumpWidget(MyApp());
    // Trigger invitation send
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();
  }, zoneSpecification: spec);

  expect(
    logs.any((log) => log.contains('[INVITATION_ANALYTICS] invitation_sent')),
    isTrue,
  );
});
```

---

## Privacy & Compliance

### GDPR Compliance
- Do NOT log personally identifiable information (PII) like names or emails in production
- Use anonymized user IDs instead
- Implement data retention policies (e.g., delete logs after 90 days)

### Production Best Practices
```dart
// Development: Log everything
if (kDebugMode) {
  debugPrint('[INVITATION_ANALYTICS] userName: $userName');
}

// Production: Only IDs
Analytics.track('invitation_sent', {
  'user_id': userId,  // ✅ OK
  // 'user_name': userName,  // ❌ Don't log PII
});
```

---

## Troubleshooting

### Issue: Analytics not appearing in logs

**Check:**
1. Verify app is running in debug mode
2. Search for `INVITATION_ANALYTICS` (case-sensitive)
3. Check if debug logging is disabled

**Fix:**
```bash
# Enable all logs
adb logcat *:V

# Filter for analytics
adb logcat | grep -i "analytics"
```

### Issue: Missing data in analytics events

**Check:**
1. Verify all required parameters are non-null
2. Check for early returns or exceptions
3. Add temporary logging before analytics calls

**Fix:**
```dart
print('[DEBUG] About to log analytics');
print('[DEBUG] eventId: $eventId (${eventId.runtimeType})');
// ... log analytics
print('[DEBUG] Analytics logged successfully');
```

---

## Contact

For questions about analytics implementation:
- Review this documentation
- Check existing analytics logs in the apps
- Follow the implementation patterns shown above
