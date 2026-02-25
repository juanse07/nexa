import 'package:flutter/material.dart';
import 'package:nexa/l10n/app_localizations.dart';
import 'package:nexa/features/hours_approval/presentation/hours_approval_detail_screen.dart';
import 'package:nexa/features/extraction/services/event_service.dart';
import 'package:nexa/shared/presentation/theme/app_colors.dart';

/// Hours Approval List Screen
/// Shows all completed events that need hours approval, with digital hours awareness
class HoursApprovalListScreen extends StatefulWidget {
  const HoursApprovalListScreen({super.key});

  @override
  State<HoursApprovalListScreen> createState() =>
      _HoursApprovalListScreenState();
}

class _HoursApprovalListScreenState extends State<HoursApprovalListScreen> {
  final EventService _eventService = EventService();
  List<Map<String, dynamic>> _events = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final completedEvents = await _eventService.fetchEvents(tab: 'completed');

      final needsApproval = completedEvents.where((event) {
        // Only truly completed events need hours approval
        // The server ?tab=completed filter is the primary gate, but also
        // check the tab/status fields defensively for backward compatibility
        final tab = event['tab']?.toString();
        final status = event['status']?.toString();
        if (tab != null && tab != 'completed') return false;
        if (status != 'completed' && status != 'fulfilled') return false;
        final hoursStatus = event['hoursStatus']?.toString();
        return hoursStatus == null ||
               hoursStatus == 'pending' ||
               hoursStatus == 'sheet_submitted';
      }).toList();

      // Sort by date (most recent first)
      needsApproval.sort((a, b) {
        final dateA = _parseEventDate(a['date']) ?? DateTime(1970);
        final dateB = _parseEventDate(b['date']) ?? DateTime(1970);
        return dateB.compareTo(dateA);
      });

