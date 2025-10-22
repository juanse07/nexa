import 'package:flutter/material.dart';
import 'package:nexa/l10n/app_localizations.dart';
import 'package:nexa/shared/ui/widgets.dart';

/// Reusable card for displaying extracted event data with optional date/time adjustment
class EventDataPreviewCard extends StatelessWidget {
  final Map<String, dynamic> eventData;
  final VoidCallback? onSaveToPending;
  final Widget? dateTimeAdjustmentWidget;
  final Widget Function(Map<String, dynamic>)? eventDetailsBuilder;
  final bool showSaveButton;

  const EventDataPreviewCard({
    super.key,
    required this.eventData,
    this.onSaveToPending,
    this.dateTimeAdjustmentWidget,
    this.eventDetailsBuilder,
    this.showSaveButton = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Event details card
        InfoCard(
          title: AppLocalizations.of(context)!.jobDetails,
          icon: Icons.event_note,
          child: eventDetailsBuilder != null
              ? eventDetailsBuilder!(eventData)
              : _buildDefaultEventDetails(context),
        ),
        if (dateTimeAdjustmentWidget != null) ...[
          const SizedBox(height: 12),
          dateTimeAdjustmentWidget!,
        ],
        if (showSaveButton && onSaveToPending != null) ...[
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: onSaveToPending,
              icon: const Icon(Icons.save, size: 18),
              label: Text(AppLocalizations.of(context)!.saveToPending),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDefaultEventDetails(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (eventData['event_name'] != null)
          DetailRow(
            label: AppLocalizations.of(context)!.job,
            value: eventData['event_name'].toString(),
            icon: Icons.celebration,
          ),
        if (eventData['client_name'] != null)
          DetailRow(
            label: AppLocalizations.of(context)!.client,
            value: eventData['client_name'].toString(),
            icon: Icons.person,
          ),
        if (eventData['date'] != null)
          DetailRow(
            label: AppLocalizations.of(context)!.date,
            value: eventData['date'].toString(),
            icon: Icons.calendar_today,
          ),
        if (eventData['start_time'] != null && eventData['end_time'] != null)
          DetailRow(
            label: AppLocalizations.of(context)!.time,
            value: '${eventData['start_time']} - ${eventData['end_time']}',
            icon: Icons.access_time,
          ),
        if (eventData['venue_name'] != null)
          DetailRow(
            label: AppLocalizations.of(context)!.location,
            value: eventData['venue_name'].toString(),
            icon: Icons.location_on,
          ),
        if (eventData['venue_address'] != null)
          DetailRow(
            label: AppLocalizations.of(context)!.address,
            value: eventData['venue_address'].toString(),
            icon: Icons.place,
          ),
        if (eventData['contact_phone'] != null)
          DetailRow(
            label: AppLocalizations.of(context)!.phone,
            value: eventData['contact_phone'].toString(),
            icon: Icons.phone,
          ),
        if (eventData['headcount_total'] != null)
          DetailRow(
            label: AppLocalizations.of(context)!.headcount,
            value: eventData['headcount_total'].toString(),
            icon: Icons.people,
          ),
      ],
    );
  }
}
