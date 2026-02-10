import 'package:dio/dio.dart';
import 'package:nexa/core/network/api_client.dart';
import 'package:nexa/core/di/injection.dart';

class StaffService {
  StaffService() : _apiClient = getIt<ApiClient>();

  final ApiClient _apiClient;

  Future<Map<String, dynamic>> fetchStaff({
    String? q,
    bool? favorite,
    String? cursor,
    String? groupId,
    int limit = 50,
  }) async {
    final params = <String, String>{'limit': '$limit'};
    if (q != null && q.trim().isNotEmpty) params['q'] = q.trim();
    if (favorite == true) params['favorite'] = 'true';
    if (cursor != null && cursor.isNotEmpty) params['cursor'] = cursor;
    if (groupId != null && groupId.isNotEmpty) params['groupId'] = groupId;

    try {
      final response = await _apiClient.get<Map<String, dynamic>>(
        '/staff',
        queryParameters: params,
      );

      if (response.statusCode != null &&
          response.statusCode! >= 200 &&
          response.statusCode! < 300) {
        return response.data ?? {};
      }

      throw Exception(
        'Failed to load staff (${response.statusCode}): ${response.data}',
      );
    } on DioException catch (e) {
      throw Exception('Failed to load staff: ${e.message}');
    }
  }

  Future<Map<String, dynamic>> fetchStaffDetail(String userKey) async {
    final encoded = Uri.encodeComponent(userKey);
    try {
      final response = await _apiClient.get<Map<String, dynamic>>(
        '/staff/$encoded',
      );

      if (response.statusCode != null &&
          response.statusCode! >= 200 &&
          response.statusCode! < 300) {
        return response.data ?? {};
      }

      throw Exception(
        'Failed to load staff detail (${response.statusCode})',
      );
    } on DioException catch (e) {
      throw Exception('Failed to load staff detail: ${e.message}');
    }
  }

  Future<Map<String, dynamic>> fetchStaffHours(String userKey) async {
    final encoded = Uri.encodeComponent(userKey);
    try {
      final response = await _apiClient.get<Map<String, dynamic>>(
        '/staff/$encoded/hours',
      );

      if (response.statusCode != null &&
          response.statusCode! >= 200 &&
          response.statusCode! < 300) {
        return response.data ?? {};
      }

      throw Exception(
        'Failed to load staff hours (${response.statusCode})',
      );
    } on DioException catch (e) {
      throw Exception('Failed to load staff hours: ${e.message}');
    }
  }

  Future<Map<String, dynamic>> updateStaffProfile(
    String userKey, {
    String? notes,
    double? rating,
    bool? isFavorite,
  }) async {
    final encoded = Uri.encodeComponent(userKey);
    final body = <String, dynamic>{};
    if (notes != null) body['notes'] = notes;
    if (rating != null) body['rating'] = rating;
    if (isFavorite != null) body['isFavorite'] = isFavorite;

    try {
      final response = await _apiClient.patch<Map<String, dynamic>>(
        '/staff/$encoded',
        data: body,
      );

      if (response.statusCode != null &&
          response.statusCode! >= 200 &&
          response.statusCode! < 300) {
        return response.data ?? {};
      }

      throw Exception(
        'Failed to update staff profile (${response.statusCode})',
      );
    } on DioException catch (e) {
      throw Exception('Failed to update staff profile: ${e.message}');
    }
  }
}
