import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';

import 'package:nexa/core/network/api_client.dart';
import 'package:nexa/features/auth/data/services/auth_service.dart';
import 'package:nexa/features/auth/presentation/pages/login_page.dart';
import 'package:nexa/features/extraction/services/clients_service.dart';
import 'package:nexa/features/extraction/services/roles_service.dart';
import 'package:nexa/features/extraction/services/tariffs_service.dart';
import 'package:nexa/features/main/presentation/main_screen.dart';
import 'package:nexa/features/users/data/services/manager_service.dart';
import 'package:nexa/features/users/presentation/pages/manager_profile_page.dart';
import 'package:nexa/features/teams/data/services/teams_service.dart';
import 'package:nexa/core/network/socket_manager.dart';
import 'package:nexa/services/notification_service.dart';

class ManagerOnboardingGate extends StatefulWidget {
  const ManagerOnboardingGate({super.key});

  @override
  State<ManagerOnboardingGate> createState() => _ManagerOnboardingGateState();
}

class _ManagerOnboardingGateState extends State<ManagerOnboardingGate> {
  late final ManagerService _managerService;
  final TeamsService _teamsService = TeamsService();
  final ClientsService _clientsService = ClientsService();
  final RolesService _rolesService = RolesService();
  final TariffsService _tariffsService = TariffsService();

  final TextEditingController _teamNameCtrl = TextEditingController();
  final TextEditingController _teamDescCtrl = TextEditingController();
  final TextEditingController _clientNameCtrl = TextEditingController();
  final TextEditingController _roleNameCtrl = TextEditingController();
  final TextEditingController _tariffRateCtrl = TextEditingController();

  _OnboardingSnapshot? _snapshot;
  bool _loading = true;
  bool _openingProfile = false;
  bool _creatingTeam = false;
  bool _creatingClient = false;
  bool _creatingRole = false;
  bool _creatingTariff = false;
  String? _error;
  String? _selectedClientId;
  String? _selectedRoleId;

  @override
  void initState() {
    super.initState();
    final api = GetIt.I<ApiClient>();
    final storage = GetIt.I<FlutterSecureStorage>();
    _managerService = ManagerService(api, storage);
    _refresh();
  }

  @override
  void dispose() {
    _teamNameCtrl.dispose();
    _teamDescCtrl.dispose();
    _clientNameCtrl.dispose();
    _roleNameCtrl.dispose();
    _tariffRateCtrl.dispose();
    super.dispose();
  }

