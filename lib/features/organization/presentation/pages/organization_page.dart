import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/widgets/custom_sliver_app_bar.dart';
import '../../../../shared/presentation/theme/app_colors.dart';
import '../../../auth/data/services/auth_service.dart';
import '../../data/services/organization_service.dart';

class OrganizationPage extends StatefulWidget {
  const OrganizationPage({super.key});

  @override
  State<OrganizationPage> createState() => _OrganizationPageState();
}

class _OrganizationPageState extends State<OrganizationPage> {
  final OrganizationService _orgService = GetIt.I<OrganizationService>();

  Map<String, dynamic>? _org;
  bool _loading = true;
  bool _actionLoading = false;
  List<Map<String, dynamic>>? _staffPool;
  bool _staffPoolLoading = false;
  String? _currentManagerId;
  int? _staffSeatsUsed;

  @override
  void initState() {
    super.initState();
    _loadManagerId();
    _loadOrg();
  }

  Future<void> _loadManagerId() async {
    final token = await AuthService.getJwt();
    if (token == null) return;
    try {
      final parts = token.split('.');
      if (parts.length == 3) {
        final payload = json.decode(
          utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
        ) as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            _currentManagerId = payload['managerId'] as String?;
          });
        }
      }
    } catch (_) {}
  }

  bool get _isOwner {
    if (_org == null || _currentManagerId == null) return false;
    final members =
        (_org!['members'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    return members.any((m) =>
        m['managerId'] == _currentManagerId && m['role'] == 'owner');
  }

  Future<void> _loadOrg() async {
    setState(() => _loading = true);
    final org = await _orgService.getMyOrganization();
    if (mounted) {
      setState(() {
        _org = org;
        _loading = false;
      });
      // Fetch live seat count if org exists
      if (org != null) {
        final orgId = org['id']?.toString() ?? '';
        if (orgId.isNotEmpty) {
          final seats = await _orgService.getStaffSeatCount(orgId);
          if (mounted && seats != null) {
            setState(() {
              _staffSeatsUsed = seats['seatsUsed'] as int?;
            });
          }
        }
      }
    }
  }

  Future<void> _loadStaffPool() async {
    if (_org == null) return;
    final orgId = _org!['id']?.toString() ?? '';
    if (orgId.isEmpty) return;
    setState(() => _staffPoolLoading = true);
    final pool = await _orgService.getStaffPool(orgId);
    if (mounted) {
      setState(() {
        _staffPool = pool;
        _staffPoolLoading = false;
      });
    }
  }

  Future<void> _toggleStaffPolicy(bool restricted) async {
    if (_org == null) return;
    final orgId = _org!['id']?.toString() ?? '';
    setState(() => _actionLoading = true);
    final policy = restricted ? 'restricted' : 'open';
    final success = await _orgService.updateStaffPolicy(orgId, policy);
    if (mounted) {
      setState(() => _actionLoading = false);
      if (success) {
        setState(() {
          _org!['staffPolicy'] = policy;
        });
        if (restricted && _staffPool == null) {
          await _loadStaffPool();
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update staff policy'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _addStaffToPool() async {
    if (_org == null) return;
    final result = await _showAddStaffDialog();
    if (result == null) return;

    final orgId = _org!['id']?.toString() ?? '';
    setState(() => _actionLoading = true);
    final entry = await _orgService.addStaffToPool(
      orgId,
      provider: result['provider']!,
      subject: result['subject']!,
      name: result['name'],
      email: result['email'],
    );
    if (mounted) {
      setState(() => _actionLoading = false);
      if (entry != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Staff added to approved pool'),
            backgroundColor: Colors.green,
          ),
        );
        await _loadStaffPool();
        setState(() {
          _org!['approvedStaffCount'] =
              (_org!['approvedStaffCount'] as int? ?? 0) + 1;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to add staff (may already exist)'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<Map<String, String>?> _showAddStaffDialog() async {
    final providerController = TextEditingController(text: 'google');
    final subjectController = TextEditingController();
    final nameController = TextEditingController();
    final emailController = TextEditingController();

    return showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Approved Staff'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: providerController,
                decoration: const InputDecoration(
                  labelText: 'Auth provider',
                  hintText: 'google, apple, phone, email',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: subjectController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Subject (user ID)',
                  hintText: 'Staff unique identifier',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Name (optional)',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email (optional)',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (subjectController.text.trim().isEmpty) return;
              Navigator.pop(ctx, {
                'provider': providerController.text.trim(),
                'subject': subjectController.text.trim(),
                'name': nameController.text.trim(),
                'email': emailController.text.trim(),
              });
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _removeStaffFromPool(Map<String, dynamic> staff) async {
    if (_org == null) return;
    final orgId = _org!['id']?.toString() ?? '';
    final provider = staff['provider'] as String? ?? '';
    final subject = staff['subject'] as String? ?? '';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Staff'),
        content: Text(
          'Remove ${staff['name'] ?? staff['email'] ?? '$provider:$subject'} from the approved pool?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _actionLoading = true);
    final success = await _orgService.removeStaffFromPool(orgId, provider, subject);
    if (mounted) {
      setState(() => _actionLoading = false);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Staff removed from approved pool'),
            backgroundColor: Colors.green,
          ),
        );
        await _loadStaffPool();
        setState(() {
          _org!['approvedStaffCount'] =
              ((_org!['approvedStaffCount'] as int? ?? 1) - 1).clamp(0, 9999);
        });
      }
    }
  }

  Future<void> _createOrg() async {
    final name = await _showNameDialog();
    if (name == null || name.isEmpty) return;

    setState(() => _actionLoading = true);
    final result = await _orgService.createOrganization(name);
    if (mounted) {
      setState(() => _actionLoading = false);
      if (result != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Organization created'),
            backgroundColor: Colors.green,
          ),
        );
        await _loadOrg();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to create organization'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<String?> _showNameDialog() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create Organization'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Organization name',
            hintText: 'e.g., Acme Events LLC',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  Future<void> _inviteMember() async {
    if (_org == null) return;
    final email = await _showInviteDialog();
    if (email == null || email.isEmpty) return;

    setState(() => _actionLoading = true);
    final result = await _orgService.inviteMember(
      _org!['id']?.toString() ?? '',
      email,
    );
    if (mounted) {
      setState(() => _actionLoading = false);
      if (result != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Invite sent to $email'),
            backgroundColor: Colors.green,
          ),
        );
        await _loadOrg();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to send invite'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<String?> _showInviteDialog() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Invite Manager'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'Email address',
            hintText: 'manager@company.com',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Send Invite'),
          ),
        ],
      ),
    );
  }

  Future<void> _transferOwnership(Map<String, dynamic> member) async {
    if (_org == null) return;
    final orgName = (_org!['name'] ?? 'this organization') as String;
    final memberName =
        (member['name'] ?? member['email'] ?? 'this member') as String;
    final memberId = member['managerId'] as String? ?? '';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Transfer Ownership'),
        content: Text(
          'Transfer ownership of "$orgName" to $memberName? You will become an admin.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Transfer'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _actionLoading = true);
    final orgId = _org!['id']?.toString() ?? '';
    final success = await _orgService.transferOwnership(orgId, memberId);
    if (mounted) {
      setState(() => _actionLoading = false);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ownership transferred to $memberName'),
            backgroundColor: Colors.green,
          ),
        );
        await _loadOrg();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to transfer ownership'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _shareFlowShift() {
    const message =
        'Check out FlowShift for managing our event staffing team!\n\n'
        'Centralized staff pool, multi-manager coordination, and streamlined '
        'scheduling \u2014 all in one app.\n\n'
        'Learn more: https://flowshift.work/business';
    Share.share(message, subject: 'FlowShift for Teams');
  }

  Future<void> _openBillingPortal() async {
    if (_org == null) return;
    setState(() => _actionLoading = true);
    final url = await _orgService.createPortalSession(
      _org!['id']?.toString() ?? '',
    );
    if (mounted) {
      setState(() => _actionLoading = false);
      if (url != null) {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to open billing portal'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _startCheckout() async {
    if (_org == null) return;
    setState(() => _actionLoading = true);
    final url = await _orgService.createCheckoutSession(
      _org!['id']?.toString() ?? '',
      successUrl: 'https://flowshift.work/checkout/success',
      cancelUrl: 'https://flowshift.work/checkout/cancel',
    );
    if (mounted) {
      setState(() => _actionLoading = false);
      if (url != null) {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to start checkout'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surfaceContainerLowest,
      body: CustomScrollView(
        slivers: [
          CustomSliverAppBar(
            title: 'Organization',
            subtitle: 'Manage your B2B account',
            onBackPressed: () => Navigator.of(context).pop(),
            expandedHeight: 120.0,
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16.0),
            sliver: SliverList(
              delegate: SliverChildListDelegate(
                _loading
                    ? [const Center(child: CircularProgressIndicator())]
                    : _org == null
                        ? _buildNoOrgContent(theme)
                        : _buildOrgContent(theme),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildNoOrgContent(ThemeData theme) {
    return [
      Card(
        elevation: 0,
        color: theme.colorScheme.surfaceContainer,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              Icon(
                Icons.business,
                size: 64,
                color: theme.colorScheme.primary.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 16),
              Text(
                'No Organization',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Create an organization to manage multiple manager accounts under a single B2B subscription with Stripe billing.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _actionLoading ? null : _createOrg,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.yellow,
                    foregroundColor: AppColors.navySpaceCadet,
                  ),
                  icon: _actionLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add_business),
                  label: const Text('Create Organization'),
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 16),
      // Invite Your Company card
      Card(
        elevation: 0,
        color: theme.colorScheme.surfaceContainer,
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              Icon(
                Icons.share,
                size: 36,
                color: theme.colorScheme.primary.withValues(alpha: 0.6),
              ),
              const SizedBox(height: 12),
              Text(
                'Already work for a company?',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Share FlowShift with your manager or admin.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _shareFlowShift,
                  icon: const Icon(Icons.share),
                  label: const Text('Share with your company'),
                ),
              ),
            ],
          ),
        ),
      ),
    ];
  }

  List<Widget> _buildOrgContent(ThemeData theme) {
    final String orgName = (_org!['name'] ?? 'Organization') as String;
    final String tier = (_org!['subscriptionTier'] ?? 'free') as String;
    final String status = (_org!['subscriptionStatus'] ?? 'none') as String;
    final members = (_org!['members'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final pendingInvites = (_org!['pendingInvites'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final isPro = tier == 'pro';
    final cancelAtPeriodEnd = _org!['cancelAtPeriodEnd'] == true;

    return [
      // Org info card
      Card(
        elevation: 0,
        color: theme.colorScheme.surfaceContainer,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.business, color: theme.colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      orgName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isPro
                          ? Colors.amber.withValues(alpha: 0.2)
                          : theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      isPro ? 'PRO' : 'FREE',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isPro ? Colors.amber.shade800 : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Status: ${_formatStatus(status)}${cancelAtPeriodEnd ? ' (cancels at period end)' : ''}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              if (!isPro)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _actionLoading ? null : _startCheckout,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.yellow,
                      foregroundColor: AppColors.navySpaceCadet,
                    ),
                    icon: _actionLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.upgrade),
                    label: const Text('Upgrade to Pro'),
                  ),
                ),
              if (isPro)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _actionLoading ? null : _openBillingPortal,
                    icon: const Icon(Icons.credit_card),
                    label: const Text('Manage Billing'),
                  ),
                ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 16),

      // Staff Seats card
      _buildStaffSeatsCard(theme),
      const SizedBox(height: 16),

      // Members card
      Card(
        elevation: 0,
        color: theme.colorScheme.surfaceContainer,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.people, color: theme.colorScheme.primary),
                  const SizedBox(width: 12),
                  Text(
                    'Members (${members.length})',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...members.map((m) => _buildMemberTile(m, theme)),
              if (pendingInvites.isNotEmpty) ...[
                const Divider(),
                Text(
                  'Pending Invites',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                ...pendingInvites.map((inv) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.mail_outline),
                      title: Text((inv['email'] ?? '') as String),
                      subtitle: Text((inv['role'] ?? 'member') as String),
                    )),
              ],
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _actionLoading ? null : _inviteMember,
                  icon: const Icon(Icons.person_add),
                  label: const Text('Invite Manager'),
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 16),

      // Staff Policy card
      _buildStaffPolicyCard(theme),

      // Approved Staff card (shown when restricted or pool is non-empty)
      if ((_org!['staffPolicy'] == 'restricted') ||
          (_org!['approvedStaffCount'] as int? ?? 0) > 0) ...[
        const SizedBox(height: 16),
        _buildApprovedStaffCard(theme),
      ],

      // Grow Your Team / Share card
      const SizedBox(height: 16),
      Card(
        elevation: 0,
        color: theme.colorScheme.surfaceContainer,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.group_add, color: theme.colorScheme.primary),
                  const SizedBox(width: 12),
                  Text(
                    'Grow Your Team',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Share FlowShift with your team or company leadership.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _shareFlowShift,
                  icon: const Icon(Icons.share),
                  label: const Text('Share'),
                ),
              ),
            ],
          ),
        ),
      ),
    ];
  }

  Widget _buildStaffSeatsCard(ThemeData theme) {
    final billingModel = (_org?['billingModel'] ?? 'flat') as String;
    final isPerSeat = billingModel == 'per_seat';
    final seatCount = _staffSeatsUsed ?? (_org?['staffSeatsUsed'] as int? ?? 0);

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.event_seat, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Staff Seats',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '$seatCount',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Active Staff Seats: $seatCount',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              isPerSeat
                  ? 'Billed per seat \u2022 Usage auto-syncs with Stripe'
                  : 'Flat rate \u2022 Unlimited staff',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStaffPolicyCard(ThemeData theme) {
    final isRestricted = _org?['staffPolicy'] == 'restricted';

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.shield_outlined, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Staff Policy',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Switch.adaptive(
                  value: isRestricted,
                  onChanged: _actionLoading ? null : _toggleStaffPolicy,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              isRestricted
                  ? 'Restricted: Managers can only add staff from the approved pool below.'
                  : 'Open: Managers can add any staff member to their teams.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildApprovedStaffCard(ThemeData theme) {
    final staffCount = _org?['approvedStaffCount'] as int? ?? 0;

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.badge_outlined, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Approved Staff ($staffCount)',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (_staffPool == null && !_staffPoolLoading)
                  TextButton(
                    onPressed: _loadStaffPool,
                    child: const Text('Load'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (_staffPoolLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_staffPool != null) ...[
              if (_staffPool!.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12.0),
                  child: Text(
                    'No approved staff yet. Add staff members to restrict team membership.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              else
                ..._staffPool!.map((staff) => _buildStaffPoolTile(staff, theme)),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _actionLoading ? null : _addStaffToPool,
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text('Add Staff'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStaffPoolTile(Map<String, dynamic> staff, ThemeData theme) {
    final name = (staff['name'] ?? staff['email'] ?? '${staff['provider']}:${staff['subject']}') as String;
    final email = (staff['email'] ?? '') as String;
    final picture = staff['picture'] as String?;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.secondaryContainer,
        backgroundImage: picture != null ? NetworkImage(picture) : null,
        child: picture == null
            ? Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: TextStyle(color: theme.colorScheme.onSecondaryContainer),
              )
            : null,
      ),
      title: Text(name),
      subtitle: email.isNotEmpty ? Text(email) : null,
      trailing: IconButton(
        icon: Icon(Icons.remove_circle_outline, color: Colors.red.shade400),
        onPressed: _actionLoading ? null : () => _removeStaffFromPool(staff),
      ),
    );
  }

  Widget _buildMemberTile(Map<String, dynamic> member, ThemeData theme) {
    final String name = (member['name'] ?? member['email'] ?? 'Unknown') as String;
    final String role = (member['role'] ?? 'member') as String;
    final String email = (member['email'] ?? '') as String;
    final bool canTransfer = _isOwner && role != 'owner';

    final roleBadge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: role == 'owner'
            ? Colors.amber.withValues(alpha: 0.2)
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        role,
        style: theme.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
    );

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.primaryContainer,
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: TextStyle(color: theme.colorScheme.onPrimaryContainer),
        ),
      ),
      title: Text(name),
      subtitle: Text(email),
      trailing: canTransfer
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                roleBadge,
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 20),
                  onSelected: (value) {
                    if (value == 'transfer') {
                      _transferOwnership(member);
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'transfer',
                      child: Row(
                        children: [
                          Icon(Icons.swap_horiz, size: 20),
                          SizedBox(width: 8),
                          Text('Transfer Ownership'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            )
          : roleBadge,
    );
  }

  String _formatStatus(String status) {
    switch (status) {
      case 'active':
        return 'Active';
      case 'trialing':
        return 'Trial';
      case 'past_due':
        return 'Past Due';
      case 'canceled':
        return 'Canceled';
      case 'unpaid':
        return 'Unpaid';
      default:
        return 'No subscription';
    }
  }
}
