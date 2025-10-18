import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nexa/core/network/socket_manager.dart';
import 'package:nexa/features/teams/data/services/teams_service.dart';
import 'package:nexa/features/teams/presentation/pages/team_detail_page.dart';

class TeamsManagementPage extends StatefulWidget {
  const TeamsManagementPage({super.key});

  @override
  State<TeamsManagementPage> createState() => _TeamsManagementPageState();
}

class _TeamsManagementPageState extends State<TeamsManagementPage> {
  final TeamsService _teamsService = TeamsService();
  StreamSubscription<SocketEvent>? _socketSubscription;

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _teams = const [];

  @override
  void initState() {
    super.initState();
    _loadTeams();
    _socketSubscription = SocketManager.instance.events.listen((event) {
      if (!mounted) return;
      if (event.event.startsWith('team:')) {
        _loadTeams();
      }
    });
  }

  Future<void> _loadTeams() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final teams = await _teamsService.fetchTeams();
      setState(() {
        _teams = teams;
        _loading = false;
      });
      final ids = teams
          .map((team) => (team['id'] ?? '').toString())
          .where((id) => id.isNotEmpty)
          .toList();
      await SocketManager.instance.joinTeams(ids);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _socketSubscription?.cancel();
    super.dispose();
  }

  Future<void> _createTeam() async {
    final nameCtrl = TextEditingController();
    final descriptionCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create Team'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Team name'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Enter a team name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: descriptionCtrl,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!(formKey.currentState?.validate() ?? false)) {
                return;
              }
              try {
                await _teamsService.createTeam(
                  name: nameCtrl.text.trim(),
                  description: descriptionCtrl.text.trim(),
                );
                if (!mounted) return;
                Navigator.of(ctx).pop(true);
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to create team: $e')),
                );
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (created == true) {
      await _loadTeams();
    }
  }

  Future<void> _deleteTeam(String teamId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete team?'),
        content: const Text(
          'Deleting this team will remove it permanently. Events that reference it will block deletion.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _teamsService.deleteTeam(teamId);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Team deleted')));
      await _loadTeams();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to delete team: $e')));
    }
  }

  Future<void> _openTeamDetail(Map<String, dynamic> team) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => TeamDetailPage(
          teamId: (team['id'] ?? '').toString(),
          teamName: (team['name'] ?? '').toString(),
        ),
      ),
    );
    await _loadTeams();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: Navigator.of(context).canPop(),
        leading: Navigator.of(context).canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).maybePop(),
              )
            : null,
        title: const Text('Teams'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createTeam,
        icon: const Icon(Icons.group_add),
        label: const Text('New team'),
      ),
      body: RefreshIndicator(onRefresh: _loadTeams, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Something went wrong',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text(_error!),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _loadTeams,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ],
      );
    }
    if (_teams.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 48),
          Icon(Icons.groups_outlined, size: 48, color: Colors.grey),
          SizedBox(height: 12),
          Center(child: Text('No teams yet. Tap “New team” to create one.')),
        ],
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _teams.length,
      itemBuilder: (context, index) {
        final team = _teams[index];
        final name = (team['name'] ?? '').toString();
        final description = (team['description'] ?? '').toString();
        final memberCount = team['memberCount'] ?? 0;
        final pendingInvites = team['pendingInvites'] ?? 0;
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 1,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name.isEmpty ? 'Untitled team' : name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        final teamId = (team['id'] ?? '').toString();
                        if (teamId.isEmpty) return;
                        _deleteTeam(teamId);
                      },
                      icon: const Icon(Icons.delete_outline),
                      color: Colors.redAccent,
                      tooltip: 'Delete team',
                    ),
                  ],
                ),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    description,
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Chip(
                      avatar: const Icon(Icons.people_alt, size: 18),
                      label: Text(
                        '$memberCount member${memberCount == 1 ? '' : 's'}',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Chip(
                      avatar: const Icon(Icons.mark_email_unread, size: 18),
                      label: Text(
                        '$pendingInvites pending invite${pendingInvites == 1 ? '' : 's'}',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => _openTeamDetail(team),
                    child: const Text('View details'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
