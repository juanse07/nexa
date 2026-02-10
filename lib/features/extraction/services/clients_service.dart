import 'package:dio/dio.dart';
import 'package:nexa/core/network/api_client.dart';
import 'package:nexa/core/di/injection.dart';

class ClientsService {
  ClientsService() : _apiClient = getIt<ApiClient>();

  final ApiClient _apiClient;

  Future<List<Map<String, dynamic>>> fetchClients() async {
    try {
      final response = await _apiClient.get('/clients');

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
        'Failed to load clients (${response.statusCode}): ${response.data}',
      );
    } on DioException catch (e) {
      throw Exception('Failed to load clients: ${e.message}');
    }
  }

  Future<Map<String, dynamic>> createClient(String name) async {
    try {
      final response = await _apiClient.post(
        '/clients',
        data: {'name': name},
      );

      if (response.statusCode != null &&
          response.statusCode! >= 200 &&
          response.statusCode! < 300) {
        return response.data as Map<String, dynamic>;
      }
      throw Exception(
        'Failed to create client (${response.statusCode}): ${response.data}',
      );
    } on DioException catch (e) {
      throw Exception('Failed to create client: ${e.message}');
    }
  }

  Future<void> renameClient(String id, String name) async {
    try {
      final response = await _apiClient.patch(
        '/clients/$id',
        data: {'name': name},
      );

      if (response.statusCode == null ||
          response.statusCode! < 200 ||
          response.statusCode! >= 300) {
        throw Exception(
          'Failed to rename client (${response.statusCode}): ${response.data}',
        );
      }
    } on DioException catch (e) {
      throw Exception('Failed to rename client: ${e.message}');
    }
  }

  Future<void> deleteClient(String id) async {
    try {
      final response = await _apiClient.delete('/clients/$id');

      if (response.statusCode == null ||
          response.statusCode! < 200 ||
          response.statusCode! >= 300) {
        throw Exception(
          'Failed to delete client (${response.statusCode}): ${response.data}',
        );
      }
    } on DioException catch (e) {
      throw Exception('Failed to delete client: ${e.message}');
    }
  }

  Future<Map<String, dynamic>> mergeClients({
    required List<String> sourceIds,
    required String targetId,
  }) async {
    try {
      final response = await _apiClient.post(
        '/clients/merge',
        data: {'sourceIds': sourceIds, 'targetId': targetId},
      );

      if (response.statusCode != null &&
          response.statusCode! >= 200 &&
          response.statusCode! < 300) {
        return response.data as Map<String, dynamic>;
      }
      throw Exception(
        'Failed to merge clients (${response.statusCode}): ${response.data}',
      );
    } on DioException catch (e) {
      throw Exception('Failed to merge clients: ${e.message}');
    }
  }
}
