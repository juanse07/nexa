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
    // For web, try to get from compile-time constants first
    if (kIsWeb) {
      return const String.fromEnvironment(key, defaultValue: '').isEmpty
        ? null
        : const String.fromEnvironment(key);
    }
    return dotenv.maybeGet(key);
  }

  /// Gets an environment variable by key with a default value
  /// Returns the default value if the key doesn't exist
  String getOrDefault(String key, String defaultValue) {
    // For web, use compile-time constants
    if (kIsWeb) {
      final value = const String.fromEnvironment(key, defaultValue: '');
      return value.isEmpty ? defaultValue : value;
    }
    return dotenv.maybeGet(key) ?? defaultValue;
  }

  /// Checks if an environment variable exists
  bool contains(String key) {
    if (kIsWeb) {
      return const String.fromEnvironment(key, defaultValue: '').isNotEmpty;
    }
    return dotenv.maybeGet(key) != null;
  }
}
