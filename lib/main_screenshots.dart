/// Screenshot-mode entry point for FlowShift Manager.
///
/// Usage:
///   flutter test integration_test/screenshots/screenshot_test.dart \
///     -d <device_id>
///
/// This entry point:
/// - Skips Firebase, Environment.load(), NotificationService
/// - Registers mock services in GetIt
/// - Runs ScreenshotApp instead of NexaApp (no splash/auth)
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nexa/screenshot_app.dart';

// These are imported via integration test — see screenshot_test.dart.
// The test calls [setupAndRunScreenshotApp] before pumping.

/// Sets up mock dependencies and returns the ScreenshotApp widget.
///
/// Called from the integration test's `main()` before `pumpWidget`.
Future<Widget> buildScreenshotApp({
  Locale locale = const Locale('en'),
  int initialTabIndex = 0,
}) async {
  WidgetsFlutterBinding.ensureInitialized();

  // Portrait only (same as real main.dart)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Suppress errors for missing assets/network calls during screenshots
  FlutterError.onError = (FlutterErrorDetails details) {
    debugPrint('Screenshot mode error (suppressed): ${details.exception}');
  };

  return ScreenshotApp(
    locale: locale,
    initialTabIndex: initialTabIndex,
  );
}
