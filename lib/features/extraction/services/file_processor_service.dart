import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:mime/mime.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import 'extraction_service.dart';

enum ProcessedFileType {
  pdf,
  image,
  unsupported,
}

class FileProcessResult {
  final String? extractedText;
  final Map<String, dynamic>? structuredData;
  final String? error;
  final bool success;

  const FileProcessResult({
    this.extractedText,
    this.structuredData,
    this.error,
    required this.success,
  });

  factory FileProcessResult.success({
    String? extractedText,
    required Map<String, dynamic> structuredData,
  }) {
    return FileProcessResult(
      extractedText: extractedText,
      structuredData: structuredData,
      error: null,
      success: true,
    );
  }

  factory FileProcessResult.error(String error) {
    return FileProcessResult(
      extractedText: null,
      structuredData: null,
      error: error,
      success: false,
    );
  }
}

/// Service responsible for processing uploaded files (PDFs and images)
/// and extracting structured event data using AI.
class FileProcessorService {
  final ExtractionService _extractionService;

  FileProcessorService({ExtractionService? extractionService})
      : _extractionService = extractionService ?? ExtractionService();

  /// Process a single PlatformFile and extract structured event data
  Future<FileProcessResult> processFile(PlatformFile platformFile) async {
    try {
      final bytes = await _resolvePlatformFileBytes(platformFile);
      final fileType = _detectFileType(bytes, platformFile.name);

      if (fileType == ProcessedFileType.unsupported) {
        final headerBytes = bytes.length > 20 ? bytes.sublist(0, 20) : bytes;
        final lookupName = kIsWeb
            ? platformFile.name
            : (platformFile.path ?? platformFile.name);
        final mimeType =
            lookupMimeType(lookupName, headerBytes: headerBytes) ?? 'unknown';
        return FileProcessResult.error('Unsupported file type: $mimeType');
      }

      final String extractedInput = await _extractContentFromFile(
        bytes: bytes,
        fileType: fileType,
      );

      // Send to AI extraction service
      final response = await _extractionService.extractStructuredData(
        input: extractedInput,
      );

      // Exclude client fields from AI output (user must pick from DB)
      final sanitized = Map<String, dynamic>.from(response);
      sanitized.remove('client_name');
      sanitized.remove('client_company_name');
      sanitized.remove('third_party_company_name');

      // Provide truncated text preview for display
      final displayText = extractedInput.length > 2000
          ? '${extractedInput.substring(0, 2000)}... [truncated]'
          : extractedInput;

      return FileProcessResult.success(
        extractedText: displayText,
        structuredData: sanitized,
      );
    } catch (e) {
      return FileProcessResult.error(e.toString());
    }
  }

  /// Process a file from bulk upload item (stored as Map)
  Future<FileProcessResult> processBulkItem(
    Map<String, dynamic> item,
  ) async {
    try {
      final bytes = await _readBytesFromBulkItem(item);
      final name = (item['name']?.toString() ?? '');
      final fileType = _detectFileType(bytes, name);

      if (fileType == ProcessedFileType.unsupported) {
        final headerBytes = bytes.length > 20 ? bytes.sublist(0, 20) : bytes;
        final rawPath = (item['path']?.toString() ?? '');
        final lookupName = rawPath.isNotEmpty ? rawPath : name;
        final mimeType =
            lookupMimeType(lookupName, headerBytes: headerBytes) ?? 'unknown';
        return FileProcessResult.error('Unsupported type: $mimeType');
      }

      final String extractedInput = await _extractContentFromFile(
        bytes: bytes,
        fileType: fileType,
      );

      final response = await _extractionService.extractStructuredData(
        input: extractedInput,
      );

      return FileProcessResult.success(
        structuredData: response,
      );
    } catch (e) {
      return FileProcessResult.error(e.toString());
    }
  }

  /// Resolve file bytes from a PlatformFile
  Future<Uint8List> _resolvePlatformFileBytes(PlatformFile file) async {
    if (file.bytes != null) {
      return file.bytes!;
    }
    if (!kIsWeb && file.path != null) {
      final ioFile = File(file.path!);
      return ioFile.readAsBytes();
    }
    throw Exception('Unable to read bytes for ${file.name}');
  }

  /// Read bytes from a bulk upload item
  Future<Uint8List> _readBytesFromBulkItem(Map<String, dynamic> item) async {
    final dynamic rawBytes = item['bytes'];
    if (rawBytes is Uint8List) {
      return rawBytes;
    }
    final dynamic path = item['path'];
    if (!kIsWeb && path is String && path.isNotEmpty) {
      final ioFile = File(path);
      return ioFile.readAsBytes();
    }
    throw Exception('Unable to read bytes for ${item['name'] ?? 'file'}');
  }

  /// Detect file type from bytes and filename
  ProcessedFileType _detectFileType(Uint8List bytes, String fileName) {
    final headerBytes = bytes.length > 20 ? bytes.sublist(0, 20) : bytes;
    final lowerName = fileName.toLowerCase();
    final mimeType = lookupMimeType(fileName, headerBytes: headerBytes) ?? '';

    if (mimeType.contains('pdf') || lowerName.endsWith('.pdf')) {
      return ProcessedFileType.pdf;
    } else if (mimeType.startsWith('image/') ||
        lowerName.endsWith('.png') ||
        lowerName.endsWith('.jpg') ||
        lowerName.endsWith('.jpeg') ||
        lowerName.endsWith('.heic')) {
      return ProcessedFileType.image;
    }

    return ProcessedFileType.unsupported;
  }

  /// Extract content from file based on type
  Future<String> _extractContentFromFile({
    required Uint8List bytes,
    required ProcessedFileType fileType,
  }) async {
    switch (fileType) {
      case ProcessedFileType.pdf:
        return await _extractTextFromPdfBytes(bytes);
      case ProcessedFileType.image:
        return '[[IMAGE_BASE64]]:${base64Encode(bytes)}';
      case ProcessedFileType.unsupported:
        throw Exception('Cannot extract content from unsupported file type');
    }
  }

  /// Extract text from PDF bytes using Syncfusion PDF library
  Future<String> _extractTextFromPdfBytes(Uint8List bytes) async {
    final document = PdfDocument(inputBytes: bytes);
    final extractor = PdfTextExtractor(document);
    final buffer = StringBuffer();
    for (int i = 0; i < document.pages.count; i++) {
      buffer.writeln(extractor.extractText(startPageIndex: i, endPageIndex: i));
    }
    document.dispose();
    return buffer.toString();
  }

  /// Generate a unique ID for a PlatformFile for deduplication
  String resolvePlatformFileId(PlatformFile file) {
    if (!kIsWeb && file.path != null && file.path!.isNotEmpty) {
      return file.path!;
    }
    return '${file.name}_${file.size}';
  }
}
