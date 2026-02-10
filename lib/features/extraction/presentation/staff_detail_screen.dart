import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:nexa/shared/widgets/initials_avatar.dart';
import '../services/staff_service.dart';
import '../services/group_service.dart';
import '../../chat/presentation/chat_screen.dart';
import 'theme/extraction_theme.dart';

class StaffDetailScreen extends StatefulWidget {
  final Map<String, dynamic> staff;

  const StaffDetailScreen({super.key, required this.staff});

  @override
  State<StaffDetailScreen> createState() => _StaffDetailScreenState();
}

class _StaffDetailScreenState extends State<StaffDetailScreen> {
  final StaffService _staffService = StaffService();
  final GroupService _groupService = GroupService();
  final TextEditingController _notesController = TextEditingController();

  Map<String, dynamic>? _hours;
  Map<String, dynamic>? _detail;
  List<Map<String, dynamic>> _allGroups = [];
  bool _isLoadingHours = false;
  bool _isLoadingDetail = false;
  bool _isSaving = false;
  late bool _isFavorite;
  late double _rating;

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

  @override
  void initState() {
    super.initState();
    _isFavorite = widget.staff['isFavorite'] == true;
    _rating = (widget.staff['rating'] as num?)?.toDouble() ?? 0;
    _notesController.text = widget.staff['notes'] as String? ?? '';
    _loadData();
  }

  @override
  void dispose() {
    _notesController.dispose();
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
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingDetail = false);
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated'),
            backgroundColor: ExColors.successDark,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
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
            _buildGroupsSection(),
            const SizedBox(height: 16),
            _buildHoursSummary(),
            const SizedBox(height: 16),
            _buildRecentShifts(),
            const SizedBox(height: 16),
            _buildRatingSection(),
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
      ],
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: ExColors.errorDark),
        );
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
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Error: $e')),
                                );
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating groups: $e'), backgroundColor: ExColors.errorDark),
        );
      }
    }
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
