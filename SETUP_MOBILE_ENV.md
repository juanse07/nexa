# Mobile Environment Setup Guide

## Problem

Your iOS/Android app is showing this error:
```
Failed host lookup: 'api.example.com'
```

This happens because the mobile app is loading placeholder values from `.env.defaults` instead of your real API URL.

## Solution

### Step 1: Fill in `.env.local` with Your Real Credentials

I've created `.env.local` with your backend URL already set. Now you need to fill in your actual Google/Apple credentials:

1. Open `.env.local` in the project root
2. Replace these placeholder values with your actual credentials:

```bash
# Google OAuth Client IDs
GOOGLE_SERVER_CLIENT_ID=your-actual-google-server-client-id
GOOGLE_CLIENT_ID_ANDROID=your-actual-google-android-client-id
GOOGLE_CLIENT_ID_IOS=your-actual-google-ios-client-id
GOOGLE_CLIENT_ID_WEB=your-actual-google-web-client-id

# Google Maps API Keys
GOOGLE_MAPS_API_KEY=your-actual-google-maps-api-key
GOOGLE_MAPS_IOS_SDK_KEY=your-actual-ios-maps-sdk-key

# OpenAI (if using OCR features)
OPENAI_API_KEY=your-actual-openai-api-key
```

### Step 2: Where to Find These Credentials

#### Google OAuth Client IDs
1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Select your project
3. Navigate to **APIs & Services** → **Credentials**
4. Look for your OAuth 2.0 Client IDs:
   - **iOS client ID** - For iOS app
   - **Android client ID** - For Android app
   - **Web client ID** - For web app
   - **Server client ID** - For backend verification

#### Google Maps API Keys
1. Same Google Cloud Console → **APIs & Services** → **Credentials**
2. Look for **API Keys**:
   - One for general use (GOOGLE_MAPS_API_KEY)
   - One restricted to iOS (GOOGLE_MAPS_IOS_SDK_KEY)

#### OpenAI API Key (Optional)
1. Go to [OpenAI Platform](https://platform.openai.com)
2. Navigate to **API Keys**
3. Create or copy your API key
4. Only needed if you're using OCR features

### Step 3: Restart Your Flutter App

After updating `.env.local`, launch the mobile app through the helper script so the values
are passed in as `--dart-define`s:

```bash
# iOS simulator example (replace -d with your device id if needed)
./tool/run_mobile_dev.sh -d <device-id>
```

The script reads `.env.local`, forwards every key as a `--dart-define`, and the app reloads
with your real backend URL and credentials.

## How This Works

### For Mobile (iOS/Android):
1. App starts up
2. Loads `.env.local` first (if exists) ✅
3. Falls back to `.env` (if `.env.local` missing)
4. Falls back to `.env.defaults` (if both missing)

### For Web (Cloudflare Pages):
- Doesn't use `.env` files
- Uses `--dart-define` flags from `build.sh` ✅ Already configured!

## Current Configuration Status

✅ **Backend URL**: `https://api.nexapymesoft.com` (already set in `.env.local`)
✅ **Apple Bundle ID**: `com.pymesoft.nexa` (already set)
✅ **Apple Service ID**: `com.pymesoft.nexa.web` (already set)
✅ **Apple Redirect URI**: `https://app.nexapymesoft.com/auth/callback` (already set)

❌ **Google Client IDs**: Need your actual values
❌ **Google Maps Keys**: Need your actual values
❌ **OpenAI Key** (optional): Need your actual value if using OCR

## Security Notes

- ✅ `.env.local` is git-ignored (safe to put secrets)
- ✅ `.env` is git-ignored (safe to put secrets)
- ⚠️ `.env.defaults` is committed to git (only placeholders!)
- ✅ Never commit real API keys to git

## Verification

After setup, verify it's working:

1. **Check logs**: Run `flutter run` and watch the startup logs
2. **Look for**: Should see your real API URL in connection attempts
3. **No more "api.example.com" errors**: The placeholder URL should be gone

## Troubleshooting

### Still seeing "api.example.com"?

1. Make sure `.env.local` exists in project root (same level as `pubspec.yaml`)
2. Stop and restart the app completely (hot reload won't reload env vars)
3. Check file encoding - should be UTF-8

### Different error now?

- If you see "Failed to connect" or "Connection refused":
  - Your backend might be down
  - Check firewall/network settings

- If you see "401 Unauthorized":
  - Google/Apple credentials might be wrong
  - Check that Client IDs match your Google Cloud Console

### For iOS Simulator:

iOS Simulator uses localhost differently:
- `localhost` and `127.0.0.1` should work fine
- If backend is on your Mac, no special configuration needed
- If backend is remote, use the full URL (https://api.nexapymesoft.com) ✅ Already set!

## Next Steps

1. ✅ Backend URL is already configured
2. ❌ Fill in Google OAuth Client IDs in `.env.local`
3. ❌ Fill in Google Maps API Keys in `.env.local`
4. ❌ (Optional) Fill in OpenAI API Key if using OCR
5. ✅ Restart the app
6. ✅ Test login and features

Once you fill in the credentials, your iOS/Android app will connect to the correct backend and authentication will work!
