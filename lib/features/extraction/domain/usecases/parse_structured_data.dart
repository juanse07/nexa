import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:nexa/core/domain/usecase.dart';
import 'package:nexa/core/errors/failures.dart';
import 'package:nexa/features/extraction/domain/repositories/extraction_repository.dart';

/// Use case for parsing structured data from raw extracted content.
class ParseStructuredData
    implements UseCase<Map<String, dynamic>, ParseStructuredDataParams> {
  /// Creates a [ParseStructuredData] use case.
  const ParseStructuredData(this.repository);

  /// The extraction repository
  final ExtractionRepository repository;

  @override
  Future<Either<Failure, Map<String, dynamic>>> call(
    ParseStructuredDataParams params,
  ) async {
    if (params.rawData.isEmpty) {
      return const Left(
        ValidationFailure('Raw data cannot be empty'),
      );
    }

    return repository.parseStructuredData(
      params.rawData,
      schema: params.schema,
    );
  }
}

/// Parameters for the [ParseStructuredData] use case.
class ParseStructuredDataParams extends Equatable {
  /// Creates [ParseStructuredDataParams].
  const ParseStructuredDataParams({
    required this.rawData,
    this.schema,
  });

  /// The raw extracted data
  final Map<String, dynamic> rawData;

  /// Optional schema to validate against
  final String? schema;

  @override
  List<Object?> get props => [rawData, schema];
}
