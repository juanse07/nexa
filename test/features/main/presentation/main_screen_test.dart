import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:nexa/features/main/presentation/main_screen.dart';
import '../../../helpers/test_app_wrapper.dart';

void main() {
  group('MainScreen Widget Tests', () {
    Widget buildMainScreen({Size screenSize = const Size(400, 800)}) {
      return buildTestApp(
        const MainScreen(),
        screenSize: screenSize,
      );
    }

    testWidgets('renders bottom navigation bar on mobile', (tester) async {
      await tester.pumpWidget(buildMainScreen());
      await tester.pumpAndSettle();

      // Should find the 5 tab labels
      expect(find.text('Jobs'), findsOneWidget);
      expect(find.text('Chat'), findsOneWidget);
      expect(find.text('Catalog'), findsOneWidget);
      expect(find.text('Attendance'), findsOneWidget);
      expect(find.text('Stats'), findsOneWidget);
    });

    testWidgets('Jobs tab label uses TerminologyProvider', (tester) async {
      final provider = TestTerminologyProvider('Shifts');
      await tester.pumpWidget(buildTestApp(
        const MainScreen(),
        terminologyProvider: provider,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Shifts'), findsOneWidget);
      expect(find.text('Jobs'), findsNothing);
    });

    testWidgets('renders with initialIndex 0 by default', (tester) async {
      await tester.pumpWidget(buildMainScreen());
      await tester.pumpAndSettle();

      // First tab should be selected (Jobs)
      expect(find.text('Jobs'), findsOneWidget);
    });

    testWidgets('renders 5 Icon widgets in bottom bar', (tester) async {
      await tester.pumpWidget(buildMainScreen());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.view_module), findsOneWidget);
      expect(find.byIcon(Icons.chat_bubble_outline), findsOneWidget);
      expect(find.byIcon(Icons.inventory_2), findsOneWidget);
      expect(find.byIcon(Icons.fact_check_outlined), findsOneWidget);
      expect(find.byIcon(Icons.bar_chart), findsOneWidget);
    });

    testWidgets('renders PageView for mobile layout', (tester) async {
      await tester.pumpWidget(buildMainScreen());
      await tester.pumpAndSettle();

      expect(find.byType(PageView), findsOneWidget);
    });

    testWidgets('desktop layout shows navigation rail (width >= 1200)',
        (tester) async {
      // Set a large screen size
      await tester.pumpWidget(buildMainScreen(
        screenSize: const Size(1400, 900),
      ));
      await tester.pumpAndSettle();

      // On desktop, should use IndexedStack instead of PageView
      expect(find.byType(IndexedStack), findsOneWidget);
      // Should show "Flowshift" brand text in nav rail
      expect(find.text('Flowshift'), findsOneWidget);
    });

    testWidgets('desktop layout does not show PageView', (tester) async {
      await tester.pumpWidget(buildMainScreen(
        screenSize: const Size(1400, 900),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(PageView), findsNothing);
    });
  });
}
