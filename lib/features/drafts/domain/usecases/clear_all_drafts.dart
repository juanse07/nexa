import 'package:dartz/dartz.dart';
import 'package:nexa/core/domain/usecase.dart';
import 'package:nexa/core/errors/failures.dart';
import 'package:nexa/features/drafts/domain/repositories/draft_repository.dart';

/// Use case for clearing all drafts from local storage.
class ClearAllDrafts implements UseCase<void, NoParams> {
  /// Creates a [ClearAllDrafts] use case.
  const ClearAllDrafts(this.repository);

  /// The draft repository
  final DraftRepository repository;

  @override
  Future<Either<Failure, void>> call(NoParams params) async {
    return repository.clearAllDrafts();
  }
}
