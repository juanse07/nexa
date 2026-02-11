/// Curated demo data for App Store / Play Store screenshots.
///
/// All dates are relative to "now" so screenshots always look current.
library;

class DemoData {
  DemoData._();

  // ── Events ──────────────────────────────────────────────────────────
  static List<Map<String, dynamic>> get events {
    final now = DateTime.now();
    final tomorrow = now.add(const Duration(days: 1));
    final nextWeek = now.add(const Duration(days: 7));
    final yesterday = now.subtract(const Duration(days: 1));

    return [
      {
        '_id': 'evt_001',
        'title': 'Annual Gala Dinner',
        'client': {'_id': 'cli_001', 'name': 'Grand Ballroom Events'},
        'venue': 'The Ritz-Carlton Ballroom',
        'address': '1150 22nd St NW, Washington, DC 20037',
        'date': tomorrow.toIso8601String(),
        'callTime': '${tomorrow.year}-${_pad(tomorrow.month)}-${_pad(tomorrow.day)}T16:00:00.000Z',
        'endTime': '${tomorrow.year}-${_pad(tomorrow.month)}-${_pad(tomorrow.day)}T23:30:00.000Z',
        'status': 'posted',
        'staffNeeded': 12,
        'acceptedStaff': _generateStaffList(8),
        'roles': [
          {'role': 'Bartender', 'count': 4},
          {'role': 'Server', 'count': 6},
          {'role': 'Event Coordinator', 'count': 2},
        ],
        'notes': 'Black-tie event. All staff must arrive in formal attire.',
        'compensation': {
          'type': 'hourly',
          'rate': 28.00,
        },
      },
      {
        '_id': 'evt_002',
        'title': 'Tech Conference Reception',
        'client': {'_id': 'cli_002', 'name': 'Marriott Downtown'},
        'venue': 'Marriott Grand Salon',
        'address': '901 Massachusetts Ave NW, Washington, DC 20001',
        'date': nextWeek.toIso8601String(),
        'callTime': '${nextWeek.year}-${_pad(nextWeek.month)}-${_pad(nextWeek.day)}T10:00:00.000Z',
        'endTime': '${nextWeek.year}-${_pad(nextWeek.month)}-${_pad(nextWeek.day)}T18:00:00.000Z',
        'status': 'posted',
        'staffNeeded': 8,
        'acceptedStaff': _generateStaffList(3),
        'roles': [
          {'role': 'Server', 'count': 4},
          {'role': 'Bartender', 'count': 2},
          {'role': 'Runner', 'count': 2},
        ],
        'notes': 'Tech conference with 500+ attendees. Cocktail service.',
        'compensation': {
          'type': 'hourly',
          'rate': 25.00,
        },
      },
      {
        '_id': 'evt_003',
        'title': 'Wedding: Johnson & Lee',
        'client': {'_id': 'cli_003', 'name': 'Elegant Affairs Co'},
        'venue': 'Dumbarton House Gardens',
        'address': '2715 Q St NW, Washington, DC 20007',
        'date': now.add(const Duration(days: 3)).toIso8601String(),
        'callTime': '${now.add(const Duration(days: 3)).toIso8601String()}',
        'endTime': '${now.add(const Duration(days: 3, hours: 8)).toIso8601String()}',
        'status': 'pending',
        'staffNeeded': 15,
        'acceptedStaff': <Map<String, dynamic>>[],
        'roles': [
          {'role': 'Server', 'count': 8},
          {'role': 'Bartender', 'count': 3},
          {'role': 'Event Coordinator', 'count': 2},
          {'role': 'Runner', 'count': 2},
        ],
        'notes': 'Outdoor wedding ceremony + indoor reception.',
        'compensation': {
          'type': 'hourly',
          'rate': 30.00,
        },
      },
      {
        '_id': 'evt_004',
        'title': 'Corporate Luncheon',
        'client': {'_id': 'cli_004', 'name': 'Capital Catering Group'},
        'venue': 'Four Seasons Terrace',
        'address': '2800 Pennsylvania Ave NW, Washington, DC 20007',
        'date': now.add(const Duration(days: 5)).toIso8601String(),
        'callTime': '${now.add(const Duration(days: 5)).toIso8601String()}',
        'endTime': '${now.add(const Duration(days: 5, hours: 4)).toIso8601String()}',
        'status': 'posted',
        'staffNeeded': 6,
        'acceptedStaff': _generateStaffList(6),
        'roles': [
          {'role': 'Server', 'count': 4},
          {'role': 'Bartender', 'count': 2},
        ],
        'notes': 'Full staff. Ready to go.',
        'compensation': {
          'type': 'hourly',
          'rate': 22.00,
        },
      },
      {
        '_id': 'evt_005',
        'title': 'Charity Fundraiser Gala',
        'client': {'_id': 'cli_005', 'name': 'National Arts Foundation'},
        'venue': 'National Building Museum',
        'address': '401 F St NW, Washington, DC 20001',
        'date': now.add(const Duration(days: 10)).toIso8601String(),
        'callTime': '${now.add(const Duration(days: 10)).toIso8601String()}',
        'endTime': '${now.add(const Duration(days: 10, hours: 6)).toIso8601String()}',
        'status': 'posted',
        'staffNeeded': 20,
        'acceptedStaff': _generateStaffList(12),
        'roles': [
          {'role': 'Server', 'count': 10},
          {'role': 'Bartender', 'count': 5},
          {'role': 'Event Coordinator', 'count': 3},
          {'role': 'Runner', 'count': 2},
        ],
        'compensation': {
          'type': 'hourly',
          'rate': 32.00,
        },
      },
      {
        '_id': 'evt_006',
        'title': 'Wine Tasting Evening',
        'client': {'_id': 'cli_002', 'name': 'Marriott Downtown'},
        'venue': 'Marriott Rooftop Lounge',
        'address': '901 Massachusetts Ave NW, Washington, DC 20001',
        'date': yesterday.toIso8601String(),
        'callTime': yesterday.toIso8601String(),
        'endTime': yesterday.add(const Duration(hours: 4)).toIso8601String(),
        'status': 'completed',
        'staffNeeded': 4,
        'acceptedStaff': _generateStaffList(4),
        'roles': [
          {'role': 'Bartender', 'count': 2},
          {'role': 'Server', 'count': 2},
        ],
        'compensation': {
          'type': 'hourly',
          'rate': 26.00,
        },
      },
    ];
  }

