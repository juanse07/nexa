import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nexa/l10n/app_localizations.dart';
import 'package:nexa/shared/services/error_display_service.dart';

import '../services/event_service.dart';
import '../services/group_service.dart';
import '../services/roles_service.dart';
import '../services/staff_service.dart';
import '../services/clients_service.dart';
import '../services/tariffs_service.dart';
import '../../teams/data/services/teams_service.dart';
import '../../teams/presentation/pages/teams_management_page.dart';
import '../../chat/data/services/chat_service.dart';
import 'package:nexa/core/network/socket_manager.dart';
import 'package:nexa/shared/presentation/theme/app_colors.dart';

class PendingPublishScreen extends StatefulWidget {
  final Map<String, dynamic> draft;
  final String draftId;

  const PendingPublishScreen({
    super.key,
    required this.draft,
    required this.draftId,
  });

  @override
  State<PendingPublishScreen> createState() => _PendingPublishScreenState();
}

class _PendingPublishScreenState extends State<PendingPublishScreen> {
  final StaffService _staffService = StaffService();
  final EventService _eventService = EventService();
  final RolesService _rolesService = RolesService();
  final ClientsService _clientsService = ClientsService();
  final TariffsService _tariffsService = TariffsService();
  final TeamsService _teamsService = TeamsService();
  final GroupService _groupService = GroupService();
  final ChatService _chatService = ChatService();
  StreamSubscription<SocketEvent>? _socketSubscription;

  final TextEditingController _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _users = const [];
  List<Map<String, dynamic>> _roles = const [];
  List<Map<String, dynamic>> _clients = const [];
  List<Map<String, dynamic>> _teams = const [];
  String? _cursor;
  bool _loadingUsers = false;
  final Set<String> _selectedKeys = <String>{};
  final Set<String> _selectedTeamIds = <String>{};
  final Set<String> _selectedGroupIds = <String>{};
  List<Map<String, dynamic>> _staffGroups = [];
  bool _loadingGroups = false;
  final Map<String, Map<String, String>> _keyToUser =
      <String, Map<String, String>>{};
  bool _publishing = false;
  final Map<String, TextEditingController> _roleCountCtrls =
      <String, TextEditingController>{};
  bool _loadingTeams = false;

  // Filter state
  String? _activeRoleFilter; // stores role name for filtering
  bool _starredFilterActive = false;
  int _totalLoadedCount = 0;
  final Set<String> _allLoadedKeys = {};

  // Memoized filtered list — invalidated on setState
  List<Map<String, dynamic>>? _filteredUsersCache;
  String? _filterCacheKey;

  /// Selected keys scoped to the currently visible (filtered) members.
  /// When a filter is active, only members passing the filter are considered.
  Set<String> get _effectiveSelectedKeys {
    final visibleKeys = _filteredUsers.map((u) =>
      (u['userKey'] ?? '${u['provider']}:${u['subject']}').toString()
    ).toSet();
    return _selectedKeys.intersection(visibleKeys);
  }

  /// Narrowing detection: determines smart button mode
  bool get _isNarrowed {
    if (_activeRoleFilter != null) return true;
    if (_starredFilterActive) return true;
    if (_searchCtrl.text.trim().isNotEmpty) return true;
    if (_selectedKeys.length < _totalLoadedCount) return true;
    return false;
  }

  @override
  void initState() {
    super.initState();
    _loadRoles();
    _loadTeams();
    _loadGroups();
    _loadStaff(reset: true);
    // Pre-fill role counts if draft already contains roles
    final roles =
        (widget.draft['roles'] as List?)?.whereType<Map>().toList() ?? const [];
    for (final r in roles) {
      final roleName = (r['role'] ?? '').toString();
      final count = (r['count'] ?? '').toString();
      if (roleName.isNotEmpty) {
        _roleCountCtrls[roleName] = TextEditingController(text: count);
      }
    }
    _socketSubscription = SocketManager.instance.events.listen((event) {
      if (!mounted) return;
      if (event.event.startsWith('team:') || event.event.startsWith('event:')) {
        _loadTeams();
      }
    });
  }

  Future<void> _loadRoles() async {
    try {
      final roles = await _rolesService.fetchRoles();
      setState(() => _roles = roles);
    } catch (e) {
      // Silently fail, roles will be empty
    }
  }

  Future<void> _loadGroups() async {
    setState(() => _loadingGroups = true);
    try {
      final groups = await _groupService.fetchGroups();
      if (mounted) setState(() { _staffGroups = groups; _loadingGroups = false; });
    } catch (e) {
      if (mounted) setState(() => _loadingGroups = false);
    }
  }

  /// Client-side filtered view of `_users` — memoized to avoid recomputing on every build.
  /// Checks both event-history roles AND backend group membership by name.
  List<Map<String, dynamic>> get _filteredUsers {
    final cacheKey = '${_activeRoleFilter ?? ''}_${_starredFilterActive}_${_users.length}';
    if (_filteredUsersCache != null && _filterCacheKey == cacheKey) {
      return _filteredUsersCache!;
    }
    var list = _users;
    if (_activeRoleFilter != null) {
      final target = _activeRoleFilter!.toLowerCase();
      list = list.where((u) {
        // Check event-history roles (shifts they've actually worked)
        final roles = u['roles'];
        if (roles is List && roles.any((r) => r.toString().toLowerCase() == target)) {
          return true;
        }
        // Check backend group membership (persistent manager tags)
        final groups = u['groups'];
        if (groups is List && groups.any((g) =>
            (g['name'] ?? '').toString().toLowerCase() == target)) {
          return true;
        }
        return false;
      }).toList();
    }
    if (_starredFilterActive) {
      list = list.where((u) => u['isFavorite'] == true).toList();
    }
    _filteredUsersCache = list;
    _filterCacheKey = cacheKey;
    return list;
  }

