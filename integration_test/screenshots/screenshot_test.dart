/// Integration test that captures App Store / Play Store screenshots
/// for the FlowShift Manager app.
///
/// Run:
///   flutter test integration_test/screenshots/screenshot_test.dart -d <device>
///
/// Screenshots are saved by the binding and collected by Fastlane.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:nexa/screenshot_app.dart';
import 'mocks/mock_services.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  /// Take a named screenshot. On Android this uses
  /// `binding.takeScreenshot(name)`. On iOS the test runner captures
  /// the screen automatically, but we still pause to ensure the frame
  /// is fully rendered.
  Future<void> takeScreenshot(String name) async {
    // Allow pending frames to complete
    await Future<void>.delayed(const Duration(milliseconds: 500));
    try {
      await binding.takeScreenshot(name);
    } catch (e) {
      debugPrint('Screenshot "$name" capture note: $e');
    }
  }

  group('Manager App Store Screenshots — English', () {
    testWidgets('Capture all screens (EN)', (WidgetTester tester) async {
      // Register mock GetIt dependencies
      await registerMockDependencies();

      // Build the screenshot app
      await tester.pumpWidget(
        const ScreenshotApp(
          locale: Locale('en'),
          initialTabIndex: 0,
        ),
      );
      await tester.pumpAndSettle();

      // ── 1. Events/Jobs list (tab 0) ──
      await takeScreenshot('01_events_en');

      // ── 2. Chat/Conversations (tab 1) ──
      await tester.tap(find.text('Chat'));
      await tester.pumpAndSettle();
      await takeScreenshot('02_chat_en');

      // ── 3. Catalog (tab 2) ──
      await tester.tap(find.text('Catalog'));
      await tester.pumpAndSettle();
      await takeScreenshot('03_catalog_en');

      // ── 4. Attendance (tab 3) ──
      await tester.tap(find.text('Attendance'));
      await tester.pumpAndSettle();
      await takeScreenshot('04_attendance_en');

      // ── 5. Stats (tab 4) ──
      await tester.tap(find.text('Stats'));
      await tester.pumpAndSettle();
      await takeScreenshot('05_statistics_en');

      // ── 6. Navigate back to Events and tap first event card ──
      final eventsFinder = find.text('Events');
      if (eventsFinder.evaluate().isNotEmpty) {
        await tester.tap(eventsFinder.first);
        await tester.pumpAndSettle();
      }

      // Try tapping the first event card for detail view
      // Look for any card-like widget in the list
      final listFinder = find.byType(ListView);
      if (listFinder.evaluate().isNotEmpty) {
        // Attempt to tap the first item
        final firstCard = find.byType(Card).first;
        if (firstCard.evaluate().isNotEmpty) {
          await tester.tap(firstCard);
          await tester.pumpAndSettle();
          await takeScreenshot('06_event_detail_en');
          // Go back
          final backButton = find.byType(BackButton);
          if (backButton.evaluate().isNotEmpty) {
            await tester.tap(backButton.first);
            await tester.pumpAndSettle();
          } else {
            // Try the AppBar back arrow
            final iconBack = find.byIcon(Icons.arrow_back);
            if (iconBack.evaluate().isNotEmpty) {
              await tester.tap(iconBack.first);
              await tester.pumpAndSettle();
            }
          }
        }
      }

      // ── 7. AI Chat (navigate via FAB or menu) ──
      // Look for AI chat entry point (often a FAB or menu item)
      final aiFab = find.byIcon(Icons.smart_toy);
      final aiAltFab = find.byIcon(Icons.auto_awesome);
      if (aiFab.evaluate().isNotEmpty) {
        await tester.tap(aiFab.first);
        await tester.pumpAndSettle();
        await takeScreenshot('07_ai_chat_en');
      } else if (aiAltFab.evaluate().isNotEmpty) {
        await tester.tap(aiAltFab.first);
        await tester.pumpAndSettle();
        await takeScreenshot('07_ai_chat_en');
      }
    });
  });

  group('Manager App Store Screenshots — Spanish', () {
    testWidgets('Capture all screens (ES)', (WidgetTester tester) async {
      await registerMockDependencies();

      await tester.pumpWidget(
        const ScreenshotApp(
          locale: Locale('es'),
          initialTabIndex: 0,
        ),
      );
      await tester.pumpAndSettle();

      // ── 1. Events list ──
      await takeScreenshot('01_events_es');

      // ── 2. Chat ──
      await tester.tap(find.text('Chat'));
      await tester.pumpAndSettle();
      await takeScreenshot('02_chat_es');

      // ── 3. Catalog ──
      // In Spanish the label may still be "Catalog" or localized
      final catalogEs = find.text('Catalog');
      final catalogEsAlt = find.text('Catálogo');
      if (catalogEsAlt.evaluate().isNotEmpty) {
        await tester.tap(catalogEsAlt.first);
      } else if (catalogEs.evaluate().isNotEmpty) {
        await tester.tap(catalogEs.first);
      }
      await tester.pumpAndSettle();
      await takeScreenshot('03_catalog_es');

      // ── 4. Attendance ──
      final attendanceEs = find.text('Attendance');
      final attendanceEsAlt = find.text('Asistencia');
      if (attendanceEsAlt.evaluate().isNotEmpty) {
        await tester.tap(attendanceEsAlt.first);
      } else if (attendanceEs.evaluate().isNotEmpty) {
        await tester.tap(attendanceEs.first);
      }
      await tester.pumpAndSettle();
      await takeScreenshot('04_attendance_es');

      // ── 5. Stats ──
      final statsEs = find.text('Stats');
      final statsEsAlt = find.text('Estadísticas');
      if (statsEsAlt.evaluate().isNotEmpty) {
        await tester.tap(statsEsAlt.first);
      } else if (statsEs.evaluate().isNotEmpty) {
        await tester.tap(statsEs.first);
      }
      await tester.pumpAndSettle();
      await takeScreenshot('05_statistics_es');

      // ── 6. Event detail ──
      final eventosLabel = find.text('Eventos');
      final eventsLabel = find.text('Events');
      if (eventosLabel.evaluate().isNotEmpty) {
        await tester.tap(eventosLabel.first);
      } else if (eventsLabel.evaluate().isNotEmpty) {
        await tester.tap(eventsLabel.first);
      }
      await tester.pumpAndSettle();

      final firstCard = find.byType(Card).first;
      if (firstCard.evaluate().isNotEmpty) {
        await tester.tap(firstCard);
        await tester.pumpAndSettle();
        await takeScreenshot('06_event_detail_es');
        final backIcon = find.byIcon(Icons.arrow_back);
        if (backIcon.evaluate().isNotEmpty) {
          await tester.tap(backIcon.first);
          await tester.pumpAndSettle();
        }
      }

      // ── 7. AI Chat ──
      final aiFab = find.byIcon(Icons.smart_toy);
      final aiAltFab = find.byIcon(Icons.auto_awesome);
      if (aiFab.evaluate().isNotEmpty) {
        await tester.tap(aiFab.first);
        await tester.pumpAndSettle();
        await takeScreenshot('07_ai_chat_es');
      } else if (aiAltFab.evaluate().isNotEmpty) {
        await tester.tap(aiAltFab.first);
        await tester.pumpAndSettle();
        await takeScreenshot('07_ai_chat_es');
      }
    });
  });
}
