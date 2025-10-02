import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:nexa/core/domain/usecase.dart';
import 'package:nexa/core/errors/failures.dart';
import 'package:nexa/features/extraction/domain/entities/extracted_data.dart';
import 'package:nexa/features/extraction/domain/entities/extraction_request.dart';
import 'package:nexa/features/extraction/domain/repositories/extraction_repository.dart';

/// Use case for extracting structured data from a source.
class ExtractData implements UseCase<ExtractedData, ExtractDataParams> {
  /// Creates an [ExtractData] use case.
  const ExtractData(this.repository);

  /// The extraction repository
  final ExtractionRepository repository;

  @override
  Future<Either<Failure, ExtractedData>> call(
    ExtractDataParams params,
  ) async {
    // Validate request
    final validationFailure = _validateRequest(params.request);
    if (validationFailure != null) {
      return Left(validationFailure);
    }

    return repository.extractData(params.request);
  }

  /// Validates the extraction request.
  ValidationFailure? _validateRequest(ExtractionRequest request) {
    final errors = <String, List<String>>{};

    if (request.source.trim().isEmpty) {
      errors['source'] = ['Source cannot be empty'];
    }

    if (request.apiKey != null && request.apiKey!.trim().isEmpty) {
      errors['apiKey'] = ['API key cannot be empty if provided'];
    }

    if (errors.isNotEmpty) {
      return ValidationFailure('Invalid extraction request', errors);
    }

    return null;
  }
}

/// Parameters for the [ExtractData] use case.
class ExtractDataParams extends Equatable {
  /// Creates [ExtractDataParams].
  const ExtractDataParams({required this.request});

  /// The extraction request
  final ExtractionRequest request;

  @override
  List<Object?> get props => [request];
}
