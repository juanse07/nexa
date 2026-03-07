import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../services/extraction_service.dart';
import '../services/event_service.dart';

/// Phases of the bulk import flow.
enum BulkPhase { selectFiles, extracting, preview, creating, complete }

/// Status of a file being processed in bulk extraction
enum BulkFileStatus {
  pending,
  processing,
  success,
  failed,
}

/// Tracks one extracted event within a file (a file can yield multiple events).
class BulkExtractedEventItem {
  Map<String, dynamic> data;
  bool isSelected;
  String? createdEventId;
  String? errorMessage;

  BulkExtractedEventItem({
    required this.data,
    this.isSelected = true,
    this.createdEventId,
    this.errorMessage,
  });

  bool get created => createdEventId != null;
}

/// Represents a single file in the bulk extraction queue
class BulkFileItem {
  final File file;
  final String fileName;
  final bool isImage;
  final int fileSize;
  BulkFileStatus status;
  String? errorMessage;
  /// Events extracted from this file (may be 1 or many).
  List<BulkExtractedEventItem> extractedEvents;

  // Legacy single-event accessors for backward compat with UI
  Map<String, dynamic>? get extractedData =>
      extractedEvents.isNotEmpty ? extractedEvents.first.data : null;
  String? get createdEventId =>
      extractedEvents.isNotEmpty ? extractedEvents.first.createdEventId : null;

  BulkFileItem({
    required this.file,
    required this.fileName,
    required this.isImage,
    required this.fileSize,
    this.status = BulkFileStatus.pending,
    this.errorMessage,
    List<BulkExtractedEventItem>? extractedEvents,
  }) : extractedEvents = extractedEvents ?? [];

