import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:nexa/core/domain/usecase.dart';
import 'package:nexa/core/errors/failures.dart';
import 'package:nexa/features/drafts/domain/entities/draft.dart';
import 'package:nexa/features/drafts/domain/repositories/draft_repository.dart';

/// Use case for loading a draft from local storage.
class LoadDraft implements UseCase<Draft, LoadDraftParams> {
  /// Creates a [LoadDraft] use case.
  const LoadDraft(this.repository);

  /// The draft repository
  final DraftRepository repository;

  @override
  Future<Either<Failure, Draft>> call(LoadDraftParams params) async {
    if (params.id.isEmpty) {
      return const Left(
        ValidationFailure('Draft ID cannot be empty'),
      );
    }
    return repository.loadDraft(params.id);
  }
}

/// Parameters for the [LoadDraft] use case.
class LoadDraftParams extends Equatable {
  /// Creates [LoadDraftParams].
  const LoadDraftParams({required this.id});

  /// The unique identifier of the draft
  final String id;

  @override
  List<Object?> get props => [id];
}
