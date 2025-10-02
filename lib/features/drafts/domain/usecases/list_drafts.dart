import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:nexa/core/domain/usecase.dart';
import 'package:nexa/core/errors/failures.dart';
import 'package:nexa/features/drafts/domain/entities/draft.dart';
import 'package:nexa/features/drafts/domain/repositories/draft_repository.dart';

/// Use case for listing drafts, optionally filtered by type.
class ListDrafts implements UseCase<List<Draft>, ListDraftsParams> {
  /// Creates a [ListDrafts] use case.
  const ListDrafts(this.repository);

  /// The draft repository
  final DraftRepository repository;

  @override
  Future<Either<Failure, List<Draft>>> call(ListDraftsParams params) async {
    if (params.type != null && params.type!.isNotEmpty) {
      return repository.listDraftsByType(params.type!);
    }
    return repository.listAllDrafts();
  }
}

/// Parameters for the [ListDrafts] use case.
class ListDraftsParams extends Equatable {
  /// Creates [ListDraftsParams].
  const ListDraftsParams({this.type});

  /// Optional type to filter drafts by
  final String? type;

  @override
  List<Object?> get props => [type];
}
