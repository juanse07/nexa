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
  final String? picture;
  final String? appId;

  ManagerProfile({this.id, this.email, this.firstName, this.lastName, this.picture, this.appId});

  factory ManagerProfile.fromMap(Map<String, dynamic> map) {
    return ManagerProfile(
      id: map['id']?.toString(),
      email: map['email']?.toString(),
      firstName: map['first_name']?.toString(),
      lastName: map['last_name']?.toString(),
      picture: map['picture']?.toString(),
      appId: map['app_id']?.toString(),
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

  Future<ManagerProfile> updateMe({String? firstName, String? lastName, String? appId, String? picture}) async {
    final payload = <String, dynamic>{};
    if (firstName != null) payload['first_name'] = firstName;
    if (lastName != null) payload['last_name'] = lastName;
    if (appId != null) payload['app_id'] = appId;
    if (picture != null) payload['picture'] = picture;
    final resp = await _apiClient.patch<Map<String, dynamic>>('/managers/me', data: payload);
    final data = resp.data ?? {};
    return ManagerProfile.fromMap(data);
  }
}


