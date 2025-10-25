# OneSignal Push Notifications Setup Guide

## 🚀 Quick Start

This guide will help you set up OneSignal push notifications for the Nexa project.

## 1. Create OneSignal Account & App

1. Go to [OneSignal.com](https://onesignal.com) and create a free account
2. Create a new app called "Nexa"
3. You'll get:
   - **App ID**: `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`
   - **REST API Key**: `xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx`

## 2. Configure Platforms in OneSignal

### Android Setup
1. In OneSignal Dashboard → Settings → Platforms → Google Android (FCM)
2. You need a Firebase Server Key:
   - Go to [Firebase Console](https://console.firebase.google.com)
   - Create/select your project
   - Project Settings → Cloud Messaging → Server Key
   - Copy and paste into OneSignal

### iOS Setup
1. In OneSignal Dashboard → Settings → Platforms → Apple iOS (APNs)
2. Upload your APNs .p8 certificate:
   - Get from Apple Developer Portal
   - Certificates, Identifiers & Profiles → Keys
   - Create key with Apple Push Notifications service (APNs)
   - Download .p8 file and upload to OneSignal

## 3. Backend Configuration

### Environment Variables
Add to your backend `.env` file:
```env
ONESIGNAL_APP_ID=your-app-id-here
ONESIGNAL_REST_API_KEY=your-rest-api-key-here
```

### Database Migration
The models have been updated. Restart your backend to apply schema changes:
```bash
cd backend
npm run dev
```

## 4. Flutter Apps Configuration

### Update OneSignal App ID

#### Manager App
Edit `/Volumes/Data/Users/juansuarez/nexa/lib/services/notification_service.dart`:
```dart
// Line 19 - Replace with your actual App ID
static const String _oneSignalAppId = 'your-onesignal-app-id-here';
```

#### Staff App
Edit `/Volumes/macOs_Files/nexaProjectStaffside/frontend/lib/services/notification_service.dart`:
```dart
// Line 19 - Replace with your actual App ID
static const String _oneSignalAppId = 'your-onesignal-app-id-here';
```

### Initialize in App Startup

#### Manager App
In your main app initialization (e.g., `main.dart` or after login):
```dart
import 'package:nexa/services/notification_service.dart';

// After successful login
await NotificationService().initialize();
```

#### Staff App
In your main app initialization (e.g., `main.dart` or after login):
```dart
import 'package:frontend/services/notification_service.dart';

// After successful login
await NotificationService().initialize();
```

### iOS Configuration

#### Info.plist Updates
Add to `ios/Runner/Info.plist`:
```xml
<key>UIBackgroundModes</key>
<array>
  <string>fetch</string>
  <string>remote-notification</string>
</array>
```

#### Enable Push Notifications Capability
1. Open `ios/Runner.xcworkspace` in Xcode
2. Select Runner target
3. Signing & Capabilities tab
4. Click "+ Capability"
5. Add "Push Notifications"

### Android Configuration

The OneSignal Flutter SDK handles most Android configuration automatically.

## 5. Testing Push Notifications

### Test from Backend
```bash
# Send test notification via API
curl -X POST http://localhost:3000/api/notifications/test \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json"
```

### Test from OneSignal Dashboard
1. Go to OneSignal Dashboard → Messages → New Push
2. Select your audience (All Users or Test Users)
3. Compose message and send

### Test from Flutter App
```dart
// In your test screen
ElevatedButton(
  onPressed: () async {
    await NotificationService().sendTestNotification();
  },
  child: Text('Send Test Notification'),
)
```

## 6. Notification Types Implemented

The system automatically sends notifications for:

- **Chat Messages** 📬
  - When user/manager receives a new message
  - Shows sender name and message preview

- **Task Assignments** ✅
  - When staff is assigned to a task
  - When task status changes

- **Event Updates** 📅
  - When new events are created
  - When event details change

- **Hours Approval** ⏰
  - When staff submits hours for approval
  - When manager approves/rejects hours

- **System Alerts** 🔔
  - Important announcements
  - Maintenance notifications

## 7. User Preferences

Users can manage their notification preferences:

```dart
// Update preferences
await NotificationService().updatePreferences({
  'chat': true,
  'tasks': true,
  'events': false,
  'hoursApproval': true,
  'system': true,
  'marketing': false,
});
```

## 8. Production Deployment

### Backend
1. Add OneSignal credentials to production `.env`
2. Deploy backend:
```bash
ssh app@198.58.111.243
cd ~/nexa-backend
./deploy.sh
```

### Flutter Apps
1. Update OneSignal App ID in both apps
2. Build release versions:
```bash
# Android
flutter build apk --release

# iOS
flutter build ios --release
```

## 9. Monitoring & Analytics

### OneSignal Dashboard
- View delivery rates
- Track click-through rates
- Monitor device registrations
- See notification history

### Backend Logs
- Check `/api/notifications/history` for sent notifications
- Monitor delivery webhooks
- Track user preferences

## 10. Troubleshooting

### Notifications not received?
1. Check OneSignal Dashboard → Audience → All Users
2. Verify device is registered
3. Check notification preferences
4. Ensure app has permission (iOS)

### Device not registering?
1. Verify OneSignal App ID is correct
2. Check auth token is valid
3. Look at console logs for errors
4. Ensure backend is reachable

### iOS specific issues?
1. Verify APNs certificate is valid
2. Check provisioning profile includes Push Notifications
3. Ensure background modes are enabled

### Android specific issues?
1. Verify Firebase Server Key is correct
2. Check if Google Play Services are installed
3. Test on physical device (not emulator)

## 📞 Support

- OneSignal Documentation: https://documentation.onesignal.com/
- OneSignal Support: https://onesignal.com/support
- Firebase Console: https://console.firebase.google.com/
- Apple Developer: https://developer.apple.com/