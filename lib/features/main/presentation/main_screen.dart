import 'dart:async';
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:provider/provider.dart';
import '../../../services/terminology_provider.dart';
import 'package:nexa/l10n/app_localizations.dart';
import '../../extraction/presentation/extraction_screen.dart';
import '../../events/presentation/manager_calendar_screen.dart';
import '../../chat/presentation/conversations_screen.dart';
import '../../attendance/presentation/attendance_dashboard_screen.dart';
import '../../statistics/presentation/statistics_dashboard_screen.dart';
import '../../users/presentation/pages/settings_page.dart';
import '../../extraction/presentation/ai_chat_screen.dart';
import '../../users/data/services/manager_service.dart';
import '../../../core/network/api_client.dart';
import '../../../shared/widgets/initials_avatar.dart';
import 'package:nexa/shared/presentation/theme/app_colors.dart';

class MainScreen extends StatefulWidget {
  final int initialIndex;

  const MainScreen({super.key, this.initialIndex = 0});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen>
    with TickerProviderStateMixin {
  int _selectedIndex = 0;
  late PageController _pageController;

  // Animation controllers for hide/show effect
  late AnimationController _bottomBarController;
  late Animation<double> _bottomBarAnimation;

  // Nav bar height tracking for partial-hide calculation
  final GlobalKey _navBarKey = GlobalKey();
  double _navBarHeight = 82.0;

  // Scroll detection variables
  double _lastScrollOffset = 0;
  double _lastScrollVelocity = 0;
  DateTime _lastScrollTime = DateTime.now();
  Timer? _autoShowTimer;
  bool _isBottomBarVisible = true;

  // Profile data for the "More" sheet
  late final ManagerService _managerService;
  String? _profilePictureUrl;
  String? _profileFirstName;
  String? _profileLastName;

  // Performance optimization constants
  static const Duration _animationDuration = Duration(milliseconds: 300); // Fast like Facebook
  static const double _scrollThreshold = 3.0; // Very responsive
  static const double _velocityThreshold = 120.0; // Velocity-based detection
  static const Duration _autoShowDelay = Duration(milliseconds: 30000); // Quick auto-show

  // Define screens - late final for single initialization
  late final List<Widget> _screens = [
    // ===== HOME & CREATE DASHBOARDS COMMENTED OUT - SAVED FOR FUTURE USE =====
    // const HomeScreen(), // Home (index 0)
    // const ExtractionScreen(
    //   initialScreenIndex: 0,
    //   hideNavigationRail: true,
    // ), // Create tab (index 1)
    // ===== END DASHBOARDS =====
    const ExtractionScreen(
      initialScreenIndex: 1,
      hideNavigationRail: true,
    ), // Events tab (index 0)
    const ManagerCalendarScreen(), // Schedule/Calendar tab (index 1)
    const ConversationsScreen(), // Chat screen (index 2)
    const ExtractionScreen(
      initialScreenIndex: 4,
      hideNavigationRail: true,
    ), // Catalog screen (index 3)
    const AttendanceDashboardScreen(), // Attendance tab (index 4)
    const StatisticsDashboardScreen(), // Statistics tab (index 5)
  ];

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);

    // Initialize animation controllers
    _bottomBarController = AnimationController(
      duration: _animationDuration,
      vsync: this,
    );

