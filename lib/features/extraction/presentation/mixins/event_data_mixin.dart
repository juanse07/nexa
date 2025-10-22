import 'package:flutter/material.dart';
import '../../services/draft_service.dart';
import '../../services/pending_events_service.dart';

/// Mixin providing shared event data management functionality
/// for extraction screen tabs
mixin EventDataMixin<T extends StatefulWidget> on State<T> {
  final DraftService _draftService = DraftService();
  final PendingEventsService _pendingService = PendingEventsService();

  /// Save event data to pending drafts
  Future<String> saveToPending(Map<String, dynamic> eventData) async {
    final id = await _pendingService.saveDraft(eventData);
    return id;
  }

  /// Clear the current draft
  Future<void> clearDraft() async {
    await _draftService.clearDraft();
  }

  /// Save data as a draft
  Future<void> saveDraft(Map<String, dynamic> eventData) async {
    try {
      await _draftService.saveDraft(eventData);
    } catch (_) {
      // Silently fail - draft saving is not critical
    }
  }

  /// Show success message with consistent styling
  void showSuccessSnackBar(String message, {Color? backgroundColor}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor ?? const Color(0xFF059669),
      ),
    );
  }

  /// Show error message with consistent styling
  void showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFEF4444),
      ),
    );
  }

  /// Save event data to pending and show success message
  Future<void> saveToPendingWithFeedback(
    Map<String, dynamic> eventData, {
    String? customMessage,
  }) async {
    try {
      await saveToPending(eventData);
      if (!mounted) return;
      showSuccessSnackBar(customMessage ?? 'Saved to Pending');
      await clearDraft();
    } catch (e) {
      if (!mounted) return;
      showErrorSnackBar('Failed to save: ${e.toString()}');
    }
  }
}
