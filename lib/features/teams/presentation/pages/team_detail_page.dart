import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:share_plus/share_plus.dart';
import 'package:nexa/features/teams/data/services/teams_service.dart';
import 'package:nexa/features/extraction/services/users_service.dart';
import 'package:nexa/features/chat/presentation/chat_screen.dart';
import 'package:nexa/features/teams/presentation/widgets/create_invite_link_dialog.dart';
import 'package:nexa/features/teams/presentation/widgets/applicant_list_tile.dart';
import 'package:nexa/features/subscription/data/services/subscription_service.dart';
import 'package:nexa/features/subscription/presentation/pages/subscription_paywall_page.dart';
import 'package:nexa/l10n/app_localizations.dart';

class TeamDetailPage extends StatefulWidget {
  const TeamDetailPage({
    super.key,
    required this.teamId,
    required this.teamName,
    this.isOwner = true,
  });

  final String teamId;
  final String teamName;
  final bool isOwner;

  @override
  State<TeamDetailPage> createState() => _TeamDetailPageState();
}

class _TeamDetailPageState extends State<TeamDetailPage> {
  final TeamsService _teamsService = TeamsService();
  final UsersService _usersService = UsersService();
  final SubscriptionService _subscriptionService = GetIt.instance<SubscriptionService>();

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _members = const [];
  List<Map<String, dynamic>> _invites = const [];
  List<Map<String, dynamic>> _inviteLinks = const [];
  List<Map<String, dynamic>> _applicants = const [];
  List<Map<String, dynamic>> _coManagers = const [];
  bool _addingMember = false;
  String? _processingApplicantId;

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
      // Fetch applicants and co-managers separately — endpoints may not be deployed yet
      List<Map<String, dynamic>> applicants = const [];
      List<Map<String, dynamic>> coManagers = const [];
      try {
        applicants = await _teamsService.fetchApplicants(widget.teamId);
      } catch (_) {
        // Silently ignore — applicants endpoint may not exist yet
      }
      try {
        coManagers = await _teamsService.fetchCoManagers(widget.teamId);
      } catch (_) {
        // Silently ignore — co-managers endpoint may not exist yet
      }
      setState(() {
        _members = results[0];
        _invites = results[1];
        _inviteLinks = results[2];
        _applicants = applicants;
        _coManagers = coManagers;
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
    final l10n = AppLocalizations.of(context)!;
    try {
      await _teamsService.removeMember(
        teamId: widget.teamId,
        memberId: memberId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.memberRemovedSuccess)));
      await _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${l10n.failedToRemoveMember}: $e')));
    }
  }

  Future<void> _sendInvite() async {
    final l10n = AppLocalizations.of(context)!;
    final emailCtrl = TextEditingController();
    final messageCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final sent = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.inviteByEmail),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: emailCtrl,
                decoration: InputDecoration(labelText: l10n.email),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return l10n.enterEmailError;
                  }
                  if (!value.contains('@')) {
                    return l10n.enterValidEmailError;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: messageCtrl,
                decoration: InputDecoration(
                  labelText: l10n.messageOptional,
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
            child: Text(l10n.cancel),
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
                  SnackBar(content: Text('${l10n.failedToSendInvite}: $e')),
                );
              }
            },
            child: Text(l10n.sendInvite),
          ),
        ],
      ),
    );

    if (sent == true) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.inviteSentTo(emailCtrl.text.trim()))),
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
          String? password,
        }) async {
          return await _teamsService.createInviteLink(
            teamId: widget.teamId,
            expiresInDays: expiresInDays,
            maxUses: maxUses,
            requireApproval: requireApproval,
            password: password,
          );
        },
      ),
    );

    if (result == true && mounted) {
      // Refresh data to show new invite in the list
      await _loadData();
    }
  }

  Future<void> _revokeInviteLink(String inviteId) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.revokeInviteLink),
        content: Text(l10n.revokeInviteLinkConfirmation),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.revoke, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await _teamsService.revokeInviteLink(widget.teamId, inviteId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.inviteLinkRevoked)),
        );
        await _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppLocalizations.of(context)!.errorPrefix}: $e')),
        );
      }
    }
  }

  Future<void> _showUsageLog(String inviteId) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final data = await _teamsService.fetchInviteUsage(widget.teamId, inviteId);
      final usageLog = (data['usageLog'] as List<dynamic>?) ?? [];

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('${l10n.usageLog} (${usageLog.length})'),
          content: SizedBox(
            width: double.maxFinite,
            child: usageLog.isEmpty
                ? Text(l10n.noUsageRecorded)
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: usageLog.length,
                    itemBuilder: (_, i) {
                      final entry = usageLog[i] as Map<String, dynamic>;
                      final name = entry['userName'] ?? entry['userKey'] ?? l10n.unknown;
                      final joinedAt = entry['joinedAt']?.toString() ?? '';
                      return ListTile(
                        dense: true,
                        leading: const Icon(Icons.person, size: 20),
                        title: Text(name.toString()),
                        subtitle: Text(joinedAt),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.close)),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.errorLoadingUsage}: $e')),
        );
      }
    }
  }

  Future<void> _createPublicLink() async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final result = await _teamsService.createPublicLink(widget.teamId);
      if (!mounted) return;

      final shortCode = result['shortCode'] as String? ?? '';
      final deepLink = result['deepLink'] as String? ?? '';
      final shareableMessage = result['shareableMessage'] as String? ?? '';

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.public, color: Colors.blue),
              const SizedBox(width: 8),
              Expanded(child: Text(l10n.publicLinkCreated)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.publicLinkDescription,
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          deepLink,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 18),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: deepLink));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(l10n.linkCopied)),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${l10n.codeLabel} $shortCode',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 18),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: shortCode));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(l10n.codeCopied)),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.share),
                    label: Text(l10n.share),
                    onPressed: () {
                      Share.share(shareableMessage, subject: l10n.shareJoinTeam);
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.done),
            ),
          ],
        ),
      );

      await _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${AppLocalizations.of(context)!.errorPrefix}: $e')),
      );
    }
  }

  Future<void> _approveApplicant(String applicantId) async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _processingApplicantId = applicantId);
    try {
      await _teamsService.approveApplicant(widget.teamId, applicantId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.applicantApproved)),
      );
      await _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${AppLocalizations.of(context)!.errorPrefix}: $e')),
      );
    } finally {
      if (mounted) setState(() => _processingApplicantId = null);
    }
  }

  Future<void> _denyApplicant(String applicantId) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.denyApplicant),
        content: Text(l10n.denyApplicantConfirmation),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.deny, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _processingApplicantId = applicantId);
    try {
      await _teamsService.denyApplicant(widget.teamId, applicantId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.applicantDenied)),
      );
      await _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${AppLocalizations.of(context)!.errorPrefix}: $e')),
      );
    } finally {
      if (mounted) setState(() => _processingApplicantId = null);
    }
  }

  Future<void> _addCoManager() async {
    final l10n = AppLocalizations.of(context)!;
    final emailCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final added = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.addCoManager),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.addCoManagerInstructions,
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: emailCtrl,
                decoration: InputDecoration(labelText: l10n.managerEmailLabel),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return l10n.enterEmailError;
                  }
                  if (!value.contains('@')) {
                    return l10n.enterValidEmailError;
                  }
                  return null;
                },
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
              if (!(formKey.currentState?.validate() ?? false)) return;
              try {
                await _teamsService.addCoManager(
                  teamId: widget.teamId,
                  email: emailCtrl.text.trim(),
                );
                if (!ctx.mounted) return;
                Navigator.of(ctx).pop(true);
              } catch (e) {
                if (!ctx.mounted) return;
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(content: Text('$e')),
                );
              }
            },
            child: Text(l10n.add),
          ),
        ],
      ),
    );

    if (added == true) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.coManagerAdded)),
      );
      await _loadData();
    }
  }

  Future<void> _removeCoManager(String coManagerId, String coManagerName) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.removeCoManager),
        content: Text(l10n.removeCoManagerConfirmation(coManagerName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.remove, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await _teamsService.removeCoManager(
        teamId: widget.teamId,
        coManagerId: coManagerId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.coManagerRemoved)),
      );
      await _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${AppLocalizations.of(context)!.errorPrefix}: $e')),
      );
    }
  }

  Future<void> _openAddMemberSheet() async {
    final l10n = AppLocalizations.of(context)!;
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
                      title: Text(l10n.addTeamMember),
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
                          hintText: l10n.searchByNameOrEmail,
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
                                  l10n.noUsersFoundTryAnother,
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
                                        ? Chip(label: Text(l10n.memberChip))
                                        : ElevatedButton(
                                            onPressed: _addingMember
                                                ? null
                                                : () =>
                                                      _handleAddMemberFromDirectory(
                                                        user,
                                                        ctx,
                                                      ),
                                            child: Text(l10n.add),
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
    final l10n = AppLocalizations.of(context)!;
    final provider = user['provider']?.toString().trim();
    final subject = user['subject']?.toString().trim();
    if (provider == null ||
        provider.isEmpty ||
        subject == null ||
        subject.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.userMissingProviderError),
        ),
      );
      return;
    }

    // Check subscription limits (free tier: 25 team members max)
    final canAdd = await _subscriptionService.canAddTeamMember();
    if (!canAdd) {
      if (!mounted) return;

      // Show paywall
      final upgraded = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => const SubscriptionPaywallPage(),
        ),
      );

      // If user didn't upgrade, return
      if (upgraded != true) {
        return;
      }
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
      ).showSnackBar(SnackBar(content: Text(l10n.addedToTeam(displayName))));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${l10n.failedToAddMember}: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _addingMember = false);
      }
    }
  }

  Future<void> _cancelInvite(String inviteId) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      await _teamsService.cancelInvite(
        teamId: widget.teamId,
        inviteId: inviteId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.inviteCancelled)));
      await _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${l10n.failedToCancelInvite}: $e')));
    }
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
        title: Text(widget.teamName),
        actions: [
          IconButton(
            onPressed: _sendInvite,
            icon: const Icon(Icons.mail_outline),
            tooltip: l10n.sendInvite,
          ),
        ],
      ),
      body: RefreshIndicator(onRefresh: _loadData, child: _buildBody()),
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
                  l10n.failedToLoadTeamData,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text(_error!),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _loadData,
                  child: Text(l10n.retry),
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
            Text(
              l10n.membersSection,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_members.isEmpty)
          Text(
            l10n.noActiveMembersYet,
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
                        tooltip: l10n.message,
                      ),
                    IconButton(
                      onPressed: memberId.isEmpty
                          ? null
                          : () => _removeMember(memberId),
                      icon: const Icon(Icons.remove_circle_outline),
                      color: Colors.redAccent,
                      tooltip: l10n.remove,
                    ),
                  ],
                ),
              ),
            );
          }),
        // ─── Co-Managers Section ───
        const SizedBox(height: 24),
        Row(
          children: [
            Text(
              l10n.coManagersSection,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            if (widget.isOwner)
              TextButton.icon(
                onPressed: _addCoManager,
                icon: const Icon(Icons.person_add, size: 18),
                label: Text(l10n.add),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (_coManagers.isEmpty)
          Text(
            l10n.noCoManagersYet,
            style: TextStyle(color: Colors.grey.shade600),
          )
        else
          ..._coManagers.map((coManager) {
            final cmName = (coManager['name'] ?? '').toString();
            final cmEmail = (coManager['email'] ?? '').toString();
            final cmId = (coManager['id'] ?? '').toString();
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFF6366F1).withOpacity(0.1),
                  child: const Icon(Icons.admin_panel_settings, color: Color(0xFF6366F1)),
                ),
                title: Text(cmName.isEmpty ? 'Manager' : cmName),
                subtitle: cmEmail.isNotEmpty ? Text(cmEmail) : null,
                trailing: widget.isOwner
                    ? IconButton(
                        onPressed: cmId.isEmpty
                            ? null
                            : () => _removeCoManager(cmId, cmName),
                        icon: const Icon(Icons.remove_circle_outline),
                        color: Colors.redAccent,
                        tooltip: l10n.removeCoManagerTooltip,
                      )
                    : null,
              ),
            );
          }),
        const SizedBox(height: 24),
        Text(
          l10n.invitesSection,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _createInviteLink,
                icon: const Icon(Icons.link, size: 18),
                label: Text(l10n.inviteLinkButton),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _createPublicLink,
                icon: const Icon(Icons.public, size: 18),
                label: Text(l10n.publicLinkButton),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 6),
            OutlinedButton.icon(
              onPressed: _sendInvite,
              icon: const Icon(Icons.mail_outline, size: 18),
              label: Text(l10n.email),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_invites.isEmpty)
          Text(l10n.noInvitesYet, style: TextStyle(color: Colors.grey.shade600))
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
                        tooltip: l10n.cancelInvite,
                      )
                    : null,
              ),
            );
          }),
        // Applicants Section
        if (_applicants.isNotEmpty) ...[
          const SizedBox(height: 24),
          Row(
            children: [
              Text(
                l10n.pendingApplicants,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_applicants.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ..._applicants.map((applicant) {
            final applicantId = (applicant['id'] ?? '').toString();
            return ApplicantListTile(
              applicant: applicant,
              isLoading: _processingApplicantId == applicantId,
              onApprove: () => _approveApplicant(applicantId),
              onDeny: () => _denyApplicant(applicantId),
            );
          }),
        ],
        // Active Invite Links Section
        if (_inviteLinks.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(
            l10n.activeInviteLinks,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          ..._inviteLinks.map((link) {
            final inviteId = (link['id'] ?? '').toString();
            final shortCode = (link['shortCode'] ?? '').toString();
            final usedCount = link['usedCount'] as int? ?? 0;
            final maxUses = link['maxUses'] as int?;
            final status = (link['status'] ?? '').toString();
            final hasPassword = link['hasPassword'] as bool? ?? false;
            final usageCount = link['usageCount'] as int? ?? usedCount;
            final inviteType = (link['inviteType'] ?? 'link').toString();
            final isPublic = inviteType == 'public';

            String usageText;
            if (maxUses != null) {
              usageText = l10n.usedCount(usedCount, maxUses);
            } else {
              usageText = l10n.usedCountUnlimited(usedCount);
            }

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: isPublic ? Colors.teal : Colors.blue,
                  child: Icon(
                    isPublic ? Icons.public : Icons.link,
                    color: Colors.white,
                  ),
                ),
                title: Row(
                  children: [
                    Text(l10n.codePrefix(shortCode)),
                    if (isPublic) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.teal.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          l10n.publicLabel,
                          style: TextStyle(fontSize: 10, color: Colors.teal.shade700, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                    if (hasPassword) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.lock, size: 14, color: Colors.orange),
                    ],
                  ],
                ),
                subtitle: Row(
                  children: [
                    Expanded(child: Text('$usageText • Status: $status')),
                    if (usageCount > 0)
                      GestureDetector(
                        onTap: () => _showUsageLog(inviteId),
                        child: Text(
                          '$usageCount joins',
                          style: const TextStyle(
                            color: Colors.blue,
                            decoration: TextDecoration.underline,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
                trailing: status == 'pending'
                    ? PopupMenuButton<String>(
                        onSelected: (value) async {
                          if (value == 'revoke') {
                            await _revokeInviteLink(inviteId);
                          }
                        },
                        itemBuilder: (_) => [
                          PopupMenuItem(
                            value: 'revoke',
                            child: Row(
                              children: [
                                const Icon(Icons.cancel, color: Colors.red, size: 18),
                                const SizedBox(width: 8),
                                Text(l10n.revoke),
                              ],
                            ),
                          ),
                        ],
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
