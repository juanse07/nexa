/// Enumeration of possible event statuses in the application.
///
/// The event lifecycle typically flows:
/// draft -> published -> confirmed -> fulfilled -> inProgress -> completed (or cancelled)
enum EventStatus {
  /// Event is being drafted and not yet published
  draft,

  /// Event is published and visible to staff
  published,

  /// Event is confirmed and scheduled
  confirmed,

  /// Event is fulfilled (all positions filled)
  fulfilled,

  /// Event is currently in progress
  inProgress,

  /// Event has been completed
  completed,

  /// Event has been cancelled
  cancelled;

  /// Returns a human-readable display name for the status.
  String get displayName {
    switch (this) {
      case EventStatus.draft:
        return 'Draft';
      case EventStatus.published:
        return 'Published';
      case EventStatus.confirmed:
        return 'Confirmed';
      case EventStatus.fulfilled:
        return 'Fulfilled';
      case EventStatus.inProgress:
        return 'In Progress';
      case EventStatus.completed:
        return 'Completed';
      case EventStatus.cancelled:
        return 'Cancelled';
    }
  }

  /// Returns true if the event can still be edited.
  bool get isEditable =>
      this == EventStatus.draft ||
      this == EventStatus.published ||
      this == EventStatus.confirmed ||
      this == EventStatus.fulfilled;

  /// Returns true if the event is active (not completed or cancelled).
  bool get isActive =>
      this != EventStatus.completed && this != EventStatus.cancelled;

  /// Returns true if the event is finalized (completed or cancelled).
  bool get isFinalized =>
      this == EventStatus.completed || this == EventStatus.cancelled;
}
