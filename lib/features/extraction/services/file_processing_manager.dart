import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../widgets/image_preview_card.dart'; // For ExtractionStatus enum
import './extraction_service.dart';

/// Event types for file processing notifications
enum FileProcessingEvent {
  fileAdded,
  statusChanged,
  fileRemoved,
  extractionCompleted,
  extractionFailed,
}

/// Callback for file processing events
typedef FileProcessingCallback = void Function(
  FileProcessingEvent event,
  File file,
  Map<String, dynamic>? extractedData,
);

/// Manages file processing state for images and documents
///
/// Handles:
/// - Image and PDF file tracking
/// - Extraction status management
/// - Error tracking
/// - Auto-removal after successful extraction
/// - Event notifications for UI updates
class FileProcessingManager extends ChangeNotifier {
  final ExtractionService _extractionService;

  // Image state
  final List<File> _selectedImages = [];
  final Map<File, ExtractionStatus> _imageStatuses = {};
  final Map<File, String?> _imageErrors = {};

  // Document state
  final List<File> _selectedDocuments = [];
  final Map<File, ExtractionStatus> _documentStatuses = {};
  final Map<File, String?> _documentErrors = {};

  // Event callback
  FileProcessingCallback? _onEvent;

  FileProcessingManager({
    ExtractionService? extractionService,
  }) : _extractionService = extractionService ?? ExtractionService();

  // Getters for images
  List<File> get selectedImages => List.unmodifiable(_selectedImages);
  Map<File, ExtractionStatus> get imageStatuses => Map.unmodifiable(_imageStatuses);
  Map<File, String?> get imageErrors => Map.unmodifiable(_imageErrors);

  // Getters for documents
  List<File> get selectedDocuments => List.unmodifiable(_selectedDocuments);
  Map<File, ExtractionStatus> get documentStatuses => Map.unmodifiable(_documentStatuses);
  Map<File, String?> get documentErrors => Map.unmodifiable(_documentErrors);

  // Combined status
  bool get isProcessing {
    return _imageStatuses.values.any((s) => s == ExtractionStatus.extracting) ||
        _documentStatuses.values.any((s) => s == ExtractionStatus.extracting);
  }

  int get totalFiles => _selectedImages.length + _selectedDocuments.length;
  int get processingCount {
    return _imageStatuses.values.where((s) => s == ExtractionStatus.extracting).length +
        _documentStatuses.values.where((s) => s == ExtractionStatus.extracting).length;
  }

  /// Set event callback for notifications
  void setEventCallback(FileProcessingCallback callback) {
    _onEvent = callback;
  }

  /// Clear event callback
  void clearEventCallback() {
    _onEvent = null;
  }

  /// Process an image file
  ///
  /// Steps:
  /// 1. Add to tracking with pending status
  /// 2. Convert to base64
  /// 3. Call extraction API
  /// 4. Update status to completed
  /// 5. Auto-remove after 500ms
  /// 6. Notify callback with extracted data
  Future<Map<String, dynamic>?> processImage(File imageFile) async {
    // Add image to list with pending status
    _selectedImages.add(imageFile);
    _imageStatuses[imageFile] = ExtractionStatus.pending;
    _notifyEvent(FileProcessingEvent.fileAdded, imageFile);
    notifyListeners();

    // Start extraction
    _imageStatuses[imageFile] = ExtractionStatus.extracting;
    _notifyEvent(FileProcessingEvent.statusChanged, imageFile);
    notifyListeners();

    try {
      // Read image bytes and convert to base64
      final bytes = await imageFile.readAsBytes();
      final base64String = base64Encode(bytes);
      final processedInput = '[[IMAGE_BASE64]]:$base64String';

      // Call extraction API
      final structuredData = await _extractionService.extractStructuredData(
        input: processedInput,
      );

      // Mark as completed
      _imageStatuses[imageFile] = ExtractionStatus.completed;
      _notifyEvent(FileProcessingEvent.statusChanged, imageFile);
      _notifyEvent(FileProcessingEvent.extractionCompleted, imageFile, structuredData);
      notifyListeners();

      // Auto-remove after delay
      await Future.delayed(const Duration(milliseconds: 500));
      removeImage(imageFile);

      return structuredData;
    } catch (e) {
      print('[FileProcessingManager] Error extracting from image: $e');
      _imageStatuses[imageFile] = ExtractionStatus.failed;
      _imageErrors[imageFile] = e.toString();
      _notifyEvent(FileProcessingEvent.statusChanged, imageFile);
      _notifyEvent(FileProcessingEvent.extractionFailed, imageFile);
      notifyListeners();
      rethrow;
    }
  }

