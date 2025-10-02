import 'package:flutter/material.dart';

/// Extension methods for BuildContext
extension ContextExtensions on BuildContext {
  // Theme accessors

  /// Gets the current theme
  ThemeData get theme => Theme.of(this);

  /// Gets the current text theme
  TextTheme get textTheme => theme.textTheme;

  /// Gets the current color scheme
  ColorScheme get colorScheme => theme.colorScheme;

  /// Gets the primary color
  Color get primaryColor => colorScheme.primary;

  /// Gets the secondary color
  Color get secondaryColor => colorScheme.secondary;

  /// Gets the background color
  Color get backgroundColor => colorScheme.surface;

  /// Gets the error color
  Color get errorColor => colorScheme.error;

  /// Checks if dark mode is enabled
  bool get isDarkMode => theme.brightness == Brightness.dark;

  // Media Query accessors

  /// Gets the media query data
  MediaQueryData get mediaQuery => MediaQuery.of(this);

  /// Gets the screen size
  Size get screenSize => mediaQuery.size;

  /// Gets the screen width
  double get screenWidth => screenSize.width;

  /// Gets the screen height
  double get screenHeight => screenSize.height;

  /// Gets the screen orientation
  Orientation get orientation => mediaQuery.orientation;

  /// Checks if the device is in portrait mode
  bool get isPortrait => orientation == Orientation.portrait;

  /// Checks if the device is in landscape mode
  bool get isLandscape => orientation == Orientation.landscape;

  /// Gets the device pixel ratio
  double get devicePixelRatio => mediaQuery.devicePixelRatio;

  /// Gets the text scale factor
  double get textScaleFactor => mediaQuery.textScaler.scale(1);

  /// Gets the padding (includes status bar, notches, etc.)
  EdgeInsets get padding => mediaQuery.padding;

  /// Gets the view insets (keyboard, etc.)
  EdgeInsets get viewInsets => mediaQuery.viewInsets;

  /// Gets the view padding
  EdgeInsets get viewPadding => mediaQuery.viewPadding;

  /// Checks if the keyboard is visible
  bool get isKeyboardVisible => viewInsets.bottom > 0;

  // Responsive helpers

  /// Checks if the screen is small (width < 600)
  bool get isSmallScreen => screenWidth < 600;

  /// Checks if the screen is medium (600 <= width < 1024)
  bool get isMediumScreen => screenWidth >= 600 && screenWidth < 1024;

  /// Checks if the screen is large (width >= 1024)
  bool get isLargeScreen => screenWidth >= 1024;

  /// Gets a responsive value based on screen size
  T responsive<T>({
    required T mobile,
    T? tablet,
    T? desktop,
  }) {
    if (isLargeScreen && desktop != null) {
      return desktop;
    } else if (isMediumScreen && tablet != null) {
      return tablet;
    } else {
      return mobile;
    }
  }

  // Navigation helpers

  /// Pushes a new route onto the navigator
  Future<T?> push<T>(Widget page) {
    return Navigator.of(this).push<T>(
      MaterialPageRoute(builder: (_) => page),
    );
  }

  /// Pushes a named route onto the navigator
  Future<T?> pushNamed<T>(String routeName, {Object? arguments}) {
    return Navigator.of(this).pushNamed<T>(routeName, arguments: arguments);
  }

  /// Replaces the current route with a new one
  Future<T?> pushReplacement<T, TO extends Object?>(Widget page, {TO? result}) {
    return Navigator.of(this).pushReplacement<T, TO>(
      MaterialPageRoute(builder: (_) => page),
      result: result,
    );
  }

  /// Replaces the current route with a named route
  Future<T?> pushReplacementNamed<T, TO extends Object?>(
    String routeName, {
    Object? arguments,
    TO? result,
  }) {
    return Navigator.of(this).pushReplacementNamed<T, TO>(
      routeName,
      arguments: arguments,
      result: result,
    );
  }

  /// Removes all routes and pushes a new one
  Future<T?> pushAndRemoveUntil<T>(
    Widget page,
    bool Function(Route<dynamic>) predicate,
  ) {
    return Navigator.of(this).pushAndRemoveUntil<T>(
      MaterialPageRoute(builder: (_) => page),
      predicate,
    );
  }

  /// Removes all routes and pushes a named route
  Future<T?> pushNamedAndRemoveUntil<T>(
    String routeName,
    bool Function(Route<dynamic>) predicate, {
    Object? arguments,
  }) {
    return Navigator.of(this).pushNamedAndRemoveUntil<T>(
      routeName,
      predicate,
      arguments: arguments,
    );
  }

  /// Pops the current route
  void pop<T>([T? result]) {
    Navigator.of(this).pop<T>(result);
  }

  /// Pops until a predicate is satisfied
  void popUntil(bool Function(Route<dynamic>) predicate) {
    Navigator.of(this).popUntil(predicate);
  }

  /// Checks if the navigator can pop
  bool get canPop => Navigator.of(this).canPop();

  // Snackbar helpers

  /// Shows a snackbar with a message
  void showSnackBar(
    String message, {
    Duration duration = const Duration(seconds: 3),
    SnackBarAction? action,
  }) {
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: duration,
        action: action,
      ),
    );
  }

  /// Shows an error snackbar
  void showErrorSnackBar(
    String message, {
    Duration duration = const Duration(seconds: 4),
  }) {
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: duration,
        backgroundColor: colorScheme.error,
      ),
    );
  }

  /// Shows a success snackbar
  void showSuccessSnackBar(
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: duration,
        backgroundColor: Colors.green,
      ),
    );
  }

  /// Hides the current snackbar
  void hideSnackBar() {
    ScaffoldMessenger.of(this).hideCurrentSnackBar();
  }

  // Dialog helpers

  /// Shows a dialog
  Future<T?> showDialogWidget<T>(Widget dialog) {
    return showDialog<T>(
      context: this,
      builder: (_) => dialog,
    );
  }

  /// Shows an error dialog
  Future<void> showErrorDialog(
    String title,
    String message, {
    String buttonText = 'OK',
  }) {
    return showDialog(
      context: this,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(this).pop(),
            child: Text(buttonText),
          ),
        ],
      ),
    );
  }

  /// Shows a confirmation dialog
  Future<bool?> showConfirmDialog(
    String title,
    String message, {
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
  }) {
    return showDialog<bool>(
      context: this,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(this).pop(false),
            child: Text(cancelText),
          ),
          TextButton(
            onPressed: () => Navigator.of(this).pop(true),
            child: Text(confirmText),
          ),
        ],
      ),
    );
  }

  // Bottom sheet helpers

  /// Shows a modal bottom sheet
  Future<T?> showBottomSheetWidget<T>(Widget content) {
    return showModalBottomSheet<T>(
      context: this,
      builder: (_) => content,
    );
  }

  // Focus helpers

  /// Unfocuses the current focus node (hides keyboard)
  void unfocus() {
    FocusScope.of(this).unfocus();
  }

  /// Requests focus on a specific node
  void requestFocus(FocusNode node) {
    FocusScope.of(this).requestFocus(node);
  }

  // Loading indicator helpers

  /// Shows a loading dialog
  void showLoading({String? message}) {
    showDialog<void>(
      context: this,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: Dialog(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                if (message != null) ...[
                  const SizedBox(width: 20),
                  Text(message),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Hides the loading dialog
  void hideLoading() {
    if (canPop) {
      pop<void>();
    }
  }
}
