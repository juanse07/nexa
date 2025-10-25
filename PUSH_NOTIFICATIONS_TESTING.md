# Push Notifications Testing Guide

## Overview
The push notification system has been fully configured for both Manager and Staff apps using OneSignal. This guide will help you test and verify the implementation.

## Configuration Status ✅

### OneSignal Setup (Two Separate App IDs)
- **Manager App ID**: `8a08b6ac-0275-4adf-9432-53712b1e0fc6` (ONESIGNAL_APP_ID)
- **Staff App ID**: `b974a231-c50a-4c4b-9cb0-59c6e0786434` (ONESIGNAL_APP_ID2)
- **iOS (APNs)**: Configured with .p8 key for both apps
- **Android (FCM)**: Configured with google-services.json for both apps

### Backend Integration
- **Notification Service**: `/backend/src/services/notificationService.ts`
- **API Endpoints**: Register device, update preferences, send test, notification history
- **Auto-notifications**: Chat messages automatically trigger push notifications

### App Integration
- **Manager App**: Notifications initialize after login in `ManagerOnboardingGate`
- **Staff App**: Notifications initialize after login in `StaffOnboardingGate`

## Testing Instructions

### 1. Initial Setup Test

#### Manager App:
1. Run the Manager app: `flutter run` (from `/Volumes/Data/Users/juansuarez/nexa`)
2. Sign in with Google or Apple
3. After login, check console for "✅ NotificationService initialized successfully"
4. iOS will prompt for notification permissions - tap "Allow"

#### Staff App:
1. Run the Staff app: `flutter run` (from `/Volumes/macOs_Files/nexaProjectStaffside/frontend`)
2. Sign in with Google or Apple
3. After login, check console for "[ONBOARDING GATE] Notifications initialized"
4. iOS will prompt for notification permissions - tap "Allow"

### 2. Test Notification Button

#### Manager App:
1. Navigate to Profile tab → Settings
2. Find "Test Notifications" card
3. Tap "Send Test Notification"
4. You should receive a push notification with:
   - Title: "🔔 Test Notification"
   - Body: "This is a test notification from Nexa Staff!"

#### Staff App:
1. Navigate to Profile tab
2. Scroll down to "Push Notifications" card
3. Tap "Send Test Notification"
4. You should receive the same test notification

### 3. Chat Message Notifications

**Test automatic notifications when sending messages:**

1. **Setup**: Have Manager app on one device/emulator and Staff app on another
2. **Send from Manager**:
   - Open chat with a staff member
   - Send a message
   - Staff should receive push notification (if app is backgrounded)
3. **Send from Staff**:
   - Open chat with a manager
   - Send a message
   - Manager should receive push notification (if app is backgrounded)

### 4. OneSignal Dashboard Verification

1. Log into OneSignal Dashboard: https://dashboard.onesignal.com
2. You have TWO separate apps to monitor:

   **Manager App:**
   - Select the app with ID ending in `...d0bb711e`
   - Check "Audience" → "All Users" for manager devices

   **Staff App:**
   - Select the app with ID ending in `...0786434`
   - Check "Audience" → "All Users" for staff devices

3. For each app, you should see:
   - Device count incrementing as users log in
   - Device types (iOS/Android)
   - Last active times
   - Separate analytics for each user type

### 5. Testing Different Notification Types

From the backend, you can trigger different notification types:

```javascript
// Example: Send a task notification
await notificationService.sendToUser(
  userId,
  'New Task Assigned',
  'You have been assigned to: Setup event equipment',
  {
    type: 'task',
    taskId: 'task123',
    eventId: 'event456'
  },
  'user' // or 'manager'
);
```

### 6. Troubleshooting

#### No notifications received:
1. Check device has internet connection
2. Verify app has notification permissions (Settings → Apps → Nexa)
3. Check OneSignal dashboard for device registration
4. Look for errors in console logs

#### iOS specific:
- Ensure you're testing on real device (simulators don't support push)
- Check APNs certificate is not expired in OneSignal settings

#### Android specific:
- Verify google-services.json is in `/android/app/`
- Check Firebase project is active
- Ensure app is not being killed by battery optimization

### 7. Testing Notification Preferences

**Manager App Settings:**
1. Go to Settings
2. Toggle different notification types on/off
3. Verify preferences are saved to backend
4. Test that disabled types don't send notifications

### 8. Production Testing Checklist

- [ ] Test notification on iOS real device
- [ ] Test notification on Android real device
- [ ] Verify chat messages trigger notifications
- [ ] Check notification appears when app is:
  - [ ] In foreground (local notification)
  - [ ] In background
  - [ ] Completely closed
- [ ] Test notification click navigation (when implemented)
- [ ] Verify device unregisters on logout

## API Testing with cURL

Test the notification system directly:

```bash
# Get auth token first (replace with actual token)
TOKEN="your-jwt-token"

# Send test notification
curl -X POST https://nexa-backend.up.railway.app/api/notifications/test \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json"

# Check notification history
curl -X GET https://nexa-backend.up.railway.app/api/notifications/history \
  -H "Authorization: Bearer $TOKEN"

# Update preferences
curl -X PATCH https://nexa-backend.up.railway.app/api/notifications/preferences \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"chat": true, "tasks": false}'
```

## Monitoring

- **OneSignal Dashboard**: Monitor delivery rates and device statistics
- **Backend Logs**: Check production server logs for notification sending
- **App Console**: Monitor for initialization and registration success

## Next Steps

1. **Implement Deep Linking**: Handle notification clicks to navigate to specific screens
2. **Add Badge Counts**: Show unread notification count on app icon
3. **Rich Notifications**: Add images and action buttons to notifications
4. **Schedule Notifications**: Implement scheduled reminders for events
5. **Analytics**: Track notification open rates and user engagement

## Support

If you encounter issues:
1. Check OneSignal documentation: https://documentation.onesignal.com
2. Review backend logs: `ssh app@198.58.111.243 "cd /srv/app && docker compose logs api"`
3. Verify OneSignal configuration in dashboard
4. Test with OneSignal's debug tools