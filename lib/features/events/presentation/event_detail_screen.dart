import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:nexa/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/config/environment.dart';
import '../../../core/constants/storage_keys.dart';
import '../../brand/data/providers/brand_provider.dart';
import '../../extraction/services/event_service.dart';
import '../../extraction/presentation/pending_publish_screen.dart';
import '../../extraction/presentation/pending_edit_screen.dart';
import '../../extraction/presentation/ai_chat_screen.dart';
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
  bool _isGeneratingSheet = false;

  @override
  void initState() {
    super.initState();
    event = widget.event;
  }

  @override
  Widget build(BuildContext context) {
    final String title = (event['client_name'] ?? AppLocalizations.of(context)!.client).toString();
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
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(title),
        backgroundColor: AppColors.navySpaceCadet,
        foregroundColor: Colors.white,
        actions: [
          if (isUpcoming)
            IconButton(
              icon: const Icon(Icons.edit_rounded),
              onPressed: () => _showEditDialog(),
            ),
        ],
      ),
      floatingActionButton: GestureDetector(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => AIChatScreen(
                startNewConversation: true,
                eventData: event,
              ),
            ),
          );
        },
        child: Container(
          height: 44,
          padding: const EdgeInsets.only(left: 4, right: 14),
          decoration: BoxDecoration(
            color: AppColors.navySpaceCadet.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: AppColors.navySpaceCadet.withValues(alpha: 0.45),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipOval(
                child: Image.asset(
                  'assets/ai_assistant_logo.png',
                  width: 36,
                  height: 36,
                  fit: BoxFit.cover,
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Text(
                  'Ask AI',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(left: 16, top: 16, right: 16, bottom: 80),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Hero header card ─────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF212C4A), Color(0xFF1E3A8A)],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF212C4A).withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: Colors.white.withValues(alpha: 0.65),
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _buildPill(
                        isUpcoming
                            ? AppLocalizations.of(context)!.upcoming
                            : AppLocalizations.of(context)!.past,
                        isUpcoming ? AppColors.success : AppColors.textMuted,
                      ),
                      if (event['status'] == 'published' ||
                          (event['status'] == 'draft' &&
                              (event['accepted_staff'] as List?)?.isNotEmpty ==
                                  true))
                        _buildVisibilityBadge(),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Action Buttons for Draft Events (Publish & Edit)
            if (event['status'] == 'draft' &&
                (event['accepted_staff'] as List?)?.isEmpty != false) ...[
              _buildDraftActionButtons(),
              const SizedBox(height: 16),
            ],

            // Action Buttons for Published/Fulfilled Events (or drafts sent to staff)
            if (event['status'] == 'published' ||
                event['status'] == 'fulfilled' ||
                (event['status'] == 'draft' &&
                    (event['accepted_staff'] as List?)?.isNotEmpty == true)) ...[
              _buildActionButtons(),
              const SizedBox(height: 16),
            ],

            // ── Event Details card ────────────────────────────────
            Builder(builder: (context) {
              final l10n = AppLocalizations.of(context)!;
              final rows = <Map<String, dynamic>>[];
              if (dateStr.isNotEmpty)
                rows.add({'icon': Icons.calendar_today_rounded, 'label': l10n.date, 'value': dateStr});
              if (location.isNotEmpty)
                rows.add({'icon': Icons.place_rounded, 'label': l10n.location, 'value': location});
              if (headcount != null)
                rows.add({'icon': Icons.people_rounded, 'label': l10n.headcount, 'value': headcount.toString()});
              if (event['venue_name'] != null)
                rows.add({'icon': Icons.location_city_rounded, 'label': l10n.locationName, 'value': event['venue_name'].toString()});
              if (event['venue_address'] != null)
                rows.add({'icon': Icons.pin_drop_rounded, 'label': l10n.address, 'value': event['venue_address'].toString()});
              if (event['start_time'] != null)
                rows.add({'icon': Icons.schedule_rounded, 'label': l10n.startTime, 'value': event['start_time'].toString()});
              if (event['end_time'] != null)
                rows.add({'icon': Icons.access_time_filled_rounded, 'label': l10n.endTime, 'value': event['end_time'].toString()});
              if (rows.isEmpty) return const SizedBox.shrink();
              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: rows.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final row = entry.value;
                    final icon = row['icon'] as IconData;
                    final label = row['label'] as String;
                    final value = row['value'] as String;
                    return Column(
                      children: [
                        if (idx > 0)
                          const Divider(height: 1, color: Color(0xFFF1F5F9)),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 13,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: AppColors.navySpaceCadet
                                      .withValues(alpha: 0.07),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  icon,
                                  size: 16,
                                  color: AppColors.navySpaceCadet,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      label,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey.shade500,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      value,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.navySpaceCadet,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              );
            }),

            // ── Roles Section ─────────────────────────────────────
            if (roles.isNotEmpty) ...[
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.work_rounded,
                      size: 16,
                      color: AppColors.warning,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    AppLocalizations.of(context)!.rolesNeeded,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navySpaceCadet,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ...roles.map((role) {
                if (role is! Map<String, dynamic>) return const SizedBox.shrink();
                final roleMap = role;
                final String rName = (roleMap['role'] ?? AppLocalizations.of(context)!.unknown).toString();
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
                                  ? AppLocalizations.of(context)!.roleVacancies(rName, acceptedForRole, rCount, vacanciesLeft)
                                  : rName,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (roleMap['call_time'] != null)
                              Text(
                                AppLocalizations.of(context)!.callTime(roleMap['call_time'].toString()),
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
              Row(
                children: [
                  Expanded(
                    child: Text(
                      AppLocalizations.of(context)!.acceptedStaffCount(acceptedStaff.length),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),
                  ),
                  if (_isGeneratingSheet)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    PopupMenuButton<String>(
                      icon: const Icon(
                        Icons.description_outlined,
                        color: AppColors.techBlue,
                        size: 22,
                      ),
                      tooltip: AppLocalizations.of(context)!.workingHoursSheetTooltip,
                      onSelected: _generateWorkingHoursSheet,
                      itemBuilder: (ctx) => [
                        PopupMenuItem(
                          value: 'pdf',
                          child: Row(
                            children: [
                              const Icon(Icons.picture_as_pdf, size: 18, color: Colors.red),
                              const SizedBox(width: 8),
                              Text(AppLocalizations.of(context)!.hoursSheetPdf),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'docx',
                          child: Row(
                            children: [
                              const Icon(Icons.description, size: 18, color: Colors.blue),
                              const SizedBox(width: 8),
                              Text(AppLocalizations.of(context)!.hoursSheetWord),
                            ],
                          ),
                        ),
                      ],
                    ),
                ],
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
                          AppLocalizations.of(context)!.member)
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
                                AppLocalizations.of(context)!.idLabel(appId!),
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
              Text(
                AppLocalizations.of(context)!.notes,
                style: const TextStyle(
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
        title: Text(AppLocalizations.of(context)!.removeStaffMember),
        content: Text(AppLocalizations.of(context)!.removeStaffConfirmation),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.errorDark,
            ),
            child: Text(AppLocalizations.of(context)!.remove),
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
        SnackBar(content: Text(AppLocalizations.of(context)!.staffRemovedSuccess)),
      );

      // Notify parent to refresh
      widget.onEventUpdated?.call();
    } catch (e) {
      setState(() => _isRemoving = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${AppLocalizations.of(context)!.failedToRemoveStaff}: $e')),
      );
    }
  }

  Widget _buildPill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
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
    final l10n = AppLocalizations.of(context)!;
    final privacyLabel = privacyStatus == 'private'
        ? l10n.privateLabel
        : l10n.publicLabel;
    final privacyIcon = privacyStatus == 'private'
        ? Icons.lock_outline
        : Icons.public;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: privacyColor.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: privacyColor.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(privacyIcon, size: 12, color: privacyColor),
          const SizedBox(width: 5),
          Text(
            privacyLabel,
            style: TextStyle(
              fontSize: 11,
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
        // Publish — gradient fill
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF212C4A), Color(0xFF1E3A8A)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: ElevatedButton.icon(
            onPressed: _navigateToPublish,
            icon: const Icon(Icons.send_rounded, size: 18),
            label: Text(AppLocalizations.of(context)!.publish),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
              textStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        // Edit — navy outline
        OutlinedButton.icon(
          onPressed: _navigateToEdit,
          icon: const Icon(Icons.edit_rounded, size: 18),
          label: Text(AppLocalizations.of(context)!.editDetails),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.navySpaceCadet,
            side: const BorderSide(color: AppColors.navySpaceCadet, width: 1.5),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
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
            title: Text(
              AppLocalizations.of(context)!.keepOpenAfterEvent,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            subtitle: Text(
              AppLocalizations.of(context)!.preventAutoCompletion,
              style: const TextStyle(fontSize: 12),
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
          label: Text(AppLocalizations.of(context)!.moveToDrafts),
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
            label: Text(AppLocalizations.of(context)!.clockInStaff),
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
            label: Text(AppLocalizations.of(context)!.openToAllStaff),
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
        title: Text(AppLocalizations.of(context)!.clockIn),
        content: Text(AppLocalizations.of(context)!.clockInConfirmation(staffName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
            ),
            child: Text(AppLocalizations.of(context)!.clockIn),
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
      SnackBar(content: Text(AppLocalizations.of(context)!.clockingInStaff(staffName))),
    );

    final result = await AttendanceService.bulkClockIn(
      eventId: eventId,
      userKeys: [userKey],
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.clockInFailed)),
      );
      return;
    }

    final results = result['results'] as List<dynamic>?;
    if (results != null && results.isNotEmpty) {
      final first = results.first as Map<String, dynamic>;
      final status = first['status'] as String?;
      if (status == 'already_clocked_in') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.alreadyClockedInName(staffName))),
        );
      } else if (status == 'success') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.clockedInSuccess(staffName)),
            backgroundColor: AppColors.success,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(first['message']?.toString() ?? AppLocalizations.of(context)!.clockInFailed)),
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
      // Treat legacy 'private_public' as 'public'
      if (visibilityType == 'private_public') return 'public';
      return visibilityType; // 'private' or 'public'
    }

    // Fallback for events without visibilityType field
    final status = (event['status'] ?? 'draft').toString();
    if (status == 'draft') return 'private';
    if (status == 'published') return 'public';
    return 'private';
  }

  Color _getPrivacyColor(String privacyStatus) {
    switch (privacyStatus) {
      case 'private':
        return AppColors.techBlue; // Indigo
      case 'public':
        return AppColors.success; // Green
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
        title: Text(AppLocalizations.of(context)!.moveToDrafts),
        content: Text(
          hasAcceptedStaff
              ? '${AppLocalizations.of(context)!.moveToDraftsConfirmation(clientName)}\n\n${AppLocalizations.of(context)!.moveToDraftsWithStaff(acceptedStaff.length)}'
              : '${AppLocalizations.of(context)!.moveToDraftsConfirmation(clientName)}\n\n${AppLocalizations.of(context)!.moveToDraftsNoStaff}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.warning,
            ),
            child: Text(AppLocalizations.of(context)!.moveToDrafts),
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
          content: Text(AppLocalizations.of(context)!.eventMovedToDrafts(clientName)),
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
          content: Text('${AppLocalizations.of(context)!.failedToMoveToDrafts}: ${e.toString()}'),
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
                ? AppLocalizations.of(context)!.eventStaysOpen
                : AppLocalizations.of(context)!.eventAutoCompletes,
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
          content: Text('${AppLocalizations.of(context)!.failedToUpdate}: ${e.toString()}'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _generateWorkingHoursSheet(String format) async {
    final eventId = (event['_id'] ?? event['id'] ?? '').toString();
    if (eventId.isEmpty) return;

    setState(() => _isGeneratingSheet = true);

    // Read preferred design from BrandProvider
    String? templateDesign;
    try {
      templateDesign = context.read<BrandProvider>().preferredDocDesign;
    } catch (_) {}

    try {
      const storage = FlutterSecureStorage();
      final token = await storage.read(key: StorageKeys.accessToken);
      final baseUrl = Environment.instance.getOrDefault(
        'API_BASE_URL', 'https://api.nexapymesoft.com',
      );

      final bodyMap = <String, String>{'format': format};
      if (templateDesign != null) {
        bodyMap['template_design'] = templateDesign;
      }

      final response = await http.post(
        Uri.parse('$baseUrl/api/events/$eventId/working-hours-sheet'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode(bodyMap),
      ).timeout(const Duration(seconds: 30));

      if (!mounted) return;
      setState(() => _isGeneratingSheet = false);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final url = data['url'] as String?;
        if (url != null) {
          final uri = Uri.parse(url);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        }
      } else {
        final errMsg = jsonDecode(response.body)['message'] ?? AppLocalizations.of(context)!.unknownError;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppLocalizations.of(context)!.failedToGenerate}: $errMsg')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isGeneratingSheet = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppLocalizations.of(context)!.failedToGenerateSheet}: $e')),
        );
      }
    }
  }

  Future<void> _makePublic() async {
    final clientName = (event['client_name'] ?? 'this job').toString();

    // TODO: Show team selector dialog
    // For now, show a simple confirmation that will make it fully public
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.openToAllStaff),
        content: Text(
          AppLocalizations.of(context)!.openToAllStaffConfirmation(clientName),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.info,
              side: const BorderSide(color: AppColors.info, width: 2),
            ),
            child: Text(AppLocalizations.of(context)!.openToAll),
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
          content: Text(AppLocalizations.of(context)!.eventNowOpenToAll(clientName)),
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
          content: Text('${AppLocalizations.of(context)!.failedToMakePublic}: ${e.toString()}'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
