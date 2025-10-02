import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Singleton class to manage environment variables
/// Loads environment variables from .env file
class Environment {
  Environment._();

  static Environment? _instance;

  /// Gets the singleton instance of Environment
  static Environment get instance {
    _instance ??= Environment._();
    return _instance!;
  }

  /// Loads environment variables from .env file
  /// Must be called before accessing any environment variables
  static Future<void> load() async {
    await dotenv.load();
  }

  /// Gets an environment variable by key
  /// Returns null if the key doesn't exist
  String? get(String key) {
    return dotenv.maybeGet(key);
  }

  /// Gets an environment variable by key with a default value
  /// Returns the default value if the key doesn't exist
  String getOrDefault(String key, String defaultValue) {
    return dotenv.maybeGet(key) ?? defaultValue;
  }

  /// Checks if an environment variable exists
  bool contains(String key) {
    return dotenv.maybeGet(key) != null;
  }
}