  // ── Clients ─────────────────────────────────────────────────────────
  static List<Map<String, dynamic>> get clients => [
        {'_id': 'cli_001', 'name': 'Grand Ballroom Events', 'email': 'events@granballroom.com', 'phone': '(202) 555-0101'},
        {'_id': 'cli_002', 'name': 'Marriott Downtown', 'email': 'catering@marriott.com', 'phone': '(202) 555-0102'},
        {'_id': 'cli_003', 'name': 'Elegant Affairs Co', 'email': 'hello@elegantaffairs.com', 'phone': '(202) 555-0103'},
        {'_id': 'cli_004', 'name': 'Capital Catering Group', 'email': 'info@capitalcatering.com', 'phone': '(202) 555-0104'},
        {'_id': 'cli_005', 'name': 'National Arts Foundation', 'email': 'events@natarts.org', 'phone': '(202) 555-0105'},
      ];

  // ── Roles ───────────────────────────────────────────────────────────
  static List<Map<String, dynamic>> get roles => [
        {'_id': 'role_001', 'name': 'Bartender', 'description': 'Craft cocktails and beverage service'},
        {'_id': 'role_002', 'name': 'Server', 'description': 'Table service and guest interaction'},
        {'_id': 'role_003', 'name': 'Event Coordinator', 'description': 'On-site logistics and team lead'},
        {'_id': 'role_004', 'name': 'Runner', 'description': 'Kitchen to table food delivery'},
        {'_id': 'role_005', 'name': 'Barback', 'description': 'Bar support and restocking'},
      ];

