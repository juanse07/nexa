import 'package:dio/dio.dart';
import 'package:nexa/core/network/api_client.dart';
import 'package:nexa/core/di/injection.dart';

class RolesService {
  RolesService() : _apiClient = getIt<ApiClient>();

  final ApiClient _apiClient;

  Future<List<Map<String, dynamic>>> fetchRoles() async {
    try {
      final response = await _apiClient.get('/roles');

      if (response.statusCode != null &&
          response.statusCode! >= 200 &&
          response.statusCode! < 300) {
        final dynamic decoded = response.data;
        if (decoded is List) {
          return decoded
              .whereType<Map<String, dynamic>>()
              .map((e) => e)
              .toList(growable: false);
        }
        return const <Map<String, dynamic>>[];
      }
      throw Exception(
        'Failed to load roles (${response.statusCode}): ${response.data}',
      );
    } on DioException catch (e) {
      throw Exception('Failed to load roles: ${e.message}');
    }
  }

  Future<Map<String, dynamic>> createRole(String name) async {
    try {
      final response = await _apiClient.post(
        '/roles',
        data: {'name': name},
      );

      if (response.statusCode != null &&
          response.statusCode! >= 200 &&
          response.statusCode! < 300) {
        return response.data as Map<String, dynamic>;
      }
      throw Exception(
        'Failed to create role (${response.statusCode}): ${response.data}',
      );
    } on DioException catch (e) {
      throw Exception('Failed to create role: ${e.message}');
    }
  }

  Future<void> renameRole(String id, String name) async {
    try {
      final response = await _apiClient.patch(
        '/roles/$id',
        data: {'name': name},
      );

      if (response.statusCode == null ||
          response.statusCode! < 200 ||
          response.statusCode! >= 300) {
        throw Exception(
          'Failed to rename role (${response.statusCode}): ${response.data}',
        );
      }
    } on DioException catch (e) {
      throw Exception('Failed to rename role: ${e.message}');
    }
  }

  Future<void> deleteRole(String id) async {
    try {
      final response = await _apiClient.delete('/roles/$id');

      if (response.statusCode == null ||
          response.statusCode! < 200 ||
          response.statusCode! >= 300) {
        throw Exception(
          'Failed to delete role (${response.statusCode}): ${response.data}',
        );
      }
    } on DioException catch (e) {
      throw Exception('Failed to delete role: ${e.message}');
    }
  }
}
