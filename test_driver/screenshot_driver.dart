/// Test driver that runs on the HOST Mac and extracts screenshots
/// from the integration test running on the simulator.
///
/// Run:
///   flutter drive \
///     --driver=test_driver/screenshot_driver.dart \
///     --target=integration_test/screenshots/screenshot_test.dart \
///     -d "iPhone 17 Pro Max"
///
/// Screenshots will be saved to: screenshots/simulator/
import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  final outputDir = Directory('screenshots/simulator');

  await integrationDriver(
    onScreenshot: (
      String screenshotName,
      List<int> screenshotBytes, [
      Map<String, Object?>? args,
    ]) async {
      if (!outputDir.existsSync()) {
        outputDir.createSync(recursive: true);
      }
      final file = File('${outputDir.path}/$screenshotName.png');
      file.writeAsBytesSync(screenshotBytes);
      print('Saved: ${file.path} (${screenshotBytes.length ~/ 1024}KB)');
      return true;
    },
  );
}
