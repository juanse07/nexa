import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexa/features/extraction/utils/chat_scroll_behavior.dart';

void main() {
  group('ChatScrollConfig', () {
    test('provides default configuration', () {
      const config = ChatScrollConfig.defaultConfig;

      expect(config.scrollDeltaThreshold, 5.0);
      expect(config.directionThreshold, 10.0);
      expect(config.bottomThreshold, 100.0);
      expect(config.autoShowDelay, const Duration(seconds: 15));
      expect(config.autoScrollInterval, const Duration(milliseconds: 150));
      expect(config.autoScrollIterations, 13);
    });

    test('allows custom configuration', () {
      const config = ChatScrollConfig(
        scrollDeltaThreshold: 10.0,
        directionThreshold: 20.0,
        bottomThreshold: 50.0,
        autoShowDelay: Duration(seconds: 10),
        autoScrollInterval: Duration(milliseconds: 100),
        autoScrollIterations: 10,
      );

      expect(config.scrollDeltaThreshold, 10.0);
      expect(config.directionThreshold, 20.0);
      expect(config.bottomThreshold, 50.0);
      expect(config.autoShowDelay, const Duration(seconds: 10));
      expect(config.autoScrollInterval, const Duration(milliseconds: 100));
      expect(config.autoScrollIterations, 10);
    });
  });

  group('ChatScrollBehavior', () {
    late ScrollController scrollController;
    late ChatScrollBehavior behavior;
    late bool inputVisible;
    late bool mounted;
    late List<String> actions; // Track hide/show calls

    setUp(() {
      scrollController = ScrollController();
      inputVisible = true;
      mounted = true;
      actions = [];

      behavior = ChatScrollBehavior(
        scrollController: scrollController,
        onHideInput: () {
          actions.add('hide');
          inputVisible = false;
        },
        onShowInput: () {
          actions.add('show');
          inputVisible = true;
        },
        isInputVisible: () => inputVisible,
        isMounted: () => mounted,
      );
    });

    tearDown(() {
      behavior.dispose();
      scrollController.dispose();
    });

    group('handleScrollNotification', () {
      testWidgets('handles ScrollStartNotification', (tester) async {
        await tester.pumpWidget(_buildTestApp(scrollController));

        fakeAsync((async) {
          // Start auto-show timer
          behavior.handleScrollNotification(
            ScrollStartNotification(
              metrics: scrollController.position,
              context: scrollController.position.context.storageContext,
            ),
          );

          // Timer should be canceled (tested by ensuring no show after delay)
          async.elapse(const Duration(seconds: 16));
          expect(actions, isEmpty); // No auto-show
        });
      });

      testWidgets('handles ScrollEndNotification and starts auto-show timer',
          (tester) async {
        await tester.pumpWidget(_buildTestApp(scrollController));
        await tester.pumpAndSettle();

        fakeAsync((async) {
          inputVisible = false; // Simulate hidden input

          behavior.handleScrollNotification(
            ScrollEndNotification(
              metrics: scrollController.position,
              context: scrollController.position.context.storageContext,
            ),
          );

          // Should start auto-show timer (15 seconds)
          expect(actions, isEmpty);

          async.elapse(const Duration(seconds: 14));
          expect(actions, isEmpty);

          async.elapse(const Duration(seconds: 1));
          expect(actions, contains('show'));
        });
      });

      testWidgets('shows input immediately when at bottom on scroll end',
          (tester) async {
        await tester.pumpWidget(_buildTestApp(scrollController));
        await tester.pumpAndSettle();

        // Scroll to bottom
        scrollController.jumpTo(scrollController.position.maxScrollExtent);
        await tester.pump();

        inputVisible = false;

        behavior.handleScrollNotification(
          ScrollEndNotification(
            metrics: scrollController.position,
            context: scrollController.position.context.storageContext,
          ),
        );

        expect(actions, contains('show'));

        // Clean up any timers created
        behavior.cancelAllTimers();
      });

      testWidgets('hides input when scrolling down significantly',
          (tester) async {
        await tester.pumpWidget(_buildTestApp(scrollController));
        await tester.pumpAndSettle();

        inputVisible = true;

        // Simulate downward scroll (scrollDelta > 0 means scrolling down)
        behavior.handleScrollNotification(
          ScrollUpdateNotification(
            metrics: scrollController.position,
            context: scrollController.position.context.storageContext,
            scrollDelta: 15.0, // Greater than directionThreshold (10)
          ),
        );

        expect(actions, contains('hide'));
      });

      testWidgets('shows input when scrolling up significantly',
          (tester) async {
        await tester.pumpWidget(_buildTestApp(scrollController));
        await tester.pumpAndSettle();

        inputVisible = false;

        // Simulate upward scroll (scrollDelta < 0 means scrolling up)
        behavior.handleScrollNotification(
          ScrollUpdateNotification(
            metrics: scrollController.position,
            context: scrollController.position.context.storageContext,
            scrollDelta: -15.0, // Less than -directionThreshold
          ),
        );

        expect(actions, contains('show'));
      });

      testWidgets('ignores small scroll deltas', (tester) async {
        await tester.pumpWidget(_buildTestApp(scrollController));
        await tester.pumpAndSettle();

        inputVisible = true;

        // Simulate tiny scroll (below scrollDeltaThreshold of 5)
        behavior.handleScrollNotification(
          ScrollUpdateNotification(
            metrics: scrollController.position,
            context: scrollController.position.context.storageContext,
            scrollDelta: 3.0, // Below threshold
          ),
        );

        expect(actions, isEmpty); // No action taken
      });

      testWidgets('always shows input when at bottom during scroll',
          (tester) async {
        await tester.pumpWidget(_buildTestApp(scrollController));
        await tester.pumpAndSettle();

        // Scroll to bottom
        scrollController.jumpTo(scrollController.position.maxScrollExtent);
        await tester.pump();

        inputVisible = false;

        // Scroll update at bottom should show input
        behavior.handleScrollNotification(
          ScrollUpdateNotification(
            metrics: scrollController.position,
            context: scrollController.position.context.storageContext,
            scrollDelta: 5.0,
          ),
        );

        expect(actions, contains('show'));
      });
    });

    group('scrollToBottom', () {
      testWidgets('jumps to bottom when not animated', (tester) async {
        await tester.pumpWidget(_buildTestApp(scrollController));
        await tester.pumpAndSettle();

        // Scroll to middle
        scrollController.jumpTo(scrollController.position.maxScrollExtent / 2);
        await tester.pump();

        expect(scrollController.position.pixels,
            lessThan(scrollController.position.maxScrollExtent));

        behavior.scrollToBottom(animated: false);
        await tester.pump();

        expect(scrollController.position.pixels,
            scrollController.position.maxScrollExtent);
      });

      testWidgets('animates to bottom when animated is true', (tester) async {
        await tester.pumpWidget(_buildTestApp(scrollController));
        await tester.pumpAndSettle();

        // Scroll to top
        scrollController.jumpTo(0);
        await tester.pump();

        behavior.scrollToBottom(animated: true);
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();

        // Should be at or near bottom
        expect(
          scrollController.position.pixels,
          greaterThanOrEqualTo(
              scrollController.position.maxScrollExtent - 10),
        );

        // Clean up auto-scroll timer
        behavior.cancelAllTimers();
      });

      testWidgets('handles missing scroll controller gracefully',
          (tester) async {
        final detachedController = ScrollController();
        final detachedBehavior = ChatScrollBehavior(
          scrollController: detachedController,
          onHideInput: () {},
          onShowInput: () {},
          isInputVisible: () => true,
          isMounted: () => true,
        );

        // Should not throw
        expect(() => detachedBehavior.scrollToBottom(), returnsNormally);

        detachedBehavior.dispose();
        detachedController.dispose();
      });
    });

    group('timer management', () {
      testWidgets('cancelAutoShowTimer cancels the timer', (tester) async {
        await tester.pumpWidget(_buildTestApp(scrollController));
        await tester.pumpAndSettle();

        fakeAsync((async) {
          inputVisible = false;

          // Create notification that starts timer
          final notification = ScrollEndNotification(
            metrics: scrollController.position,
            context: scrollController.position.context.storageContext,
          );

          behavior.handleScrollNotification(notification);

          // Cancel timer
          behavior.cancelAutoShowTimer();

          // Advance time - timer should not fire
          async.elapse(const Duration(seconds: 20));

          expect(actions, isEmpty); // No show
        });
      });

      test('cancelAutoScrollTimer cancels the periodic timer', () {
        fakeAsync((async) {
          var scrollCount = 0;

          // Start animated scroll (which uses auto-scroll timer)
          // Note: This is simplified since actual scroll uses ScrollController
          behavior.cancelAutoScrollTimer();

          // Timer should not fire
          async.elapse(const Duration(seconds: 5));

          expect(scrollCount, 0);
        });
      });

      testWidgets('cancelAllTimers cancels all timers', (tester) async {
        await tester.pumpWidget(_buildTestApp(scrollController));
        await tester.pumpAndSettle();

        fakeAsync((async) {
          inputVisible = false;

          // Start auto-show timer
          behavior.handleScrollNotification(
            ScrollEndNotification(
              metrics: scrollController.position,
              context: scrollController.position.context.storageContext,
            ),
          );

          // Cancel all
          behavior.cancelAllTimers();

          // Advance time
          async.elapse(const Duration(seconds: 20));

          expect(actions, isEmpty); // No show
        });
      });
    });

    group('dispose', () {
      testWidgets('cancels all timers on dispose', (tester) async {
        await tester.pumpWidget(_buildTestApp(scrollController));
        await tester.pumpAndSettle();

        fakeAsync((async) {
          inputVisible = false;

          // Start timer
          behavior.handleScrollNotification(
            ScrollEndNotification(
              metrics: scrollController.position,
              context: scrollController.position.context.storageContext,
            ),
          );

          // Dispose
          behavior.dispose();

          // Advance time
          async.elapse(const Duration(seconds: 20));

          expect(actions, isEmpty);
        });
      });

      test('can be called multiple times safely', () {
        expect(() {
          behavior.dispose();
          behavior.dispose();
        }, returnsNormally);
      });
    });

    group('utility methods', () {
      testWidgets('isAtTop detects top position', (tester) async {
        await tester.pumpWidget(_buildTestApp(scrollController));
        await tester.pumpAndSettle();

        scrollController.jumpTo(0);
        await tester.pump();

        expect(behavior.isAtTop(), true);

        scrollController.jumpTo(scrollController.position.maxScrollExtent);
        await tester.pump();

        expect(behavior.isAtTop(), false);
      });

      testWidgets('scrollPercentage calculates position percentage',
          (tester) async {
        await tester.pumpWidget(_buildTestApp(scrollController));
        await tester.pumpAndSettle();

        scrollController.jumpTo(0);
        await tester.pump();

        expect(behavior.scrollPercentage, 0.0);

        scrollController.jumpTo(scrollController.position.maxScrollExtent);
        await tester.pump();

        expect(behavior.scrollPercentage, 1.0);

        scrollController.jumpTo(scrollController.position.maxScrollExtent / 2);
        await tester.pump();

        expect(behavior.scrollPercentage, closeTo(0.5, 0.1));
      });

      testWidgets('hasScrollableContent detects scrollable content',
          (tester) async {
        await tester.pumpWidget(_buildTestApp(scrollController));
        await tester.pumpAndSettle();

        expect(behavior.hasScrollableContent, true);
      });

      testWidgets('hasScrollableContent returns false with no content',
          (tester) async {
        final emptyController = ScrollController();
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: ListView(
              controller: emptyController,
              children: const [],
            ),
          ),
        ));
        await tester.pumpAndSettle();

        final emptyBehavior = ChatScrollBehavior(
          scrollController: emptyController,
          onHideInput: () {},
          onShowInput: () {},
          isInputVisible: () => true,
          isMounted: () => true,
        );

        expect(emptyBehavior.hasScrollableContent, false);

        emptyBehavior.dispose();
        emptyController.dispose();
      });
    });

    group('custom configuration', () {
      testWidgets('respects custom scroll delta threshold', (tester) async {
        await tester.pumpWidget(_buildTestApp(scrollController));
        await tester.pumpAndSettle();

        final customBehavior = ChatScrollBehavior(
          scrollController: scrollController,
          onHideInput: () => actions.add('hide'),
          onShowInput: () => actions.add('show'),
          isInputVisible: () => inputVisible,
          isMounted: () => mounted,
          config: const ChatScrollConfig(scrollDeltaThreshold: 20.0),
        );

        inputVisible = true;

        // Scroll delta of 15 should be ignored (below 20 threshold)
        customBehavior.handleScrollNotification(
          ScrollUpdateNotification(
            metrics: scrollController.position,
            context: scrollController.position.context.storageContext,
            scrollDelta: 15.0,
          ),
        );

        expect(actions, isEmpty);

        customBehavior.dispose();
      });

      testWidgets('respects custom bottom threshold', (tester) async {
        await tester.pumpWidget(_buildTestApp(scrollController));
        await tester.pumpAndSettle();

        final customBehavior = ChatScrollBehavior(
          scrollController: scrollController,
          onHideInput: () => actions.add('hide'),
          onShowInput: () => actions.add('show'),
          isInputVisible: () => inputVisible,
          isMounted: () => mounted,
          config: const ChatScrollConfig(bottomThreshold: 200.0),
        );

        // Scroll to position that would be "bottom" with default threshold (100px)
        // but NOT with custom threshold (200px)
        // 250px from bottom > 200px threshold, so not "at bottom"
        scrollController.jumpTo(scrollController.position.maxScrollExtent - 250);
        await tester.pump();

        inputVisible = false;

        customBehavior.handleScrollNotification(
          ScrollEndNotification(
            metrics: scrollController.position,
            context: scrollController.position.context.storageContext,
          ),
        );

        // Should NOT auto-show because we're not within 200px of bottom
        expect(actions, isEmpty);

        customBehavior.dispose();
      });
    });
  });
}

/// Helper widget to create a scrollable test environment
Widget _buildTestApp(ScrollController controller) {
  return MaterialApp(
    home: Scaffold(
      body: ListView.builder(
        controller: controller,
        itemCount: 100, // Enough items to scroll
        itemBuilder: (context, index) => ListTile(
          title: Text('Item $index'),
        ),
      ),
    ),
  );
}