  // ── Tariffs ─────────────────────────────────────────────────────────
  static List<Map<String, dynamic>> get tariffs => [
        {'_id': 'tar_001', 'client': 'cli_001', 'role': 'Bartender', 'rate': 28.00, 'currency': 'USD'},
        {'_id': 'tar_002', 'client': 'cli_001', 'role': 'Server', 'rate': 24.00, 'currency': 'USD'},
        {'_id': 'tar_003', 'client': 'cli_002', 'role': 'Bartender', 'rate': 25.00, 'currency': 'USD'},
        {'_id': 'tar_004', 'client': 'cli_002', 'role': 'Server', 'rate': 22.00, 'currency': 'USD'},
        {'_id': 'tar_005', 'client': 'cli_003', 'role': 'Event Coordinator', 'rate': 35.00, 'currency': 'USD'},
      ];

  // ── Conversations (Chat) ────────────────────────────────────────────
  static List<Map<String, dynamic>> get conversations => [
        {
          '_id': 'conv_001',
          'name': 'Annual Gala Team',
          'eventId': 'evt_001',
          'lastMessage': 'Uniform update: black vest required',
          'lastMessageTime': DateTime.now().subtract(const Duration(minutes: 15)).toIso8601String(),
          'unreadCount': 2,
          'participants': 8,
        },
        {
          '_id': 'conv_002',
          'name': 'Tech Conference Crew',
          'eventId': 'evt_002',
          'lastMessage': 'Setup begins at 8 AM sharp',
          'lastMessageTime': DateTime.now().subtract(const Duration(hours: 1)).toIso8601String(),
          'unreadCount': 0,
          'participants': 5,
        },
        {
          '_id': 'conv_003',
          'name': 'Wedding Staff',
          'eventId': 'evt_003',
          'lastMessage': 'Menu finalized — see attached PDF',
          'lastMessageTime': DateTime.now().subtract(const Duration(hours: 3)).toIso8601String(),
          'unreadCount': 1,
          'participants': 12,
        },
        {
          '_id': 'conv_004',
          'name': 'All Staff Announcements',
          'lastMessage': 'Holiday schedule posted for December',
          'lastMessageTime': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
          'unreadCount': 0,
          'participants': 45,
        },
      ];

  // ── AI Chat (Valerio) ──────────────────────────────────────────────
  static List<Map<String, dynamic>> get aiChatMessages => [
        {
          'role': 'user',
          'content': 'How many events do I have scheduled this week?',
          'timestamp': DateTime.now().subtract(const Duration(minutes: 5)).toIso8601String(),
        },
        {
          'role': 'assistant',
          'content':
              'You have **3 events** scheduled this week:\n\n'
              '1. **Annual Gala Dinner** — tomorrow at The Ritz-Carlton (12 staff needed, 8 confirmed)\n'
              '2. **Wedding: Johnson & Lee** — in 3 days at Dumbarton House (15 staff needed)\n'
              '3. **Corporate Luncheon** — in 5 days at Four Seasons (fully staffed)\n\n'
              'Would you like me to help fill the remaining positions for the wedding?',
          'timestamp': DateTime.now().subtract(const Duration(minutes: 4)).toIso8601String(),
        },
        {
          'role': 'user',
          'content': 'Yes, send availability requests to bartenders for the wedding.',
          'timestamp': DateTime.now().subtract(const Duration(minutes: 3)).toIso8601String(),
        },
        {
          'role': 'assistant',
          'content':
              'Done! I\'ve sent availability requests to **6 bartenders** for the Johnson & Lee Wedding on '
              '${DateTime.now().add(const Duration(days: 3)).month}/${DateTime.now().add(const Duration(days: 3)).day}.\n\n'
              'Notified: Maria G., James T., Sofia R., Alex K., Chen W., Priya M.\n\n'
              'I\'ll let you know as responses come in.',
          'timestamp': DateTime.now().subtract(const Duration(minutes: 2)).toIso8601String(),
        },
      ];

