import 'package:injectable/injectable.dart';
import 'package:qonversion_flutter/qonversion_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../../../../core/network/api_client.dart';

/// Subscription Service for Manager App
/// Handles Qonversion integration and subscription management
/// Integrated with GetIt dependency injection
@lazySingleton
class SubscriptionService {
  final ApiClient _apiClient;

  SubscriptionService(this._apiClient);

  bool _initialized = false;
  String? _qonversionUserId;

  /// Initialize Qonversion SDK
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Get Qonversion project key from environment
      final projectKey = dotenv.env['QONVERSION_PROJECT_KEY'];
      if (projectKey == null || projectKey.isEmpty) {
        print('[SubscriptionService] QONVERSION_PROJECT_KEY not found - subscription disabled');
        _initialized = true;
        return;
      }

      print('[SubscriptionService] Initializing Qonversion SDK...');

      // Initialize Qonversion SDK (v11 API)
      final config = QonversionConfigBuilder(
        projectKey,
        QLaunchMode.subscriptionManagement,
      ).build();
      Qonversion.initialize(config);

      // Get Qonversion user info
      final userInfo = await Qonversion.getSharedInstance().userInfo();
      _qonversionUserId = userInfo.qonversionId;
      print('[SubscriptionService] Qonversion initialized, user ID: $_qonversionUserId');

      // Link to backend
      if (_qonversionUserId != null && _qonversionUserId!.isNotEmpty) {
        await _linkUserToBackend(_qonversionUserId!);
      }

