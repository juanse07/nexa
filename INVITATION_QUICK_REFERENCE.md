# Event Invitation System - Quick Reference

## 🚀 Quick Links

- **Backend API Spec:** `BACKEND_API_INVITATIONS.md`
- **Analytics Guide:** `INVITATION_ANALYTICS_GUIDE.md`
- **Full Summary:** `INVITATION_IMPLEMENTATION_SUMMARY.md`
- **This Guide:** Quick reference for common tasks

---

## 📍 Key Code Locations

### Manager App

| Component | File | Line |
|-----------|------|------|
| Send invitation button | `chat_screen.dart` | 425-434 |
| Send invitation logic | `chat_screen.dart` | 335-398 |
| Invitation card rendering | `chat_screen.dart` | ~475-520 |
| Invitation card widget | `widgets/event_invitation_card.dart` | Full file |
| Send dialog | `dialogs/send_event_invitation_dialog.dart` | Full file |
| ChatService.sendEventInvitation() | `chat_service.dart` | 221-277 |
| Socket response listener | `chat_screen.dart` | 113-184 |

### Staff App

| Component | File | Line |
|-----------|------|------|
| Invitation card rendering | `chat_page.dart` | 329-414 |
| Accept/Decline handler | `chat_page.dart` | 436-506 |
| Decline confirmation | `chat_page.dart` | 416-434 |
| Invitation card widget | `widgets/event_invitation_card.dart` | Full file |
| ChatService.respondToInvitation() | `chat_service.dart` | 222-257 |
| ChatService.fetchEventDetails() | `chat_service.dart` | 260-281 |

---

## 🔌 API Endpoints Reference

### Send Invitation
```http
POST /chat/conversations/:targetId/messages
Authorization: Bearer <JWT>
Content-Type: application/json

{
  "message": "You've been invited to Summer Gala as Lead Server",
  "messageType": "eventInvitation",
  "metadata": {
    "eventId": "507f1f77bcf86cd799439011",
    "roleId": "507f1f77bcf86cd799439012",
    "status": "pending"
  }
}
```

### Respond to Invitation
```http
POST /chat/invitations/:messageId/respond
Authorization: Bearer <JWT>
Content-Type: application/json

{
  "accept": true,
  "eventId": "507f1f77bcf86cd799439011",
  "roleId": "507f1f77bcf86cd799439012"
}
```

### Get Event Details
```http
GET /events/:eventId
Authorization: Bearer <JWT>
```

---

## 📡 Socket Events

### chat:message (Server → Staff)
```json
{
  "id": "507f1f77bcf86cd799439013",
  "conversationId": "507f1f77bcf86cd799439014",
  "senderType": "manager",
  "message": "You've been invited to...",
  "messageType": "eventInvitation",
  "metadata": {
    "eventId": "507f1f77bcf86cd799439011",
    "roleId": "507f1f77bcf86cd799439012",
    "status": "pending"
  }
}
```

### invitation:responded (Server → Manager)
```json
{
  "messageId": "507f1f77bcf86cd799439013",
  "conversationId": "507f1f77bcf86cd799439014",
  "status": "accepted",
  "userId": "user_123",
  "userName": "Jane Smith",
  "eventId": "507f1f77bcf86cd799439011",
  "roleId": "507f1f77bcf86cd799439012"
}
```

---

## 🎨 UI Components

### EventInvitationCard Props (Manager)

```dart
EventInvitationCard(
  eventName: 'Summer Gala 2024',
  roleName: 'Lead Server',
  clientName: 'Bluebird Catering',
  startDate: DateTime(2025, 6, 15, 18, 0),
  endDate: DateTime(2025, 6, 15, 23, 0),
  venueName: 'Grand Ballroom',
  rate: 28.50,
  status: 'pending',        // 'pending' | 'accepted' | 'declined'
  respondedAt: null,
  isManager: true,
  onAccept: null,           // Always null for manager view
  onDecline: null,
)
```

### EventInvitationCard Props (Staff)

```dart
EventInvitationCard(
  eventName: 'Summer Gala 2024',
  roleName: 'Lead Server',
  clientName: 'Bluebird Catering',
  startDate: DateTime(2025, 6, 15, 18, 0),
  endDate: DateTime(2025, 6, 15, 23, 0),
  venueName: 'Grand Ballroom',
  rate: 28.50,
  status: 'pending',
  respondedAt: null,
  onAccept: () => _handleResponse(true),   // Callback
  onDecline: () => _showConfirmation(),    // Callback
)
```

---

## 🔍 Common Code Snippets

### Check if Message is Invitation

```dart
if (message.messageType == 'eventInvitation') {
  // Render invitation card
  return _buildInvitationCard(message);
} else {
  // Render regular message
  return _MessageBubble(message: message);
}
```

