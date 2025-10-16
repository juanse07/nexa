# Nexa Store Submission Checklist

Use this guide to prepare and submit Nexa to the Apple App Store and Google Play Store. Mark items complete as you progress.

---

## 1. Accounts & Access
- [ ] Apple Developer Program membership is active and 2FA devices are available.
- [ ] Google Play Console organization is active with billing info and release manager access.
- [ ] Company support email and marketing website are ready (`support@nexapymesoft.com`, https://nexapymesoft.com).

---

## 2. Environment & Configuration
- [ ] `.env.local` contains production values (API base URL, OpenAI key, Google/Apple IDs, Maps keys). Remove placeholder lines (e.g., “what else”).
- [ ] Run `./tool/run_mobile_dev.sh -d <device>` to sanity-check builds with current defines.
- [ ] For Android, ensure `android/key.properties` exists with release keystore credentials (see `android/RELEASE_SIGNING_SETUP.md`).

---

## 3. iOS Preparation
- [ ] Bundle ID in App Store Connect matches `com.pymesoft.nexa`.
- [ ] Update `ios/Runner/Runner.entitlements` → set `aps-environment` to `production` or remove if push isn’t shipping.
- [ ] Adjust `UISupportedInterfaceOrientations` in `ios/Runner/Info.plist` to match the app (portrait-only unless landscape is supported).
- [ ] Verify Info.plist usage descriptions (camera, photos, location) match review expectations.
- [ ] Run `flutter clean` then `./build_ios_release.sh` to produce `build/ios/ipa/*.ipa`.
- [ ] Validate the IPA in Xcode Organizer or Transporter and archive export logs.

---

## 4. Android Preparation
- [ ] `android/app/build.gradle.kts` uses your namespace/package (`com.pymesoft.nexa`) and versionName/versionCode from `pubspec.yaml`.
- [ ] Generate/confirm release keystore and update `android/key.properties`.
- [ ] Build both artifacts:
  - `./build_android_release.sh` (APK)
  - `flutter build appbundle --release` (AAB for Play submission)
- [ ] Confirm `android/app/proguard-rules.pro` contains required keep rules and that the release build runs on a device.

---

## 5. Store Assets & Metadata
- [ ] Publish `PRIVACY_POLICY.md` to a public URL; confirm Terms of Service URL is live.
- [ ] Fill out `STORE_LISTING_GUIDE.md` templates: titles, short/full descriptions, keywords, categories, support URL.
- [ ] Capture screenshots:
  - iOS: 6.7", 6.5", 5.5", (optional) iPad 12.9".
  - Android: phone (min 3), optional 7"/10" tablet shots.
- [ ] Create Android feature graphic (1024×500) and optional promo video.
- [ ] Export final app icons from `assets/logo*.png` if changes were made.

---

## 6. Compliance Forms
- [ ] App Store Connect “App Privacy” questionnaire completed (reference privacy policy).
- [ ] Google Play Console “Data safety” and “Content rating” forms submitted.
- [ ] Confirm no in-app purchases; set pricing tier/free accordingly.

---

## 7. QA & Testing
- [ ] Run `flutter test` and sanity `flutter run` on a physical device.
- [ ] Use TestFlight (External or Internal) to verify login, event creation, AI extraction, and hours approval with production backend.
- [ ] Create internal testing track on Google Play; run the same smoke tests.
- [ ] Prepare reviewer/demo credentials (limited access admin + staff account) and note them for submission forms.

---

## 8. Submission
- [ ] Upload iOS IPA via Xcode/Transporter, attach build to the App Store Connect listing, and enter release notes.
- [ ] Upload Android AAB in Google Play Console → Production (or Closed testing first); provide release notes.
- [ ] Include review notes highlighting:
  - AI extraction processes user-supplied documents via OpenAI.
  - Google/Apple Sign-In use.
  - Any features requiring camera/photos/location.
- [ ] Monitor review dashboards for questions; respond promptly.

---

## 9. Post-Approval
- [ ] Tag release in git (`git tag v1.0.0`) and push.
- [ ] Update internal documentation with approved build numbers.
- [ ] Schedule marketing announcements and notify stakeholders.

Keep this checklist in sync with future releases—update version numbers, feature highlights, and store assets when you ship major changes.
