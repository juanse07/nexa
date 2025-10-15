# Building Release Versions

## The Problem

**.env files are NOT included in release builds!**

When you build a release APK, AAB, or IPA:
- ❌ `.env`, `.env.local`, `.env.defaults` are **NOT bundled** with the app
- ❌ Environment variables are **NOT available** at runtime
- ❌ The app will use hardcoded fallback values or crash

**This is why your release app shows timeout errors while debug mode works fine.**

## The Solution

Use the provided build scripts that **bake environment variables into the compiled app** using `--dart-define` flags.

### For Android Release:

```bash
./build_android_release.sh
```

This creates: `build/app/outputs/flutter-apk/app-release.apk`

### For iOS Release:

```bash
./build_ios_release.sh
```

This creates: `build/ios/ipa/*.ipa`

### For Web (Cloudflare Pages):

The `build.sh` script already handles this correctly ✅

## How It Works

The build scripts:
1. Load environment variables from `.env.local`
2. Pass them to Flutter via `--dart-define` flags
3. Flutter compiles these values **directly into the app binary**
4. At runtime, `Environment.get()` reads these compile-time constants

## Development vs Release

### Development (Debug Mode)
```bash
flutter run
```
- ✅ Loads `.env.local` at runtime
- ✅ Can be changed without rebuilding
- ✅ Works in simulator/emulator

### Release (Production)
```bash
./build_android_release.sh
# or
./build_ios_release.sh
```
- ✅ Environment variables **baked into the binary**
- ❌ Cannot be changed after build
- ✅ Works on physical devices and app stores

## Important Notes

1. **Never commit `.env.local`** - it contains secrets (already in `.gitignore`)
2. **Always use build scripts for releases** - don't run `flutter build` directly
3. **`.env.defaults` has placeholders only** - never put real credentials there
4. **Web builds use Cloudflare environment variables** - set in Cloudflare Pages dashboard

## Troubleshooting

### "TimeoutException" or "Failed to connect" errors in release builds

**Cause:** App was built without `--dart-define` flags, using placeholder URLs

**Fix:** Rebuild using the provided scripts:
```bash
./build_android_release.sh
# or
./build_ios_release.sh
```

### "API returns 404" errors

**Cause:** `API_BASE_URL` or `API_PATH_PREFIX` not set correctly

**Fix:** Check your `.env.local` has:
```
API_BASE_URL=https://api.nexapymesoft.com
API_PATH_PREFIX=/api
```

Then rebuild.

### Google Sign-In fails in release

**Cause:** Google Client IDs not passed to build

**Fix:** Make sure `.env.local` has your actual Google Client IDs, then rebuild.

## Summary

| Build Type | Command | Env Source | Use Case |
|------------|---------|------------|----------|
| Debug | `flutter run` | `.env.local` (runtime) | Local development |
| Android Release | `./build_android_release.sh` | `.env.local` (compile-time) | Play Store / APK |
| iOS Release | `./build_ios_release.sh` | `.env.local` (compile-time) | App Store / TestFlight |
| Web Release | `build.sh` | Cloudflare env vars (compile-time) | Cloudflare Pages |

**Always use the build scripts for production releases!**
