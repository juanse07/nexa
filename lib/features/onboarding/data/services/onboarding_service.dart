import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

import '../../../../core/config/app_config.dart';
import '../../../auth/data/services/auth_service.dart';
import '../../presentation/widgets/enhanced_city_picker.dart';

/// Service for managing manager onboarding flow
class OnboardingService {
  /// Check if device location services are enabled
  static Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  /// Request location permission from user
  static Future<LocationPermission> requestLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    return permission;
  }

  /// Get current device location
  /// Returns null if permission denied or location unavailable
  static Future<Position?> getCurrentLocation() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('[OnboardingService] Location services disabled');
        return null;
      }

      // Check permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print('[OnboardingService] Location permission denied');
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        print('[OnboardingService] Location permission permanently denied');
        return null;
      }

      // Get current position with timeout
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 10),
      );

      print('[OnboardingService] Got location: ${position.latitude}, ${position.longitude}');
      return position;
    } catch (e) {
      print('[OnboardingService] Failed to get location: $e');
      return null;
    }
  }

  /// Convert coordinates to city name using reverse geocoding
  static Future<String?> getCityFromCoordinates(double latitude, double longitude) async {
    try {
      print('[OnboardingService] Reverse geocoding: $latitude, $longitude');

      final placemarks = await placemarkFromCoordinates(latitude, longitude);

      if (placemarks.isEmpty) {
        print('[OnboardingService] No placemarks found');
        return null;
      }

      final placemark = placemarks.first;

      // Build city string: "City, State, Country"
      final parts = <String>[];
      if (placemark.locality != null && placemark.locality!.isNotEmpty) {
        parts.add(placemark.locality!);
      }
      if (placemark.administrativeArea != null && placemark.administrativeArea!.isNotEmpty) {
        parts.add(placemark.administrativeArea!);
      }
      if (placemark.country != null && placemark.country!.isNotEmpty) {
        parts.add(placemark.country!);
      }

      final city = parts.join(', ');
      print('[OnboardingService] Detected city: $city');
      return city.isNotEmpty ? city : null;
    } catch (e) {
      print('[OnboardingService] Failed to reverse geocode: $e');
      return null;
    }
  }

  /// Auto-detect user's city from device location
  /// Returns city string or null if detection failed
  static Future<String?> detectUserCity() async {
    try {
      final position = await getCurrentLocation();
      if (position == null) {
        return null;
      }

      return await getCityFromCoordinates(position.latitude, position.longitude);
    } catch (e) {
      print('[OnboardingService] Failed to detect city: $e');
      return null;
    }
  }

  /// Submit manager's preferred city to backend
  static Future<bool> submitPreferredCity(String city) async {
    try {
      final token = await AuthService.getJwt();
      if (token == null) {
        print('[OnboardingService] Not authenticated');
        return false;
      }

      final baseUrl = AppConfig.instance.baseUrl;
      final url = Uri.parse('$baseUrl/managers/me');

      final response = await http.patch(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'preferredCity': city,
        }),
      );

      if (response.statusCode == 200) {
        print('[OnboardingService] City saved: $city');
        return true;
      } else {
        print('[OnboardingService] Failed to save city: ${response.statusCode} ${response.body}');
        return false;
      }
    } catch (e) {
      print('[OnboardingService] Error saving city: $e');
      return false;
    }
  }

  /// Trigger venue discovery for a city
  /// Returns venue count on success, null on failure
  static Future<int?> discoverVenues(String city, {bool isTourist = false}) async {
    try {
      final token = await AuthService.getJwt();
      if (token == null) {
        print('[OnboardingService] Not authenticated');
        return null;
      }

      final baseUrl = AppConfig.instance.baseUrl;
      final url = Uri.parse('$baseUrl/ai/discover-venues');

      print('[OnboardingService] Discovering venues for ${isTourist ? "tourist city" : "metro area"}: $city');

      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'city': city,
          'isTourist': isTourist,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final venueCount = data['venueCount'] as int?;
        print('[OnboardingService] Discovered $venueCount venues');
        return venueCount;
      } else {
        print('[OnboardingService] Failed to discover venues: ${response.statusCode} ${response.body}');
        return null;
      }
    } catch (e) {
      print('[OnboardingService] Error discovering venues: $e');
      return null;
    }
  }

  /// Complete onboarding: save city and discover venues
  static Future<OnboardingResult> completeOnboarding(String city) async {
    try {
      // First, save the preferred city
      final citySaved = await submitPreferredCity(city);
      if (!citySaved) {
        return OnboardingResult(
          success: false,
          message: 'Failed to save city preference',
        );
      }

      // Check if city is a tourist destination
      final isTourist = _isTouristCity(city);
      print('[OnboardingService] City "$city" is ${isTourist ? "a tourist destination" : "a metro area"}');

      // Then, discover venues with appropriate search strategy
      final venueCount = await discoverVenues(city, isTourist: isTourist);
      if (venueCount == null) {
        return OnboardingResult(
          success: false,
          message: 'Failed to discover venues',
        );
      }

      return OnboardingResult(
        success: true,
        message: 'Successfully discovered $venueCount venues in $city',
        venueCount: venueCount,
      );
    } catch (e) {
      print('[OnboardingService] Error completing onboarding: $e');
      return OnboardingResult(
        success: false,
        message: 'Unexpected error: $e',
      );
    }
  }

  /// Helper method to check if a city is a tourist destination
  static bool _isTouristCity(String city) {
    try {
      // Extract city name from "City, State, Country" format
      final cityName = city.split(',').first.trim();

      // Find matching city entry
      final cityEntry = allCities.firstWhere(
        (entry) => entry.name.toLowerCase() == cityName.toLowerCase(),
        orElse: () => const CityEntry('', '', isTourist: false),
      );

      return cityEntry.isTourist;
    } catch (e) {
      print('[OnboardingService] Error checking tourist city: $e');
      return false; // Default to metro search if error
    }
  }
}

/// Result of onboarding process
class OnboardingResult {
  final bool success;
  final String message;
  final int? venueCount;

  OnboardingResult({
    required this.success,
    required this.message,
    this.venueCount,
  });
}
