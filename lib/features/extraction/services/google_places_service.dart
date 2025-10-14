import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/config/environment.dart';

class GooglePlacesService {
  static String get _apiKey {
    final key = Environment.instance.get('GOOGLE_MAPS_API_KEY') ?? '';
    if (key.isEmpty) {
      throw Exception('GOOGLE_MAPS_API_KEY not found in .env file');
    }
    return key;
  }

  static const String _baseUrl = 'https://maps.googleapis.com/maps/api';

  /// Get place predictions for autocomplete
  static Future<List<PlacePrediction>> getPlacePredictions(String input) async {
    if (input.isEmpty) return [];

    // Optional geo bias (defaults: Colorado, USA)
    final biasLat = double.tryParse(
          Environment.instance.get('PLACES_BIAS_LAT') ?? '',
        ) ??
        39.7392; // Denver
    final biasLng = double.tryParse(
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
    final queryParams = [
      'input=${Uri.encodeComponent(input)}',
      'key=$_apiKey',
      // Do not hard-filter to address only; allow establishments to match well-known venues
      if (components.isNotEmpty)
        'components=${Uri.encodeComponent(components)}',
      'location=$biasLat,$biasLng',
      'radius=$biasRadiusM',
      'region=us',
      'sessiontoken=$sessionToken',
    ].join('&');

    final url = Uri.parse('$_baseUrl/place/autocomplete/json?$queryParams');

    try {
      // Minimal debug signal without exposing the key
      // ignore: avoid_print
      print(
        '[places] autocomplete request q="${input.substring(0, input.length.clamp(0, 20))}"',
      );
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          final predictions = (data['predictions'] as List)
              .map((p) => PlacePrediction.fromJson(p))
              .toList();
          return predictions;
        }
        // ignore: avoid_print
        print(
          '[places] autocomplete status=${data['status']} msg=${data['error_message'] ?? ''}',
        );
        throw Exception(
          'Places autocomplete failed: ${data['status']} ${data['error_message'] ?? ''}',
        );
      }
      // ignore: avoid_print
      print('[places] HTTP ${response.statusCode}: ${response.body}');
      throw Exception('HTTP ${response.statusCode} from Places');
    } catch (e) {
      // ignore: avoid_print
      print('Error getting place predictions: $e');
      rethrow;
    }
  }

  /// Get place details including formatted address and coordinates
  static Future<PlaceDetails?> getPlaceDetails(String placeId) async {
    final url = Uri.parse(
      '$_baseUrl/place/details/json?place_id=$placeId&key=$_apiKey&fields=formatted_address,geometry,address_components',
    );

    try {
      // ignore: avoid_print
      print(
        '[places] details request id=${placeId.substring(0, placeId.length.clamp(0, 12))}...',
      );
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          return PlaceDetails.fromJson(data['result'], placeId: placeId);
        }
        // ignore: avoid_print
        print(
          '[places] details status=${data['status']} msg=${data['error_message'] ?? ''}',
        );
        throw Exception(
          'Places details failed: ${data['status']} ${data['error_message'] ?? ''}',
        );
      }
      // ignore: avoid_print
      print('[places] details HTTP ${response.statusCode}: ${response.body}');
      throw Exception('HTTP ${response.statusCode} from Places details');
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
    try {
      final preds = await getPlacePredictions(input);
      if (preds.isEmpty) return null;
      // Prefer a candidate with a placeId and meaningful description
      final PlacePrediction first = preds.first;
      return getPlaceDetails(first.placeId);
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