  // ── Staff Members (for Attendance) ─────────────────────────────────
  static List<Map<String, dynamic>> get staffMembers => [
        {'_id': 'staff_001', 'name': 'Maria Garcia', 'role': 'Bartender', 'status': 'clocked_in', 'clockInTime': DateTime.now().subtract(const Duration(hours: 2)).toIso8601String()},
        {'_id': 'staff_002', 'name': 'James Thompson', 'role': 'Server', 'status': 'clocked_in', 'clockInTime': DateTime.now().subtract(const Duration(hours: 2, minutes: 15)).toIso8601String()},
        {'_id': 'staff_003', 'name': 'Sofia Rodriguez', 'role': 'Event Coordinator', 'status': 'clocked_in', 'clockInTime': DateTime.now().subtract(const Duration(hours: 3)).toIso8601String()},
        {'_id': 'staff_004', 'name': 'Alex Kim', 'role': 'Bartender', 'status': 'clocked_in', 'clockInTime': DateTime.now().subtract(const Duration(hours: 1, minutes: 45)).toIso8601String()},
        {'_id': 'staff_005', 'name': 'Chen Wang', 'role': 'Server', 'status': 'pending', 'clockInTime': null},
        {'_id': 'staff_006', 'name': 'Priya Mehta', 'role': 'Runner', 'status': 'clocked_in', 'clockInTime': DateTime.now().subtract(const Duration(hours: 1, minutes: 30)).toIso8601String()},
        {'_id': 'staff_007', 'name': 'David Brown', 'role': 'Server', 'status': 'clocked_out', 'clockInTime': DateTime.now().subtract(const Duration(hours: 6)).toIso8601String(), 'clockOutTime': DateTime.now().subtract(const Duration(hours: 1)).toIso8601String()},
        {'_id': 'staff_008', 'name': 'Emma Wilson', 'role': 'Bartender', 'status': 'clocked_in', 'clockInTime': DateTime.now().subtract(const Duration(hours: 2, minutes: 30)).toIso8601String()},
        {'_id': 'staff_009', 'name': 'Lucas Santos', 'role': 'Runner', 'status': 'pending', 'clockInTime': null},
        {'_id': 'staff_010', 'name': 'Aisha Johnson', 'role': 'Server', 'status': 'clocked_in', 'clockInTime': DateTime.now().subtract(const Duration(hours: 1)).toIso8601String()},
        {'_id': 'staff_011', 'name': 'Ryan Park', 'role': 'Barback', 'status': 'clocked_in', 'clockInTime': DateTime.now().subtract(const Duration(hours: 2, minutes: 10)).toIso8601String()},
        {'_id': 'staff_012', 'name': 'Isabella Rossi', 'role': 'Event Coordinator', 'status': 'clocked_in', 'clockInTime': DateTime.now().subtract(const Duration(hours: 3, minutes: 5)).toIso8601String()},
      ];

  // ── Helpers ─────────────────────────────────────────────────────────
  static String _pad(int n) => n.toString().padLeft(2, '0');

  static List<Map<String, dynamic>> _generateStaffList(int count) {
    const names = [
      'Maria Garcia', 'James Thompson', 'Sofia Rodriguez', 'Alex Kim',
      'Chen Wang', 'Priya Mehta', 'David Brown', 'Emma Wilson',
      'Lucas Santos', 'Aisha Johnson', 'Ryan Park', 'Isabella Rossi',
      'Marcus Lee', 'Fatima Al-Hassan', 'Diego Morales', 'Hannah Chen',
      'Omar Patel', 'Yuki Tanaka', 'Sarah Davis', 'Andre Williams',
    ];
    return List.generate(
      count,
      (i) => {
        '_id': 'staff_${(i + 1).toString().padLeft(3, '0')}',
        'name': names[i % names.length],
        'status': 'accepted',
      },
    );
  }
}
