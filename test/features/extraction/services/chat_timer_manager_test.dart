import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexa/features/extraction/services/chat_timer_manager.dart';

void main() {
  group('ChatTimerConfig', () {
    test('provides default configuration', () {
      const config = ChatTimerConfig.defaultConfig;

      expect(config.confirmationDuration, const Duration(seconds: 30));
      expect(config.resetDuration, const Duration(seconds: 5));
      expect(config.inactivityDuration, const Duration(minutes: 2));
      expect(config.autoShowDuration, const Duration(seconds: 15));
      expect(config.autoScrollInterval, const Duration(milliseconds: 150));
    });

    test('allows custom configuration', () {
      const config = ChatTimerConfig(
        confirmationDuration: Duration(seconds: 45),
        resetDuration: Duration(seconds: 3),
        inactivityDuration: Duration(minutes: 5),
        autoShowDuration: Duration(seconds: 10),
        autoScrollInterval: Duration(milliseconds: 100),
      );

      expect(config.confirmationDuration, const Duration(seconds: 45));
      expect(config.resetDuration, const Duration(seconds: 3));
      expect(config.inactivityDuration, const Duration(minutes: 5));
      expect(config.autoShowDuration, const Duration(seconds: 10));
      expect(config.autoScrollInterval, const Duration(milliseconds: 100));
    });
  });

  group('ChatTimerManager', () {
    late ChatTimerManager manager;

    setUp(() {
      manager = ChatTimerManager();
    });

    tearDown(() {
      manager.dispose();
    });

    group('startConfirmationTimer', () {
      test('calls onTick with countdown values', () {
        fakeAsync((async) {
          final List<int> ticks = [];

          manager.startConfirmationTimer(
            onTick: (secondsRemaining) => ticks.add(secondsRemaining),
            onComplete: () {},
          );

          // Initial tick
          expect(ticks, [30]);

          // Tick every second
          async.elapse(const Duration(seconds: 1));
          expect(ticks, [30, 29]);

          async.elapse(const Duration(seconds: 1));
          expect(ticks, [30, 29, 28]);

          async.elapse(const Duration(seconds: 5));
          expect(ticks.length, 8); // 30, 29, 28, 27, 26, 25, 24, 23
        });
      });

      test('calls onComplete after 30 seconds', () {
        fakeAsync((async) {
          var completed = false;

          manager.startConfirmationTimer(
            onTick: (_) {},
            onComplete: () => completed = true,
          );

          expect(completed, false);

          async.elapse(const Duration(seconds: 29));
          expect(completed, false);

          async.elapse(const Duration(seconds: 1));
          expect(completed, true);
        });
      });

      test('respects custom configuration', () {
        fakeAsync((async) {
          final customManager = ChatTimerManager(
            config: const ChatTimerConfig(confirmationDuration: Duration(seconds: 10)),
          );
          var completed = false;

          customManager.startConfirmationTimer(
            onTick: (_) {},
            onComplete: () => completed = true,
          );

          async.elapse(const Duration(seconds: 9));
          expect(completed, false);

          async.elapse(const Duration(seconds: 1));
          expect(completed, true);

          customManager.dispose();
        });
      });

      test('can be canceled', () {
        fakeAsync((async) {
          var completed = false;

          manager.startConfirmationTimer(
            onTick: (_) {},
            onComplete: () => completed = true,
          );

          async.elapse(const Duration(seconds: 15));
          manager.cancel(ChatTimerType.confirmation);

          async.elapse(const Duration(seconds: 20));
          expect(completed, false); // Should not complete after cancel
        });
      });
    });

    group('startResetTimer', () {
      test('calls onComplete after 5 seconds', () {
        fakeAsync((async) {
          var completed = false;

          manager.startResetTimer(
            onComplete: () => completed = true,
          );

          expect(completed, false);

          async.elapse(const Duration(seconds: 4));
          expect(completed, false);

          async.elapse(const Duration(seconds: 1));
          expect(completed, true);
        });
      });

      test('respects custom duration', () {
        fakeAsync((async) {
          final customManager = ChatTimerManager(
            config: const ChatTimerConfig(resetDuration: Duration(seconds: 2)),
          );
          var completed = false;

          customManager.startResetTimer(
            onComplete: () => completed = true,
          );

          async.elapse(const Duration(seconds: 2));
          expect(completed, true);

          customManager.dispose();
        });
      });

      test('can be canceled', () {
        fakeAsync((async) {
          var completed = false;

          manager.startResetTimer(
            onComplete: () => completed = true,
          );

          async.elapse(const Duration(seconds: 2));
          manager.cancel(ChatTimerType.reset);

          async.elapse(const Duration(seconds: 10));
          expect(completed, false);
        });
      });
    });

    group('startInactivityTimer', () {
      test('calls onTimeout after 2 minutes', () {
        fakeAsync((async) {
          var timedOut = false;

          manager.startInactivityTimer(
            onTimeout: () => timedOut = true,
          );

          expect(timedOut, false);

          async.elapse(const Duration(minutes: 1, seconds: 59));
          expect(timedOut, false);

          async.elapse(const Duration(seconds: 1));
          expect(timedOut, true);
        });
      });

      test('respects custom duration', () {
        fakeAsync((async) {
          final customManager = ChatTimerManager(
            config: const ChatTimerConfig(inactivityDuration: Duration(seconds: 30)),
          );
          var timedOut = false;

          customManager.startInactivityTimer(
            onTimeout: () => timedOut = true,
          );

          async.elapse(const Duration(seconds: 30));
          expect(timedOut, true);

          customManager.dispose();
        });
      });
    });

    group('startAutoShowTimer', () {
      test('calls onShow after 15 seconds', () {
        fakeAsync((async) {
          var shown = false;

          manager.startAutoShowTimer(
            onShow: () => shown = true,
          );

          expect(shown, false);

          async.elapse(const Duration(seconds: 14));
          expect(shown, false);

          async.elapse(const Duration(seconds: 1));
          expect(shown, true);
        });
      });
    });

    group('startAutoScrollTimer', () {
      test('calls onTick periodically', () {
        fakeAsync((async) {
          var scrollCount = 0;

          manager.startAutoScrollTimer(
            onTick: () => scrollCount++,
          );

          // Initial call happens immediately
          expect(scrollCount, 0);

          // Then every 150ms
          async.elapse(const Duration(milliseconds: 150));
          expect(scrollCount, 1);

          async.elapse(const Duration(milliseconds: 150));
          expect(scrollCount, 2);

          async.elapse(const Duration(milliseconds: 750)); // 5 more periods
          expect(scrollCount, 7);
        });
      });

      test('respects custom interval', () {
        fakeAsync((async) {
          final customManager = ChatTimerManager(
            config: const ChatTimerConfig(autoScrollInterval: Duration(milliseconds: 100)),
          );
          var scrollCount = 0;

          customManager.startAutoScrollTimer(
            onTick: () => scrollCount++,
          );

          async.elapse(const Duration(milliseconds: 100));
          expect(scrollCount, 1);

          async.elapse(const Duration(milliseconds: 100));
          expect(scrollCount, 2);

          customManager.dispose();
        });
      });
    });

    group('cancel', () {
      test('cancels specific timer type', () {
        fakeAsync((async) {
          var confirmationCompleted = false;
          var resetCompleted = false;

          manager.startConfirmationTimer(
            onTick: (_) {},
            onComplete: () => confirmationCompleted = true,
          );

          manager.startResetTimer(
            onComplete: () => resetCompleted = true,
          );

          // Cancel only confirmation timer
          manager.cancel(ChatTimerType.confirmation);

          // Advance time past both timer durations
          async.elapse(const Duration(seconds: 31));

          expect(confirmationCompleted, false); // Canceled
          expect(resetCompleted, true); // Not canceled
        });
      });

      test('safely handles canceling non-existent timer', () {
        expect(
          () => manager.cancel(ChatTimerType.confirmation),
          returnsNormally,
        );
      });

      test('allows restarting canceled timer', () {
        fakeAsync((async) {
          var completionCount = 0;

          manager.startResetTimer(
            onComplete: () => completionCount++,
          );

          async.elapse(const Duration(seconds: 2));
          manager.cancel(ChatTimerType.reset);

          async.elapse(const Duration(seconds: 10));
          expect(completionCount, 0);

          // Restart timer
          manager.startResetTimer(
            onComplete: () => completionCount++,
          );

          async.elapse(const Duration(seconds: 5));
          expect(completionCount, 1);
        });
      });
    });

    group('cancelAll', () {
      test('cancels all running timers', () {
        fakeAsync((async) {
          var confirmationCompleted = false;
          var resetCompleted = false;
          var inactivityTimedOut = false;

          manager.startConfirmationTimer(
            onTick: (_) {},
            onComplete: () => confirmationCompleted = true,
          );

          manager.startResetTimer(
            onComplete: () => resetCompleted = true,
          );

          manager.startInactivityTimer(
            onTimeout: () => inactivityTimedOut = true,
          );

          // Cancel all
          manager.cancelAll();

          // Advance time past all timer durations
          async.elapse(const Duration(minutes: 5));

          expect(confirmationCompleted, false);
          expect(resetCompleted, false);
          expect(inactivityTimedOut, false);
        });
      });
    });

    group('dispose', () {
      test('cancels all timers and cleans up resources', () {
        fakeAsync((async) {
          var confirmationCompleted = false;

          manager.startConfirmationTimer(
            onTick: (_) {},
            onComplete: () => confirmationCompleted = true,
          );

          manager.dispose();

          // Advance time
          async.elapse(const Duration(seconds: 31));

          expect(confirmationCompleted, false); // Timer should be canceled
        });
      });

      test('can be called multiple times safely', () {
        expect(() {
          manager.dispose();
          manager.dispose();
        }, returnsNormally);
      });
    });

    group('multiple timers', () {
      test('can run multiple different timer types concurrently', () {
        fakeAsync((async) {
          var confirmationTicks = 0;
          var resetCompleted = false;
          var inactivityTimedOut = false;

          manager.startConfirmationTimer(
            onTick: (_) => confirmationTicks++,
            onComplete: () {},
          );

          manager.startResetTimer(
            onComplete: () => resetCompleted = true,
          );

          manager.startInactivityTimer(
            onTimeout: () => inactivityTimedOut = true,
          );

          // After 6 seconds
          async.elapse(const Duration(seconds: 6));

          expect(confirmationTicks, 7); // Initial + 6 ticks
          expect(resetCompleted, true); // 5 second timer completed
          expect(inactivityTimedOut, false); // 2 minute timer still running
        });
      });

      test('restarting same timer type cancels previous one', () {
        fakeAsync((async) {
          var firstCompleted = false;
          var secondCompleted = false;

          manager.startResetTimer(
            onComplete: () => firstCompleted = true,
          );

          async.elapse(const Duration(seconds: 2));

          // Start another reset timer (should cancel first)
          manager.startResetTimer(
            onComplete: () => secondCompleted = true,
          );

          async.elapse(const Duration(seconds: 4));

          expect(firstCompleted, false); // First timer was canceled
          expect(secondCompleted, false); // Second timer not done yet

          async.elapse(const Duration(seconds: 1));

          expect(firstCompleted, false);
          expect(secondCompleted, true); // Second timer completed
        });
      });
    });
  });
}
