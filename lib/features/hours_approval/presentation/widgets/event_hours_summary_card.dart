import 'package:flutter/material.dart';
import 'package:nexa/l10n/app_localizations.dart';
import 'package:nexa/shared/presentation/theme/app_colors.dart';

class EventHoursSummaryCard extends StatelessWidget {
  final Map<String, dynamic> event;
  final int totalStaff;
  final int clockedOutCount;
  final double totalEstimatedHours;

  const EventHoursSummaryCard({
    super.key,
    required this.event,
    required this.totalStaff,
    required this.clockedOutCount,
    required this.totalEstimatedHours,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final eventName = event['event_name']?.toString() ?? l10n.shift;
    final clientName = event['client_name']?.toString() ?? '';
    final venueName = event['venue_name']?.toString() ?? '';
    final dateStr = (event['date']?.toString() ?? '').split('T').first;
    final startTime = event['start_time']?.toString() ?? '';
    final endTime = event['end_time']?.toString() ?? '';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    eventName,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (dateStr.isNotEmpty)
                  Text(
                    dateStr,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
              ],
            ),
            if (startTime.isNotEmpty || endTime.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                [startTime, endTime].where((s) => s.isNotEmpty).join(' - '),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
            ],
            if (clientName.isNotEmpty || venueName.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  if (clientName.isNotEmpty) ...[
                    Icon(Icons.business, size: 14, color: AppColors.textMuted),
                    const SizedBox(width: 4),
                    Text(clientName, style: theme.textTheme.bodySmall),
                  ],
                  if (clientName.isNotEmpty && venueName.isNotEmpty)
                    const SizedBox(width: 12),
                  if (venueName.isNotEmpty) ...[
                    Icon(Icons.location_on, size: 14, color: AppColors.textMuted),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        venueName,
                        style: theme.textTheme.bodySmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            ],
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStat(
                  context,
                  icon: Icons.people,
                  label: l10n.staffCount(totalStaff),
                  color: AppColors.info,
                ),
                _buildStat(
                  context,
                  icon: Icons.check_circle_outline,
                  label: l10n.clockedOutCount(clockedOutCount),
                  color: AppColors.success,
                ),
                _buildStat(
                  context,
                  icon: Icons.schedule,
                  label: l10n.estHours(totalEstimatedHours.toStringAsFixed(1)),
                  color: AppColors.warning,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStat(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}
