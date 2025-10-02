import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:nexa/core/domain/usecase.dart';
import 'package:nexa/core/errors/failures.dart';
import 'package:nexa/features/extraction/domain/entities/extracted_data.dart';
import 'package:nexa/features/extraction/domain/repositories/extraction_repository.dart';

/// Use case for extracting data from a PDF file.
class ExtractFromPdf implements UseCase<ExtractedData, ExtractFromPdfParams> {
  /// Creates an [ExtractFromPdf] use case.
  const ExtractFromPdf(this.repository);

  /// The extraction repository
  final ExtractionRepository repository;

  @override
  Future<Either<Failure, ExtractedData>> call(
    ExtractFromPdfParams params,
  ) async {
    // Validate parameters
    if (params.pdfPath.trim().isEmpty) {
      return const Left(
        ValidationFailure('PDF path cannot be empty'),
      );
    }
    if (params.apiKey.trim().isEmpty) {
      return const Left(
        ValidationFailure('API key cannot be empty'),
      );
    }

    return repository.extractFromPdf(params.pdfPath, params.apiKey);
  }
}

/// Parameters for the [ExtractFromPdf] use case.
class ExtractFromPdfParams extends Equatable {
  /// Creates [ExtractFromPdfParams].
  const ExtractFromPdfParams({
    required this.pdfPath,
    required this.apiKey,
  });

  /// Path to the PDF file
  final String pdfPath;

  /// API key for the extraction service
  final String apiKey;

  @override
  List<Object?> get props => [pdfPath, apiKey];
}
