import 'package:dio/dio.dart';
import 'package:nexa/core/network/api_client.dart';
import 'package:nexa/core/di/injection.dart';

class UsersService {
  UsersService() : _apiClient = getIt<ApiClient>();

  final ApiClient _apiClient;

  Future<Map<String, dynamic>> fetchUsers({
    String? q,
    String? cursor,
    int limit = 20,
  }) async {
    final params = <String, String>{'limit': '$limit'};
    if (q != null && q.trim().isNotEmpty) params['q'] = q.trim();
    if (cursor != null && cursor.isNotEmpty) params['cursor'] = cursor;

    try {
      final response = await _apiClient.get<Map<String, dynamic>>(
        '/users',
        queryParameters: params,
      );

      if (response.statusCode != null &&
          response.statusCode! >= 200 &&
          response.statusCode! < 300) {
        return response.data ?? {};
      }

      throw Exception(
        'Failed to load users (${response.statusCode}): ${response.data}',
      );
    } on DioException catch (e) {
      throw Exception(
        'Failed to load users: ${e.message}',
      );
    }
  }

  Future<Map<String, dynamic>> fetchTeamMembers({
    String? q,
    String? cursor,
    int limit = 20,
  }) async {
    final params = <String, String>{'limit': '$limit'};
    if (q != null && q.trim().isNotEmpty) params['q'] = q.trim();
    if (cursor != null && cursor.isNotEmpty) params['cursor'] = cursor;

    try {
      final response = await _apiClient.get<Map<String, dynamic>>(
        '/teams/my/members',
        queryParameters: params,
      );

      if (response.statusCode != null &&
          response.statusCode! >= 200 &&
          response.statusCode! < 300) {
        return response.data ?? {};
      }

      throw Exception(
        'Failed to load team members (${response.statusCode}): ${response.data}',
      );
    } on DioException catch (e) {
      throw Exception(
        'Failed to load team members: ${e.message}',
      );
    }
  }
}
