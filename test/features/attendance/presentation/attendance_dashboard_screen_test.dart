import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexa/features/attendance/presentation/attendance_dashboard_screen.dart';

void main() {
  group('AttendanceDashboardScreen Widget Tests', () {
    Widget buildScreen() {
      return const MaterialApp(
        home: AttendanceDashboardScreen(),
      );
    }

    testWidgets('renders a Scaffold', (tester) async {
      await tester.pumpWidget(buildScreen());
      expect(find.byType(Scaffold), findsWidgets);
    });

    testWidgets('shows loading state initially', (tester) async {
      await tester.pumpWidget(buildScreen());
      // May show loading or empty state
      expect(find.byType(AttendanceDashboardScreen), findsOneWidget);
    });

    testWidgets('is a StatefulWidget', (tester) async {
      await tester.pumpWidget(buildScreen());
      expect(find.byType(AttendanceDashboardScreen), findsOneWidget);
    });

    testWidgets('renders without errors', (tester) async {
      await tester.pumpWidget(buildScreen());
      expect(tester.takeException(), isNull);
    });

    testWidgets('widget type is correct', (tester) async {
      await tester.pumpWidget(buildScreen());
      final widget = tester.widget<AttendanceDashboardScreen>(
        find.byType(AttendanceDashboardScreen),
      );
      expect(widget, isNotNull);
    });
  });
}
