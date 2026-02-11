import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:nexa/core/network/api_client.dart';

/// A role option returned from the backend.
class CaricatureRole {
  CaricatureRole({
    required this.id,
    required this.label,
    required this.icon,
    required this.category,
    required this.locked,
  });

  final String id;
  final String label;
  final String icon;
  final String category;
  final bool locked;

  factory CaricatureRole.fromMap(Map<String, dynamic> map) {
    return CaricatureRole(
      id: map['id'] as String,
      label: map['label'] as String,
      icon: map['icon'] as String? ?? 'person',
      category: map['category'] as String? ?? 'Other',
      locked: map['locked'] as bool? ?? false,
    );
  }
}

/// An art style option returned from the backend.
class CaricatureArtStyle {
  CaricatureArtStyle({
    required this.id,
    required this.label,
    required this.icon,
    required this.locked,
  });

  final String id;
  final String label;
  final String icon;
  final bool locked;

  factory CaricatureArtStyle.fromMap(Map<String, dynamic> map) {
    return CaricatureArtStyle(
      id: map['id'] as String,
      label: map['label'] as String,
      icon: map['icon'] as String? ?? 'brush',
      locked: map['locked'] as bool? ?? false,
    );
  }
}

/// Response from GET /api/caricature/styles
class StylesResponse {
  StylesResponse({
    required this.roles,
    required this.artStyles,
  });

  final List<CaricatureRole> roles;
  final List<CaricatureArtStyle> artStyles;
}

/// Result of a caricature generation.
class CaricatureResult {
  CaricatureResult({
    required this.url,
    required this.remaining,
  });

  final String url;
  final int remaining;
}

/// Service for AI caricature generation via the backend API.
class CaricatureService {
  CaricatureService(this._apiClient);

  final ApiClient _apiClient;

  /// Fetch available roles and art styles.
  Future<StylesResponse> getStyles() async {
    final response = await _apiClient.get<dynamic>(
      '/caricature/styles',
      options: Options(
        receiveTimeout: const Duration(seconds: 15),
      ),
    );

    final data = _parseResponse(response.data);
    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'Failed to load styles');
    }

    final rolesRaw = data['roles'] as List<dynamic>? ?? [];
    final roles = rolesRaw
        .map((r) => CaricatureRole.fromMap(r as Map<String, dynamic>))
        .toList();

    final artStylesRaw = data['artStyles'] as List<dynamic>? ?? [];
    final artStyles = artStylesRaw
        .map((s) => CaricatureArtStyle.fromMap(s as Map<String, dynamic>))
        .toList();

    return StylesResponse(
      roles: roles,
      artStyles: artStyles,
    );
  }

  /// Generate a caricature with the given role and art style.
  /// Extended timeout since image generation takes 10-20 seconds.
  Future<CaricatureResult> generate(String roleId, String artStyleId) async {
    final response = await _apiClient.post<dynamic>(
      '/caricature/generate',
      data: {'role': roleId, 'artStyle': artStyleId},
      options: Options(
        sendTimeout: const Duration(seconds: 90),
        receiveTimeout: const Duration(seconds: 90),
      ),
    );

    final data = _parseResponse(response.data);

    if (response.statusCode == 429) {
      throw Exception(data['message'] ?? 'Daily limit reached');
    }
    if (response.statusCode == 400) {
      throw Exception(data['message'] ?? 'Invalid request');
    }
    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'Generation failed');
    }

    return CaricatureResult(
      url: data['url'] as String,
      remaining: data['remaining'] as int? ?? 0,
    );
  }

  Map<String, dynamic> _parseResponse(dynamic data) {
    if (data == null) return {};
    if (data is Map<String, dynamic>) return data;
    if (data is String) {
      try {
        return jsonDecode(data) as Map<String, dynamic>;
      } catch (_) {
        return {'message': data};
      }
    }
    return {};
  }
}
