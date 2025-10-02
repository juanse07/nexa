import 'package:dartz/dartz.dart';
import 'package:nexa/core/errors/failures.dart';
import 'package:nexa/features/extraction/domain/entities/extracted_data.dart';
import 'package:nexa/features/extraction/domain/entities/extraction_request.dart';

/// Repository interface for data extraction operations.
///
/// This abstract class defines the contract for AI/ML-based data extraction
/// from documents, images, and text using services like OpenAI.
abstract class ExtractionRepository {
  /// Extracts structured data from a source.
  ///
  /// Parameters:
  /// - [request]: The extraction request with source and options
  ///
  /// Returns the extracted data or a [Failure] if extraction fails.
  Future<Either<Failure, ExtractedData>> extractData(
    ExtractionRequest request,
  );

  /// Extracts data from a PDF file.
  ///
  /// Parameters:
  /// - [pdfPath]: Path to the PDF file
  /// - [apiKey]: API key for the extraction service
  ///
  /// Returns the extracted data or a [Failure] if extraction fails.
  Future<Either<Failure, ExtractedData>> extractFromPdf(
    String pdfPath,
    String apiKey,
  );

  /// Extracts data from an image.
  ///
  /// Parameters:
  /// - [imagePath]: Path to the image file
  /// - [apiKey]: API key for the extraction service
  ///
  /// Returns the extracted data or a [Failure] if extraction fails.
  Future<Either<Failure, ExtractedData>> extractFromImage(
    String imagePath,
    String apiKey,
  );

  /// Extracts data from text.
  ///
  /// Parameters:
  /// - [text]: The text content to extract from
  /// - [apiKey]: API key for the extraction service
  ///
  /// Returns the extracted data or a [Failure] if extraction fails.
  Future<Either<Failure, ExtractedData>> extractFromText(
    String text,
    String apiKey,
  );

  /// Parses structured data from raw extracted content.
  ///
  /// Parameters:
  /// - [rawData]: The raw extracted data
  /// - [schema]: Optional schema to validate against
  ///
  /// Returns the parsed structured data or a [Failure] if parsing fails.
  Future<Either<Failure, Map<String, dynamic>>> parseStructuredData(
    Map<String, dynamic> rawData, {
    String? schema,
  });

  /// Validates extracted data against a schema.
  ///
  /// Parameters:
  /// - [data]: The extracted data to validate
  /// - [schema]: The schema to validate against
  ///
  /// Returns validation results or a [Failure] if validation fails.
  Future<Either<Failure, ValidationResult>> validateExtractedData(
    ExtractedData data,
    String schema,
  );
}

/// Represents the result of validation.
class ValidationResult {
  /// Creates a [ValidationResult].
  const ValidationResult({
    required this.isValid,
    this.errors = const [],
    this.warnings = const [],
  });

  /// Whether the validation passed
  final bool isValid;

  /// List of validation errors
  final List<String> errors;

  /// List of validation warnings
  final List<String> warnings;

  /// Returns true if there are no errors or warnings.
  bool get isPerfect => isValid && errors.isEmpty && warnings.isEmpty;

  /// Returns true if there are warnings but no errors.
  bool get hasWarnings => isValid && warnings.isNotEmpty;
}
