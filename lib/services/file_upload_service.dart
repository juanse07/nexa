import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:nexa/core/network/api_client.dart';

/// Result of a file upload operation
class UploadResult {
  final String url;
  final String? key;
  final String? filename;
  final int? size;

  UploadResult({
    required this.url,
    this.key,
    this.filename,
    this.size,
  });

  factory UploadResult.fromMap(Map<String, dynamic> map) {
    return UploadResult(
      url: map['url'] as String,
      key: map['key'] as String?,
      filename: map['filename'] as String?,
      size: map['size'] as int?,
    );
  }
}

/// Service for uploading files to Cloudflare R2 via the backend API
class FileUploadService {
  FileUploadService(this._apiClient);

  final ApiClient _apiClient;

  /// Uploads a profile picture from a File
  /// Returns the public URL of the uploaded image
  Future<String> uploadProfilePicture(
    File file, {
    void Function(int, int)? onSendProgress,
  }) async {
    final filename = file.path.split('/').last;
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        file.path,
        filename: filename,
      ),
    });

    final response = await _apiClient.post<dynamic>(
      '/upload/profile-picture',
      data: formData,
      options: Options(
        contentType: 'multipart/form-data',
      ),
      onSendProgress: onSendProgress,
    );

    final data = _parseResponse(response.data);
    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'Upload failed');
    }
    return data['url'] as String;
  }

  /// Helper to parse response data that might be String or Map
  Map<String, dynamic> _parseResponse(dynamic data) {
    if (data == null) return {};
    if (data is Map<String, dynamic>) return data;
    if (data is String) {
      try {
        return jsonDecode(data) as Map<String, dynamic>;
      } catch (_) {
        return {'message': data};
      }
    }
    return {};
  }

  /// Uploads a profile picture from bytes (useful for web or cropped images)
  Future<String> uploadProfilePictureBytes(
    Uint8List bytes,
    String filename, {
    void Function(int, int)? onSendProgress,
  }) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(
        bytes,
        filename: filename,
      ),
    });

    final response = await _apiClient.post<dynamic>(
      '/upload/profile-picture',
      data: formData,
      options: Options(
        contentType: 'multipart/form-data',
      ),
      onSendProgress: onSendProgress,
    );

    final data = _parseResponse(response.data);
    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'Upload failed');
    }
    return data['url'] as String;
  }

  /// Uploads a document (PDF, contract, etc.)
  /// Returns the upload result with URL and key
  Future<UploadResult> uploadDocument(
    File file, {
    void Function(int, int)? onSendProgress,
  }) async {
    final filename = file.path.split('/').last;
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        file.path,
        filename: filename,
      ),
    });

    final response = await _apiClient.post<dynamic>(
      '/upload/document',
      data: formData,
      options: Options(
        contentType: 'multipart/form-data',
      ),
      onSendProgress: onSendProgress,
    );

    final data = _parseResponse(response.data);
    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'Upload failed');
    }
    return UploadResult.fromMap(data);
  }

  /// Uploads a sign-in sheet photo for an event
  /// Returns the public URL of the uploaded image
  Future<String> uploadSignInSheet(
    String eventId,
    File file, {
    void Function(int, int)? onSendProgress,
  }) async {
    final filename = file.path.split('/').last;
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        file.path,
        filename: filename,
      ),
    });

    final response = await _apiClient.post<dynamic>(
      '/upload/sign-in-sheet/$eventId',
      data: formData,
      options: Options(
        contentType: 'multipart/form-data',
      ),
      onSendProgress: onSendProgress,
    );

    final data = _parseResponse(response.data);
    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'Upload failed');
    }
    return data['url'] as String;
  }

  /// Uploads a sign-in sheet from bytes
  Future<String> uploadSignInSheetBytes(
    String eventId,
    Uint8List bytes,
    String filename, {
    void Function(int, int)? onSendProgress,
  }) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(
        bytes,
        filename: filename,
      ),
    });

    final response = await _apiClient.post<dynamic>(
      '/upload/sign-in-sheet/$eventId',
      data: formData,
      options: Options(
        contentType: 'multipart/form-data',
      ),
      onSendProgress: onSendProgress,
    );

    final data = _parseResponse(response.data);
    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'Upload failed');
    }
    return data['url'] as String;
  }

  /// Gets a presigned URL for downloading a private file
  Future<String> getPresignedUrl(
    String key, {
    int expiresInSeconds = 3600,
  }) async {
    final response = await _apiClient.get<dynamic>(
      '/upload/presigned-url',
      queryParameters: {
        'key': key,
        'expiresIn': expiresInSeconds,
      },
    );

    final data = _parseResponse(response.data);
    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'Failed to get URL');
    }
    return data['url'] as String;
  }

  /// Deletes a file from storage
  Future<void> deleteFile(String key) async {
    await _apiClient.delete<void>(
      '/upload/file',
      data: {'key': key},
    );
  }
}
