import 'package:nexa/core/di/injection.dart';
import 'package:nexa/core/network/api_client.dart';
import 'package:nexa/features/teams/data/services/teams_service.dart';

class HomeStatsService {
  HomeStatsService()
      : _apiClient = getIt<ApiClient>(),
        _teamsService = TeamsService();

  final ApiClient _apiClient;
  final TeamsService _teamsService;

  /// Fetch upcoming jobs count (future events starting from now)
  Future<int> fetchUpcomingJobsCount() async {
    try {
      final response = await _apiClient.get('/events');
      print('📊 Events API Response: ${response.data}');

      if (response.data is Map<String, dynamic>) {
        final events = response.data['events'] as List?;
        print('📊 Total events found: ${events?.length ?? 0}');

        if (events == null || events.isEmpty) return 0;

        // Print first event structure to debug
        if (events.isNotEmpty) {
          print('📊 First event structure: ${events.first}');
        }

        // Filter for upcoming events (future events)
        final now = DateTime.now();
        print('📊 Current time: $now');

        final upcomingEvents = events.where((event) {
          if (event is! Map<String, dynamic>) return false;

          // Try different possible date field names
          final startDateStr = event['start_date']?.toString() ??
                              event['startDate']?.toString() ??
                              event['date']?.toString() ??
                              event['event_date']?.toString();

          if (startDateStr == null) {
            print('📊 Event missing date: ${event['id'] ?? 'unknown'}');
            return false;
          }

          try {
            final startDate = DateTime.parse(startDateStr);
            final isUpcoming = startDate.isAfter(now);
            print('📊 Event ${event['event_name'] ?? event['name'] ?? 'unknown'}: $startDateStr -> $isUpcoming');
            return isUpcoming;
          } catch (e) {
            print('📊 Failed to parse date: $startDateStr - Error: $e');
            return false;
          }
        }).toList();

        print('📊 Upcoming events count: ${upcomingEvents.length}');
        return upcomingEvents.length;
      }
      return 0;
    } catch (e) {
      print('❌ Error fetching upcoming jobs count: $e');
      return 0;
    }
  }

  /// Fetch team name (first team's name)
  Future<String> fetchTeamName() async {
    try {
      final teams = await _teamsService.fetchTeams();
      if (teams.isNotEmpty) {
        return teams.first['name']?.toString() ?? 'My Team';
      }
      return 'My Team';
    } catch (e) {
      print('Error fetching team name: $e');
      return 'My Team';
    }
  }

  /// Fetch total team members count across all teams
  Future<int> fetchTeamMembersCount() async {
    try {
      final teams = await _teamsService.fetchTeams();
      int totalMembers = 0;

      for (final team in teams) {
        final teamId = team['id']?.toString();
        if (teamId != null) {
          final members = await _teamsService.fetchMembers(teamId);
          totalMembers += members.length;
        }
      }

      return totalMembers;
    } catch (e) {
      print('Error fetching team members count: $e');
      return 0;
    }
  }

  /// Fetch hours for this week
  Future<int> fetchThisWeekHours() async {
    try {
      // TODO: Implement hours API endpoint
      // For now, return 0 as placeholder
      print('⏰ Hours endpoint not yet implemented');
      return 0;
    } catch (e) {
      print('Error fetching week hours: $e');
      return 0;
    }
  }
}
