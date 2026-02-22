import 'package:nexa/features/extraction/services/event_service.dart';
import 'package:nexa/features/teams/data/services/teams_service.dart';

class HomeStatsService {
  HomeStatsService()
      : _eventService = EventService(),
        _teamsService = TeamsService();

  final EventService _eventService;
  final TeamsService _teamsService;

  /// Fetch upcoming jobs count (future events starting from now)
  Future<int> fetchUpcomingJobsCount() async {
    try {
      final events = await _eventService.fetchEvents(
        isPast: false,
        status: 'published,confirmed,in_progress',
      );
      return events.length;
    } catch (e) {
      print('Error fetching upcoming jobs count: $e');
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
