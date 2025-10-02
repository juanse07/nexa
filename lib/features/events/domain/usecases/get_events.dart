import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:nexa/core/domain/usecase.dart';
import 'package:nexa/core/errors/failures.dart';
import 'package:nexa/features/events/domain/entities/event.dart';
import 'package:nexa/features/events/domain/repositories/event_repository.dart';

/// Use case for retrieving all events.
///
/// This use case fetches all events from the repository, optionally
/// filtered by a user key for user-specific events.
class GetEvents implements UseCase<List<Event>, GetEventsParams> {
  /// Creates a [GetEvents] use case.
  const GetEvents(this.repository);

  /// The event repository
  final EventRepository repository;

  @override
  Future<Either<Failure, List<Event>>> call(GetEventsParams params) async {
    return repository.getEvents(userKey: params.userKey);
  }
}

/// Parameters for the [GetEvents] use case.
class GetEventsParams extends Equatable {
  /// Creates [GetEventsParams].
  const GetEventsParams({this.userKey});

  /// Optional user key for filtering events
  final String? userKey;

  @override
  List<Object?> get props => [userKey];
}
