import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:nexa/core/domain/usecase.dart';
import 'package:nexa/core/errors/failures.dart';
import 'package:nexa/features/events/domain/entities/event.dart';
import 'package:nexa/features/events/domain/repositories/event_repository.dart';

/// Use case for retrieving a single event by its ID.
///
/// This use case fetches a specific event from the repository using
/// its unique identifier.
class GetEventById implements UseCase<Event, GetEventByIdParams> {
  /// Creates a [GetEventById] use case.
  const GetEventById(this.repository);

  /// The event repository
  final EventRepository repository;

  @override
  Future<Either<Failure, Event>> call(GetEventByIdParams params) async {
    if (params.id.isEmpty) {
      return const Left(
        ValidationFailure('Event ID cannot be empty'),
      );
    }
    return repository.getEventById(params.id);
  }
}

/// Parameters for the [GetEventById] use case.
class GetEventByIdParams extends Equatable {
  /// Creates [GetEventByIdParams].
  const GetEventByIdParams({required this.id});

  /// The unique identifier of the event
  final String id;

  @override
  List<Object?> get props => [id];
}
