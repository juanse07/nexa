import 'package:flutter/material.dart';

import '../services/event_service.dart';
import '../services/pending_events_service.dart';
import '../services/roles_service.dart';
import '../services/users_service.dart';
import '../services/clients_service.dart';
import '../services/tariffs_service.dart';

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
  final PendingEventsService _pendingService = PendingEventsService();
  final EventService _eventService = EventService();
  final RolesService _rolesService = RolesService();
  final ClientsService _clientsService = ClientsService();
  final TariffsService _tariffsService = TariffsService();

  bool _everyone = true;
  final TextEditingController _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _users = const [];
  List<Map<String, dynamic>> _roles = const [];
  List<Map<String, dynamic>> _clients = const [];
  String? _cursor;
  bool _loadingUsers = false;
  final Set<String> _selectedKeys = <String>{};
  final Map<String, Map<String, String>> _keyToUser =
      <String, Map<String, String>>{};
  bool _publishing = false;
  final Map<String, TextEditingController> _roleCountCtrls =
      <String, TextEditingController>{};

  @override
  void initState() {
    super.initState();
    _loadRoles();
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
  }

  Future<void> _loadRoles() async {
    try {
      final roles = await _rolesService.fetchRoles();
      setState(() => _roles = roles);
    } catch (e) {
      // Silently fail, roles will be empty
    }
  }

  Future<void> _loadUsers({bool reset = false}) async {
    if (_loadingUsers) return;
    setState(() => _loadingUsers = true);
    try {
      final res = await _usersService.fetchUsers(
        q: _searchCtrl.text.trim(),
        cursor: reset ? null : _cursor,
        limit: 20,
      );
      final items =
          (res['items'] as List?)?.whereType<Map<String, dynamic>>().toList() ??
          const [];
      setState(() {
        _users = reset ? items : [..._users, ...items];
        _cursor = (res['nextCursor'] as String?).toString();
        for (final u in items) {
          final key = '${u['provider']}:${u['subject']}';
          _keyToUser[key] = {
            'name': (u['name'] ?? '').toString(),
            'email': (u['email'] ?? '').toString(),
          };
        }
      });
    } finally {
      setState(() => _loadingUsers = false);
    }
  }

  Future<void> _publish() async {
    if (!_everyone && _selectedKeys.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Select at least one user')));
      return;
    }
    setState(() => _publishing = true);
    try {
      final payload = Map<String, dynamic>.from(widget.draft);

      // First, pick client
      final clientData = await _promptClientPicker();
      if (clientData == null) {
        setState(() => _publishing = false);
        return;
      }
      final clientName = (clientData['name'] ?? '').toString();
      final rawClientId = (clientData['id'] ?? '').toString();
      final clientId = rawClientId.isNotEmpty ? rawClientId : null;
      payload['client_name'] = clientName;
      if (clientId != null) {
        payload['clientId'] = clientId;
        payload['client_id'] = clientId;
      }

      // Then, ensure role counts are set at publish time
      final counts = await _promptRoleCounts(payload);
      if (counts == null) {
        setState(() => _publishing = false);
        return;
      }
      final roleDefs = _countsToRoles(counts);
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

      if (!_everyone) {
        payload['audience_user_keys'] = _selectedKeys.toList();
      }
      await _eventService.createEvent(payload);
      await _pendingService.deleteDraft(widget.draftId);
      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Event published')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Publish failed: $e')));
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.draft;
    final client = (data['client_name'] ?? '').toString();
    final name = (data['event_name'] ?? data['venue_name'] ?? 'Untitled')
        .toString();
    final date = (data['date'] ?? '').toString();
    return Scaffold(
      appBar: AppBar(title: const Text('Publish Event')),
      body: Column(
        children: [
          Padding(
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
                  title: const Text('Visible to everyone'),
                  value: _everyone,
                  onChanged: (v) => setState(() => _everyone = v),
                ),
                if (!_everyone) ...[
                  TextField(
                    controller: _searchCtrl,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Search users',
                    ),
                    onSubmitted: (_) => _loadUsers(reset: true),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 220,
                    child: NotificationListener<ScrollNotification>(
                      onNotification: (n) {
                        if (n.metrics.pixels >=
                                n.metrics.maxScrollExtent - 100 &&
                            _cursor != null) {
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
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _publishing ? null : _publish,
                child: Text(_publishing ? 'Publishing...' : 'Publish'),
              ),
            ),
          ),
        ],
      ),
    );
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
              title: const Text('Set roles for this event'),
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
