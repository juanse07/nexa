import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:nexa/core/constants/storage_keys.dart';
import 'package:nexa/core/network/api_client.dart';

class ManagerProfile {
  final String? id;
  final String? email;
  final String? firstName;
  final String? lastName;
  final String? name;
  final String? picture;
  final String? appId;
  final String? phoneNumber;

  ManagerProfile({
    this.id,
    this.email,
    this.firstName,
    this.lastName,
    this.name,
    this.picture,
    this.appId,
    this.phoneNumber,
  });

  factory ManagerProfile.fromMap(Map<String, dynamic> map) {
    return ManagerProfile(
      id: map['id']?.toString(),
      email: map['email']?.toString(),
      firstName: map['first_name']?.toString(),     // Backend returns snake_case
      lastName: map['last_name']?.toString(),       // Backend returns snake_case
      name: map['name']?.toString(),
      picture: map['picture']?.toString(),
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
  }) async {
    final payload = <String, dynamic>{};
    if (firstName != null) payload['first_name'] = firstName;      // Backend expects snake_case
    if (lastName != null) payload['last_name'] = lastName;        // Backend expects snake_case
    if (appId != null) payload['app_id'] = appId;                 // Backend expects snake_case
    if (picture != null) payload['picture'] = picture;
    if (phoneNumber != null) payload['phone_number'] = phoneNumber; // Backend expects snake_case

    final resp = await _apiClient.patch<Map<String, dynamic>>('/managers/me', data: payload);
    final data = resp.data ?? {};
    return ManagerProfile.fromMap(data);
  }
}


