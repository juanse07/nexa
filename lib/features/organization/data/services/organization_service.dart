import 'package:injectable/injectable.dart';

import '../../../../core/network/api_client.dart';

@lazySingleton
class OrganizationService {
  final ApiClient _apiClient;

  OrganizationService(this._apiClient);

  /// Get the current manager's organization (or null)
  Future<Map<String, dynamic>?> getMyOrganization() async {
    try {
      final response = await _apiClient.get('/organizations/mine');
      if (response.statusCode == 200) {
        return response.data['organization'] as Map<String, dynamic>?;
      }
      return null;
    } catch (e) {
      print('[OrganizationService] getMyOrganization error: $e');
      return null;
    }
  }

  /// Create a new organization (manager becomes owner)
  Future<Map<String, dynamic>?> createOrganization(String name) async {
    try {
      final response = await _apiClient.post(
        '/organizations',
        data: {'name': name},
      );
      if (response.statusCode == 201) {
        return response.data as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('[OrganizationService] createOrganization error: $e');
      return null;
    }
  }

  /// Create a Stripe Checkout session URL for org Pro subscription
  Future<String?> createCheckoutSession(
    String orgId, {
    required String successUrl,
    required String cancelUrl,
  }) async {
    try {
      final response = await _apiClient.post(
        '/organizations/$orgId/checkout',
        data: {
          'successUrl': successUrl,
          'cancelUrl': cancelUrl,
        },
      );
      if (response.statusCode == 200) {
        return response.data['url'] as String?;
      }
      return null;
    } catch (e) {
      print('[OrganizationService] createCheckoutSession error: $e');
      return null;
    }
  }

  /// Create a Stripe Billing Portal session URL
  Future<String?> createPortalSession(String orgId) async {
    try {
      final response = await _apiClient.post(
        '/organizations/$orgId/portal',
      );
      if (response.statusCode == 200) {
        return response.data['url'] as String?;
      }
      return null;
    } catch (e) {
      print('[OrganizationService] createPortalSession error: $e');
      return null;
    }
  }

  /// Invite a manager to the organization by email
  Future<Map<String, dynamic>?> inviteMember(
    String orgId,
    String email, {
    String role = 'member',
  }) async {
    try {
      final response = await _apiClient.post(
        '/organizations/$orgId/members',
        data: {'email': email, 'role': role},
      );
      if (response.statusCode == 201) {
        return response.data as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('[OrganizationService] inviteMember error: $e');
      return null;
    }
  }

  /// Remove a member from the organization
  Future<bool> removeMember(String orgId, String managerId) async {
    try {
      final response = await _apiClient.delete(
        '/organizations/$orgId/members/$managerId',
      );
      return response.statusCode == 200;
    } catch (e) {
      print('[OrganizationService] removeMember error: $e');
      return false;
    }
  }

  /// Join an organization via invite token
  Future<Map<String, dynamic>?> joinOrganization(String token) async {
    try {
      final response = await _apiClient.post(
        '/organizations/join/$token',
      );
      if (response.statusCode == 200) {
        return response.data as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('[OrganizationService] joinOrganization error: $e');
      return null;
    }
  }

  /// Transfer organization ownership to another member
  Future<bool> transferOwnership(String orgId, String newOwnerId) async {
    try {
      final response = await _apiClient.post(
        '/organizations/$orgId/transfer',
        data: {'newOwnerId': newOwnerId},
      );
      return response.statusCode == 200;
    } catch (e) {
      print('[OrganizationService] transferOwnership error: $e');
      return false;
    }
  }

  // ─── Staff Pool Management ─────────────────────────────────────

  /// Get the approved staff pool for an organization
  Future<List<Map<String, dynamic>>?> getStaffPool(String orgId) async {
    try {
      final response = await _apiClient.get('/organizations/$orgId/staff');
      if (response.statusCode == 200) {
        final staff = response.data['staff'] as List?;
        return staff?.cast<Map<String, dynamic>>();
      }
      return null;
    } catch (e) {
      print('[OrganizationService] getStaffPool error: $e');
      return null;
    }
  }

  /// Add a staff member to the approved pool
  Future<Map<String, dynamic>?> addStaffToPool(
    String orgId, {
    required String provider,
    required String subject,
    String? name,
    String? email,
  }) async {
    try {
      final response = await _apiClient.post(
        '/organizations/$orgId/staff',
        data: {
          'provider': provider,
          'subject': subject,
          if (name != null) 'name': name,
          if (email != null) 'email': email,
        },
      );
      if (response.statusCode == 201) {
        return response.data['entry'] as Map<String, dynamic>?;
      }
      return null;
    } catch (e) {
      print('[OrganizationService] addStaffToPool error: $e');
      return null;
    }
  }

  /// Remove a staff member from the approved pool
  Future<bool> removeStaffFromPool(
    String orgId,
    String provider,
    String subject,
  ) async {
    try {
      final response = await _apiClient.delete(
        '/organizations/$orgId/staff/$provider/$subject',
      );
      return response.statusCode == 200;
    } catch (e) {
      print('[OrganizationService] removeStaffFromPool error: $e');
      return false;
    }
  }

  /// Update the organization's staff policy
  Future<bool> updateStaffPolicy(String orgId, String policy) async {
    try {
      final response = await _apiClient.patch(
        '/organizations/$orgId/policy',
        data: {'staffPolicy': policy},
      );
      return response.statusCode == 200;
    } catch (e) {
      print('[OrganizationService] updateStaffPolicy error: $e');
      return false;
    }
  }
}
