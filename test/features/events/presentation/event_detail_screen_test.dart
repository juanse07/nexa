import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nexa/features/events/presentation/event_detail_screen.dart';
import 'package:nexa/l10n/app_localizations.dart';
import 'package:nexa/core/network/api_client.dart';
import 'package:nexa/features/subscription/data/services/subscription_service.dart';

class MockApiClient extends Mock implements ApiClient {}
class MockSubscriptionService extends Mock implements SubscriptionService {}

void main() {
  group('EventDetailScreen Widget Tests', () {
    late MockApiClient mockApiClient;
    late MockSubscriptionService mockSubscriptionService;

    setUp(() {
      mockApiClient = MockApiClient();
      mockSubscriptionService = MockSubscriptionService();

      final getIt = GetIt.instance;
      if (getIt.isRegistered<ApiClient>()) getIt.unregister<ApiClient>();
      if (getIt.isRegistered<SubscriptionService>()) getIt.unregister<SubscriptionService>();
      getIt.registerSingleton<ApiClient>(mockApiClient);
      getIt.registerSingleton<SubscriptionService>(mockSubscriptionService);
    });

    tearDown(() {
      final getIt = GetIt.instance;
      if (getIt.isRegistered<ApiClient>()) getIt.unregister<ApiClient>();
      if (getIt.isRegistered<SubscriptionService>()) getIt.unregister<SubscriptionService>();
    });

    Widget buildScreen(Map<String, dynamic> event) {
      return MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en')],
        home: EventDetailScreen(event: event),
      );
    }

    final sampleEvent = {
      'id': '123',
      'client_name': 'Acme Corp',
      'shift_name': 'Evening Gala',
      'event_name': 'Evening Gala',
      'date': '2025-12-20',
      'start_time': '18:00',
      'end_time': '23:00',
      'venue_name': 'Grand Ballroom',
      'venue_address': '456 Event Ave',
      'city': 'Denver',
      'state': 'CO',
      'status': 'draft',
      'roles': [
        {'role': 'Bartender', 'count': 3},
        {'role': 'Server', 'count': 5},
      ],
      'accepted_staff': [],
      'role_stats': [
        {'role': 'Bartender', 'capacity': 3, 'taken': 0, 'remaining': 3, 'is_full': false},
        {'role': 'Server', 'capacity': 5, 'taken': 0, 'remaining': 5, 'is_full': false},
      ],
    };

    testWidgets('renders client name in app bar or header', (tester) async {
      await tester.pumpWidget(buildScreen(sampleEvent));
      await tester.pumpAndSettle();
      expect(find.text('Acme Corp'), findsWidgets);
    });

    testWidgets('renders event/shift name', (tester) async {
      await tester.pumpWidget(buildScreen(sampleEvent));
      await tester.pumpAndSettle();
      expect(find.text('Evening Gala'), findsWidgets);
    });

    testWidgets('renders date information', (tester) async {
      await tester.pumpWidget(buildScreen(sampleEvent));
      await tester.pumpAndSettle();
      expect(find.textContaining('2025'), findsWidgets);
    });

    testWidgets('renders venue name', (tester) async {
      await tester.pumpWidget(buildScreen(sampleEvent));
      await tester.pumpAndSettle();
      expect(find.text('Grand Ballroom'), findsWidgets);
    });

    testWidgets('renders role information', (tester) async {
      await tester.pumpWidget(buildScreen(sampleEvent));
      await tester.pumpAndSettle();
      expect(find.textContaining('Bartender'), findsWidgets);
    });

    testWidgets('renders location', (tester) async {
      await tester.pumpWidget(buildScreen(sampleEvent));
      await tester.pumpAndSettle();
      expect(find.textContaining('Denver'), findsWidgets);
    });

    testWidgets('renders Scaffold', (tester) async {
      await tester.pumpWidget(buildScreen(sampleEvent));
      await tester.pumpAndSettle();
      expect(find.byType(Scaffold), findsWidgets);
    });

    testWidgets('handles missing optional fields gracefully', (tester) async {
      final minimalEvent = {
        'id': '456',
        'roles': [
          {'role': 'Staff', 'count': 1},
        ],
        'accepted_staff': [],
        'role_stats': [],
        'status': 'draft',
      };
      await tester.pumpWidget(buildScreen(minimalEvent));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders status badge for draft events', (tester) async {
      await tester.pumpWidget(buildScreen(sampleEvent));
      await tester.pumpAndSettle();
      // Draft events show "Upcoming" or "Past" badge, not "Draft" text
      expect(find.text('Upcoming').evaluate().isNotEmpty ||
             find.text('Past').evaluate().isNotEmpty, isTrue);
    });

    testWidgets('renders with published status', (tester) async {
      final publishedEvent = {...sampleEvent, 'status': 'published'};
      await tester.pumpWidget(buildScreen(publishedEvent));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders accepted staff section when present', (tester) async {
      final eventWithStaff = {
        ...sampleEvent,
        'accepted_staff': [
          {'userKey': 'google:1', 'name': 'Jane Doe', 'role': 'Bartender', 'response': 'accepted'},
        ],
      };
      await tester.pumpWidget(buildScreen(eventWithStaff));
      await tester.pumpAndSettle();
      expect(find.textContaining('Jane'), findsWidgets);
    });

    testWidgets('renders time range', (tester) async {
      await tester.pumpWidget(buildScreen(sampleEvent));
      await tester.pumpAndSettle();
      expect(find.textContaining('18:00'), findsWidgets);
    });
  });
}
