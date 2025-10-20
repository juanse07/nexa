import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'env_file_loader.dart';

/// Singleton class to manage environment variables
/// Loads environment variables from .env file (mobile/desktop) or uses compile-time constants (web)
class Environment {
  Environment._();

  static Environment? _instance;
  static bool _isLoaded = false;
  static final Map<String, String> _runtimeCache = <String, String>{};
  static const List<String> _keys = [
    'API_BASE_URL',
    'API_PATH_PREFIX',
    'GOOGLE_CLIENT_ID_IOS',
    'GOOGLE_CLIENT_ID_ANDROID',
    'GOOGLE_CLIENT_ID_WEB',
    'GOOGLE_SERVER_CLIENT_ID',
    'APPLE_BUNDLE_ID',
    'APPLE_SERVICE_ID',
    'APPLE_REDIRECT_URI',
    'GOOGLE_MAPS_IOS_SDK_KEY',
    'PLACES_BIAS_LAT',
    'PLACES_BIAS_LNG',
    'PLACES_COMPONENTS',
    'PLACES_BIAS_RADIUS_M',
    'ENVIRONMENT',
    'DEBUG_MODE',
  ];

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

        // Manually populate runtime and dotenv caches with the final merged values
        // Merge with --dart-define overrides
        for (final key in _keys) {
          final override = _getDartDefine(key);
          if (override != null && override.isNotEmpty) {
            allVars[key] = override;
          }
        }

        final buffer = StringBuffer();
        allVars.forEach((key, value) {
          buffer.writeln('$key=$value');
        });
        dotenv.testLoad(fileInput: buffer.toString());

        _runtimeCache
          ..clear()
          ..addAll(allVars);
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
    if (kIsWeb) return _getDartDefine(key);
    final cached = _runtimeCache[key];
    if (cached != null && cached.isNotEmpty) return cached;
    return _safeMaybeGet(key);
  }

  /// Gets an environment variable by key with a default value
  /// Returns the default value if the key doesn't exist
  String getOrDefault(String key, String defaultValue) {
    if (kIsWeb) return _getDartDefine(key) ?? defaultValue;
    final cached = _runtimeCache[key];
    if (cached != null && cached.isNotEmpty) return cached;
    return _safeMaybeGet(key) ?? defaultValue;
  }

  /// Checks if an environment variable exists
  bool contains(String key) {
    if (kIsWeb) return _getDartDefine(key) != null;
    if (_runtimeCache.containsKey(key) && (_runtimeCache[key]?.isNotEmpty ?? false)) {
      return true;
    }
    return _safeMaybeGet(key) != null;
  }

  /// Helper method to get web environment variables with compile-time constants
  static String? _getDartDefine(String key) {
    switch (key) {
      case 'API_BASE_URL':
        return _valueOrNull(const String.fromEnvironment('API_BASE_URL'));
      case 'API_PATH_PREFIX':
        return _valueOrNull(const String.fromEnvironment('API_PATH_PREFIX'));
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
      final value = _runtimeCache[key] ?? dotenv.maybeGet(key);
      if (value != null && value.isNotEmpty) {
        return value;
      }
      return _getDartDefine(key);
    } catch (e) {
      if (e is NotInitializedError) {
        return null;
      }
      rethrow;
    }
  }
}
