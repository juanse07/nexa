import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:nexa/core/config/app_config.dart';

class NotificationApiService {
  static final NotificationApiService _instance = NotificationApiService._internal();
  factory NotificationApiService() => _instance;
  NotificationApiService._internal();

  final Dio _dio = Dio();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<String?> get _authToken async {
    return await _storage.read(key: 'auth_token');
  }

  Future<String?> getUserId() async {
    // Get user ID from stored auth data
    return await _storage.read(key: 'user_id');
  }

  /// Register device for push notifications
  Future<bool> registerDevice({
    required String oneSignalPlayerId,
    required String deviceType,
  }) async {
    try {
      final token = await _authToken;
      if (token == null) return false;

      final response = await _dio.post(
        '${AppConfig.instance.baseUrl}/api/notifications/register-device',
        data: {
          'oneSignalPlayerId': oneSignalPlayerId,
          'deviceType': deviceType,
        },
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error registering device: $e');
      return false;
    }
  }

  /// Unregister device (on logout)
  Future<bool> unregisterDevice(String oneSignalPlayerId) async {
    try {
      final token = await _authToken;
      if (token == null) return false;

      final response = await _dio.delete(
        '${AppConfig.instance.baseUrl}/api/notifications/unregister-device',
        data: {'oneSignalPlayerId': oneSignalPlayerId},
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error unregistering device: $e');
      return false;
    }
  }

  /// Get notification history
  Future<List<Map<String, dynamic>>> getNotificationHistory({
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final token = await _authToken;
      if (token == null) return [];

      final response = await _dio.get(
        '${AppConfig.instance.baseUrl}/api/notifications/history',
        queryParameters: {
          'limit': limit,
          'offset': offset,
        },
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );

      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(
          response.data['notifications'] ?? [],
        );
      }
      return [];
    } catch (e) {
      print('Error getting notification history: $e');
      return [];
    }
  }

  /// Get notification preferences
  Future<Map<String, bool>?> getNotificationPreferences() async {
    try {
      final token = await _authToken;
      if (token == null) return null;

      // Get user profile to fetch preferences
      final response = await _dio.get(
        '${AppConfig.instance.baseUrl}/api/managers/me',
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );

      if (response.statusCode == 200) {
        final prefs = response.data['manager']?['notificationPreferences'];
        if (prefs != null) {
          return Map<String, bool>.from(prefs);
        }
      }
      return null;
    } catch (e) {
      print('Error getting notification preferences: $e');
      return null;
    }
  }

  /// Update notification preferences
  Future<bool> updateNotificationPreferences(
    Map<String, bool> preferences,
  ) async {
    try {
      final token = await _authToken;
      if (token == null) return false;

      final response = await _dio.patch(
        '${AppConfig.instance.baseUrl}/api/notifications/preferences',
        data: preferences,
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error updating notification preferences: $e');
      return false;
    }
  }

  /// Mark notification as read
  Future<bool> markAsRead(String notificationId) async {
    try {
      final token = await _authToken;
      if (token == null) return false;

      final response = await _dio.post(
        '${AppConfig.instance.baseUrl}/api/notifications/mark-read',
        data: {'notificationId': notificationId},
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error marking notification as read: $e');
      return false;
    }
  }

  /// Mark all notifications as read
  Future<bool> markAllAsRead() async {
    try {
      final token = await _authToken;
      if (token == null) return false;

      final response = await _dio.post(
        '${AppConfig.instance.baseUrl}/api/notifications/mark-all-read',
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error marking all as read: $e');
      return false;
    }
  }

  /// Get unread notification count
  Future<int> getUnreadCount() async {
    try {
      final token = await _authToken;
      if (token == null) return 0;

      final response = await _dio.get(
        '${AppConfig.instance.baseUrl}/api/notifications/unread-count',
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );

      if (response.statusCode == 200) {
        return response.data['count'] ?? 0;
      }
      return 0;
    } catch (e) {
      print('Error getting unread count: $e');
      return 0;
    }
  }

  /// Send test notification
  Future<bool> sendTestNotification({
    String? title,
    String? body,
    String? type,
  }) async {
    try {
      final token = await _authToken;
      if (token == null) return false;

      final response = await _dio.post(
        '${AppConfig.instance.baseUrl}/api/notifications/test',
        data: {
          if (title != null) 'title': title,
          if (body != null) 'body': body,
          if (type != null) 'type': type,
        },
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error sending test notification: $e');
      return false;
    }
  }
}