import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:nexa/core/network/api_client.dart';
import 'package:nexa/features/brand/data/models/brand_profile.dart';

enum BrandLoadingState {
  idle,
  loading,
  uploading,
  extractingColors,
  savingColors,
  deleting,
}

/// Provider for managing brand customization state.
class BrandProvider with ChangeNotifier {
  BrandProvider(this._apiClient);

  final ApiClient _apiClient;

  BrandProfile? _profile;
  BrandLoadingState _state = BrandLoadingState.idle;
  String? _error;
  double _uploadProgress = 0;

  // Temporary color edits (before saving)
  String? _editPrimaryColor;
  String? _editSecondaryColor;
  String? _editAccentColor;
  String? _editNeutralColor;

  BrandProfile? get profile => _profile;
  BrandLoadingState get state => _state;
  String? get error => _error;
  double get uploadProgress => _uploadProgress;
  bool get hasProfile => _profile != null && _profile!.hasColors;
  bool get hasLogo => _profile?.hasLogo ?? false;

  String? get editPrimaryColor => _editPrimaryColor;
  String? get editSecondaryColor => _editSecondaryColor;
  String? get editAccentColor => _editAccentColor;
  String? get editNeutralColor => _editNeutralColor;

  bool get hasUnsavedChanges {
    if (_profile == null) return false;
    return (_editPrimaryColor != null && _editPrimaryColor != _profile!.primaryColor) ||
        (_editSecondaryColor != null && _editSecondaryColor != _profile!.secondaryColor) ||
        (_editAccentColor != null && _editAccentColor != _profile!.accentColor) ||
        (_editNeutralColor != null && _editNeutralColor != _profile!.neutralColor);
  }

  /// Get the display color (edited or saved) for each slot.
  String? get displayPrimary => _editPrimaryColor ?? _profile?.primaryColor;
  String? get displaySecondary => _editSecondaryColor ?? _profile?.secondaryColor;
  String? get displayAccent => _editAccentColor ?? _profile?.accentColor;
  String? get displayNeutral => _editNeutralColor ?? _profile?.neutralColor;

  void setEditColor(String slot, String hexColor) {
    switch (slot) {
      case 'primary':
        _editPrimaryColor = hexColor;
      case 'secondary':
        _editSecondaryColor = hexColor;
      case 'accent':
        _editAccentColor = hexColor;
      case 'neutral':
        _editNeutralColor = hexColor;
    }
    notifyListeners();
  }

  void _clearEdits() {
    _editPrimaryColor = null;
    _editSecondaryColor = null;
    _editAccentColor = null;
    _editNeutralColor = null;
  }

  /// Load current brand profile from backend.
  Future<void> loadProfile() async {
    _state = BrandLoadingState.loading;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiClient.get<Map<String, dynamic>>('/brand/profile');
      final data = response.data;
      if (data != null && data['brandProfile'] != null) {
        _profile = BrandProfile.fromJson(data['brandProfile'] as Map<String, dynamic>);
      } else {
        _profile = null;
      }
      _clearEdits();
    } catch (e) {
      _error = 'Failed to load brand profile';
      debugPrint('[BrandProvider] loadProfile error: $e');
    } finally {
      _state = BrandLoadingState.idle;
      notifyListeners();
    }
  }

  /// Upload a logo image file.
  Future<bool> uploadLogo(File file) async {
    _state = BrandLoadingState.uploading;
    _error = null;
    _uploadProgress = 0;
    notifyListeners();

    try {
      final formData = FormData.fromMap({
        'logo': await MultipartFile.fromFile(
          file.path,
          filename: file.path.split('/').last,
        ),
      });

      final response = await _apiClient.post<Map<String, dynamic>>(
        '/brand/logo',
        data: formData,
      );

      _state = BrandLoadingState.extractingColors;
      notifyListeners();

      final data = response.data;
      if (data != null && data['brandProfile'] != null) {
        _profile = BrandProfile.fromJson(data['brandProfile'] as Map<String, dynamic>);
        _clearEdits();
      }

      _state = BrandLoadingState.idle;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to upload logo';
      debugPrint('[BrandProvider] uploadLogo error: $e');
      _state = BrandLoadingState.idle;
      notifyListeners();
      return false;
    }
  }

  /// Save manually edited colors to the backend.
  Future<bool> saveColors() async {
    if (!hasUnsavedChanges) return true;

    _state = BrandLoadingState.savingColors;
    _error = null;
    notifyListeners();

    try {
      final body = <String, String>{};
      if (_editPrimaryColor != null) body['primaryColor'] = _editPrimaryColor!;
      if (_editSecondaryColor != null) body['secondaryColor'] = _editSecondaryColor!;
      if (_editAccentColor != null) body['accentColor'] = _editAccentColor!;
      if (_editNeutralColor != null) body['neutralColor'] = _editNeutralColor!;

      final response = await _apiClient.put<Map<String, dynamic>>(
        '/brand/colors',
        data: body,
      );

      final data = response.data;
      if (data != null && data['brandProfile'] != null) {
        _profile = BrandProfile.fromJson(data['brandProfile'] as Map<String, dynamic>);
      }
      _clearEdits();

      _state = BrandLoadingState.idle;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to save colors';
      debugPrint('[BrandProvider] saveColors error: $e');
      _state = BrandLoadingState.idle;
      notifyListeners();
      return false;
    }
  }

  /// Delete the brand profile entirely.
  Future<bool> deleteBrandProfile() async {
    _state = BrandLoadingState.deleting;
    _error = null;
    notifyListeners();

    try {
      await _apiClient.delete<Map<String, dynamic>>('/brand/profile');
      _profile = null;
      _clearEdits();

      _state = BrandLoadingState.idle;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to remove branding';
      debugPrint('[BrandProvider] deleteBrandProfile error: $e');
      _state = BrandLoadingState.idle;
      notifyListeners();
      return false;
    }
  }
}
