import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:nexa/core/domain/entity.dart';

part 'extraction_request.freezed.dart';

/// Represents a request to extract data from a source.
@freezed
class ExtractionRequest with _$ExtractionRequest implements Entity {
  /// Creates an [ExtractionRequest] instance.
  const factory ExtractionRequest({
    /// The source content (file path, base64 data, or text)
    required String source,

    /// The type of source (pdf, image, text)
    required ExtractionSourceType sourceType,

    /// Target schema or template for extraction
    String? targetSchema,

    /// List of specific fields to extract
    List<String>? fieldsToExtract,

    /// API key for the extraction service
    String? apiKey,

    /// Additional extraction options
    @Default({}) Map<String, dynamic> options,
  }) = _ExtractionRequest;

  const ExtractionRequest._();

  /// Returns true if the request has specific fields to extract.
  bool get hasSpecificFields =>
      fieldsToExtract != null && fieldsToExtract!.isNotEmpty;

  /// Returns true if the request has a target schema.
  bool get hasTargetSchema =>
      targetSchema != null && targetSchema!.isNotEmpty;
}

/// Enumeration of extraction source types.
enum ExtractionSourceType {
  /// PDF document
  pdf,

  /// Image file (PNG, JPG, etc.)
  image,

  /// Plain text
  text,

  /// URL to a document
  url;

  /// Returns a human-readable display name for the source type.
  String get displayName {
    switch (this) {
      case ExtractionSourceType.pdf:
        return 'PDF';
      case ExtractionSourceType.image:
        return 'Image';
      case ExtractionSourceType.text:
        return 'Text';
      case ExtractionSourceType.url:
        return 'URL';
    }
  }
}
