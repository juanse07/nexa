import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:nexa/core/constants/error_messages.dart';
import 'package:nexa/core/errors/error_handler.dart';
import 'package:nexa/core/errors/exceptions.dart';
import 'package:nexa/core/errors/failures.dart';
import 'package:nexa/shared/presentation/theme/app_colors.dart';

/// Message severity levels for consistent styling
enum MessageSeverity {
  success,
  error,
  warning,
  info,
}

/// Centralized error and message display service
///
/// Provides consistent SnackBar styling and display logic across the app.
/// Handles success messages, errors, warnings, and info notifications.
class ErrorDisplayService {
  ErrorDisplayService._();

  /// Display a success message with green styling
  ///
  /// Use for confirmations like "Shift saved", "Event created", etc.
  static void showSuccess(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 2),
  }) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.success, // Green
        duration: duration,
      ),
    );
  }

  /// Display an error message with red styling
  ///
  /// Use for failures like "Failed to save", "Network error", etc.
  static void showError(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 4),
  }) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: duration,
      ),
    );
  }

  /// Display a warning message with orange styling
  ///
  /// Use for warnings like "File too large", "Limited features", etc.
  static void showWarning(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.orange[700],
        duration: duration,
      ),
    );
  }

  /// Display an info message with blue styling
  ///
  /// Use for informational messages like "Loading...", "Processing...", etc.
  static void showInfo(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 2),
  }) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.blue[700],
        duration: duration,
      ),
    );
  }

  /// Display an error from an exception
  ///
  /// Automatically formats the error message and handles common cases.
  static void showErrorFromException(
    BuildContext context,
    dynamic error, {
    String? prefix,
    Duration duration = const Duration(seconds: 4),
  }) {
    if (!context.mounted) return;

    final String errorMessage = _formatException(error);
    final String fullMessage = prefix != null ? '$prefix: $errorMessage' : errorMessage;

    showError(context, fullMessage, duration: duration);
  }

  /// Show a custom styled message with full control
  static void showCustom(
    BuildContext context, {
    required String message,
    required Color backgroundColor,
    Color textColor = Colors.white,
    Duration duration = const Duration(seconds: 3),
    SnackBarAction? action,
  }) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(color: textColor),
        ),
        backgroundColor: backgroundColor,
        duration: duration,
        action: action,
      ),
    );
  }

  /// Show a message with retry action
  static void showErrorWithRetry(
    BuildContext context,
    String message,
    VoidCallback onRetry, {
    Duration duration = const Duration(seconds: 6),
  }) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: duration,
        action: SnackBarAction(
          label: 'Retry',
          textColor: Colors.white,
          onPressed: onRetry,
        ),
      ),
    );
  }

  /// Format common exceptions into user-friendly messages
  ///
  /// Priority order:
  /// 1. Typed exceptions (AppException, Failure, DioException)
  /// 2. String-based pattern matching for untyped exceptions
  /// 3. "Exception: <message>" extraction with JSON/HTTP stripping
  /// 4. Safe fallback — never returns raw strings
  static String _formatException(dynamic error) {
    if (error == null) return ErrorMessages.somethingWentWrong;

    // 1. Typed exceptions — extract the clean message
    if (error is AppException) {
      return error.message ?? ErrorMessages.somethingWentWrong;
    }
    if (error is Failure) {
      return error.message;
    }
    if (error is DioException) {
      return ErrorHandler.handleDioError(error).message;
    }

    // 2. String-based detection for untyped exceptions
    final s = error.toString();
    if (s.contains('SocketException') || s.contains('NetworkException')) {
      return ErrorMessages.noInternetConnection;
    }
    if (s.contains('TimeoutException')) {
      return ErrorMessages.connectionTimeout;
    }
    if (s.contains('FormatException')) {
      return ErrorMessages.invalidData;
    }

    // 3. Extract message from "Exception: <message>" pattern
    if (s.contains('Exception:')) {
      var msg = s.split('Exception:').last.trim();
      // Strip any JSON payloads leaked from HTTP responses
      msg = msg.replaceAll(RegExp(r'\{.*\}'), '').trim();
      // Strip HTTP status patterns like "(401)" or "HTTP 500:"
      msg = msg.replaceAll(RegExp(r'\(\d{3}\)'), '').trim();
      msg = msg.replaceAll(RegExp(r'HTTP \d{3}:?'), '').trim();
      if (msg.isNotEmpty && !msg.startsWith('{') && msg.length < 200) {
        return msg;
      }
    }

    // 4. Safe fallback — never return raw strings
    return ErrorMessages.somethingWentWrong;
  }

  /// Clear all currently displayed snackbars
  static void clearAll(BuildContext context) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
  }

  /// Show loading message that can be dismissed later
  ///
  /// Returns a function to dismiss the loading message.
  static VoidCallback showLoading(
    BuildContext context,
    String message,
  ) {
    if (!context.mounted) return () {};

    final controller = ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.blue[700],
        duration: const Duration(days: 1), // Effectively indefinite
      ),
    );

    return () => controller.close();
  }
}

/// Extension methods for easier access
extension ErrorDisplayExtension on BuildContext {
  /// Show success message
  void showSuccess(String message) {
    ErrorDisplayService.showSuccess(this, message);
  }

  /// Show error message
  void showError(String message) {
    ErrorDisplayService.showError(this, message);
  }

  /// Show warning message
  void showWarning(String message) {
    ErrorDisplayService.showWarning(this, message);
  }

  /// Show info message
  void showInfo(String message) {
    ErrorDisplayService.showInfo(this, message);
  }

  /// Show error from exception
  void showErrorFromException(dynamic error, {String? prefix}) {
    ErrorDisplayService.showErrorFromException(this, error, prefix: prefix);
  }
}
