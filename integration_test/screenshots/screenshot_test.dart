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

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:integration_test/integration_test.dart';

import 'package:nexa/screenshot_gallery_app.dart';
import 'mocks/mock_services.dart';

/// Global key for the RepaintBoundary wrapping each scenario widget.
/// Used to capture screenshots from Flutter's rendering tree directly,
/// bypassing the native iOS screenshot mechanism which returns black
/// images with Impeller (Metal) rendering in Flutter 3.35+.
final _screenshotBoundaryKey = GlobalKey();

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  /// Captures a screenshot by rendering directly from Flutter's rendering
  /// tree using [RenderRepaintBoundary.toImage]. This bypasses the native
  /// iOS IntegrationTestPlugin which uses drawViewHierarchyInRect — a UIKit
  /// API that cannot capture Metal/Impeller surfaces (returns black).
  Future<void> takeScreenshot(String name) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    try {
      final boundary = _screenshotBoundaryKey.currentContext
          ?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        debugPrint('Screenshot "$name": RepaintBoundary not found, falling back to native');
        await binding.takeScreenshot(name);
        return;
      }
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        debugPrint('Screenshot "$name": toByteData returned null');
        return;
      }
      final pngBytes = byteData.buffer.asUint8List().toList();

      // Store in reportData so the driver's onScreenshot receives the bytes
      binding.reportData ??= <String, dynamic>{};
      binding.reportData!['screenshots'] ??= <dynamic>[];
      (binding.reportData!['screenshots']! as List<dynamic>).add(<String, dynamic>{
        'screenshotName': name,
        'bytes': pngBytes,
      });
      debugPrint('Screenshot "$name": captured ${pngBytes.length ~/ 1024}KB via Dart rendering');
    } catch (e) {
      debugPrint('Screenshot "$name" capture error: $e');
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

        await tester.pumpWidget(
          RepaintBoundary(
            key: _screenshotBoundaryKey,
            child: build(const Locale('en')),
          ),
        );

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

        await tester.pumpWidget(
          RepaintBoundary(
            key: _screenshotBoundaryKey,
            child: build(const Locale('es')),
          ),
        );

        for (int frame = 0; frame < 10; frame++) {
          await tester.pump(const Duration(milliseconds: 100));
        }

        await takeScreenshot(screenshotName);

        await GetIt.instance.reset();
      });
    }
  });
}
