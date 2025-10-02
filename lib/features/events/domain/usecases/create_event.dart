import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:nexa/core/domain/usecase.dart';
import 'package:nexa/core/errors/failures.dart';
import 'package:nexa/features/events/domain/entities/event.dart';
import 'package:nexa/features/events/domain/repositories/event_repository.dart';

/// Use case for creating a new event.
///
/// This use case validates and creates a new event in the repository.
/// It performs business logic validation before delegating to the repository.
class CreateEvent implements UseCase<Event, CreateEventParams> {
  /// Creates a [CreateEvent] use case.
  const CreateEvent(this.repository);

  /// The event repository
  final EventRepository repository;

  @override
  Future<Either<Failure, Event>> call(CreateEventParams params) async {
    // Validate event data
    final validationFailure = _validateEvent(params.event);
    if (validationFailure != null) {
      return Left(validationFailure);
    }

    return repository.createEvent(params.event);
  }

  /// Validates the event data before creation.
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

    if (event.startDate.isBefore(
      DateTime.now().subtract(const Duration(days: 1)),
    )) {
      errors['startDate'] = ['Event start date cannot be in the past'];
    }

    if (errors.isNotEmpty) {
      return ValidationFailure('Invalid event data', errors);
    }

    return null;
  }
}

/// Parameters for the [CreateEvent] use case.
class CreateEventParams extends Equatable {
  /// Creates [CreateEventParams].
  const CreateEventParams({required this.event});

  /// The event to create
  final Event event;

  @override
  List<Object?> get props => [event];
}
