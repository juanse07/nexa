import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:nexa/core/domain/usecase.dart';
import 'package:nexa/core/errors/failures.dart';
import 'package:nexa/features/extraction/domain/entities/extracted_data.dart';
import 'package:nexa/features/extraction/domain/repositories/extraction_repository.dart';

/// Use case for extracting data from an image file.
class ExtractFromImage
    implements UseCase<ExtractedData, ExtractFromImageParams> {
  /// Creates an [ExtractFromImage] use case.
  const ExtractFromImage(this.repository);

  /// The extraction repository
  final ExtractionRepository repository;

  @override
  Future<Either<Failure, ExtractedData>> call(
    ExtractFromImageParams params,
  ) async {
    // Validate parameters
    if (params.imagePath.trim().isEmpty) {
      return const Left(
        ValidationFailure('Image path cannot be empty'),
      );
    }
    if (params.apiKey.trim().isEmpty) {
      return const Left(
        ValidationFailure('API key cannot be empty'),
      );
    }

    return repository.extractFromImage(params.imagePath, params.apiKey);
  }
}

/// Parameters for the [ExtractFromImage] use case.
class ExtractFromImageParams extends Equatable {
  /// Creates [ExtractFromImageParams].
  const ExtractFromImageParams({
    required this.imagePath,
    required this.apiKey,
  });

  /// Path to the image file
  final String imagePath;

  /// API key for the extraction service
  final String apiKey;

  @override
  List<Object?> get props => [imagePath, apiKey];
}
