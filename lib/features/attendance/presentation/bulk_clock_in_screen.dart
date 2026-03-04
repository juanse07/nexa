import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nexa/l10n/app_localizations.dart';
import 'package:nexa/shared/presentation/theme/app_colors.dart';
import 'package:nexa/shared/services/error_display_service.dart';
import '../services/attendance_service.dart';

/// Screen for managers to bulk clock-in multiple staff members at once.
class BulkClockInScreen extends StatefulWidget {
  final Map<String, dynamic> event;

  const BulkClockInScreen({super.key, required this.event});

  @override
  State<BulkClockInScreen> createState() => _BulkClockInScreenState();
}

class _BulkClockInScreenState extends State<BulkClockInScreen> {
  final Set<String> _selectedUserKeys = {};
  final TextEditingController _noteController = TextEditingController();
  bool _isSubmitting = false;

  List<Map<String, dynamic>> get _acceptedStaff {
    final staff = widget.event['accepted_staff'] as List<dynamic>?;
    return staff?.cast<Map<String, dynamic>>() ?? [];
  }

  String get _eventName =>
      widget.event['client_name'] as String? ??
      widget.event['event_name'] as String? ??
      widget.event['shift_name'] as String? ??
      'Event';

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  void _toggleSelection(String userKey) {
    setState(() {
      if (_selectedUserKeys.contains(userKey)) {
        _selectedUserKeys.remove(userKey);
      } else {
        _selectedUserKeys.add(userKey);
      }
    });
  }

  void _selectAll() {
    setState(() {
      final eligible = _acceptedStaff
          .where((s) => !_isAlreadyClockedIn(s))
          .map((s) => s['userKey'] as String?)
          .whereType<String>()
          .toSet();
      if (_selectedUserKeys.containsAll(eligible) && eligible.isNotEmpty) {
        _selectedUserKeys.clear();
      } else {
        _selectedUserKeys
          ..clear()
          ..addAll(eligible);
      }
    });
  }

  bool _isAlreadyClockedIn(Map<String, dynamic> staff) {
    final attendance = staff['attendance'] as List<dynamic>?;
    if (attendance == null || attendance.isEmpty) return false;
    final last = attendance.last as Map<String, dynamic>;
    return last['clockOutAt'] == null;
  }

