import 'package:dio/dio.dart';
import 'package:nexa/core/network/api_client.dart';
import 'package:nexa/core/di/injection.dart';

class GroupService {
  GroupService() : _apiClient = getIt<ApiClient>();

  final ApiClient _apiClient;

  Future<List<Map<String, dynamic>>> fetchGroups() async {
    try {
      final response = await _apiClient.get<Map<String, dynamic>>('/groups');

      if (response.statusCode != null &&
          response.statusCode! >= 200 &&
          response.statusCode! < 300) {
        final data = response.data ?? {};
        final items = (data['items'] as List<dynamic>?) ?? [];
        return items.map((e) => e as Map<String, dynamic>).toList();
      }

      throw Exception('Failed to load groups (${response.statusCode})');
    } on DioException catch (e) {
      throw Exception('Failed to load groups: ${e.message}');
    }
  }

  Future<Map<String, dynamic>> createGroup(String name, {String? color}) async {
    try {
      final body = <String, dynamic>{'name': name};
      if (color != null) body['color'] = color;

      final response = await _apiClient.post<Map<String, dynamic>>(
        '/groups',
        data: body,
      );

      if (response.statusCode != null &&
          response.statusCode! >= 200 &&
          response.statusCode! < 300) {
        return response.data ?? {};
      }

      throw Exception('Failed to create group (${response.statusCode})');
    } on DioException catch (e) {
      throw Exception('Failed to create group: ${e.message}');
    }
  }

  Future<Map<String, dynamic>> updateGroup(
    String groupId, {
    String? name,
    String? color,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (name != null) body['name'] = name;
      if (color != null) body['color'] = color;

      final response = await _apiClient.patch<Map<String, dynamic>>(
        '/groups/$groupId',
        data: body,
      );

      if (response.statusCode != null &&
          response.statusCode! >= 200 &&
          response.statusCode! < 300) {
        return response.data ?? {};
      }

      throw Exception('Failed to update group (${response.statusCode})');
    } on DioException catch (e) {
      throw Exception('Failed to update group: ${e.message}');
    }
  }

  Future<void> deleteGroup(String groupId) async {
    try {
      final response = await _apiClient.delete('/groups/$groupId');

      if (response.statusCode != null &&
          response.statusCode! >= 200 &&
          response.statusCode! < 300) {
        return;
      }

      throw Exception('Failed to delete group (${response.statusCode})');
    } on DioException catch (e) {
      throw Exception('Failed to delete group: ${e.message}');
    }
  }

  Future<void> addMembers(String groupId, List<String> userKeys) async {
    try {
      final response = await _apiClient.post<Map<String, dynamic>>(
        '/groups/$groupId/members',
        data: {'userKeys': userKeys},
      );

      if (response.statusCode != null &&
          response.statusCode! >= 200 &&
          response.statusCode! < 300) {
        return;
      }

      throw Exception('Failed to add members (${response.statusCode})');
    } on DioException catch (e) {
      throw Exception('Failed to add members: ${e.message}');
    }
  }

  Future<void> removeMember(String groupId, String userKey) async {
    final encoded = Uri.encodeComponent(userKey);
    try {
      final response = await _apiClient.delete(
        '/groups/$groupId/members/$encoded',
      );

      if (response.statusCode != null &&
          response.statusCode! >= 200 &&
          response.statusCode! < 300) {
        return;
      }

      throw Exception('Failed to remove member (${response.statusCode})');
    } on DioException catch (e) {
      throw Exception('Failed to remove member: ${e.message}');
    }
  }
}
