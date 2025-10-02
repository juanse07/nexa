import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:nexa/core/domain/usecase.dart';
import 'package:nexa/core/errors/failures.dart';
import 'package:nexa/features/drafts/domain/repositories/draft_repository.dart';

/// Use case for deleting a draft from local storage.
class DeleteDraft implements UseCase<void, DeleteDraftParams> {
  /// Creates a [DeleteDraft] use case.
  const DeleteDraft(this.repository);

  /// The draft repository
  final DraftRepository repository;

  @override
  Future<Either<Failure, void>> call(DeleteDraftParams params) async {
    if (params.id.isEmpty) {
      return const Left(
        ValidationFailure('Draft ID cannot be empty'),
      );
    }
    return repository.deleteDraft(params.id);
  }
}

/// Parameters for the [DeleteDraft] use case.
class DeleteDraftParams extends Equatable {
  /// Creates [DeleteDraftParams].
  const DeleteDraftParams({required this.id});

  /// The unique identifier of the draft to delete
  final String id;

  @override
  List<Object?> get props => [id];
}
