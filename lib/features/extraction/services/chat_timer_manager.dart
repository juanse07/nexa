import 'dart:async';

/// Timer type enumeration for type-safe timer management
enum ChatTimerType {
  confirmation, // Countdown timer for auto-save
  reset, // Delay before resetting UI state
  inactivity, // Timeout for inactive confirmation screens
  autoShow, // Delay before auto-showing hidden input
  autoScroll, // Periodic timer for scroll position tracking
}

/// Configuration for timer durations
class ChatTimerConfig {
  /// Duration for confirmation countdown (reduced from 90s to 30s)
  final Duration confirmationDuration;

  /// Duration for reset delay after save/discard
  final Duration resetDuration;

  /// Duration for inactivity timeout
  final Duration inactivityDuration;

  /// Duration before auto-showing hidden input
  final Duration autoShowDuration;

  /// Interval for scroll tracking
  final Duration autoScrollInterval;

  const ChatTimerConfig({
    this.confirmationDuration = const Duration(seconds: 30),
    this.resetDuration = const Duration(seconds: 5),
    this.inactivityDuration = const Duration(minutes: 2),
    this.autoShowDuration = const Duration(seconds: 15),
    this.autoScrollInterval = const Duration(milliseconds: 150),
  });

  /// Default configuration with optimized durations
  static const ChatTimerConfig defaultConfig = ChatTimerConfig();

  /// Legacy configuration (for backwards compatibility)
  static const ChatTimerConfig legacyConfig = ChatTimerConfig(
    confirmationDuration: Duration(seconds: 90),
  );
}

/// Centralized timer management for AI chat screen
///
/// Manages all timers in one place with:
/// - Automatic cleanup on disposal
/// - Type-safe timer identification
/// - Configurable durations
/// - Callback-based event handling
class ChatTimerManager {
  final ChatTimerConfig config;
  final Map<ChatTimerType, Timer> _timers = {};
  final Map<ChatTimerType, int> _tickCounts = {};

  ChatTimerManager({this.config = ChatTimerConfig.defaultConfig});

  /// Start the confirmation countdown timer
  ///
  /// Fires callback every second with remaining seconds.
  /// Auto-completes when countdown reaches zero.
  void startConfirmationTimer({
    required void Function(int secondsRemaining) onTick,
    required void Function() onComplete,
  }) {
    cancel(ChatTimerType.confirmation);

    int secondsRemaining = config.confirmationDuration.inSeconds;
    _tickCounts[ChatTimerType.confirmation] = secondsRemaining;

    _timers[ChatTimerType.confirmation] = Timer.periodic(
      const Duration(seconds: 1),
      (timer) {
        secondsRemaining--;
        _tickCounts[ChatTimerType.confirmation] = secondsRemaining;

        if (secondsRemaining <= 0) {
          timer.cancel();
          _timers.remove(ChatTimerType.confirmation);
          _tickCounts.remove(ChatTimerType.confirmation);
          onComplete();
        } else {
          onTick(secondsRemaining);
        }
      },
    );

    // Call immediately with initial value
    onTick(secondsRemaining);
  }

  /// Start the reset delay timer
  ///
  /// Fires callback once after configured delay.
  void startResetTimer({required void Function() onComplete}) {
    cancel(ChatTimerType.reset);

    _timers[ChatTimerType.reset] = Timer(
      config.resetDuration,
      () {
        _timers.remove(ChatTimerType.reset);
        onComplete();
      },
    );
  }

  /// Start the inactivity timeout timer
  ///
  /// Fires callback if no activity for configured duration.
  void startInactivityTimer({required void Function() onTimeout}) {
    cancel(ChatTimerType.inactivity);

    _timers[ChatTimerType.inactivity] = Timer(
      config.inactivityDuration,
      () {
        _timers.remove(ChatTimerType.inactivity);
        onTimeout();
      },
    );
  }

  /// Start the auto-show delay timer
  ///
  /// Fires callback after configured delay to show hidden input.
  void startAutoShowTimer({required void Function() onShow}) {
    cancel(ChatTimerType.autoShow);

    _timers[ChatTimerType.autoShow] = Timer(
      config.autoShowDuration,
      () {
        _timers.remove(ChatTimerType.autoShow);
        onShow();
      },
    );
  }

  /// Start the auto-scroll periodic timer
  ///
  /// Fires callback at regular intervals for scroll tracking.
  void startAutoScrollTimer({required void Function() onTick}) {
    cancel(ChatTimerType.autoScroll);

    _timers[ChatTimerType.autoScroll] = Timer.periodic(
      config.autoScrollInterval,
      (_) => onTick(),
    );
  }

  /// Cancel a specific timer
  ///
  /// Safe to call even if timer doesn't exist.
  void cancel(ChatTimerType type) {
    _timers[type]?.cancel();
    _timers.remove(type);
    _tickCounts.remove(type);
  }

  /// Cancel all timers
  ///
  /// Should be called during disposal to prevent memory leaks.
  void cancelAll() {
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
    _tickCounts.clear();
  }

  /// Check if a timer is currently running
  bool isActive(ChatTimerType type) {
    return _timers.containsKey(type);
  }

  /// Get the current tick count for a timer (if applicable)
  ///
  /// Returns null if timer doesn't track ticks or isn't running.
  int? getTickCount(ChatTimerType type) {
    return _tickCounts[type];
  }

  /// Restart an existing timer with the same callback
  ///
  /// Useful for resetting inactivity timers on user interaction.
  void restart(ChatTimerType type) {
    // This is a simplified restart - in production you'd need to store callbacks
    // For now, callers should cancel and start manually with their callbacks
    throw UnimplementedError(
      'Restart not implemented - use cancel() then start methods',
    );
  }

  /// Dispose of all resources
  ///
  /// Must be called when manager is no longer needed.
  void dispose() {
    cancelAll();
  }
}
