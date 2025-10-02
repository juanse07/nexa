import 'package:intl/intl.dart';
import 'package:nexa/core/constants/app_constants.dart';

/// Extension methods for DateTime
extension DateExtensions on DateTime {
  /// Formats the DateTime to default date format (yyyy-MM-dd)
  String toFormattedString() {
    return DateFormat(AppConstants.defaultDateFormat).format(this);
  }

  /// Formats the DateTime to display date format (MMM dd, yyyy)
  String toDisplayDate() {
    return DateFormat(AppConstants.displayDateFormat).format(this);
  }

  /// Formats the DateTime to display date-time format
  String toDisplayDateTime() {
    return DateFormat(AppConstants.displayDateTimeFormat).format(this);
  }

  /// Formats the DateTime to API date format
  String toApiDate() {
    return DateFormat(AppConstants.apiDateFormat).format(this);
  }

  /// Formats the DateTime to API date-time format (ISO 8601)
  String toApiDateTime() {
    return DateFormat(AppConstants.apiDateTimeFormat).format(toUtc());
  }

  /// Formats the DateTime to a custom format
  String toCustomFormat(String format) {
    return DateFormat(format).format(this);
  }

  /// Checks if the date is today
  bool get isToday {
    final now = DateTime.now();
    return year == now.year && month == now.month && day == now.day;
  }

  /// Checks if the date is yesterday
  bool get isYesterday {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return year == yesterday.year &&
        month == yesterday.month &&
        day == yesterday.day;
  }

  /// Checks if the date is tomorrow
  bool get isTomorrow {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    return year == tomorrow.year &&
        month == tomorrow.month &&
        day == tomorrow.day;
  }

  /// Checks if the date is in the current week
  bool get isThisWeek {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 6));
    return isAfter(weekStart.subtract(const Duration(days: 1))) &&
        isBefore(weekEnd.add(const Duration(days: 1)));
  }

  /// Checks if the date is in the current month
  bool get isThisMonth {
    final now = DateTime.now();
    return year == now.year && month == now.month;
  }

  /// Checks if the date is in the current year
  bool get isThisYear {
    final now = DateTime.now();
    return year == now.year;
  }

  /// Checks if the date is in the past
  bool get isPast {
    return isBefore(DateTime.now());
  }

  /// Checks if the date is in the future
  bool get isFuture {
    return isAfter(DateTime.now());
  }

  /// Checks if the date is a weekend (Saturday or Sunday)
  bool get isWeekend {
    return weekday == DateTime.saturday || weekday == DateTime.sunday;
  }

  /// Checks if the date is a weekday (Monday to Friday)
  bool get isWeekday {
    return !isWeekend;
  }

  /// Gets the start of the day (00:00:00)
  DateTime get startOfDay {
    return DateTime(year, month, day);
  }

  /// Gets the end of the day (23:59:59.999)
  DateTime get endOfDay {
    return DateTime(year, month, day, 23, 59, 59, 999);
  }

  /// Gets the start of the week (Monday 00:00:00)
  DateTime get startOfWeek {
    final monday = subtract(Duration(days: weekday - 1));
    return monday.startOfDay;
  }

  /// Gets the end of the week (Sunday 23:59:59.999)
  DateTime get endOfWeek {
    final sunday = add(Duration(days: DateTime.daysPerWeek - weekday));
    return sunday.endOfDay;
  }

  /// Gets the start of the month
  DateTime get startOfMonth {
    return DateTime(year, month);
  }

  /// Gets the end of the month
  DateTime get endOfMonth {
    return DateTime(year, month + 1, 0, 23, 59, 59, 999);
  }

  /// Gets the start of the year
  DateTime get startOfYear {
    return DateTime(year);
  }

  /// Gets the end of the year
  DateTime get endOfYear {
    return DateTime(year, 12, 31, 23, 59, 59, 999);
  }

  /// Adds a specified number of days
  DateTime addDays(int days) {
    return add(Duration(days: days));
  }

  /// Subtracts a specified number of days
  DateTime subtractDays(int days) {
    return subtract(Duration(days: days));
  }

  /// Adds a specified number of months
  DateTime addMonths(int months) {
    return DateTime(year, month + months, day, hour, minute, second);
  }

  /// Subtracts a specified number of months
  DateTime subtractMonths(int months) {
    return DateTime(year, month - months, day, hour, minute, second);
  }

  /// Adds a specified number of years
  DateTime addYears(int years) {
    return DateTime(year + years, month, day, hour, minute, second);
  }

  /// Subtracts a specified number of years
  DateTime subtractYears(int years) {
    return DateTime(year - years, month, day, hour, minute, second);
  }

  /// Gets the number of days in the month
  int get daysInMonth {
    return DateTime(year, month + 1, 0).day;
  }

  /// Formats the date as relative time (e.g., "2 hours ago")
  String toRelativeTime() {
    final now = DateTime.now();
    final difference = now.difference(this);

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

  /// Gets a friendly date string (Today, Yesterday, or formatted date)
  String toFriendlyString() {
    if (isToday) return 'Today';
    if (isYesterday) return 'Yesterday';
    if (isTomorrow) return 'Tomorrow';
    return toDisplayDate();
  }

  /// Checks if this date is the same day as another date
  bool isSameDay(DateTime other) {
    return year == other.year && month == other.month && day == other.day;
  }

  /// Checks if this date is between two other dates (inclusive)
  bool isBetween(DateTime start, DateTime end) {
    return (isAfter(start) || isSameDay(start)) &&
        (isBefore(end) || isSameDay(end));
  }

  /// Gets the age in years from this date to now
  int get age {
    final now = DateTime.now();
    var age = now.year - year;
    if (now.month < month || (now.month == month && now.day < day)) {
      age--;
    }
    return age;
  }

  /// Gets the quarter of the year (1-4)
  int get quarter {
    return ((month - 1) ~/ 3) + 1;
  }

  /// Gets the week number of the year
  int get weekOfYear {
    final firstDayOfYear = DateTime(year, 1, 1);
    final daysSinceFirstDay = difference(firstDayOfYear).inDays;
    return ((daysSinceFirstDay + firstDayOfYear.weekday) / 7).ceil();
  }

  /// Copies the date with optional parameter overrides
  DateTime copyWith({
    int? year,
    int? month,
    int? day,
    int? hour,
    int? minute,
    int? second,
    int? millisecond,
  }) {
    return DateTime(
      year ?? this.year,
      month ?? this.month,
      day ?? this.day,
      hour ?? this.hour,
      minute ?? this.minute,
      second ?? this.second,
      millisecond ?? this.millisecond,
    );
  }
}
