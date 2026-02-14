/// Gallery app that renders any of 49 screenshot scenarios.
///
/// Each scenario index maps to a specific screen state.
/// Used by the integration test to capture App Store screenshots.
library;

import 'package:flutter/material.dart';

import 'package:nexa/features/extraction/presentation/extraction_screen.dart';
import 'package:nexa/features/events/presentation/event_detail_screen.dart';
// EventEditScreen excluded — has pre-existing syntax error
// MergeClientsPage excluded — references non-existent method
import 'package:nexa/features/extraction/presentation/pending_edit_screen.dart';
import 'package:nexa/features/extraction/presentation/pending_publish_screen.dart';
import 'package:nexa/features/extraction/presentation/staff_detail_screen.dart';
import 'package:nexa/features/extraction/presentation/ai_chat_screen.dart';
import 'package:nexa/features/attendance/presentation/bulk_clock_in_screen.dart';
import 'package:nexa/features/attendance/presentation/flagged_attendance_screen.dart';
import 'package:nexa/features/hours_approval/presentation/hours_approval_list_screen.dart';
import 'package:nexa/features/hours_approval/presentation/hours_approval_screen.dart';
import 'package:nexa/features/hours_approval/presentation/manual_hours_entry_screen.dart';
import 'package:nexa/features/teams/presentation/pages/teams_management_page.dart';
import 'package:nexa/features/teams/presentation/pages/team_detail_page.dart';
import 'package:nexa/features/users/presentation/pages/settings_page.dart';
import 'package:nexa/features/users/presentation/pages/manager_profile_page.dart';
import 'package:nexa/features/auth/presentation/pages/login_page.dart';
import 'package:nexa/features/subscription/presentation/pages/subscription_paywall_page.dart';
import 'package:nexa/screenshot_app.dart';

/// All 49 screenshot scenario definitions.
///
/// Each entry is a (name, builder) pair. The builder returns a widget
/// wrapped in [ScreenshotApp] with the correct locale and providers.
class ScreenshotScenarios {
  ScreenshotScenarios._();

