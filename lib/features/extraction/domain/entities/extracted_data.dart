import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:nexa/core/domain/entity.dart';

part 'extracted_data.freezed.dart';

/// Represents data extracted from a document or image.
///
/// This entity contains structured information extracted from PDFs,
/// images, or other documents using AI/ML extraction services.
@freezed
class ExtractedData with _$ExtractedData implements Entity {
  /// Creates an [ExtractedData] instance.
  const factory ExtractedData({
    /// Unique identifier for this extraction
    required String id,

    /// Source type (pdf, image, text)
    required String sourceType,

    /// Original source file name or identifier
    String? sourceName,

    /// Extracted structured data as JSON
    required Map<String, dynamic> data,

    /// Confidence score (0.0 to 1.0)
    double? confidenceScore,

    /// List of fields that were extracted
    @Default([]) List<String> extractedFields,

    /// List of fields that failed to extract
    @Default([]) List<String> failedFields,

    /// Extraction method or model used
    String? extractionMethod,

    /// When the extraction was performed
    required DateTime extractedAt,

    /// Processing time in milliseconds
    int? processingTimeMs,

    /// Any errors or warnings during extraction
    @Default([]) List<String> warnings,

    /// Whether the extraction was successful
    @Default(true) bool isSuccessful,

    /// Additional metadata about the extraction
    @Default({}) Map<String, dynamic> metadata,
  }) = _ExtractedData;

  const ExtractedData._();

  /// Returns true if the extraction has a high confidence score.
  bool get hasHighConfidence =>
      confidenceScore != null && confidenceScore! >= 0.8;

  /// Returns true if the extraction has a medium confidence score.
  bool get hasMediumConfidence =>
      confidenceScore != null &&
      confidenceScore! >= 0.5 &&
      confidenceScore! < 0.8;

  /// Returns true if the extraction has a low confidence score.
  bool get hasLowConfidence =>
      confidenceScore != null && confidenceScore! < 0.5;

  /// Returns the number of successfully extracted fields.
  int get successfulFieldCount => extractedFields.length;

  /// Returns the number of failed fields.
  int get failedFieldCount => failedFields.length;

  /// Returns the total number of fields attempted.
  int get totalFieldCount => successfulFieldCount + failedFieldCount;

  /// Returns the success rate as a percentage (0.0 to 1.0).
  double get successRate =>
      totalFieldCount > 0 ? successfulFieldCount / totalFieldCount : 0.0;

  /// Returns true if there are any warnings.
  bool get hasWarnings => warnings.isNotEmpty;

  /// Returns true if all fields were extracted successfully.
  bool get isComplete => failedFieldCount == 0 && successfulFieldCount > 0;

  /// Gets a specific field from the extracted data.
  T? getField<T>(String fieldName) {
    final value = data[fieldName];
    if (value is T) {
      return value;
    }
    return null;
  }

  /// Checks if a specific field was extracted.
  bool hasField(String fieldName) => extractedFields.contains(fieldName);
}