  Future<void> _performBulkClockIn() async {
    final l10n = AppLocalizations.of(context)!;
    if (_selectedUserKeys.isEmpty) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(l10n.pleaseSelectAtLeastOneStaff)));
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final response = await AttendanceService.bulkClockIn(
        eventId: widget.event['_id'] as String,
        userKeys: _selectedUserKeys.toList(),
        note: _noteController.text.isEmpty ? null : _noteController.text,
      );

      if (response != null && mounted) {
        final successful = response['successful'] as int? ?? 0;
        final total = response['total'] as int? ?? 0;
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(
            content: Text(l10n.successfullyClockedIn(successful, total)),
            backgroundColor: AppColors.success,
          ));
        _showResultsDialog(response);
      } else if (mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(
            content: Text(l10n.failedBulkClockIn),
            backgroundColor: AppColors.errorDark,
          ));
      }
    } catch (e) {
      if (mounted) ErrorDisplayService.showErrorFromException(context, e);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showResultsDialog(Map<String, dynamic> response) {
    final results = response['results'] as List<dynamic>?;
    if (results == null) return;
    final l10n = AppLocalizations.of(context)!;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_outline,
                  color: AppColors.success, size: 22),
            ),
            const SizedBox(width: 12),
            Text(
              l10n.bulkClockInResults,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: results.length,
            separatorBuilder: (_, __) =>
                Divider(height: 1, color: Colors.grey.shade200),
            itemBuilder: (_, i) {
              final r = results[i] as Map<String, dynamic>;
              final isSuccess = r['status'] == 'success';
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    Icon(
                      isSuccess ? Icons.check_circle : Icons.error_outline,
                      color: isSuccess ? AppColors.success : AppColors.errorDark,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            r['staffName'] as String? ?? l10n.unknown,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                          if (r['message'] is String &&
                              (r['message'] as String).isNotEmpty)
                            Text(
                              r['message'] as String,
                              style: TextStyle(
                                fontSize: 11,
                                color: isSuccess
                                    ? Colors.grey.shade500
                                    : AppColors.errorDark,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context, true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.navySpaceCadet,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              child: Text(l10n.done),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final eventDate = widget.event['date'] != null
        ? DateTime.tryParse(widget.event['date'] as String)
        : null;
    final eligibleCount =
        _acceptedStaff.where((s) => !_isAlreadyClockedIn(s)).length;
    final allSelected =
        eligibleCount > 0 && _selectedUserKeys.length >= eligibleCount;
    final venueLabel = widget.event['venue_name']?.toString() ??
        widget.event['venue_address']?.toString();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: Text(l10n.bulkClockIn),
        backgroundColor: AppColors.navySpaceCadet,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (eligibleCount > 0)
            TextButton(
              onPressed: _selectAll,
              child: Text(
                allSelected ? l10n.deselectAll : l10n.selectAll,
                style: const TextStyle(
                    color: Colors.white70, fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // ── Event header (extends AppBar visually) ─────────────────────
          Container(
            width: double.infinity,
            color: AppColors.navySpaceCadet,
            padding: const EdgeInsets.fromLTRB(20, 2, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _eventName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                if (eventDate != null) ...[
                  const SizedBox(height: 6),
                  Row(children: [
                    const Icon(Icons.calendar_today_outlined,
                        size: 13, color: Colors.white54),
                    const SizedBox(width: 6),
                    Text(
                      DateFormat('EEEE, MMMM d, yyyy').format(eventDate),
                      style: const TextStyle(fontSize: 13, color: Colors.white70),
                    ),
                  ]),
                ],
                if (venueLabel != null) ...[
                  const SizedBox(height: 4),
                  Row(children: [
                    const Icon(Icons.location_on_outlined,
                        size: 13, color: Colors.white54),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        venueLabel,
                        style: const TextStyle(
                            fontSize: 13, color: Colors.white70),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ]),
                ],
              ],
            ),
          ),

          // ── Selection counter strip ─────────────────────────────────────
          Container(
            color: Colors.white,
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              children: [
                Text(
                  l10n.staffCount(_acceptedStaff.length),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                  ),
                ),
                const Spacer(),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: _selectedUserKeys.isEmpty
                      ? const SizedBox.shrink()
                      : Container(
                          key: const ValueKey('badge'),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.techBlue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${_selectedUserKeys.length} selected',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.techBlue,
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 1),

          // ── Staff list ──────────────────────────────────────────────────
          Expanded(
            child: _acceptedStaff.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.people_outline,
                            size: 52, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        Text(
                          l10n.noAcceptedStaffForEvent,
                          style: TextStyle(
                              color: Colors.grey.shade500, fontSize: 15),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 16),
                    itemCount: _acceptedStaff.length,
                    itemBuilder: (_, i) =>
                        _buildStaffCard(_acceptedStaff[i]),
                  ),
          ),

          // ── Bottom panel ────────────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 12,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _noteController,
                    decoration: InputDecoration(
                      hintText: l10n.groupCheckInHint,
                      labelText: l10n.overrideNoteOptional,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: AppColors.techBlue, width: 1.5),
                      ),
                      prefixIcon: const Icon(Icons.edit_note_outlined,
                          color: Colors.grey, size: 20),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      isDense: true,
                    ),
                    maxLines: 1,
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed:
                          _selectedUserKeys.isEmpty || _isSubmitting
                              ? null
                              : _performBulkClockIn,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.navySpaceCadet,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        disabledBackgroundColor: Colors.grey.shade200,
                        disabledForegroundColor: Colors.grey.shade400,
                        elevation: 0,
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.login_rounded, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  l10n.clockInStaffCount(
                                      _selectedUserKeys.length),
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStaffCard(Map<String, dynamic> staff) {
    final l10n = AppLocalizations.of(context)!;
    final userKey = staff['userKey'] as String?;
    final isSelected =
        userKey != null && _selectedUserKeys.contains(userKey);
    final isClockedIn = _isAlreadyClockedIn(staff);

    final rawName = (staff['name'] ??
            '${staff['first_name'] ?? ''} ${staff['last_name'] ?? ''}'
                .trim())
        .toString();
    final name = rawName.isEmpty ? l10n.unknown : rawName;
    final role = staff['role']?.toString();
    final picture = staff['picture']?.toString();
    final initials = name[0].toUpperCase();

    return GestureDetector(
      onTap: isClockedIn || userKey == null
          ? null
          : () => _toggleSelection(userKey),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 8),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isClockedIn
              ? AppColors.success.withOpacity(0.04)
              : isSelected
                  ? AppColors.techBlue.withOpacity(0.07)
                  : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isClockedIn
                ? AppColors.success.withOpacity(0.3)
                : isSelected
                    ? AppColors.techBlue.withOpacity(0.5)
                    : Colors.grey.shade200,
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected || isClockedIn
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Row(
          children: [
            // ── Avatar with status badge ──────────────────────────────
            Stack(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: isClockedIn
                      ? AppColors.success.withOpacity(0.12)
                      : isSelected
                          ? AppColors.techBlue.withOpacity(0.12)
                          : Colors.grey.shade100,
                  backgroundImage:
                      picture != null && picture.isNotEmpty
                          ? NetworkImage(picture)
                          : null,
                  child: picture == null || picture.isEmpty
                      ? Text(
                          initials,
                          style: TextStyle(
                            color: isClockedIn
                                ? AppColors.success
                                : isSelected
                                    ? AppColors.techBlue
                                    : Colors.grey.shade600,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        )
                      : null,
                ),
                if (isClockedIn || isSelected)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: isClockedIn
                            ? AppColors.success
                            : AppColors.techBlue,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(Icons.check,
                          size: 9, color: Colors.white),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 13),

            // ── Name / role / clocked-in label ────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isClockedIn
                          ? Colors.grey.shade400
                          : AppColors.textDark,
                    ),
                  ),
                  if (role != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      role,
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade500),
                    ),
                  ],
                  if (isClockedIn) ...[
                    const SizedBox(height: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.success.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        l10n.alreadyClockedIn,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.success,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // ── Custom checkbox ───────────────────────────────────────
            if (!isClockedIn) ...[
              const SizedBox(width: 8),
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.techBlue : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.techBlue
                        : Colors.grey.shade300,
                    width: 1.5,
                  ),
                ),
                child: isSelected
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : null,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
