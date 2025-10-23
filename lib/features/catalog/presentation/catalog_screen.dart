import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/widgets/section_navigation_dropdown.dart';
import '../../teams/presentation/pages/teams_management_page.dart';
import '../../extraction/presentation/ai_chat_screen.dart';
import '../../users/presentation/pages/manager_profile_page.dart';
import '../../users/presentation/pages/settings_page.dart';
import '../../users/data/services/manager_service.dart';
import '../../../features/auth/data/services/auth_service.dart';
import '../../../features/auth/presentation/pages/login_page.dart';
import '../../main/presentation/main_screen.dart';
import 'package:get_it/get_it.dart';

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key});

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  late final ManagerService _managerService;
  String? _profilePictureUrl;

  @override
  void initState() {
    super.initState();
    _managerService = GetIt.I<ManagerService>();
    _loadProfilePicture();
  }

  Future<void> _loadProfilePicture() async {
    try {
      final me = await _managerService.getMe();
      if (!mounted) return;
      setState(() {
        _profilePictureUrl = me.picture;
      });
    } catch (_) {
      // Silently ignore; avatar will fall back to icon
    }
  }

  void _handleNavigationDropdown(String section) {
    HapticFeedback.lightImpact();

    switch (section) {
      case 'Jobs':
        // Navigate to Jobs tab (MainScreen index 2)
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MainScreen(initialIndex: 2)),
        );
        break;
      case 'Clients':
        // Already on Catalog screen - do nothing or refresh
        break;
      case 'Teams':
        // Navigate to Teams Management (separate screen, not a main tab)
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const TeamsManagementPage()),
        );
        break;
      case 'Catalog':
        // Already on Catalog - do nothing
        break;
      case 'AI Chat':
        // Navigate to AI Chat screen (separate screen, not a main tab)
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AIChatScreen()),
        );
        break;
    }
  }

  void _openTeamsManagementPage() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const TeamsManagementPage()),
    );
  }

  Future<void> _handleLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await AuthService.signOut();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (route) => false,
      );
    }
  }

  Widget _buildProfileMenu(BuildContext context) {
    final theme = Theme.of(context);
    return PopupMenuButton<String>(
      tooltip: 'Account',
      position: PopupMenuPosition.under,
      onSelected: (value) async {
        if (value == 'profile') {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ManagerProfilePage()),
          );
        } else if (value == 'settings') {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const SettingsPage()),
          );
        } else if (value == 'teams') {
          _openTeamsManagementPage();
        } else if (value == 'logout') {
          await _handleLogout(context);
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem<String>(
          value: 'profile',
          child: ListTile(
            leading: Icon(Icons.account_circle),
            title: Text('My Profile'),
          ),
        ),
        const PopupMenuItem<String>(
          value: 'settings',
          child: ListTile(
            leading: Icon(Icons.settings),
            title: Text('Settings'),
          ),
        ),
        const PopupMenuItem<String>(
          value: 'teams',
          child: ListTile(
            leading: Icon(Icons.groups_outlined),
            title: Text('Manage Teams'),
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'logout',
          child: ListTile(
            leading: Icon(Icons.logout),
            title: Text('Logout'),
          ),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: _buildAvatarOrIcon(theme),
      ),
    );
  }

  Widget _buildAvatarOrIcon(ThemeData theme) {
    final url = _profilePictureUrl?.trim();
    final hasUrl = url != null && url.isNotEmpty;
    return CircleAvatar(
      radius: 16,
      backgroundColor: Colors.white24,
      backgroundImage: hasUrl ? NetworkImage(url!) : null,
      child: hasUrl ? null : const Icon(Icons.person, color: Colors.white),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 1200;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: isDesktop ? null : AppBar(
        title: SectionNavigationDropdown(
          selectedSection: 'Catalog',
          onNavigate: _handleNavigationDropdown,
          isFixed: true,
        ),
        backgroundColor: const Color(0xFF7C3AED),
        elevation: 0,
        actions: [
          _buildProfileMenu(context),
        ],
      ),
      body: const Center(
        child: Text(
          'Catalog Screen',
          style: TextStyle(fontSize: 20, color: Colors.grey),
        ),
      ),
    );
  }
}