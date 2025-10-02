import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:nexa/core/domain/entity.dart';

part 'draft.freezed.dart';

/// Represents a draft saved locally for offline editing.
///
/// Drafts allow users to save work in progress locally before
/// publishing to the server. They can be used for events, forms,
/// or any other data that needs local persistence.
@freezed
class Draft with _$Draft implements Entity {
  /// Creates a [Draft] instance.
  const factory Draft({
    /// Unique identifier for the draft
    required String id,

    /// Type of draft (e.g., "event", "client", "user")
    required String type,

    /// The draft data as a JSON object
    required Map<String, dynamic> data,

    /// Human-readable title for the draft
    String? title,

    /// Description or notes about the draft
    String? description,

    /// When the draft was created
    required DateTime createdAt,

    /// When the draft was last updated
    required DateTime updatedAt,

    /// Whether the draft has been synchronized with the server
    @Default(false) bool isSynced,

    /// Additional metadata
    @Default({}) Map<String, dynamic> metadata,
  }) = _Draft;

  const Draft._();

  /// Returns true if the draft has been modified recently (within 24 hours).
  bool get isRecentlyModified {
    final now = DateTime.now();
    final difference = now.difference(updatedAt);
    return difference.inHours < 24;
  }

  /// Returns the age of the draft in days.
  int get ageInDays {
    final now = DateTime.now();
    return now.difference(createdAt).inDays;
  }

  /// Returns true if the draft is stale (older than 30 days).
  bool get isStale => ageInDays > 30;

  /// Returns a display title for the draft.
  String get displayTitle {
    if (title != null && title!.isNotEmpty) {
      return title!;
    }
    // Try to extract a title from the data
    final dataTitle = data['title'] ?? data['name'];
    if (dataTitle != null && dataTitle.toString().isNotEmpty) {
      return dataTitle.toString();
    }
    return 'Untitled $type';
  }

  /// Returns true if the draft has any data.
  bool get hasData => data.isNotEmpty;

  /// Returns the number of hours since last update.
  int get hoursSinceUpdate {
    final now = DateTime.now();
    return now.difference(updatedAt).inHours;
  }
}
