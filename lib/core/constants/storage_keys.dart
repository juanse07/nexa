/// Storage keys for SharedPreferences and FlutterSecureStorage
class StorageKeys {
  StorageKeys._();

  // Authentication Keys (Secure Storage)
  static const String accessToken = 'access_token';
  static const String refreshToken = 'refresh_token';
  static const String tokenExpiry = 'token_expiry';
  static const String userId = 'user_id';
  static const String userEmail = 'user_email';

  // User Preferences (Shared Preferences)
  static const String isDarkMode = 'is_dark_mode';
  static const String language = 'language';
  static const String isFirstLaunch = 'is_first_launch';
  static const String hasCompletedOnboarding = 'has_completed_onboarding';
  static const String lastSyncTime = 'last_sync_time';
  static const String notificationsEnabled = 'notifications_enabled';

  // Cache Keys (Shared Preferences)
  static const String cachedClients = 'cached_clients';
  static const String cachedEvents = 'cached_events';
  static const String cachedTariffs = 'cached_tariffs';
  static const String cachedRoles = 'cached_roles';
  static const String cachedUsers = 'cached_users';

  // Cache Timestamps
  static const String clientsCacheTimestamp = 'clients_cache_timestamp';
  static const String eventsCacheTimestamp = 'events_cache_timestamp';
  static const String tariffsCacheTimestamp = 'tariffs_cache_timestamp';
  static const String rolesCacheTimestamp = 'roles_cache_timestamp';
  static const String usersCacheTimestamp = 'users_cache_timestamp';

  // Draft Keys
  static const String draftPrefix = 'draft_';
  static const String draftList = 'draft_list';
  static const String lastDraftId = 'last_draft_id';

  // Settings Keys
  static const String biometricsEnabled = 'biometrics_enabled';
  static const String autoSaveEnabled = 'auto_save_enabled';
  static const String syncInterval = 'sync_interval';
  static const String cacheSize = 'cache_size';
  static const String maxCacheSize = 'max_cache_size';

  // Session Keys
  static const String sessionId = 'session_id';
  static const String lastActivityTime = 'last_activity_time';
  static const String sessionTimeout = 'session_timeout';

  /// Gets a draft key by ID
  static String draftById(String id) => '$draftPrefix$id';

  /// Gets a cache key by prefix and ID
  static String cacheKeyById(String prefix, String id) => '${prefix}_$id';
}
