import 'package:flutter/material.dart';
import 'package:nexa/shared/services/error_display_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:nexa/shared/widgets/initials_avatar.dart';
import 'package:nexa/shared/constants/skill_cert_catalogs.dart';
import '../services/staff_service.dart';
import '../services/group_service.dart';
import '../../chat/presentation/chat_screen.dart';
import '../../users/presentation/pages/user_events_screen.dart';
import 'theme/extraction_theme.dart';

class StaffDetailScreen extends StatefulWidget {
  final Map<String, dynamic> staff;

  const StaffDetailScreen({super.key, required this.staff});

  @override
  State<StaffDetailScreen> createState() => _StaffDetailScreenState();
}

class _StaffDetailScreenState extends State<StaffDetailScreen>
    with SingleTickerProviderStateMixin {
  TabController? _tabController;
  final StaffService _staffService = StaffService();
  final GroupService _groupService = GroupService();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _externalIdController = TextEditingController();

  Map<String, dynamic>? _hours;
  Map<String, dynamic>? _detail;
  List<Map<String, dynamic>> _allGroups = [];
  List<Map<String, dynamic>> _venueHistory = [];
  bool _isLoadingHours = false;
  bool _isLoadingDetail = false;
  bool _isLoadingVenues = false;
  bool _isSaving = false;
  bool _isSavingPayroll = false;
  bool _isSavingSkills = false;
  late bool _isFavorite;
  late double _rating;
  String _workerType = 'w2';

  String get _userKey => widget.staff['userKey'] as String? ?? '';
  String get _name =>
      widget.staff['name'] as String? ??
      '${widget.staff['first_name'] ?? ''} ${widget.staff['last_name'] ?? ''}'.trim();
  String? get _email => widget.staff['email'] as String?;
  String? get _phone => widget.staff['phone_number'] as String?;
  String? get _picture => widget.staff['picture'] as String?;
  List<dynamic> get _roles =>
      (_detail?['roles'] as List<dynamic>?) ??
      (widget.staff['roles'] as List<dynamic>?) ??
      [];
  List<dynamic> get _recentShifts =>
      (_detail?['recentShifts'] as List<dynamic>?) ?? [];
  List<dynamic> get _groups =>
      (_detail?['groups'] as List<dynamic>?) ?? [];

  void _ensureTabController() {
    if (_tabController == null) {
      _tabController = TabController(length: 3, vsync: this);
      _tabController!.addListener(() => setState(() {}));
    }
  }

  @override
  void initState() {
    super.initState();
    _ensureTabController();
    _isFavorite = widget.staff['isFavorite'] == true;
    _rating = (widget.staff['rating'] as num?)?.toDouble() ?? 0;
    _notesController.text = widget.staff['notes'] as String? ?? '';
    _loadData();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    _notesController.dispose();
    _externalIdController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoadingHours = true;
      _isLoadingDetail = true;
    });

    try {
      final groups = await _groupService.fetchGroups();
      if (mounted) setState(() => _allGroups = groups);
    } catch (_) {}

    try {
      final hours = await _staffService.fetchStaffHours(_userKey);
      if (mounted) setState(() { _hours = hours; _isLoadingHours = false; });
    } catch (_) {
      if (mounted) setState(() => _isLoadingHours = false);
    }

    try {
      final detail = await _staffService.fetchStaffDetail(_userKey);
      if (mounted) {
        setState(() {
          _detail = detail;
          _isLoadingDetail = false;
          // Update from server data
          _notesController.text = detail['notes'] as String? ?? _notesController.text;
          _rating = (detail['rating'] as num?)?.toDouble() ?? _rating;
          _isFavorite = detail['isFavorite'] == true;
          // Payroll fields
          _externalIdController.text = detail['externalEmployeeId'] as String? ?? '';
          _workerType = detail['workerType'] as String? ?? 'w2';
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingDetail = false);
    }

    // Load venue history
    try {
      setState(() => _isLoadingVenues = true);
      final venueData = await _staffService.fetchVenueHistory(_userKey);
      if (mounted) {
        setState(() {
          _venueHistory = (venueData['venues'] as List<dynamic>? ?? [])
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          _isLoadingVenues = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingVenues = false);
    }
  }

  Future<void> _toggleFavorite() async {
    final newValue = !_isFavorite;
    setState(() => _isFavorite = newValue);
    try {
      await _staffService.updateStaffProfile(_userKey, isFavorite: newValue);
    } catch (_) {
      if (mounted) setState(() => _isFavorite = !newValue);
    }
  }

  Future<void> _saveNotes() async {
    setState(() => _isSaving = true);
    try {
      await _staffService.updateStaffProfile(
        _userKey,
        notes: _notesController.text,
        rating: _rating,
      );
      if (mounted) {
        ScaffoldMessenger.of(context)..clearSnackBars()..showSnackBar(
          const SnackBar(
            content: Text('Profile updated'),
            backgroundColor: ExColors.successDark,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)..clearSnackBars()..showSnackBar(
          SnackBar(
            content: Text('Error saving: $e'),
            backgroundColor: ExColors.errorDark,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _onRatingChanged(double newRating) async {
    setState(() => _rating = newRating);
    try {
      await _staffService.updateStaffProfile(_userKey, rating: newRating);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ExColors.backgroundLight,
      appBar: AppBar(
        title: Text(_name.isEmpty ? 'Staff Detail' : _name),
        backgroundColor: Colors.white,
        foregroundColor: ExColors.textPrimary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isFavorite ? Icons.star : Icons.star_border,
              color: _isFavorite ? Colors.amber : Colors.grey,
            ),
            onPressed: _toggleFavorite,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProfileHeader(),
            const SizedBox(height: 16),
            _buildQuickActions(),
            const SizedBox(height: 16),
            _buildStaffInfoTabs(),
            const SizedBox(height: 16),
            _buildHoursSummary(),
            const SizedBox(height: 16),
            _buildRecentShifts(),
            const SizedBox(height: 16),
            _buildVenueHistorySection(),
            const SizedBox(height: 16),
            _buildRatingSection(),
            const SizedBox(height: 16),
            _buildPayrollSection(),
            const SizedBox(height: 16),
            _buildNotesSection(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          UserAvatar(
            imageUrl: _picture,
            fullName: _name,
            email: _email,
            radius: 40,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _name.isEmpty ? 'Unknown' : _name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: ExColors.textPrimary,
                  ),
                ),
                if (_email != null && _email!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    _email!,
                    style: const TextStyle(
                      fontSize: 14,
                      color: ExColors.textSecondary,
                    ),
                  ),
                ],
                if (_phone != null && _phone!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    _phone!,
                    style: const TextStyle(
                      fontSize: 14,
                      color: ExColors.textSecondary,
                    ),
                  ),
                ],
                if (_roles.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: _roles.map((role) => _buildRoleChip(role.toString())).toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleChip(String role) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: ExColors.techBlue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        role,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: ExColors.techBlue,
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Row(
      children: [
        Expanded(
          child: _buildActionButton(
            icon: Icons.message_outlined,
            label: 'Message',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ChatScreen(
                    targetId: _userKey,
                    targetName: _name,
                    targetPicture: _picture,
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildActionButton(
            icon: Icons.phone_outlined,
            label: 'Call',
            onTap: _phone != null && _phone!.isNotEmpty
                ? () => launchUrl(Uri.parse('tel:$_phone'))
                : null,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildActionButton(
            icon: Icons.email_outlined,
            label: 'Email',
            onTap: _email != null && _email!.isNotEmpty
                ? () => launchUrl(Uri.parse('mailto:$_email'))
                : null,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildActionButton(
            icon: Icons.event_note_outlined,
            label: 'Events',
            onTap: _userKey.isNotEmpty ? _openUserEvents : null,
          ),
        ),
      ],
    );
  }

  void _openUserEvents() {
    // UserEventsScreen expects user['provider'] and user['subject']
    final parts = _userKey.split(':');
    final userMap = <String, dynamic>{
      'provider': parts.isNotEmpty ? parts[0] : '',
      'subject': parts.length > 1 ? parts.sublist(1).join(':') : '',
      'name': _name,
      'first_name': widget.staff['first_name'],
      'last_name': widget.staff['last_name'],
      'email': _email,
      'picture': _picture,
    };
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => UserEventsScreen(user: userMap)),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    VoidCallback? onTap,
  }) {
    final isEnabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isEnabled ? ExColors.techBlue.withOpacity(0.3) : Colors.grey.shade200,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: isEnabled ? ExColors.techBlue : Colors.grey.shade400, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isEnabled ? ExColors.techBlue : Colors.grey.shade400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Tabbed Staff Info Card ──────────────────────────────────────────
  Widget _buildStaffInfoTabs() {
    _ensureTabController();
    final tc = _tabController!;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TabBar(
            controller: tc,
            isScrollable: false,
            labelColor: ExColors.techBlue,
            unselectedLabelColor: Colors.grey.shade500,
            indicatorColor: ExColors.techBlue,
            indicatorSize: TabBarIndicatorSize.tab,
            labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            unselectedLabelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            labelPadding: const EdgeInsets.symmetric(horizontal: 4),
            dividerHeight: 0,
            tabs: const [
              Tab(text: 'Groups'),
              Tab(text: 'Skills'),
              Tab(text: 'Certs'),
            ],
          ),
          Divider(height: 1, color: Colors.grey.shade200),
          Padding(
            padding: const EdgeInsets.all(16),
            child: _buildTabContent(tc.index),
          ),
        ],
      ),
    );
  }

  Widget _buildTabContent(int index) {
    switch (index) {
      case 0:
        return _buildGroupsTabContent();
      case 1:
        return _buildSkillsTabContent();
      case 2:
        return _buildCertsTabContent();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildGroupsTabContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Spacer(),
            GestureDetector(
              onTap: _showAddToGroupDialog,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: ExColors.techBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.add, size: 20, color: ExColors.techBlue),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_groups.isEmpty)
          Text('Not in any groups', style: TextStyle(fontSize: 14, color: Colors.grey.shade500))
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _groups.map((group) {
              final groupId = (group['_id'] ?? '').toString();
              final name = (group['name'] ?? '').toString();
              final colorHex = group['color'] as String?;
              final chipColor = _parseColor(colorHex) ?? ExColors.techBlue;
              return Chip(
                label: Text(name, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: chipColor)),
                backgroundColor: chipColor.withOpacity(0.1),
                deleteIcon: Icon(Icons.close, size: 16, color: chipColor),
                onDeleted: () => _removeFromGroup(groupId),
                side: BorderSide.none,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildSkillsTabContent() {
    final unconfirmed = _selfReportedSkills
        .where((s) => !_skills.any((ms) => ms.toLowerCase() == s.toLowerCase()))
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Spacer(),
            if (_isSavingSkills)
              const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
            else
              GestureDetector(
                onTap: _showSkillPicker,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: ExColors.techBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.add, size: 20, color: ExColors.techBlue),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (_skills.isEmpty && unconfirmed.isEmpty)
          Text('No skills added yet', style: TextStyle(fontSize: 14, color: Colors.grey.shade500))
        else ...[
          if (_skills.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _skills.map((skill) => Chip(
                label: Text(_titleCase(skill), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: ExColors.techBlue)),
                backgroundColor: ExColors.techBlue.withOpacity(0.1),
                deleteIcon: const Icon(Icons.close, size: 16, color: ExColors.techBlue),
                onDeleted: () => _removeSkill(skill),
                side: BorderSide.none,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              )).toList(),
            ),
          if (unconfirmed.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Self-reported', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey.shade600)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: unconfirmed.map((skill) => ActionChip(
                label: Text(_titleCase(skill), style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                avatar: const Icon(Icons.check_circle_outline, size: 16, color: ExColors.successDark),
                backgroundColor: Colors.grey.shade100,
                side: BorderSide(color: Colors.grey.shade300),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onPressed: () => _confirmSkill(skill),
              )).toList(),
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildCertsTabContent() {
    final unverified = _selfReportedCerts.where((sc) =>
      !_certifications.any((mc) =>
        (mc['name'] as String?)?.toLowerCase() == (sc['name'] as String?)?.toLowerCase()
      )
    ).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Spacer(),
            GestureDetector(
              onTap: _showCertPicker,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: ExColors.techBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.add, size: 20, color: ExColors.techBlue),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_certifications.isEmpty && unverified.isEmpty)
          Text('No certifications', style: TextStyle(fontSize: 14, color: Colors.grey.shade500))
        else ...[
          ..._certifications.map((cert) => _buildCertCard(cert, verified: true)),
          if (unverified.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Self-reported', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey.shade600)),
            const SizedBox(height: 6),
            ...unverified.map((cert) => _buildCertCard(cert, verified: false)),
          ],
        ],
      ],
    );
  }

  Widget _buildGroupsSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Groups',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: ExColors.textPrimary,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _showAddToGroupDialog,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: ExColors.techBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.add, size: 20, color: ExColors.techBlue),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_groups.isEmpty)
            Text(
              'Not in any groups',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _groups.map((group) {
                final groupId = (group['_id'] ?? '').toString();
                final name = (group['name'] ?? '').toString();
                final colorHex = group['color'] as String?;
                final chipColor = _parseColor(colorHex) ?? ExColors.techBlue;

                return Chip(
                  label: Text(
                    name,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: chipColor,
                    ),
                  ),
                  backgroundColor: chipColor.withOpacity(0.1),
                  deleteIcon: Icon(Icons.close, size: 16, color: chipColor),
                  onDeleted: () => _removeFromGroup(groupId),
                  side: BorderSide.none,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Color? _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    try {
      final cleaned = hex.replaceFirst('#', '');
      return Color(int.parse('FF$cleaned', radix: 16));
    } catch (_) {
      return null;
    }
  }

  Future<void> _removeFromGroup(String groupId) async {
    try {
      await _groupService.removeMember(groupId, _userKey);
      // Reload detail to refresh groups
      final detail = await _staffService.fetchStaffDetail(_userKey);
      if (mounted) setState(() => _detail = detail);
    } catch (e) {
      if (mounted) {
        ErrorDisplayService.showErrorFromException(context, e);
      }
    }
  }

  Future<void> _showAddToGroupDialog() async {
    // Current group IDs this staff is in
    final currentGroupIds = _groups.map((g) => (g['_id'] ?? '').toString()).toSet();
    final selected = Set<String>.from(currentGroupIds);
    final newGroupController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Text('Manage Groups'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_allGroups.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          'No groups yet. Create one below.',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      )
                    else
                      ...(_allGroups).map((group) {
                        final gid = (group['id'] ?? '').toString();
                        final name = (group['name'] ?? '').toString();
                        final isChecked = selected.contains(gid);
                        return CheckboxListTile(
                          title: Text(name),
                          value: isChecked,
                          dense: true,
                          onChanged: (val) {
                            setDialogState(() {
                              if (val == true) {
                                selected.add(gid);
                              } else {
                                selected.remove(gid);
                              }
                            });
                          },
                        );
                      }),
                    const Divider(),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: newGroupController,
                            decoration: const InputDecoration(
                              hintText: 'New group name...',
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () async {
                            final name = newGroupController.text.trim();
                            if (name.isEmpty) return;
                            try {
                              final created = await _groupService.createGroup(name);
                              final newId = (created['id'] ?? '').toString();
                              newGroupController.clear();
                              // Refresh groups list
                              final groups = await _groupService.fetchGroups();
                              setDialogState(() {
                                _allGroups = groups;
                                selected.add(newId);
                              });
                            } catch (e) {
                              if (mounted) {
                                ErrorDisplayService.showErrorFromException(context, e);
                              }
                            }
                          },
                          child: const Text('Create'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    await _applyGroupChanges(currentGroupIds, selected);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ExColors.techBlue,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _applyGroupChanges(Set<String> oldIds, Set<String> newIds) async {
    // Groups to add this user to
    final toAdd = newIds.difference(oldIds);
    // Groups to remove this user from
    final toRemove = oldIds.difference(newIds);

    try {
      for (final gid in toAdd) {
        await _groupService.addMembers(gid, [_userKey]);
      }
      for (final gid in toRemove) {
        await _groupService.removeMember(gid, _userKey);
      }
      // Reload detail to refresh groups
      final detail = await _staffService.fetchStaffDetail(_userKey);
      if (mounted) setState(() => _detail = detail);
    } catch (e) {
      if (mounted) {
        ErrorDisplayService.showErrorFromException(context, e, prefix: 'Error updating groups');
      }
    }
  }

  // ─── Skills Section ─────────────────────────────────────────────────────
  List<String> get _skills =>
      List<String>.from((_detail?['skills'] as List<dynamic>?) ?? []);
  List<String> get _selfReportedSkills =>
      List<String>.from((_detail?['selfReportedSkills'] as List<dynamic>?) ?? []);

  Widget _buildSkillsSection() {
    // Self-reported skills not yet confirmed by manager
    final unconfirmed = _selfReportedSkills
        .where((s) => !_skills.any((ms) => ms.toLowerCase() == s.toLowerCase()))
        .toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.psychology_outlined, size: 18, color: ExColors.techBlue),
              const SizedBox(width: 8),
              const Text(
                'Skills',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: ExColors.textPrimary,
                ),
              ),
              const Spacer(),
              if (_isSavingSkills)
                const SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                GestureDetector(
                  onTap: _showSkillPicker,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: ExColors.techBlue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.add, size: 20, color: ExColors.techBlue),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (_skills.isEmpty && unconfirmed.isEmpty)
            Text(
              'No skills added yet',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
            )
          else ...[
            // Manager-confirmed skills
            if (_skills.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _skills.map((skill) => Chip(
                  label: Text(
                    _titleCase(skill),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: ExColors.techBlue),
                  ),
                  backgroundColor: ExColors.techBlue.withOpacity(0.1),
                  deleteIcon: const Icon(Icons.close, size: 16, color: ExColors.techBlue),
                  onDeleted: () => _removeSkill(skill),
                  side: BorderSide.none,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                )).toList(),
              ),
            // Self-reported (unconfirmed) skills
            if (unconfirmed.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Self-reported',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: unconfirmed.map((skill) => ActionChip(
                  label: Text(
                    _titleCase(skill),
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                  avatar: const Icon(Icons.check_circle_outline, size: 16, color: ExColors.successDark),
                  backgroundColor: Colors.grey.shade100,
                  side: BorderSide(color: Colors.grey.shade300),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  onPressed: () => _confirmSkill(skill),
                )).toList(),
              ),
            ],
          ],
        ],
      ),
    );
  }

  // Using shared catalogs from skill_cert_catalogs.dart
  static final _skillCategories = skillCategories;

  Future<void> _showSkillPicker() async {
    final existing = _skills.map((s) => s.toLowerCase()).toSet();
    final selected = <String>{};

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        var searchQuery = '';
        var activeCategory = 'All';

        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final entries = <MapEntry<String, List<String>>>[];
            for (final cat in _skillCategories.entries) {
              final filtered = cat.value.$2.where((s) {
                if (activeCategory != 'All' && cat.key != activeCategory) return false;
                if (searchQuery.isNotEmpty) return s.toLowerCase().contains(searchQuery.toLowerCase());
                return true;
              }).toList();
              if (filtered.isNotEmpty) entries.add(MapEntry(cat.key, filtered));
            }

            return Container(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.85),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 40, height: 4,
                    decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
                    child: Row(
                      children: [
                        const Text('Add Skills', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: ExColors.textPrimary)),
                        const Spacer(),
                        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Search skills...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        filled: true, fillColor: Colors.grey.shade50,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                      ),
                      onChanged: (v) => setSheetState(() => searchQuery = v),
                    ),
                  ),
                  SizedBox(
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: const Text('All'),
                            selected: activeCategory == 'All',
                            selectedColor: ExColors.techBlue.withOpacity(0.15),
                            onSelected: (_) => setSheetState(() => activeCategory = 'All'),
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                        ..._skillCategories.entries.map((cat) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            avatar: Icon(cat.value.$1, size: 16),
                            label: Text(cat.key),
                            selected: activeCategory == cat.key,
                            selectedColor: ExColors.techBlue.withOpacity(0.15),
                            onSelected: (_) => setSheetState(() => activeCategory = cat.key),
                            visualDensity: VisualDensity.compact,
                          ),
                        )),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Flexible(
                    child: entries.isEmpty
                      ? Center(child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text('No skills match "$searchQuery"', style: TextStyle(color: Colors.grey.shade500)),
                        ))
                      : ListView(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          children: entries.expand((entry) => [
                            Padding(
                              padding: const EdgeInsets.only(top: 8, bottom: 6),
                              child: Text(entry.key, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade600)),
                            ),
                            Wrap(
                              spacing: 8, runSpacing: 8,
                              children: entry.value.map((skill) {
                                final isExisting = existing.contains(skill.toLowerCase());
                                final isSelected = selected.contains(skill.toLowerCase());
                                return FilterChip(
                                  label: Text(skill, style: TextStyle(fontSize: 13, color: isExisting ? Colors.grey : null)),
                                  selected: isExisting || isSelected,
                                  selectedColor: isExisting ? Colors.grey.shade200 : ExColors.techBlue.withOpacity(0.15),
                                  checkmarkColor: isExisting ? Colors.grey : ExColors.techBlue,
                                  onSelected: isExisting ? null : (val) => setSheetState(() {
                                    val ? selected.add(skill.toLowerCase()) : selected.remove(skill.toLowerCase());
                                  }),
                                  visualDensity: VisualDensity.compact,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  side: BorderSide(color: isExisting ? Colors.grey.shade300 : Colors.grey.shade200),
                                );
                              }).toList(),
                            ),
                          ]).toList(),
                        ),
                  ),
                  Container(
                    padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.of(ctx).viewInsets.bottom + MediaQuery.of(ctx).padding.bottom + 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border(top: BorderSide(color: Colors.grey.shade200)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                textCapitalization: TextCapitalization.words,
                                decoration: InputDecoration(
                                  hintText: 'Enter custom skill...',
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)),
                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)),
                                  isDense: true,
                                ),
                                onSubmitted: (v) {
                                  final trimmed = v.trim();
                                  if (trimmed.isNotEmpty && !existing.contains(trimmed.toLowerCase()) && !selected.contains(trimmed.toLowerCase())) {
                                    setSheetState(() => selected.add(trimmed.toLowerCase()));
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(ctx),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: ExColors.techBlue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text(selected.isEmpty ? 'Cancel' : 'Done (${selected.length} selected)'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (selected.isNotEmpty) {
      final updated = [..._skills, ...selected];
      await _saveSkills(updated);
    }
  }

  Future<void> _addSkill(String skill) async {
    final updated = [..._skills, skill.toLowerCase()];
    await _saveSkills(updated);
  }

  Future<void> _removeSkill(String skill) async {
    final updated = _skills.where((s) => s != skill).toList();
    await _saveSkills(updated);
  }

  Future<void> _confirmSkill(String skill) async {
    final updated = [..._skills, skill.toLowerCase()];
    await _saveSkills(updated);
  }

  Future<void> _saveSkills(List<String> skills) async {
    setState(() => _isSavingSkills = true);
    try {
      await _staffService.updateStaffProfile(_userKey, skills: skills);
      final detail = await _staffService.fetchStaffDetail(_userKey);
      if (mounted) setState(() => _detail = detail);
    } catch (e) {
      if (mounted) {
        ErrorDisplayService.showErrorFromException(context, e, prefix: 'Error saving skills');
      }
    } finally {
      if (mounted) setState(() => _isSavingSkills = false);
    }
  }

  // ─── Certifications Section ────────────────────────────────────────────
  List<Map<String, dynamic>> get _certifications =>
      List<Map<String, dynamic>>.from((_detail?['certifications'] as List<dynamic>?) ?? []);
  List<Map<String, dynamic>> get _selfReportedCerts =>
      List<Map<String, dynamic>>.from((_detail?['selfReportedCertifications'] as List<dynamic>?) ?? []);

  Widget _buildCertificationsSection() {
    final unverified = _selfReportedCerts.where((sc) =>
      !_certifications.any((mc) =>
        (mc['name'] as String?)?.toLowerCase() == (sc['name'] as String?)?.toLowerCase()
      )
    ).toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.verified_outlined, size: 18, color: ExColors.techBlue),
              const SizedBox(width: 8),
              const Text(
                'Certifications',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: ExColors.textPrimary),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _showCertPicker,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: ExColors.techBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.add, size: 20, color: ExColors.techBlue),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_certifications.isEmpty && unverified.isEmpty)
            Text('No certifications', style: TextStyle(fontSize: 14, color: Colors.grey.shade500))
          else ...[
            ..._certifications.map((cert) => _buildCertCard(cert, verified: true)),
            if (unverified.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Self-reported', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey.shade600)),
              const SizedBox(height: 6),
              ...unverified.map((cert) => _buildCertCard(cert, verified: false)),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildCertCard(Map<String, dynamic> cert, {required bool verified}) {
    final name = cert['name']?.toString() ?? '';
    final expiryStr = cert['expiryDate']?.toString();
    final expiry = expiryStr != null ? DateTime.tryParse(expiryStr) : null;
    final now = DateTime.now();

    Color statusColor = ExColors.successDark;
    String statusText = 'Valid';
    if (expiry != null) {
      if (expiry.isBefore(now)) {
        statusColor = Colors.red.shade700;
        statusText = 'Expired';
      } else if (expiry.isBefore(now.add(const Duration(days: 30)))) {
        statusColor = Colors.orange.shade700;
        statusText = 'Expiring soon';
      }
    } else {
      statusText = 'No expiry';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            verified ? Icons.verified : Icons.pending_outlined,
            size: 18,
            color: verified ? ExColors.successDark : Colors.grey,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                if (expiry != null)
                  Text(
                    '${expiry.month}/${expiry.day}/${expiry.year}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(statusText, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: statusColor)),
          ),
          if (!verified) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _verifyCertification(cert),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: ExColors.successDark.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.check, size: 16, color: ExColors.successDark),
              ),
            ),
          ] else ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _removeCertification(name),
              child: Icon(Icons.close, size: 16, color: Colors.grey.shade400),
            ),
          ],
        ],
      ),
    );
  }

  // Using shared catalogs from skill_cert_catalogs.dart
  static final _certCategories = certCategories;

  Future<void> _showCertPicker() async {
    final existingNames = _certifications.map((c) => (c['name'] as String?)?.toLowerCase() ?? '').toSet();
    final newCerts = <Map<String, dynamic>>[];

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        var searchQuery = '';
        var activeCategory = 'All';
        final selectedNames = <String>{};
        final expiryDates = <String, DateTime?>{};

        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final entries = <MapEntry<String, List<String>>>[];
            for (final cat in _certCategories.entries) {
              final filtered = cat.value.$2.where((c) {
                if (activeCategory != 'All' && cat.key != activeCategory) return false;
                if (searchQuery.isNotEmpty) return c.toLowerCase().contains(searchQuery.toLowerCase());
                return true;
              }).toList();
              if (filtered.isNotEmpty) entries.add(MapEntry(cat.key, filtered));
            }

            return Container(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.85),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 40, height: 4,
                    decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
                    child: Row(
                      children: [
                        const Text('Add Certification', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: ExColors.textPrimary)),
                        const Spacer(),
                        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Search certifications...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        filled: true, fillColor: Colors.grey.shade50,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                      ),
                      onChanged: (v) => setSheetState(() => searchQuery = v),
                    ),
                  ),
                  SizedBox(
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: const Text('All'),
                            selected: activeCategory == 'All',
                            selectedColor: ExColors.techBlue.withOpacity(0.15),
                            onSelected: (_) => setSheetState(() => activeCategory = 'All'),
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                        ..._certCategories.entries.map((cat) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            avatar: Icon(cat.value.$1, size: 16),
                            label: Text(cat.key),
                            selected: activeCategory == cat.key,
                            selectedColor: ExColors.techBlue.withOpacity(0.15),
                            onSelected: (_) => setSheetState(() => activeCategory = cat.key),
                            visualDensity: VisualDensity.compact,
                          ),
                        )),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Flexible(
                    child: entries.isEmpty
                      ? Center(child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text('No certifications match "$searchQuery"', style: TextStyle(color: Colors.grey.shade500)),
                        ))
                      : ListView(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          children: entries.expand((entry) => [
                            Padding(
                              padding: const EdgeInsets.only(top: 8, bottom: 6),
                              child: Text(entry.key, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade600)),
                            ),
                            Wrap(
                              spacing: 8, runSpacing: 8,
                              children: entry.value.map((cert) {
                                final isExisting = existingNames.contains(cert.toLowerCase());
                                final isSelected = selectedNames.contains(cert);
                                return FilterChip(
                                  label: Text(cert, style: TextStyle(fontSize: 13, color: isExisting ? Colors.grey : null)),
                                  selected: isExisting || isSelected,
                                  selectedColor: isExisting ? Colors.grey.shade200 : ExColors.techBlue.withOpacity(0.15),
                                  checkmarkColor: isExisting ? Colors.grey : ExColors.techBlue,
                                  onSelected: isExisting ? null : (val) async {
                                    if (val) {
                                      final expiry = await showDatePicker(
                                        context: ctx,
                                        initialDate: DateTime.now().add(const Duration(days: 365)),
                                        firstDate: DateTime(2020),
                                        lastDate: DateTime(2040),
                                        helpText: 'Expiry date (cancel to skip)',
                                      );
                                      setSheetState(() {
                                        selectedNames.add(cert);
                                        expiryDates[cert] = expiry;
                                      });
                                    } else {
                                      setSheetState(() {
                                        selectedNames.remove(cert);
                                        expiryDates.remove(cert);
                                      });
                                    }
                                  },
                                  visualDensity: VisualDensity.compact,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  side: BorderSide(color: isExisting ? Colors.grey.shade300 : Colors.grey.shade200),
                                );
                              }).toList(),
                            ),
                          ]).toList(),
                        ),
                  ),
                  Container(
                    padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.of(ctx).viewInsets.bottom + MediaQuery.of(ctx).padding.bottom + 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border(top: BorderSide(color: Colors.grey.shade200)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                textCapitalization: TextCapitalization.words,
                                decoration: InputDecoration(
                                  hintText: 'Enter custom certification...',
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)),
                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)),
                                  isDense: true,
                                ),
                                onSubmitted: (v) async {
                                  final trimmed = v.trim();
                                  if (trimmed.isNotEmpty && !existingNames.contains(trimmed.toLowerCase()) && !selectedNames.contains(trimmed)) {
                                    final expiry = await showDatePicker(
                                      context: ctx,
                                      initialDate: DateTime.now().add(const Duration(days: 365)),
                                      firstDate: DateTime(2020),
                                      lastDate: DateTime(2040),
                                      helpText: 'Expiry date (cancel to skip)',
                                    );
                                    setSheetState(() {
                                      selectedNames.add(trimmed);
                                      expiryDates[trimmed] = expiry;
                                    });
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              for (final name in selectedNames) {
                                final map = <String, dynamic>{
                                  'name': name,
                                  'verifiedAt': DateTime.now().toUtc().toIso8601String(),
                                };
                                if (expiryDates[name] != null) {
                                  map['expiryDate'] = expiryDates[name]!.toUtc().toIso8601String();
                                }
                                newCerts.add(map);
                              }
                              Navigator.pop(ctx);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: ExColors.techBlue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text(selectedNames.isEmpty ? 'Cancel' : 'Done (${selectedNames.length} selected)'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (newCerts.isNotEmpty) {
      final updated = [..._certifications, ...newCerts];
      await _saveCertifications(updated);
    }
  }

  Future<void> _verifyCertification(Map<String, dynamic> cert) async {
    final verified = {
      'name': cert['name'],
      if (cert['expiryDate'] != null) 'expiryDate': cert['expiryDate'],
      'verifiedAt': DateTime.now().toUtc().toIso8601String(),
    };
    final updated = [..._certifications, verified];
    await _saveCertifications(updated);
  }

  Future<void> _removeCertification(String name) async {
    final updated = _certifications.where((c) => c['name'] != name).toList();
    await _saveCertifications(updated);
  }

  Future<void> _saveCertifications(List<Map<String, dynamic>> certs) async {
    try {
      await _staffService.updateStaffProfile(_userKey, certifications: certs);
      final detail = await _staffService.fetchStaffDetail(_userKey);
      if (mounted) setState(() => _detail = detail);
    } catch (e) {
      if (mounted) {
        ErrorDisplayService.showErrorFromException(context, e, prefix: 'Error saving certifications');
      }
    }
  }

  // ─── Venue History Section ─────────────────────────────────────────────
  Widget _buildVenueHistorySection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.location_on_outlined, size: 18, color: ExColors.techBlue),
              const SizedBox(width: 8),
              const Text(
                'Venue History',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: ExColors.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_isLoadingVenues)
            const Center(child: CircularProgressIndicator(strokeWidth: 2))
          else if (_venueHistory.isEmpty)
            Text('No venue history yet', style: TextStyle(fontSize: 14, color: Colors.grey.shade500))
          else
            ..._venueHistory.take(10).map((venue) {
              final venueName = venue['venueName']?.toString() ?? 'Unknown';
              final clientName = venue['clientName']?.toString() ?? '';
              final timesWorked = venue['timesWorked'] ?? 0;
              final lastWorked = venue['lastWorked'] != null
                  ? DateTime.tryParse(venue['lastWorked'].toString())
                  : null;
              final roles = (venue['roles'] as List<dynamic>? ?? []).cast<String>();
              final lastStr = lastWorked != null
                  ? '${lastWorked.month}/${lastWorked.year}'
                  : '';

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.store, size: 20, color: Colors.orange.shade700),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            venueName,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: ExColors.textPrimary),
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                          ),
                          if (clientName.isNotEmpty)
                            Text(clientName, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                          Text(
                            '$timesWorked times${lastStr.isNotEmpty ? ' · Last: $lastStr' : ''}',
                            style: const TextStyle(fontSize: 12, color: ExColors.textSecondary),
                          ),
                          if (roles.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 4,
                              children: roles.map((r) => Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(r, style: TextStyle(fontSize: 10, color: Colors.grey.shade700)),
                              )).toList(),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  String _titleCase(String s) {
    if (s.isEmpty) return s;
    return s.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1);
    }).join(' ');
  }

  Widget _buildHoursSummary() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Hours Summary',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: ExColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          if (_isLoadingHours)
            const Center(child: CircularProgressIndicator(strokeWidth: 2))
          else
            Row(
              children: [
                _buildHoursColumn(
                  'This Week',
                  '${_hours?['weekly']?['hours'] ?? 0}h',
                  '${_hours?['weekly']?['shifts'] ?? 0} shifts',
                ),
                _buildHoursDivider(),
                _buildHoursColumn(
                  'This Month',
                  '${_hours?['monthly']?['hours'] ?? 0}h',
                  '${_hours?['monthly']?['shifts'] ?? 0} shifts',
                ),
                _buildHoursDivider(),
                _buildHoursColumn(
                  'All Time',
                  '${_hours?['allTime']?['hours'] ?? 0}h',
                  '${_hours?['allTime']?['shifts'] ?? 0} shifts',
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildHoursColumn(String label, String value, String subtitle) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: ExColors.techBlue,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 11,
              color: ExColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHoursDivider() {
    return Container(
      width: 1,
      height: 48,
      color: Colors.grey.shade200,
    );
  }

  Widget _buildRecentShifts() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recent Shifts',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: ExColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          if (_isLoadingDetail)
            const Center(child: CircularProgressIndicator(strokeWidth: 2))
          else if (_recentShifts.isEmpty)
            Text(
              'No shifts recorded yet',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
            )
          else
            ..._recentShifts.take(10).map((shift) {
              final date = shift['date'] != null
                  ? DateTime.tryParse(shift['date'].toString())
                  : null;
              final dateStr = date != null
                  ? '${date.month}/${date.day}/${date.year}'
                  : 'N/A';
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: ExColors.techBlue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.event, size: 20, color: ExColors.techBlue),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            shift['eventName']?.toString() ?? 'Shift',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: ExColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '$dateStr  ·  ${shift['role'] ?? 'Staff'}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: ExColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${shift['hours'] ?? 0}h',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: ExColors.techBlue,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildRatingSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Rating',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: ExColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          _buildStarRating(),
        ],
      ),
    );
  }

  Widget _buildStarRating() {
    final ratingLabels = ['', 'Poor', 'Fair', 'Good', 'Great', 'Excellent'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(5, (index) {
            final starValue = index + 1.0;
            final halfValue = index + 0.5;
            // Determine fill: full, half, or empty
            IconData icon;
            Color color;
            if (_rating >= starValue) {
              icon = Icons.star_rounded;
              color = Colors.amber.shade600;
            } else if (_rating >= halfValue) {
              icon = Icons.star_half_rounded;
              color = Colors.amber.shade600;
            } else {
              icon = Icons.star_outline_rounded;
              color = Colors.grey.shade300;
            }

            return GestureDetector(
              onTapDown: (details) {
                // Detect left half vs right half of star for half-star support
                final tapX = details.localPosition.dx;
                final isLeftHalf = tapX < 20; // half of 40px star
                final newRating = isLeftHalf ? halfValue : starValue;
                // Tap same rating again → clear
                final finalRating = newRating == _rating ? 0.0 : newRating;
                _onRatingChanged(finalRating);
              },
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 1.0, end: _rating >= halfValue ? 1.0 : 1.0),
                duration: const Duration(milliseconds: 150),
                builder: (context, scale, child) {
                  return AnimatedScale(
                    scale: _rating >= halfValue ? 1.0 : 0.9,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutBack,
                    child: child,
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Icon(icon, color: color, size: 40),
                ),
              ),
            );
          }),
        ),
        if (_rating > 0) ...[
          const SizedBox(height: 8),
          Text(
            '${_rating % 1 == 0 ? _rating.toInt() : _rating}/5 — ${ratingLabels[_rating.ceil()]}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _savePayroll() async {
    setState(() => _isSavingPayroll = true);
    try {
      await _staffService.updateStaffProfile(
        _userKey,
        externalEmployeeId: _externalIdController.text.trim(),
        workerType: _workerType,
      );
      if (mounted) {
        ScaffoldMessenger.of(context)..clearSnackBars()..showSnackBar(
          const SnackBar(
            content: Text('Payroll info updated'),
            backgroundColor: ExColors.successDark,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)..clearSnackBars()..showSnackBar(
          SnackBar(
            content: Text('Error saving payroll info: $e'),
            backgroundColor: ExColors.errorDark,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingPayroll = false);
    }
  }

  Widget _buildPayrollSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_balance_outlined, size: 18, color: ExColors.techBlue),
              const SizedBox(width: 8),
              const Text(
                'Payroll',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: ExColors.textPrimary,
                ),
              ),
              const Spacer(),
              if (_externalIdController.text.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: ExColors.successDark.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('Mapped', style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600, color: ExColors.successDark,
                  )),
                ),
            ],
          ),
          const SizedBox(height: 16),
          // External Employee ID
          TextField(
            controller: _externalIdController,
            decoration: InputDecoration(
              labelText: 'External Employee ID',
              hintText: 'ADP File Number / Paychex ID',
              hintStyle: TextStyle(color: Colors.grey.shade400),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: ExColors.techBlue),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Worker type toggle
          Row(
            children: [
              const Text('Worker Type:', style: TextStyle(
                fontSize: 14, color: ExColors.textSecondary,
              )),
              const SizedBox(width: 12),
              ChoiceChip(
                label: const Text('W-2'),
                selected: _workerType == 'w2',
                onSelected: (_) => setState(() => _workerType = 'w2'),
                selectedColor: ExColors.techBlue.withOpacity(0.15),
                labelStyle: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: _workerType == 'w2' ? ExColors.techBlue : Colors.grey,
                ),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('1099'),
                selected: _workerType == '1099',
                onSelected: (_) => setState(() => _workerType = '1099'),
                selectedColor: const Color(0xFFFED7AA),
                labelStyle: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: _workerType == '1099' ? const Color(0xFF92400E) : Colors.grey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSavingPayroll ? null : _savePayroll,
              style: ElevatedButton.styleFrom(
                backgroundColor: ExColors.techBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isSavingPayroll
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Save Payroll Info', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Notes',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: ExColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notesController,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'Add notes about this staff member...',
              hintStyle: TextStyle(color: Colors.grey.shade400),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: ExColors.techBlue),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _saveNotes,
              style: ElevatedButton.styleFrom(
                backgroundColor: ExColors.techBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Save', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}
