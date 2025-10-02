import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:nexa/core/domain/usecase.dart';
import 'package:nexa/core/errors/failures.dart';
import 'package:nexa/features/events/domain/entities/event.dart';
import 'package:nexa/features/events/domain/entities/event_status.dart';
import 'package:nexa/features/events/domain/repositories/event_repository.dart';

/// Use case for retrieving events by their status.
///
/// This use case fetches all events that match a specific status
/// (e.g., confirmed, pending, completed).
class GetEventsByStatus implements UseCase<List<Event>, GetEventsByStatusParams> {
  /// Creates a [GetEventsByStatus] use case.
  const GetEventsByStatus(this.repository);

  /// The event repository
  final EventRepository repository;

  @override
  Future<Either<Failure, List<Event>>> call(
    GetEventsByStatusParams params,
  ) async {
    return repository.getEventsByStatus(params.status);
  }
}

/// Parameters for the [GetEventsByStatus] use case.
class GetEventsByStatusParams extends Equatable {
  /// Creates [GetEventsByStatusParams].
  const GetEventsByStatusParams({required this.status});

  /// The status to filter events by
  final EventStatus status;

  @override
  List<Object?> get props => [status];
}
