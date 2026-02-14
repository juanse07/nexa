/// Dio interceptor that returns canned demo data for all API routes.
///
/// This allows screens that use ApiClient (via Dio) to render with realistic
/// data without any real backend connection.
library;

import 'package:dio/dio.dart';

import '../fixtures/demo_data.dart';

class MockDioInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final path = options.uri.path;
    final method = options.method.toUpperCase();

    // Only intercept GET requests for data fetching; POST/PUT/DELETE return success
    if (method != 'GET') {
      handler.resolve(Response(
        requestOptions: options,
        statusCode: 200,
        data: {'success': true},
      ));
      return;
    }

    // Route to canned responses based on URL path
    final dynamic data = _routeToMockData(path);

    handler.resolve(Response(
      requestOptions: options,
      statusCode: 200,
      data: data,
    ));
  }

  dynamic _routeToMockData(String path) {
    // Normalize: strip /api prefix if present
    final normalized = path.replaceFirst(RegExp(r'^/api'), '');

    // Events
    if (normalized == '/events' || normalized == '/events/sync') {
      return {
        'events': DemoData.events,
        'serverTimestamp': DateTime.now().toIso8601String(),
        'deltaSync': false,
      };
    }

    // Single event detail
    if (RegExp(r'^/events/[^/]+$').hasMatch(normalized) &&
        !normalized.contains('clocked') &&
        !normalized.contains('staff') &&
        !normalized.contains('publish') &&
        !normalized.contains('unpublish') &&
        !normalized.contains('batch') &&
        !normalized.contains('currently')) {
      return DemoData.eventDetailEvent;
    }

    // Events for a specific user
    if (normalized.contains('/events') && normalized.contains('userKey')) {
      return DemoData.events.take(3).toList();
    }

    // Currently clocked in
    if (normalized.contains('currently-clocked-in')) {
      return {'staff': DemoData.clockedInStaff};
    }

    // Clients
    if (normalized == '/clients') {
      return DemoData.clients;
    }

    // Client duplicates
    if (normalized.contains('/clients/duplicates')) {
      return DemoData.duplicateClientGroups;
    }

    // Roles
    if (normalized == '/roles') {
      return DemoData.roles;
    }

    // Tariffs
    if (normalized == '/tariffs') {
      return DemoData.tariffs;
    }

    // Staff list (paginated)
    if (normalized == '/staff') {
      return {
        'staff': DemoData.staffMembers,
        'nextCursor': null,
        'total': DemoData.staffMembers.length,
      };
    }

    // Staff detail
    if (RegExp(r'^/staff/[^/]+$').hasMatch(normalized)) {
      return DemoData.staffDetailMember;
    }

    // Staff hours
    if (normalized.contains('/staff/') && normalized.contains('/hours')) {
      return {
        'totalHours': 247.5,
        'recentShifts': DemoData.events.take(3).toList(),
      };
    }

    // Users (paginated)
    if (normalized == '/users') {
      return {
        'users': DemoData.staffMembers,
        'nextCursor': null,
        'total': DemoData.staffMembers.length,
      };
    }

    // Teams
    if (normalized == '/teams') {
      return DemoData.teams;
    }

    // My team members (used by PendingPublishScreen)
    if (normalized == '/teams/my/members') {
      return {
        'members': DemoData.teamMembers,
        'nextCursor': null,
        'total': DemoData.teamMembers.length,
      };
    }

    // Team members
    if (RegExp(r'^/teams/[^/]+/members$').hasMatch(normalized)) {
      return DemoData.teamMembers;
    }

    // Team invites
    if (RegExp(r'^/teams/[^/]+/invites$').hasMatch(normalized)) {
      return DemoData.teamInvites;
    }

    // Team invite links
    if (RegExp(r'^/teams/[^/]+/invite-links$').hasMatch(normalized)) {
      return DemoData.teamInviteLinks;
    }

    // Manager profile
    if (normalized == '/managers/me') {
      return DemoData.managerProfile;
    }

    // Groups
    if (normalized == '/groups') {
      return DemoData.groups;
    }

    // Conversations (chat)
    if (normalized.contains('/chat/conversations')) {
      return DemoData.conversationsApi;
    }

    // Chat messages
    if (normalized.contains('/chat/messages')) {
      return {'messages': DemoData.chatMessages};
    }

    // Statistics
    if (normalized.contains('/statistics/manager/summary')) {
      return DemoData.managerStatistics;
    }

    // Payroll report
    if (normalized.contains('/statistics/payroll')) {
      return DemoData.payrollReport;
    }

    // Top performers
    if (normalized.contains('/statistics/top-performers')) {
      return DemoData.topPerformers;
    }

    // Attendance analytics
    if (normalized.contains('/attendance/analytics')) {
      return DemoData.attendanceAnalytics;
    }

    // Attendance report
    if (normalized.contains('/attendance/report')) {
      return {'records': DemoData.attendanceRecords};
    }

    // Hours approval events
    if (normalized.contains('/hours-approval') ||
        normalized.contains('/timesheets')) {
      return DemoData.hoursApprovalEvents;
    }

    // Venues
    if (normalized == '/venues') {
      return DemoData.venues;
    }

    // Cities
    if (normalized == '/cities') {
      return DemoData.cities;
    }

    // Subscription status
    if (normalized.contains('/subscription')) {
      return {
        'plan': 'pro',
        'status': 'active',
        'expiresAt': DateTime.now().add(const Duration(days: 365)).toIso8601String(),
      };
    }

    // Drafts
    if (normalized == '/drafts') {
      return [DemoData.draftEvent];
    }

    // Default: empty success
    return <String, dynamic>{};
  }
}
