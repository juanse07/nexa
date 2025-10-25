#!/bin/bash

# Test script to fix notification issues
# This script will:
# 1. Clear all stale device registrations
# 2. Display instructions to re-register the device

echo "🔧 Notification Fix Script"
echo "=========================="
echo ""

# Read auth token from secure storage (you'll need to get this from your app)
read -p "Enter your auth token (from Flutter secure storage): " AUTH_TOKEN

if [ -z "$AUTH_TOKEN" ]; then
  echo "❌ Auth token required"
  exit 1
fi

echo ""
echo "Step 1: Clearing all stale device registrations..."
RESPONSE=$(curl -s -X DELETE "https://api.nexapymesoft.com/api/notifications/clear-devices" \
  -H "Authorization: Bearer $AUTH_TOKEN" \
  -H "Content-Type: application/json")

echo "Response: $RESPONSE"

echo ""
echo "✅ Stale devices cleared!"
echo ""
echo "Step 2: Next steps"
echo "=================="
echo "1. Close the Flutter app completely (swipe up to kill it)"
echo "2. Reopen the app"
echo "3. The app will automatically re-register with OneSignal"
echo "4. Look for these log messages:"
echo "   [NOTIF REG] Player ID: xxx, Subscribed: true"
echo "   [NOTIF REG] ✅ Device registered with backend"
echo ""
echo "5. Once registered, try sending a test notification"
echo ""
echo "Debugging tips:"
echo "- If 'Subscribed: false', the app will try to opt-in automatically"
echo "- Make sure you have accepted push notification permissions"
echo "- On iOS: Settings > Nexa > Notifications must be ON"
echo "- On Android: Notifications are auto-granted"
