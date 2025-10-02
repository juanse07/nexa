import 'package:dartz/dartz.dart';
import 'package:nexa/core/errors/failures.dart';
import 'package:nexa/features/events/domain/entities/event.dart';
import 'package:nexa/features/events/domain/entities/event_status.dart';

/// Repository interface for event data operations.
///
/// This abstract class defines the contract for event data access.
/// Implementations should handle data fetching from remote APIs,
/// local caching, and error handling.
///
/// All methods return [Either<Failure, T>] to handle errors gracefully
/// without throwing exceptions.
abstract class EventRepository {
  /// Retrieves all events from the data source.
  ///
  /// Parameters:
  /// - [userKey]: Optional user key for filtering events
  ///
  /// Returns a list of events or a [Failure] if the operation fails.
  Future<Either<Failure, List<Event>>> getEvents({String? userKey});

  /// Retrieves a single event by its ID.
  ///
  /// Parameters:
  /// - [id]: The unique identifier of the event
  ///
  /// Returns the event or a [NotFoundFailure] if not found.
  Future<Either<Failure, Event>> getEventById(String id);

  /// Creates a new event.
  ///
  /// Parameters:
  /// - [event]: The event entity to create
  ///
  /// Returns the created event with server-assigned ID and timestamps.
  Future<Either<Failure, Event>> createEvent(Event event);

  /// Updates an existing event.
  ///
  /// Parameters:
  /// - [id]: The unique identifier of the event to update
  /// - [event]: The updated event data
  ///
  /// Returns the updated event or a [NotFoundFailure] if not found.
  Future<Either<Failure, Event>> updateEvent(String id, Event event);

  /// Deletes an event by its ID.
  ///
  /// Parameters:
  /// - [id]: The unique identifier of the event to delete
  ///
  /// Returns void on success or a [Failure] on error.
  Future<Either<Failure, void>> deleteEvent(String id);

  /// Retrieves all upcoming events (events in the future).
  ///
  /// Returns a list of upcoming events sorted by start date.
  Future<Either<Failure, List<Event>>> getUpcomingEvents();

  /// Retrieves all past events (events that have ended).
  ///
  /// Returns a list of past events sorted by start date (most recent first).
  Future<Either<Failure, List<Event>>> getPastEvents();

  /// Retrieves events by status.
  ///
  /// Parameters:
  /// - [status]: The status to filter by
  ///
  /// Returns a list of events matching the given status.
  Future<Either<Failure, List<Event>>> getEventsByStatus(EventStatus status);

  /// Retrieves events for a specific client.
  ///
  /// Parameters:
  /// - [clientId]: The unique identifier of the client
  ///
  /// Returns a list of events for the specified client.
  Future<Either<Failure, List<Event>>> getEventsByClient(String clientId);

  /// Retrieves events within a specific date range.
  ///
  /// Parameters:
  /// - [startDate]: The start of the date range
  /// - [endDate]: The end of the date range
  ///
  /// Returns a list of events within the specified date range.
  Future<Either<Failure, List<Event>>> getEventsByDateRange(
    DateTime startDate,
    DateTime endDate,
  );

  /// Updates the status of an event.
  ///
  /// Parameters:
  /// - [id]: The unique identifier of the event
  /// - [status]: The new status
  ///
  /// Returns the updated event or a [Failure] on error.
  Future<Either<Failure, Event>> updateEventStatus(
    String id,
    EventStatus status,
  );

  /// Assigns staff to an event role.
  ///
  /// Parameters:
  /// - [eventId]: The unique identifier of the event
  /// - [roleId]: The role ID within the event
  /// - [userIds]: List of user IDs to assign
  ///
  /// Returns the updated event or a [Failure] on error.
  Future<Either<Failure, Event>> assignStaffToRole(
    String eventId,
    String roleId,
    List<String> userIds,
  );

  /// Removes staff from an event role.
  ///
  /// Parameters:
  /// - [eventId]: The unique identifier of the event
  /// - [roleId]: The role ID within the event
  /// - [userIds]: List of user IDs to remove
  ///
  /// Returns the updated event or a [Failure] on error.
  Future<Either<Failure, Event>> removeStaffFromRole(
    String eventId,
    String roleId,
    List<String> userIds,
  );
}
