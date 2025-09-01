import 'package:flutter/material.dart';

import '../services/event_service.dart';
import '../services/pending_events_service.dart';
import '../services/users_service.dart';

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

  bool _everyone = true;
  final TextEditingController _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _users = const [];
  String? _cursor;
  bool _loadingUsers = false;
  final Set<String> _selectedKeys = <String>{};
  final Map<String, Map<String, String>> _keyToUser =
      <String, Map<String, String>>{};
  bool _publishing = false;

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
      if (payload['roles'] is! List || (payload['roles'] as List).isEmpty) {
        final counts = await _promptRoleCounts(payload);
        if (counts == null) {
          setState(() => _publishing = false);
          return;
        }
        payload['roles'] = _countsToRoles(counts);
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
                          if (idx >= _users.length)
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(12),
                                child: CircularProgressIndicator(),
                              ),
                            );
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
    final bartenders = TextEditingController(
      text: extract(existing, 'bartender').toString(),
    );
    final servers = TextEditingController(
      text: extract(existing, 'server').toString(),
    );
    final dishwashers = TextEditingController(
      text: extract(existing, 'dishwasher').toString(),
    );
    final captain = TextEditingController(
      text: extract(existing, 'captain').toString(),
    );
    final delivery = TextEditingController(
      text: extract(existing, 'delivery').toString(),
    );

    return showDialog<Map<String, int>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Set roles for this event'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _numField(bartenders, 'Bartenders'),
              const SizedBox(height: 8),
              _numField(servers, 'Servers'),
              const SizedBox(height: 8),
              _numField(dishwashers, 'Dishwashers'),
              const SizedBox(height: 8),
              _numField(captain, 'Catering Captain (optional)'),
              const SizedBox(height: 8),
              _numField(delivery, 'Delivery Driver (optional)'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop({
                'bartender': int.tryParse(bartenders.text.trim()) ?? 0,
                'server': int.tryParse(servers.text.trim()) ?? 0,
                'dishwasher': int.tryParse(dishwashers.text.trim()) ?? 0,
                'captain': int.tryParse(captain.text.trim()) ?? 0,
                'delivery': int.tryParse(delivery.text.trim()) ?? 0,
              });
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
    void add(String name, int value) {
      if (value > 0) list.add({'role': name, 'count': value});
    }

    add('Bartender', counts['bartender'] ?? 0);
    add('Server', counts['server'] ?? 0);
    add('Dishwasher', counts['dishwasher'] ?? 0);
    add('Catering Captain', counts['captain'] ?? 0);
    add('Delivery Driver', counts['delivery'] ?? 0);
    return list;
  }
}
