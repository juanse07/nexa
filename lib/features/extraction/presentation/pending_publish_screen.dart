import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nexa/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/event_service.dart';
import '../services/group_service.dart';
import '../services/roles_service.dart';
import '../services/users_service.dart';
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
  final UsersService _usersService = UsersService();
  final EventService _eventService = EventService();
  final RolesService _rolesService = RolesService();
  final ClientsService _clientsService = ClientsService();
  final TariffsService _tariffsService = TariffsService();
  final TeamsService _teamsService = TeamsService();
  final GroupService _groupService = GroupService();
  final ChatService _chatService = ChatService();
  StreamSubscription<SocketEvent>? _socketSubscription;

  bool _visibleToEntireTeam = false;
  String? _selectedVisibilityTeamId; // Team for "visible to entire team" mode
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
  Set<String> _favoriteUsers = {};
  String? _selectedRoleFilter; // For filtering favorites by role
  // Visibility type is now automatically determined:
  // - 'private' when sending direct invitations through chat
  // - 'public' when publishing to teams

  @override
  void initState() {
    super.initState();
    _loadRoles();
    _loadTeams();
    _loadGroups();
    _loadFavorites();
    // Load users immediately since _visibleToEntireTeam is false by default
    _loadUsers(reset: true);
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

  Future<void> _loadUsers({bool reset = false}) async {
    if (_loadingUsers) return;
    setState(() => _loadingUsers = true);
    try {
      final res = await _usersService.fetchTeamMembers(
        q: _searchCtrl.text.trim(),
        cursor: reset ? null : _cursor,
        limit: 20,
      );
      final items =
          (res['items'] as List?)?.whereType<Map<String, dynamic>>().toList() ??
          const [];
      setState(() {
        _users = reset ? items : [..._users, ...items];
        _cursor = res['nextCursor'] as String?;
        for (final u in items) {
          final key = '${u['provider']}:${u['subject']}';
          _keyToUser[key] = {
            'name': (u['name'] ?? '').toString(),
            'email': (u['email'] ?? '').toString(),
            'id': (u['id'] ?? u['_id'] ?? '').toString(),
            'subject': (u['subject'] ?? '').toString(),
            'provider': (u['provider'] ?? '').toString(),
            'first_name': (u['first_name'] ?? '').toString(),
            'last_name': (u['last_name'] ?? '').toString(),
          };
        }
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
      });
    } catch (e) {
      setState(() => _loadingTeams = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load teams: $e')));
      }
    }
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _favoriteUsers = prefs.getStringList('favorite_users')?.toSet() ?? {};
    });
  }

  List<Map<String, dynamic>> get _favoriteUsersList {
    if (_users.isEmpty) return [];

    // Filter users by favorites
    final favorites = _users.where((user) {
      final key = '${user['provider']}:${user['subject']}';
      // Check if user is a favorite with any role OR with the selected role filter
      if (_selectedRoleFilter != null) {
        return _favoriteUsers.contains('$key:$_selectedRoleFilter');
      } else {
        // Check if user is favorite with any role
        return _favoriteUsers.any((fav) => fav.startsWith('$key:'));
      }
    }).toList();

    return favorites;
  }

  void _selectAllFavorites() {
    setState(() {
      for (final user in _favoriteUsersList) {
        final key = '${user['provider']}:${user['subject']}';
        _selectedKeys.add(key);
      }
    });
  }

  void _deselectAllFavorites() {
    setState(() {
      for (final user in _favoriteUsersList) {
        final key = '${user['provider']}:${user['subject']}';
        _selectedKeys.remove(key);
      }
    });
  }

  List<String> get _availableRoleFilters {
    return _roles.map((r) => (r['name'] ?? '').toString())
        .where((name) => name.isNotEmpty)
        .toList();
  }

  Future<void> _sendDirectInvitations() async {
    if (_selectedKeys.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
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
            ScaffoldMessenger.of(context).showSnackBar(
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

      // Prompt for role assignments
      final userRoleAssignments = await _promptRoleAssignmentsForUsers(roleDefs);
      if (userRoleAssignments == null) {
        print('[DIRECT INVITATIONS] User cancelled role assignment');
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Invitations sent: $successCount successful${failureCount > 0 ? ", $failureCount failed" : ""}. Event published privately - only invited staff can see it.',
          ),
          backgroundColor: successCount > 0 ? Colors.green : Colors.orange,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send invitations: $e')),
      );
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  Future<void> _publish() async {
    if (!_visibleToEntireTeam && _selectedKeys.isEmpty && _selectedTeamIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one user or team')),
      );
      return;
    }
    if (_visibleToEntireTeam && _selectedVisibilityTeamId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a team for visibility')),
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
            ScaffoldMessenger.of(context).showSnackBar(
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
      // This properly transitions status from 'draft' → 'published' with metadata
      final List<String> audienceUserKeys;
      final List<String> audienceTeamIds;

      if (_visibleToEntireTeam) {
        // When visible to entire team, send only the team ID in audience_team_ids
        audienceUserKeys = const <String>[];
        audienceTeamIds = [_selectedVisibilityTeamId!];
      } else {
        // Specific user/team selection
        audienceUserKeys = _selectedKeys.toList();
        audienceTeamIds = _selectedTeamIds.toList();
      }

      print('[PUBLISH] About to publish event: ${widget.draftId}');
      print('[PUBLISH] audienceUserKeys: $audienceUserKeys');
      print('[PUBLISH] audienceTeamIds: $audienceTeamIds');

      // Automatically set visibility to 'public' when publishing to teams
      final publishedEvent = await _eventService.publishEvent(
        widget.draftId,
        audienceUserKeys: audienceUserKeys,
        audienceTeamIds: audienceTeamIds,
        audienceGroupIds: _selectedGroupIds.isNotEmpty ? _selectedGroupIds.toList() : null,
        visibilityType: 'public',
      );

      print('[PUBLISH] ✓ Event published successfully');
      final eventId = (publishedEvent['_id'] ?? publishedEvent['id'] ?? '').toString();
      print('[PUBLISH] Event ID: $eventId');

      // Send individual invitations to selected users via chat
      // IMPORTANT: Wrap invitation sending in try-catch to ensure screen closes even if this fails
      // Only send individual invitations when NOT publishing to entire team
      String publishMessage = AppLocalizations.of(context)!.jobPosted;
      if (!_visibleToEntireTeam && _selectedKeys.isNotEmpty && eventId.isNotEmpty) {
        print('[PUBLISH] Will send individual invitations to ${_selectedKeys.length} users');
        try {
          await _sendJobInvitationsToUsers(eventId, publishedEvent, roleDefs);
          publishMessage = '${AppLocalizations.of(context)!.jobPosted} and invitations sent';
          print('[PUBLISH] ✓ Invitations sent successfully');
        } catch (e) {
          print('[PUBLISH] ✗ Failed to send invitations: $e');
          publishMessage = '${AppLocalizations.of(context)!.jobPosted}, but some invitations failed';
        }
      } else {
        print('[PUBLISH] Skipping individual invitations (visibleToEntireTeam: $_visibleToEntireTeam, selectedKeys: ${_selectedKeys.length})');
      }

      print('[PUBLISH] Closing publish screen and showing success message');
      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(publishMessage)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Publish failed: $e')));
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  Future<void> _sendJobInvitationsToUsers(
    String eventId,
    Map<String, dynamic> eventData,
    List<Map<String, dynamic>> roles,
  ) async {
    print('[PUBLISH] Sending job invitations to ${_selectedKeys.length} users');

    if (roles.isEmpty) {
      print('[PUBLISH] No roles defined, skipping invitations');
      return;
    }

    // Prompt user to select role for each selected user
    final userRoleAssignments = await _promptRoleAssignmentsForUsers(roles);
    if (userRoleAssignments == null) {
      print('[PUBLISH] User cancelled role assignment');
      return;
    }

    // For each selected user, send them a job invitation via chat with their assigned role
    for (final entry in userRoleAssignments.entries) {
      final userKey = entry.key;
      final roleId = entry.value;

      if (roleId == null || roleId.isEmpty) {
        print('[PUBLISH] Skipping $userKey - no role assigned');
        continue;
      }

      try {
        print('[PUBLISH] Sending invitation to $userKey for role $roleId');

        await _chatService.sendEventInvitation(
          targetId: userKey,
          eventId: eventId,
          roleId: roleId,
          eventData: eventData,
        );

        print('[PUBLISH] Successfully sent invitation to $userKey');
      } catch (e) {
        print('[PUBLISH] Failed to send invitation to $userKey: $e');
        // Continue sending to other users even if one fails
      }
    }
  }

  Future<Map<String, String>?> _promptRoleAssignmentsForUsers(
    List<Map<String, dynamic>> roles,
  ) async {
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
    for (final userKey in _selectedKeys) {
      assignments[userKey] = roleNames.first;
    }

    final result = await showDialog<Map<String, String>?>(
      context: context,
      barrierDismissible: true, // Allow dismissing by tapping outside
      builder: (context) => _RoleAssignmentDialog(
        users: _selectedKeys.map((key) {
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
    final data = widget.draft;
    final client = (data['client_name'] ?? '').toString();
    final name = (data['event_name'] ?? data['venue_name'] ?? 'Untitled')
        .toString();
    final date = (data['date'] ?? '').toString();
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.postJob)),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(
                  client.isNotEmpty ? client : 'Client',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    name,
                    date,
                  ].where((s) => s.toString().isNotEmpty).join(' • '),
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Visible to entire team'),
                  value: _visibleToEntireTeam,
                  onChanged: (v) {
                    setState(() {
                      _visibleToEntireTeam = v;
                      // Auto-select first team if enabling and no team selected
                      if (_visibleToEntireTeam &&
                          _selectedVisibilityTeamId == null &&
                          _teams.isNotEmpty) {
                        _selectedVisibilityTeamId =
                            (_teams.first['id'] ?? '').toString();
                      }
                    });
                  },
                ),
                if (_visibleToEntireTeam) ...[
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _selectedVisibilityTeamId,
                    decoration: const InputDecoration(
                      labelText: 'Select team',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                    hint: const Text('Select team'),
                    items: _teams.map((team) {
                      final teamId = (team['id'] ?? '').toString();
                      final name = (team['name'] ?? 'Untitled team').toString();
                      return DropdownMenuItem(
                        value: teamId,
                        child: Text(name),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() => _selectedVisibilityTeamId = value);
                    },
                  ),
                ],
                const SizedBox(height: 16),
                // No explicit visibility selector - determined by button pressed
                if (!_visibleToEntireTeam) ...[
                  _buildTeamSelector(),
                  _buildGroupSelector(),
                  _buildFavoritesSection(),
                  const SizedBox(height: 16),
                  const Text(
                    'Team Members',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _searchCtrl,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Search team members',
                    ),
                    onChanged: (_) => _loadUsers(reset: true),
                    onSubmitted: (_) => _loadUsers(reset: true),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 220,
                    child: _users.isEmpty && !_loadingUsers
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(
                                _searchCtrl.text.trim().isEmpty
                                    ? 'No team members yet.\nAdd members to your teams first.'
                                    : 'No team members found matching "${_searchCtrl.text.trim()}"',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                            ),
                          )
                        : NotificationListener<ScrollNotification>(
                            onNotification: (n) {
                              if (n.metrics.pixels >=
                                      n.metrics.maxScrollExtent - 100 &&
                                  _cursor != null &&
                                  _cursor != 'null' &&
                                  !_loadingUsers) {
                                _loadUsers();
                              }
                              return false;
                            },
                            child: ListView.builder(
                              itemCount: _users.length + (_loadingUsers ? 1 : 0),
                              itemBuilder: (ctx, idx) {
                                if (idx >= _users.length) {
                                  return const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(12),
                                      child: CircularProgressIndicator(),
                                    ),
                                  );
                                }
                                final u = _users[idx];
                                final key = '${u['provider']}:${u['subject']}';
                                final selected = _selectedKeys.contains(key);
                                return CheckboxListTile(
                                  value: selected,
                                  onChanged: (_) {
                                    setState(() {
                                      if (selected) {
                                        _selectedKeys.remove(key);
                                      } else {
                                        _selectedKeys.add(key);
                                      }
                                    });
                                  },
                                  title: Text(
                                    (u['name'] ?? u['email'] ?? key).toString(),
                                  ),
                                  subtitle: Text((u['email'] ?? '').toString()),
                                );
                              },
                            ),
                          ),
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _selectedKeys.map((k) {
                      final info = _keyToUser[k] ?? const {};
                      final display = [
                        (info['name'] ?? '').toString(),
                        (info['email'] ?? '').toString(),
                      ].where((s) => s.isNotEmpty).join(' — ');
                      return Chip(
                        label: Text(display.isNotEmpty ? display : k),
                      );
                    }).toList(),
                  ),
                ],
                  ],
                ),
              ),
            ),
          ),
          // Pinned action buttons at bottom
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Send Direct Invitations button (keeps event private/draft)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _publishing ? null : _sendDirectInvitations,
                        icon: const Icon(Icons.mail_outline),
                        label: const Text(
                          'Send Direct Invitations (Private)',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: const BorderSide(color: AppColors.techBlue, width: 2),
                          foregroundColor: AppColors.techBlue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Event stays private - only invited people can see it',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    // Publish to Team button (makes event public)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _publishing ? null : _publish,
                        icon: const Icon(Icons.campaign),
                        label: Text(
                          _publishing ? 'Publishing...' : 'Publish to Team/Public',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: AppColors.techBlue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Event becomes visible to selected teams/members',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
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
            const Text(
              'Target teams',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: _openTeamsManagement,
              icon: const Icon(Icons.groups_outlined),
              label: const Text('Manage teams'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_loadingTeams)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: LinearProgressIndicator(minHeight: 2),
          )
        else if (!hasTeams)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'Create a team to target groups of workers.',
              style: TextStyle(color: Colors.grey.shade600),
            ),
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
        const Row(
          children: [
            Icon(Icons.group_work, size: 18, color: Colors.deepPurple),
            SizedBox(width: 8),
            Text(
              'Staff Groups',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_loadingGroups)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: LinearProgressIndicator(minHeight: 2),
          )
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

  Widget _buildFavoritesSection() {
    final favorites = _favoriteUsersList;
    final allFavoritesSelected = favorites.isNotEmpty &&
        favorites.every((user) {
          final key = '${user['provider']}:${user['subject']}';
          return _selectedKeys.contains(key);
        });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.star, color: Colors.amber, size: 20),
            const SizedBox(width: 8),
            const Text(
              'Favorites',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            const Spacer(),
            if (favorites.isNotEmpty)
              TextButton(
                onPressed: allFavoritesSelected
                    ? _deselectAllFavorites
                    : _selectAllFavorites,
                child: Text(
                  allFavoritesSelected ? 'Deselect All' : 'Select All',
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        // Role filter dropdown
        if (_availableRoleFilters.isNotEmpty)
          DropdownButtonFormField<String>(
            value: _selectedRoleFilter,
            decoration: InputDecoration(
              labelText: 'Filter by role',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              prefixIcon: const Icon(Icons.filter_list),
            ),
            items: [
              const DropdownMenuItem<String>(
                value: null,
                child: Text('All roles'),
              ),
              ..._availableRoleFilters.map((role) {
                return DropdownMenuItem<String>(
                  value: role,
                  child: Text(role),
                );
              }).toList(),
            ],
            onChanged: (value) {
              setState(() => _selectedRoleFilter = value);
            },
          ),
        const SizedBox(height: 12),
        if (favorites.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              _selectedRoleFilter != null
                  ? 'No favorites found for $_selectedRoleFilter'
                  : 'No favorites yet. Favorite users from chat to see them here.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: favorites.map((user) {
              final key = '${user['provider']}:${user['subject']}';
              final name = (user['name'] ?? user['email'] ?? key).toString();
              final isSelected = _selectedKeys.contains(key);
              return FilterChip(
                selected: isSelected,
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star, size: 14, color: Colors.amber),
                    const SizedBox(width: 4),
                    Text(name),
                  ],
                ),
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedKeys.add(key);
                    } else {
                      _selectedKeys.remove(key);
                    }
                  });
                },
              );
            }).toList(),
          ),
      ],
    );
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
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Role "$newName" created'),
                                ),
                              );
                            } catch (e) {
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
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
                        ScaffoldMessenger.of(context).showSnackBar(
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
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to create client: $e')),
                      );
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
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Failed to save tariff for $roleName: $e',
                                    ),
                                  ),
                                );
                              }
                            }

                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
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
