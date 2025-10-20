import 'package:flutter/material.dart';
import 'package:nexa/l10n/app_localizations.dart';
import 'event_edit_screen.dart';
import '../../extraction/services/event_service.dart';

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

  @override
  void initState() {
    super.initState();
    event = widget.event;
  }

  @override
  Widget build(BuildContext context) {
    final String title = (event['client_name'] ?? 'Client').toString();
    final String subtitle = (event['event_name'] ?? event['venue_name'] ?? AppLocalizations.of(context)!.untitledJob).toString();

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
        ? const Color(0xFF059669)
        : const Color(0xFF6B7280);

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: const Color(0xFF6366F1),
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
                    const Color(0xFF6366F1).withOpacity(0.08),
                    const Color(0xFF8B5CF6).withOpacity(0.05),
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
                      color: Color(0xFF0F172A),
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
                ],
              ),
            ),
            const SizedBox(height: 24),

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
                  color: Color(0xFF0F172A),
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
                      color: const Color(0xFFF59E0B).withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.work, color: Color(0xFFF59E0B), size: 20),
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
              const Text(
                'Accepted Staff',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
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
                    color: const Color(0xFFF0F9FF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFF0EA5E9).withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      // Profile Avatar (smaller)
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: const Color(0xFF0EA5E9).withOpacity(0.1),
                        backgroundImage: pictureUrl != null && pictureUrl.isNotEmpty
                            ? NetworkImage(pictureUrl)
                            : null,
                        child: pictureUrl == null || pictureUrl.isEmpty
                            ? const Icon(
                                Icons.person,
                                color: Color(0xFF0EA5E9),
                                size: 18,
                              )
                            : null,
                      ),
                      const SizedBox(width: 10),
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
                      if (status != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF059669).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            status,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF059669),
                            ),
                          ),
                        ),
                      // Only show remove button for upcoming events (more elegant)
                      if (isUpcoming && userKey != null) ...[
                        const SizedBox(width: 6),
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _isRemoving ? null : () => _removeStaffMember(userKey!),
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDC2626).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(
                                Icons.person_remove_outlined,
                                size: 16,
                                color: Color(0xFFDC2626),
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
                  color: Color(0xFF0F172A),
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
    print('DEBUG: Event detail - passing event to edit screen');
    print('DEBUG: Event _id: ${event['_id']}');
    print('DEBUG: Event id: ${event['id']}');
    print('DEBUG: Event keys: ${event.keys.toList()}');

    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EventEditScreen(event: event),
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
              backgroundColor: const Color(0xFFDC2626),
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
          Icon(icon, size: 20, color: const Color(0xFF6366F1)),
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
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
