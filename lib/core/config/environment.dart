import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// Singleton class to manage environment variables
/// Loads environment variables from .env file (mobile/desktop) or uses compile-time constants (web)
class Environment {
  Environment._();

  static Environment? _instance;
  static bool _isLoaded = false;

  /// Gets the singleton instance of Environment
  static Environment get instance {
    _instance ??= Environment._();
    return _instance!;
  }

  /// Loads environment variables from .env file
  /// Must be called before accessing any environment variables
  /// For web builds, this is a no-op as environment variables should be baked in at build time
  static Future<void> load() async {
    if (_isLoaded) return;

    try {
      // For web, we skip loading .env file as it won't be bundled
      // Environment variables should be provided via --dart-define at build time
      if (!kIsWeb) {
        await dotenv.load();
      }
      _isLoaded = true;
    } catch (e) {
      // Gracefully handle missing .env file
      print('Warning: Could not load .env file: $e');
      _isLoaded = true;
    }
  }

  /// Gets an environment variable by key
  /// Returns null if the key doesn't exist
  String? get(String key) {
    if (kIsWeb) {
      // For web builds, we need to check specific keys at compile time
      // This is a limitation of String.fromEnvironment which requires constant keys
      return _getWebEnvironmentVariable(key);
    }
    return dotenv.maybeGet(key);
  }

  /// Gets an environment variable by key with a default value
  /// Returns the default value if the key doesn't exist
  String getOrDefault(String key, String defaultValue) {
    if (kIsWeb) {
      return _getWebEnvironmentVariable(key) ?? defaultValue;
    }
    return dotenv.maybeGet(key) ?? defaultValue;
  }

  /// Checks if an environment variable exists
  bool contains(String key) {
    if (kIsWeb) {
      return _getWebEnvironmentVariable(key) != null;
    }
    return dotenv.maybeGet(key) != null;
  }

  /// Helper method to get web environment variables with compile-time constants
  static String? _getWebEnvironmentVariable(String key) {
    switch (key) {
      case 'API_BASE_URL':
        const value = String.fromEnvironment('API_BASE_URL');
        return value.isEmpty ? null : value;
      case 'API_PATH_PREFIX':
        const value = String.fromEnvironment('API_PATH_PREFIX');
        return value.isEmpty ? null : value;
      case 'GOOGLE_MAPS_API_KEY':
        const value = String.fromEnvironment('GOOGLE_MAPS_API_KEY');
        return value.isEmpty ? null : value;
      case 'GOOGLE_CLIENT_ID_WEB':
        const value = String.fromEnvironment('GOOGLE_CLIENT_ID_WEB');
        return value.isEmpty ? null : value;
      case 'GOOGLE_SERVER_CLIENT_ID':
        const value = String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');
        return value.isEmpty ? null : value;
      case 'PLACES_BIAS_LAT':
        const value = String.fromEnvironment('PLACES_BIAS_LAT');
        return value.isEmpty ? null : value;
      case 'PLACES_BIAS_LNG':
        const value = String.fromEnvironment('PLACES_BIAS_LNG');
        return value.isEmpty ? null : value;
      case 'PLACES_COMPONENTS':
        const value = String.fromEnvironment('PLACES_COMPONENTS');
        return value.isEmpty ? null : value;
      case 'OPENAI_API_KEY':
        const value = String.fromEnvironment('OPENAI_API_KEY');
        return value.isEmpty ? null : value;
      case 'GOOGLE_CLIENT_ID_ANDROID':
        const value = String.fromEnvironment('GOOGLE_CLIENT_ID_ANDROID');
        return value.isEmpty ? null : value;
      case 'GOOGLE_CLIENT_ID_IOS':
        const value = String.fromEnvironment('GOOGLE_CLIENT_ID_IOS');
        return value.isEmpty ? null : value;
      case 'GOOGLE_MAPS_IOS_SDK_KEY':
        const value = String.fromEnvironment('GOOGLE_MAPS_IOS_SDK_KEY');
        return value.isEmpty ? null : value;
      case 'APPLE_BUNDLE_ID':
        const value = String.fromEnvironment('APPLE_BUNDLE_ID');
        return value.isEmpty ? null : value;
      default:
        return null;
    }
  }
}