  Future<void> _refresh({bool showSpinner = true}) async {
    if (showSpinner) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final profile = await _managerService.getMe();
      SocketManager.instance.registerManager(profile.id);

      // Initialize notifications after successful authentication
      await NotificationService().initialize();

      final teams = await _teamsService.fetchTeams();
      final clients = await _clientsService.fetchClients();
      final roles = await _rolesService.fetchRoles();
      final tariffs = await _tariffsService.fetchTariffs();
      final snapshot = _OnboardingSnapshot(
        profile: profile,
        teams: teams,
        clients: clients,
        roles: roles,
        tariffs: tariffs,
      );
      setState(() {
        _snapshot = snapshot;
        _loading = false;
        _error = null;
        _syncSelections(snapshot);
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _syncSelections(_OnboardingSnapshot snapshot) {
    if (snapshot.clients.isEmpty) {
      _selectedClientId = null;
    } else {
      final hasCurrent = snapshot.clients.any(
        (c) => _resolveId(c) == _selectedClientId,
      );
      if (!hasCurrent) {
        _selectedClientId = _resolveId(snapshot.clients.first);
      }
    }

    if (snapshot.roles.isEmpty) {
      _selectedRoleId = null;
    } else {
      final hasCurrent = snapshot.roles.any(
        (r) => _resolveId(r) == _selectedRoleId,
      );
      if (!hasCurrent) {
        _selectedRoleId = _resolveId(snapshot.roles.first);
      }
    }
  }

  Future<void> _createTeam() async {
    final name = _teamNameCtrl.text.trim();
    if (name.isEmpty) {
      _showSnack('Enter a team/company name to continue');
      return;
    }
    setState(() {
      _creatingTeam = true;
    });
    try {
      await _teamsService.createTeam(
        name: name,
        description: _teamDescCtrl.text.trim().isEmpty ? null : _teamDescCtrl.text.trim(),
      );
      _teamNameCtrl.clear();
      _teamDescCtrl.clear();
      _showSnack('Team created successfully!');
      await _refresh();
    } catch (e) {
      _showSnack('Failed to create team: $e');
    } finally {
      if (mounted) {
        setState(() {
          _creatingTeam = false;
        });
      }
    }
  }

  Future<void> _createClient() async {
    final name = _clientNameCtrl.text.trim();
    if (name.isEmpty) {
      _showSnack('Enter a client name to continue');
      return;
    }
    setState(() {
      _creatingClient = true;
    });
    try {
      await _clientsService.createClient(name);
      _clientNameCtrl.clear();
      _showSnack('Client created');
      await _refresh();
    } catch (e) {
      _showSnack('Failed to create client: $e');
    } finally {
      if (mounted) {
        setState(() {
          _creatingClient = false;
        });
      }
    }
  }

  Future<void> _createRole() async {
    final name = _roleNameCtrl.text.trim();
    if (name.isEmpty) {
      _showSnack('Enter a role name to continue');
      return;
    }
    setState(() {
      _creatingRole = true;
    });
    try {
      await _rolesService.createRole(name);
      _roleNameCtrl.clear();
      _showSnack('Role created');
      await _refresh();
    } catch (e) {
      _showSnack('Failed to create role: $e');
    } finally {
      if (mounted) {
        setState(() {
          _creatingRole = false;
        });
      }
    }
  }

  Future<void> _createTariff() async {
    final snapshot = _snapshot;
    if (snapshot == null) return;
    if (!snapshot.hasClient || !snapshot.hasRole) {
      _showSnack('Create a client and a role before adding a tariff');
      return;
    }
    final clientId = _selectedClientId;
    final roleId = _selectedRoleId;
    if (clientId == null ||
        clientId.isEmpty ||
        roleId == null ||
        roleId.isEmpty) {
      _showSnack('Select a client and a role');
      return;
    }
    final rateText = _tariffRateCtrl.text.trim();
    final rate = double.tryParse(rateText);
    if (rate == null || rate <= 0) {
      _showSnack('Enter a valid hourly rate (e.g. 22.50)');
      return;
    }
    setState(() {
      _creatingTariff = true;
    });
    try {
      await _tariffsService.upsertTariff(
        clientId: clientId,
        roleId: roleId,
        rate: rate,
      );
      _tariffRateCtrl.clear();
      _showSnack('Tariff saved');
      await _refresh();
    } catch (e) {
      _showSnack('Failed to save tariff: $e');
    } finally {
      if (mounted) {
        setState(() {
          _creatingTariff = false;
        });
      }
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openProfile() async {
    // Debug logging for web
    if (kIsWeb) {
      print('[WEB DEBUG] _openProfile called, _openingProfile: $_openingProfile');
    }

    if (_openingProfile) {
      if (kIsWeb) print('[WEB DEBUG] Already opening profile, skipping');
      return;
    }

    setState(() {
      _openingProfile = true;
    });

    if (kIsWeb) print('[WEB DEBUG] Navigating to ManagerProfilePage');

    try {
      await Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const ManagerProfilePage()));
      if (kIsWeb) print('[WEB DEBUG] Returned from ManagerProfilePage');
      await _refresh();
    } catch (e) {
      if (kIsWeb) print('[WEB DEBUG] Error opening profile: $e');
      if (mounted) {
        _showSnack('Failed to open profile: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _openingProfile = false;
        });
        if (kIsWeb) print('[WEB DEBUG] _openingProfile reset to false');
      }
    }
  }

  Future<void> _signOut() async {
    await AuthService.signOut();
    if (!mounted) return;
    await Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Getting Started'),
          actions: [
            IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh)),
          ],
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 48,
                  color: Colors.redAccent,
                ),
                const SizedBox(height: 16),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.redAccent),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: _refresh,
                      child: const Text('Retry'),
                    ),
                    const SizedBox(width: 16),
                    OutlinedButton(
                      onPressed: () {
                        // Skip error and navigate to main screen anyway
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (_) => const MainScreen(),
                          ),
                        );
                      },
                      child: const Text('Skip'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    final snapshot = _snapshot;
    if (snapshot == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (snapshot.isComplete) {
      return const MainScreen();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Let’s get you set up'),
        actions: [
          TextButton(
            onPressed: _signOut,
            child: const Text(
              'Sign out',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: kIsWeb
          ? ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const SizedBox(height: 12),
                _buildIntroCard(snapshot),
                const SizedBox(height: 20),
                _buildProfileStep(snapshot),
                const SizedBox(height: 16),
                _buildTeamStep(snapshot),
                const SizedBox(height: 16),
                _buildClientStep(snapshot),
                const SizedBox(height: 16),
                _buildRoleStep(snapshot),
                const SizedBox(height: 16),
                _buildTariffStep(snapshot),
                const SizedBox(height: 32),
                if (snapshot.missingSteps.isNotEmpty)
                  Text(
                    'Complete all steps above to access the full dashboard.',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
              ],
            )
          : RefreshIndicator(
              onRefresh: () => _refresh(showSpinner: false),
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const SizedBox(height: 12),
                  _buildIntroCard(snapshot),
                  const SizedBox(height: 20),
                  _buildProfileStep(snapshot),
                  const SizedBox(height: 16),
                  _buildTeamStep(snapshot),
                  const SizedBox(height: 16),
                  _buildClientStep(snapshot),
                  const SizedBox(height: 16),
                  _buildRoleStep(snapshot),
                  const SizedBox(height: 16),
                  _buildTariffStep(snapshot),
                  const SizedBox(height: 32),
                  if (snapshot.missingSteps.isNotEmpty)
                    Text(
                      'Complete all steps above to access the full dashboard.',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildIntroCard(_OnboardingSnapshot snapshot) {
    final missing = snapshot.missingSteps;
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Finish these steps to activate your Nexa workspace:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildStatusChip(
                  label: 'Profile',
                  completed: snapshot.hasProfile,
                ),
                _buildStatusChip(
                  label: 'Team',
                  completed: snapshot.hasTeam,
                ),
                _buildStatusChip(
                  label: 'Client',
                  completed: snapshot.hasClient,
                ),
                _buildStatusChip(label: 'Role', completed: snapshot.hasRole),
                _buildStatusChip(
                  label: 'Tariff',
                  completed: snapshot.hasTariff,
                ),
              ],
            ),
            if (missing.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Next up: ${missing.join(', ')}',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip({required String label, required bool completed}) {
    return Chip(
      avatar: Icon(
        completed ? Icons.check_circle : Icons.radio_button_unchecked,
        color: completed ? const Color(0xFF059669) : Colors.grey,
        size: 18,
      ),
      label: Text(label),
      backgroundColor: completed
          ? const Color(0xFFE8F5E9)
          : const Color(0xFFF3F4F6),
    );
  }

  Widget _buildProfileStep(_OnboardingSnapshot snapshot) {
    final completed = snapshot.hasProfile;
    final subtitle = completed
        ? 'Profile ready: ${snapshot.profile.firstName ?? ''} ${snapshot.profile.lastName ?? ''}'
              .trim()
        : 'Add your first and last name so staff know who you are.';

    // Web-friendly button with explicit pointer handling
    final button = ElevatedButton.icon(
      onPressed: _openingProfile ? null : () {
        if (kIsWeb) {
          print('[WEB DEBUG] Button onPressed triggered');
        }
        _openProfile();
      },
      icon: _openingProfile
          ? const SizedBox(
              height: 18,
              width: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(completed ? Icons.person : Icons.person_outline),
      label: Text(completed ? 'Review profile' : 'Update profile'),
    );

    // Wrap button in MouseRegion for web to ensure pointer events work
    final webButton = kIsWeb && !_openingProfile
        ? MouseRegion(
            cursor: SystemMouseCursors.click,
            child: button,
          )
        : button;

    return _buildStepCard(
      title: '1. Update your profile',
      completed: completed,
      subtitle: subtitle.isEmpty ? 'Profile details updated.' : subtitle,
      action: webButton,
    );
  }

  Widget _buildTeamStep(_OnboardingSnapshot snapshot) {
    final completed = snapshot.hasTeam;
    return _buildStepCard(
      title: '2. Create your team/company',
      completed: completed,
      subtitle: completed
          ? 'Team ready: ${snapshot.teams.isNotEmpty ? _resolveName(snapshot.teams.first) : ""}'
          : 'Set up your staffing company (e.g., "MES - Minneapolis Event Staffing")',
      action: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _teamNameCtrl,
            enabled: snapshot.hasProfile,
            decoration: InputDecoration(
              labelText: 'Team/Company name',
              hintText: 'e.g. MES - Minneapolis Event Staffing',
              helperText: snapshot.hasProfile
                  ? null
                  : 'Complete your profile first',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _teamDescCtrl,
            enabled: snapshot.hasProfile,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: 'Description (optional)',
              hintText: 'Brief description of your staffing company',
              helperText: snapshot.hasProfile
                  ? null
                  : 'Complete your profile first',
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: (!snapshot.hasProfile || _creatingTeam)
                ? null
                : _createTeam,
            icon: _creatingTeam
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.business),
            label: Text(completed ? 'Add another team' : 'Create team'),
          ),
        ],
      ),
    );
  }

  Widget _buildClientStep(_OnboardingSnapshot snapshot) {
    final completed = snapshot.hasClient;
    return _buildStepCard(
      title: '3. Create your first client',
      completed: completed,
      subtitle: completed
          ? 'Clients configured: ${snapshot.clients.length}'
          : 'You need at least one client before you can staff events.',
      action: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _clientNameCtrl,
            enabled: snapshot.hasProfile && snapshot.hasTeam,
            decoration: InputDecoration(
              labelText: 'Client name',
              hintText: 'e.g. Bluebird Catering',
              helperText: snapshot.hasProfile && snapshot.hasTeam
                  ? null
                  : 'Complete profile and team first',
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: (!snapshot.hasProfile || !snapshot.hasTeam || _creatingClient)
                ? null
                : _createClient,
            icon: _creatingClient
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add_business),
            label: Text(completed ? 'Add another client' : 'Create client'),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleStep(_OnboardingSnapshot snapshot) {
    final completed = snapshot.hasRole;
    return _buildStepCard(
      title: '4. Add at least one role',
      completed: completed,
      subtitle: completed
          ? 'Roles configured: ${snapshot.roles.length}'
          : 'Roles help match staff to the right job (waiter, chef, bartender…).',
      action: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _roleNameCtrl,
            enabled: snapshot.hasProfile && snapshot.hasClient,
            decoration: InputDecoration(
              labelText: 'Role name',
              hintText: 'e.g. Lead Server',
              helperText: snapshot.hasProfile && snapshot.hasClient
                  ? null
                  : 'Finish previous steps first',
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed:
                (!snapshot.hasProfile || !snapshot.hasClient || _creatingRole)
                ? null
                : _createRole,
            icon: _creatingRole
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.badge_outlined),
            label: Text(completed ? 'Add another role' : 'Create role'),
          ),
        ],
      ),
    );
  }

  Widget _buildTariffStep(_OnboardingSnapshot snapshot) {
    final completed = snapshot.hasTariff;
    final clients = snapshot.clients;
    final roles = snapshot.roles;
    return _buildStepCard(
      title: '5. Set your first tariff',
      completed: completed,
      subtitle: completed
          ? 'Tariffs configured: ${snapshot.tariffs.length}'
          : 'Set a rate so staffing assignments know what to bill.',
      action: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<String>(
            value: _selectedClientId,
            onChanged: (!snapshot.hasProfile || !snapshot.hasClient)
                ? null
                : (value) => setState(() {
                    _selectedClientId = value;
                  }),
            items: clients
                .map(
                  (client) => DropdownMenuItem<String>(
                    value: _resolveId(client),
                    child: Text(_resolveName(client)),
                  ),
                )
                .toList(),
            decoration: InputDecoration(
              labelText: 'Client',
              helperText: clients.isEmpty ? 'Create a client first' : null,
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _selectedRoleId,
            onChanged:
                (!snapshot.hasProfile ||
                    !snapshot.hasClient ||
                    !snapshot.hasRole)
                ? null
                : (value) => setState(() {
                    _selectedRoleId = value;
                  }),
            items: roles
                .map(
                  (role) => DropdownMenuItem<String>(
                    value: _resolveId(role),
                    child: Text(_resolveName(role)),
                  ),
                )
                .toList(),
            decoration: InputDecoration(
              labelText: 'Role',
              helperText: roles.isEmpty ? 'Create a role first' : null,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _tariffRateCtrl,
            enabled:
                snapshot.hasProfile && snapshot.hasClient && snapshot.hasRole,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Hourly rate (USD)',
              hintText: 'e.g. 24.00',
              helperText:
                  snapshot.hasProfile && snapshot.hasClient && snapshot.hasRole
                  ? 'You can adjust this later in Catalog > Tariffs'
                  : 'Finish previous steps first',
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed:
                (!snapshot.hasProfile ||
                    !snapshot.hasClient ||
                    !snapshot.hasRole ||
                    _creatingTariff)
                ? null
                : _createTariff,
            icon: _creatingTariff
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.attach_money),
            label: Text(completed ? 'Add another tariff' : 'Save tariff'),
          ),
        ],
      ),
    );
  }

  Widget _buildStepCard({
    required String title,
    required bool completed,
    required String subtitle,
    required Widget action,
  }) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(
                  completed ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: completed ? const Color(0xFF059669) : Colors.grey,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(subtitle, style: TextStyle(color: Colors.grey.shade700)),
            const SizedBox(height: 16),
            action,
          ],
        ),
      ),
    );
  }

  String _resolveId(Map<String, dynamic> data) {
    final id = data['id'] ?? data['_id'];
    return id?.toString() ?? '';
  }

  String _resolveName(Map<String, dynamic> data) {
    final name = data['name'] ?? data['title'] ?? data['label'];
    if (name != null) {
      return name.toString();
    }
    if (data.containsKey('first_name') || data.containsKey('last_name')) {
      final first = data['first_name']?.toString() ?? '';
      final last = data['last_name']?.toString() ?? '';
      final joined = '$first $last'.trim();
      if (joined.isNotEmpty) return joined;
    }
    return 'Untitled';
  }
}

class _OnboardingSnapshot {
  const _OnboardingSnapshot({
    required this.profile,
    required this.teams,
    required this.clients,
    required this.roles,
    required this.tariffs,
  });

  final ManagerProfile profile;
  final List<Map<String, dynamic>> teams;
  final List<Map<String, dynamic>> clients;
  final List<Map<String, dynamic>> roles;
  final List<Map<String, dynamic>> tariffs;

  bool get hasProfile {
    final first = profile.firstName?.trim();
    final last = profile.lastName?.trim();
    return (first?.isNotEmpty ?? false) && (last?.isNotEmpty ?? false);
  }

  bool get hasTeam => teams.isNotEmpty;

  bool get hasClient => clients.isNotEmpty;

  bool get hasRole => roles.isNotEmpty;

  bool get hasTariff => tariffs.isNotEmpty;

  bool get isComplete => hasProfile && hasTeam && hasClient && hasRole && hasTariff;

  List<String> get missingSteps {
    final missing = <String>[];
    if (!hasProfile) missing.add('profile');
    if (!hasTeam) missing.add('team');
    if (!hasClient) missing.add('client');
    if (!hasRole) missing.add('role');
    if (!hasTariff) missing.add('tariff');
    return missing;
  }
}