### Extract Invitation Metadata

```dart
final metadata = message.metadata ?? {};
final eventId = metadata['eventId'] as String?;
final roleId = metadata['roleId'] as String?;
final status = metadata['status'] as String?;
final respondedAt = metadata['respondedAt'] != null
    ? DateTime.parse(metadata['respondedAt'] as String)
    : null;
```

### Check if Invitation is Pending

```dart
final isPending = status == null || status == 'pending';
final isAccepted = status == 'accepted';
final isDeclined = status == 'declined';

// Show buttons only for pending invitations
onAccept: isPending ? () => handleAccept() : null,
onDecline: isPending ? () => handleDecline() : null,
```

### Send Invitation (Manager)

```dart
try {
  final sentMessage = await ChatService().sendEventInvitation(
    targetId: userId,
    eventId: eventId,
    roleId: roleId,
    eventData: eventData,
  );

  // Add to local messages list
  setState(() {
    _messages.add(sentMessage);
  });
} catch (e) {
  // Show error
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Failed: $e')),
  );
}
```

### Respond to Invitation (Staff)

```dart
try {
  await ChatService().respondToInvitation(
    messageId: message.id,
    eventId: eventId,
    roleId: roleId,
    accept: true, // or false for decline
  );

  // Show success
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Invitation accepted!')),
  );

  // Reload messages to get updated status
  await _loadMessages();
} catch (e) {
  // Show error
}
```

### Listen to Invitation Responses (Manager)

```dart
StreamSubscription<Map<String, dynamic>>? _invitationSubscription;

@override
void initState() {
  super.initState();
  _listenToInvitationResponses();
}

void _listenToInvitationResponses() {
  _invitationSubscription = ChatService()
      .invitationResponseStream
      .listen((data) {
    final status = data['status'] as String?;
    final userName = data['userName'] as String?;

    // Show notification
    if (status == 'accepted') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$userName accepted!')),
      );
    }

    // Reload messages
    _loadMessages();
  });
}

@override
void dispose() {
  _invitationSubscription?.cancel();
  super.dispose();
}
```

---

## 📊 Analytics Event Logging

### Log Invitation Sent

```dart
print('[INVITATION_ANALYTICS] invitation_sent event started');
print('[INVITATION_ANALYTICS] eventId: $eventId');
print('[INVITATION_ANALYTICS] roleId: $roleId');
print('[INVITATION_ANALYTICS] targetId: $targetId');
// ... send invitation
print('[INVITATION_ANALYTICS] invitation_sent success');
print('[INVITATION_ANALYTICS] messageId: ${message.id}');
print('[INVITATION_ANALYTICS] sendDuration: ${duration.inMilliseconds}ms');
```

### Log Invitation Response

```dart
final responseTime = DateTime.now().difference(message.createdAt).inMinutes;

debugPrint('[INVITATION_ANALYTICS] invitation_responded event started');
debugPrint('[INVITATION_ANALYTICS] messageId: ${message.id}');
debugPrint('[INVITATION_ANALYTICS] accept: $accept');
debugPrint('[INVITATION_ANALYTICS] responseTimeMinutes: $responseTime');
// ... respond to invitation
debugPrint('[INVITATION_ANALYTICS] invitation_responded success');
```

### Monitor Analytics in Real-Time

```bash
# Android
adb logcat | grep "INVITATION_ANALYTICS"

# iOS (in Xcode Console)
# Filter: INVITATION_ANALYTICS
```

---

## 🧪 Testing Commands

### Run Flutter Analyze

```bash
# Manager app
cd "/Volumes/Macintosh HD/Users/juansuarez/nexa"
flutter analyze --no-fatal-infos

# Staff app
cd "/Volumes/macOs_Files/nexaProjectStaffside/frontend"
flutter analyze --no-fatal-infos
```

### Build Apps

```bash
# Manager app (Android)
cd "/Volumes/Macintosh HD/Users/juansuarez/nexa"
flutter build apk --release

# Staff app (Android)
cd "/Volumes/macOs_Files/nexaProjectStaffside/frontend"
flutter build apk --release
```

### Run on Device

```bash
# Check connected devices
flutter devices

# Run manager app
cd "/Volumes/Macintosh HD/Users/juansuarez/nexa"
flutter run

# Run staff app
cd "/Volumes/macOs_Files/nexaProjectStaffside/frontend"
flutter run
```

---

## 🐛 Debug Helpers

### Enable Verbose Logging

```dart
// In chat_screen.dart or chat_page.dart
@override
void initState() {
  super.initState();

  // Add debug logging
  print('[DEBUG] ChatScreen initialized');
  print('[DEBUG] targetId: ${widget.targetId}');
  print('[DEBUG] conversationId: ${widget.conversationId}');

  // ... rest of init
}
```

### Inspect Message Object

