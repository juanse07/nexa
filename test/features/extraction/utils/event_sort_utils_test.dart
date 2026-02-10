import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexa/features/extraction/utils/event_sort_utils.dart';

void main() {
  // ── Sample events with varied dates, times, and _id values ──
  final eventA = <String, dynamic>{
    '_id': '65a0000000000000000aaaaa', // oldest ObjectID
    'shift_name': 'Morning Shift',
    'date': '2025-03-10',
    'start_time': '8:00 AM',
  };
  final eventB = <String, dynamic>{
    '_id': '65b0000000000000000bbbbb',
    'shift_name': 'Afternoon Shift',
    'date': '2025-03-15',
    'start_time': '2:00 PM',
  };
  final eventC = <String, dynamic>{
    '_id': '65c0000000000000000ccccc', // newest ObjectID
    'shift_name': 'Evening Shift',
    'date': '2025-03-05',
    'start_time': '6:00 PM',
  };

  final events = [eventB, eventA, eventC]; // deliberately unsorted

  group('EventSortUtils.sortEvents', () {
    test('dateAsc sorts by job date ascending', () {
      final sorted = EventSortUtils.sortEvents(events, EventSortMode.dateAsc);

      expect(sorted[0]['shift_name'], 'Evening Shift'); // Mar 5
      expect(sorted[1]['shift_name'], 'Morning Shift'); // Mar 10
      expect(sorted[2]['shift_name'], 'Afternoon Shift'); // Mar 15
    });

    test('dateDesc sorts by job date descending', () {
      final sorted = EventSortUtils.sortEvents(events, EventSortMode.dateDesc);

      expect(sorted[0]['shift_name'], 'Afternoon Shift'); // Mar 15
      expect(sorted[1]['shift_name'], 'Morning Shift'); // Mar 10
      expect(sorted[2]['shift_name'], 'Evening Shift'); // Mar 5
    });

    test('lastCreated sorts by _id descending (newest first)', () {
      final sorted =
          EventSortUtils.sortEvents(events, EventSortMode.lastCreated);

      expect(sorted[0]['_id'], '65c0000000000000000ccccc'); // C = newest
      expect(sorted[1]['_id'], '65b0000000000000000bbbbb'); // B
      expect(sorted[2]['_id'], '65a0000000000000000aaaaa'); // A = oldest
    });

    test('does not mutate the original list', () {
      final original = [...events];
      EventSortUtils.sortEvents(events, EventSortMode.dateAsc);
      expect(events.map((e) => e['_id']).toList(),
          original.map((e) => e['_id']).toList());
    });

    test('handles empty list gracefully', () {
      final sorted =
          EventSortUtils.sortEvents([], EventSortMode.dateAsc);
      expect(sorted, isEmpty);
    });
  });

  group('EventSortUtils.sortEvents – tiebreaker on same date', () {
    test('dateAsc uses shift_name as tiebreaker when dates are equal', () {
      final sameDate = [
        {'shift_name': 'Zebra Shift', 'date': '2025-04-01', 'start_time': '9:00 AM'},
        {'shift_name': 'Alpha Shift', 'date': '2025-04-01', 'start_time': '9:00 AM'},
      ];
      final sorted =
          EventSortUtils.sortEvents(sameDate, EventSortMode.dateAsc);

      expect(sorted[0]['shift_name'], 'Alpha Shift');
      expect(sorted[1]['shift_name'], 'Zebra Shift');
    });
  });

  group('EventSortUtils.sortEvents – null date handling', () {
    test('events with null dates sort to the end in dateAsc', () {
      final withNull = [
        <String, dynamic>{'shift_name': 'No Date', 'date': null},
        eventC, // Mar 5
        eventA, // Mar 10
      ];
      final sorted =
          EventSortUtils.sortEvents(withNull, EventSortMode.dateAsc);

      expect(sorted[0]['shift_name'], 'Evening Shift'); // Mar 5
      expect(sorted[1]['shift_name'], 'Morning Shift'); // Mar 10
      expect(sorted[2]['shift_name'], 'No Date'); // null → end
    });

    test('events with null dates sort to the end in dateDesc', () {
      final withNull = [
        <String, dynamic>{'shift_name': 'No Date', 'date': null},
        eventC, // Mar 5
        eventA, // Mar 10
      ];
      final sorted =
          EventSortUtils.sortEvents(withNull, EventSortMode.dateDesc);

      expect(sorted[0]['shift_name'], 'Morning Shift'); // Mar 10
      expect(sorted[1]['shift_name'], 'Evening Shift'); // Mar 5
      expect(sorted[2]['shift_name'], 'No Date'); // null → end
    });
  });

  group('EventSortUtils.eventDateTime', () {
    test('parses date + AM time correctly', () {
      final dt = EventSortUtils.eventDateTime(eventA);
      expect(dt, DateTime(2025, 3, 10, 8, 0));
    });

    test('parses date + PM time correctly', () {
      final dt = EventSortUtils.eventDateTime(eventB);
      expect(dt, DateTime(2025, 3, 15, 14, 0));
    });

    test('returns date only when start_time is missing', () {
      final noTime = <String, dynamic>{'date': '2025-06-01'};
      final dt = EventSortUtils.eventDateTime(noTime);
      expect(dt, DateTime(2025, 6, 1));
    });

    test('returns null for null date', () {
      final noDate = <String, dynamic>{'shift_name': 'No Date'};
      expect(EventSortUtils.eventDateTime(noDate), isNull);
    });

    test('returns null for empty date string', () {
      final emptyDate = <String, dynamic>{'date': ''};
      expect(EventSortUtils.eventDateTime(emptyDate), isNull);
    });

    test('uses end_time when useEnd is true', () {
      final event = <String, dynamic>{
        'date': '2025-07-01',
        'start_time': '9:00 AM',
        'end_time': '5:00 PM',
      };
      final dt = EventSortUtils.eventDateTime(event, useEnd: true);
      expect(dt, DateTime(2025, 7, 1, 17, 0));
    });
  });

  group('EventSortUtils.parseTimeOfDayString', () {
    test('parses "3:30 PM"', () {
      final tod = EventSortUtils.parseTimeOfDayString('3:30 PM');
      expect(tod, const TimeOfDay(hour: 15, minute: 30));
    });

    test('parses "12:00 AM" as midnight', () {
      final tod = EventSortUtils.parseTimeOfDayString('12:00 AM');
      expect(tod, const TimeOfDay(hour: 0, minute: 0));
    });

    test('parses "12:00 PM" as noon', () {
      final tod = EventSortUtils.parseTimeOfDayString('12:00 PM');
      expect(tod, const TimeOfDay(hour: 12, minute: 0));
    });

    test('parses 24h format "14:30"', () {
      final tod = EventSortUtils.parseTimeOfDayString('14:30');
      expect(tod, const TimeOfDay(hour: 14, minute: 30));
    });

    test('parses hour-only "8 am"', () {
      final tod = EventSortUtils.parseTimeOfDayString('8 am');
      expect(tod, const TimeOfDay(hour: 8, minute: 0));
    });

    test('returns null for empty string', () {
      expect(EventSortUtils.parseTimeOfDayString(''), isNull);
    });

    test('returns null for non-time string', () {
      expect(EventSortUtils.parseTimeOfDayString('hello'), isNull);
    });
  });
}
