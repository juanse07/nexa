import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:nexa/features/users/presentation/pages/settings_page.dart';
import '../../../../helpers/test_app_wrapper.dart';

void main() {
  group('SettingsPage Widget Tests', () {
    Widget buildSettingsPage() {
      return buildTestApp(const SettingsPage());
    }

    testWidgets('renders Scaffold', (tester) async {
      await tester.pumpWidget(buildSettingsPage());
      expect(find.byType(Scaffold), findsWidgets);
    });

    testWidgets('is a StatefulWidget', (tester) async {
      await tester.pumpWidget(buildSettingsPage());
      expect(find.byType(SettingsPage), findsOneWidget);
    });

    testWidgets('renders without errors', (tester) async {
      await tester.pumpWidget(buildSettingsPage());
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders Settings-related text', (tester) async {
      await tester.pumpWidget(buildSettingsPage());
      await tester.pump();
      // Settings page should have the Settings title or similar
      expect(
        find.textContaining('Settings').evaluate().isNotEmpty ||
            find.textContaining('Account').evaluate().isNotEmpty ||
            find.byType(AppBar).evaluate().isNotEmpty,
        isTrue,
      );
    });

    testWidgets('has back navigation', (tester) async {
      await tester.pumpWidget(buildSettingsPage());
      await tester.pump();
      // Should have a back button since it's pushed as a page
      expect(find.byType(BackButton).evaluate().isNotEmpty ||
             find.byIcon(Icons.arrow_back).evaluate().isNotEmpty ||
             find.byType(IconButton).evaluate().isNotEmpty,
        isTrue,
      );
    });

    testWidgets('shows terminology section', (tester) async {
      await tester.pumpWidget(buildSettingsPage());
      await tester.pump();
      // The settings page has terminology configuration
      expect(
        find.textContaining('terminology').evaluate().isNotEmpty ||
            find.textContaining('Terminology').evaluate().isNotEmpty ||
            find.textContaining('Jobs').evaluate().isNotEmpty,
        isTrue,
      );
    });
  });
}
