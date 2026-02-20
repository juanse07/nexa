import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nexa/features/extraction/services/users_service.dart';
import 'package:nexa/features/hours_approval/services/timesheet_extraction_service.dart';
import 'package:nexa/l10n/app_localizations.dart';

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
  final UsersService _usersService = UsersService();
  final TimesheetExtractionService _extractionService = TimesheetExtractionService();
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _searchResults = [];
  final Map<String, _StaffHoursInput> _selectedStaff = {};
  bool _isSearching = false;
  bool _isSubmitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadInitialUsers();
  }

  Future<void> _loadInitialUsers() async {
    setState(() {
      _isSearching = true;
      _error = null;
    });

    try {
      final result = await _usersService.fetchUsers(limit: 20);
      final items = result['items'] as List?;
      if (items != null) {
        setState(() {
          _searchResults = items.cast<Map<String, dynamic>>();
          _isSearching = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = '${AppLocalizations.of(context)!.failedToLoadUsers}: $e';
        _isSearching = false;
      });
    }
  }

  Future<void> _searchUsers(String query) async {
    if (query.trim().isEmpty) {
      _loadInitialUsers();
      return;
    }

    setState(() {
      _isSearching = true;
      _error = null;
    });

    try {
      final result = await _usersService.fetchUsers(q: query, limit: 20);
      final items = result['items'] as List?;
      if (items != null) {
        setState(() {
          _searchResults = items.cast<Map<String, dynamic>>();
          _isSearching = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = '${AppLocalizations.of(context)!.failedToSearchUsers}: $e';
        _isSearching = false;
      });
    }
  }

  void _toggleStaffSelection(Map<String, dynamic> user) {
    setState(() {
      final userId = user['id']?.toString() ?? '';
      if (_selectedStaff.containsKey(userId)) {
        _selectedStaff.remove(userId);
      } else {
        final userKey = '${user['provider']}:${user['subject']}';
        final name = user['name']?.toString() ??
            '${user['first_name'] ?? ''} ${user['last_name'] ?? ''}'.trim();

        _selectedStaff[userId] = _StaffHoursInput(
          userId: userId,
          userKey: userKey,
          name: name,
          email: user['email']?.toString() ?? '',
          picture: user['picture']?.toString(),
        );
      }
    });
  }

  Future<void> _submitHours() async {
    // Validate all selected staff have sign-in and sign-out times
    final invalidStaff = _selectedStaff.values
        .where((s) => s.signInTime == null || s.signOutTime == null || s.hours <= 0)
        .toList();
    if (invalidStaff.isNotEmpty) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
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
      final eventId = widget.event['_id'] ?? widget.event['id'];

      // Convert to StaffHours format
      final staffHours = _selectedStaff.values.map((s) {
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
        submittedBy: 'Manager', // TODO: Get actual user
      );

      // Immediately approve the submitted hours
      if (result.processedCount > 0) {
        await _extractionService.bulkApproveHours(
          eventId: eventId.toString(),
          approvedBy: 'Manager', // TODO: Get actual user
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.processedCount > 0
                  ? AppLocalizations.of(context)!.hoursSubmittedAndApproved
                  : result.message,
            ),
            backgroundColor: result.processedCount > 0 ? Colors.green : Colors.orange,
          ),
        );

        if (result.processedCount > 0) {
          Navigator.of(context).pop(true); // Return true to indicate success
        } else {
          setState(() {
            _isSubmitting = false;
          });
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

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.manualHoursEntry),
        actions: [
          if (_selectedStaff.isNotEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Chip(
                  label: Text('${_selectedStaff.length} selected'),
                  backgroundColor: theme.colorScheme.primary,
                  labelStyle: const TextStyle(color: Colors.white),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: l10n.searchStaffByNameEmail,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _loadInitialUsers();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (value) {
                _searchUsers(value);
              },
            ),
          ),

          // Error message
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                _error!,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),

          // User list
          Expanded(
            child: _isSearching
                ? const Center(child: CircularProgressIndicator())
                : _searchResults.isEmpty
                    ? Center(child: Text(l10n.noUsersFound))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _searchResults.length,
                        itemBuilder: (context, index) {
                          final user = _searchResults[index];
                          final userId = user['id']?.toString() ?? '';
                          final isSelected = _selectedStaff.containsKey(userId);

                          return _buildUserCard(user, isSelected);
                        },
                      ),
          ),

          // Submit button
          if (_selectedStaff.isNotEmpty)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _isSubmitting ? null : _submitHours,
                    icon: const Icon(Icons.check_circle),
                    label: Text(l10n.submitHoursButton(_selectedStaff.length)),
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

  Widget _buildUserCard(Map<String, dynamic> user, bool isSelected) {
    final theme = Theme.of(context);
    final userId = user['id']?.toString() ?? '';
    final name = user['name']?.toString() ??
        '${user['first_name'] ?? ''} ${user['last_name'] ?? ''}'.trim();
    final email = user['email']?.toString() ?? '';
    final picture = user['picture']?.toString();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSelected
            ? BorderSide(color: theme.colorScheme.primary, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          if (isSelected) {
            // Show edit dialog
            _showHoursInputDialog(_selectedStaff[userId]!);
          } else {
            // Toggle selection
            _toggleStaffSelection(user);
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Checkbox
              Checkbox(
                value: isSelected,
                onChanged: (_) => _toggleStaffSelection(user),
              ),
              const SizedBox(width: 12),

              // Avatar
              CircleAvatar(
                radius: 24,
                backgroundImage: picture != null ? NetworkImage(picture) : null,
                child: picture == null && name.isNotEmpty
                    ? Text(name[0].toUpperCase())
                    : picture == null
                        ? const Text('?')
                        : null,
              ),
              const SizedBox(width: 12),

              // User info
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
                    const SizedBox(height: 4),
                    Text(
                      email,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),

              // Hours display
              if (isSelected && _selectedStaff[userId] != null) ...[
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${_selectedStaff[userId]!.hours.toStringAsFixed(1)} hrs',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    if (_selectedStaff[userId]!.role != null &&
                        _selectedStaff[userId]!.role!.isNotEmpty)
                      Text(
                        _selectedStaff[userId]!.role!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
                const Icon(Icons.edit, size: 20),
              ],
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

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          // Calculate hours whenever times change
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
                  // Sign-In Time Picker
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
                        setDialogState(() {
                          signInTime = time;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 8),

                  // Sign-Out Time Picker
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
                        setDialogState(() {
                          signOutTime = time;
                        });
                      }
                    },
                  ),

                  // Calculated Hours Display
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
    if (diffMinutes < 0) diffMinutes += 24 * 60; // Handle overnight shifts

    return diffMinutes / 60.0;
  }
}

class _StaffHoursInput {
  final String userId;
  final String userKey;
  final String name;
  final String email;
  final String? picture;
  double hours;
  String? role;
  String? signInTime;
  String? signOutTime;
  String? notes;

  _StaffHoursInput({
    required this.userId,
    required this.userKey,
    required this.name,
    required this.email,
    this.picture,
    this.hours = 0.0,
    this.role,
    this.signInTime,
    this.signOutTime,
    this.notes,
  });
}
