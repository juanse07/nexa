import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'env_file_loader.dart';

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
        // Load in priority order: .env.defaults (lowest) → .env → .env.local (highest)
        final allVars = <String, String>{};

        // 1. Load .env.defaults first (lowest priority)
        final defaultVars = await loadEnvFile('.env.defaults');
        allVars.addAll(defaultVars);

        // 2. Load .env (overrides defaults)
        final envVars = await loadEnvFile('.env');
        allVars.addAll(envVars);

        // 3. Load .env.local last (highest priority, overrides everything)
        final localVars = await loadEnvFile('.env.local');
        allVars.addAll(localVars);

        // Manually populate dotenv with the final merged values
        for (final entry in allVars.entries) {
          dotenv.env[entry.key] = entry.value;
        }
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
    return _safeMaybeGet(key);
  }

  /// Gets an environment variable by key with a default value
  /// Returns the default value if the key doesn't exist
  String getOrDefault(String key, String defaultValue) {
    if (kIsWeb) {
      return _getWebEnvironmentVariable(key) ?? defaultValue;
    }
    return _safeMaybeGet(key) ?? defaultValue;
  }

  /// Checks if an environment variable exists
  bool contains(String key) {
    if (kIsWeb) {
      return _getWebEnvironmentVariable(key) != null;
    }
    return _safeMaybeGet(key) != null;
  }

  /// Helper method to get web environment variables with compile-time constants
  static String? _getWebEnvironmentVariable(String key) {
    switch (key) {
      case 'API_BASE_URL':
        return _valueOrNull(const String.fromEnvironment('API_BASE_URL'));
      case 'API_PATH_PREFIX':
        return _valueOrNull(const String.fromEnvironment('API_PATH_PREFIX'));
      case 'GOOGLE_MAPS_API_KEY':
        return _valueOrNull(const String.fromEnvironment('GOOGLE_MAPS_API_KEY'));
      case 'GOOGLE_CLIENT_ID_WEB':
        return _valueOrNull(const String.fromEnvironment('GOOGLE_CLIENT_ID_WEB'));
      case 'GOOGLE_SERVER_CLIENT_ID':
        return _valueOrNull(
          const String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID'),
        );
      case 'PLACES_BIAS_LAT':
        return _valueOrNull(const String.fromEnvironment('PLACES_BIAS_LAT'));
      case 'PLACES_BIAS_LNG':
        return _valueOrNull(const String.fromEnvironment('PLACES_BIAS_LNG'));
      case 'PLACES_COMPONENTS':
        return _valueOrNull(const String.fromEnvironment('PLACES_COMPONENTS'));
      case 'PLACES_BIAS_RADIUS_M':
        return _valueOrNull(
          const String.fromEnvironment('PLACES_BIAS_RADIUS_M'),
        );
      case 'OPENAI_API_KEY':
        return _valueOrNull(const String.fromEnvironment('OPENAI_API_KEY'));
      case 'OPENAI_BASE_URL':
        return _valueOrNull(const String.fromEnvironment('OPENAI_BASE_URL'));
      case 'OPENAI_VISION_MODEL':
        return _valueOrNull(
          const String.fromEnvironment('OPENAI_VISION_MODEL'),
        );
      case 'OPENAI_TEXT_MODEL':
        return _valueOrNull(const String.fromEnvironment('OPENAI_TEXT_MODEL'));
      case 'OPENAI_ORG_ID':
        return _valueOrNull(const String.fromEnvironment('OPENAI_ORG_ID'));
      case 'GOOGLE_CLIENT_ID_ANDROID':
        return _valueOrNull(
          const String.fromEnvironment('GOOGLE_CLIENT_ID_ANDROID'),
        );
      case 'GOOGLE_CLIENT_ID_IOS':
        return _valueOrNull(
          const String.fromEnvironment('GOOGLE_CLIENT_ID_IOS'),
        );
      case 'GOOGLE_MAPS_IOS_SDK_KEY':
        return _valueOrNull(
          const String.fromEnvironment('GOOGLE_MAPS_IOS_SDK_KEY'),
        );
      case 'APPLE_BUNDLE_ID':
        return _valueOrNull(const String.fromEnvironment('APPLE_BUNDLE_ID'));
      case 'APPLE_SERVICE_ID':
        return _valueOrNull(const String.fromEnvironment('APPLE_SERVICE_ID'));
      case 'APPLE_REDIRECT_URI':
        return _valueOrNull(const String.fromEnvironment('APPLE_REDIRECT_URI'));
      default:
        return null;
    }
  }

  static String? _valueOrNull(String value) => value.isEmpty ? null : value;

  static String? _safeMaybeGet(String key) {
    try {
      final value = dotenv.maybeGet(key);
      if (value != null && value.isNotEmpty) {
        return value;
      }
      return _getWebEnvironmentVariable(key);
    } catch (e) {
      if (e is NotInitializedError) {
        return null;
      }
      rethrow;
    }
  }
}
