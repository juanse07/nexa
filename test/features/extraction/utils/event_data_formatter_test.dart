import 'package:flutter_test/flutter_test.dart';
import 'package:nexa/features/extraction/utils/event_data_formatter.dart';

void main() {
  group('EventDataFormatter', () {
    group('formatExtractedData', () {
      test('formats event data with standard fields', () {
        final data = {
          'event_name': 'Tech Conference',
          'client_name': 'Acme Corp',
          'date': '2025-01-15',
          'venue': 'Convention Center',
          'location': 'San Francisco, CA',
          'call_time': '14:00',
          'setup_time': '13:00',
          'headcount': 150,
          'attire': 'Business casual',
        };

        final result = EventDataFormatter.formatExtractedData(data);

        expect(result, contains('Event: Tech Conference'));
        expect(result, contains('Client: Acme Corp'));
        expect(result, contains('Date: 2025-01-15'));
        expect(result, contains('Venue: Convention Center'));
        expect(result, contains('Location: San Francisco, CA'));
        expect(result, contains('Call Time: 14:00'));
        expect(result, contains('Setup Time: 13:00'));
        expect(result, contains('Headcount: 150'));
        expect(result, contains('Attire: Business casual'));
      });

      test('formats minimal event data with only some fields', () {
        final data = {
          'client_name': 'Simple Event Co',
          'date': '2025-02-20',
        };

        final result = EventDataFormatter.formatExtractedData(data);

        expect(result, contains('Client: Simple Event Co'));
        expect(result, contains('Date: 2025-02-20'));
        expect(result, isNot(contains('Event:')));
        expect(result, isNot(contains('Venue:')));
      });

      test('handles empty data map', () {
        final result = EventDataFormatter.formatExtractedData({});
        expect(result.trim(), isEmpty);
      });

      test('skips null and empty values', () {
        final data = {
          'event_name': 'Test Event',
          'client_name': null,
          'date': '',
          'venue': 'Test Venue',
        };

        final result = EventDataFormatter.formatExtractedData(data);

        expect(result, contains('Event: Test Event'));
        expect(result, contains('Venue: Test Venue'));
        expect(result, isNot(contains('Client:')));
        expect(result, isNot(contains('Date:')));
      });

      test('formats roles when present', () {
        final data = {
          'roles': [
            {'role': 'Chef', 'count': 3},
            {'role': 'Server', 'count': 5},
          ],
        };

        final result = EventDataFormatter.formatExtractedData(data);

        expect(result, contains('Roles'));
        // The implementation should format roles somehow
      });
    });

    group('buildEventSummary', () {
      test('builds complete event summary', () {
        final eventData = {
          'event_name': 'Wedding Reception',
          'client_name': 'Smith Family',
          'date': '2025-06-15',
          'start_time': '18:00',
          'end_time': '23:00',
          'venue_name': 'Grand Ballroom',
          'venue_address': '123 Oak St',
          'city': 'Portland',
          'headcount_total': 200,
        };

        final result = EventDataFormatter.buildEventSummary(eventData);

        // Summary should include key information
        expect(result.isNotEmpty, true);
      });

      test('handles minimal event data', () {
        final eventData = {
          'client_name': 'Basic Event',
          'date': '2025-03-10',
        };

        final result = EventDataFormatter.buildEventSummary(eventData);

        expect(result.isNotEmpty, true);
      });

      test('handles empty event data', () {
        final result = EventDataFormatter.buildEventSummary({});
        expect(result.isNotEmpty, true); // Should return some default summary
      });
    });

    group('formatDate', () {
      test('formats ISO date to readable format', () {
        expect(EventDataFormatter.formatDate('2025-01-15'), 'January 15, 2025');
        expect(EventDataFormatter.formatDate('2025-12-31'), 'December 31, 2025');
        expect(EventDataFormatter.formatDate('2025-07-04'), 'July 4, 2025');
      });

      test('handles invalid date formats gracefully', () {
        final result = EventDataFormatter.formatDate('invalid-date');
        // Should return the input unchanged
        expect(result, 'invalid-date');
      });

      test('preserves single-digit days', () {
        expect(EventDataFormatter.formatDate('2025-03-05'), 'March 5, 2025');
        expect(EventDataFormatter.formatDate('2025-11-01'), 'November 1, 2025');
      });

      test('handles different year values', () {
        expect(EventDataFormatter.formatDate('2024-06-20'), 'June 20, 2024');
        expect(EventDataFormatter.formatDate('2026-09-12'), 'September 12, 2026');
      });

      test('handles empty string', () {
        expect(EventDataFormatter.formatDate(''), '');
      });
    });

    group('formatTime', () {
      test('converts 24-hour time to 12-hour with AM/PM', () {
        expect(EventDataFormatter.formatTime('00:00'), '12:00 AM');
        expect(EventDataFormatter.formatTime('01:30'), '1:30 AM');
        expect(EventDataFormatter.formatTime('12:00'), '12:00 PM');
        expect(EventDataFormatter.formatTime('13:45'), '1:45 PM');
        expect(EventDataFormatter.formatTime('23:59'), '11:59 PM');
      });

      test('handles edge cases around noon and midnight', () {
        expect(EventDataFormatter.formatTime('00:30'), '12:30 AM');
        expect(EventDataFormatter.formatTime('12:30'), '12:30 PM');
      });

      test('handles invalid time formats gracefully', () {
        final result = EventDataFormatter.formatTime('invalid');
        // Should return input unchanged
        expect(result, 'invalid');
      });

      test('handles empty string', () {
        expect(EventDataFormatter.formatTime(''), '');
      });

      test('preserves minutes correctly', () {
        expect(EventDataFormatter.formatTime('09:05'), '9:05 AM');
        expect(EventDataFormatter.formatTime('14:00'), '2:00 PM');
        expect(EventDataFormatter.formatTime('15:30'), '3:30 PM');
      });

      test('handles afternoon times correctly', () {
        expect(EventDataFormatter.formatTime('13:00'), '1:00 PM');
        expect(EventDataFormatter.formatTime('18:45'), '6:45 PM');
        expect(EventDataFormatter.formatTime('21:15'), '9:15 PM');
      });
    });

    group('formatDuration', () {
      test('formats seconds to M:SS format', () {
        expect(EventDataFormatter.formatDuration(30), '0:30');
        expect(EventDataFormatter.formatDuration(60), '1:00');
        expect(EventDataFormatter.formatDuration(90), '1:30');
        expect(EventDataFormatter.formatDuration(150), '2:30');
      });

      test('handles zero duration', () {
        expect(EventDataFormatter.formatDuration(0), '0:00');
      });

      test('handles large durations (hours as minutes)', () {
        // 2 hours = 120 minutes
        expect(EventDataFormatter.formatDuration(7200), '120:00');
      });

      test('pads seconds with zero', () {
        expect(EventDataFormatter.formatDuration(65), '1:05');
        expect(EventDataFormatter.formatDuration(305), '5:05');
      });
    });

    group('formatList', () {
      test('formats list with default separator', () {
        final items = ['Apple', 'Banana', 'Cherry'];
        expect(EventDataFormatter.formatList(items), 'Apple, Banana, Cherry');
      });

      test('formats list with custom separator', () {
        final items = ['Red', 'Green', 'Blue'];
        expect(
          EventDataFormatter.formatList(items, separator: ' | '),
          'Red | Green | Blue',
        );
      });

      test('handles single item list', () {
        final items = ['Solo'];
        expect(EventDataFormatter.formatList(items), 'Solo');
      });

      test('handles empty list', () {
        expect(EventDataFormatter.formatList([]), '');
      });

      test('handles null list', () {
        expect(EventDataFormatter.formatList(null), '');
      });

      test('handles mixed type list', () {
        final items = ['Text', 123, true];
        final result = EventDataFormatter.formatList(items);
        expect(result, contains('Text'));
        expect(result, contains('123'));
        expect(result, contains('true'));
      });

      test('handles list with null values', () {
        final items = ['A', null, 'C'];
        final result = EventDataFormatter.formatList(items);
        // Should skip nulls or convert to string
        expect(result.isNotEmpty, true);
      });
    });

    group('edge cases', () {
      test('handles very long text values', () {
        final data = {
          'event_name': 'A' * 1000,
          'venue': 'B' * 500,
        };

        final result = EventDataFormatter.formatExtractedData(data);

        expect(result, contains('Event:'));
        expect(result, contains('Venue:'));
      });

      test('handles special characters in text', () {
        final data = {
          'event_name': 'Event with "quotes" & symbols!',
          'venue': 'Venue with\nnewlines',
        };

        final result = EventDataFormatter.formatExtractedData(data);

        expect(result, contains('Event with "quotes" & symbols!'));
      });

      test('handles numeric values as integers', () {
        final data = {
          'headcount': 100,
        };

        final result = EventDataFormatter.formatExtractedData(data);

        expect(result, contains('Headcount: 100'));
      });

      test('handles boolean values', () {
        final data = {
          'event_name': 'Test',
          'confirmed': true,
        };

        final result = EventDataFormatter.formatExtractedData(data);

        // Should include the confirmed field somehow
        expect(result.isNotEmpty, true);
      });
    });
  });
}
