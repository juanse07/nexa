import 'package:dio/dio.dart';
import 'package:nexa/core/network/api_client.dart';
import 'package:nexa/features/cities/data/models/city.dart';
import 'package:nexa/features/venues/data/models/venue.dart';

/// Service for managing cities in manager profile
class CityService {
  CityService(this._apiClient);

  final ApiClient _apiClient;

  /// Get all cities for the current manager
  Future<List<City>> getCities() async {
    final resp = await _apiClient.get<Map<String, dynamic>>('/managers/me');
    final data = resp.data ?? {};
    final citiesJson = data['cities'] as List<dynamic>? ?? [];
    return citiesJson.map((json) => City.fromJson(json as Map<String, dynamic>)).toList();
  }

  /// Add a new city to manager's profile
  /// Returns updated list of cities
  Future<List<City>> addCity(City city) async {
    final payload = city.toJson();
    final resp = await _apiClient.post<Map<String, dynamic>>(
      '/managers/me/cities',
      data: payload,
    );
    final data = resp.data ?? {};
    final citiesJson = data['cities'] as List<dynamic>? ?? [];
    return citiesJson.map((json) => City.fromJson(json as Map<String, dynamic>)).toList();
  }

  /// Update a city at specific index
  /// Returns updated list of cities
  Future<List<City>> updateCity(int index, City city) async {
    final payload = city.toJson();
    final resp = await _apiClient.patch<Map<String, dynamic>>(
      '/managers/me/cities/$index',
      data: payload,
    );
    final data = resp.data ?? {};
    final citiesJson = data['cities'] as List<dynamic>? ?? [];
    return citiesJson.map((json) => City.fromJson(json as Map<String, dynamic>)).toList();
  }

  /// Delete a city at specific index
  /// Returns updated cities and venue lists
  Future<CityDeletionResult> deleteCity(int index) async {
    final resp = await _apiClient.delete<Map<String, dynamic>>(
      '/managers/me/cities/$index',
    );
    final data = resp.data ?? {};

    final citiesJson = data['cities'] as List<dynamic>? ?? [];
    final cities = citiesJson.map((json) => City.fromJson(json as Map<String, dynamic>)).toList();

    final venuesJson = data['venueList'] as List<dynamic>? ?? [];
    final venues = venuesJson.map((json) => Venue.fromJson(json as Map<String, dynamic>)).toList();

    return CityDeletionResult(cities: cities, venues: venues);
  }

  /// Discover venues for a specific city
  /// Returns venues for the city
  Future<VenueDiscoveryResult> discoverVenues(City city) async {
    final payload = {
      'city': city.name,
      'isTourist': city.isTourist,
    };

    // AI venue discovery can take 60-90 seconds due to web search
    final resp = await _apiClient.post<Map<String, dynamic>>(
      '/ai/discover-venues',
      data: payload,
      options: Options(
        receiveTimeout: const Duration(seconds: 120), // 2 minutes for AI processing
      ),
    );

    final data = resp.data ?? {};
    final venuesJson = data['venues'] as List<dynamic>? ?? [];
    final venues = venuesJson.map((json) => Venue.fromJson(json as Map<String, dynamic>)).toList();

    return VenueDiscoveryResult(
      city: data['city'] as String? ?? city.name,
      venueCount: data['venueCount'] as int? ?? venues.length,
      venues: venues,
      updatedAt: data['updatedAt'] != null
          ? DateTime.parse(data['updatedAt'] as String)
          : null,
    );
  }
}

/// Result of deleting a city (includes updated cities and venues)
class CityDeletionResult {
  final List<City> cities;
  final List<Venue> venues;

  CityDeletionResult({
    required this.cities,
    required this.venues,
  });
}

/// Result of venue discovery for a city
class VenueDiscoveryResult {
  final String city;
  final int venueCount;
  final List<Venue> venues;
  final DateTime? updatedAt;

  VenueDiscoveryResult({
    required this.city,
    required this.venueCount,
    required this.venues,
    this.updatedAt,
  });
}
