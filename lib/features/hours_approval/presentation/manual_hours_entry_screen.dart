import 'package:flutter/material.dart';
import 'package:nexa/features/hours_approval/services/timesheet_extraction_service.dart';
import 'package:nexa/l10n/app_localizations.dart';
import 'package:nexa/shared/presentation/theme/app_colors.dart';

class ManualHoursEntryScreen extends StatefulWidget {
  final Map<String, dynamic> event;

  const ManualHoursEntryScreen({
    super.key,
    required this.event,
  });

  @override
  State<ManualHoursEntryScreen> createState() => _ManualHoursEntryScreenState();
}

class _ManualHoursEntryScreenState extends State<ManualHoursEntryScreen> {
  final TimesheetExtractionService _extractionService = TimesheetExtractionService();
  final TextEditingController _filterController = TextEditingController();

  late List<Map<String, dynamic>> _allStaff;
  List<Map<String, dynamic>> _filteredStaff = [];
  final Map<String, _StaffHoursInput> _selectedStaff = {};
  bool _isSubmitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAcceptedStaff();
  }

  void _loadAcceptedStaff() {
    final accepted = widget.event['accepted_staff'] as List? ?? [];
    _allStaff = accepted.cast<Map<String, dynamic>>();

    // Pre-populate from existing digital attendance data
    for (final staff in _allStaff) {
      final userKey = staff['userKey']?.toString() ?? '';
      final name = staff['name']?.toString() ??
          '${staff['first_name'] ?? ''} ${staff['last_name'] ?? ''}'.trim();
      final role = staff['role']?.toString();
      final picture = staff['picture']?.toString();

      // Check for existing digital hours
      final attendance = staff['attendance'] as List?;
      String? signInTime;
      String? signOutTime;
      double hours = 0;

      if (attendance != null && attendance.isNotEmpty) {
        final lastSession = attendance.last as Map<String, dynamic>;
        final clockIn = _parseDateTime(lastSession['clockInAt']);
        final clockOut = _parseDateTime(lastSession['clockOutAt']);
        final est = (lastSession['estimatedHours'] as num?)?.toDouble();

        if (clockIn != null) signInTime = _formatTimeOfDay(TimeOfDay.fromDateTime(clockIn));
        if (clockOut != null) signOutTime = _formatTimeOfDay(TimeOfDay.fromDateTime(clockOut));
        if (est != null) hours = est;
      }

      _selectedStaff[userKey] = _StaffHoursInput(
        userKey: userKey,
        name: name,
        picture: picture,
        hours: hours,
        role: role,
        signInTime: signInTime,
        signOutTime: signOutTime,
      );
    }

    _filteredStaff = List.from(_allStaff);
  }

  DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    try {
      return DateTime.parse(value.toString());
    } catch (_) {
      return null;
    }
  }

  void _filterStaff(String query) {
    setState(() {
      if (query.trim().isEmpty) {
        _filteredStaff = List.from(_allStaff);
      } else {
        final q = query.toLowerCase();
        _filteredStaff = _allStaff.where((staff) {
          final name = (staff['name']?.toString() ??
              '${staff['first_name'] ?? ''} ${staff['last_name'] ?? ''}'.trim())
              .toLowerCase();
          final role = (staff['role']?.toString() ?? '').toLowerCase();
          return name.contains(q) || role.contains(q);
        }).toList();
      }
    });
  }

  Future<void> _submitHours() async {
    // Filter staff with valid hours
    final validEntries = _selectedStaff.values
        .where((s) => s.signInTime != null && s.signOutTime != null && s.hours > 0)
        .toList();

    if (validEntries.isEmpty) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context)..clearSnackBars()..showSnackBar(
        SnackBar(
          content: Text(l10n.pleaseEnterTimesForAllStaff),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      final l10n = AppLocalizations.of(context)!;
      final eventId = widget.event['_id'] ?? widget.event['id'];

      final staffHours = validEntries.map((s) {
        return StaffHours(
          name: s.name,
          role: s.role ?? '',
          signInTime: s.signInTime,
          signOutTime: s.signOutTime,
          approvedHours: s.hours,
          notes: s.notes,
        );
      }).toList();

      final result = await _extractionService.submitHours(
        eventId: eventId.toString(),
        staffHours: staffHours,
        sheetPhotoUrl: 'manual_entry',
        submittedBy: 'Manager',
      );

      if (result.processedCount > 0) {
        await _extractionService.bulkApproveHours(
          eventId: eventId.toString(),
          approvedBy: 'Manager',
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context)..clearSnackBars()..showSnackBar(
          SnackBar(
            content: Text(
              result.processedCount > 0
                  ? l10n.hoursSubmittedAndApproved
                  : result.message,
            ),
            backgroundColor: result.processedCount > 0 ? Colors.green : Colors.orange,
          ),
        );

        if (result.processedCount > 0) {
          Navigator.of(context).pop(true);
        } else {
          setState(() => _isSubmitting = false);
        }
      }
    } catch (e) {
      setState(() {
        _error = '${AppLocalizations.of(context)!.failedToSubmitHours}: $e';
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final entriesWithHours = _selectedStaff.values
        .where((s) => s.signInTime != null && s.signOutTime != null && s.hours > 0)
        .length;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.manualHoursEntry),
        actions: [
          if (entriesWithHours > 0)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Chip(
                  label: Text('$entriesWithHours with hours'),
                  backgroundColor: theme.colorScheme.primary,
                  labelStyle: const TextStyle(color: Colors.white),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Filter bar (local filter, not API search)
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _filterController,
              decoration: InputDecoration(
                hintText: l10n.searchStaffByNameEmail,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _filterController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _filterController.clear();
                          _filterStaff('');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: _filterStaff,
            ),
          ),

          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                _error!,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),

          // Staff list
          Expanded(
            child: _filteredStaff.isEmpty
                ? Center(child: Text(l10n.noUsersFound))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _filteredStaff.length,
                    itemBuilder: (context, index) {
                      final staff = _filteredStaff[index];
                      final userKey = staff['userKey']?.toString() ?? '';
                      final input = _selectedStaff[userKey];
                      return _buildStaffCard(staff, input);
                    },
                  ),
          ),

          // Submit button
          if (entriesWithHours > 0)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _isSubmitting ? null : _submitHours,
                    icon: const Icon(Icons.check_circle),
                    label: Text(l10n.submitHoursButton(entriesWithHours)),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStaffCard(Map<String, dynamic> staff, _StaffHoursInput? input) {
    final theme = Theme.of(context);
    final name = staff['name']?.toString() ??
        '${staff['first_name'] ?? ''} ${staff['last_name'] ?? ''}'.trim();
    final role = staff['role']?.toString() ?? '';
    final picture = staff['picture']?.toString();
    final hasHours = input != null && input.hours > 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: hasHours
            ? BorderSide(color: AppColors.success, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          if (input != null) {
            _showHoursInputDialog(input);
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundImage: picture != null ? NetworkImage(picture) : null,
                backgroundColor: AppColors.surfaceGray,
                child: picture == null && name.isNotEmpty
                    ? Text(name[0].toUpperCase())
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (role.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        role,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                    if (hasHours && input?.signInTime != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        '${input.signInTime} — ${input.signOutTime}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (hasHours) ...[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${input?.hours.toStringAsFixed(1)} hrs',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 4),
                const Icon(Icons.edit, size: 20, color: AppColors.textMuted),
              ] else
                Icon(Icons.add_circle_outline, color: AppColors.info),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showHoursInputDialog(_StaffHoursInput staffInput) async {
    final l10n = AppLocalizations.of(context)!;
    final roleController = TextEditingController(text: staffInput.role ?? '');
    final notesController = TextEditingController(text: staffInput.notes ?? '');

    TimeOfDay? signInTime = staffInput.signInTime != null
        ? _parseTimeOfDay(staffInput.signInTime!)
        : null;
    TimeOfDay? signOutTime = staffInput.signOutTime != null
        ? _parseTimeOfDay(staffInput.signOutTime!)
        : null;

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          double calculatedHours = 0.0;
          if (signInTime != null && signOutTime != null) {
            calculatedHours = _calculateHours(signInTime!, signOutTime!);
          }

          return AlertDialog(
            title: Text(l10n.hoursForStaff(staffInput.name)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(Icons.login),
                    title: Text(l10n.signInTimeRequired),
                    subtitle: Text(
                      signInTime != null
                          ? _formatTimeOfDay(signInTime!)
                          : l10n.notSet,
                    ),
                    trailing: const Icon(Icons.access_time),
                    onTap: () async {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: signInTime ?? TimeOfDay.now(),
                      );
                      if (time != null) {
                        setDialogState(() => signInTime = time);
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    leading: const Icon(Icons.logout),
                    title: Text(l10n.signOutTimeRequired),
                    subtitle: Text(
                      signOutTime != null
                          ? _formatTimeOfDay(signOutTime!)
                          : l10n.notSet,
                    ),
                    trailing: const Icon(Icons.access_time),
                    onTap: () async {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: signOutTime ?? TimeOfDay.now(),
                      );
                      if (time != null) {
                        setDialogState(() => signOutTime = time);
                      }
                    },
                  ),
                  if (signInTime != null && signOutTime != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Card(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.schedule, color: Colors.white),
                              const SizedBox(width: 8),
                              Text(
                                l10n.totalHoursFormat(calculatedHours.toStringAsFixed(2)),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w300,
                                  fontSize: 16,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: roleController,
                    decoration: InputDecoration(
                      labelText: l10n.roleHint,
                      hintText: l10n.bartenderHint,
                      prefixIcon: const Icon(Icons.badge),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: notesController,
                    decoration: InputDecoration(
                      labelText: l10n.notesLabel,
                      hintText: l10n.optionalNotes,
                      prefixIcon: const Icon(Icons.note),
                    ),
                    maxLines: 3,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: () {
                  setState(() {
                    staffInput.signInTime = signInTime != null
                        ? _formatTimeOfDay(signInTime!)
                        : null;
                    staffInput.signOutTime = signOutTime != null
                        ? _formatTimeOfDay(signOutTime!)
                        : null;
                    staffInput.hours = calculatedHours;
                    staffInput.role = roleController.text.isNotEmpty
                        ? roleController.text
                        : null;
                    staffInput.notes = notesController.text.isNotEmpty
                        ? notesController.text
                        : null;
                  });
                  Navigator.pop(context);
                },
                child: Text(l10n.save),
              ),
            ],
          );
        },
      ),
    );
  }

  TimeOfDay? _parseTimeOfDay(String timeStr) {
    try {
      final regex = RegExp(r'(\d{1,2}):(\d{2})\s*(AM|PM)', caseSensitive: false);
      final match = regex.firstMatch(timeStr);
      if (match == null) return null;

      var hour = int.parse(match.group(1)!);
      final minute = int.parse(match.group(2)!);
      final period = match.group(3)!.toUpperCase();

      if (period == 'PM' && hour != 12) hour += 12;
      if (period == 'AM' && hour == 12) hour = 0;

      return TimeOfDay(hour: hour, minute: minute);
    } catch (e) {
      return null;
    }
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  double _calculateHours(TimeOfDay signIn, TimeOfDay signOut) {
    final signInMinutes = signIn.hour * 60 + signIn.minute;
    final signOutMinutes = signOut.hour * 60 + signOut.minute;

    var diffMinutes = signOutMinutes - signInMinutes;
    if (diffMinutes < 0) diffMinutes += 24 * 60;

    return diffMinutes / 60.0;
  }
}

class _StaffHoursInput {
  final String userKey;
  final String name;
  final String? picture;
  double hours;
  String? role;
  String? signInTime;
  String? signOutTime;
  String? notes;

  _StaffHoursInput({
    required this.userKey,
    required this.name,
    this.picture,
    this.hours = 0.0,
    this.role,
    this.signInTime,
    this.signOutTime,
    this.notes,
  });
}