    _bottomBarAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(
      parent: _bottomBarController,
      curve: Curves.easeOutCubic, // Smooth cubic easing
      reverseCurve: Curves.easeInCubic,
    ));

    // Start with bottom bar visible
    _bottomBarController.forward();

    // Load profile for the More sheet avatar
    _managerService = ManagerService(GetIt.I<ApiClient>(), GetIt.I<FlutterSecureStorage>());
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final me = await _managerService.getMe();
      if (!mounted) return;
      setState(() {
        _profilePictureUrl = me.picture;
        _profileFirstName = me.firstName;
        _profileLastName = me.lastName;
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _bottomBarController.dispose();
    _pageController.dispose();
    _autoShowTimer?.cancel();
    super.dispose();
  }

  void _handleScroll(ScrollNotification notification) {
    // Only handle scroll updates from the main scrollable
    if (notification is! ScrollUpdateNotification) return;

    // Ignore horizontal scroll events (like PageView swipes)
    if (notification.metrics.axis != Axis.vertical) return;

    // Check if we have enough content to warrant hiding navigation
    // For Catalog tab (index 3), check if there's scrollable content
    if (_selectedIndex == 3) {
      // Check if there's enough content to scroll
      final maxScroll = notification.metrics.maxScrollExtent;
      if (maxScroll < 300) { // Less than 300px of scrollable content (~5 cards)
        _showBars(); // Always show bars when content is minimal
        return;
      }
    }

    final now = DateTime.now();
    final timeDiff = now.difference(_lastScrollTime).inMilliseconds;

    if (timeDiff == 0) return;

    final scrollDelta = notification.scrollDelta ?? 0;
    final metrics = notification.metrics;

    // Calculate velocity (pixels per second)
    final velocity = (scrollDelta / timeDiff) * 1000;

    // Cancel any pending auto-show timer
    _autoShowTimer?.cancel();

    // Always show when at the top
    if (metrics.pixels <= 0) {
      _showBars();
      return;
    }

    // Velocity-based detection for more responsive feel
    final shouldHide = velocity > _velocityThreshold ||
                       (scrollDelta > _scrollThreshold && velocity > 0);
    final shouldShow = velocity < -_velocityThreshold ||
                       (scrollDelta < -_scrollThreshold && velocity < 0);

    if (shouldHide && _isBottomBarVisible) {
      _hideBars();
    } else if (shouldShow && !_isBottomBarVisible) {
      _showBars();
    }

    // Auto-show after scroll stops (like Facebook)
    _autoShowTimer = Timer(_autoShowDelay, () {
      if (!_isBottomBarVisible && mounted) {
        _showBars();
      }
    });

    _lastScrollOffset = metrics.pixels;
    _lastScrollVelocity = velocity;
    _lastScrollTime = now;
  }

  void _showBars() {
    if (!_isBottomBarVisible) {
      HapticFeedback.selectionClick();
      setState(() {
        _isBottomBarVisible = true;
      });
      _bottomBarController.forward();
    }
  }

  void _hideBars() {
    if (_isBottomBarVisible) {
      HapticFeedback.selectionClick();
      setState(() {
        _isBottomBarVisible = false;
      });
      _bottomBarController.reverse();
    }
  }

  void _onItemTapped(int index) {
    HapticFeedback.lightImpact();

    // Always show bars when switching tabs
    _showBars();

    setState(() {
      _selectedIndex = index;
    });

    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    context.watch<TerminologyProvider>().updateSystemLanguage(context);
    final bool isDesktop = MediaQuery.of(context).size.width >= 1200;

    if (isDesktop) {
      return _buildDesktopLayout();
    }

    return Scaffold(
      body: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          _handleScroll(notification);
          return false;
        },
        child: Stack(
          children: [
            // Main content with PageView
            PageView(
              controller: _pageController,
              onPageChanged: (index) {
                // Show bars when page changes
                _showBars();
                setState(() {
                  _selectedIndex = index;
                });
              },
              children: _screens,
            ),

            // Animated bottom navigation bar — frosted glass, 90% hide on scroll
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: AnimatedBuilder(
                animation: _bottomBarAnimation,
                builder: (context, child) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    final box = _navBarKey.currentContext?.findRenderObject() as RenderBox?;
                    if (box != null && box.hasSize) {
                      _navBarHeight = box.size.height;
                    }
                  });
                  // Slide 75% off screen when hidden — 25% frosted strip remains
                  final translateY = (1 - _bottomBarAnimation.value) * _navBarHeight * 0.75;
                  final iconOpacity = _bottomBarAnimation.value.clamp(0.0, 1.0);
                  return Transform.translate(
                    offset: Offset(0, translateY),
                    child: Opacity(
                      opacity: iconOpacity,
                      child: child,
                    ),
                  );
                },
                child: _buildBottomNavigationBar(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      key: _navBarKey,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 2, 8, 0),
          child: IntrinsicHeight(
            child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Main pill ──────────────────────────────
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(26),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          Color(0xCCFFFFFF),
                          Color(0xBBEAEEFF),
                        ],
                      ),
                        borderRadius: BorderRadius.circular(26),
                        border: Border.all(
                          color: Color(0x88FFFFFF),
                          width: 0.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.10),
                            blurRadius: 24,
                            offset: const Offset(0, 6),
                          ),
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildNavButton(0, Icons.view_module, context.watch<TerminologyProvider>().plural),
                          _buildNavButton(1, Icons.calendar_month_rounded, l10n.navSchedule),
                          _buildNavButton(2, Icons.chat_bubble_outline, l10n.navChat),
                          _buildMoreButton(context),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // ── New Job island ─────────────────────────
              ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AIChatScreen()),
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          Color(0xCCFFFFFF),
                          Color(0xBBEAEEFF),
                        ],
                      ),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: Color(0x88FFFFFF),
                          width: 0.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.10),
                            blurRadius: 24,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Icon(
                          Icons.add_rounded,
                          color: AppColors.navySpaceCadet,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavButton(int index, IconData icon, String label) {
    final isSelected = _selectedIndex == index;

    return Expanded(
      child: Listener(
        onPointerDown: (_) {
          _onItemTapped(index);
        },
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.navySpaceCadet : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                icon,
                color: isSelected ? Colors.white : Colors.grey[600],
                size: 20,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppColors.navySpaceCadet : Colors.grey[600],
                fontSize: 9,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                letterSpacing: 0.1,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMoreButton(BuildContext context) {
    final isActive = _selectedIndex >= 3;
    return Expanded(
      child: Listener(
        onPointerDown: (_) => _showMoreSheet(context),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: isActive ? AppColors.navySpaceCadet : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: InitialsAvatar(
                imageUrl: _profilePictureUrl,
                firstName: _profileFirstName ?? '',
                lastName: _profileLastName ?? '',
                radius: 11,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              'Más',
              style: TextStyle(
                color: isActive ? AppColors.navySpaceCadet : Colors.grey[600],
                fontSize: 9,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMoreSheet(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final fullName = [_profileFirstName, _profileLastName]
        .where((s) => s != null && s.isNotEmpty)
        .join(' ');

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        snap: true,
        snapSizes: const [0.75, 0.92],
        builder: (ctx, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              // Drag handle
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 20),
                decoration: BoxDecoration(
                  color: AppColors.borderMedium,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Profile header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    InitialsAvatar(
                      imageUrl: _profilePictureUrl,
                      firstName: _profileFirstName ?? '',
                      lastName: _profileLastName ?? '',
                      radius: 28,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            fullName.isNotEmpty ? fullName : 'Manager',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.navySpaceCadet,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'FlowShift Manager',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded, color: Colors.grey[400]),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),
              Divider(height: 1, color: AppColors.borderLight),
              const SizedBox(height: 8),

              // Navigation items
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  children: [
                    _buildSheetNavTile(
                      ctx: ctx,
                      icon: Icons.inventory_2,
                      label: l10n.navCatalog,
                      index: 3,
                    ),
                    _buildSheetNavTile(
                      ctx: ctx,
                      icon: Icons.fact_check_outlined,
                      label: l10n.navAttendance,
                      index: 4,
                    ),
                    _buildSheetNavTile(
                      ctx: ctx,
                      icon: Icons.bar_chart,
                      label: l10n.navStats,
                      index: 5,
                    ),
                    const SizedBox(height: 8),
                    Divider(height: 1, color: AppColors.borderLight),
                    const SizedBox(height: 8),
                    _buildSheetActionTile(
                      ctx: ctx,
                      icon: Icons.settings_outlined,
                      label: l10n.settings,
                      onTap: () {
                        Navigator.pop(ctx);
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const SettingsPage()),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSheetNavTile({
    required BuildContext ctx,
    required IconData icon,
    required String label,
    required int index,
  }) {
    final isActive = _selectedIndex == index;
    return Listener(
      onPointerDown: (_) {
        Navigator.pop(ctx);
        _onItemTapped(index);
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.navySpaceCadet.withValues(alpha: 0.06)
              : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 22,
                color: isActive ? AppColors.navySpaceCadet : Colors.grey[600]),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                color: isActive ? AppColors.navySpaceCadet : AppColors.textSecondary,
              ),
            ),
            const Spacer(),
            Icon(Icons.chevron_right_rounded,
                size: 20, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  Widget _buildSheetActionTile({
    required BuildContext ctx,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(icon, size: 22, color: Colors.grey[600]),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
            const Spacer(),
            Icon(Icons.chevron_right_rounded, size: 20, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      body: Row(
        children: [
          // Navigation Rail
          _buildNavigationRail(),
          // Content - Using IndexedStack for web to avoid PageView issues
          Expanded(
            child: IndexedStack(
              index: _selectedIndex,
              children: _screens,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationRail() {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      width: 240,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.navySpaceCadet, AppColors.oceanBlue],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          // Logo section
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Image.asset(
                    'assets/logo_icon_square.png',
                    width: 32,
                    height: 32,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.sync_alt,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Flowshift',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          const Divider(
            color: Colors.white24,
            height: 1,
            indent: 24,
            endIndent: 24,
          ),
          const SizedBox(height: 20),
          // Navigation items
          // ===== HOME & CREATE BUTTONS REMOVED =====
          // _buildRailItem(0, Icons.home_rounded, 'Home'),
          // _buildRailItem(1, Icons.add_circle_outline, 'Create'),
          // ===== END REMOVED BUTTONS =====
          _buildRailItem(0, Icons.view_module, context.watch<TerminologyProvider>().plural), // Events (index 0)
          _buildRailItem(1, Icons.calendar_month_rounded, l10n.navSchedule), // Calendar (index 1)
          _buildRailItem(2, Icons.chat_bubble_outline, l10n.navChat), // Chat (index 2)
          _buildRailItem(3, Icons.inventory_2, l10n.navCatalog), // Catalog (index 3)
          _buildRailItem(4, Icons.fact_check_outlined, l10n.navAttendance), // Attendance (index 4)
          const Spacer(),
          // Settings at bottom
          _buildRailItem(-1, Icons.settings, l10n.settings),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildRailItem(int index, IconData icon, String label) {
    final bool isSelected = _selectedIndex == index;

    // Use Listener for raw pointer events to bypass gesture issues
    return Listener(
      onPointerDown: (_) {
        if (index >= 0) {
          setState(() {
            _selectedIndex = index;
          });
        } else if (index == -1) {
          // Navigate to Settings
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const SettingsPage(),
            ),
          );
        }
      },
      behavior: HitTestBehavior.opaque,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
            ? Colors.white.withOpacity(0.2)
            : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected
                ? Colors.white
                : Colors.white.withOpacity(0.7),
              size: 24,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: isSelected
                  ? Colors.white
                  : Colors.white.withOpacity(0.8),
                fontSize: 15,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            if (isSelected) ...[
              const Spacer(),
              Container(
                width: 4,
                height: 20,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ],
        ),
        ),
      ),
    );
  }
}
