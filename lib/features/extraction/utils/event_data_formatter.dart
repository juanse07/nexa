/// Event Data Formatting Utility
///
/// Centralizes all event data formatting logic to avoid duplication
/// and improve maintainability. Handles date/time formatting, event
/// summaries, and extracted data presentation.
class EventDataFormatter {
  EventDataFormatter._();

  // Field mapping for extracted data formatting
  static const Map<String, String> _extractedDataFields = {
    'event_name': 'Event',
    'client_name': 'Client',
    'date': 'Date',
    'venue': 'Venue',
    'location': 'Location',
    'call_time': 'Call Time',
    'setup_time': 'Setup Time',
    'headcount': 'Headcount',
    'attire': 'Attire',
  };

  // Month names for date formatting
  static const List<String> _monthNames = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  /// Formats extracted data from image/PDF/text into readable string
  ///
  /// Takes a map of extracted data and returns a formatted multi-line string
  /// with field labels. Handles optional role information.
  static String formatExtractedData(Map<String, dynamic> data) {
    final buffer = StringBuffer();

    // Format standard fields using field mapping
    for (final entry in _extractedDataFields.entries) {
      final value = data[entry.key];
      if (value != null && value.toString().isNotEmpty) {
        buffer.writeln('${entry.value}: $value');
      }
    }

    // Format roles section if present
    final roles = data['roles'];
    if (roles != null && roles is List && roles.isNotEmpty) {
      buffer.writeln('\nStaff Roles:');
      for (final role in roles) {
        if (role is Map) {
          final roleName = role['role_name'] ?? role['role'] ?? '';
          final count = role['count'] ?? role['quantity'] ?? '';
          if (roleName.toString().isNotEmpty) {
            buffer.writeln(
                '- $roleName${count.toString().isNotEmpty ? ' ($count)' : ''}');
          }
        }
      }
    }

    return buffer.toString().trim();
  }

  /// Builds a formatted event summary with emojis and structured layout
  ///
  /// Creates a user-friendly summary of event data including:
  /// - Event name and date
  /// - Client information
  /// - Staff roles needed with call times
  /// - Venue details
  /// - Event timing
  static String buildEventSummary(Map<String, dynamic> eventData) {
    final buffer = StringBuffer();

    buffer.writeln('✅ Event Created!\n');

    // Event name
    final eventName = eventData['event_name'] ?? 'Unnamed Event';
    buffer.writeln('📋 $eventName');

    // Date
    final date = eventData['date'];
    if (date != null) {
      final formattedDate = formatDate(date.toString());
      buffer.writeln('📅 $formattedDate');
    }

    // Client
    final client = eventData['client_name'];
    if (client != null) {
      buffer.writeln('🏢 $client');
    }

    // Roles
    final roles = eventData['roles'];
    if (roles is List && roles.isNotEmpty) {
      buffer.writeln('\n👥 Staff Needed:');
      for (final role in roles) {
        if (role is! Map) continue;
        final roleName = role['role']?.toString() ?? 'Staff';
        final count = role['count'] as int? ?? 0;
        final callTime = role['call_time'];
        final timeStr =
            callTime != null ? ' (arrive at ${formatTime(callTime.toString())})' : '';
        buffer.writeln(
            '  • $count ${_capitalize(roleName)}${count > 1 ? 's' : ''}$timeStr');
      }
    }

    // Venue
    final venueName = eventData['venue_name'];
    final venueAddress = eventData['venue_address'];
    if (venueName != null || venueAddress != null) {
      buffer.writeln('\n📍 Venue:');
      if (venueName != null) {
        buffer.writeln('   $venueName');
      }
      if (venueAddress != null) {
        buffer.writeln('   $venueAddress');
      }
    }

    // Event times (if provided)
    final startTime = eventData['start_time'];
    final endTime = eventData['end_time'];
    if (startTime != null || endTime != null) {
      buffer.write('\n⏰ Event Time: ');
      if (startTime != null) {
        buffer.write(formatTime(startTime.toString()));
      }
      if (endTime != null) {
        buffer.write(' - ${formatTime(endTime.toString())}');
      }
      buffer.writeln();
    }

    buffer.writeln('\nSaved to Pending - ready to publish!');
    buffer.writeln('\n[LINK:Check Pending]');

    return buffer.toString();
  }

  /// Formats ISO date string to human-readable format
  ///
  /// Converts ISO 8601 date (e.g., "2025-01-15") to readable format
  /// (e.g., "January 15, 2025"). Returns original string if parsing fails.
  static String formatDate(String isoDate) {
    try {
      final date = DateTime.parse(isoDate);
      return '${_monthNames[date.month - 1]} ${date.day}, ${date.year}';
    } catch (_) {
      return isoDate; // Return original if parsing fails
    }
  }

  /// Formats 24-hour time to 12-hour format with AM/PM
  ///
  /// Converts 24-hour time (e.g., "14:30") to 12-hour format with period
  /// (e.g., "2:30 PM"). Returns original string if parsing fails.
  static String formatTime(String time24) {
    try {
      final parts = time24.split(':');
      if (parts.isEmpty) return time24;

      final hour = int.parse(parts[0]);
      final minute = parts.length > 1 ? parts[1] : '00';
      final period = hour >= 12 ? 'PM' : 'AM';
      final hour12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);

      return '$hour12:$minute $period';
    } catch (_) {
      return time24; // Return original if parsing fails
    }
  }

  /// Capitalizes the first letter of a string
  ///
  /// Helper method for formatting role names and other text.
  /// Returns empty string if input is empty.
  static String _capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

  /// Formats a duration in seconds to MM:SS format
  ///
  /// Useful for displaying countdown timers or duration values.
  static String formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  /// Formats a list of strings into a comma-separated string
  ///
  /// Useful for displaying multiple values (e.g., attire options).
  /// Returns empty string if list is null or empty.
  static String formatList(List<dynamic>? items, {String separator = ', '}) {
    if (items == null || items.isEmpty) return '';
    return items.map((e) => e.toString()).join(separator);
  }
}
