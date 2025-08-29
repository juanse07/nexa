import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class GooglePlacesService {
  static String get _apiKey {
    final key = dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';
    if (key.isEmpty) {
      throw Exception('GOOGLE_MAPS_API_KEY not found in .env file');
    }
    return key;
  }

  static const String _baseUrl = 'https://maps.googleapis.com/maps/api';

  /// Get place predictions for autocomplete
  static Future<List<PlacePrediction>> getPlacePredictions(String input) async {
    if (input.isEmpty) return [];

    final url = Uri.parse(
      '$_baseUrl/place/autocomplete/json?input=${Uri.encodeComponent(input)}&key=$_apiKey&types=address',
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          final predictions = (data['predictions'] as List)
              .map((p) => PlacePrediction.fromJson(p))
              .toList();
          return predictions;
        }
      }
      return [];
    } catch (e) {
      print('Error getting place predictions: $e');
      return [];
    }
  }

  /// Get place details including formatted address and coordinates
  static Future<PlaceDetails?> getPlaceDetails(String placeId) async {
    final url = Uri.parse(
      '$_baseUrl/place/details/json?place_id=$placeId&key=$_apiKey&fields=formatted_address,geometry,address_components',
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          return PlaceDetails.fromJson(data['result']);
        }
      }
      return null;
    } catch (e) {
      print('Error getting place details: $e');
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
  final String formattedAddress;
  final double latitude;
  final double longitude;
  final Map<String, String> addressComponents;

  PlaceDetails({
    required this.formattedAddress,
    required this.latitude,
    required this.longitude,
    required this.addressComponents,
  });

  factory PlaceDetails.fromJson(Map<String, dynamic> json) {
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
      formattedAddress: json['formatted_address'] ?? '',
      latitude: (location['lat'] ?? 0.0).toDouble(),
      longitude: (location['lng'] ?? 0.0).toDouble(),
      addressComponents: components,
    );
  }
}
