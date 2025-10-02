import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:nexa/core/domain/usecase.dart';
import 'package:nexa/core/errors/failures.dart';
import 'package:nexa/features/events/domain/entities/event.dart';
import 'package:nexa/features/events/domain/repositories/event_repository.dart';

/// Use case for updating an existing event.
///
/// This use case validates and updates an event in the repository.
/// It performs business logic validation before delegating to the repository.
class UpdateEvent implements UseCase<Event, UpdateEventParams> {
  /// Creates an [UpdateEvent] use case.
  const UpdateEvent(this.repository);

  /// The event repository
  final EventRepository repository;

  @override
  Future<Either<Failure, Event>> call(UpdateEventParams params) async {
    // Validate event ID
    if (params.id.isEmpty) {
      return const Left(
        ValidationFailure('Event ID cannot be empty'),
      );
    }

    // Validate event data
    final validationFailure = _validateEvent(params.event);
    if (validationFailure != null) {
      return Left(validationFailure);
    }

    return repository.updateEvent(params.id, params.event);
  }

  /// Validates the event data before update.
  ValidationFailure? _validateEvent(Event event) {
    final errors = <String, List<String>>{};

    if (event.title.trim().isEmpty) {
      errors['title'] = ['Event title is required'];
    }

    if (event.clientId.trim().isEmpty) {
      errors['clientId'] = ['Client is required'];
    }

    if (event.endDate.isBefore(event.startDate)) {
      errors['endDate'] = ['End date must be after start date'];
    }

    if (errors.isNotEmpty) {
      return ValidationFailure('Invalid event data', errors);
    }

    return null;
  }
}

/// Parameters for the [UpdateEvent] use case.
class UpdateEventParams extends Equatable {
  /// Creates [UpdateEventParams].
  const UpdateEventParams({
    required this.id,
    required this.event,
  });

  /// The unique identifier of the event to update
  final String id;

  /// The updated event data
  final Event event;

  @override
  List<Object?> get props => [id, event];
}