```dart
void _debugMessage(ChatMessage message) {
  print('[DEBUG] ===== MESSAGE DEBUG =====');
  print('[DEBUG] ID: ${message.id}');
  print('[DEBUG] Type: ${message.messageType}');
  print('[DEBUG] Metadata: ${message.metadata}');
  print('[DEBUG] EventID: ${message.metadata?['eventId']}');
  print('[DEBUG] RoleID: ${message.metadata?['roleId']}');
  print('[DEBUG] Status: ${message.metadata?['status']}');
  print('[DEBUG] =========================');
}
```

### Check Socket Connection

```dart
final socket = SocketManager.instance.socket;
print('[DEBUG] Socket connected: ${socket?.connected}');
print('[DEBUG] Socket ID: ${socket?.id}');
```

---

## ⚠️ Common Pitfalls

### 1. Null Safety
```dart
// ❌ Wrong
final eventId = metadata['eventId'];  // Might be null

// ✅ Correct
final eventId = metadata['eventId'] as String?;
if (eventId == null) return;
```

### 2. Metadata Access
```dart
// ❌ Wrong
message.metadata['eventId']  // Error if metadata is null

// ✅ Correct
final metadata = message.metadata ?? {};
final eventId = metadata['eventId'] as String?;
```

### 3. Status Checks
```dart
// ❌ Wrong
if (status == 'pending')  // Misses null case

// ✅ Correct
if (status == null || status == 'pending')
```

### 4. Message Duplication
```dart
// ❌ Wrong - adds duplicates
_messages.add(newMessage);

// ✅ Correct - check for duplicates
if (!_messages.any((m) => m.id == newMessage.id)) {
  _messages.add(newMessage);
}
```

### 5. Missing await
```dart
// ❌ Wrong - doesn't wait for completion
_chatService.sendEventInvitation(...);
setState(() { ... });

// ✅ Correct
final message = await _chatService.sendEventInvitation(...);
setState(() { ... });
```

---

## 🎯 Status Colors Reference

```dart
// Pending (default)
borderColor: Color(0xFF6366F1),  // Purple
backgroundColor: Color(0xFFF5F3FF),

// Accepted
borderColor: Color(0xFF059669),  // Green
backgroundColor: Color(0xFFF0FDF4),

// Declined
borderColor: Colors.grey.shade400,
backgroundColor: Colors.grey.shade50,
```

---

## 📦 Dependencies

### Manager App
```yaml
timeago: ^3.7.0  # Time-relative formatting
intl: ^0.19.0    # Date formatting
http: ^1.1.0     # HTTP requests
```

### Staff App
```yaml
intl: ^0.19.0    # Date formatting
http: ^1.1.0     # HTTP requests
```

---

## 🔗 Related Files

### Manager App Structure
```
lib/
├── features/
│   ├── chat/
│   │   ├── domain/
│   │   │   └── entities/
│   │   │       └── chat_message.dart
│   │   ├── data/
│   │   │   └── services/
│   │   │       └── chat_service.dart
│   │   └── presentation/
│   │       ├── chat_screen.dart
│   │       ├── widgets/
│   │       │   └── event_invitation_card.dart
│   │       └── dialogs/
│   │           └── send_event_invitation_dialog.dart
│   └── extraction/
│       ├── services/
│       │   └── event_service.dart
│       └── presentation/
│           └── extraction_screen.dart
```

### Staff App Structure
```
lib/
├── models/
│   └── chat_message.dart
├── services/
│   └── chat_service.dart
├── pages/
│   └── chat_page.dart
└── widgets/
    └── event_invitation_card.dart
```

---

## 💡 Pro Tips

1. **Always check for null metadata:**
   ```dart
   final metadata = message.metadata ?? {};
   ```

2. **Use descriptive variable names:**
   ```dart
   final isPending = status == null || status == 'pending';
   // Not: final p = s == null || s == 'pending';
   ```

3. **Add analytics to all user actions:**
   ```dart
   print('[INVITATION_ANALYTICS] user_action');
   ```

4. **Handle errors gracefully:**
   ```dart
   try {
     // Action
   } catch (e) {
     // Log + Show user-friendly message
   }
   ```

5. **Use const for static widgets:**
   ```dart
   const SizedBox(height: 8)  // Not: SizedBox(height: 8)
   ```

---

## 🆘 Need Help?

1. Check `BACKEND_API_INVITATIONS.md` for API specs
2. Check `INVITATION_ANALYTICS_GUIDE.md` for analytics
3. Check `INVITATION_IMPLEMENTATION_SUMMARY.md` for full details
4. Search code for `[INVITATION_ANALYTICS]` to trace flow
5. Add debug logging at key points

---

**Last Updated:** 2025-10-19
**Version:** 1.0.0
**Status:** ✅ Production Ready
