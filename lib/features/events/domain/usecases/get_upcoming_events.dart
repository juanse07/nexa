import 'package:dartz/dartz.dart';
import 'package:nexa/core/domain/usecase.dart';
import 'package:nexa/core/errors/failures.dart';
import 'package:nexa/features/events/domain/entities/event.dart';
import 'package:nexa/features/events/domain/repositories/event_repository.dart';

/// Use case for retrieving upcoming events.
///
/// This use case fetches all events that are scheduled in the future,
/// typically sorted by start date.
class GetUpcomingEvents implements UseCase<List<Event>, NoParams> {
  /// Creates a [GetUpcomingEvents] use case.
  const GetUpcomingEvents(this.repository);

  /// The event repository
  final EventRepository repository;

  @override
  Future<Either<Failure, List<Event>>> call(NoParams params) async {
    return repository.getUpcomingEvents();
  }
}
