import 'package:dio/dio.dart';
import 'package:nexa/core/network/api_client.dart';
import 'package:nexa/core/di/injection.dart';

class TariffsService {
  TariffsService() : _apiClient = getIt<ApiClient>();

  final ApiClient _apiClient;

  Future<List<Map<String, dynamic>>> fetchTariffs({
    String? clientId,
    String? roleId,
  }) async {
    try {
      final params = <String, String>{};
      if (clientId != null && clientId.isNotEmpty) params['clientId'] = clientId;
      if (roleId != null && roleId.isNotEmpty) params['roleId'] = roleId;

      final response = await _apiClient.get(
        '/tariffs',
        queryParameters: params.isEmpty ? null : params,
      );

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
        'Failed to load tariffs (${response.statusCode}): ${response.data}',
      );
    } on DioException catch (e) {
      throw Exception('Failed to load tariffs: ${e.message}');
    }
  }

  Future<Map<String, dynamic>> upsertTariff({
    required String clientId,
    required String roleId,
    required double rate,
    String currency = 'USD',
  }) async {
    try {
      final response = await _apiClient.post(
        '/tariffs',
        data: {
          'clientId': clientId,
          'roleId': roleId,
          'rate': rate,
          'currency': currency,
        },
      );

      if (response.statusCode != null &&
          response.statusCode! >= 200 &&
          response.statusCode! < 300) {
        return response.data as Map<String, dynamic>;
      }
      throw Exception(
        'Failed to save tariff (${response.statusCode}): ${response.data}',
      );
    } on DioException catch (e) {
      throw Exception('Failed to save tariff: ${e.message}');
    }
  }

  Future<void> deleteTariff(String id) async {
    try {
      final response = await _apiClient.delete('/tariffs/$id');

      if (response.statusCode == null ||
          response.statusCode! < 200 ||
          response.statusCode! >= 300) {
        throw Exception(
          'Failed to delete tariff (${response.statusCode}): ${response.data}',
        );
      }
    } on DioException catch (e) {
      throw Exception('Failed to delete tariff: ${e.message}');
    }
  }
}
