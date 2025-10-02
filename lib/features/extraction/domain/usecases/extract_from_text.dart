import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:nexa/core/domain/usecase.dart';
import 'package:nexa/core/errors/failures.dart';
import 'package:nexa/features/extraction/domain/entities/extracted_data.dart';
import 'package:nexa/features/extraction/domain/repositories/extraction_repository.dart';

/// Use case for extracting data from text.
class ExtractFromText
    implements UseCase<ExtractedData, ExtractFromTextParams> {
  /// Creates an [ExtractFromText] use case.
  const ExtractFromText(this.repository);

  /// The extraction repository
  final ExtractionRepository repository;

  @override
  Future<Either<Failure, ExtractedData>> call(
    ExtractFromTextParams params,
  ) async {
    // Validate parameters
    if (params.text.trim().isEmpty) {
      return const Left(
        ValidationFailure('Text cannot be empty'),
      );
    }
    if (params.apiKey.trim().isEmpty) {
      return const Left(
        ValidationFailure('API key cannot be empty'),
      );
    }

    return repository.extractFromText(params.text, params.apiKey);
  }
}

/// Parameters for the [ExtractFromText] use case.
class ExtractFromTextParams extends Equatable {
  /// Creates [ExtractFromTextParams].
  const ExtractFromTextParams({
    required this.text,
    required this.apiKey,
  });

  /// The text content to extract from
  final String text;

  /// API key for the extraction service
  final String apiKey;

  @override
  List<Object?> get props => [text, apiKey];
}
