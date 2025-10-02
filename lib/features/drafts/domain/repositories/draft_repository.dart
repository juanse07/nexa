import 'package:dartz/dartz.dart';
import 'package:nexa/core/errors/failures.dart';
import 'package:nexa/features/drafts/domain/entities/draft.dart';

/// Repository interface for draft data operations.
///
/// This abstract class defines the contract for draft data access.
/// Drafts are typically stored locally for offline editing capabilities.
abstract class DraftRepository {
  /// Saves a draft to local storage.
  ///
  /// Parameters:
  /// - [draft]: The draft to save
  ///
  /// Returns the saved draft or a [Failure] if the operation fails.
  Future<Either<Failure, Draft>> saveDraft(Draft draft);

  /// Loads a draft from local storage.
  ///
  /// Parameters:
  /// - [id]: The unique identifier of the draft
  ///
  /// Returns the draft or a [NotFoundFailure] if not found.
  Future<Either<Failure, Draft>> loadDraft(String id);

  /// Deletes a draft from local storage.
  ///
  /// Parameters:
  /// - [id]: The unique identifier of the draft to delete
  ///
  /// Returns void on success or a [Failure] on error.
  Future<Either<Failure, void>> deleteDraft(String id);

  /// Lists all drafts of a specific type.
  ///
  /// Parameters:
  /// - [type]: The type of drafts to list (e.g., "event", "client")
  ///
  /// Returns a list of drafts or a [Failure] if the operation fails.
  Future<Either<Failure, List<Draft>>> listDraftsByType(String type);

  /// Lists all drafts.
  ///
  /// Returns a list of all drafts or a [Failure] if the operation fails.
  Future<Either<Failure, List<Draft>>> listAllDrafts();

  /// Clears all drafts from local storage.
  ///
  /// Returns void on success or a [Failure] on error.
  Future<Either<Failure, void>> clearAllDrafts();

  /// Updates a draft in local storage.
  ///
  /// Parameters:
  /// - [id]: The unique identifier of the draft to update
  /// - [draft]: The updated draft data
  ///
  /// Returns the updated draft or a [NotFoundFailure] if not found.
  Future<Either<Failure, Draft>> updateDraft(String id, Draft draft);

  /// Checks if a draft exists.
  ///
  /// Parameters:
  /// - [id]: The unique identifier of the draft
  ///
  /// Returns true if the draft exists, false otherwise.
  Future<Either<Failure, bool>> draftExists(String id);

  /// Deletes stale drafts (older than a specified number of days).
  ///
  /// Parameters:
  /// - [olderThanDays]: Delete drafts older than this many days
  ///
  /// Returns the number of drafts deleted or a [Failure] on error.
  Future<Either<Failure, int>> deleteStaleDrafts({int olderThanDays = 30});
}