  /// Apply a filter chip tap: instant client-side first, server-side fallback if empty.
  ///
  /// [role] — set to a role name to filter, or null to clear role filter.
  /// [starred] — set to true/false to toggle starred, or null to leave unchanged.
  void _applyFilter({String? role, bool? starred}) {
    setState(() {
      _activeRoleFilter = role;
      _starredFilterActive = starred ?? false;
      _filteredUsersCache = null; // invalidate cache

      // When clearing all filters, re-select all loaded members
      if (role == null && !(starred ?? false)) {
        _selectedKeys.addAll(_allLoadedKeys);
      }
    });

    // If client-side filter yields nothing but we haven't loaded all pages,
    // fall back to server-side filtered request to catch members beyond loaded page.
    final clientResults = _filteredUsers;
    final hasMorePages = _cursor != null && _cursor != 'null';
    final hasActiveFilter = _activeRoleFilter != null || _starredFilterActive;
    if (clientResults.isEmpty && hasMorePages && hasActiveFilter) {
      _loadStaff(reset: true, serverFilter: true);
    }
  }

  Future<void> _loadStaff({bool reset = false, bool serverFilter = false}) async {
    if (_loadingUsers) return;
    setState(() => _loadingUsers = true);
    try {
      final res = await _staffService.fetchStaff(
        q: _searchCtrl.text.trim(),
        cursor: reset ? null : _cursor,
        role: serverFilter ? _activeRoleFilter : null,
        favorite: serverFilter && _starredFilterActive ? true : null,
        limit: 50,
      );
      final items =
          (res['items'] as List?)?.whereType<Map<String, dynamic>>().toList() ??
          const [];
      setState(() {
        if (serverFilter) {
          // Server-filtered fallback: merge results into _users without losing existing data.
          // Add new members not already present so role chips stay stable.
          final existingKeys = _users.map((u) =>
            (u['userKey'] ?? '${u['provider']}:${u['subject']}').toString()
          ).toSet();
          for (final item in items) {
            final key = (item['userKey'] ?? '${item['provider']}:${item['subject']}').toString();
            if (!existingKeys.contains(key)) {
              _users = [..._users, item];
            }
          }
        } else if (reset) {
          _users = items;
          _selectedKeys.clear();
        } else {
          _users = [..._users, ...items];
        }
        if (!serverFilter) {
          _cursor = res['nextCursor'] as String?;
        }
        _filteredUsersCache = null; // invalidate cache
        for (final u in items) {
          final key = (u['userKey'] ?? '${u['provider']}:${u['subject']}').toString();
          _keyToUser[key] = {
            'name': (u['name'] ?? '').toString(),
            'email': (u['email'] ?? '').toString(),
            'id': (u['id'] ?? u['_id'] ?? '').toString(),
            'subject': (u['subject'] ?? '').toString(),
            'provider': (u['provider'] ?? '').toString(),
            'first_name': (u['first_name'] ?? '').toString(),
            'last_name': (u['last_name'] ?? '').toString(),
          };
          // Pre-select all loaded members
          _selectedKeys.add(key);
          _allLoadedKeys.add(key);
        }
        _totalLoadedCount = _allLoadedKeys.length;
      });
    } finally {
      setState(() => _loadingUsers = false);
    }
  }

  Future<void> _loadTeams() async {
    setState(() => _loadingTeams = true);
    try {
      final teams = await _teamsService.fetchTeams();
      final availableIds = teams
          .map((team) => (team['id'] ?? '').toString())
          .where((id) => id.isNotEmpty)
          .toSet();
      _selectedTeamIds.removeWhere((id) => !availableIds.contains(id));
      setState(() {
        _teams = teams;
        _loadingTeams = false;
        // Auto-preselect first team if none selected
        if (_selectedTeamIds.isEmpty && _teams.isNotEmpty) {
          final firstId = (_teams.first['id'] ?? '').toString();
          if (firstId.isNotEmpty) _selectedTeamIds.add(firstId);
        }
      });
    } catch (e) {
      setState(() => _loadingTeams = false);
      if (mounted) {
        ErrorDisplayService.showErrorFromException(context, e, prefix: 'Failed to load teams');
      }
    }
  }

  Future<void> _sendDirectInvitations() async {
    final keysToInvite = _effectiveSelectedKeys;
    if (keysToInvite.isEmpty) {
      ScaffoldMessenger.of(context)..clearSnackBars()..showSnackBar(
        const SnackBar(content: Text('Select at least one person to invite')),
      );
      return;
    }

    setState(() => _publishing = true);
    try {
      final payload = Map<String, dynamic>.from(widget.draft);

      // Check if client already exists
      final existingClientName = (payload['client_name'] ?? '').toString().trim();
      String clientName = existingClientName;

      if (existingClientName.isEmpty) {
        final clientData = await _promptClientPicker();
        if (clientData == null) {
          setState(() => _publishing = false);
          return;
        }
        clientName = (clientData['name'] ?? '').toString();
        final rawClientId = (clientData['id'] ?? '').toString();
        payload['client_name'] = clientName;
        if (rawClientId.isNotEmpty) {
          payload['clientId'] = rawClientId;
          payload['client_id'] = rawClientId;
        }
      }

      // Check if roles exist with positive counts
      final existingRoles = (payload['roles'] as List?)?.whereType<Map<dynamic, dynamic>>().toList() ?? [];
      final hasPositiveRoles = existingRoles.any((role) {
        final count = role['count'];
        if (count is int) return count > 0;
        final parsed = int.tryParse(count?.toString() ?? '');
        return parsed != null && parsed > 0;
      });

      Map<String, int> counts;
      List<Map<String, dynamic>> roleDefs;

      if (!hasPositiveRoles) {
        final promptedCounts = await _promptRoleCounts(payload);
        if (promptedCounts == null) {
          setState(() => _publishing = false);
          return;
        }
        counts = promptedCounts;
        roleDefs = _countsToRoles(counts);
        if (roleDefs.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context)..clearSnackBars()..showSnackBar(
              const SnackBar(content: Text('Add at least one role with a positive headcount')),
            );
          }
          setState(() => _publishing = false);
          return;
        }
        payload['roles'] = roleDefs;
      } else {
        roleDefs = existingRoles.map((role) => Map<String, dynamic>.from(role)).toList();
      }

