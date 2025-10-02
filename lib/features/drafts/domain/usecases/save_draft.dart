import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:nexa/core/domain/usecase.dart';
import 'package:nexa/core/errors/failures.dart';
import 'package:nexa/features/drafts/domain/entities/draft.dart';
import 'package:nexa/features/drafts/domain/repositories/draft_repository.dart';

/// Use case for saving a draft to local storage.
class SaveDraft implements UseCase<Draft, SaveDraftParams> {
  /// Creates a [SaveDraft] use case.
  const SaveDraft(this.repository);

  /// The draft repository
  final DraftRepository repository;

  @override
  Future<Either<Failure, Draft>> call(SaveDraftParams params) async {
    // Validate draft data
    final validationFailure = _validateDraft(params.draft);
    if (validationFailure != null) {
      return Left(validationFailure);
    }

    return repository.saveDraft(params.draft);
  }

  /// Validates the draft data before saving.
  ValidationFailure? _validateDraft(Draft draft) {
    final errors = <String, List<String>>{};

    if (draft.id.trim().isEmpty) {
      errors['id'] = ['Draft ID is required'];
    }

    if (draft.type.trim().isEmpty) {
      errors['type'] = ['Draft type is required'];
    }

    if (draft.data.isEmpty) {
      errors['data'] = ['Draft data cannot be empty'];
    }

    if (errors.isNotEmpty) {
      return ValidationFailure('Invalid draft data', errors);
    }

    return null;
  }
}

/// Parameters for the [SaveDraft] use case.
class SaveDraftParams extends Equatable {
  /// Creates [SaveDraftParams].
  const SaveDraftParams({required this.draft});

  /// The draft to save
  final Draft draft;

  @override
  List<Object?> get props => [draft];
}
