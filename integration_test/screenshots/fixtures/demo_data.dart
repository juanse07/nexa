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

  // ── Event Detail (backend API format for EventDetailScreen) ────────
  static Map<String, dynamic> get eventDetailEvent {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    return {
      '_id': 'evt_001',
      'event_name': 'Annual Gala Dinner',
      'shift_name': 'Annual Gala Dinner',
      'title': 'Annual Gala Dinner',
      'client_name': 'Grand Ballroom Events',
      'client': {'_id': 'cli_001', 'name': 'Grand Ballroom Events'},
      'venue_name': 'The Ritz-Carlton Ballroom',
      'venue': 'The Ritz-Carlton Ballroom',
      'venue_address': '1150 22nd St NW, Washington, DC 20037',
      'address': '1150 22nd St NW, Washington, DC 20037',
      'city': 'Washington',
      'state': 'DC',
      'date': tomorrow.toIso8601String(),
      'start_time': '16:00',
      'end_time': '23:30',
      'callTime': '${tomorrow.year}-${_pad(tomorrow.month)}-${_pad(tomorrow.day)}T16:00:00.000Z',
      'endTime': '${tomorrow.year}-${_pad(tomorrow.month)}-${_pad(tomorrow.day)}T23:30:00.000Z',
      'status': 'posted',
      'headcount_total': 12,
      'staffNeeded': 12,
      'accepted_staff': _generateDetailedStaffList(8),
      'acceptedStaff': _generateDetailedStaffList(8),
      'roles': [
        {'role': 'Bartender', 'count': 4},
        {'role': 'Server', 'count': 6},
        {'role': 'Event Coordinator', 'count': 2},
      ],
      'notes': 'Black-tie event. All staff must arrive in formal attire.',
      'contact_name': 'Jennifer Collins',
      'contact_phone': '(202) 555-0150',
      'visibilityType': 'specific',
      'keepOpenForAcceptance': false,
      'compensation': {'type': 'hourly', 'rate': 28.00},
    };
  }

  // ── Draft Event (for PendingEditScreen / PendingPublishScreen) ────
  static Map<String, dynamic> get draftEvent {
    final inThreeDays = DateTime.now().add(const Duration(days: 3));
    return {
      '_id': 'draft_001',
      'event_name': 'Wedding: Johnson & Lee',
      'title': 'Wedding: Johnson & Lee',
      'client_name': 'Elegant Affairs Co',
      'client': {'_id': 'cli_003', 'name': 'Elegant Affairs Co'},
      'venue_name': 'Dumbarton House Gardens',
      'venue': 'Dumbarton House Gardens',
      'venue_address': '2715 Q St NW, Washington, DC 20007',
      'address': '2715 Q St NW, Washington, DC 20007',
      'date': inThreeDays.toIso8601String(),
      'start_time': '14:00',
      'end_time': '22:00',
      'callTime': inThreeDays.toIso8601String(),
      'endTime': inThreeDays.add(const Duration(hours: 8)).toIso8601String(),
      'status': 'pending',
      'headcount_total': 15,
      'staffNeeded': 15,
      'roles': [
        {'role': 'Server', 'count': 8},
        {'role': 'Bartender', 'count': 3},
        {'role': 'Event Coordinator', 'count': 2},
        {'role': 'Runner', 'count': 2},
      ],
      'notes': 'Outdoor wedding ceremony + indoor reception. Formal attire required.',
      'contact_name': 'Michael Johnson',
      'contact_phone': '(202) 555-0175',
      'compensation': {'type': 'hourly', 'rate': 30.00},
    };
  }

  // ── Staff Detail (for StaffDetailScreen) ──────────────────────────
  static Map<String, dynamic> get staffDetailMember => {
        'userKey': 'google:staff001',
        '_id': 'staff_001',
        'name': 'Maria Garcia',
        'first_name': 'Maria',
        'last_name': 'Garcia',
        'email': 'maria.garcia@example.com',
        'phone_number': '(202) 555-0201',
        'picture': null,
        'roles': ['Bartender', 'Server'],
        'isFavorite': true,
        'rating': 4.8,
        'totalRatings': 23,
        'notes': 'Excellent bartender. Great with guests. Always on time.',
        'groups': [
          {'_id': 'grp_001', 'name': 'VIP Team', 'color': '#1976D2'},
          {'_id': 'grp_002', 'name': 'Regulars', 'color': '#388E3C'},
        ],
        'totalHours': 247.5,
        'eventsWorked': 42,
        'provider': 'google',
        'subject': 'staff001',
      };

  // ── Teams ─────────────────────────────────────────────────────────
  static List<Map<String, dynamic>> get teams => [
        {
          '_id': 'team_001',
          'name': 'DC Metro Team',
          'description': 'Staff based in the DC metropolitan area',
          'memberCount': 24,
          'createdAt': DateTime.now().subtract(const Duration(days: 90)).toIso8601String(),
        },
        {
          '_id': 'team_002',
          'name': 'VIP Event Specialists',
          'description': 'Elite team for high-profile events',
          'memberCount': 8,
          'createdAt': DateTime.now().subtract(const Duration(days: 45)).toIso8601String(),
        },
        {
          '_id': 'team_003',
          'name': 'Weekend Warriors',
          'description': 'Available for weekend events only',
          'memberCount': 15,
          'createdAt': DateTime.now().subtract(const Duration(days: 30)).toIso8601String(),
        },
      ];

  static List<Map<String, dynamic>> get teamMembers => [
        {'_id': 'staff_001', 'name': 'Maria Garcia', 'email': 'maria@example.com', 'picture': null, 'role': 'Bartender', 'joinedAt': DateTime.now().subtract(const Duration(days: 80)).toIso8601String()},
        {'_id': 'staff_002', 'name': 'James Thompson', 'email': 'james@example.com', 'picture': null, 'role': 'Server', 'joinedAt': DateTime.now().subtract(const Duration(days: 75)).toIso8601String()},
        {'_id': 'staff_003', 'name': 'Sofia Rodriguez', 'email': 'sofia@example.com', 'picture': null, 'role': 'Event Coordinator', 'joinedAt': DateTime.now().subtract(const Duration(days: 60)).toIso8601String()},
        {'_id': 'staff_004', 'name': 'Alex Kim', 'email': 'alex@example.com', 'picture': null, 'role': 'Bartender', 'joinedAt': DateTime.now().subtract(const Duration(days: 45)).toIso8601String()},
        {'_id': 'staff_006', 'name': 'Priya Mehta', 'email': 'priya@example.com', 'picture': null, 'role': 'Runner', 'joinedAt': DateTime.now().subtract(const Duration(days: 30)).toIso8601String()},
      ];

  static List<Map<String, dynamic>> get teamInvites => [
        {'_id': 'inv_001', 'email': 'newstaff@example.com', 'status': 'pending', 'sentAt': DateTime.now().subtract(const Duration(days: 2)).toIso8601String()},
      ];

  static List<Map<String, dynamic>> get teamInviteLinks => [
        {'_id': 'link_001', 'code': 'DC-METRO-2024', 'uses': 5, 'maxUses': 20, 'expiresAt': DateTime.now().add(const Duration(days: 30)).toIso8601String(), 'createdAt': DateTime.now().subtract(const Duration(days: 5)).toIso8601String()},
      ];

  // ── Manager Profile ───────────────────────────────────────────────
  static Map<String, dynamic> get managerProfile => {
        '_id': 'mgr_001',
        'email': 'sarah.mitchell@flowshift.io',
        'firstName': 'Sarah',
        'lastName': 'Mitchell',
        'name': 'Sarah Mitchell',
        'picture': null,
        'originalPicture': null,
        'caricatureHistory': <Map<String, dynamic>>[],
        'appId': 'FS-MGR-001',
        'phoneNumber': '(202) 555-0100',
        'cities': ['Washington, DC', 'Arlington, VA'],
        'venueCount': 12,
        'lastVenueUpdate': DateTime.now().subtract(const Duration(days: 3)).toIso8601String(),
        'subscription': {'plan': 'pro', 'status': 'active'},
      };

  // ── Groups (for staff categorization) ─────────────────────────────
  static List<Map<String, dynamic>> get groups => [
        {'_id': 'grp_001', 'name': 'VIP Team', 'memberCount': 8},
        {'_id': 'grp_002', 'name': 'Regulars', 'memberCount': 15},
        {'_id': 'grp_003', 'name': 'New Hires', 'memberCount': 5},
      ];

  // ── Conversations (API format for ChatService) ────────────────────
  static List<Map<String, dynamic>> get conversationsApi => [
        {
          '_id': 'conv_001',
          'participants': [
            {'userKey': 'google:staff001', 'name': 'Maria Garcia', 'picture': null},
          ],
          'lastMessage': {'content': 'Uniform update: black vest required', 'sentAt': DateTime.now().subtract(const Duration(minutes: 15)).toIso8601String()},
          'unreadCount': 2,
          'eventId': 'evt_001',
          'eventName': 'Annual Gala Dinner',
        },
        {
          '_id': 'conv_002',
          'participants': [
            {'userKey': 'google:staff002', 'name': 'James Thompson', 'picture': null},
          ],
          'lastMessage': {'content': 'Setup begins at 8 AM sharp', 'sentAt': DateTime.now().subtract(const Duration(hours: 1)).toIso8601String()},
          'unreadCount': 0,
          'eventId': 'evt_002',
          'eventName': 'Tech Conference',
        },
        {
          '_id': 'conv_003',
          'participants': [
            {'userKey': 'google:staff003', 'name': 'Sofia Rodriguez', 'picture': null},
          ],
          'lastMessage': {'content': 'Menu finalized — see attached PDF', 'sentAt': DateTime.now().subtract(const Duration(hours: 3)).toIso8601String()},
          'unreadCount': 1,
        },
        {
          '_id': 'conv_004',
          'participants': [
            {'userKey': 'google:staff008', 'name': 'Emma Wilson', 'picture': null},
          ],
          'lastMessage': {'content': 'Can I switch shifts on Saturday?', 'sentAt': DateTime.now().subtract(const Duration(hours: 5)).toIso8601String()},
          'unreadCount': 0,
        },
        {
          '_id': 'conv_005',
          'participants': [
            {'userKey': 'google:staff004', 'name': 'Alex Kim', 'picture': null},
          ],
          'lastMessage': {'content': 'Thanks for the great feedback!', 'sentAt': DateTime.now().subtract(const Duration(days: 1)).toIso8601String()},
          'unreadCount': 0,
        },
      ];

  // ── Chat Messages (for individual ChatScreen) ─────────────────────
  static List<Map<String, dynamic>> get chatMessages => [
        {'_id': 'msg_001', 'senderId': 'mgr_001', 'content': 'Hi Maria! Are you available for the Gala on Friday?', 'sentAt': DateTime.now().subtract(const Duration(hours: 2)).toIso8601String(), 'isMe': true},
        {'_id': 'msg_002', 'senderId': 'google:staff001', 'content': 'Yes! I\'d love to work that event. What time should I arrive?', 'sentAt': DateTime.now().subtract(const Duration(hours: 1, minutes: 45)).toIso8601String(), 'isMe': false},
        {'_id': 'msg_003', 'senderId': 'mgr_001', 'content': 'Call time is 4 PM. Black tie dress code. Can you bartend?', 'sentAt': DateTime.now().subtract(const Duration(hours: 1, minutes: 30)).toIso8601String(), 'isMe': true},
        {'_id': 'msg_004', 'senderId': 'google:staff001', 'content': 'Absolutely! I\'ll bring my cocktail kit. Looking forward to it!', 'sentAt': DateTime.now().subtract(const Duration(hours: 1)).toIso8601String(), 'isMe': false},
        {'_id': 'msg_005', 'senderId': 'mgr_001', 'content': 'Uniform update: black vest required', 'sentAt': DateTime.now().subtract(const Duration(minutes: 15)).toIso8601String(), 'isMe': true},
      ];

  // ── Attendance Analytics ──────────────────────────────────────────
  static Map<String, dynamic> get attendanceAnalytics => {
        'totalHoursThisWeek': 312.5,
        'totalHoursLastWeek': 287.0,
        'attendanceRate': 94.2,
        'avgHoursPerStaff': 6.5,
        'totalStaffActive': 48,
        'flaggedCount': 3,
        'onTimeRate': 91.5,
      };

  // ── Clocked-In Staff (for live grid) ──────────────────────────────
  static List<Map<String, dynamic>> get clockedInStaff => [
        {'_id': 'staff_001', 'name': 'Maria Garcia', 'role': 'Bartender', 'eventName': 'Annual Gala Dinner', 'clockInTime': DateTime.now().subtract(const Duration(hours: 2)).toIso8601String(), 'picture': null},
        {'_id': 'staff_002', 'name': 'James Thompson', 'role': 'Server', 'eventName': 'Annual Gala Dinner', 'clockInTime': DateTime.now().subtract(const Duration(hours: 2, minutes: 15)).toIso8601String(), 'picture': null},
        {'_id': 'staff_003', 'name': 'Sofia Rodriguez', 'role': 'Event Coordinator', 'eventName': 'Annual Gala Dinner', 'clockInTime': DateTime.now().subtract(const Duration(hours: 3)).toIso8601String(), 'picture': null},
        {'_id': 'staff_004', 'name': 'Alex Kim', 'role': 'Bartender', 'eventName': 'Tech Conference', 'clockInTime': DateTime.now().subtract(const Duration(hours: 1, minutes: 45)).toIso8601String(), 'picture': null},
        {'_id': 'staff_006', 'name': 'Priya Mehta', 'role': 'Runner', 'eventName': 'Tech Conference', 'clockInTime': DateTime.now().subtract(const Duration(hours: 1, minutes: 30)).toIso8601String(), 'picture': null},
        {'_id': 'staff_008', 'name': 'Emma Wilson', 'role': 'Bartender', 'eventName': 'Annual Gala Dinner', 'clockInTime': DateTime.now().subtract(const Duration(hours: 2, minutes: 30)).toIso8601String(), 'picture': null},
      ];

  // ── Attendance Records ────────────────────────────────────────────
  static List<Map<String, dynamic>> get attendanceRecords => [
        {'_id': 'att_001', 'staffName': 'Maria Garcia', 'eventName': 'Wine Tasting Evening', 'clockIn': DateTime.now().subtract(const Duration(days: 1, hours: 6)).toIso8601String(), 'clockOut': DateTime.now().subtract(const Duration(days: 1, hours: 2)).toIso8601String(), 'hours': 4.0, 'status': 'completed'},
        {'_id': 'att_002', 'staffName': 'David Brown', 'eventName': 'Wine Tasting Evening', 'clockIn': DateTime.now().subtract(const Duration(days: 1, hours: 6)).toIso8601String(), 'clockOut': DateTime.now().subtract(const Duration(days: 1, hours: 1)).toIso8601String(), 'hours': 5.0, 'status': 'flagged', 'flag': 'Overtime without approval'},
        {'_id': 'att_003', 'staffName': 'James Thompson', 'eventName': 'Corporate Mixer', 'clockIn': DateTime.now().subtract(const Duration(days: 2, hours: 8)).toIso8601String(), 'clockOut': DateTime.now().subtract(const Duration(days: 2, hours: 2)).toIso8601String(), 'hours': 6.0, 'status': 'completed'},
      ];

  // ── Statistics ────────────────────────────────────────────────────
  static Map<String, dynamic> get managerStatistics => {
        'totalRevenue': 24750.00,
        'totalHours': 892.5,
        'totalEvents': 28,
        'avgRevenuePerEvent': 883.93,
        'activeStaff': 48,
        'topRole': 'Server',
        'period': 'month',
      };

  static Map<String, dynamic> get payrollReport => {
        'totalPayroll': 18562.50,
        'breakdown': [
          {'role': 'Server', 'hours': 420.0, 'amount': 9660.00, 'staffCount': 18},
          {'role': 'Bartender', 'hours': 280.0, 'amount': 7000.00, 'staffCount': 10},
          {'role': 'Event Coordinator', 'hours': 112.5, 'amount': 3937.50, 'staffCount': 5},
          {'role': 'Runner', 'hours': 80.0, 'amount': 1600.00, 'staffCount': 8},
        ],
        'period': 'month',
      };

  static List<Map<String, dynamic>> get topPerformers => [
        {'_id': 'staff_001', 'name': 'Maria Garcia', 'role': 'Bartender', 'hours': 48.5, 'events': 8, 'rating': 4.9, 'picture': null},
        {'_id': 'staff_003', 'name': 'Sofia Rodriguez', 'role': 'Event Coordinator', 'hours': 42.0, 'events': 7, 'rating': 4.8, 'picture': null},
        {'_id': 'staff_002', 'name': 'James Thompson', 'role': 'Server', 'hours': 38.5, 'events': 6, 'rating': 4.7, 'picture': null},
        {'_id': 'staff_008', 'name': 'Emma Wilson', 'role': 'Bartender', 'hours': 36.0, 'events': 6, 'rating': 4.6, 'picture': null},
        {'_id': 'staff_012', 'name': 'Isabella Rossi', 'role': 'Event Coordinator', 'hours': 35.0, 'events': 5, 'rating': 4.5, 'picture': null},
      ];

  // ── Hours Approval Events ─────────────────────────────────────────
  static List<Map<String, dynamic>> get hoursApprovalEvents {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final twoDaysAgo = DateTime.now().subtract(const Duration(days: 2));
    return [
      {
        '_id': 'evt_006',
        'event_name': 'Wine Tasting Evening',
        'title': 'Wine Tasting Evening',
        'client_name': 'Marriott Downtown',
        'date': yesterday.toIso8601String(),
        'status': 'completed',
        'staffNeeded': 4,
        'acceptedStaff': _generateDetailedStaffList(4),
        'hoursApproved': false,
      },
      {
        '_id': 'evt_007',
        'event_name': 'Corporate Mixer',
        'title': 'Corporate Mixer',
        'client_name': 'Capital Catering Group',
        'date': twoDaysAgo.toIso8601String(),
        'status': 'completed',
        'staffNeeded': 6,
        'acceptedStaff': _generateDetailedStaffList(6),
        'hoursApproved': false,
      },
    ];
  }

  // ── Venues ────────────────────────────────────────────────────────
  static List<Map<String, dynamic>> get venues => [
        {'_id': 'ven_001', 'name': 'The Ritz-Carlton Ballroom', 'address': '1150 22nd St NW', 'city': 'Washington', 'state': 'DC', 'source': 'places', 'lat': 38.9048, 'lng': -77.0479},
        {'_id': 'ven_002', 'name': 'Marriott Grand Salon', 'address': '901 Massachusetts Ave NW', 'city': 'Washington', 'state': 'DC', 'source': 'manual', 'lat': 38.9023, 'lng': -77.0235},
        {'_id': 'ven_003', 'name': 'Dumbarton House Gardens', 'address': '2715 Q St NW', 'city': 'Washington', 'state': 'DC', 'source': 'places', 'lat': 38.9116, 'lng': -77.0625},
        {'_id': 'ven_004', 'name': 'Four Seasons Terrace', 'address': '2800 Pennsylvania Ave NW', 'city': 'Washington', 'state': 'DC', 'source': 'places', 'lat': 38.9053, 'lng': -77.0595},
        {'_id': 'ven_005', 'name': 'National Building Museum', 'address': '401 F St NW', 'city': 'Washington', 'state': 'DC', 'source': 'places', 'lat': 38.8982, 'lng': -77.0164},
        {'_id': 'ven_006', 'name': 'The Watergate Hotel', 'address': '2650 Virginia Ave NW', 'city': 'Washington', 'state': 'DC', 'source': 'ai', 'lat': 38.8994, 'lng': -77.0556},
      ];

  // ── Cities ────────────────────────────────────────────────────────
  static List<Map<String, dynamic>> get cities => [
        {'_id': 'city_001', 'name': 'Washington', 'state': 'DC', 'country': 'US', 'isTourist': true, 'venueCount': 8},
        {'_id': 'city_002', 'name': 'Arlington', 'state': 'VA', 'country': 'US', 'isTourist': false, 'venueCount': 4},
      ];

  // ── Duplicate Client Groups (for MergeClientsPage) ────────────────
  static List<Map<String, dynamic>> get duplicateClientGroups => [
        {
          'group': [
            {'_id': 'cli_002', 'name': 'Marriott Downtown', 'email': 'catering@marriott.com'},
            {'_id': 'cli_006', 'name': 'Marriott Hotel Downtown', 'email': 'events@marriott.com'},
          ],
          'similarity': 0.92,
        },
        {
          'group': [
            {'_id': 'cli_004', 'name': 'Capital Catering Group', 'email': 'info@capitalcatering.com'},
            {'_id': 'cli_007', 'name': 'Capital Catering', 'email': 'hello@capitalcatering.com'},
          ],
          'similarity': 0.88,
        },
      ];

  // ── Helpers ─────────────────────────────────────────────────────────
  static String _pad(int n) => n.toString().padLeft(2, '0');

  static const _staffNames = [
    'Maria Garcia', 'James Thompson', 'Sofia Rodriguez', 'Alex Kim',
    'Chen Wang', 'Priya Mehta', 'David Brown', 'Emma Wilson',
    'Lucas Santos', 'Aisha Johnson', 'Ryan Park', 'Isabella Rossi',
    'Marcus Lee', 'Fatima Al-Hassan', 'Diego Morales', 'Hannah Chen',
    'Omar Patel', 'Yuki Tanaka', 'Sarah Davis', 'Andre Williams',
  ];

  static const _staffRoles = [
    'Bartender', 'Server', 'Event Coordinator', 'Bartender',
    'Server', 'Runner', 'Server', 'Bartender',
    'Runner', 'Server', 'Barback', 'Event Coordinator',
    'Server', 'Bartender', 'Runner', 'Server',
    'Bartender', 'Server', 'Event Coordinator', 'Server',
  ];

  static List<Map<String, dynamic>> _generateStaffList(int count) {
    return List.generate(
      count,
      (i) => {
        '_id': 'staff_${(i + 1).toString().padLeft(3, '0')}',
        'name': _staffNames[i % _staffNames.length],
        'status': 'accepted',
      },
    );
  }

  /// Detailed staff list with userKey, role, email — for EventDetailScreen etc.
  static List<Map<String, dynamic>> _generateDetailedStaffList(int count) {
    return List.generate(
      count,
      (i) => {
        '_id': 'staff_${(i + 1).toString().padLeft(3, '0')}',
        'userKey': 'google:staff${(i + 1).toString().padLeft(3, '0')}',
        'name': _staffNames[i % _staffNames.length],
        'role': _staffRoles[i % _staffRoles.length],
        'email': '${_staffNames[i % _staffNames.length].split(' ').first.toLowerCase()}@example.com',
        'picture': null,
        'status': 'accepted',
      },
    );
  }
}
