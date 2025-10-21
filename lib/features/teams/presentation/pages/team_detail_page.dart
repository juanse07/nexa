import 'package:flutter/material.dart';
import 'package:nexa/features/teams/data/services/teams_service.dart';
import 'package:nexa/features/extraction/services/users_service.dart';
import 'package:nexa/features/chat/presentation/chat_screen.dart';
import 'package:nexa/features/teams/presentation/widgets/create_invite_link_dialog.dart';

class TeamDetailPage extends StatefulWidget {
  const TeamDetailPage({
    super.key,
    required this.teamId,
    required this.teamName,
  });

  final String teamId;
  final String teamName;

  @override
  State<TeamDetailPage> createState() => _TeamDetailPageState();
}

class _TeamDetailPageState extends State<TeamDetailPage> {
  final TeamsService _teamsService = TeamsService();
  final UsersService _usersService = UsersService();

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _members = const [];
  List<Map<String, dynamic>> _invites = const [];
  List<Map<String, dynamic>> _inviteLinks = const [];
  bool _addingMember = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _teamsService.fetchMembers(widget.teamId),
        _teamsService.fetchInvites(widget.teamId),
        _teamsService.fetchInviteLinks(widget.teamId),
      ]);
      setState(() {
        _members = results[0];
        _invites = results[1];
        _inviteLinks = results[2];
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _removeMember(String memberId) async {
    try {
      await _teamsService.removeMember(
        teamId: widget.teamId,
        memberId: memberId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Member removed')));
      await _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to remove member: $e')));
    }
  }

  Future<void> _sendInvite() async {
    final emailCtrl = TextEditingController();
    final messageCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final sent = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Invite by email'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: emailCtrl,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Enter an email';
                  }
                  if (!value.contains('@')) {
                    return 'Enter a valid email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: messageCtrl,
                decoration: const InputDecoration(
                  labelText: 'Message (optional)',
                ),
                minLines: 2,
                maxLines: 4,
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
                await _teamsService.createInvites(
                  teamId: widget.teamId,
                  recipients: [
                    {'email': emailCtrl.text.trim()},
                  ],
                  message: messageCtrl.text.trim().isEmpty
                      ? null
                      : messageCtrl.text.trim(),
                );
                if (!mounted) return;
                Navigator.of(ctx).pop(true);
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to send invite: $e')),
                );
              }
            },
            child: const Text('Send invite'),
          ),
        ],
      ),
    );

    if (sent == true) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invite sent to ${emailCtrl.text.trim()}')),
      );
      await _loadData();
    }
  }

  Future<void> _createInviteLink() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => CreateInviteLinkDialog(
        teamName: widget.teamName,
        onCreateLink: ({
          int? expiresInDays,
          int? maxUses,
          bool requireApproval = false,
        }) async {
          return await _teamsService.createInviteLink(
            teamId: widget.teamId,
            expiresInDays: expiresInDays,
            maxUses: maxUses,
            requireApproval: requireApproval,
          );
        },
      ),
    );

    if (result == true && mounted) {
      // Refresh data to show new invite in the list
      await _loadData();
    }
  }

  Future<void> _openAddMemberSheet() async {
    if (_addingMember) return;
    final existingKeys = _members
        .map(
          (member) =>
              '${(member['provider'] ?? '').toString()}:${(member['subject'] ?? '').toString()}',
        )
        .toSet();

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        final searchCtrl = TextEditingController();
        List<Map<String, dynamic>> results = const [];
        String? cursor;
        bool loading = false;
        String? error;
        String currentQuery = '';
        bool initialized = false;

        Future<void> performSearch(
          StateSetter setStateSheet, {
          bool reset = true,
        }) async {
          if (loading) return;
          setStateSheet(() {
            loading = true;
            if (reset) error = null;
          });
          try {
            final response = await _usersService.fetchUsers(
              q: currentQuery.trim().isEmpty ? null : currentQuery.trim(),
              cursor: reset ? null : cursor,
              limit: 25,
            );
            final items =
                (response['items'] as List?)
                    ?.whereType<Map>()
                    .map((e) => e.cast<String, dynamic>())
                    .toList() ??
                const <Map<String, dynamic>>[];
            final nextCursor = response['nextCursor']?.toString();
            cursor = (nextCursor != null && nextCursor.isNotEmpty)
                ? nextCursor
                : null;
            setStateSheet(() {
              results = reset ? items : [...results, ...items];
            });
          } catch (e) {
            setStateSheet(() {
              error = e.toString();
            });
          } finally {
            setStateSheet(() {
              loading = false;
            });
          }
        }

        return StatefulBuilder(
          builder: (ctx, setStateSheet) {
            if (!initialized) {
              initialized = true;
              Future.microtask(() => performSearch(setStateSheet));
            }

            Future<void> onSearchSubmitted(String value) async {
              currentQuery = value;
              await performSearch(setStateSheet, reset: true);
            }

            Future<void> loadMore() async {
              if (cursor == null) return;
              await performSearch(setStateSheet, reset: false);
            }

            return Padding(
              padding: MediaQuery.of(ctx).viewInsets,
              child: SizedBox(
                height: MediaQuery.of(ctx).size.height * 0.75,
                child: Column(
                  children: [
                    AppBar(
                      automaticallyImplyLeading: false,
                      title: const Text('Add team member'),
                      actions: [
                        IconButton(
                          onPressed: () => Navigator.of(ctx).pop(false),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: TextField(
                        controller: searchCtrl,
                        textInputAction: TextInputAction.search,
                        decoration: InputDecoration(
                          hintText: 'Search by name or email',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: currentQuery.isNotEmpty
                              ? IconButton(
                                  onPressed: () {
                                    searchCtrl.clear();
                                    currentQuery = '';
                                    performSearch(setStateSheet, reset: true);
                                  },
                                  icon: const Icon(Icons.clear),
                                )
                              : null,
                        ),
                        onSubmitted: onSearchSubmitted,
                      ),
                    ),
                    if (error != null)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          error!,
                          style: const TextStyle(color: Colors.redAccent),
                        ),
                      ),
                    Expanded(
                      child: NotificationListener<ScrollNotification>(
                        onNotification: (notification) {
                          if (notification.metrics.pixels >=
                                  notification.metrics.maxScrollExtent - 80 &&
                              !loading &&
                              cursor != null) {
                            loadMore();
                          }
                          return false;
                        },
                        child: results.isEmpty && !loading
                            ? Center(
                                child: Text(
                                  'No users found. Try another search.',
                                  style: TextStyle(color: Colors.grey.shade600),
                                ),
                              )
                            : ListView.builder(
                                itemCount: results.length + (loading ? 1 : 0),
                                itemBuilder: (listCtx, index) {
                                  if (index >= results.length) {
                                    return const Padding(
                                      padding: EdgeInsets.all(16),
                                      child: Center(
                                        child: CircularProgressIndicator(),
                                      ),
                                    );
                                  }
                                  final user = results[index];
                                  final provider = (user['provider'] ?? '')
                                      .toString();
                                  final subject = (user['subject'] ?? '')
                                      .toString();
                                  final key = '$provider:$subject';
                                  final alreadyMember = existingKeys.contains(
                                    key,
                                  );
                                  final name = (user['name'] ?? '')
                                      .toString()
                                      .trim();
                                  final email = (user['email'] ?? '')
                                      .toString()
                                      .trim();
                                  final subtitle = [
                                    if (email.isNotEmpty) email,
                                    key,
                                  ].join(' • ');
                                  return ListTile(
                                    leading: const CircleAvatar(
                                      child: Icon(Icons.person_outline),
                                    ),
                                    title: Text(
                                      name.isNotEmpty
                                          ? name
                                          : email.isNotEmpty
                                          ? email
                                          : key,
                                    ),
                                    subtitle: subtitle.isEmpty
                                        ? null
                                        : Text(subtitle),
                                    trailing: alreadyMember
                                        ? const Chip(label: Text('Member'))
                                        : ElevatedButton(
                                            onPressed: _addingMember
                                                ? null
                                                : () =>
                                                      _handleAddMemberFromDirectory(
                                                        user,
                                                        ctx,
                                                      ),
                                            child: const Text('Add'),
                                          ),
                                  );
                                },
                              ),
                      ),
                    ),
                    if (loading && results.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator(),
                      ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (result == true) {
      await _loadData();
    }
  }

  Future<void> _handleAddMemberFromDirectory(
    Map<String, dynamic> user,
    BuildContext sheetContext,
  ) async {
    final provider = user['provider']?.toString().trim();
    final subject = user['subject']?.toString().trim();
    if (provider == null ||
        provider.isEmpty ||
        subject == null ||
        subject.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User is missing provider/subject information'),
        ),
      );
      return;
    }

    setState(() => _addingMember = true);
    try {
      await _teamsService.addMember(
        teamId: widget.teamId,
        provider: provider,
        subject: subject,
        email: user['email']?.toString(),
        name: user['name']?.toString(),
      );
      if (!mounted) return;
      Navigator.of(sheetContext).pop(true);
      final displayName =
          user['name']?.toString() ??
          user['email']?.toString() ??
          '$provider:$subject';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Added $displayName to the team')));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to add member: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _addingMember = false);
      }
    }
  }

  Future<void> _cancelInvite(String inviteId) async {
    try {
      await _teamsService.cancelInvite(
        teamId: widget.teamId,
        inviteId: inviteId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Invite cancelled')));
      await _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to cancel invite: $e')));
    }
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
        title: Text(widget.teamName),
        actions: [
          IconButton(
            onPressed: _sendInvite,
            icon: const Icon(Icons.mail_outline),
            tooltip: 'Send invite',
          ),
        ],
      ),
      body: RefreshIndicator(onRefresh: _loadData, child: _buildBody()),
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
                  'Could not load team data',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text(_error!),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _loadData,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            const Text(
              'Members',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_members.isEmpty)
          Text(
            'No active members yet.',
            style: TextStyle(color: Colors.grey.shade600),
          )
        else
          ..._members.map((member) {
            final name = (member['name'] ?? '').toString();
            final email = (member['email'] ?? '').toString();
            final provider = (member['provider'] ?? '').toString();
            final subject = (member['subject'] ?? '').toString();
            final memberId = (member['id'] ?? '').toString();
            final subtitle = [
              if (email.isNotEmpty) email,
              if (provider.isNotEmpty && subject.isNotEmpty)
                '$provider:$subject',
            ].join(' • ');
            final userKey = provider.isNotEmpty && subject.isNotEmpty
                ? '$provider:$subject'
                : null;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person_outline)),
                title: Text(name.isEmpty ? 'Pending member' : name),
                subtitle: subtitle.isEmpty ? null : Text(subtitle),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (userKey != null)
                      IconButton(
                        onPressed: () {
                          print('[TEAM DETAIL] Chat button pressed for userKey: $userKey');
                          print('[TEAM DETAIL] targetName: ${name.isNotEmpty ? name : email}');
                          print('[TEAM DETAIL] About to navigate to ChatScreen...');
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) {
                                print('[TEAM DETAIL] Building ChatScreen widget...');
                                return ChatScreen(
                                  targetId: userKey,
                                  targetName: name.isNotEmpty ? name : email,
                                  targetPicture: member['picture']?.toString(),
                                );
                              },
                            ),
                          ).then((value) {
                            print('[TEAM DETAIL] Navigation to ChatScreen completed');
                          }).catchError((error) {
                            print('[TEAM DETAIL ERROR] Failed to navigate to ChatScreen: $error');
                          });
                        },
                        icon: const Icon(Icons.chat_bubble_outline),
                        color: Colors.blue,
                        tooltip: 'Message',
                      ),
                    IconButton(
                      onPressed: memberId.isEmpty
                          ? null
                          : () => _removeMember(memberId),
                      icon: const Icon(Icons.remove_circle_outline),
                      color: Colors.redAccent,
                      tooltip: 'Remove',
                    ),
                  ],
                ),
              ),
            );
          }),
        const SizedBox(height: 24),
        Row(
          children: [
            const Text(
              'Invites',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: _createInviteLink,
              icon: const Icon(Icons.link),
              label: const Text('Create Invite Link'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: _sendInvite,
              icon: const Icon(Icons.mark_email_unread_outlined),
              label: const Text('Send email'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_invites.isEmpty)
          Text('No invites yet.', style: TextStyle(color: Colors.grey.shade600))
        else
          ..._invites.map((invite) {
            final status = (invite['status'] ?? '').toString();
            final email = (invite['email'] ?? '').toString();
            final provider = (invite['provider'] ?? '').toString();
            final subject = (invite['subject'] ?? '').toString();
            final inviteId = (invite['id'] ?? '').toString();
            final createdAt = invite['createdAt']?.toString();
            final subtitle =
                [
                      if (email.isNotEmpty) email,
                      if (provider.isNotEmpty && subject.isNotEmpty)
                        '$provider:$subject',
                      if (createdAt != null) createdAt,
                    ]
                    .where(
                      (value) => value != null && value.toString().isNotEmpty,
                    )
                    .join(' • ');
            final isPending = status == 'pending';
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: isPending
                      ? Colors.amber.shade100
                      : Colors.green.shade100,
                  child: Icon(
                    isPending
                        ? Icons.pending_outlined
                        : Icons.check_circle_outline,
                    color: isPending
                        ? Colors.amber.shade800
                        : Colors.green.shade700,
                  ),
                ),
                title: Text(status.toUpperCase()),
                subtitle: subtitle.isEmpty ? null : Text(subtitle),
                trailing: isPending
                    ? IconButton(
                        onPressed: inviteId.isEmpty
                            ? null
                            : () => _cancelInvite(inviteId),
                        icon: const Icon(Icons.close),
                        tooltip: 'Cancel invite',
                      )
                    : null,
              ),
            );
          }),
        // Active Invite Links Section
        if (_inviteLinks.isNotEmpty) ...[
          const SizedBox(height: 24),
          const Text(
            'Active Invite Links',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          ..._inviteLinks.map((link) {
            final shortCode = (link['shortCode'] ?? '').toString();
            final usedCount = link['usedCount'] as int? ?? 0;
            final maxUses = link['maxUses'] as int?;
            final status = (link['status'] ?? '').toString();
            final expiresAt = link['expiresAt']?.toString();

            String usageText;
            if (maxUses != null) {
              usageText = 'Used: $usedCount / $maxUses';
            } else {
              usageText = 'Used: $usedCount (unlimited)';
            }

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.blue,
                  child: Icon(Icons.link, color: Colors.white),
                ),
                title: Text('Code: $shortCode'),
                subtitle: Text('$usageText • Status: $status'),
                trailing: status == 'pending'
                    ? IconButton(
                        onPressed: () async {
                          // You can add revoke functionality here if needed
                        },
                        icon: const Icon(Icons.more_vert),
                      )
                    : null,
              ),
            );
          }).toList(),
        ],
      ],
    );
  }
}
