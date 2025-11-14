import 'dart:async';
import 'package:flutter/material.dart';

/// Configuration for scroll behavior thresholds
class ChatScrollConfig {
  /// Minimum scroll delta to trigger hide/show (in pixels)
  final double scrollDeltaThreshold;

  /// Scroll threshold for direction detection (in pixels)
  final double directionThreshold;

  /// Distance from bottom to consider "at bottom" (in pixels)
  final double bottomThreshold;

  /// Duration to wait before auto-showing hidden input
  final Duration autoShowDelay;

  /// Interval for auto-scroll tracking during animations
  final Duration autoScrollInterval;

  /// Number of auto-scroll iterations (for tracking growing text)
  final int autoScrollIterations;

  const ChatScrollConfig({
    this.scrollDeltaThreshold = 5.0,
    this.directionThreshold = 10.0,
    this.bottomThreshold = 100.0,
    this.autoShowDelay = const Duration(seconds: 15),
    this.autoScrollInterval = const Duration(milliseconds: 150),
    this.autoScrollIterations = 13, // ~2 seconds
  });

  /// Default configuration with optimized values
  static const ChatScrollConfig defaultConfig = ChatScrollConfig();
}

/// Delegate for handling chat screen scroll behavior
///
/// Manages:
/// - Auto-hide/show input based on scroll direction
/// - Auto-show timer after scroll ends
/// - Bottom detection
/// - Animated scroll-to-bottom for new messages
class ChatScrollBehavior {
  final ChatScrollConfig config;
  final ScrollController scrollController;

  /// Callback when input should be hidden
  final VoidCallback onHideInput;

  /// Callback when input should be shown
  final VoidCallback onShowInput;

  /// Callback to check if input is currently visible
  final bool Function() isInputVisible;

  /// Callback to check if widget is still mounted
  final bool Function() isMounted;

  Timer? _autoShowTimer;
  Timer? _autoScrollTimer;

  ChatScrollBehavior({
    required this.scrollController,
    required this.onHideInput,
    required this.onShowInput,
    required this.isInputVisible,
    required this.isMounted,
    this.config = ChatScrollConfig.defaultConfig,
  });

  /// Handle scroll notifications
  ///
  /// Returns true if notification was handled, false otherwise.
  /// Should be called from NotificationListener's onNotification callback.
  bool handleScrollNotification(ScrollNotification notification) {
    if (notification is ScrollStartNotification) {
      return _handleScrollStart();
    }

    if (notification is ScrollEndNotification) {
      return _handleScrollEnd();
    }

    if (notification is ScrollUpdateNotification) {
      return _handleScrollUpdate(notification);
    }

    return false;
  }

  /// Handle scroll start - cancel auto-show timer
  bool _handleScrollStart() {
    cancelAutoShowTimer();
    return false;
  }

  /// Handle scroll end - start auto-show timer and check if at bottom
  bool _handleScrollEnd() {
    // Start auto-show timer
    cancelAutoShowTimer();
    _autoShowTimer = Timer(config.autoShowDelay, () {
      if (!isInputVisible() && isMounted()) {
        onShowInput();
      }
    });

    // Check if at bottom and show input if needed
    if (_isAtBottom() && !isInputVisible()) {
      onShowInput();
    }

    return false;
  }

  /// Handle scroll update - show/hide input based on direction
  bool _handleScrollUpdate(ScrollUpdateNotification notification) {
    final scrollDelta = notification.scrollDelta ?? 0;

    // Skip if no actual movement
    if (scrollDelta.abs() < config.scrollDeltaThreshold) {
      return false;
    }

    // Always show input when at bottom
    if (_isAtBottom()) {
      if (!isInputVisible()) {
        onShowInput();
      }
      return false;
    }

    // Direction-based logic
    if (scrollDelta > config.directionThreshold && isInputVisible()) {
      // Scrolling down - hide input
      onHideInput();
    } else if (scrollDelta < -config.directionThreshold && !isInputVisible()) {
      // Scrolling up - show input
      onShowInput();
    }

    return false;
  }

  /// Check if scroll position is at bottom
  bool _isAtBottom() {
    if (!scrollController.hasClients) return false;

    return scrollController.position.pixels >=
        scrollController.position.maxScrollExtent - config.bottomThreshold;
  }

  /// Scroll to bottom of the list
  ///
  /// If [animated] is true, uses smooth scrolling and tracks growing text
  /// with periodic position updates.
  void scrollToBottom({bool animated = false}) {
    if (!scrollController.hasClients) return;

    if (animated) {
      _scrollToBottomAnimated();
    } else {
      _scrollToBottomImmediate();
    }
  }

  /// Immediate jump to bottom
  void _scrollToBottomImmediate() {
    if (scrollController.hasClients) {
      scrollController.jumpTo(scrollController.position.maxScrollExtent);
    }
  }

  /// Animated scroll to bottom with tracking for growing content
  void _scrollToBottomAnimated() {
    // Cancel any existing auto-scroll timer
    cancelAutoScrollTimer();

    // Scroll immediately to show the message
    Future.delayed(const Duration(milliseconds: 100), () {
      if (scrollController.hasClients) {
        scrollController.jumpTo(scrollController.position.maxScrollExtent);
      }
    });

    // Continuously scroll to track animated/growing text
    int scrollCount = 0;
    _autoScrollTimer = Timer.periodic(config.autoScrollInterval, (timer) {
      if (!isMounted() || !scrollController.hasClients) {
        timer.cancel();
        return;
      }

      // Scroll to bottom to follow the growing text
      scrollController.animateTo(
        scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
      );

      scrollCount++;
      // Stop after configured iterations
      if (scrollCount >= config.autoScrollIterations) {
        timer.cancel();
      }
    });
  }

  /// Cancel the auto-show timer
  void cancelAutoShowTimer() {
    _autoShowTimer?.cancel();
    _autoShowTimer = null;
  }

  /// Cancel the auto-scroll timer
  void cancelAutoScrollTimer() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
  }

  /// Cancel all timers
  void cancelAllTimers() {
    cancelAutoShowTimer();
    cancelAutoScrollTimer();
  }

  /// Dispose of all resources
  void dispose() {
    cancelAllTimers();
  }

  /// Check if user is scrolled to top
  bool isAtTop() {
    if (!scrollController.hasClients) return false;
    return scrollController.position.pixels <= config.bottomThreshold;
  }

  /// Get current scroll percentage (0.0 to 1.0)
  double get scrollPercentage {
    if (!scrollController.hasClients) return 0.0;

    final position = scrollController.position;
    if (position.maxScrollExtent == 0) return 1.0;

    return (position.pixels / position.maxScrollExtent).clamp(0.0, 1.0);
  }

  /// Check if there's content to scroll
  bool get hasScrollableContent {
    if (!scrollController.hasClients) return false;
    return scrollController.position.maxScrollExtent > 0;
  }
}
