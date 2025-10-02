import 'package:nexa/core/config/environment.dart';

/// Application environment types
enum AppEnvironment {
  /// Development environment
  development,

  /// Staging environment
  staging,

  /// Production environment
  production,
}

/// Application configuration class
/// Manages all app configuration and environment-specific settings
class AppConfig {
  AppConfig._();

  static AppConfig? _instance;

  /// Gets the singleton instance of AppConfig
  static AppConfig get instance {
    _instance ??= AppConfig._();
    return _instance!;
  }

  final Environment _env = Environment.instance;

  /// Current application environment
  AppEnvironment get environment {
    final env = _env.get('ENVIRONMENT')?.toLowerCase() ?? 'development';
    switch (env) {
      case 'production':
      case 'prod':
        return AppEnvironment.production;
      case 'staging':
        return AppEnvironment.staging;
      default:
        return AppEnvironment.development;
    }
  }

  /// Backend base URL
  String get baseUrl {
    final apiBase = _env.get('API_BASE_URL') ?? _env.get('BACKEND_BASE_URL');
    final pathPrefix = _env.get('API_PATH_PREFIX') ?? '';
    
    if (apiBase != null) {
      return pathPrefix.isNotEmpty ? '$apiBase$pathPrefix' : apiBase;
    }
    
    return 'https://api.nexapymesoft.com/api';
  }

  /// OpenAI API key
  String get openAIKey {
    return _env.getOrDefault(
      'OPENAI_API_KEY',
      '',
    );
  }

  /// Google Maps API key
  String get googleMapsKey {
    return _env.getOrDefault(
      'GOOGLE_MAPS_API_KEY',
      '',
    );
  }

  /// Google Maps iOS SDK key
  String get googleMapsIosKey {
    return _env.getOrDefault(
      'GOOGLE_MAPS_IOS_SDK_KEY',
      '',
    );
  }

  /// Google Places autocomplete bias latitude
  double get placesBiasLat {
    final lat = _env.get('PLACES_BIAS_LAT');
    return lat != null ? double.tryParse(lat) ?? 39.7392 : 39.7392;
  }

  /// Google Places autocomplete bias longitude
  double get placesBiasLng {
    final lng = _env.get('PLACES_BIAS_LNG');
    return lng != null ? double.tryParse(lng) ?? -104.9903 : -104.9903;
  }

  /// Google Places components filter
  String get placesComponents {
    return _env.getOrDefault(
      'PLACES_COMPONENTS',
      'country:us',
    );
  }

  /// Check if app is in development mode
  bool get isDevelopment => environment == AppEnvironment.development;

  /// Check if app is in staging mode
  bool get isStaging => environment == AppEnvironment.staging;

  /// Check if app is in production mode
  bool get isProduction => environment == AppEnvironment.production;

  /// Check if debug mode is enabled
  bool get isDebugMode {
    return _env.get('DEBUG_MODE')?.toLowerCase() == 'true' || isDevelopment;
  }
}
