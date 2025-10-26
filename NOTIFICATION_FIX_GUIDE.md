# Push Notification Fix Guide

## Problem Identified

Your notifications were failing with the error:
```
{"id":"","errors":["All included players are not subscribed"]}
```

**Root Cause**: Device Player IDs were being registered in the backend database but were NOT actually subscribed in OneSignal's system. This happens when:
1. The OneSignal SDK initializes but doesn't complete the subscription process
2. The device doesn't opt-in to push notifications
3. Stale Player IDs from previous app installations

## What Was Fixed

### Backend Changes (✅ Deployed)
1. Added `clearAllDevices()` method to remove stale device registrations
2. Added `DELETE /api/notifications/clear-devices` endpoint for troubleshooting
3. Backend now properly handles the "not subscribed" error case

### Frontend Changes (⚠️ Not Yet Deployed)
The staff app needs these updates:
1. Added retry logic for OneSignal initialization
2. Added explicit subscription check (`pushSubscription.optedIn`)
3. Auto opt-in if device is not subscribed
4. Detailed logging with `[NOTIF REG]` prefix
5. Fixed API base URL to `https://api.nexapymesoft.com`

## How to Fix Your Current Issue

### Step 1: Clear Stale Devices

You have 5 stale device registrations in the database. Clear them with:

```bash
# Option A: Using the test script
./test-notification-fix.sh

# Option B: Using curl directly
curl -X DELETE "https://api.nexapymesoft.com/api/notifications/clear-devices" \
  -H "Authorization: Bearer YOUR_AUTH_TOKEN" \
  -H "Content-Type: application/json"
```

To get your auth token, check Flutter secure storage or the app logs.

### Step 2: Deploy Updated Staff App

The Flutter changes need to be deployed to your device:

```bash
# Navigate to staff app directory
cd /Volumes/macOs_Files/nexaProjectStaffside/frontend

# Build and run on your device
flutter run --release
# OR
flutter build apk --release
```

### Step 3: Test the Registration

1. **Close the app completely** (swipe up to kill it)
2. **Reopen the app**
3. **Watch the logs** for these messages:

```
[NOTIF REG] Player ID: xxx-xxx-xxx, Subscribed: true
[NOTIF REG] Setting OneSignal external user ID: xxx
[NOTIF REG] ✅ Device registered with backend: xxx
```

**If you see `Subscribed: false`**, the app will automatically try to opt-in:
```
[NOTIF REG] ⚠️ Device is not opted-in to push notifications!
[NOTIF REG] Attempting to opt-in...
[NOTIF REG] Opt-in completed, new status: true
```

### Step 4: Verify Permissions

#### iOS:
1. Go to **Settings > Nexa**
2. Tap **Notifications**
3. Ensure **Allow Notifications** is ON
4. Enable **Lock Screen**, **Notification Center**, **Banners**

#### Android:
- Notifications are auto-granted at install time
- Check **Settings > Apps > Nexa > Notifications** if needed

### Step 5: Send Test Notification

Once registered, send a test notification:

```bash
curl -X POST "https://api.nexapymesoft.com/api/notifications/test" \
  -H "Authorization: Bearer YOUR_AUTH_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "🎉 Test Notification",
    "body": "If you see this, notifications are working!",
    "type": "system"
  }'
```

Expected response:
```json
{
  "message": "Test notification sent successfully",
  "notification": {
    "id": "...",
    "title": "🎉 Test Notification",
    "body": "If you see this, notifications are working!",
    "type": "system"
  }
}
```

## Troubleshooting

### Issue: "No OneSignal Player ID available yet"

**Solution**: The SDK hasn't initialized. Wait 2-3 seconds after app launch, or restart the app.

### Issue: Device shows as registered but still no notifications

**Check these in order:**
1. **Subscription status**: Look for `Subscribed: true` in logs
2. **Permission granted**: Check device settings
3. **Correct OneSignal App ID**: Should be `b974a231-c50a-4c4b-9cb0-59c6e0786434` for staff app
4. **Player ID validity**: Try clearing devices and re-registering

### Issue: "All included players are not subscribed" (old error)

This should be fixed after following the steps above. If it persists:
1. Clear devices again
2. Uninstall and reinstall the app
3. Check OneSignal dashboard to verify Player ID exists

### Issue: Notification appears in backend logs but not on device

**Possible causes:**
- **App is in foreground**: iOS suppresses notifications by default. The updated app now shows local notifications when in foreground.
- **Do Not Disturb enabled**: Check device settings
- **Battery saver mode**: Some Android devices suppress notifications

## How Notifications Work Now

```
┌─────────────┐
│ Flutter App │
│  (Staff)    │
└──────┬──────┘
       │
       │ 1. Initialize OneSignal SDK
       │    OneSignal.initialize(appId)
       ↓
┌──────────────┐
│  OneSignal   │ 2. SDK creates Player ID
│   Servers    │    and subscribes device
└──────┬───────┘
       │
       │ 3. App gets Player ID
       │    OneSignal.User.getOnesignalId()
       ↓
┌──────────────┐
│   Backend    │ 4. App registers with backend
│     API      │    POST /api/notifications/register-device
└──────┬───────┘
       │
       │ 5. Backend stores mapping:
       │    User ID → Player ID
       │
       │ 6. When sending notification:
       │    Backend → OneSignal REST API
       │    with Player IDs
       ↓
┌──────────────┐
│  OneSignal   │ 7. OneSignal validates Player IDs
│   Servers    │    are subscribed
└──────┬───────┘
       │
       │ 8. Push notification delivered
       ↓
┌─────────────┐
│   Device    │ Notification appears!
└─────────────┘
```

## Key Changes Made

### notificationService.ts (Backend)
```typescript
// NEW: Clear stale devices
async clearAllDevices(userId: string, userType: 'user' | 'manager') {
  // Removes all device registrations for a user
}
```

### notification_service.dart (Frontend)
```dart
// NEW: Check subscription status
final pushSubscription = OneSignal.User.pushSubscription;
final isSubscribed = pushSubscription.optedIn;

// NEW: Auto opt-in if not subscribed
if (!isSubscribed) {
  await pushSubscription.optIn();
}
```

## Next Steps

After testing, you should:
1. Monitor the logs for a few days
2. Test notifications in different scenarios:
   - App in foreground
   - App in background
   - App closed
3. Test on both iOS and Android
4. Remove debug logging once stable

## Support

If issues persist:
1. Check OneSignal dashboard (https://onesignal.com/apps)
2. Verify Player IDs exist and are subscribed
3. Check backend logs: `ssh app@198.58.111.243 "cd /srv/app && docker compose logs api | tail -100"`
4. Share the `[NOTIF REG]` and `[NOTIF DEBUG]` logs for diagnosis
