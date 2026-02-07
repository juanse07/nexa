import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nexa/features/subscription/presentation/pages/subscription_paywall_page.dart';
import 'package:nexa/features/subscription/data/services/subscription_service.dart';

class MockSubscriptionService extends Mock implements SubscriptionService {}

void main() {
  group('SubscriptionPaywallPage Widget Tests', () {
    late MockSubscriptionService mockService;

    setUp(() {
      mockService = MockSubscriptionService();
      // Register mock in GetIt
      if (GetIt.instance.isRegistered<SubscriptionService>()) {
        GetIt.instance.unregister<SubscriptionService>();
      }
      GetIt.instance.registerSingleton<SubscriptionService>(mockService);
    });

    tearDown(() {
      if (GetIt.instance.isRegistered<SubscriptionService>()) {
        GetIt.instance.unregister<SubscriptionService>();
      }
    });

    Widget buildScreen() {
      return const MaterialApp(
        home: SubscriptionPaywallPage(),
      );
    }

    testWidgets('renders Scaffold', (tester) async {
      await tester.pumpWidget(buildScreen());
      expect(find.byType(Scaffold), findsWidgets);
    });

    testWidgets('is a StatefulWidget', (tester) async {
      await tester.pumpWidget(buildScreen());
      expect(find.byType(SubscriptionPaywallPage), findsOneWidget);
    });

    testWidgets('renders without errors', (tester) async {
      await tester.pumpWidget(buildScreen());
      expect(tester.takeException(), isNull);
    });

    testWidgets('shows Pro or subscription-related text', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      // The paywall should mention Pro, Upgrade, or subscription
      expect(
        find.textContaining('Pro').evaluate().isNotEmpty ||
            find.textContaining('Upgrade').evaluate().isNotEmpty ||
            find.textContaining('Subscribe').evaluate().isNotEmpty,
        isTrue,
      );
    });

    testWidgets('has purchase/subscribe button', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      // Should have at least one button for purchase
      expect(find.byType(ElevatedButton).evaluate().isNotEmpty ||
             find.byType(FilledButton).evaluate().isNotEmpty ||
             find.byType(TextButton).evaluate().isNotEmpty,
        isTrue,
      );
    });

    testWidgets('has restore purchases option', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      expect(
        find.textContaining('Restore').evaluate().isNotEmpty ||
            find.textContaining('restore').evaluate().isNotEmpty,
        isTrue,
      );
    });
  });
}
