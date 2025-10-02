import 'package:nexa/core/constants/app_constants.dart';

/// Extension methods for String
extension StringExtensions on String {
  /// Capitalizes the first letter of the string
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1).toLowerCase()}';
  }

  /// Capitalizes the first letter of each word
  String capitalizeWords() {
    if (isEmpty) return this;
    return split(' ').map((word) => word.capitalize()).join(' ');
  }

  /// Converts string to title case
  String toTitleCase() {
    return capitalizeWords();
  }

  /// Checks if the string is a valid email
  bool get isEmail {
    final emailRegex = RegExp(AppConstants.emailRegex);
    return emailRegex.hasMatch(this);
  }

  /// Checks if the string is a valid phone number
  bool get isPhone {
    final phoneRegex = RegExp(AppConstants.phoneRegex);
    return phoneRegex.hasMatch(this);
  }

  /// Checks if the string is a valid URL
  bool get isUrl {
    final urlRegex = RegExp(AppConstants.urlRegex);
    return urlRegex.hasMatch(this);
  }

  /// Checks if the string is numeric
  bool get isNumeric {
    return num.tryParse(this) != null;
  }

  /// Checks if the string is an integer
  bool get isInteger {
    return int.tryParse(this) != null;
  }

  /// Checks if the string is a valid double
  bool get isDouble {
    return double.tryParse(this) != null;
  }

  /// Checks if the string is alphabetic only
  bool get isAlphabetic {
    return RegExp('^[a-zA-Z]+\$').hasMatch(this);
  }

  /// Checks if the string is alphanumeric
  bool get isAlphanumeric {
    return RegExp('^[a-zA-Z0-9]+\$').hasMatch(this);
  }

  /// Removes all whitespace from the string
  String removeWhitespace() {
    return replaceAll(RegExp(r'\s+'), '');
  }

  /// Removes all non-digit characters from the string
  String removeNonDigits() {
    return replaceAll(RegExp(r'\D'), '');
  }

  /// Truncates the string to a maximum length with ellipsis
  String truncate(int maxLength, {String ellipsis = '...'}) {
    if (length <= maxLength) return this;
    return '${substring(0, maxLength - ellipsis.length)}$ellipsis';
  }

  /// Reverses the string
  String reverse() {
    return split('').reversed.join();
  }

  /// Checks if the string is null or empty
  bool get isNullOrEmpty {
    return trim().isEmpty;
  }

  /// Checks if the string is not null and not empty
  bool get isNotNullOrEmpty {
    return trim().isNotEmpty;
  }

  /// Counts the occurrences of a substring
  int count(String substring) {
    return substring.allMatches(this).length;
  }

  /// Checks if the string contains only digits
  bool get isDigitsOnly {
    return RegExp('^[0-9]+\$').hasMatch(this);
  }

  /// Converts string to int, returns null if conversion fails
  int? toIntOrNull() {
    return int.tryParse(this);
  }

  /// Converts string to double, returns null if conversion fails
  double? toDoubleOrNull() {
    return double.tryParse(this);
  }

  /// Converts string to DateTime, returns null if conversion fails
  DateTime? toDateTimeOrNull() {
    try {
      return DateTime.parse(this);
    } catch (e) {
      return null;
    }
  }

  /// Checks if the string matches a regex pattern
  bool matches(String pattern) {
    return RegExp(pattern).hasMatch(this);
  }

  /// Checks if the string starts with any of the given prefixes
  bool startsWithAny(List<String> prefixes) {
    return prefixes.any(startsWith);
  }

  /// Checks if the string ends with any of the given suffixes
  bool endsWithAny(List<String> suffixes) {
    return suffixes.any(endsWith);
  }

  /// Checks if the string contains any of the given substrings
  bool containsAny(List<String> substrings) {
    return substrings.any(contains);
  }

  /// Converts the first character to lowercase
  String decapitalize() {
    if (isEmpty) return this;
    return '${this[0].toLowerCase()}${substring(1)}';
  }

  /// Wraps the string at a specified width
  String wrap(int width) {
    if (length <= width) return this;
    final buffer = StringBuffer();
    var currentPos = 0;

    while (currentPos < length) {
      final endPos = (currentPos + width < length) ? currentPos + width : length;
      buffer.writeln(substring(currentPos, endPos));
      currentPos = endPos;
    }

    return buffer.toString().trimRight();
  }

  /// Converts string to snake_case
  String toSnakeCase() {
    return replaceAllMapped(
      RegExp(r'[A-Z]'),
      (match) => '_${match.group(0)!.toLowerCase()}',
    ).replaceFirst(RegExp(r'^_'), '');
  }

  /// Converts string to camelCase
  String toCamelCase() {
    final words = split(RegExp(r'[\s_-]+'));
    if (words.isEmpty) return this;

    return words.first.toLowerCase() +
        words
            .skip(1)
            .map((word) => word.capitalize())
            .join();
  }

  /// Converts string to PascalCase
  String toPascalCase() {
    return split(RegExp(r'[\s_-]+'))
        .map((word) => word.capitalize())
        .join();
  }

  /// Converts string to kebab-case
  String toKebabCase() {
    return replaceAllMapped(
      RegExp(r'[A-Z]'),
      (match) => '-${match.group(0)!.toLowerCase()}',
    )
        .replaceFirst(RegExp(r'^-'), '')
        .replaceAll(RegExp(r'[\s_]+'), '-')
        .toLowerCase();
  }

  /// Converts string to CONSTANT_CASE
  String toConstantCase() {
    return toSnakeCase().toUpperCase();
  }
}
