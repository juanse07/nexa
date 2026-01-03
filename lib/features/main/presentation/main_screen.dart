import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../services/terminology_provider.dart';
// ===== HOME DASHBOARD COMMENTED OUT - SAVED FOR FUTURE USE =====
// import '../../home/presentation/home_screen.dart';
// ===== END HOME DASHBOARD IMPORT =====
import '../../extraction/presentation/extraction_screen.dart';
import '../../chat/presentation/conversations_screen.dart';
import '../../attendance/presentation/attendance_dashboard_screen.dart';
import '../../users/presentation/pages/settings_page.dart';
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

  // Scroll detection variables
  double _lastScrollOffset = 0;
  double _lastScrollVelocity = 0;
  DateTime _lastScrollTime = DateTime.now();
  Timer? _autoShowTimer;
  bool _isBottomBarVisible = true;

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
    ), // Jobs/Events tab (now index 0)
    const ConversationsScreen(), // Chat screen (now index 1)
    const ExtractionScreen(
      initialScreenIndex: 4,
      hideNavigationRail: true,
    ), // Catalog screen (now index 2)
    const AttendanceDashboardScreen(), // Attendance tab (index 3)
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
    // For Jobs/Events tab (index 2), check if there's scrollable content
    if (_selectedIndex == 2) {
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

            // Animated bottom navigation bar
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _bottomBarAnimation,
                  builder: (context, child) {
                    // Move completely off screen (bar height + safe area + extra margin)
                    final translateY = (1 - _bottomBarAnimation.value) * 150;
                    return Transform.translate(
                      offset: Offset(0, translateY),
                      child: child,
                    );
                  },
                  child: _buildBottomNavigationBar(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.formFillSlate, // Light grey background
        border: Border(
          top: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      child: SafeArea(
        top: false, // Don't add top padding
        child: SizedBox(
          height: 48, // Facebook/Instagram exact height
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // ===== HOME & CREATE BUTTONS REMOVED =====
              // _buildNavButton(0, Icons.home_rounded, 'Home'),
              // _buildNavButton(1, Icons.add_circle_outline, 'Create'),
              // ===== END REMOVED BUTTONS =====
              _buildNavButton(0, Icons.view_module, context.watch<TerminologyProvider>().plural), // Was index 2, now 0
              _buildNavButton(1, Icons.chat_bubble_outline, 'Chat'), // Was index 3, now 1
              _buildNavButton(2, Icons.inventory_2, 'Catalog'), // Was index 4, now 2
              _buildNavButton(3, Icons.fact_check_outlined, 'Attendance'), // Attendance tab (index 3)
            ],
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
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.techBlue : AppColors.primaryPurple, // Tech blue selected, Navy unselected
              size: 28, // Larger icons for better visibility
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppColors.techBlue : const Color(0xFF64748B), // Tech blue selected, Slate grey unselected
                fontSize: 10, // Optimized for 48px height
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                letterSpacing: 0.2,
              ),
            ),
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
                    'assets/logo_icon_square_transparent.png',
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
          _buildRailItem(0, Icons.view_module, context.watch<TerminologyProvider>().plural), // Was index 2, now 0
          _buildRailItem(1, Icons.chat_bubble_outline, 'Chat'), // Was index 3, now 1
          _buildRailItem(2, Icons.inventory_2, 'Catalog'), // Was index 4, now 2
          _buildRailItem(3, Icons.fact_check_outlined, 'Attendance'), // Attendance tab (index 3)
          const Spacer(),
          // Settings at bottom
          _buildRailItem(-1, Icons.settings, 'Settings'),
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