      // Update the draft with roles and client info (but DON'T publish)
      await _eventService.updateEvent(widget.draftId, payload);

      // Prompt for role assignments (scoped to filtered selection)
      final userRoleAssignments = await _promptRoleAssignmentsForUsers(roleDefs, keysToInvite);
      if (userRoleAssignments == null) {
        setState(() => _publishing = false);
        return;
      }

      // Build array of {userKey, roleId} for bulk invitation endpoint
      final assignments = userRoleAssignments.entries.map((entry) {
        return {
          'userKey': entry.key,
          'roleId': entry.value,
        };
      }).toList();

      // Call bulk invitation endpoint
      final response = await _chatService.sendBulkInvitations(
        eventId: widget.draftId,
        userRoleAssignments: assignments,
      );

      if (!mounted) return;

      final successCount = (response['successCount'] as num?)?.toInt() ?? 0;
      final failureCount = (response['failureCount'] as num?)?.toInt() ?? 0;

      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context)..clearSnackBars()..showSnackBar(
        SnackBar(
          content: Text(
            'Invitations sent: $successCount successful${failureCount > 0 ? ", $failureCount failed" : ""}. Event published privately - only invited staff can see it.',
          ),
          backgroundColor: successCount > 0 ? Colors.green : Colors.orange,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ErrorDisplayService.showErrorFromException(context, e, prefix: 'Failed to send invitations');
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  Future<void> _publish() async {
    if (_selectedKeys.isEmpty && _selectedTeamIds.isEmpty) {
      ScaffoldMessenger.of(context)..clearSnackBars()..showSnackBar(
        const SnackBar(content: Text('Select at least one user or team')),
      );
      return;
    }
    setState(() => _publishing = true);
    try {
      final payload = Map<String, dynamic>.from(widget.draft);

      // Check if client already exists in draft
      final existingClientName = (payload['client_name'] ?? '').toString().trim();
      final existingClientId = (payload['clientId'] ?? payload['client_id'] ?? '').toString().trim();

      String clientName = existingClientName;
      String? clientId = existingClientId.isNotEmpty ? existingClientId : null;

      // Only prompt for client if missing
      if (existingClientName.isEmpty) {
        final clientData = await _promptClientPicker();
        if (clientData == null) {
          setState(() => _publishing = false);
          return;
        }
        clientName = (clientData['name'] ?? '').toString();
        final rawClientId = (clientData['id'] ?? '').toString();
        clientId = rawClientId.isNotEmpty ? rawClientId : null;
        payload['client_name'] = clientName;
        if (clientId != null) {
          payload['clientId'] = clientId;
          payload['client_id'] = clientId;
        }
      }

      // Check if roles already exist with positive counts
      final existingRoles = (payload['roles'] as List?)?.whereType<Map<dynamic, dynamic>>().toList() ?? [];
      final hasPositiveRoles = existingRoles.any((role) {
        final count = role['count'];
        if (count is int) return count > 0;
        final parsed = int.tryParse(count?.toString() ?? '');
        return parsed != null && parsed > 0;
      });

      Map<String, int> counts;
      List<Map<String, dynamic>> roleDefs;

      // Only prompt for roles if missing or all zero
      if (!hasPositiveRoles) {
        final promptedCounts = await _promptRoleCounts(payload);
        if (promptedCounts == null) {
          setState(() => _publishing = false);
          return;
        }
        counts = promptedCounts;
        roleDefs = _countsToRoles(counts);
        if (roleDefs.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context)..clearSnackBars()..showSnackBar(
              const SnackBar(
                content: Text('Add at least one role with a positive headcount'),
              ),
            );
          }
          setState(() => _publishing = false);
          return;
        }
        payload['roles'] = roleDefs;
      } else {
        // Use existing roles from draft
        roleDefs = existingRoles.map((role) => Map<String, dynamic>.from(role)).toList();
        counts = {};
        for (final role in existingRoles) {
          final roleName = (role['role'] ?? '').toString().toLowerCase();
          final count = role['count'];
          if (count is int) {
            counts[roleName] = count;
          } else {
            final parsed = int.tryParse(count?.toString() ?? '');
            if (parsed != null) counts[roleName] = parsed;
          }
        }
      }

      final totalHeadcount = counts.values.fold<int>(
        0,
        (acc, value) => acc + value,
      );
      if (totalHeadcount > 0) {
        payload['headcount_total'] = totalHeadcount;
      }

      // Get roles with non-zero counts for tariff picker
      final activeRoleNames = counts.entries
          .where((e) => e.value > 0)
          .map((e) => e.key)
          .toList();

      // Prompt for tariffs if there are active roles and we have a client ID
      if (activeRoleNames.isNotEmpty && clientId != null) {
        final tariffs = await _promptTariffPicker(
          clientId: clientId,
          roleNames: activeRoleNames,
        );
        if (tariffs == null) {
          setState(() => _publishing = false);
          return;
        }
        if (tariffs.isNotEmpty) {
          final errorMessage = await _persistTariffsFromPicker(
            clientId: clientId,
            tariffs: tariffs,
          );
          if (errorMessage != null) {
            if (mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(errorMessage)));
            }
            setState(() => _publishing = false);
            return;
          }
        }
      }

      // First, update the draft with the new data (client, roles, tariffs)
      await _eventService.updateEvent(widget.draftId, payload);

      // Then publish the draft using the dedicated publish endpoint
      final audienceUserKeys = _selectedKeys.toList();
      final audienceTeamIds = _selectedTeamIds.toList();

      // Automatically set visibility to 'public' when publishing to teams
      final publishedEvent = await _eventService.publishEvent(
        widget.draftId,
        audienceUserKeys: audienceUserKeys,
        audienceTeamIds: audienceTeamIds,
        audienceGroupIds: _selectedGroupIds.isNotEmpty ? _selectedGroupIds.toList() : null,
        visibilityType: 'public',
      );

      final eventId = (publishedEvent['_id'] ?? publishedEvent['id'] ?? '').toString();

      // Send individual invitations to selected users via chat
      String publishMessage = AppLocalizations.of(context)!.jobPosted;
      if (_selectedKeys.isNotEmpty && eventId.isNotEmpty) {
        try {
          await _sendJobInvitationsToUsers(eventId, publishedEvent, roleDefs);
          publishMessage = '${AppLocalizations.of(context)!.jobPosted} and invitations sent';
        } catch (e) {
          publishMessage = '${AppLocalizations.of(context)!.jobPosted}, but some invitations failed';
        }
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(publishMessage)));
    } catch (e) {
      if (!mounted) return;
      ErrorDisplayService.showErrorFromException(context, e, prefix: 'Publish failed');
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  Future<void> _sendJobInvitationsToUsers(
    String eventId,
    Map<String, dynamic> eventData,
    List<Map<String, dynamic>> roles,
  ) async {
    if (roles.isEmpty) return;

    // Prompt user to select role for each selected user
    final userRoleAssignments = await _promptRoleAssignmentsForUsers(roles);
    if (userRoleAssignments == null) return;

    // For each selected user, send them a job invitation via chat with their assigned role
    for (final entry in userRoleAssignments.entries) {
      final userKey = entry.key;
      final roleId = entry.value;

      if (roleId == null || roleId.isEmpty) continue;

      try {
        await _chatService.sendEventInvitation(
          targetId: userKey,
          eventId: eventId,
          roleId: roleId,
          eventData: eventData,
        );
      } catch (e) {
        // Continue sending to other users even if one fails
      }
    }
  }

  Future<Map<String, String>?> _promptRoleAssignmentsForUsers(
    List<Map<String, dynamic>> roles, [
    Set<String>? scopedKeys,
  ]) async {
    final keys = scopedKeys ?? _effectiveSelectedKeys;
    final roleNames = roles
        .map((r) => (r['role'] ?? r['name'] ?? '').toString())
        .where((name) => name.isNotEmpty)
        .toList();

    if (roleNames.isEmpty) {
      return null;
    }

    // Build a map of user key -> assigned role name
    final Map<String, String> assignments = {};

    // Initialize with first role for all users
    for (final userKey in keys) {
      assignments[userKey] = roleNames.first;
    }

    final result = await showDialog<Map<String, String>?>(
      context: context,
      barrierDismissible: true,
      builder: (context) => _RoleAssignmentDialog(
        users: keys.map((key) {
          final user = _keyToUser[key];
          return {
            'key': key,
            'name': '${user?['first_name'] ?? ''} ${user?['last_name'] ?? ''}'.trim(),
            'email': user?['email'] ?? '',
          };
        }).toList(),
        roleNames: roleNames,
        initialAssignments: assignments,
      ),
    );

    return result;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final data = widget.draft;
    final client = (data['client_name'] ?? '').toString();
    final name = (data['event_name'] ?? data['venue_name'] ?? 'Untitled').toString();
    final date = (data['date'] ?? '').toString();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(l10n.postJob),
        backgroundColor: AppColors.navySpaceCadet,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Event info card ──────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 4,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.primaryIndigo,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                client.isNotEmpty ? client : 'Client',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.navySpaceCadet,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                [name, date].where((s) => s.isNotEmpty).join(' • '),
                                style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  _buildTeamSelector(),
                  _buildGroupSelector(),
                  _buildFilterSection(l10n),
                  const SizedBox(height: 16),

                  // ── Team Members ─────────────────────────────
                  Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppColors.navySpaceCadet.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.person_search_rounded,
                          size: 16,
                          color: AppColors.navySpaceCadet,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Team Members',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: AppColors.navySpaceCadet,
                        ),
                      ),
                      const Spacer(),
                      if (_filteredUsers.isNotEmpty) ...[
                        // Select all / Deselect all toggle
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              final allKeys = _filteredUsers.map((u) =>
                                (u['userKey'] ?? '${u['provider']}:${u['subject']}').toString()
                              ).toSet();
                              final allSelected = allKeys.every(_selectedKeys.contains);
                              if (allSelected) {
                                _selectedKeys.removeAll(allKeys);
                              } else {
                                _selectedKeys.addAll(allKeys);
                              }
                            });
                          },
                          child: Builder(builder: (context) {
                            final allKeys = _filteredUsers.map((u) =>
                              (u['userKey'] ?? '${u['provider']}:${u['subject']}').toString()
                            ).toSet();
                            final allSelected = allKeys.isNotEmpty &&
                                allKeys.every(_selectedKeys.contains);
                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  allSelected
                                      ? Icons.check_box_rounded
                                      : Icons.check_box_outline_blank_rounded,
                                  size: 18,
                                  color: AppColors.primaryIndigo,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  allSelected ? 'Deselect all' : 'Select all',
                                  style: const TextStyle(
                                    color: AppColors.primaryIndigo,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            );
                          }),
                        ),
                        const SizedBox(width: 10),
                      ],
                      if (_effectiveSelectedKeys.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.navySpaceCadet,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${_effectiveSelectedKeys.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search, size: 20),
                      hintText: 'Search team members',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onChanged: (_) => _loadStaff(reset: true),
                    onSubmitted: (_) => _loadStaff(reset: true),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 220,
                    child: _filteredUsers.isEmpty && !_loadingUsers
                        ? Center(
                            child: Text(
                              _searchCtrl.text.trim().isEmpty && _activeRoleFilter == null && !_starredFilterActive
                                  ? 'No team members yet.\nAdd members to your teams first.'
                                  : _activeRoleFilter != null
                                      ? 'No members with role "$_activeRoleFilter"'
                                      : _starredFilterActive
                                          ? 'No starred members'
                                          : 'No results for "${_searchCtrl.text.trim()}"',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey.shade500),
                            ),
                          )
                        : Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: NotificationListener<ScrollNotification>(
                              onNotification: (n) {
                                if (n.metrics.pixels >=
                                        n.metrics.maxScrollExtent - 100 &&
                                    _cursor != null &&
                                    _cursor != 'null' &&
                                    !_loadingUsers) {
                                  _loadStaff();
                                }
                                return false;
                              },
                              child: ListView.builder(
                                itemCount:
                                    _filteredUsers.length + (_loadingUsers ? 1 : 0),
                                itemBuilder: (ctx, idx) {
                                  if (idx >= _filteredUsers.length) {
                                    return const Center(
                                      child: Padding(
                                        padding: EdgeInsets.all(12),
                                        child: CircularProgressIndicator(),
                                      ),
                                    );
                                  }
                                  final u = _filteredUsers[idx];
                                  final key = (u['userKey'] ?? '${u['provider']}:${u['subject']}').toString();
                                  final selected =
                                      _selectedKeys.contains(key);
                                  final isFav = u['isFavorite'] == true;
                                  return CheckboxListTile(
                                    value: selected,
                                    activeColor: AppColors.navySpaceCadet,
                                    dense: true,
                                    onChanged: (_) {
                                      setState(() {
                                        if (selected) {
                                          _selectedKeys.remove(key);
                                        } else {
                                          _selectedKeys.add(key);
                                        }
                                      });
                                    },
                                    title: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            (u['name'] ?? u['email'] ?? key)
                                                .toString(),
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                        if (isFav)
                                          const Icon(
                                            Icons.star_rounded,
                                            size: 16,
                                            color: Colors.amber,
                                          ),
                                      ],
                                    ),
                                    subtitle: Text(
                                      (u['email'] ?? '').toString(),
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                  ),
                  // Selected count is shown in the header badge
                ],
              ),
            ),
          ),

          // ── Smart action button ──────────────────────────────
          _buildSmartButton(l10n),
        ],
      ),
    );
  }

  Widget _buildFilterSection(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.primaryIndigo.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.filter_list_rounded,
                size: 16,
                color: AppColors.primaryIndigo,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              l10n.filterStaff,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: AppColors.navySpaceCadet,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              // "All roles" chip — clears role + starred filters
              _filterChip(
                label: l10n.allRoles,
                isSelected: _activeRoleFilter == null && !_starredFilterActive,
                onTap: () => _applyFilter(role: null, starred: false),
              ),
              const SizedBox(width: 6),
              // "Starred" chip
              _filterChip(
                label: l10n.starredFilter,
                isSelected: _starredFilterActive,
                icon: Icons.star_rounded,
                iconColor: _starredFilterActive ? Colors.white : Colors.amber,
                onTap: () => _applyFilter(starred: !_starredFilterActive),
              ),
              const SizedBox(width: 6),
              // Dynamic role chips from manager's defined roles
              ..._roles.map((role) {
                final roleName = (role['name'] ?? '').toString();
                if (roleName.isEmpty) return const SizedBox.shrink();
                final isSelected = _activeRoleFilter == roleName;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: _filterChip(
                    label: roleName,
                    isSelected: isSelected,
                    onTap: () => _applyFilter(
                      role: isSelected ? null : roleName,
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _filterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    IconData? icon,
    Color? iconColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.navySpaceCadet
              : AppColors.navySpaceCadet.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: iconColor ?? Colors.white),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : AppColors.navySpaceCadet,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSmartButton(AppLocalizations l10n) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isNarrowed) ...[
                // Narrowed → private invitations
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _publishing ? null : _sendDirectInvitations,
                    icon: const Icon(Icons.mail_outline_rounded, size: 18),
                    label: Text(
                      _publishing ? 'Sending...' : l10n.sendDirectInvitations,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(
                        color: AppColors.navySpaceCadet,
                        width: 1.5,
                      ),
                      foregroundColor: AppColors.navySpaceCadet,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.eventStaysPrivate,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  textAlign: TextAlign.center,
                ),
              ] else ...[
                // Not narrowed → public publish
                SizedBox(
                  width: double.infinity,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF212C4A),
                          Color(0xFF1E3A8A),
                        ],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ElevatedButton.icon(
                      onPressed: _publishing ? null : _publish,
                      icon: const Icon(Icons.campaign_rounded, size: 18),
                      label: Text(
                        _publishing ? 'Publishing...' : l10n.publishToTeam,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.eventBecomesVisible,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTeamSelector() {
    final hasTeams = _teams.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.navySpaceCadet.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.group_outlined,
                size: 16,
                color: AppColors.navySpaceCadet,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Target Teams',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: AppColors.navySpaceCadet,
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: _openTeamsManagement,
              child: const Row(
                children: [
                  Icon(
                    Icons.people_alt_rounded,
                    size: 14,
                    color: AppColors.primaryIndigo,
                  ),
                  SizedBox(width: 4),
                  Text(
                    'Manage',
                    style: TextStyle(
                      color: AppColors.primaryIndigo,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (_loadingTeams)
          const LinearProgressIndicator(minHeight: 2)
        else if (!hasTeams)
          Text(
            'Create a team to target groups of workers.',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _teams.map((team) {
              final teamId = (team['id'] ?? '').toString();
              final name = (team['name'] ?? '').toString();
              final isSelected = _selectedTeamIds.contains(teamId);
              return FilterChip(
                selected: isSelected,
                selectedColor: AppColors.navySpaceCadet,
                checkmarkColor: Colors.white,
                backgroundColor: Colors.white,
                side: BorderSide(
                  color: isSelected ? AppColors.navySpaceCadet : AppColors.border,
                  width: 1.5,
                ),
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : AppColors.navySpaceCadet,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                label: Text(name.isEmpty ? 'Untitled team' : name),
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      if (teamId.isNotEmpty) _selectedTeamIds.add(teamId);
                    } else {
                      _selectedTeamIds.remove(teamId);
                    }
                  });
                },
              );
            }).toList(),
          ),
        const SizedBox(height: 16),
      ],
    );
  }


  Widget _buildGroupSelector() {
    if (_staffGroups.isEmpty && !_loadingGroups) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFF7A3AFB).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.group_work_rounded,
                size: 16,
                color: Color(0xFF7A3AFB),
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Staff Groups',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: AppColors.navySpaceCadet,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (_loadingGroups)
          const LinearProgressIndicator(minHeight: 2)
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _staffGroups.map((group) {
              final groupId = (group['id'] ?? '').toString();
              final name = (group['name'] ?? '').toString();
              final memberCount = (group['memberCount'] as int?) ?? 0;
              final isSelected = _selectedGroupIds.contains(groupId);
              return FilterChip(
                selected: isSelected,
                selectedColor: const Color(0xFF7A3AFB),
                checkmarkColor: Colors.white,
                backgroundColor: Colors.white,
                side: BorderSide(
                  color: isSelected
                      ? const Color(0xFF7A3AFB)
                      : AppColors.border,
                  width: 1.5,
                ),
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : AppColors.navySpaceCadet,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                label: Text('${name.isEmpty ? 'Untitled' : name} ($memberCount)'),
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      if (groupId.isNotEmpty) _selectedGroupIds.add(groupId);
                    } else {
                      _selectedGroupIds.remove(groupId);
                    }
                  });
                },
              );
            }).toList(),
          ),
        const SizedBox(height: 16),
      ],
    );
  }

  Future<void> _openTeamsManagement() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const TeamsManagementPage()));
    await _loadTeams();
  }

  @override
  void dispose() {
    _socketSubscription?.cancel();
    _searchCtrl.dispose();
    for (final controller in _roleCountCtrls.values) {
      controller.dispose();
    }
    _roleCountCtrls.clear();
    super.dispose();
  }

  Future<Map<String, int>?> _promptRoleCounts(
    Map<String, dynamic> payload,
  ) async {
    int extract(List<dynamic> roles, String keyword) {
      for (final r in roles) {
        if (r is Map) {
          final name = (r['role'] ?? '').toString().toLowerCase();
          if (name.contains(keyword)) {
            final v = r['count'];
            if (v is int) return v;
            final parsed = int.tryParse(v?.toString() ?? '');
            if (parsed != null) return parsed;
          }
        }
      }
      return 0;
    }

    final List<dynamic> existing = (payload['roles'] is List)
        ? (payload['roles'] as List)
        : const [];

    // Create controllers for all available roles dynamically
    final Map<String, TextEditingController> roleControllers = {};
    for (final role in _roles) {
      final roleName = (role['name'] ?? '').toString();
      if (roleName.isEmpty) continue;

      final existingCount = extract(existing, roleName.toLowerCase());
      roleControllers[roleName] = TextEditingController(
        text: existingCount.toString(),
      );
    }

    final TextEditingController newRoleCtrl = TextEditingController();

    return showDialog<Map<String, int>>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setStateDialog) {
            return AlertDialog(
              title: Text(AppLocalizations.of(context)!.setRolesForJob),
              content: SizedBox(
                width: 400,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (roleControllers.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('No roles available. Create one below.'),
                        )
                      else
                        ...roleControllers.entries.map((entry) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _numField(entry.value, entry.key),
                          );
                        }).toList(),
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 8),
                      TextField(
                        controller: newRoleCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Or create new role',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final newName = newRoleCtrl.text.trim();
                            if (newName.isEmpty) return;
                            try {
                              await _rolesService.createRole(newName);
                              // Reload roles
                              await _loadRoles();
                              // Add controller for the new role
                              roleControllers[newName] = TextEditingController(
                                text: '0',
                              );
                              newRoleCtrl.clear();
                              setStateDialog(() {});
                              if (!mounted) return;
                              ScaffoldMessenger.of(context)..clearSnackBars()..showSnackBar(
                                SnackBar(
                                  content: Text('Role "$newName" created'),
                                ),
                              );
                            } catch (e) {
                              if (!mounted) return;
                              ScaffoldMessenger.of(context)..clearSnackBars()..showSnackBar(
                                SnackBar(
                                  content: Text('Failed to create role: $e'),
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Create Role'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(null),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final counts = <String, int>{};
                    for (final entry in roleControllers.entries) {
                      final roleName = entry.key;
                      final controller = entry.value;
                      counts[roleName.toLowerCase()] =
                          int.tryParse(controller.text.trim()) ?? 0;
                    }
                    final hasPositive = counts.values.any((value) => value > 0);
                    if (!hasPositive) {
                      if (mounted) {
                        ScaffoldMessenger.of(context)..clearSnackBars()..showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Add at least one role with a positive headcount',
                            ),
                          ),
                        );
                      }
                      return;
                    }
                    Navigator.of(ctx).pop(counts);
                  },
                  child: const Text('Continue'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _numField(TextEditingController c, String label) {
    return TextField(
      controller: c,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.people),
      ),
    );
  }

  List<Map<String, dynamic>> _countsToRoles(Map<String, int> counts) {
    final list = <Map<String, dynamic>>[];

    // Add roles with counts > 0, using proper case names from _roles
    for (final entry in counts.entries) {
      final count = entry.value;
      if (count > 0) {
        // Find the proper case name from available roles
        final properCaseName =
            _roles
                .firstWhere(
                  (r) =>
                      (r['name']?.toString() ?? '').toLowerCase() == entry.key,
                  orElse: () => {'name': entry.key},
                )['name']
                ?.toString() ??
            entry.key;

        list.add({'role': properCaseName, 'count': count});
      }
    }

    return list;
  }

  Future<String?> _persistTariffsFromPicker({
    required String clientId,
    required Map<String, double> tariffs,
  }) async {
    if (tariffs.isEmpty) return null;
    final failures = <String>[];
    for (final entry in tariffs.entries) {
      final rate = entry.value;
      if (rate <= 0) continue;
      final roleId = _findRoleIdForKey(entry.key);
      if (roleId == null) {
        failures.add('${entry.key} (role missing)');
        continue;
      }
      try {
        await _tariffsService.upsertTariff(
          clientId: clientId,
          roleId: roleId,
          rate: rate,
        );
      } catch (e) {
        failures.add('${entry.key}: $e');
      }
    }
    if (failures.isEmpty) {
      return null;
    }
    return 'Failed to save tariffs: ${failures.join(', ')}';
  }

  String? _findRoleIdForKey(String roleKey) {
    final normalized = roleKey.trim().toLowerCase();
    if (normalized.isEmpty) return null;
    for (final role in _roles) {
      final roleName = (role['name'] ?? '').toString().trim().toLowerCase();
      if (roleName == normalized) {
        final id = (role['id'] ?? role['_id'] ?? '').toString();
        if (id.isNotEmpty) return id;
      }
    }
    return null;
  }

  Future<Map<String, dynamic>?> _promptClientPicker() async {
    // Load latest clients
    try {
      final clients = await _clientsService.fetchClients();
      setState(() => _clients = clients);
    } catch (e) {
      // Fail silently, clients will be empty
    }

    final TextEditingController newClientCtrl = TextEditingController();

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setStateDialog) {
            return AlertDialog(
              title: const Text('Select Client'),
              content: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_clients.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('No clients available. Create one below.'),
                      )
                    else
                      SizedBox(
                        height: 200,
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: _clients.length,
                          itemBuilder: (ctx, idx) {
                            final client = _clients[idx];
                            final name = (client['name'] ?? 'Unnamed')
                                .toString();
                            final id = (client['id'] ?? client['_id'] ?? '')
                                .toString();
                            return ListTile(
                              title: Text(name),
                              onTap: () => Navigator.of(
                                ctx,
                              ).pop({'name': name, 'id': id}),
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),
                    TextField(
                      controller: newClientCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Or create new client',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(null),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final newName = newClientCtrl.text.trim();
                    if (newName.isEmpty) return;
                    try {
                      final newClient = await _clientsService.createClient(
                        newName,
                      );
                      if (!mounted) return;
                      final newId = (newClient['id'] ?? newClient['_id'] ?? '')
                          .toString();
                      Navigator.of(ctx).pop({'name': newName, 'id': newId});
                    } catch (e) {
                      if (!mounted) return;
                      ErrorDisplayService.showErrorFromException(context, e, prefix: 'Failed to create client');
                    }
                  },
                  child: const Text('Create & Select'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<Map<String, double>?> _promptTariffPicker({
    required String clientId,
    required List<String> roleNames,
  }) async {
    // Load tariffs for this client
    List<Map<String, dynamic>> tariffs = [];
    try {
      tariffs = await _tariffsService.fetchTariffs(clientId: clientId);
    } catch (e) {
      // Silently fail, tariffs will be empty
    }

    // Create a map of role name to role ID for matching
    final Map<String, String> roleNameToId = {};
    for (final role in _roles) {
      final name = (role['name'] ?? '').toString();
      final id = (role['id'] ?? role['_id'] ?? '').toString();
      if (name.isNotEmpty && id.isNotEmpty) {
        roleNameToId[name.toLowerCase()] = id;
      }
    }

    // Create controllers for tariff rates for each role
    final Map<String, TextEditingController> tariffControllers = {};
    final Map<String, bool> hasExistingTariff = {};

    for (final roleName in roleNames) {
      final roleId = roleNameToId[roleName.toLowerCase()];

      // Find existing tariff for this role by matching roleId
      final existingTariff = tariffs.firstWhere(
        (t) => (t['roleId']?.toString() ?? '') == roleId,
        orElse: () => <String, dynamic>{},
      );

      final existingRate = existingTariff['rate']?.toString() ?? '';
      final hasExisting = existingRate.isNotEmpty;

      tariffControllers[roleName] = TextEditingController(text: existingRate);
      hasExistingTariff[roleName] = hasExisting;
    }

    return showDialog<Map<String, double>>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setStateDialog) {
            return AlertDialog(
              title: const Text('Set tariffs for roles'),
              content: SizedBox(
                width: 400,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Set or update tariff rates for each role:',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      ...tariffControllers.entries.map((entry) {
                        final roleName = entry.key;
                        final hasExisting =
                            hasExistingTariff[roleName] ?? false;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: TextField(
                            controller: entry.value,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(
                              labelText: '${entry.key} Rate',
                              prefixIcon: const Icon(Icons.attach_money),
                              border: const OutlineInputBorder(),
                              hintText: 'e.g., 50.00',
                              suffixIcon: hasExisting
                                  ? const Tooltip(
                                      message: 'Existing tariff loaded',
                                      child: Icon(
                                        Icons.check_circle,
                                        color: Colors.green,
                                      ),
                                    )
                                  : null,
                              helperText: hasExisting
                                  ? 'Existing tariff'
                                  : 'New tariff',
                            ),
                          ),
                        );
                      }).toList(),
                      const SizedBox(height: 8),
                      const Divider(),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            // Save all tariffs that have been entered
                            for (final entry in tariffControllers.entries) {
                              final roleName = entry.key;
                              final rateStr = entry.value.text.trim();
                              if (rateStr.isEmpty) continue;

                              final rate = double.tryParse(rateStr);
                              if (rate == null) continue;

                              // Get the role ID for this role name
                              final roleId =
                                  roleNameToId[roleName.toLowerCase()];
                              if (roleId == null) continue;

                              try {
                                await _tariffsService.upsertTariff(
                                  clientId: clientId,
                                  roleId: roleId,
                                  rate: rate,
                                );
                              } catch (e) {
                                if (!mounted) return;
                                ScaffoldMessenger.of(context)..clearSnackBars()..showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Failed to save tariff for $roleName: $e',
                                    ),
                                  ),
                                );
                              }
                            }

                            if (!mounted) return;
                            ScaffoldMessenger.of(context)..clearSnackBars()..showSnackBar(
                              const SnackBar(content: Text('Tariffs saved')),
                            );
                            // Reload tariffs to refresh the UI with updated data
                            try {
                              tariffs = await _tariffsService.fetchTariffs(
                                clientId: clientId,
                              );
                              // Update the hasExistingTariff map
                              for (final roleName in roleNames) {
                                final roleId =
                                    roleNameToId[roleName.toLowerCase()];
                                final existingTariff = tariffs.firstWhere(
                                  (t) =>
                                      (t['roleId']?.toString() ?? '') == roleId,
                                  orElse: () => <String, dynamic>{},
                                );
                                hasExistingTariff[roleName] =
                                    existingTariff['rate']
                                        ?.toString()
                                        .isNotEmpty ??
                                    false;
                              }
                            } catch (e) {
                              // Silently fail
                            }
                            setStateDialog(() {});
                          },
                          icon: const Icon(Icons.save),
                          label: const Text('Save Tariffs'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(null),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final rates = <String, double>{};
                    for (final entry in tariffControllers.entries) {
                      final roleName = entry.key;
                      final rateStr = entry.value.text.trim();
                      if (rateStr.isNotEmpty) {
                        final rate = double.tryParse(rateStr);
                        if (rate != null) {
                          rates[roleName] = rate;
                        }
                      }
                    }
                    Navigator.of(ctx).pop(rates);
                  },
                  child: const Text('Continue'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _RoleAssignmentDialog extends StatefulWidget {
  final List<Map<String, dynamic>> users;
  final List<String> roleNames;
  final Map<String, String> initialAssignments;

  const _RoleAssignmentDialog({
    required this.users,
    required this.roleNames,
    required this.initialAssignments,
  });

  @override
  State<_RoleAssignmentDialog> createState() => _RoleAssignmentDialogState();
}

class _RoleAssignmentDialogState extends State<_RoleAssignmentDialog> {
  late Map<String, String> assignments;

  @override
  void initState() {
    super.initState();
    assignments = Map.from(widget.initialAssignments);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Assign Roles to Staff'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: widget.users.length,
          itemBuilder: (context, index) {
            final user = widget.users[index];
            final userKey = user['key'] as String;
            final userName = user['name'] as String? ?? 'Unknown';
            final userEmail = user['email'] as String? ?? '';

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userName.isNotEmpty ? userName : userEmail,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    if (userName.isNotEmpty && userEmail.isNotEmpty)
                      Text(
                        userEmail,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: assignments[userKey],
                      decoration: const InputDecoration(
                        labelText: 'Role',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      items: widget.roleNames.map((role) {
                        return DropdownMenuItem(
                          value: role,
                          child: Text(role),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            assignments[userKey] = value;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(assignments),
          child: const Text('Send Invitations'),
        ),
      ],
    );
  }
}
