import 'package:flutter/material.dart';

import '../services/event_service.dart';
import '../services/pending_events_service.dart';
import '../services/roles_service.dart';
import '../services/users_service.dart';
import '../services/clients_service.dart';

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
  final Map<String, TextEditingController> _roleCountCtrls = <String, TextEditingController>{};

  @override
  void initState() {
    super.initState();
    _loadRoles();
    // Pre-fill role counts if draft already contains roles
    final roles = (widget.draft['roles'] as List?)?.whereType<Map>().toList() ?? const [];
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
      final clientName = await _promptClientPicker();
      if (clientName == null) {
        setState(() => _publishing = false);
        return;
      }
      payload['client_name'] = clientName;

      // Then, ensure role counts are set at publish time
      final counts = await _promptRoleCounts(payload);
      if (counts == null) {
        setState(() => _publishing = false);
        return;
      }
      payload['roles'] = _countsToRoles(counts);
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

    return showDialog<Map<String, int>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Set roles for this event'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: roleControllers.entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _numField(entry.value, entry.key),
              );
            }).toList(),
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
              Navigator.of(ctx).pop(counts);
            },
            child: const Text('Continue'),
          ),
        ],
      ),
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
        final properCaseName = _roles.firstWhere(
          (r) => (r['name']?.toString() ?? '').toLowerCase() == entry.key,
          orElse: () => {'name': entry.key},
        )['name']?.toString() ?? entry.key;

        list.add({'role': properCaseName, 'count': count});
      }
    }

    return list;
  }

  Future<String?> _promptClientPicker() async {
    // Load latest clients
    try {
      final clients = await _clientsService.fetchClients();
      setState(() => _clients = clients);
    } catch (e) {
      // Fail silently, clients will be empty
    }

    final TextEditingController newClientCtrl = TextEditingController();

    return showDialog<String>(
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
                            final name = (client['name'] ?? 'Unnamed').toString();
                            return ListTile(
                              title: Text(name),
                              onTap: () => Navigator.of(ctx).pop(name),
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
                      await _clientsService.createClient(newName);
                      if (!mounted) return;
                      Navigator.of(ctx).pop(newName);
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
}
