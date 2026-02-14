/// Golden test that renders all 49 screenshot scenarios and saves them
/// as PNG files to screenshots/goldens/.
///
/// Run:
///   flutter test --update-goldens test/screenshots_golden/screenshot_golden_test.dart
///
/// PNGs will appear in: screenshots/goldens/
@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

import 'package:nexa/screenshot_gallery_app.dart';

// Import mock services from integration test directory
import '../../integration_test/screenshots/mocks/mock_services.dart';

/// Mock platform channels that aren't available in headless widget tests.
void _mockPlatformChannels() {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  // FlutterSecureStorage
  const secureChannel =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  messenger.setMockMethodCallHandler(secureChannel, (MethodCall call) async {
    if (call.method == 'read') {
      final key = call.arguments['key'] as String?;
      if (key == 'access_token') return 'mock-jwt-token-for-screenshots';
      return null;
    }
    if (call.method == 'readAll') return <String, String>{};
    if (call.method == 'containsKey') return false;
    return null;
  });

  // AudioRecorder (record package)
  const recordChannel = MethodChannel('com.llfbandit.record/messages');
  messenger.setMockMethodCallHandler(recordChannel, (MethodCall call) async {
    if (call.method == 'create') return '0';
    if (call.method == 'hasPermission') return true;
    if (call.method == 'isRecording' || call.method == 'isPaused') {
      return false;
    }
    return null;
  });

  // Geolocator
  const geoChannel = MethodChannel('flutter.baseflow.com/geolocator');
  messenger.setMockMethodCallHandler(geoChannel, (MethodCall call) async {
    if (call.method == 'isLocationServiceEnabled') return false;
    if (call.method == 'checkPermission') return 0;
    return null;
  });
}

void main() {
  final scenarios = ScreenshotScenarios.scenarios;

  // iPhone 15 Pro Max logical size (430 x 932 points)
  const deviceSize = Size(430, 932);

  for (int i = 0; i < scenarios.length; i++) {
    final (name, build) = scenarios[i];
    final index = (i + 1).toString().padLeft(2, '0');
    final goldenPath = '../../screenshots/goldens/${index}_$name.png';

    testWidgets('Screenshot $index: $name', (WidgetTester tester) async {
      // Set the render surface to phone size
      tester.view.physicalSize = deviceSize * 3.0; // 3x for retina
      tester.view.devicePixelRatio = 3.0;

      // Mock platform channels for headless test
      _mockPlatformChannels();

      // Register mock DI
      await registerMockDependencies();

      // Suppress non-critical errors in screenshot mode
      final origOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        final msg = details.toString();
        if (msg.contains('overflowed') ||
            msg.contains('RenderFlex') ||
            msg.contains('MissingPluginException') ||
            msg.contains('Could not find the correct Provider') ||
            msg.contains('No implementation found')) {
          return;
        }
        origOnError?.call(details);
      };

      // Build the widget
      await tester.pumpWidget(build(const Locale('en')));
      while (tester.takeException() != null) {}

      // Pump frames to let data load and widgets render
      for (int frame = 0; frame < 15; frame++) {
        await tester.pump(const Duration(milliseconds: 100));
        while (tester.takeException() != null) {}
      }

      // Save as golden file (PNG)
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(goldenPath),
      );

      // Drain any remaining exceptions
      while (tester.takeException() != null) {}

      // Restore error handler
      FlutterError.onError = origOnError;

      // Clean up
      await GetIt.instance.reset();
    });
  }
}