      setState(() {
        _events = needsApproval;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load data. Please try again.';
        _isLoading = false;
      });
    }
  }

  DateTime? _parseEventDate(dynamic date) {
    if (date == null) return null;
    try {
      if (date is DateTime) return date;
      return DateTime.parse(date.toString());
    } catch (e) {
      return null;
    }
  }

  /// Reads backend-computed approval fields from the event response.
  _EventHoursInfo _computeEventHoursInfo(Map<String, dynamic> event) {
    final acceptedStaff = event['accepted_staff'] as List? ?? [];
    final category = event['approvalCategory']?.toString();

    _EventStatus status;
    switch (category) {
      case 'ready_to_approve':
        status = _EventStatus.readyToApprove;
      case 'sheet_submitted':
        status = _EventStatus.sheetSubmitted;
      default:
        status = _EventStatus.needsHoursEntry;
    }

    return _EventHoursInfo(
      status: status,
      totalStaff: acceptedStaff.length,
      clockedOutCount: (event['clockedOutCount'] as num?)?.toInt() ?? 0,
      totalEstimatedHours: (event['totalEstimatedHours'] as num?)?.toDouble() ?? 0,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: AppBar(
        title: Text(l10n.hoursApproval),
        backgroundColor: AppColors.primaryPurple,
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: _loadEvents,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _buildError(theme)
                : _events.isEmpty
                    ? _buildEmptyState(theme)
                    : _buildEventsList(theme),
      ),
    );
  }

  Widget _buildError(ThemeData theme) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(l10n.failedToLoadEvents, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              _error ?? l10n.unknownError,
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadEvents,
              icon: const Icon(Icons.refresh),
              label: Text(l10n.retry),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 80, color: Colors.green[300]),
            const SizedBox(height: 24),
            Text(
              l10n.allCaughtUp,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.noEventsNeedApprovalDescription,
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _loadEvents,
              icon: const Icon(Icons.refresh),
              label: Text(l10n.refresh),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventsList(ThemeData theme) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _events.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) return _buildHeader(theme);
        final event = _events[index - 1];
        return _buildEventCard(event, theme);
      },
    );
  }

  Widget _buildHeader(ThemeData theme) {
    final l10n = AppLocalizations.of(context)!;

    int readyCount = 0;
    int sheetCount = 0;
    int needsEntryCount = 0;

    for (final event in _events) {
      final info = _computeEventHoursInfo(event);
      switch (info.status) {
        case _EventStatus.readyToApprove:
          readyCount++;
        case _EventStatus.sheetSubmitted:
          sheetCount++;
        case _EventStatus.needsHoursEntry:
          needsEntryCount++;
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if (readyCount > 0)
                _buildHeaderChip(
                  count: readyCount,
                  label: l10n.readyToApprove,
                  color: AppColors.success,
                  icon: Icons.check_circle_outline,
                ),
              if (sheetCount > 0)
                _buildHeaderChip(
                  count: sheetCount,
                  label: l10n.sheetSubmitted,
                  color: AppColors.warning,
                  icon: Icons.pending_actions,
                ),
              if (needsEntryCount > 0)
                _buildHeaderChip(
                  count: needsEntryCount,
                  label: l10n.needsHoursEntry,
                  color: AppColors.info,
                  icon: Icons.edit_note,
                ),
            ],
          ),
    );
  }

  Widget _buildHeaderChip({
    required int count,
    required String label,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            '$count $label',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventCard(Map<String, dynamic> event, ThemeData theme) {
    final l10n = AppLocalizations.of(context)!;
    final eventName = event['event_name']?.toString() ?? l10n.untitledJob;
    final clientName = event['client_name']?.toString() ?? '';
    final eventDate = _parseEventDate(event['date']);
    final info = _computeEventHoursInfo(event);

    // Status badge config
    String statusLabel;
    Color statusColor;
    IconData statusIcon;

    switch (info.status) {
      case _EventStatus.readyToApprove:
        statusLabel = l10n.readyToApprove;
        statusColor = AppColors.success;
        statusIcon = Icons.check_circle_outline;
      case _EventStatus.sheetSubmitted:
        statusLabel = l10n.sheetSubmitted;
        statusColor = AppColors.warning;
        statusIcon = Icons.pending_actions;
      case _EventStatus.needsHoursEntry:
        statusLabel = l10n.needsHoursEntry;
        statusColor = AppColors.info;
        statusIcon = Icons.edit_note;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          final result = await Navigator.of(context).push<bool>(
            MaterialPageRoute(
              builder: (_) => HoursApprovalDetailScreen(event: event),
            ),
          );
          if (result == true) _loadEvents();
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          eventName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (clientName.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.business,
                                size: 14,
                                color: AppColors.textMuted,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  clientName,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: AppColors.textMuted,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: statusColor.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(statusIcon, size: 14, color: statusColor),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              statusLabel,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: statusColor,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 16,
                        color: AppColors.textMuted,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        eventDate != null
                            ? '${eventDate.month}/${eventDate.day}/${eventDate.year}'
                            : l10n.dateUnknown,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                  if (info.totalStaff > 0)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '\u2022',
                          style: TextStyle(color: AppColors.textMuted),
                        ),
                        const SizedBox(width: 6),
                        Icon(Icons.people, size: 16, color: AppColors.textMuted),
                        const SizedBox(width: 4),
                        Text(
                          l10n.staffClockedCount(info.clockedOutCount, info.totalStaff),
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  if (info.totalEstimatedHours > 0)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '\u2022',
                          style: TextStyle(color: AppColors.textMuted),
                        ),
                        const SizedBox(width: 6),
                        Icon(Icons.schedule, size: 16, color: AppColors.textMuted),
                        const SizedBox(width: 4),
                        Text(
                          l10n.estimatedTotalHours(info.totalEstimatedHours.toStringAsFixed(1)),
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _EventStatus {
  readyToApprove,
  sheetSubmitted,
  needsHoursEntry,
}

class _EventHoursInfo {
  final _EventStatus status;
  final int totalStaff;
  final int clockedOutCount;
  final double totalEstimatedHours;

  const _EventHoursInfo({
    required this.status,
    required this.totalStaff,
    required this.clockedOutCount,
    required this.totalEstimatedHours,
  });
}
