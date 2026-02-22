import 'package:flutter/material.dart';
import 'package:nexa/l10n/app_localizations.dart';
import 'package:nexa/features/hours_approval/presentation/hours_approval_screen.dart';
import 'package:nexa/features/extraction/services/event_service.dart';
import 'package:nexa/shared/presentation/theme/app_colors.dart';

/// Hours Approval List Screen
/// Shows all completed events that need hours approval
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
      final pastEvents = await _eventService.fetchEvents(isPast: true);

      // Filter by hoursStatus (kept client-side since null values are awkward as query params)
      final needsApproval = pastEvents.where((event) {
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
        _error = e.toString();
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
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
            Icon(
              Icons.error_outline,
              size: 64,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.failedToLoadEvents,
              style: theme.textTheme.titleMedium,
            ),
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
            Icon(
              Icons.check_circle_outline,
              size: 80,
              color: Colors.green[300],
            ),
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
      itemCount: _events.length + 1, // +1 for header
      itemBuilder: (context, index) {
        if (index == 0) {
          return _buildHeader(theme);
        }

        final event = _events[index - 1];
        return _buildEventCard(event, theme);
      },
    );
  }

  Widget _buildHeader(ThemeData theme) {
    final l10n = AppLocalizations.of(context)!;
    final pendingCount = _events.where((e) =>
      e['hoursStatus']?.toString() == 'sheet_submitted'
    ).length;
    final needsSubmissionCount = _events.where((e) =>
      e['hoursStatus']?.toString() == null ||
      e['hoursStatus']?.toString() == 'pending'
    ).length;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.hoursApproval,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.primaryPurple,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (pendingCount > 0) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.pending_actions,
                        size: 16,
                        color: Colors.orange[700],
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '$pendingCount ${l10n.pendingReviewLabel}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.orange[700],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
              ],
              if (needsSubmissionCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.upload_file,
                        size: 16,
                        color: Colors.blue[700],
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '$needsSubmissionCount ${l10n.needsSheetLabel}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue[700],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
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
    final hoursStatus = event['hoursStatus']?.toString();
    final acceptedStaff = (event['accepted_staff'] as List?)?.length ?? 0;

    // Determine status badge
    String statusLabel;
    MaterialColor statusColor;
    IconData statusIcon;

    if (hoursStatus == 'sheet_submitted') {
      statusLabel = l10n.pendingReviewLabel;
      statusColor = Colors.orange;
      statusIcon = Icons.pending_actions;
    } else {
      statusLabel = l10n.needsSheetLabel;
      statusColor = Colors.blue;
      statusIcon = Icons.upload_file;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          final result = await Navigator.of(context).push<bool>(
            MaterialPageRoute(
              builder: (_) => HoursApprovalScreen(event: event),
            ),
          );

          // Refresh if changes were made
          if (result == true) {
            _loadEvents();
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
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
                                color: theme.colorScheme.onSurface.withOpacity(0.6),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                clientName,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: statusColor.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          statusIcon,
                          size: 14,
                          color: statusColor[700],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          statusLabel,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: statusColor[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 16,
                    color: theme.colorScheme.onSurface.withOpacity(0.5),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    eventDate != null
                        ? '${eventDate.month}/${eventDate.day}/${eventDate.year}'
                        : l10n.dateUnknown,
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(width: 16),
                  Icon(
                    Icons.people,
                    size: 16,
                    color: theme.colorScheme.onSurface.withOpacity(0.5),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '$acceptedStaff staff',
                    style: theme.textTheme.bodySmall,
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
