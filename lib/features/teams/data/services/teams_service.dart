import 'package:dio/dio.dart';
import 'package:nexa/core/di/injection.dart';
import 'package:nexa/core/network/api_client.dart';

class TeamsService {
  TeamsService() : _apiClient = getIt<ApiClient>();

  final ApiClient _apiClient;

  Future<List<Map<String, dynamic>>> fetchTeams() async {
    try {
      print('[TeamsService.fetchTeams] Starting request...');
      final response = await _apiClient.get('/teams');
      print('[TeamsService.fetchTeams] Response status: ${response.statusCode}');
      print('[TeamsService.fetchTeams] Response data type: ${response.data.runtimeType}');
      print('[TeamsService.fetchTeams] Response data: ${response.data}');

      if (_isSuccess(response.statusCode)) {
        final dynamic data = response.data;
        if (data is Map<String, dynamic>) {
          final dynamic teams = data['teams'];
          print('[TeamsService.fetchTeams] Teams field type: ${teams.runtimeType}');
          if (teams is List) {
            print('[TeamsService.fetchTeams] Found ${teams.length} teams');
            return teams.whereType<Map<String, dynamic>>().toList(
              growable: false,
            );
          }
        } else if (data is List) {
          // Handle case where response is directly a list
          print('[TeamsService.fetchTeams] Response is directly a list with ${data.length} items');
          return data.whereType<Map<String, dynamic>>().toList(growable: false);
        }
        print('[TeamsService.fetchTeams] No teams found, returning empty list');
        return const <Map<String, dynamic>>[];
      }
      print('[TeamsService.fetchTeams] ✗ Non-success status: ${response.statusCode}');
      throw Exception('Failed to fetch teams (${response.statusCode})');
    } on DioException catch (e) {
      print('[TeamsService.fetchTeams] ✗ DioException: ${e.type}');
      print('[TeamsService.fetchTeams] ✗ Message: ${e.message}');
      print('[TeamsService.fetchTeams] ✗ Response: ${e.response?.data}');
      print('[TeamsService.fetchTeams] ✗ Status code: ${e.response?.statusCode}');
      throw Exception('Failed to fetch teams: ${e.message}');
    } catch (e, stackTrace) {
      print('[TeamsService.fetchTeams] ✗ Unexpected error: $e');
      print('[TeamsService.fetchTeams] ✗ Stack trace: $stackTrace');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> createTeam({
    required String name,
    String? description,
  }) async {
    try {
      final response = await _apiClient.post(
        '/teams',
        data: {
          'name': name,
          if (description != null && description.trim().isNotEmpty)
            'description': description.trim(),
        },
      );
      if (_isSuccess(response.statusCode)) {
        return Map<String, dynamic>.from(response.data as Map);
      }
      throw Exception('Failed to create team (${response.statusCode})');
    } on DioException catch (e) {
      throw Exception('Failed to create team: ${e.message}');
    }
  }

  Future<void> deleteTeam(String teamId) async {
    try {
      final response = await _apiClient.delete('/teams/$teamId');
      if (!_isSuccess(response.statusCode)) {
        throw Exception('Failed to delete team (${response.statusCode})');
      }
    } on DioException catch (e) {
      throw Exception('Failed to delete team: ${e.message}');
    }
  }

  Future<List<Map<String, dynamic>>> fetchMembers(String teamId) async {
    try {
      final response = await _apiClient.get('/teams/$teamId/members');
      if (_isSuccess(response.statusCode)) {
        final dynamic data = response.data;
        if (data is Map<String, dynamic>) {
          final dynamic members = data['members'];
          if (members is List) {
            return members.whereType<Map<String, dynamic>>().toList(
              growable: false,
            );
          }
        }
        return const <Map<String, dynamic>>[];
      }
      throw Exception('Failed to fetch members (${response.statusCode})');
    } on DioException catch (e) {
      throw Exception('Failed to fetch members: ${e.message}');
    }
  }

  Future<List<Map<String, dynamic>>> fetchInvites(String teamId) async {
    try {
      final response = await _apiClient.get('/teams/$teamId/invites');
      if (_isSuccess(response.statusCode)) {
        final dynamic data = response.data;
        if (data is Map<String, dynamic>) {
          final dynamic invites = data['invites'];
          if (invites is List) {
            return invites.whereType<Map<String, dynamic>>().toList(
              growable: false,
            );
          }
        }
        return const <Map<String, dynamic>>[];
      }
      throw Exception('Failed to fetch invites (${response.statusCode})');
    } on DioException catch (e) {
      throw Exception('Failed to fetch invites: ${e.message}');
    }
  }

  Future<void> removeMember({
    required String teamId,
    required String memberId,
  }) async {
    try {
      final response = await _apiClient.delete(
        '/teams/$teamId/members/$memberId',
      );
      if (!_isSuccess(response.statusCode)) {
        throw Exception('Failed to remove member (${response.statusCode})');
      }
    } on DioException catch (e) {
      throw Exception('Failed to remove member: ${e.message}');
    }
  }

  Future<void> addMember({
    required String teamId,
    required String provider,
    required String subject,
    String? email,
    String? name,
  }) async {
    try {
      final response = await _apiClient.post(
        '/teams/$teamId/members',
        data: {
          'provider': provider,
          'subject': subject,
          if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
          if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
        },
      );
      if (!_isSuccess(response.statusCode)) {
        throw Exception('Failed to add member (${response.statusCode})');
      }
    } on DioException catch (e) {
      throw Exception('Failed to add member: ${e.message}');
    }
  }

  Future<List<Map<String, dynamic>>> createInvites({
    required String teamId,
    required List<Map<String, String>> recipients,
    int? expiresInDays,
    String? message,
  }) async {
    try {
      final response = await _apiClient.post(
        '/teams/$teamId/invites',
        data: {
          'recipients': recipients,
          if (expiresInDays != null) 'expiresInDays': expiresInDays,
          if (message != null && message.trim().isNotEmpty)
            'message': message.trim(),
        },
      );
      if (_isSuccess(response.statusCode)) {
        final dynamic data = response.data;
        if (data is Map<String, dynamic>) {
          final dynamic invites = data['invites'];
          if (invites is List) {
            return invites.whereType<Map<String, dynamic>>().toList(
              growable: false,
            );
          }
        }
        return const <Map<String, dynamic>>[];
      }
      throw Exception('Failed to create invites (${response.statusCode})');
    } on DioException catch (e) {
      throw Exception('Failed to create invites: ${e.message}');
    }
  }

  Future<void> cancelInvite({
    required String teamId,
    required String inviteId,
  }) async {
    try {
      final response = await _apiClient.post(
        '/teams/$teamId/invites/$inviteId/cancel',
      );
      if (!_isSuccess(response.statusCode)) {
        throw Exception('Failed to cancel invite (${response.statusCode})');
      }
    } on DioException catch (e) {
      throw Exception('Failed to cancel invite: ${e.message}');
    }
  }

  /// Create a shareable invite link for a team
  Future<Map<String, dynamic>> createInviteLink({
    required String teamId,
    int? expiresInDays,
    int? maxUses,
    bool requireApproval = false,
    String? password,
  }) async {
    try {
      final response = await _apiClient.post(
        '/teams/$teamId/invites/create-link',
        data: {
          if (expiresInDays != null) 'expiresInDays': expiresInDays,
          if (maxUses != null) 'maxUses': maxUses,
          'requireApproval': requireApproval,
          if (password != null) 'password': password,
        },
      );
      if (_isSuccess(response.statusCode)) {
        return Map<String, dynamic>.from(response.data as Map);
      }
      throw Exception('Failed to create invite link (${response.statusCode})');
    } on DioException catch (e) {
      throw Exception('Failed to create invite link: ${e.message}');
    }
  }

  /// Fetch all shareable invite links for a team
  Future<List<Map<String, dynamic>>> fetchInviteLinks(String teamId) async {
    try {
      final response = await _apiClient.get('/teams/$teamId/invites/links');
      if (_isSuccess(response.statusCode)) {
        final dynamic data = response.data;
        if (data is Map<String, dynamic>) {
          final dynamic invites = data['invites'];
          if (invites is List) {
            return invites.whereType<Map<String, dynamic>>().toList(
              growable: false,
            );
          }
        }
        return const <Map<String, dynamic>>[];
      }
      throw Exception('Failed to fetch invite links (${response.statusCode})');
    } on DioException catch (e) {
      throw Exception('Failed to fetch invite links: ${e.message}');
    }
  }

  /// Revoke an invite link
  Future<void> revokeInviteLink(String teamId, String inviteId) async {
    try {
      final response = await _apiClient.patch(
        '/teams/$teamId/invites/$inviteId/revoke',
        data: {},
      );
      if (!_isSuccess(response.statusCode)) {
        throw Exception('Failed to revoke invite link (${response.statusCode})');
      }
    } on DioException catch (e) {
      throw Exception('Failed to revoke invite link: ${e.message}');
    }
  }

  /// Fetch usage audit log for an invite link
  Future<Map<String, dynamic>> fetchInviteUsage(String teamId, String inviteId) async {
    try {
      final response = await _apiClient.get('/teams/$teamId/invites/$inviteId/usage');
      if (_isSuccess(response.statusCode)) {
        return Map<String, dynamic>.from(response.data as Map);
      }
      throw Exception('Failed to fetch invite usage (${response.statusCode})');
    } on DioException catch (e) {
      throw Exception('Failed to fetch invite usage: ${e.message}');
    }
  }

  /// Create a public recruitment link for a team
  Future<Map<String, dynamic>> createPublicLink(String teamId) async {
    try {
      final response = await _apiClient.post(
        '/teams/$teamId/invites/create-public-link',
        data: {},
      );
      if (_isSuccess(response.statusCode)) {
        return Map<String, dynamic>.from(response.data as Map);
      }
      throw Exception('Failed to create public link (${response.statusCode})');
    } on DioException catch (e) {
      throw Exception('Failed to create public link: ${e.message}');
    }
  }

  /// Fetch applicants for a team
  Future<List<Map<String, dynamic>>> fetchApplicants(
    String teamId, {
    String status = 'pending',
  }) async {
    try {
      final response = await _apiClient.get(
        '/teams/$teamId/applicants',
        queryParameters: {'status': status},
      );
      if (_isSuccess(response.statusCode)) {
        final dynamic data = response.data;
        if (data is Map<String, dynamic>) {
          final dynamic applicants = data['applicants'];
          if (applicants is List) {
            return applicants.whereType<Map<String, dynamic>>().toList(
              growable: false,
            );
          }
        }
        return const <Map<String, dynamic>>[];
      }
      throw Exception('Failed to fetch applicants (${response.statusCode})');
    } on DioException catch (e) {
      throw Exception('Failed to fetch applicants: ${e.message}');
    }
  }

  /// Approve an applicant
  Future<void> approveApplicant(String teamId, String applicantId) async {
    try {
      final response = await _apiClient.post(
        '/teams/$teamId/applicants/$applicantId/approve',
        data: {},
      );
      if (!_isSuccess(response.statusCode)) {
        throw Exception('Failed to approve applicant (${response.statusCode})');
      }
    } on DioException catch (e) {
      throw Exception('Failed to approve applicant: ${e.message}');
    }
  }

  /// Deny an applicant
  Future<void> denyApplicant(String teamId, String applicantId) async {
    try {
      final response = await _apiClient.post(
        '/teams/$teamId/applicants/$applicantId/deny',
        data: {},
      );
      if (!_isSuccess(response.statusCode)) {
        throw Exception('Failed to deny applicant (${response.statusCode})');
      }
    } on DioException catch (e) {
      throw Exception('Failed to deny applicant: ${e.message}');
    }
  }

  /// Fetch availability for all team members
  Future<List<Map<String, dynamic>>> fetchMembersAvailability() async {
    try {
      final response = await _apiClient.get('/teams/members/availability');
      if (_isSuccess(response.statusCode)) {
        final dynamic data = response.data;
        if (data is Map<String, dynamic>) {
          final dynamic availability = data['availability'];
          if (availability is List) {
            return availability.whereType<Map<String, dynamic>>().toList(
              growable: false,
            );
          }
        }
        return const <Map<String, dynamic>>[];
      }
      throw Exception('Failed to fetch members availability (${response.statusCode})');
    } on DioException catch (e) {
      throw Exception('Failed to fetch members availability: ${e.message}');
    }
  }

  bool _isSuccess(int? statusCode) {
    if (statusCode == null) return false;
    return statusCode >= 200 && statusCode < 300;
  }
}
