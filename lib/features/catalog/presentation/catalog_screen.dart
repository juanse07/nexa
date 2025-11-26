import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/widgets/section_navigation_dropdown.dart';
import '../../teams/presentation/pages/teams_management_page.dart';
import '../../extraction/presentation/ai_chat_screen.dart';
import '../../extraction/presentation/extraction_screen.dart';
import '../../users/presentation/pages/manager_profile_page.dart';
import '../../users/presentation/pages/settings_page.dart';
import '../../users/data/services/manager_service.dart';
import '../../../features/auth/data/services/auth_service.dart';
import '../../../features/auth/presentation/pages/login_page.dart';
import '../../main/presentation/main_screen.dart';
import 'package:get_it/get_it.dart';
import 'package:nexa/shared/presentation/theme/app_colors.dart';

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

  void _handleNavigationDropdown(String section) async {
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
        final result = await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AIChatScreen()),
        );
        // Handle "Check Pending" navigation
        if (result != null && result is Map && result['action'] == 'show_pending') {
          if (!mounted) return;
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => const ExtractionScreen(
                initialScreenIndex: 1, // Jobs/Events tab
                initialEventsTabIndex: 0, // Pending sub-tab
              ),
            ),
          );
        }
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

    if (isDesktop) {
      return Scaffold(
        backgroundColor: AppColors.surfaceLight,
        appBar: AppBar(
          title: SectionNavigationDropdown(
            selectedSection: 'Catalog',
            onNavigate: _handleNavigationDropdown,
            isFixed: true,
          ),
          backgroundColor: AppColors.yellow,
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

    // Mobile layout with Facebook-style scrolling AppBar
    final statusBarHeight = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Facebook-style floating app bar - collapses to just status bar
            SliverAppBar(
              floating: true,
              snap: true,
              pinned: false,
              toolbarHeight: 56,
              // When collapsed, only show status bar height
              collapsedHeight: 0,
              // When expanded, show status bar + toolbar
              expandedHeight: statusBarHeight + 56,
              backgroundColor: AppColors.yellow,
              elevation: 2,
              shadowColor: Colors.black.withOpacity(0.2),
              // This is critical - always draw the safe area background
              flexibleSpace: LayoutBuilder(
                builder: (context, constraints) {
                  // Calculate how collapsed we are (0 = fully collapsed, 1 = fully expanded)
                  final collapseFactor = ((constraints.maxHeight - statusBarHeight) / 56).clamp(0.0, 1.0);

                  return Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppColors.yellow, AppColors.primaryPurple],
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Status bar space - always visible
                        SizedBox(height: statusBarHeight),
                        // Toolbar content - fades out and slides up when collapsing
                        if (collapseFactor > 0.01)
                          Opacity(
                            opacity: collapseFactor,
                            child: SizedBox(
                              height: 56 * collapseFactor,
                              child: Row(
                                children: [
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: SectionNavigationDropdown(
                                      selectedSection: 'Catalog',
                                      onNavigate: _handleNavigationDropdown,
                                      isFixed: true,
                                    ),
                                  ),
                                  _buildProfileMenu(context),
                                  const SizedBox(width: 8),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Content area
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    // Sample content to demonstrate scrolling
                    for (int i = 0; i < 20; i++)
                      Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: const Icon(Icons.inventory_2),
                          title: Text('Catalog Item ${i + 1}'),
                          subtitle: const Text('Sample catalog item'),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
