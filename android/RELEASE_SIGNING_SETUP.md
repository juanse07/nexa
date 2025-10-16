# Android Release Signing Setup

## Step 1: Generate a Keystore

Run this command in your terminal:

```bash
keytool -genkey -v -keystore ~/nexa-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias nexa-release
```

You'll be prompted for:
- **Keystore password**: (choose a strong password)
- **Key password**: (can be the same as keystore password)
- **Your name**: Juan Suarez (or your name)
- **Organizational unit**: Pymesoft
- **Organization**: Pymesoft
- **City**: (your city)
- **State**: (your state)
- **Country code**: US

**IMPORTANT**:
- Save the passwords securely (you'll need them for every release)
- Backup the keystore file to a secure location
- If you lose the keystore, you cannot update your app on Play Store!

## Step 2: Create key.properties File

Create a file at `android/key.properties` with:

```properties
storePassword=YOUR_KEYSTORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=nexa-release
storeFile=/Users/juansuarez/nexa-keystore.jks
```

Replace the passwords with your actual passwords from Step 1.

**SECURITY**: Add `android/key.properties` to `.gitignore` (already done)

## Step 3: Update build.gradle.kts

The signing configuration is already set up in `android/app/build.gradle.kts`.

## Step 4: Build Release APK/AAB

```bash
# Build App Bundle (recommended for Play Store)
flutter build appbundle --release

# Or build APK
flutter build apk --release
```

The files will be at:
- **AAB**: `build/app/outputs/bundle/release/app-release.aab`
- **APK**: `build/app/outputs/flutter-apk/app-release.apk`

## Next Steps

1. Create keystore (Step 1)
2. Create key.properties (Step 2)
3. Test release build
4. Upload to Google Play Console
