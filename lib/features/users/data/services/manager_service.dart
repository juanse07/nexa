import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:nexa/core/constants/storage_keys.dart';
import 'package:nexa/core/network/api_client.dart';

class CaricatureHistoryItem {
  final String url;
  final String role;
  final String artStyle;
  final DateTime createdAt;

  CaricatureHistoryItem({
    required this.url,
    required this.role,
    required this.artStyle,
    required this.createdAt,
  });

  factory CaricatureHistoryItem.fromMap(Map<String, dynamic> map) {
    return CaricatureHistoryItem(
      url: map['url'] as String? ?? '',
      role: map['role'] as String? ?? '',
      artStyle: map['artStyle'] as String? ?? '',
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

class ManagerProfile {
  final String? id;
  final String? email;
  final String? firstName;
  final String? lastName;
  final String? name;
  final String? picture;
  final String? originalPicture; // pre-caricature picture (for revert)
  final List<CaricatureHistoryItem> caricatureHistory;
  final String? appId;
  final String? phoneNumber;

  ManagerProfile({
    this.id,
    this.email,
    this.firstName,
    this.lastName,
    this.name,
    this.picture,
    this.originalPicture,
    this.caricatureHistory = const [],
    this.appId,
    this.phoneNumber,
  });

  factory ManagerProfile.fromMap(Map<String, dynamic> map) {
    final historyRaw = map['caricatureHistory'] as List<dynamic>? ?? [];
    return ManagerProfile(
      id: map['id']?.toString(),
      email: map['email']?.toString(),
      firstName: map['first_name']?.toString(),     // Backend returns snake_case
      lastName: map['last_name']?.toString(),       // Backend returns snake_case
      name: map['name']?.toString(),
      picture: map['picture']?.toString(),
      originalPicture: map['originalPicture']?.toString(),
      caricatureHistory: historyRaw
          .map((e) => CaricatureHistoryItem.fromMap(e as Map<String, dynamic>))
          .toList(),
      appId: map['app_id']?.toString(),             // Backend returns snake_case
      phoneNumber: map['phone_number']?.toString(), // Backend returns snake_case
    );
  }
}

class ManagerService {
  ManagerService(this._apiClient, this._secureStorage);

  final ApiClient _apiClient;
  final FlutterSecureStorage _secureStorage;

  Future<ManagerProfile> getMe() async {
    final resp = await _apiClient.get<Map<String, dynamic>>('/managers/me');
    final data = resp.data ?? {};
    return ManagerProfile.fromMap(data);
  }

  Future<ManagerProfile> updateMe({
    String? firstName,
    String? lastName,
    String? appId,
    String? picture,
    String? phoneNumber,
    bool isCaricature = false,
  }) async {
    final payload = <String, dynamic>{};
    if (firstName != null) payload['first_name'] = firstName;      // Backend expects snake_case
    if (lastName != null) payload['last_name'] = lastName;        // Backend expects snake_case
    if (appId != null) payload['app_id'] = appId;                 // Backend expects snake_case
    if (picture != null) payload['picture'] = picture;
    if (phoneNumber != null) payload['phone_number'] = phoneNumber; // Backend expects snake_case
    if (isCaricature) payload['isCaricature'] = true;

    final resp = await _apiClient.patch<Map<String, dynamic>>('/managers/me', data: payload);
    final data = resp.data ?? {};
    return ManagerProfile.fromMap(data);
  }

  /// Revert to the original (pre-caricature) picture.
  Future<ManagerProfile> revertPicture() async {
    final resp = await _apiClient.post<Map<String, dynamic>>('/managers/me/revert-picture');
    final data = resp.data ?? {};
    // Return a partial profile — caller should reload for full data
    return ManagerProfile(
      picture: data['picture']?.toString(),
      originalPicture: data['originalPicture']?.toString(),
    );
  }

  /// Delete a caricature from history by index.
  Future<List<CaricatureHistoryItem>> deleteCaricature(int index) async {
    final resp = await _apiClient.delete<Map<String, dynamic>>('/managers/me/caricatures/$index');
    final data = resp.data ?? {};
    final historyRaw = data['caricatureHistory'] as List<dynamic>? ?? [];
    return historyRaw
        .map((e) => CaricatureHistoryItem.fromMap(e as Map<String, dynamic>))
        .toList();
  }
}