  /// Returns the list of all scenario definitions.
  /// Each tuple is (screenshotName, widgetBuilder).
  static List<(String name, Widget Function(Locale locale) build)>
      get scenarios => [
            // ── Group A: Main Tabs (5) ──────────────────────────────────
            (
              'events_posted',
              (locale) => ScreenshotApp(
                    locale: locale,
                    initialTabIndex: 0,
                  ),
            ),
            (
              'conversations_list',
              (locale) => ScreenshotApp(
                    locale: locale,
                    initialTabIndex: 1,
                  ),
            ),
            (
              'catalog_clients',
              (locale) => ScreenshotApp(
                    locale: locale,
                    initialTabIndex: 2,
                  ),
            ),
            (
              'attendance_dashboard',
              (locale) => ScreenshotApp(
                    locale: locale,
                    initialTabIndex: 3,
                  ),
            ),
            (
              'statistics_dashboard',
              (locale) => ScreenshotApp(
                    locale: locale,
                    initialTabIndex: 4,
                  ),
            ),

            // ── Group B: Events Sub-Tabs (4) ────────────────────────────
            (
              'events_pending',
              (locale) => ScreenshotApp(
                    locale: locale,
                    child: const ExtractionScreen(
                      initialScreenIndex: 1,
                      initialEventsTabIndex: 0,
                      hideNavigationRail: true,
                    ),
                  ),
            ),
            (
              'events_full',
              (locale) => ScreenshotApp(
                    locale: locale,
                    child: const ExtractionScreen(
                      initialScreenIndex: 1,
                      initialEventsTabIndex: 2,
                      hideNavigationRail: true,
                    ),
                  ),
            ),
            (
              'events_completed',
              (locale) => ScreenshotApp(
                    locale: locale,
                    child: const ExtractionScreen(
                      initialScreenIndex: 1,
                      initialEventsTabIndex: 3,
                      hideNavigationRail: true,
                    ),
                  ),
            ),
            (
              'events_search',
              (locale) => ScreenshotApp(
                    locale: locale,
                    initialTabIndex: 0,
                  ),
            ),

            // ── Group C: Event Workflow (5) ──────────────────────────────
            (
              'event_detail',
              (locale) => ScreenshotApp(
                    locale: locale,
                    child: EventDetailScreen(
                      event: _demoEvent,
                    ),
                  ),
            ),
            (
              'event_edit',
              (locale) => ScreenshotApp(
                    locale: locale,
                    child: const _PlaceholderScreen(
                      title: 'Edit Event',
                      subtitle: 'Event edit form with pre-filled fields',
                    ),
                  ),
            ),
            (
              'pending_edit',
              (locale) => ScreenshotApp(
                    locale: locale,
                    child: PendingEditScreen(
                      draft: _demoDraft,
                      draftId: 'draft_001',
                    ),
                  ),
            ),
            (
              'pending_publish',
              (locale) => ScreenshotApp(
                    locale: locale,
                    child: PendingPublishScreen(
                      draft: _demoDraft,
                      draftId: 'draft_001',
                    ),
                  ),
            ),
            (
              'bulk_clock_in',
              (locale) => ScreenshotApp(
                    locale: locale,
                    child: BulkClockInScreen(
                      event: _demoEvent,
                    ),
                  ),
            ),

            // ── Group D: Catalog Sub-Tabs (4) ───────────────────────────
            (
              'catalog_roles',
              (locale) => ScreenshotApp(
                    locale: locale,
                    child: const _CatalogTabScreen(tabIndex: 0),
                  ),
            ),
            (
              'catalog_tariffs',
              (locale) => ScreenshotApp(
                    locale: locale,
                    child: const _CatalogTabScreen(tabIndex: 0),
                  ),
            ),
            (
              'catalog_staff',
              (locale) => ScreenshotApp(
                    locale: locale,
                    child: const _CatalogTabScreen(tabIndex: 0),
                  ),
            ),
            (
              'staff_detail',
              (locale) => ScreenshotApp(
                    locale: locale,
                    child: StaffDetailScreen(
                      staff: _demoStaff,
                    ),
                  ),
            ),

            // ── Group E: Chat & AI (5) ──────────────────────────────────
            (
              'chat_individual',
              (locale) => ScreenshotApp(
                    locale: locale,
                    child: const _PlaceholderScreen(
                      title: 'Chat',
                      subtitle: 'Individual conversation view',
                    ),
                  ),
            ),
            (
              'ai_chat',
              (locale) => ScreenshotApp(
                    locale: locale,
                    child: const AIChatScreen(),
                  ),
            ),
            (
              'ai_chat_event_card',
              (locale) => ScreenshotApp(
                    locale: locale,
                    child: AIChatScreen(
                      eventData: _demoEvent,
                    ),
                  ),
            ),
            (
              'send_invitation_dialog',
              (locale) => ScreenshotApp(
                    locale: locale,
                    child: const _PlaceholderScreen(
                      title: 'Send Invitation',
                      subtitle: 'Event invitation dialog',
                    ),
                  ),
            ),
            (
              'create_invite_link',
              (locale) => ScreenshotApp(
                    locale: locale,
                    child: const _PlaceholderScreen(
                      title: 'Create Invite Link',
                      subtitle: 'Team invite link creation',
                    ),
                  ),
            ),

            // ── Group F: Post a Job (3) ─────────────────────────────────
            (
              'post_job_upload',
              (locale) => ScreenshotApp(
                    locale: locale,
                    child: const ExtractionScreen(
                      initialScreenIndex: 0,
                      initialIndex: 0,
                      hideNavigationRail: true,
                    ),
                  ),
            ),
            (
              'post_job_ai_chat',
              (locale) => ScreenshotApp(
                    locale: locale,
                    child: const ExtractionScreen(
                      initialScreenIndex: 0,
                      initialIndex: 1,
                      hideNavigationRail: true,
                    ),
                  ),
            ),
            (
              'post_job_manual',
              (locale) => ScreenshotApp(
                    locale: locale,
                    child: const ExtractionScreen(
                      initialScreenIndex: 0,
                      initialIndex: 2,
                      hideNavigationRail: true,
                    ),
                  ),
            ),

            // ── Group G: Attendance (4) ─────────────────────────────────
            (
              'attendance_live_grid',
              (locale) => ScreenshotApp(
                    locale: locale,
                    initialTabIndex: 3,
                  ),
            ),
            (
              'attendance_weekly_chart',
              (locale) => ScreenshotApp(
                    locale: locale,
                    initialTabIndex: 3,
                  ),
            ),
            (
              'flagged_attendance',
              (locale) => ScreenshotApp(
                    locale: locale,
                    child: const FlaggedAttendanceScreen(),
                  ),
            ),
            (
              'hours_approval_list',
              (locale) => ScreenshotApp(
                    locale: locale,
                    child: const HoursApprovalListScreen(),
                  ),
            ),

            // ── Group H: Hours Approval (2) ─────────────────────────────
            (
              'hours_approval',
              (locale) => ScreenshotApp(
                    locale: locale,
                    child: HoursApprovalScreen(
                      event: _demoCompletedEvent,
                    ),
                  ),
            ),
            (
              'manual_hours_entry',
              (locale) => ScreenshotApp(
                    locale: locale,
                    child: ManualHoursEntryScreen(
                      event: _demoCompletedEvent,
                    ),
                  ),
            ),

            // ── Group I: Teams (3) ──────────────────────────────────────
            (
              'teams_management',
              (locale) => ScreenshotApp(
                    locale: locale,
                    child: const TeamsManagementPage(),
                  ),
            ),
            (
              'team_detail',
              (locale) => ScreenshotApp(
                    locale: locale,
                    child: const TeamDetailPage(
                      teamId: 'team_001',
                      teamName: 'DC Metro Team',
                    ),
                  ),
            ),
            (
              'merge_clients',
              (locale) => ScreenshotApp(
                    locale: locale,
                    child: const _PlaceholderScreen(
                      title: 'Merge Clients',
                      subtitle: 'Merge duplicate clients page',
                    ),
                  ),
            ),

            // ── Group J: Settings & Profile (4) ─────────────────────────
            (
              'settings',
              (locale) => ScreenshotApp(
                    locale: locale,
                    child: const SettingsPage(),
                  ),
            ),
            (
              'manager_profile',
              (locale) => ScreenshotApp(
                    locale: locale,
                    child: const ManagerProfilePage(),
                  ),
            ),
            (
              'brand_customization',
              (locale) => ScreenshotApp(
                    locale: locale,
                    child: const SettingsPage(),
                  ),
            ),
            (
              'venue_list',
              (locale) => ScreenshotApp(
                    locale: locale,
                    child: const _PlaceholderScreen(
                      title: 'Venues',
                      subtitle: 'Tabbed venue list by city',
                    ),
                  ),
            ),

            // ── Group K: Onboarding & Auth (3) ──────────────────────────
            (
              'login_page',
              (locale) => ScreenshotApp(
                    locale: locale,
                    child: const LoginPage(),
                  ),
            ),
            (
              'onboarding_city',
              (locale) => ScreenshotApp(
                    locale: locale,
                    child: const _PlaceholderScreen(
                      title: 'Select Your City',
                      subtitle: 'City selection during onboarding',
                    ),
                  ),
            ),
            (
              'subscription_paywall',
              (locale) => ScreenshotApp(
                    locale: locale,
                    child: const SubscriptionPaywallPage(),
                  ),
            ),

            // ── Group L: Statistics Detail (3) ──────────────────────────
            (
              'stats_leaderboard',
              (locale) => ScreenshotApp(
                    locale: locale,
                    initialTabIndex: 4,
                  ),
            ),
            (
              'stats_payroll',
              (locale) => ScreenshotApp(
                    locale: locale,
                    initialTabIndex: 4,
                  ),
            ),
            (
              'stats_export',
              (locale) => ScreenshotApp(
                    locale: locale,
                    initialTabIndex: 4,
                  ),
            ),

            // ── Group M: Dialogs & Modals (4) ──────────────────────────
            (
              'brand_color_picker',
              (locale) => ScreenshotApp(
                    locale: locale,
                    child: const _PlaceholderScreen(
                      title: 'Brand Colors',
                      subtitle: 'Color picker dialog',
                    ),
                  ),
            ),
            (
              'batch_event_import',
              (locale) => ScreenshotApp(
                    locale: locale,
                    child: const _PlaceholderScreen(
                      title: 'Batch Import',
                      subtitle: 'Batch event creation from documents',
                    ),
                  ),
            ),
            (
              'event_confirmation',
              (locale) => ScreenshotApp(
                    locale: locale,
                    child: const _PlaceholderScreen(
                      title: 'Confirm Event',
                      subtitle: 'Event publish confirmation card',
                    ),
                  ),
            ),
            (
              'caricature_generator',
              (locale) => ScreenshotApp(
                    locale: locale,
                    child: const ManagerProfilePage(),
                  ),
            ),
          ];

