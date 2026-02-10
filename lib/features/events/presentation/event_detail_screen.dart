import 'package:flutter/material.dart';
import 'package:nexa/l10n/app_localizations.dart';
import '../../extraction/services/event_service.dart';
import '../../extraction/presentation/pending_publish_screen.dart';
import '../../extraction/presentation/pending_edit_screen.dart';
import 'package:nexa/shared/presentation/theme/app_colors.dart';
import '../../attendance/presentation/bulk_clock_in_screen.dart';
import '../../attendance/services/attendance_service.dart';

class EventDetailScreen extends StatefulWidget {
  final Map<String, dynamic> event;
  final VoidCallback? onEventUpdated;

  const EventDetailScreen({
    super.key,
    required this.event,
    this.onEventUpdated,
  });

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  late Map<String, dynamic> event;
  final EventService _eventService = EventService();
  bool _isRemoving = false;
  bool _isUpdatingKeepOpen = false;

  @override
  void initState() {
    super.initState();
    event = widget.event;
  }

  @override
  Widget build(BuildContext context) {
    final String title = (event['client_name'] ?? 'Client').toString();
    final String subtitle = (event['shift_name'] ?? event['venue_name'] ?? AppLocalizations.of(context)!.untitledJob).toString();

    String dateStr = '';
    bool isUpcoming = false;
    final dynamic rawDate = event['date'];
    if (rawDate is String && rawDate.isNotEmpty) {
      try {
        final d = DateTime.parse(rawDate);
        final now = DateTime.now();
        isUpcoming = !d.isBefore(DateTime(now.year, now.month, now.day));
        dateStr = '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      } catch (_) {
        dateStr = rawDate;
      }
    }

    final String location = [
      event['city'],
      event['state'],
    ].where((v) => v != null && v.toString().isNotEmpty).join(', ');

    final int? headcount = (event['headcount_total'] is int)
        ? event['headcount_total'] as int
        : int.tryParse((event['headcount_total'] ?? '').toString());

    final List<dynamic> roles = (event['roles'] is List)
        ? (event['roles'] as List)
        : const [];

    final List<dynamic> acceptedStaff = (event['accepted_staff'] is List)
        ? (event['accepted_staff'] as List)
        : const [];

    final statusColor = isUpcoming
        ? AppColors.success
        : AppColors.textMuted;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: AppColors.techBlue,
        foregroundColor: Colors.white,
        actions: [
          // Only show edit for upcoming events
          if (isUpcoming)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => _showEditDialog(),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Event Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.techBlue.withOpacity(0.08),
                    AppColors.yellow.withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  // Status and Visibility Badges Row
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      // Status Badge (Upcoming/Past)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: statusColor.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          isUpcoming ? 'Upcoming' : 'Past',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: statusColor,
                          ),
                        ),
                      ),
                      // Visibility Badge (for published events or drafts sent to staff)
                      if (event['status'] == 'published' ||
                          (event['status'] == 'draft' && (event['accepted_staff'] as List?)?.isNotEmpty == true))
                        _buildVisibilityBadge(),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Action Buttons for Draft Events (Publish & Edit)
            if (event['status'] == 'draft' && (event['accepted_staff'] as List?)?.isEmpty != false) ...[
              _buildDraftActionButtons(),
              const SizedBox(height: 24),
            ],

            // Action Buttons for Published Events (or drafts sent to staff)
            if (event['status'] == 'published' ||
                (event['status'] == 'draft' && (event['accepted_staff'] as List?)?.isNotEmpty == true)) ...[
              _buildActionButtons(),
              const SizedBox(height: 24),
            ],

            // Event Details
            if (dateStr.isNotEmpty) _buildInfoRow(Icons.calendar_today, AppLocalizations.of(context)!.date, dateStr),
            if (location.isNotEmpty) _buildInfoRow(Icons.place, AppLocalizations.of(context)!.location, location),
            if (headcount != null) _buildInfoRow(Icons.people, AppLocalizations.of(context)!.headcount, headcount.toString()),
            if (event['venue_name'] != null) _buildInfoRow(Icons.location_city, AppLocalizations.of(context)!.locationName, event['venue_name'].toString()),
            if (event['venue_address'] != null) _buildInfoRow(Icons.pin_drop, AppLocalizations.of(context)!.address, event['venue_address'].toString()),
            if (event['start_time'] != null) _buildInfoRow(Icons.schedule, AppLocalizations.of(context)!.startTime, event['start_time'].toString()),
            if (event['end_time'] != null) _buildInfoRow(Icons.schedule, AppLocalizations.of(context)!.endTime, event['end_time'].toString()),

            // Roles Section
            if (roles.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text(
                AppLocalizations.of(context)!.rolesNeeded,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 12),
              ...roles.map((role) {
                if (role is! Map<String, dynamic>) return const SizedBox.shrink();
                final roleMap = role;
                final String rName = (roleMap['role'] ?? 'Unknown').toString();
                final int rCount = int.tryParse((roleMap['count'] ?? '').toString()) ??
                    (roleMap['count'] is int ? (roleMap['count'] as int) : 0);

                // Compute accepted count for this role
                final int acceptedForRole = acceptedStaff.where((m) {
                  if (m is Map<String, dynamic>) {
                    final roleVal = (m['role'] ?? '').toString().toLowerCase();
                    return roleVal == rName.toLowerCase();
                  }
                  return false;
                }).length;

                final int vacanciesLeft = (rCount - acceptedForRole).clamp(0, 1 << 30);

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.warning.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.work, color: AppColors.warning, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              rCount > 0
                                  ? '$rName ($acceptedForRole/$rCount, $vacanciesLeft left)'
                                  : rName,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (roleMap['call_time'] != null)
                              Text(
                                'Call time: ${roleMap['call_time']}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],

            // Accepted Staff Section
            if (acceptedStaff.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text(
                'Accepted Staff (${acceptedStaff.length})',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 12),
              ...acceptedStaff.map((member) {
                String displayName;
                String? status;
                String? roleLabel;
                String? userKey;
                String? appId;
                String? pictureUrl;

                if (member is Map<String, dynamic>) {
                  final m = member;
                  displayName = (m['name'] ??
                          m['first_name'] ??
                          m['email'] ??
                          m['subject'] ??
                          m['userKey'] ??
                          'Member')
                      .toString();
                  status = m['response']?.toString();
                  final r = (m['role'] ?? '').toString();
                  roleLabel = r.isNotEmpty ? r : null;
                  userKey = m['userKey']?.toString();
                  appId = m['app_id']?.toString();
                  pictureUrl = m['picture']?.toString();
                } else if (member is String) {
                  displayName = member;
                } else {
                  displayName = member.toString();
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.formFillCyan,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.info.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      // Profile Avatar (smaller)
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: AppColors.info.withOpacity(0.1),
                        backgroundImage: pictureUrl != null && pictureUrl.isNotEmpty
                            ? NetworkImage(pictureUrl)
                            : null,
                        child: pictureUrl == null || pictureUrl.isEmpty
                            ? const Icon(
                                Icons.person,
                                color: AppColors.info,
                                size: 18,
                              )
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (roleLabel != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                roleLabel,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                            if (appId != null && appId.isNotEmpty) ...[
                              const SizedBox(height: 1),
                              Text(
                                'ID: $appId',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (status != null) ...[
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.success.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            status,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppColors.success,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      // Clock-in button for published events with accepted staff
                      if (event['status'] != 'draft' && userKey != null) ...[
                        const SizedBox(width: 10),
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _confirmAndClockIn(userKey!, displayName),
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppColors.success.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(
                                Icons.timer_outlined,
                                size: 18,
                                color: AppColors.success,
                              ),
                            ),
                          ),
                        ),
                      ],
                      // Only show remove button for upcoming events (more elegant)
                      if (isUpcoming && userKey != null) ...[
                        const SizedBox(width: 10),
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _isRemoving ? null : () => _removeStaffMember(userKey!),
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppColors.errorDark.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(
                                Icons.person_remove_outlined,
                                size: 16,
                                color: AppColors.errorDark,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }),
            ],

            // Notes Section
            if (event['notes'] != null && event['notes'].toString().isNotEmpty) ...[
              const SizedBox(height: 24),
              const Text(
                'Notes',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.grey.shade200,
                    width: 1,
                  ),
                ),
                child: Text(
                  event['notes'].toString(),
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _showEditDialog() async {
    final eventId = (event['_id'] ?? event['id'] ?? '').toString();

    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PendingEditScreen(
          draft: event,
          draftId: eventId,
        ),
      ),
    );

    if (result == true) {
      // Refresh the event data by popping and letting parent reload
      widget.onEventUpdated?.call();
      if (!mounted) return;
      Navigator.of(context).pop();
    }
  }

  Future<void> _removeStaffMember(String userKey) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Staff Member'),
        content: const Text('Are you sure you want to remove this staff member from the event?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.errorDark,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isRemoving = true);

    try {
      final eventId = (event['_id'] ?? event['id'] ?? '').toString();
      final updatedEvent = await _eventService.removeAcceptedStaff(eventId, userKey);

      setState(() {
        event = updatedEvent;
        _isRemoving = false;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Staff member removed successfully')),
      );

      // Notify parent to refresh
      widget.onEventUpdated?.call();
    } catch (e) {
      setState(() => _isRemoving = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to remove staff member: $e')),
      );
    }
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.techBlue),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textDark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVisibilityBadge() {
    final privacyStatus = _getPrivacyStatus();
    final privacyColor = _getPrivacyColor(privacyStatus);
    final privacyLabel = privacyStatus == 'private'
        ? 'Private'
        : privacyStatus == 'public'
            ? 'Public'
            : 'Private+Public';
    final privacyIcon = privacyStatus == 'private'
        ? Icons.lock_outline
        : privacyStatus == 'public'
            ? Icons.public
            : Icons.group;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: privacyColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: privacyColor.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(privacyIcon, size: 14, color: privacyColor),
          const SizedBox(width: 6),
          Text(
            privacyLabel,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: privacyColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDraftActionButtons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Publish Button
        ElevatedButton.icon(
          onPressed: _navigateToPublish,
          icon: const Icon(Icons.send, size: 20),
          label: const Text('Publish'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.success,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Edit Button
        OutlinedButton.icon(
          onPressed: _navigateToEdit,
          icon: const Icon(Icons.edit, size: 20),
          label: const Text('Edit Details'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.techBlue,
            side: const BorderSide(color: AppColors.techBlue, width: 2),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ],
    );
  }

  void _navigateToPublish() async {
    final eventId = (event['_id'] ?? event['id'] ?? '').toString();

    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PendingPublishScreen(
          draft: event,
          draftId: eventId,
        ),
      ),
    );

    if (result == true) {
      widget.onEventUpdated?.call();
      if (!mounted) return;
      Navigator.of(context).pop();
    }
  }

  void _navigateToEdit() async {
    final eventId = (event['_id'] ?? event['id'] ?? '').toString();

    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PendingEditScreen(
          draft: event,
          draftId: eventId,
        ),
      ),
    );

    if (result == true) {
      widget.onEventUpdated?.call();
      if (!mounted) return;
      // Refresh the event data
      try {
        final updatedEvent = await _eventService.getEvent(eventId);
        setState(() {
          event = updatedEvent;
        });
      } catch (e) {
        // If refresh fails, just pop
        Navigator.of(context).pop();
      }
    }
  }

  Widget _buildActionButtons() {
    final privacyStatus = _getPrivacyStatus();
    final keepOpen = event['keepOpen'] == true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Keep Open toggle (prevents auto-completion)
        Card(
          elevation: 0,
          color: AppColors.techBlue.withOpacity(0.05),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(
              color: AppColors.techBlue.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: SwitchListTile(
            title: const Text(
              'Keep Open After Event',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            subtitle: const Text(
              'Prevent automatic completion when event date passes',
              style: TextStyle(fontSize: 12),
            ),
            value: keepOpen,
            onChanged: _isUpdatingKeepOpen ? null : _toggleKeepOpen,
            activeColor: AppColors.techBlue,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          ),
        ),
        const SizedBox(height: 16),
        // Move to Drafts button (always shown for published events)
        ElevatedButton.icon(
          onPressed: _isRemoving ? null : _moveToDrafts,
          icon: const Icon(Icons.undo, size: 18),
          label: const Text('Move to Drafts'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.warning,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
        // Clock In Staff button (published events with accepted staff, today or past)
        if (_shouldShowClockInButton()) ...[
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () => _openBulkClockIn(),
            icon: const Icon(Icons.login, size: 18),
            label: const Text('Clock In Staff'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
        // Open to All Staff button (only for private events)
        if (privacyStatus == 'private') ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _isRemoving ? null : _makePublic,
            icon: const Icon(Icons.groups, size: 20),
            label: const Text('Open to All Staff'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.info,
              side: const BorderSide(color: AppColors.info, width: 2),
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ],
    );
  }

  bool _shouldShowClockInButton() {
    final status = (event['status'] ?? 'draft').toString();
    if (status != 'published') return false;

    final acceptedStaff = event['accepted_staff'] as List<dynamic>?;
    if (acceptedStaff == null || acceptedStaff.isEmpty) return false;

    final rawDate = event['date'];
    if (rawDate is! String || rawDate.isEmpty) return false;
    try {
      final eventDate = DateTime.parse(rawDate);
      final today = DateTime.now();
      final todayStart = DateTime(today.year, today.month, today.day);
      // Allow today or past events (not future)
      return !eventDate.isAfter(todayStart.add(const Duration(days: 1)).subtract(const Duration(milliseconds: 1)));
    } catch (_) {
      return false;
    }
  }

  Future<void> _confirmAndClockIn(String userKey, String staffName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clock In'),
        content: Text('Clock in $staffName for this event?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
            ),
            child: const Text('Clock In'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    _clockInStaffMember(userKey, staffName);
  }

  Future<void> _clockInStaffMember(String userKey, String staffName) async {
    final eventId = event['_id']?.toString() ?? '';
    if (eventId.isEmpty) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Clocking in $staffName...')),
    );

    final result = await AttendanceService.bulkClockIn(
      eventId: eventId,
      userKeys: [userKey],
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Clock-in failed. Please try again.')),
      );
      return;
    }

    final results = result['results'] as List<dynamic>?;
    if (results != null && results.isNotEmpty) {
      final first = results.first as Map<String, dynamic>;
      final status = first['status'] as String?;
      if (status == 'already_clocked_in') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$staffName is already clocked in')),
        );
      } else if (status == 'success') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$staffName clocked in successfully'),
            backgroundColor: AppColors.success,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(first['message']?.toString() ?? 'Clock-in failed')),
        );
      }
    }
  }

  void _openBulkClockIn() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => BulkClockInScreen(event: event)),
    );
  }

  String _getPrivacyStatus() {
    // Read from database field if available
    final visibilityType = event['visibilityType']?.toString();
    if (visibilityType != null) {
      // Map database values to display values
      if (visibilityType == 'private_public') {
        return 'private_public';
      }
      return visibilityType; // 'private' or 'public'
    }

    // Fallback to calculated logic for events without visibilityType field
    final status = (event['status'] ?? 'draft').toString();

    // Draft events are always private
    if (status == 'draft') {
      return 'private';
    }

    // For published events, check if had invitations before publishing
    if (status == 'published') {
      final publishedAtRaw = event['publishedAt'];
      final acceptedStaff = (event['accepted_staff'] as List?)?.cast<Map<String, dynamic>>() ?? [];

      if (publishedAtRaw != null && acceptedStaff.isNotEmpty) {
        try {
          final publishedAt = DateTime.parse(publishedAtRaw.toString());

          // Check if any staff accepted before the event was published
          for (final staff in acceptedStaff) {
            final respondedAtRaw = staff['respondedAt'];
            if (respondedAtRaw != null) {
              try {
                final respondedAt = DateTime.parse(respondedAtRaw.toString());
                if (respondedAt.isBefore(publishedAt)) {
                  return 'private_public'; // Had private invitations before publishing
                }
              } catch (_) {}
            }
          }
        } catch (_) {}
      }

      return 'public'; // Published without prior private invitations
    }

    // Fallback for other statuses
    return 'private';
  }

  Color _getPrivacyColor(String privacyStatus) {
    switch (privacyStatus) {
      case 'private':
        return AppColors.techBlue; // Indigo
      case 'public':
        return AppColors.success; // Green
      case 'private_public':
      case 'mix': // Legacy fallback
        return AppColors.warning; // Amber/Orange
      default:
        return Colors.grey;
    }
  }

  Future<void> _moveToDrafts() async {
    final clientName = (event['client_name'] ?? 'this job').toString();
    final acceptedStaff = (event['accepted_staff'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final hasAcceptedStaff = acceptedStaff.isNotEmpty;

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Move to Drafts'),
        content: Text(
          hasAcceptedStaff
              ? 'Move "$clientName" back to drafts?\n\n'
                  'This will:\n'
                  '• Remove all ${acceptedStaff.length} accepted staff members\n'
                  '• Send them a notification\n'
                  '• Hide the job from staff view\n\n'
                  'You can republish it later.'
              : 'Move "$clientName" back to drafts?\n\n'
                  'This will hide the job from staff view. You can republish it later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.warning,
            ),
            child: const Text('Move to Drafts'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isRemoving = true);

    try {
      final eventId = (event['_id'] ?? event['id'] ?? '').toString();

      // Call the unpublish endpoint
      await _eventService.unpublishEvent(eventId);

      if (!mounted) return;

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$clientName moved to drafts!'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );

      // Notify parent to refresh and pop this screen
      widget.onEventUpdated?.call();
      Navigator.of(context).pop();
    } catch (e) {
      setState(() => _isRemoving = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to move to drafts: ${e.toString()}'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _toggleKeepOpen(bool newValue) async {
    setState(() => _isUpdatingKeepOpen = true);

    try {
      final eventId = (event['_id'] ?? event['id'] ?? '').toString();

      // Update keepOpen field via API
      final updatedEvent = await _eventService.updateEvent(eventId, {
        'keepOpen': newValue,
      });

      if (!mounted) return;

      // Update local event state
      setState(() {
        event = updatedEvent;
        _isUpdatingKeepOpen = false;
      });

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newValue
                ? 'Event will stay open after completion'
                : 'Event will auto-complete when past',
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );

      // Notify parent to refresh
      widget.onEventUpdated?.call();
    } catch (e) {
      setState(() => _isUpdatingKeepOpen = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update: ${e.toString()}'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _makePublic() async {
    final clientName = (event['client_name'] ?? 'this job').toString();

    // TODO: Show team selector dialog
    // For now, show a simple confirmation that will make it fully public
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Open to All Staff'),
        content: Text(
          'Make "$clientName" visible to all staff members?\n\n'
          'This will change the job from private (invited only) to public, allowing all team members to see and accept it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.info,
              side: const BorderSide(color: AppColors.info, width: 2),
            ),
            child: const Text('Open to All'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isRemoving = true);

    try {
      final eventId = (event['_id'] ?? event['id'] ?? '').toString();

      // Call the change visibility endpoint
      await _eventService.changeVisibility(
        eventId,
        visibilityType: 'public',
      );

      if (!mounted) return;

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$clientName is now open to all staff!'),
          backgroundColor: AppColors.info,
          behavior: SnackBarBehavior.floating,
        ),
      );

      // Reload event data
      final updatedEvent = await _eventService.getEvent(eventId);
      setState(() {
        event = updatedEvent;
        _isRemoving = false;
      });

      // Notify parent to refresh
      widget.onEventUpdated?.call();
    } catch (e) {
      setState(() => _isRemoving = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to make public: ${e.toString()}'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
