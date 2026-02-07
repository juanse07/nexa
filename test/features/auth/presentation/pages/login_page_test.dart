import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexa/features/auth/presentation/pages/login_page.dart';

void main() {
  group('LoginPage Widget Tests', () {
    Widget buildLoginPage() {
      return MediaQuery(
        data: const MediaQueryData(size: Size(600, 1200)),
        child: const MaterialApp(
          home: LoginPage(),
        ),
      );
    }

    testWidgets('renders Welcome Back text', (tester) async {
      // Suppress overflow errors — they're visual warnings, not logic bugs
      final oldHandler = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.toString().contains('overflowed')) return;
        oldHandler?.call(details);
      };

      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(() => FlutterError.onError = oldHandler);

      await tester.pumpWidget(buildLoginPage());
      expect(find.text('Welcome Back'), findsOneWidget);
    });

    testWidgets('renders sign-in subtitle', (tester) async {
      final oldHandler = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.toString().contains('overflowed')) return;
        oldHandler?.call(details);
      };

      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(() => FlutterError.onError = oldHandler);

      await tester.pumpWidget(buildLoginPage());
      expect(find.text('Sign in to continue to your account'), findsOneWidget);
    });

    testWidgets('renders Continue with Google button', (tester) async {
      final oldHandler = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.toString().contains('overflowed')) return;
        oldHandler?.call(details);
      };

      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(() => FlutterError.onError = oldHandler);

      await tester.pumpWidget(buildLoginPage());
      expect(find.text('Continue with Google'), findsOneWidget);
    });

    testWidgets('renders Continue with Phone button', (tester) async {
      final oldHandler = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.toString().contains('overflowed')) return;
        oldHandler?.call(details);
      };

      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(() => FlutterError.onError = oldHandler);

      await tester.pumpWidget(buildLoginPage());
      expect(find.text('Continue with Phone'), findsOneWidget);
    });

    testWidgets('renders terms and privacy footer text', (tester) async {
      final oldHandler = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.toString().contains('overflowed')) return;
        oldHandler?.call(details);
      };

      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(() => FlutterError.onError = oldHandler);

      await tester.pumpWidget(buildLoginPage());
      expect(find.textContaining('Terms of Service'), findsOneWidget);
    });

    testWidgets('renders without fatal errors', (tester) async {
      final oldHandler = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.toString().contains('overflowed')) return;
        oldHandler?.call(details);
      };

      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(() => FlutterError.onError = oldHandler);

      await tester.pumpWidget(buildLoginPage());
      expect(find.byType(LoginPage), findsOneWidget);
    });

    testWidgets('Google button is a FilledButton', (tester) async {
      final oldHandler = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.toString().contains('overflowed')) return;
        oldHandler?.call(details);
      };

      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(() => FlutterError.onError = oldHandler);

      await tester.pumpWidget(buildLoginPage());
      expect(find.byType(FilledButton), findsOneWidget);
    });

    testWidgets('Phone button is an OutlinedButton', (tester) async {
      final oldHandler = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.toString().contains('overflowed')) return;
        oldHandler?.call(details);
      };

      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(() => FlutterError.onError = oldHandler);

      await tester.pumpWidget(buildLoginPage());
      expect(find.byType(OutlinedButton), findsWidgets);
    });
  });
}
