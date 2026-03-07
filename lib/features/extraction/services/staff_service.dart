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
    String? role,
    String? skill,
    int limit = 50,
  }) async {
    final params = <String, String>{'limit': '$limit'};
    if (q != null && q.trim().isNotEmpty) params['q'] = q.trim();
    if (favorite == true) params['favorite'] = 'true';
    if (cursor != null && cursor.isNotEmpty) params['cursor'] = cursor;
    if (groupId != null && groupId.isNotEmpty) params['groupId'] = groupId;
    if (role != null && role.trim().isNotEmpty) params['role'] = role.trim();
    if (skill != null && skill.trim().isNotEmpty) params['skill'] = skill.trim();

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

  Future<Map<String, dynamic>> fetchVenueHistory(String userKey) async {
    final encoded = Uri.encodeComponent(userKey);
    try {
      final response = await _apiClient.get<Map<String, dynamic>>(
        '/staff/$encoded/venue-history',
      );

      if (response.statusCode != null &&
          response.statusCode! >= 200 &&
          response.statusCode! < 300) {
        return response.data ?? {};
      }

      throw Exception(
        'Failed to load venue history (${response.statusCode})',
      );
    } on DioException catch (e) {
      throw Exception('Failed to load venue history: ${e.message}');
    }
  }

  Future<Map<String, dynamic>> updateStaffProfile(
    String userKey, {
    String? notes,
    double? rating,
    bool? isFavorite,
    String? externalEmployeeId,
    String? workerType,
    String? department,
    String? earningsCode,
    List<String>? skills,
    List<Map<String, dynamic>>? certifications,
    List<String>? preferredRoles,
  }) async {
    final encoded = Uri.encodeComponent(userKey);
    final body = <String, dynamic>{};
    if (notes != null) body['notes'] = notes;
    if (rating != null) body['rating'] = rating;
    if (isFavorite != null) body['isFavorite'] = isFavorite;
    if (externalEmployeeId != null) body['externalEmployeeId'] = externalEmployeeId;
    if (workerType != null) body['workerType'] = workerType;
    if (department != null) body['department'] = department;
    if (earningsCode != null) body['earningsCode'] = earningsCode;
    if (skills != null) body['skills'] = skills;
    if (certifications != null) body['certifications'] = certifications;
    if (preferredRoles != null) body['preferredRoles'] = preferredRoles;

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

  /// Fetch AI-ranked staff recommendations for a specific event role.
  Future<Map<String, dynamic>> fetchRecommendedStaff(
    String eventId,
    String role, {
    int limit = 10,
  }) async {
    try {
      final response = await _apiClient.get<Map<String, dynamic>>(
        '/events/$eventId/recommended-staff',
        queryParameters: {'role': role, 'limit': '$limit'},
      );

      if (response.statusCode != null &&
          response.statusCode! >= 200 &&
          response.statusCode! < 300) {
        return response.data ?? {};
      }

      throw Exception(
        'Failed to get recommendations (${response.statusCode})',
      );
    } on DioException catch (e) {
      throw Exception('Failed to get recommendations: ${e.message}');
    }
  }
}
