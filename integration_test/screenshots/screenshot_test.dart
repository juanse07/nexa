/// Integration test that captures 49 unique App Store / Play Store screenshots
/// for the FlowShift Manager app.
///
/// Run with driver (saves PNGs to screenshots/simulator/):
///   flutter drive \
///     --driver=test_driver/screenshot_driver.dart \
///     --target=integration_test/screenshots/screenshot_test.dart \
///     -d "iPhone 17 Pro Max"
///
/// Run via Fastlane (all devices):
///   cd ios && bundle exec fastlane screenshots
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:integration_test/integration_test.dart';

import 'package:nexa/screenshot_gallery_app.dart';
import 'mocks/mock_services.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  /// Take a named screenshot via the binding.
  /// On iOS, must convert Metal surface → bitmap first.
  /// The driver's onScreenshot callback saves PNGs to disk on the host.
  Future<void> takeScreenshot(String name) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    try {
      await binding.convertFlutterSurfaceToImage();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await binding.takeScreenshot(name);
      await binding.revertFlutterImage();
    } catch (e) {
      debugPrint('Screenshot "$name" note: $e');
    }
  }

  // All 49 scenarios from the gallery
  final scenarios = ScreenshotScenarios.scenarios;

  // ── English Screenshots ───────────────────────────────────────────
  group('App Store Screenshots — English', () {
    for (int i = 0; i < scenarios.length; i++) {
      final (name, build) = scenarios[i];
      final screenshotName = '${(i + 1).toString().padLeft(2, '0')}_${name}_en';

      testWidgets(screenshotName, (WidgetTester tester) async {
        await registerMockDependencies();

        await tester.pumpWidget(build(const Locale('en')));

        for (int frame = 0; frame < 10; frame++) {
          await tester.pump(const Duration(milliseconds: 100));
        }

        await takeScreenshot(screenshotName);

        await GetIt.instance.reset();
      });
    }
  });

  // ── Spanish Screenshots ───────────────────────────────────────────
  group('App Store Screenshots — Spanish', () {
    for (int i = 0; i < scenarios.length; i++) {
      final (name, build) = scenarios[i];
      final screenshotName = '${(i + 1).toString().padLeft(2, '0')}_${name}_es';

      testWidgets(screenshotName, (WidgetTester tester) async {
        await registerMockDependencies();

        await tester.pumpWidget(build(const Locale('es')));

        for (int frame = 0; frame < 10; frame++) {
          await tester.pump(const Duration(milliseconds: 100));
        }

        await takeScreenshot(screenshotName);

        await GetIt.instance.reset();
      });
    }
  });
}
