import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:nexa/shared/services/error_display_service.dart';

/// Types of route errors that can occur during navigation
enum RouteErrorType {
  /// Route/page not found
  notFound,

  /// User not authenticated (401)
  unauthorized,

  /// User not authorized for this route (403)
  forbidden,

  /// Missing or invalid route parameters
  invalidParams,

  /// General navigation failure
  navigationFailed,

  /// Widget build error during navigation
  buildError,
}

/// Centralized route error management for consistent navigation error handling.
///
/// Provides safe navigation methods that wrap Navigator calls with try-catch,
/// log errors to console for debugging, and show user-friendly snackbar messages.
///
/// Usage:
/// ```dart
/// await RouteErrorManager.instance.navigateSafely(
///   context,
///   () => EventDetailScreen(eventId: eventId),
/// );
/// ```
class RouteErrorManager {
  RouteErrorManager._();

  /// Singleton instance
  static final RouteErrorManager instance = RouteErrorManager._();

  /// Navigate to a widget with automatic error handling.
  ///
  /// On error: logs details to console, shows snackbar, and stays on current screen.
  ///
  /// [builder] - Lazy widget builder (catches construction errors)
  /// [replace] - If true, replaces current route instead of pushing
  /// [clearStack] - If true, clears navigation stack before navigating
  Future<T?> navigateSafely<T>(
    BuildContext context,
    Widget Function() builder, {
    bool replace = false,
    bool clearStack = false,
  }) async {
    if (!context.mounted) return null;

    try {
      // Build widget first to catch construction errors
      final Widget destination = builder();

      final route = MaterialPageRoute<T>(
        builder: (_) => destination,
      );

      if (!context.mounted) return null;

      if (clearStack) {
        return await Navigator.of(context).pushAndRemoveUntil<T>(
          route,
          (route) => false,
        );
      } else if (replace) {
        return await Navigator.of(context).pushReplacement<T, void>(route);
      } else {
        return await Navigator.of(context).push<T>(route);
      }
    } catch (error, stackTrace) {
      _handleNavigationError(
        context,
        RouteErrorType.buildError,
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  /// Navigate to a widget with a custom page route builder.
  ///
  /// Useful for custom transitions like fade, slide, etc.
  Future<T?> navigateWithRouteSafely<T>(
    BuildContext context,
    Route<T> Function() routeBuilder,
  ) async {
    if (!context.mounted) return null;

    try {
      final route = routeBuilder();

      if (!context.mounted) return null;

      return await Navigator.of(context).push<T>(route);
    } catch (error, stackTrace) {
      _handleNavigationError(
        context,
        RouteErrorType.navigationFailed,
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  /// Push a named route with automatic error handling.
  ///
  /// Note: Named routes must be defined in MaterialApp routes map.
  Future<T?> pushNamedSafely<T>(
    BuildContext context,
    String routeName, {
    Object? arguments,
  }) async {
    if (!context.mounted) return null;

    try {
      return await Navigator.of(context).pushNamed<T>(
        routeName,
        arguments: arguments,
      );
    } catch (error, stackTrace) {
      _handleNavigationError(
        context,
        RouteErrorType.notFound,
        routeName: routeName,
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  /// Push a named route and remove all previous routes.
  Future<T?> pushNamedAndRemoveAllSafely<T>(
    BuildContext context,
    String routeName, {
    Object? arguments,
  }) async {
    if (!context.mounted) return null;

    try {
      return await Navigator.of(context).pushNamedAndRemoveUntil<T>(
        routeName,
        (route) => false,
        arguments: arguments,
      );
    } catch (error, stackTrace) {
      _handleNavigationError(
        context,
        RouteErrorType.notFound,
        routeName: routeName,
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  /// Pop the current route safely.
  ///
  /// Returns false if cannot pop (e.g., already at root).
  bool popSafely<T>(BuildContext context, [T? result]) {
    if (!context.mounted) return false;

    try {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop<T>(result);
        return true;
      }
      return false;
    } catch (error, stackTrace) {
      _logError(
        RouteErrorType.navigationFailed,
        error: error,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  /// Handle a route error manually.
  ///
  /// Use this when you catch a navigation-related error in your own code
  /// and want consistent error handling.
  void handleError(
    BuildContext context,
    RouteErrorType type, {
    String? routeName,
    Object? error,
    StackTrace? stackTrace,
  }) {
    _handleNavigationError(
      context,
      type,
      routeName: routeName,
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// Get user-friendly message for an error type.
  String getErrorMessage(RouteErrorType type) {
    switch (type) {
      case RouteErrorType.notFound:
        return 'Page not found';
      case RouteErrorType.unauthorized:
        return 'Please log in to continue';
      case RouteErrorType.forbidden:
        return "You don't have access to this page";
      case RouteErrorType.invalidParams:
        return 'Something went wrong. Please try again.';
      case RouteErrorType.navigationFailed:
        return 'Unable to open page. Please try again.';
      case RouteErrorType.buildError:
        return 'Something went wrong loading this page.';
    }
  }

  /// Internal handler for navigation errors.
  void _handleNavigationError(
    BuildContext context,
    RouteErrorType type, {
    String? routeName,
    Object? error,
    StackTrace? stackTrace,
  }) {
    // Log to console for debugging
    _logError(type, routeName: routeName, error: error, stackTrace: stackTrace);

    // Show user-friendly snackbar
    if (context.mounted) {
      ErrorDisplayService.showError(context, getErrorMessage(type));
    }
  }

  /// Log error details to console.
  void _logError(
    RouteErrorType type, {
    String? routeName,
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (kDebugMode) {
      debugPrint('═══════════════════════════════════════════════════════════');
      debugPrint('[RouteError] TYPE: ${type.name}');
      if (routeName != null) {
        debugPrint('[RouteError] Route: $routeName');
      }
      if (error != null) {
        debugPrint('[RouteError] Error: $error');
      }
      if (stackTrace != null) {
        debugPrint('[RouteError] StackTrace:');
        debugPrint(stackTrace.toString());
      }
      debugPrint('═══════════════════════════════════════════════════════════');
    }
  }
}
