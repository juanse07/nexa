/// Enumeration of possible event statuses in the application.
///
/// The event lifecycle typically flows:
/// draft -> pending -> confirmed -> completed (or cancelled)
enum EventStatus {
  /// Event is being drafted and not yet published
  draft,

  /// Event is published and awaiting confirmation
  pending,

  /// Event is confirmed and scheduled
  confirmed,

  /// Event has been completed
  completed,

  /// Event has been cancelled
  cancelled,

  /// Event is currently in progress
  inProgress;

  /// Returns a human-readable display name for the status.
  String get displayName {
    switch (this) {
      case EventStatus.draft:
        return 'Draft';
      case EventStatus.pending:
        return 'Pending';
      case EventStatus.confirmed:
        return 'Confirmed';
      case EventStatus.completed:
        return 'Completed';
      case EventStatus.cancelled:
        return 'Cancelled';
      case EventStatus.inProgress:
        return 'In Progress';
    }
  }

  /// Returns true if the event can still be edited.
  bool get isEditable =>
      this == EventStatus.draft ||
      this == EventStatus.pending ||
      this == EventStatus.confirmed;

  /// Returns true if the event is active (not completed or cancelled).
  bool get isActive =>
      this != EventStatus.completed && this != EventStatus.cancelled;

  /// Returns true if the event is finalized (completed or cancelled).
  bool get isFinalized =>
      this == EventStatus.completed || this == EventStatus.cancelled;
}
