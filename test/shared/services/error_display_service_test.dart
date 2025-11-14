import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexa/shared/services/error_display_service.dart';

void main() {
  group('ErrorDisplayService', () {
    late Widget testApp;

    setUp(() {
      testApp = MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                // Button to trigger error displays
              },
              child: const Text('Test Button'),
            ),
          ),
        ),
      );
    });

    group('showSuccess', () {
      testWidgets('displays success SnackBar with green background',
          (tester) async {
        await tester.pumpWidget(testApp);

        final context = tester.element(find.byType(ElevatedButton));
        ErrorDisplayService.showSuccess(context, 'Operation successful');

        await tester.pump();

        // Find the SnackBar
        expect(find.text('Operation successful'), findsOneWidget);

        // Verify background color (green)
        final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
        expect(snackBar.backgroundColor, const Color(0xFF059669));
      });

      testWidgets('respects custom duration', (tester) async {
        await tester.pumpWidget(testApp);

        final context = tester.element(find.byType(ElevatedButton));
        ErrorDisplayService.showSuccess(
          context,
          'Quick message',
          duration: const Duration(seconds: 1),
        );

        await tester.pump();

        final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
        expect(snackBar.duration, const Duration(seconds: 1));
      });

      testWidgets('uses default 2 second duration', (tester) async {
        await tester.pumpWidget(testApp);

        final context = tester.element(find.byType(ElevatedButton));
        ErrorDisplayService.showSuccess(context, 'Default duration');

        await tester.pump();

        final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
        expect(snackBar.duration, const Duration(seconds: 2));
      });

      testWidgets('does not show when context is not mounted', (tester) async {
        await tester.pumpWidget(testApp);

        final context = tester.element(find.byType(ElevatedButton));

        // Remove the widget
        await tester.pumpWidget(const SizedBox());

        // Try to show SnackBar with unmounted context
        ErrorDisplayService.showSuccess(context, 'Should not appear');

        await tester.pump();

        expect(find.byType(SnackBar), findsNothing);
      });
    });

    group('showError', () {
      testWidgets('displays error SnackBar with red background',
          (tester) async {
        await tester.pumpWidget(testApp);

        final context = tester.element(find.byType(ElevatedButton));
        ErrorDisplayService.showError(context, 'Error occurred');

        await tester.pump();

        expect(find.text('Error occurred'), findsOneWidget);

        final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
        expect(snackBar.backgroundColor, Colors.red);
      });

      testWidgets('uses default 4 second duration for errors', (tester) async {
        await tester.pumpWidget(testApp);

        final context = tester.element(find.byType(ElevatedButton));
        ErrorDisplayService.showError(context, 'Error message');

        await tester.pump();

        final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
        expect(snackBar.duration, const Duration(seconds: 4));
      });

      testWidgets('respects custom duration', (tester) async {
        await tester.pumpWidget(testApp);

        final context = tester.element(find.byType(ElevatedButton));
        ErrorDisplayService.showError(
          context,
          'Custom duration error',
          duration: const Duration(seconds: 6),
        );

        await tester.pump();

        final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
        expect(snackBar.duration, const Duration(seconds: 6));
      });
    });

    group('showWarning', () {
      testWidgets('displays warning SnackBar with orange background',
          (tester) async {
        await tester.pumpWidget(testApp);

        final context = tester.element(find.byType(ElevatedButton));
        ErrorDisplayService.showWarning(context, 'Warning message');

        await tester.pump();

        expect(find.text('Warning message'), findsOneWidget);

        final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
        expect(snackBar.backgroundColor, Colors.orange[700]);
      });

      testWidgets('uses default 3 second duration', (tester) async {
        await tester.pumpWidget(testApp);

        final context = tester.element(find.byType(ElevatedButton));
        ErrorDisplayService.showWarning(context, 'Warning');

        await tester.pump();

        final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
        expect(snackBar.duration, const Duration(seconds: 3));
      });
    });

    group('showInfo', () {
      testWidgets('displays info SnackBar with blue background',
          (tester) async {
        await tester.pumpWidget(testApp);

        final context = tester.element(find.byType(ElevatedButton));
        ErrorDisplayService.showInfo(context, 'Info message');

        await tester.pump();

        expect(find.text('Info message'), findsOneWidget);

        final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
        expect(snackBar.backgroundColor, Colors.blue[700]);
      });

      testWidgets('uses default 2 second duration', (tester) async {
        await tester.pumpWidget(testApp);

        final context = tester.element(find.byType(ElevatedButton));
        ErrorDisplayService.showInfo(context, 'Info');

        await tester.pump();

        final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
        expect(snackBar.duration, const Duration(seconds: 2));
      });
    });

    group('showErrorFromException', () {
      testWidgets('formats and displays exception message', (tester) async {
        await tester.pumpWidget(testApp);

        final context = tester.element(find.byType(ElevatedButton));
        ErrorDisplayService.showErrorFromException(
          context,
          Exception('Test exception'),
        );

        await tester.pump();

        expect(find.text('Test exception'), findsOneWidget);
      });

      testWidgets('adds prefix to exception message', (tester) async {
        await tester.pumpWidget(testApp);

        final context = tester.element(find.byType(ElevatedButton));
        ErrorDisplayService.showErrorFromException(
          context,
          Exception('Database error'),
          prefix: 'Failed to save',
        );

        await tester.pump();

        expect(find.text('Failed to save: Database error'), findsOneWidget);
      });

      testWidgets('formats SocketException as network error', (tester) async {
        await tester.pumpWidget(testApp);

        final context = tester.element(find.byType(ElevatedButton));

        // Simulate a SocketException string representation
        final error = 'SocketException: Connection refused';
        ErrorDisplayService.showErrorFromException(context, error);

        await tester.pump();

        expect(find.text('Network connection failed'), findsOneWidget);
      });

      testWidgets('formats TimeoutException appropriately', (tester) async {
        await tester.pumpWidget(testApp);

        final context = tester.element(find.byType(ElevatedButton));
        final error = 'TimeoutException after 5 seconds';
        ErrorDisplayService.showErrorFromException(context, error);

        await tester.pump();

        expect(find.text('Request timed out'), findsOneWidget);
      });

      testWidgets('formats FormatException appropriately', (tester) async {
        await tester.pumpWidget(testApp);

        final context = tester.element(find.byType(ElevatedButton));
        final error = 'FormatException: Invalid JSON';
        ErrorDisplayService.showErrorFromException(context, error);

        await tester.pump();

        expect(find.text('Invalid data format'), findsOneWidget);
      });

      testWidgets('extracts message after "Exception:" marker', (tester) async {
        await tester.pumpWidget(testApp);

        final context = tester.element(find.byType(ElevatedButton));
        final error = 'Exception: File not found';
        ErrorDisplayService.showErrorFromException(context, error);

        await tester.pump();

        expect(find.text('File not found'), findsOneWidget);
      });

      testWidgets('handles null error gracefully', (tester) async {
        await tester.pumpWidget(testApp);

        final context = tester.element(find.byType(ElevatedButton));
        ErrorDisplayService.showErrorFromException(context, null);

        await tester.pump();

        expect(find.text('Unknown error occurred'), findsOneWidget);
      });
    });

    group('showCustom', () {
      testWidgets('displays custom styled SnackBar', (tester) async {
        await tester.pumpWidget(testApp);

        final context = tester.element(find.byType(ElevatedButton));
        ErrorDisplayService.showCustom(
          context,
          message: 'Custom message',
          backgroundColor: Colors.purple,
          textColor: Colors.yellow,
        );

        await tester.pump();

        expect(find.text('Custom message'), findsOneWidget);

        final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
        expect(snackBar.backgroundColor, Colors.purple);

        final text = tester.widget<Text>(find.text('Custom message'));
        expect(text.style?.color, Colors.yellow);
      });

      testWidgets('supports custom action button', (tester) async {
        await tester.pumpWidget(testApp);

        var actionPressed = false;

        final context = tester.element(find.byType(ElevatedButton));
        ErrorDisplayService.showCustom(
          context,
          message: 'Message with action',
          backgroundColor: Colors.teal,
          action: SnackBarAction(
            label: 'UNDO',
            onPressed: () => actionPressed = true,
          ),
        );

        await tester.pump();
        await tester.pumpAndSettle(); // Wait for SnackBar animation to complete

        // Find and tap the action button
        expect(find.text('UNDO'), findsOneWidget);

        await tester.tap(find.text('UNDO'));
        await tester.pump();

        expect(actionPressed, true);
      });
    });

    group('showErrorWithRetry', () {
      testWidgets('displays error with retry action', (tester) async {
        await tester.pumpWidget(testApp);

        var retryPressed = false;

        final context = tester.element(find.byType(ElevatedButton));
        ErrorDisplayService.showErrorWithRetry(
          context,
          'Operation failed',
          () => retryPressed = true,
        );

        await tester.pump();
        await tester.pumpAndSettle(); // Wait for SnackBar animation

        expect(find.text('Operation failed'), findsOneWidget);
        expect(find.text('Retry'), findsOneWidget);

        // Verify red background
        final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
        expect(snackBar.backgroundColor, Colors.red);

        // Tap retry button
        await tester.tap(find.text('Retry'));
        await tester.pump();

        expect(retryPressed, true);
      });

      testWidgets('uses 6 second duration by default', (tester) async {
        await tester.pumpWidget(testApp);

        final context = tester.element(find.byType(ElevatedButton));
        ErrorDisplayService.showErrorWithRetry(
          context,
          'Error',
          () {},
        );

        await tester.pump();

        final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
        expect(snackBar.duration, const Duration(seconds: 6));
      });
    });

    group('showLoading', () {
      testWidgets('displays loading indicator with message', (tester) async {
        await tester.pumpWidget(testApp);

        final context = tester.element(find.byType(ElevatedButton));
        final dismiss = ErrorDisplayService.showLoading(context, 'Loading data...');

        await tester.pump();

        expect(find.text('Loading data...'), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
        expect(snackBar.backgroundColor, Colors.blue[700]);

        // Clean up
        dismiss();
      });

      testWidgets('can be dismissed programmatically', (tester) async {
        await tester.pumpWidget(testApp);

        final context = tester.element(find.byType(ElevatedButton));
        final dismiss = ErrorDisplayService.showLoading(context, 'Loading...');

        await tester.pump();

        expect(find.text('Loading...'), findsOneWidget);

        // Dismiss
        dismiss();
        await tester.pump();

        // SnackBar should start dismissing
        await tester.pumpAndSettle();

        expect(find.text('Loading...'), findsNothing);
      });

      testWidgets('has very long duration (effectively indefinite)', (tester) async {
        await tester.pumpWidget(testApp);

        final context = tester.element(find.byType(ElevatedButton));
        final dismiss = ErrorDisplayService.showLoading(context, 'Loading...');

        await tester.pump();

        final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
        expect(snackBar.duration, const Duration(days: 1));

        dismiss();
      });
    });

    group('clearAll', () {
      testWidgets('removes all displayed SnackBars', (tester) async {
        await tester.pumpWidget(testApp);

        final context = tester.element(find.byType(ElevatedButton));

        // Show multiple SnackBars
        ErrorDisplayService.showSuccess(context, 'Success');
        await tester.pump();

        expect(find.text('Success'), findsOneWidget);

        // Clear all
        ErrorDisplayService.clearAll(context);
        await tester.pumpAndSettle();

        expect(find.text('Success'), findsNothing);
      });

      testWidgets('handles context.mounted check', (tester) async {
        await tester.pumpWidget(testApp);

        final context = tester.element(find.byType(ElevatedButton));

        // Remove widget
        await tester.pumpWidget(const SizedBox());

        // Should not throw
        expect(() => ErrorDisplayService.clearAll(context), returnsNormally);
      });
    });

    group('BuildContext extensions', () {
      testWidgets('showSuccess extension works', (tester) async {
        await tester.pumpWidget(testApp);

        final context = tester.element(find.byType(ElevatedButton));
        context.showSuccess('Extension success');

        await tester.pump();

        expect(find.text('Extension success'), findsOneWidget);
      });

      testWidgets('showError extension works', (tester) async {
        await tester.pumpWidget(testApp);

        final context = tester.element(find.byType(ElevatedButton));
        context.showError('Extension error');

        await tester.pump();

        expect(find.text('Extension error'), findsOneWidget);
      });

      testWidgets('showWarning extension works', (tester) async {
        await tester.pumpWidget(testApp);

        final context = tester.element(find.byType(ElevatedButton));
        context.showWarning('Extension warning');

        await tester.pump();

        expect(find.text('Extension warning'), findsOneWidget);
      });

      testWidgets('showInfo extension works', (tester) async {
        await tester.pumpWidget(testApp);

        final context = tester.element(find.byType(ElevatedButton));
        context.showInfo('Extension info');

        await tester.pump();

        expect(find.text('Extension info'), findsOneWidget);
      });

      testWidgets('showErrorFromException extension works', (tester) async {
        await tester.pumpWidget(testApp);

        final context = tester.element(find.byType(ElevatedButton));
        context.showErrorFromException(
          Exception('Test'),
          prefix: 'Failed',
        );

        await tester.pump();

        expect(find.text('Failed: Test'), findsOneWidget);
      });
    });

    group('edge cases', () {
      testWidgets('handles very long messages', (tester) async {
        await tester.pumpWidget(testApp);

        final longMessage = 'A' * 500;
        final context = tester.element(find.byType(ElevatedButton));
        ErrorDisplayService.showSuccess(context, longMessage);

        await tester.pump();

        expect(find.textContaining('A'), findsOneWidget);
      });

      testWidgets('handles messages with newlines', (tester) async {
        await tester.pumpWidget(testApp);

        final context = tester.element(find.byType(ElevatedButton));
        ErrorDisplayService.showInfo(context, 'Line 1\nLine 2\nLine 3');

        await tester.pump();

        expect(find.text('Line 1\nLine 2\nLine 3'), findsOneWidget);
      });

      testWidgets('handles special characters in messages', (tester) async {
        await tester.pumpWidget(testApp);

        final context = tester.element(find.byType(ElevatedButton));
        ErrorDisplayService.showError(context, 'Error: "invalid" & <unsafe>');

        await tester.pump();

        expect(find.text('Error: "invalid" & <unsafe>'), findsOneWidget);
      });
    });
  });
}