  /// Process a PDF document file
  ///
  /// Steps:
  /// 1. Add to tracking with pending status
  /// 2. Extract text from PDF
  /// 3. Call extraction API with text
  /// 4. Update status to completed
  /// 5. Auto-remove after 500ms
  /// 6. Notify callback with extracted data
  Future<Map<String, dynamic>?> processDocument(File documentFile) async {
    // Add document to list with pending status
    _selectedDocuments.add(documentFile);
    _documentStatuses[documentFile] = ExtractionStatus.pending;
    _notifyEvent(FileProcessingEvent.fileAdded, documentFile);
    notifyListeners();

    // Start extraction
    _documentStatuses[documentFile] = ExtractionStatus.extracting;
    _notifyEvent(FileProcessingEvent.statusChanged, documentFile);
    notifyListeners();

    try {
      // Read PDF bytes
      final bytes = await documentFile.readAsBytes();

      // Extract text from PDF
      final extractedText = await _extractTextFromPdf(bytes);

      if (extractedText.trim().isEmpty) {
        throw Exception('No text found in PDF. The PDF might be scanned or image-based.');
      }

      // Send extracted text to extraction API
      final structuredData = await _extractionService.extractStructuredData(
        input: extractedText,
      );

      // Mark as completed
      _documentStatuses[documentFile] = ExtractionStatus.completed;
      _notifyEvent(FileProcessingEvent.statusChanged, documentFile);
      _notifyEvent(FileProcessingEvent.extractionCompleted, documentFile, structuredData);
      notifyListeners();

      // Auto-remove after delay
      await Future.delayed(const Duration(milliseconds: 500));
      removeDocument(documentFile);

      return structuredData;
    } catch (e) {
      print('[FileProcessingManager] Error extracting from document: $e');
      _documentStatuses[documentFile] = ExtractionStatus.failed;
      _documentErrors[documentFile] = e.toString();
      _notifyEvent(FileProcessingEvent.statusChanged, documentFile);
      _notifyEvent(FileProcessingEvent.extractionFailed, documentFile);
      notifyListeners();
      rethrow;
    }
  }

  /// Extract text from PDF bytes using Syncfusion PDF library
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

  /// Remove an image from tracking
  void removeImage(File imageFile) {
    _selectedImages.remove(imageFile);
    _imageStatuses.remove(imageFile);
    _imageErrors.remove(imageFile);
    _notifyEvent(FileProcessingEvent.fileRemoved, imageFile);
    notifyListeners();
  }

  /// Remove a document from tracking
  void removeDocument(File documentFile) {
    _selectedDocuments.remove(documentFile);
    _documentStatuses.remove(documentFile);
    _documentErrors.remove(documentFile);
    _notifyEvent(FileProcessingEvent.fileRemoved, documentFile);
    notifyListeners();
  }

  /// Clear all files
  void clearAll() {
    _selectedImages.clear();
    _imageStatuses.clear();
    _imageErrors.clear();
    _selectedDocuments.clear();
    _documentStatuses.clear();
    _documentErrors.clear();
    notifyListeners();
  }

  /// Get status for an image file
  ExtractionStatus? getImageStatus(File file) => _imageStatuses[file];

  /// Get error for an image file
  String? getImageError(File file) => _imageErrors[file];

  /// Get status for a document file
  ExtractionStatus? getDocumentStatus(File file) => _documentStatuses[file];

  /// Get error for a document file
  String? getDocumentError(File file) => _documentErrors[file];

  /// Notify event callback
  void _notifyEvent(
    FileProcessingEvent event,
    File file, [
    Map<String, dynamic>? extractedData,
  ]) {
    _onEvent?.call(event, file, extractedData);
  }

  @override
  void dispose() {
    clearAll();
    _onEvent = null;
    super.dispose();
  }
}
