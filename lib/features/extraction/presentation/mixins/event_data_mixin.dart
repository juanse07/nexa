import 'package:flutter/material.dart';
import '../../services/draft_service.dart';
import '../../services/event_service.dart';
import 'package:nexa/shared/presentation/theme/app_colors.dart';

/// Mixin providing shared event data management functionality
/// for extraction screen tabs
mixin EventDataMixin<T extends StatefulWidget> on State<T> {
  final DraftService _draftService = DraftService();
  final EventService _eventService = EventService();

  /// Save event data to database as draft (pending events)
  /// Returns the created event ID
  Future<String> saveToPending(Map<String, dynamic> eventData) async {
    // Save to database with status='draft' (new architecture)
    final draftPayload = {
      ...eventData,
      'status': 'draft', // Mark as draft so it appears in Pending tab
    };

    final createdEvent = await _eventService.createEvent(draftPayload);
    final id = (createdEvent['_id'] ?? createdEvent['id'] ?? '').toString();

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
        backgroundColor: backgroundColor ?? AppColors.success,
      ),
    );
  }

  /// Show error message with consistent styling
  void showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
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