  // ── Demo data shortcuts ─────────────────────────────────────────
  static Map<String, dynamic> get _demoEvent {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    return {
      '_id': 'evt_001',
      'event_name': 'Annual Gala Dinner',
      'title': 'Annual Gala Dinner',
      'client_name': 'Grand Ballroom Events',
      'client': {'_id': 'cli_001', 'name': 'Grand Ballroom Events'},
      'venue_name': 'The Ritz-Carlton Ballroom',
      'venue': 'The Ritz-Carlton Ballroom',
      'venue_address': '1150 22nd St NW, Washington, DC 20037',
      'address': '1150 22nd St NW, Washington, DC 20037',
      'date': tomorrow.toIso8601String(),
      'callTime':
          '${tomorrow.year}-${tomorrow.month.toString().padLeft(2, '0')}-${tomorrow.day.toString().padLeft(2, '0')}T16:00:00.000Z',
      'endTime':
          '${tomorrow.year}-${tomorrow.month.toString().padLeft(2, '0')}-${tomorrow.day.toString().padLeft(2, '0')}T23:30:00.000Z',
      'start_time': '16:00',
      'end_time': '23:30',
      'status': 'posted',
      'headcount_total': 12,
      'staffNeeded': 12,
      'accepted_staff': _demoStaffList(8),
      'acceptedStaff': _demoStaffList(8),
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

  static Map<String, dynamic> get _demoDraft {
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
      'callTime': inThreeDays.toIso8601String(),
      'endTime': inThreeDays.add(const Duration(hours: 8)).toIso8601String(),
      'start_time': '14:00',
      'end_time': '22:00',
      'status': 'pending',
      'headcount_total': 15,
      'staffNeeded': 15,
      'roles': [
        {'role': 'Server', 'count': 8},
        {'role': 'Bartender', 'count': 3},
        {'role': 'Event Coordinator', 'count': 2},
        {'role': 'Runner', 'count': 2},
      ],
      'notes': 'Outdoor wedding ceremony + indoor reception.',
      'compensation': {'type': 'hourly', 'rate': 30.00},
    };
  }

  static Map<String, dynamic> get _demoCompletedEvent {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return {
      '_id': 'evt_006',
      'event_name': 'Wine Tasting Evening',
      'title': 'Wine Tasting Evening',
      'client_name': 'Marriott Downtown',
      'client': {'_id': 'cli_002', 'name': 'Marriott Downtown'},
      'venue_name': 'Marriott Rooftop Lounge',
      'venue': 'Marriott Rooftop Lounge',
      'date': yesterday.toIso8601String(),
      'status': 'completed',
      'staffNeeded': 4,
      'accepted_staff': _demoStaffList(4),
      'acceptedStaff': _demoStaffList(4),
      'roles': [
        {'role': 'Bartender', 'count': 2},
        {'role': 'Server', 'count': 2},
      ],
    };
  }

  static Map<String, dynamic> get _demoStaff => {
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
        'notes': 'Excellent bartender. Great with guests.',
        'provider': 'google',
        'subject': 'staff001',
      };

  static const _names = [
    'Maria Garcia',
    'James Thompson',
    'Sofia Rodriguez',
    'Alex Kim',
    'Chen Wang',
    'Priya Mehta',
    'David Brown',
    'Emma Wilson',
    'Lucas Santos',
    'Aisha Johnson',
    'Ryan Park',
    'Isabella Rossi',
  ];

  static List<Map<String, dynamic>> _demoStaffList(int count) {
    return List.generate(
      count,
      (i) => {
            '_id': 'staff_${(i + 1).toString().padLeft(3, '0')}',
            'userKey': 'google:staff${(i + 1).toString().padLeft(3, '0')}',
            'name': _names[i % _names.length],
            'picture': null,
            'status': 'accepted',
          },
    );
  }
}

/// Helper widget to show a specific Catalog sub-tab.
class _CatalogTabScreen extends StatelessWidget {
  final int tabIndex;
  const _CatalogTabScreen({required this.tabIndex});

  @override
  Widget build(BuildContext context) {
    // ExtractionScreen index 4 = Catalog, with sub-tab from initialIndex
    return ExtractionScreen(
      initialScreenIndex: 4,
      initialIndex: tabIndex,
      hideNavigationRail: true,
    );
  }
}

/// Placeholder screen for scenarios that need complex dialog/modal setup.
/// These will be replaced with real implementations incrementally.
class _PlaceholderScreen extends StatelessWidget {
  final String title;
  final String subtitle;

  const _PlaceholderScreen({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.camera_alt_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
