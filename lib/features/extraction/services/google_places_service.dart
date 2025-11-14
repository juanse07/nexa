import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/config/app_config.dart';
import '../../../core/config/environment.dart';
import '../../auth/data/services/auth_service.dart';

class GooglePlacesService {
  static String get _baseUrl => AppConfig.instance.baseUrl;

  /// Get place predictions for autocomplete
  /// [userLat] and [userLng] are optional - if provided, results will be biased to user's location
  static Future<List<PlacePrediction>> getPlacePredictions(
    String input, {
    double? userLat,
    double? userLng,
  }) async {
    if (input.isEmpty) return [];

    // Get auth token
    final token = await AuthService.getJwt();
    if (token == null) {
      throw Exception('Not authenticated');
    }

    // Optional geo bias - use user location if provided, otherwise defaults (Colorado, USA)
    final biasLat = userLat ??
        double.tryParse(
          Environment.instance.get('PLACES_BIAS_LAT') ?? '',
        ) ??
        39.7392; // Denver
    final biasLng = userLng ??
        double.tryParse(
          Environment.instance.get('PLACES_BIAS_LNG') ?? '',
        ) ??
        -104.9903;
    final biasRadiusM = int.tryParse(
          Environment.instance.get('PLACES_BIAS_RADIUS_M') ?? '',
        ) ??
        450000; // ~450km
    final components = (Environment.instance.get('PLACES_COMPONENTS') ??
            'country:us')
        .trim();

    final sessionToken = DateTime.now().millisecondsSinceEpoch.toString();

    final url = Uri.parse('$_baseUrl/places/autocomplete');

    try {
      // Call backend proxy instead of Google directly
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'input': input,
          'biasLat': biasLat,
          'biasLng': biasLng,
          'biasRadiusM': biasRadiusM,
          'components': components,
          'sessionToken': sessionToken,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          final predictions = (data['predictions'] as List)
              .map((p) => PlacePrediction.fromJson(p))
              .toList();
          return predictions;
        }
        if (data['status'] == 'ZERO_RESULTS') {
          return [];
        }
        throw Exception(
          'Places autocomplete failed: ${data['status']} ${data['error'] ?? ''}',
        );
      }
      throw Exception('HTTP ${response.statusCode} from backend');
    } catch (e) {
      // ignore: avoid_print
      print('Error getting place predictions: $e');
      rethrow;
    }
  }

  /// Get place details including formatted address and coordinates
  static Future<PlaceDetails?> getPlaceDetails(String placeId) async {
    // Get auth token
    final token = await AuthService.getJwt();
    if (token == null) {
      throw Exception('Not authenticated');
    }

    final url = Uri.parse('$_baseUrl/places/details');

    try {
      // Call backend proxy instead of Google directly
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({'placeId': placeId}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          return PlaceDetails.fromJson(data['result'], placeId: placeId);
        }
        throw Exception(
          'Places details failed: ${data['status']} ${data['error'] ?? ''}',
        );
      }
      throw Exception('HTTP ${response.statusCode} from backend');
    } catch (e) {
      // ignore: avoid_print
      print('Error getting place details: $e');
      rethrow;
    }
  }

  /// Convenience: Resolve a free-form address string to place details by
  /// querying autocomplete and returning the top candidate's details.
  static Future<PlaceDetails?> resolveAddressToPlaceDetails(
    String address,
  ) async {
    final input = address.trim();
    if (input.isEmpty) return null;

    // Get auth token
    final token = await AuthService.getJwt();
    if (token == null) {
      throw Exception('Not authenticated');
    }

    final url = Uri.parse('$_baseUrl/places/resolve-address');

    try {
      // Use backend convenience endpoint that combines autocomplete + details
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({'address': address}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK' && data['result'] != null) {
          // Extract placeId from result if available, otherwise use a placeholder
          final placeId = data['result']['place_id'] ?? '';
          return PlaceDetails.fromJson(data['result'], placeId: placeId);
        }
        return null; // ZERO_RESULTS or no result
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}

class PlacePrediction {
  final String placeId;
  final String description;
  final String mainText;
  final String secondaryText;

  PlacePrediction({
    required this.placeId,
    required this.description,
    required this.mainText,
    required this.secondaryText,
  });

  factory PlacePrediction.fromJson(Map<String, dynamic> json) {
    return PlacePrediction(
      placeId: json['place_id'] ?? '',
      description: json['description'] ?? '',
      mainText: json['structured_formatting']?['main_text'] ?? '',
      secondaryText: json['structured_formatting']?['secondary_text'] ?? '',
    );
  }
}

class PlaceDetails {
  final String placeId;
  final String formattedAddress;
  final double latitude;
  final double longitude;
  final Map<String, String> addressComponents;

  PlaceDetails({
    required this.placeId,
    required this.formattedAddress,
    required this.latitude,
    required this.longitude,
    required this.addressComponents,
  });

  factory PlaceDetails.fromJson(
    Map<String, dynamic> json, {
    required String placeId,
  }) {
    final geometry = json['geometry'] ?? {};
    final location = geometry['location'] ?? {};

    // Parse address components
    final components = <String, String>{};
    final addressComponents = json['address_components'] as List? ?? [];

    for (final component in addressComponents) {
      final types = component['types'] as List? ?? [];
      final longName = component['long_name'] ?? '';
      final shortName = component['short_name'] ?? '';

      for (final type in types) {
        switch (type) {
          case 'street_number':
            components['street_number'] = longName;
            break;
          case 'route':
            components['street'] = longName;
            break;
          case 'locality':
            components['city'] = longName;
            break;
          case 'administrative_area_level_1':
            components['state'] = shortName;
            break;
          case 'postal_code':
            components['postal_code'] = longName;
            break;
          case 'country':
            components['country'] = longName;
            break;
        }
      }
    }

    return PlaceDetails(
      placeId: placeId,
      formattedAddress: json['formatted_address'] ?? '',
      latitude: (location['lat'] ?? 0.0).toDouble(),
      longitude: (location['lng'] ?? 0.0).toDouble(),
      addressComponents: components,
    );
  }
}
