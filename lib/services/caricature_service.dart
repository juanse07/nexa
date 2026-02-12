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
      id: map['id']?.toString() ?? '',
      label: map['label']?.toString() ?? '',
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
      id: map['id']?.toString() ?? '',
      label: map['label']?.toString() ?? '',
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

/// Result of a caricature generation (preview — not yet saved).
class CaricatureResult {
  CaricatureResult({
    required this.base64,
    required this.role,
    required this.artStyle,
    required this.model,
    required this.remaining,
  });

  final String base64;
  final String role;
  final String artStyle;
  final String model;
  final int remaining;
}

/// Result of accepting a caricature (saved to storage).
class CaricatureAcceptResult {
  CaricatureAcceptResult({required this.url});

  final String url;
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
  Future<CaricatureResult> generate(String roleId, String artStyleId, {String model = 'dev'}) async {
    final response = await _apiClient.post<dynamic>(
      '/caricature/generate',
      data: {'role': roleId, 'artStyle': artStyleId, 'model': model},
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

    final base64 = data['base64'];
    if (base64 == null || base64 is! String) {
      throw Exception('Server returned no image data');
    }

    return CaricatureResult(
      base64: base64,
      role: data['role'] as String? ?? roleId,
      artStyle: data['artStyle'] as String? ?? artStyleId,
      model: data['model'] as String? ?? model,
      remaining: data['remaining'] as int? ?? 0,
    );
  }

  /// Accept a generated caricature — uploads to storage and saves to history.
  Future<CaricatureAcceptResult> accept(CaricatureResult preview) async {
    final response = await _apiClient.post<dynamic>(
      '/caricature/accept',
      data: {
        'base64': preview.base64,
        'role': preview.role,
        'artStyle': preview.artStyle,
        'model': preview.model,
      },
      options: Options(
        sendTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
      ),
    );

    final data = _parseResponse(response.data);
    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'Failed to save caricature');
    }

    final url = data['url'];
    if (url == null || url is! String) {
      throw Exception('Server returned no image URL');
    }
    return CaricatureAcceptResult(url: url);
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