  /// Human-readable file size
  String get formattedSize {
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// Provider for managing bulk file extraction and event creation.
///
/// Flow: selectFiles → extracting → preview (edit/toggle) → creating → complete
class BulkExtractionProvider extends ChangeNotifier {
  final ExtractionService _extractionService = ExtractionService();
  final EventService _eventService = EventService();

  List<BulkFileItem> _files = [];
  BulkPhase _phase = BulkPhase.selectFiles;
  bool _isCancelled = false;

  // Public getters
  BulkPhase get phase => _phase;
  List<BulkFileItem> get files => List.unmodifiable(_files);
  bool get isCancelled => _isCancelled;
  bool get hasFiles => _files.isNotEmpty;

  // Legacy compat getters used by existing UI code
  bool get isProcessing => _phase == BulkPhase.extracting || _phase == BulkPhase.creating;
  bool get isComplete => _phase == BulkPhase.complete;

  int get totalFiles => _files.length;
  int get pendingCount => _files.where((f) => f.status == BulkFileStatus.pending).length;
  int get processingCount => _files.where((f) => f.status == BulkFileStatus.processing).length;
  int get successCount {
    int count = 0;
    for (final f in _files) {
      count += f.extractedEvents.where((e) => e.created).length;
    }
    return count > 0 ? count : _files.where((f) => f.status == BulkFileStatus.success).length;
  }
  int get failedCount => _files.where((f) => f.status == BulkFileStatus.failed).length;
  int get completedCount => successCount + failedCount;

  double get progress => totalFiles > 0 ? completedCount / totalFiles : 0.0;

  List<BulkExtractedEventItem> get allExtractedEvents =>
      _files.expand((f) => f.extractedEvents).toList();

  int get selectedCount =>
      allExtractedEvents.where((e) => e.isSelected).length;

  int get totalExtractedEvents => allExtractedEvents.length;

  int get extractedFileCount =>
      _files.where((f) => f.status == BulkFileStatus.success || f.extractedEvents.isNotEmpty).length;

  double get extractionProgress {
    if (_files.isEmpty) return 0;
    final done = _files.where((f) =>
        f.status == BulkFileStatus.success ||
        f.status == BulkFileStatus.failed ||
        f.extractedEvents.isNotEmpty).length;
    return done / _files.length;
  }

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
    _phase = BulkPhase.selectFiles;
    _isCancelled = false;
    notifyListeners();
  }

  /// Reset state for another round of imports
  void reset() {
    _files.clear();
    _phase = BulkPhase.selectFiles;
    _isCancelled = false;
    notifyListeners();
  }

  /// Cancel ongoing processing
  void cancel() {
    _isCancelled = true;
    notifyListeners();
  }

  /// Load pre-extracted events from AI Chat (skips file selection + extraction phases).
  /// Jumps directly to the preview phase.
  void loadPreExtractedEvents({
    required File file,
    required List<Map<String, dynamic>> events,
  }) {
    final fileName = file.path.split('/').last;
    final extension = fileName.split('.').last.toLowerCase();
    final isImage = ['jpg', 'jpeg', 'png', 'heic'].contains(extension);

    final item = BulkFileItem(
      file: file,
      fileName: fileName,
      isImage: isImage,
      fileSize: file.existsSync() ? file.lengthSync() : 0,
      status: BulkFileStatus.success,
      extractedEvents: events
          .map((data) => BulkExtractedEventItem(data: data))
          .toList(),
    );

    _files = [item];
    _phase = BulkPhase.preview;
    _isCancelled = false;
    notifyListeners();
  }

  // ── Phase 1: Extract all files (no creation) ──

  Future<void> extractAllFiles() async {
    if (_files.isEmpty) return;

    _phase = BulkPhase.extracting;
    _isCancelled = false;
    notifyListeners();

    for (int i = 0; i < _files.length; i++) {
      if (_isCancelled) break;

      final item = _files[i];
      if (item.extractedEvents.isNotEmpty) continue; // already extracted

      item.status = BulkFileStatus.processing;
      notifyListeners();

      try {
        final bytes = await item.file.readAsBytes();
        String input;

        if (item.isImage) {
          final base64 = base64Encode(bytes);
          input = '[[IMAGE_BASE64]]:$base64';
        } else {
          input = await _extractTextFromPdf(bytes);
          if (input.trim().isEmpty) {
            throw Exception('No text found in PDF. It may be scanned or image-based.');
          }
        }

        final extractedList = await _extractionService.extractStructuredDataMulti(
          input: input,
        );

        if (extractedList.isEmpty) {
          throw Exception('No events found in this file.');
        }

        item.extractedEvents = extractedList
            .map((data) => BulkExtractedEventItem(data: data))
            .toList();
        item.status = BulkFileStatus.success;

      } catch (e) {
        item.status = BulkFileStatus.failed;
        item.errorMessage = _formatErrorMessage(e.toString());
      }

      notifyListeners();

      if (!_isCancelled && i < _files.length - 1) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
    }

    _phase = BulkPhase.preview;
    notifyListeners();
  }

  // ── Preview controls ──

  void toggleEvent(int fileIdx, int eventIdx) {
    if (fileIdx < _files.length &&
        eventIdx < _files[fileIdx].extractedEvents.length) {
      final event = _files[fileIdx].extractedEvents[eventIdx];
      event.isSelected = !event.isSelected;
      notifyListeners();
    }
  }

  void selectAll() {
    for (final f in _files) {
      for (final e in f.extractedEvents) {
        e.isSelected = true;
      }
    }
    notifyListeners();
  }

  void deselectAll() {
    for (final f in _files) {
      for (final e in f.extractedEvents) {
        e.isSelected = false;
      }
    }
    notifyListeners();
  }

  void updateEventData(int fileIdx, int eventIdx, Map<String, dynamic> data) {
    if (fileIdx < _files.length &&
        eventIdx < _files[fileIdx].extractedEvents.length) {
      _files[fileIdx].extractedEvents[eventIdx].data = data;
      notifyListeners();
    }
  }

  /// Apply shared field values to all selected events.
  /// Skips 'date' to preserve each event's individual date.
  void applyBulkEdit(Map<String, dynamic> edits) {
    final safeEdits = Map<String, dynamic>.from(edits)..remove('date');
    for (final file in _files) {
      for (final event in file.extractedEvents) {
        if (!event.isSelected) continue;
        for (final entry in safeEdits.entries) {
          event.data[entry.key] = entry.value;
        }
      }
    }
    notifyListeners();
  }

  // ── Phase 2: Create selected events ──

  Future<void> createSelectedEvents() async {
    _phase = BulkPhase.creating;
    _isCancelled = false;
    notifyListeners();

    for (final file in _files) {
      for (final event in file.extractedEvents) {
        if (_isCancelled) break;
        if (!event.isSelected || event.created) continue;

        try {
          final eventPayload = _sanitizeEventPayload(event.data);
          final createdEvent = await _eventService.createEvent(eventPayload);
          event.createdEventId =
              createdEvent['_id']?.toString() ?? createdEvent['id']?.toString();
        } on SubscriptionLimitException catch (e) {
          event.errorMessage = e.message;
          _isCancelled = true;
        } catch (e) {
          event.errorMessage = _formatErrorMessage(e.toString());
        }

        notifyListeners();

        if (!_isCancelled) {
          await Future<void>.delayed(const Duration(milliseconds: 300));
        }
      }
      if (_isCancelled) break;
    }

    // Update file statuses based on event results
    for (final file in _files) {
      final selected = file.extractedEvents.where((e) => e.isSelected);
      if (selected.isEmpty) continue;
      final anyCreated = selected.any((e) => e.created);
      file.status = anyCreated ? BulkFileStatus.success : BulkFileStatus.failed;
    }

    _phase = BulkPhase.complete;
    notifyListeners();
  }

  /// Legacy method: extract + create in one pass (backward compat).
  Future<void> processAllFiles() async {
    await extractAllFiles();
    if (_isCancelled) return;
    await createSelectedEvents();
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

    // Default times when AI didn't extract them
    payload['start_time'] ??= '09:00';
    payload['end_time'] ??= '17:00';

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
