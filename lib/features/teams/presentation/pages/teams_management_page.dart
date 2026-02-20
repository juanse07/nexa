import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nexa/core/network/socket_manager.dart';
import 'package:nexa/features/teams/data/services/teams_service.dart';
import 'package:nexa/features/teams/presentation/pages/team_detail_page.dart';
import 'package:nexa/l10n/app_localizations.dart';

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
    final l10n = AppLocalizations.of(context)!;
    final nameCtrl = TextEditingController();
    final descriptionCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.createTeamTitle),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameCtrl,
                decoration: InputDecoration(labelText: l10n.teamNameLabel),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return l10n.enterTeamNameError;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: descriptionCtrl,
                minLines: 2,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: l10n.descriptionOptional,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
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
                  SnackBar(content: Text('${l10n.failedToCreateTeam}: $e')),
                );
              }
            },
            child: Text(l10n.create),
          ),
        ],
      ),
    );

    if (created == true) {
      await _loadTeams();
    }
  }

  Future<void> _deleteTeam(String teamId) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteTeamConfirmation),
        content: Text(l10n.deleteTeamWarning),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: Text(l10n.delete),
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
      ).showSnackBar(SnackBar(content: Text(l10n.teamDeleted)));
      await _loadTeams();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${l10n.failedToDeleteTeam}: $e')));
    }
  }

  Future<void> _openTeamDetail(Map<String, dynamic> team) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => TeamDetailPage(
          teamId: (team['id'] ?? '').toString(),
          teamName: (team['name'] ?? '').toString(),
          isOwner: team['isOwner'] as bool? ?? true,
        ),
      ),
    );
    await _loadTeams();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: Navigator.of(context).canPop(),
        leading: Navigator.of(context).canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).maybePop(),
              )
            : null,
        title: Text(l10n.teams),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createTeam,
        icon: const Icon(Icons.group_add),
        label: Text(l10n.newTeam),
      ),
      body: RefreshIndicator(onRefresh: _loadTeams, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    final l10n = AppLocalizations.of(context)!;
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
                Text(
                  l10n.somethingWentWrong,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text(_error!),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _loadTeams,
                  child: Text(l10n.retry),
                ),
              ],
            ),
          ),
        ],
      );
    }
    if (_teams.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 48),
          const Icon(Icons.groups_outlined, size: 48, color: Colors.grey),
          const SizedBox(height: 12),
          Center(child: Text(l10n.noTeamsYet)),
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
        final memberCount = (team['memberCount'] as int?) ?? 0;
        final pendingInvites = (team['pendingInvites'] as int?) ?? 0;
        final isOwner = team['isOwner'] as bool? ?? true;
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
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              name.isEmpty ? l10n.untitledTeam : name,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (!isOwner) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF6366F1).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                l10n.coManager,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFF6366F1),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (isOwner)
                      IconButton(
                        onPressed: () {
                          final teamId = (team['id'] ?? '').toString();
                          if (teamId.isEmpty) return;
                          _deleteTeam(teamId);
                        },
                        icon: const Icon(Icons.delete_outline),
                        color: Colors.redAccent,
                        tooltip: l10n.deleteTeamConfirmation,
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
                      label: Text(l10n.members(memberCount)),
                    ),
                    const SizedBox(width: 8),
                    Chip(
                      avatar: const Icon(Icons.mark_email_unread, size: 18),
                      label: Text(l10n.pendingInvites(pendingInvites)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => _openTeamDetail(team),
                    child: Text(l10n.viewDetails),
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
