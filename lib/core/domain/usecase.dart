import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:nexa/core/errors/failures.dart';

/// Base class for all use cases in the application.
///
/// Use cases represent business logic operations and should be the only
/// way to interact with repositories from the presentation layer.
///
/// Type parameters:
/// - [Type]: The return type of the use case
/// - [Params]: The parameters required by the use case
///
/// Example:
/// ```dart
/// class GetEventById extends UseCase<Event, GetEventByIdParams> {
///   final EventRepository repository;
///
///   GetEventById(this.repository);
///
///   @override
///   Future<Either<Failure, Event>> call(GetEventByIdParams params) {
///     return repository.getEventById(params.id);
///   }
/// }
/// ```
abstract class UseCase<Type, Params> {
  /// Executes the use case with the given [params].
  ///
  /// Returns an [Either] with a [Failure] on the left if the operation fails,
  /// or the expected [Type] on the right if it succeeds.
  Future<Either<Failure, Type>> call(Params params);
}

/// Placeholder class for use cases that don't require any parameters.
///
/// Example:
/// ```dart
/// class GetCurrentUser extends UseCase<User, NoParams> {
///   @override
///   Future<Either<Failure, User>> call(NoParams params) {
///     return repository.getCurrentUser();
///   }
/// }
/// ```
class NoParams extends Equatable {
  /// Creates a [NoParams] instance.
  const NoParams();

  @override
  List<Object?> get props => [];
}
