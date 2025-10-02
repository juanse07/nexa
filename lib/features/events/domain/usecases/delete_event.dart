import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:nexa/core/domain/usecase.dart';
import 'package:nexa/core/errors/failures.dart';
import 'package:nexa/features/events/domain/repositories/event_repository.dart';

/// Use case for deleting an event.
///
/// This use case removes an event from the repository by its ID.
class DeleteEvent implements UseCase<void, DeleteEventParams> {
  /// Creates a [DeleteEvent] use case.
  const DeleteEvent(this.repository);

  /// The event repository
  final EventRepository repository;

  @override
  Future<Either<Failure, void>> call(DeleteEventParams params) async {
    if (params.id.isEmpty) {
      return const Left(
        ValidationFailure('Event ID cannot be empty'),
      );
    }
    return repository.deleteEvent(params.id);
  }
}

/// Parameters for the [DeleteEvent] use case.
class DeleteEventParams extends Equatable {
  /// Creates [DeleteEventParams].
  const DeleteEventParams({required this.id});

  /// The unique identifier of the event to delete
  final String id;

  @override
  List<Object?> get props => [id];
}
