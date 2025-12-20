import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../services/extraction_service.dart';
import '../services/event_service.dart';

/// Status of a file being processed in bulk extraction
enum BulkFileStatus {
  pending,
  processing,
  success,
  failed,
}

/// Represents a single file in the bulk extraction queue
class BulkFileItem {
  final File file;
  final String fileName;
  final bool isImage;
  final int fileSize;
  BulkFileStatus status;
  String? errorMessage;
  Map<String, dynamic>? extractedData;
  String? createdEventId;

  BulkFileItem({
    required this.file,
    required this.fileName,
    required this.isImage,
    required this.fileSize,
    this.status = BulkFileStatus.pending,
    this.errorMessage,
    this.extractedData,
    this.createdEventId,
  });

  /// Human-readable file size
  String get formattedSize {
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// Provider for managing bulk file extraction and event creation
class BulkExtractionProvider extends ChangeNotifier {
  final ExtractionService _extractionService = ExtractionService();
  final EventService _eventService = EventService();

  List<BulkFileItem> _files = [];
  bool _isProcessing = false;
  bool _isCancelled = false;
  bool _isComplete = false;

  // Public getters
  List<BulkFileItem> get files => List.unmodifiable(_files);
  bool get isProcessing => _isProcessing;
  bool get isCancelled => _isCancelled;
  bool get isComplete => _isComplete;
  bool get hasFiles => _files.isNotEmpty;

  int get totalFiles => _files.length;
  int get pendingCount => _files.where((f) => f.status == BulkFileStatus.pending).length;
  int get processingCount => _files.where((f) => f.status == BulkFileStatus.processing).length;
  int get successCount => _files.where((f) => f.status == BulkFileStatus.success).length;
  int get failedCount => _files.where((f) => f.status == BulkFileStatus.failed).length;
  int get completedCount => successCount + failedCount;

  double get progress => totalFiles > 0 ? completedCount / totalFiles : 0.0;

  /// Add files to the queue
  void addFiles(List<File> newFiles) {
    for (final file in newFiles) {
      final fileName = file.path.split('/').last;
      final extension = fileName.split('.').last.toLowerCase();
      final isImage = ['jpg', 'jpeg', 'png', 'heic'].contains(extension);

      // Skip duplicates
      if (_files.any((f) => f.file.path == file.path)) continue;

      _files.add(BulkFileItem(
        file: file,
        fileName: fileName,
        isImage: isImage,
        fileSize: file.lengthSync(),
      ));
    }
    notifyListeners();
  }

  /// Remove a file from the queue
  void removeFile(int index) {
    if (index >= 0 && index < _files.length) {
      _files.removeAt(index);
      notifyListeners();
    }
  }

  /// Clear all files
  void clearAll() {
    _files.clear();
    _isComplete = false;
    _isCancelled = false;
    notifyListeners();
  }

  /// Reset state for another round of imports
  void reset() {
    _files.clear();
    _isProcessing = false;
    _isCancelled = false;
    _isComplete = false;
    notifyListeners();
  }

  /// Cancel ongoing processing
  void cancel() {
    _isCancelled = true;
    notifyListeners();
  }

  /// Process all files sequentially
  /// Sequential processing avoids API rate limits and provides clear progress
  Future<void> processAllFiles() async {
    if (_files.isEmpty || _isProcessing) return;

    _isProcessing = true;
    _isCancelled = false;
    _isComplete = false;
    notifyListeners();

    for (int i = 0; i < _files.length; i++) {
      if (_isCancelled) break;

      final item = _files[i];

      // Skip already processed files
      if (item.status == BulkFileStatus.success ||
          item.status == BulkFileStatus.failed) {
        continue;
      }

      // Mark as processing
      item.status = BulkFileStatus.processing;
      notifyListeners();

      try {
        // Step 1: Read file and prepare input
        final bytes = await item.file.readAsBytes();
        String input;

        if (item.isImage) {
          // Images: convert to base64 with marker
          final base64 = base64Encode(bytes);
          input = '[[IMAGE_BASE64]]:$base64';
        } else {
          // PDFs: extract text first
          input = await _extractTextFromPdf(bytes);
          if (input.trim().isEmpty) {
            throw Exception('No text found in PDF. It may be scanned or image-based.');
          }
        }

        // Step 2: Extract structured data via AI
        final extractedData = await _extractionService.extractStructuredData(
          input: input,
        );
        item.extractedData = extractedData;

        // Step 3: Sanitize and create event as draft
        final eventPayload = _sanitizeEventPayload(extractedData);

        final createdEvent = await _eventService.createEvent(eventPayload);
        item.createdEventId = createdEvent['_id']?.toString() ?? createdEvent['id']?.toString();
        item.status = BulkFileStatus.success;

      } on SubscriptionLimitException catch (e) {
        item.status = BulkFileStatus.failed;
        item.errorMessage = e.message;
        // Stop processing on subscription limit
        _isCancelled = true;
      } catch (e) {
        item.status = BulkFileStatus.failed;
        item.errorMessage = _formatErrorMessage(e.toString());
      }

      notifyListeners();

      // Small delay between files to be gentle on the API
      if (!_isCancelled && i < _files.length - 1) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
    }

    _isProcessing = false;
    _isComplete = true;
    notifyListeners();
  }

  /// Sanitize extracted data to match backend validation requirements
  Map<String, dynamic> _sanitizeEventPayload(Map<String, dynamic> data) {
    final payload = <String, dynamic>{
      ...data,
      'status': 'draft',
    };

    // Clean up empty string fields that should be null
    // Backend rejects empty strings for email validation
    final fieldsToNullifyIfEmpty = [
      'contact_email',
      'contact_phone',
      'contact_name',
      'uniform',
      'pay_rate_info',
    ];

    for (final field in fieldsToNullifyIfEmpty) {
      if (payload[field] is String && (payload[field] as String).trim().isEmpty) {
        payload.remove(field);
      }
    }

    // Sanitize roles array
    if (payload['roles'] != null && payload['roles'] is List) {
      final roles = (payload['roles'] as List).map((role) {
        if (role is Map<String, dynamic>) {
          final sanitizedRole = <String, dynamic>{...role};

          // Ensure count is a number, default to 1 if null or invalid
          if (sanitizedRole['count'] == null || sanitizedRole['count'] is! num) {
            sanitizedRole['count'] = 1;
          }

          // Ensure role name exists
          final roleName = sanitizedRole['role'] as String?;
          if (roleName == null || roleName.isEmpty) {
            sanitizedRole['role'] = 'Staff';
          }

          // Normalize call_time - extract HH:mm from ISO datetime
          if (sanitizedRole['call_time'] is String) {
            final callTime = sanitizedRole['call_time'] as String;
            if (callTime.contains('T') && callTime.length > 10) {
              final match = RegExp(r'T(\d{2}:\d{2})').firstMatch(callTime);
              if (match != null) {
                sanitizedRole['call_time'] = match.group(1);
              }
            }
            // Remove invalid call_time (too long or missing colon)
            if (!(sanitizedRole['call_time'] as String).contains(':') ||
                (sanitizedRole['call_time'] as String).length > 10) {
              sanitizedRole.remove('call_time');
            }
          } else if (sanitizedRole['call_time'] == null) {
            sanitizedRole.remove('call_time');
          }

          return sanitizedRole;
        }
        return {'role': 'Staff', 'count': 1};
      }).toList();

      // Filter out roles without valid names
      payload['roles'] = roles.where((r) =>
        r['role'] != null &&
        (r['role'] as String).isNotEmpty
      ).toList();
    }

    // Ensure at least one role exists
    if (payload['roles'] == null || (payload['roles'] as List).isEmpty) {
      payload['roles'] = [{'role': 'Staff', 'count': 1}];
    }

    // Normalize time fields - strip ISO date prefix if present (e.g., "2025-08-13T16:00:00Z" → "16:00")
    final timeFields = ['start_time', 'end_time', 'setup_time'];
    for (final field in timeFields) {
      if (payload[field] is String) {
        final value = payload[field] as String;
        // Check if it's a full ISO datetime
        if (value.contains('T') && value.length > 10) {
          // Extract just the time portion (HH:mm)
          final match = RegExp(r'T(\d{2}:\d{2})').firstMatch(value);
          if (match != null) {
            payload[field] = match.group(1);
          }
        }
        // Remove descriptive text like "30 minutes before event start time"
        if (!(payload[field] as String).contains(':') || (payload[field] as String).length > 10) {
          payload.remove(field);
        }
      }
    }

    // Normalize date field - ensure it's just YYYY-MM-DD
    if (payload['date'] is String) {
      final dateValue = payload['date'] as String;
      if (dateValue.contains('T')) {
        payload['date'] = dateValue.split('T').first;
      }
    }

    return payload;
  }

  /// Extract text from PDF bytes using Syncfusion
  Future<String> _extractTextFromPdf(Uint8List bytes) async {
    final document = PdfDocument(inputBytes: bytes);
    final extractor = PdfTextExtractor(document);
    final buffer = StringBuffer();

    for (int i = 0; i < document.pages.count; i++) {
      buffer.writeln(extractor.extractText(startPageIndex: i, endPageIndex: i));
    }

    document.dispose();
    return buffer.toString();
  }

  /// Format error message for display
  String _formatErrorMessage(String error) {
    if (error.contains('rate limit')) {
      return 'Rate limit reached. Try again later.';
    }
    if (error.contains('No text found')) {
      return 'PDF appears to be scanned/image-based.';
    }
    if (error.contains('429')) {
      return 'API rate limit. Please wait.';
    }
    if (error.length > 50) {
      return '${error.substring(0, 47)}...';
    }
    return error.replaceFirst('Exception: ', '');
  }

  @override
  void dispose() {
    _files.clear();
    super.dispose();
  }
}
