import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:badges/badges.dart' as badges;
import 'package:nexa/services/notification_api_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final NotificationApiService _apiService = NotificationApiService();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  // OneSignal App ID - Replace with your actual App ID
  static const String _oneSignalAppId = 'YOUR_ONESIGNAL_APP_ID_HERE';

  // Notification counts
  int _unreadChatCount = 0;
  int _unreadTaskCount = 0;
  final _notificationCountController = StreamController<int>.broadcast();

  Stream<int> get notificationCountStream => _notificationCountController.stream;
  int get totalUnreadCount => _unreadChatCount + _unreadTaskCount;

  /// Initialize OneSignal and local notifications
  Future<void> initialize() async {
    try {
      // Initialize local notifications for foreground display
      await _initializeLocalNotifications();

      // Initialize OneSignal
      OneSignal.Debug.setLogLevel(OSLogLevel.verbose);

      OneSignal.initialize(_oneSignalAppId);

      // Request permission (iOS only, Android granted at install)
      if (Platform.isIOS) {
        final permission = await OneSignal.Notifications.requestPermission(true);
        print('OneSignal permission granted: $permission');
      }

      // Set up notification handlers
      _setupNotificationHandlers();

      // Get and register device token
      await _registerDevice();

      // Load notification preferences
      await _loadNotificationPreferences();

      print('✅ NotificationService initialized successfully');
    } catch (e) {
      print('❌ Failed to initialize NotificationService: $e');
    }
  }

  /// Initialize local notifications for foreground display
  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _handleLocalNotificationClick,
    );
  }

  /// Set up OneSignal notification handlers
  void _setupNotificationHandlers() {
    // Handle notification when received (app in foreground)
    OneSignal.Notifications.addForegroundWillDisplayListener((event) {
      print('Notification received in foreground: ${event.notification.title}');

      // Show local notification when app is in foreground
      _showLocalNotification(
        event.notification.title ?? 'New Notification',
        event.notification.body ?? '',
        event.notification.additionalData ?? {},
      );

      // Update badge count
      _updateBadgeCount(event.notification.additionalData);
    });

    // Handle notification click
    OneSignal.Notifications.addClickListener((event) {
      print('Notification clicked: ${event.notification.title}');
      _handleNotificationClick(event.notification.additionalData ?? {});
    });

    // Handle permission changes
    OneSignal.Notifications.addPermissionObserver((permission) {
      print('Permission changed: $permission');
      _storage.write(key: 'notificationsEnabled', value: permission.toString());
    });
  }

  /// Register device with backend
  Future<void> _registerDevice() async {
    try {
      // Get OneSignal Player ID
      final deviceState = await OneSignal.User.getOnesignalId();

      if (deviceState == null) {
        print('No OneSignal Player ID available yet');
        return;
      }

      // Get user's MongoDB ID from auth token
      final userId = await _apiService.getUserId();
      if (userId != null) {
        // Set external user ID in OneSignal
        OneSignal.login(userId);

        // Register device with backend
        await _apiService.registerDevice(
          oneSignalPlayerId: deviceState,
          deviceType: Platform.isIOS ? 'ios' : 'android',
        );

        print('✅ Device registered with backend: $deviceState');
      }
    } catch (e) {
      print('❌ Failed to register device: $e');
    }
  }

  /// Show local notification when app is in foreground
  Future<void> _showLocalNotification(
    String title,
    String body,
    Map<String, dynamic> data,
  ) async {
    const androidDetails = AndroidNotificationDetails(
      'nexa_channel',
      'Nexa Notifications',
      channelDescription: 'Notifications for Nexa app',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
      payload: data.toString(),
    );
  }

  /// Handle local notification click
  void _handleLocalNotificationClick(NotificationResponse response) {
    // Parse payload and navigate
    if (response.payload != null) {
      _handleNotificationClick({});
    }
  }

  /// Handle notification click navigation
  void _handleNotificationClick(Map<String, dynamic> data) {
    final type = data['type'] as String?;

    switch (type) {
      case 'chat':
        _navigateToChat(data);
        break;
      case 'task':
        _navigateToTask(data);
        break;
      case 'event':
        _navigateToEvent(data);
        break;
      case 'hours':
        _navigateToHours(data);
        break;
      default:
        // Navigate to notifications page
        _navigateToNotifications();
    }
  }

  /// Navigate to chat screen
  void _navigateToChat(Map<String, dynamic> data) {
    final conversationId = data['conversationId'];
    final userKey = data['userKey'];

    // TODO: Implement navigation to chat screen
    print('Navigate to chat: $conversationId, user: $userKey');
  }

  /// Navigate to task details
  void _navigateToTask(Map<String, dynamic> data) {
    final taskId = data['taskId'];

    // TODO: Implement navigation to task screen
    print('Navigate to task: $taskId');
  }

  /// Navigate to event details
  void _navigateToEvent(Map<String, dynamic> data) {
    final eventId = data['eventId'];

    // TODO: Implement navigation to event screen
    print('Navigate to event: $eventId');
  }

  /// Navigate to hours approval
  void _navigateToHours(Map<String, dynamic> data) {
    final timesheetId = data['timesheetId'];

    // TODO: Implement navigation to hours screen
    print('Navigate to hours: $timesheetId');
  }

  /// Navigate to notifications list
  void _navigateToNotifications() {
    // TODO: Implement navigation to notifications screen
    print('Navigate to notifications list');
  }

  /// Update badge count based on notification data
  void _updateBadgeCount(Map<String, dynamic>? data) {
    if (data == null) return;

    final type = data['type'] as String?;

    switch (type) {
      case 'chat':
        _unreadChatCount++;
        break;
      case 'task':
        _unreadTaskCount++;
        break;
    }

    _notificationCountController.add(totalUnreadCount);

    // Update app badge (iOS)
    if (Platform.isIOS) {
      // badges.updateBadgeCount(totalUnreadCount);
    }
  }

  /// Reset badge count for a specific type
  void resetBadgeCount(String type) {
    switch (type) {
      case 'chat':
        _unreadChatCount = 0;
        break;
      case 'task':
        _unreadTaskCount = 0;
        break;
    }

    _notificationCountController.add(totalUnreadCount);

    if (Platform.isIOS && totalUnreadCount == 0) {
      // badges.removeBadge();
    }
  }

  /// Load notification preferences
  Future<void> _loadNotificationPreferences() async {
    final preferences = await _apiService.getNotificationPreferences();
    if (preferences != null) {
      print('Loaded notification preferences: $preferences');
    }
  }

  /// Update notification preferences
  Future<void> updatePreferences(Map<String, bool> preferences) async {
    await _apiService.updateNotificationPreferences(preferences);
  }

  /// Send test notification
  Future<void> sendTestNotification() async {
    await _apiService.sendTestNotification();
  }

  /// Unregister device on logout
  Future<void> unregisterDevice() async {
    try {
      final deviceState = await OneSignal.User.getOnesignalId();

      if (deviceState != null) {
        await _apiService.unregisterDevice(deviceState);
      }

      // Clear OneSignal user
      OneSignal.logout();

      print('✅ Device unregistered');
    } catch (e) {
      print('❌ Failed to unregister device: $e');
    }
  }

  /// Dispose resources
  void dispose() {
    _notificationCountController.close();
  }
}