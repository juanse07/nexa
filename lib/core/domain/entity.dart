/// Base interface for all domain entities.
///
/// Domain entities represent the core business objects of the application.
/// They should be immutable and contain only business logic, no presentation
/// or data access logic.
///
/// All entities should:
/// - Be immutable (use Freezed for implementation)
/// - Extend Equatable or use Freezed for value equality
/// - Contain only domain-relevant properties
/// - Not depend on any external frameworks except Dart core
///
/// Example:
/// ```dart
/// @freezed
/// class Event with _$Event implements Entity {
///   const factory Event({
///     required String id,
///     required String title,
///     required DateTime startDate,
///   }) = _Event;
/// }
/// ```
abstract class Entity {
  /// Creates an [Entity].
  const Entity();
}