      _initialized = true;
    } catch (e) {
      print('[SubscriptionService] Initialization failed: $e');
      _initialized = true; // Mark as initialized to prevent retry loops
    }
  }

  /// Get current subscription status from Qonversion
  Future<Map<String, dynamic>> getSubscriptionStatus() async {
    try {
      if (!_initialized) {
        await initialize();
      }

      // If Qonversion isn't configured, return free tier
      if (_qonversionUserId == null) {
        return {'tier': 'free', 'isActive': false};
      }

      // Check Qonversion entitlements
      final entitlements = await Qonversion.getSharedInstance().checkEntitlements();

      // Look for 'pro' entitlement
      final proEntitlement = entitlements['pro'];
      final isActive = proEntitlement != null && proEntitlement.isActive;

      print('[SubscriptionService] Status check: ${isActive ? 'Pro' : 'Free'}');

      // Sync with backend
      await _syncWithBackend();

      return {
        'tier': isActive ? 'pro' : 'free',
        'isActive': isActive,
        'expirationDate': proEntitlement?.expirationDate?.toIso8601String(),
      };
    } catch (e) {
      print('[SubscriptionService] Error getting status: $e');
      return {'tier': 'free', 'isActive': false};
    }
  }

  /// Purchase Pro subscription (pricing TBD: $15-25/month)
  Future<bool> purchaseProSubscription() async {
    try {
      if (!_initialized) {
        await initialize();
      }

      // If Qonversion isn't configured, return false
      if (_qonversionUserId == null) {
        print('[SubscriptionService] Cannot purchase - Qonversion not initialized');
        return false;
      }

      // Get available offerings
      final offerings = await Qonversion.getSharedInstance().offerings();
      final mainOffering = offerings.main;

      if (mainOffering == null) {
        print('[SubscriptionService] No offerings available');
        return false;
      }

      // Find Pro subscription product (monthly subscription)
      QProduct? proProduct;
      for (final product in mainOffering.products) {
        if (product.qonversionId == 'manager_pro_monthly') {
          proProduct = product;
          break;
        }
      }

      if (proProduct == null) {
        print('[SubscriptionService] Pro product not found');
        return false;
      }

      print('[SubscriptionService] Purchasing ${proProduct.qonversionId}...');

      // Purchase using v11 API
      final result = await Qonversion.getSharedInstance().purchaseProduct(proProduct);

      // Check if purchase was successful
      final isActive = result['pro']?.isActive ?? false;

      if (isActive) {
        print('[SubscriptionService] Purchase successful!');
        await _syncWithBackend();
      } else {
        print('[SubscriptionService] Purchase completed but entitlement not active');
      }

      return isActive;
    } catch (e) {
      print('[SubscriptionService] Purchase failed: $e');
      return false;
    }
  }

  /// Restore purchases (for users who already subscribed on another device)
  Future<bool> restorePurchases() async {
    try {
      if (!_initialized) {
        await initialize();
      }

      // If Qonversion isn't configured, return false
      if (_qonversionUserId == null) {
        print('[SubscriptionService] Cannot restore - Qonversion not initialized');
        return false;
      }

      // Restore purchases from App Store/Google Play
      final entitlements = await Qonversion.getSharedInstance().restore();

      // Check if Pro entitlement is active
      final isActive = entitlements['pro']?.isActive ?? false;

      if (isActive) {
        print('[SubscriptionService] Subscription restored!');
        await _syncWithBackend();
      } else {
        print('[SubscriptionService] No active subscription found');
      }

      return isActive;
    } catch (e) {
      print('[SubscriptionService] Restore failed: $e');
      return false;
    }
  }

  /// Get manager-specific usage statistics
  /// Returns team size, event count, analytics access
  Future<Map<String, dynamic>> getManagerUsage() async {
    try {
      final response = await _apiClient.get('/subscription/manager/usage');

      if (response.statusCode == 200) {
        print('[SubscriptionService] Usage stats loaded successfully');
        return response.data as Map<String, dynamic>;
      }

      print('[SubscriptionService] Failed to get usage: ${response.statusCode}');
      return {};
    } catch (e) {
      print('[SubscriptionService] Usage fetch error: $e');
      return {};
    }
  }

  /// Get subscription details from backend
  Future<Map<String, dynamic>> getBackendStatus() async {
    try {
      final response = await _apiClient.get('/subscription/status');

      if (response.statusCode == 200) {
        print('[SubscriptionService] Backend status: ${response.data['tier']}');
        return response.data as Map<String, dynamic>;
      }

      print('[SubscriptionService] Backend status fetch failed: ${response.statusCode}');
      return {};
    } catch (e) {
      print('[SubscriptionService] Backend status error: $e');
      return {};
    }
  }

  /// Link Qonversion user ID to backend
  Future<void> _linkUserToBackend(String qonversionUserId) async {
    try {
      final response = await _apiClient.post(
        '/subscription/link-user',
        data: {'qonversionUserId': qonversionUserId},
      );

      if (response.statusCode == 200) {
        print('[SubscriptionService] User linked successfully');
      } else {
        print('[SubscriptionService] Link user failed: ${response.statusCode}');
      }
    } catch (e) {
      print('[SubscriptionService] Link user error: $e');
    }
  }

  /// Sync subscription state with backend
  Future<void> _syncWithBackend() async {
    try {
      final response = await _apiClient.post('/subscription/sync');

      if (response.statusCode == 200) {
        print('[SubscriptionService] Sync successful');
      } else {
        print('[SubscriptionService] Sync failed: ${response.statusCode}');
      }
    } catch (e) {
      print('[SubscriptionService] Sync error: $e');
    }
  }

  /// Check if manager is Pro subscriber
  Future<bool> isPro() async {
    final status = await getSubscriptionStatus();
    return status['tier'] == 'pro' && status['isActive'] == true;
  }

  /// Check if team limit is reached (free tier: 25 members)
  Future<bool> canAddTeamMember() async {
    final usage = await getManagerUsage();
    return (usage['teamMembers']?['canAddMore'] as bool?) ?? true;
  }

  /// Check if event limit is reached (free tier: 10 events/month)
  Future<bool> canCreateEvent() async {
    final usage = await getManagerUsage();
    return (usage['events']?['canCreateMore'] as bool?) ?? true;
  }

  /// Check if analytics is accessible (Pro only)
  Future<bool> hasAnalyticsAccess() async {
    final usage = await getManagerUsage();
    return (usage['analytics']?['hasAccess'] as bool?) ?? false;
  }
}
