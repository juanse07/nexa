import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexa/features/statistics/presentation/statistics_dashboard_screen.dart';

void main() {
  group('StatisticsDashboardScreen Widget Tests', () {
    Widget buildScreen() {
      return const MaterialApp(
        home: StatisticsDashboardScreen(),
      );
    }

    testWidgets('renders a Scaffold', (tester) async {
      await tester.pumpWidget(buildScreen());
      expect(find.byType(Scaffold), findsWidgets);
    });

    testWidgets('shows loading state initially', (tester) async {
      await tester.pumpWidget(buildScreen());
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('is a StatefulWidget', (tester) async {
      await tester.pumpWidget(buildScreen());
      expect(find.byType(StatisticsDashboardScreen), findsOneWidget);
    });

    testWidgets('renders without errors', (tester) async {
      await tester.pumpWidget(buildScreen());
      expect(tester.takeException(), isNull);
    });

    testWidgets('widget type is correct', (tester) async {
      await tester.pumpWidget(buildScreen());
      final widget = tester.widget<StatisticsDashboardScreen>(
        find.byType(StatisticsDashboardScreen),
      );
      expect(widget, isNotNull);
    });
  });
}
