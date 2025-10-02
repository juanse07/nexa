import 'package:intl/intl.dart';
import 'package:nexa/core/constants/app_constants.dart';

/// Formatting utilities for dates, currency, and other values
class Formatters {
  Formatters._();

  // Date Formatters

  /// Formats a DateTime to the default date format (yyyy-MM-dd)
  static String formatDate(DateTime date) {
    return DateFormat(AppConstants.defaultDateFormat).format(date);
  }

  /// Formats a DateTime to a display-friendly date format (MMM dd, yyyy)
  static String formatDisplayDate(DateTime date) {
    return DateFormat(AppConstants.displayDateFormat).format(date);
  }

  /// Formats a DateTime to a display-friendly date-time format
  static String formatDisplayDateTime(DateTime date) {
    return DateFormat(AppConstants.displayDateTimeFormat).format(date);
  }

  /// Formats a DateTime to API date format (yyyy-MM-dd)
  static String formatApiDate(DateTime date) {
    return DateFormat(AppConstants.apiDateFormat).format(date);
  }

  /// Formats a DateTime to API date-time format (ISO 8601)
  static String formatApiDateTime(DateTime date) {
    return DateFormat(AppConstants.apiDateTimeFormat).format(date.toUtc());
  }

  /// Formats a DateTime to a custom format
  static String formatCustomDate(DateTime date, String format) {
    return DateFormat(format).format(date);
  }

  /// Parses a date string to DateTime
  static DateTime? parseDate(String dateString, [String? format]) {
    try {
      if (format != null) {
        return DateFormat(format).parse(dateString);
      }
      return DateTime.parse(dateString);
    } catch (e) {
      return null;
    }
  }

  /// Formats a DateTime to relative time (e.g., "2 hours ago")
  static String formatRelativeTime(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 365) {
      final years = (difference.inDays / 365).floor();
      return '$years ${years == 1 ? 'year' : 'years'} ago';
    } else if (difference.inDays > 30) {
      final months = (difference.inDays / 30).floor();
      return '$months ${months == 1 ? 'month' : 'months'} ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} ${difference.inDays == 1 ? 'day' : 'days'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} ${difference.inMinutes == 1 ? 'minute' : 'minutes'} ago';
    } else {
      return 'Just now';
    }
  }

  // Currency Formatters

  /// Formats a number as currency (USD)
  static String formatCurrency(num amount, {String symbol = '\$'}) {
    final formatter = NumberFormat.currency(
      symbol: symbol,
      decimalDigits: 2,
    );
    return formatter.format(amount);
  }

  /// Formats a number as currency with a specific locale
  static String formatCurrencyWithLocale(
    num amount, {
    String locale = 'en_US',
    String symbol = '\$',
  }) {
    final formatter = NumberFormat.currency(
      locale: locale,
      symbol: symbol,
      decimalDigits: 2,
    );
    return formatter.format(amount);
  }

  /// Formats a number as compact currency (e.g., $1.2K, $3.4M)
  static String formatCompactCurrency(num amount, {String symbol = '\$'}) {
    final formatter = NumberFormat.compactCurrency(
      symbol: symbol,
      decimalDigits: 1,
    );
    return formatter.format(amount);
  }

  // Number Formatters

  /// Formats a number with thousand separators
  static String formatNumber(num number) {
    final formatter = NumberFormat('#,##0.##');
    return formatter.format(number);
  }

  /// Formats a number as a percentage
  static String formatPercentage(num value, {int decimals = 0}) {
    final formatter = NumberFormat.percentPattern()
      ..minimumFractionDigits = decimals
      ..maximumFractionDigits = decimals;
    return formatter.format(value);
  }

  /// Formats a number with a specific number of decimal places
  static String formatDecimal(num number, int decimals) {
    return number.toStringAsFixed(decimals);
  }

  // Phone Number Formatters

  /// Formats a phone number to (XXX) XXX-XXXX format
  static String formatPhoneNumber(String phone) {
    // Remove all non-digit characters
    final digits = phone.replaceAll(RegExp(r'\\D'), '');

    if (digits.length == 10) {
      return '(${digits.substring(0, 3)}) ${digits.substring(3, 6)}-${digits.substring(6)}';
    } else if (digits.length == 11 && digits.startsWith('1')) {
      return '+1 (${digits.substring(1, 4)}) ${digits.substring(4, 7)}-${digits.substring(7)}';
    }

    // Return original if format is not recognized
    return phone;
  }

  /// Formats a phone number to international format
  static String formatInternationalPhone(String phone, String countryCode) {
    final digits = phone.replaceAll(RegExp(r'\\D'), '');
    return '+$countryCode $digits';
  }

  // Text Formatters

  /// Capitalizes the first letter of a string
  static String capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }

  /// Capitalizes the first letter of each word
  static String capitalizeWords(String text) {
    if (text.isEmpty) return text;
    return text.split(' ').map(capitalize).join(' ');
  }

  /// Truncates text to a maximum length with ellipsis
  static String truncate(String text, int maxLength, {String ellipsis = '...'}) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength - ellipsis.length)}$ellipsis';
  }

  // File Size Formatters

  /// Formats file size in bytes to human-readable format
  static String formatFileSize(int bytes) {
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var size = bytes.toDouble();
    var suffixIndex = 0;

    while (size >= 1024 && suffixIndex < suffixes.length - 1) {
      size /= 1024;
      suffixIndex++;
    }

    return '${size.toStringAsFixed(2)} ${suffixes[suffixIndex]}';
  }

  // Duration Formatters

  /// Formats a Duration to HH:MM:SS format
  static String formatDuration(Duration duration) {
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');

    if (duration.inHours > 0) {
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  /// Formats seconds to a human-readable duration
  static String formatSeconds(int seconds) {
    if (seconds < 60) {
      return '$seconds ${seconds == 1 ? 'second' : 'seconds'}';
    } else if (seconds < 3600) {
      final minutes = (seconds / 60).floor();
      return '$minutes ${minutes == 1 ? 'minute' : 'minutes'}';
    } else {
      final hours = (seconds / 3600).floor();
      return '$hours ${hours == 1 ? 'hour' : 'hours'}';
    }
  }
}
