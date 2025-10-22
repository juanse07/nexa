import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'widgets/stats_card.dart';
import '../../main/presentation/main_screen.dart';
import '../../extraction/presentation/extraction_screen.dart';
import '../../extraction/presentation/ai_chat_screen.dart';
import '../../teams/presentation/pages/teams_management_page.dart';
import '../../hours_approval/presentation/hours_approval_list_screen.dart';
import '../../chat/presentation/conversations_screen.dart';
import '../data/services/home_stats_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  late AnimationController _animationController;
  double _scrollOffset = 0.0;
  final HomeStatsService _statsService = HomeStatsService();

  // Stats data
  int _upcomingJobsCount = 0;
  int _teamMembersCount = 0;
  int _weekHours = 0;
  String _teamName = 'My Team';
  bool _statsLoading = true;

  final List<FeatureItem> _features = [
    FeatureItem(
      icon: Icons.chat_bubble_outline,
      title: 'Chat',
      description: 'send jobs through the chat',
      color: const Color(0xFF6366F1),
      accentColor: const Color(0xFF8B5CF6),
      index: 3, // Chat screen index in MainScreen (ConversationsScreen)
    ),
    FeatureItem(
      icon: Icons.auto_awesome,
      title: 'AI Chat',
      description: 'create, update, ask questions ',
      color: const Color(0xFFEC4899), // Pink
      accentColor: const Color(0xFFF472B6),
      index: -2, // Special index for AI Chat screen
      isAI: true,
    ),
    FeatureItem(
      icon: Icons.calendar_today,
      title: 'Jobs',
      description: 'Manage your created cards',
      color: const Color(0xFF8B5CF6), // Purple
      accentColor: const Color(0xFFA78BFA),
      index: 2, // Jobs/Events tab in MainScreen
    ),
    FeatureItem(
      icon: Icons.group_outlined,
      title: 'Teams',
      description: 'invite people to Join',
      color: const Color(0xFF10B981), // Green
      accentColor: const Color(0xFF34D399),
      index: -3, // Special index for Teams Management page
    ),
    FeatureItem(
      icon: Icons.access_time,
      title: 'Hours',
      description: 'Trackteam work hours',
      color: const Color(0xFFF59E0B), // Orange
      accentColor: const Color(0xFFFBBF24),
      index: -4, // Special index for Hours screen
    ),
    FeatureItem(
      icon: Icons.inventory_2_outlined,
      title: 'Catalog',
      description: 'create clients, roles, and tariffs',
      color: const Color(0xFF6366F1), // Blue
      accentColor: const Color(0xFF818CF8),
      index: 4, // Catalog screen index in MainScreen
    ),
  ];

  final List<QuickAction> _quickActions = [
    QuickAction(icon: Icons.auto_awesome, label: 'AI Chat', isAIChat: true), // AI Chat screen
    QuickAction(icon: Icons.upload_file, label: 'Upload', tabIndex: 0), // Upload tab
    QuickAction(icon: Icons.add_circle_outline, label: 'Create', tabIndex: 2), // Manual tab
    QuickAction(icon: Icons.qr_code_scanner, label: 'Timesheet', tabIndex: 0), // Scan goes to Upload (merged)
   
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000), // Slower animation
    ); // Removed ..repeat() to stop continuous animation

    _scrollController.addListener(() {
      // Only update if offset changed significantly (reduces rebuilds)
      if ((_scrollOffset - _scrollController.offset).abs() > 15) {
        setState(() {
          _scrollOffset = _scrollController.offset;
        });
      }
    });

    // Load stats data
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final jobs = await _statsService.fetchUpcomingJobsCount();
      final members = await _statsService.fetchTeamMembersCount();
      final hours = await _statsService.fetchThisWeekHours();
      final teamName = await _statsService.fetchTeamName();

      if (mounted) {
        setState(() {
          _upcomingJobsCount = jobs;
          _teamMembersCount = members;
          _weekHours = hours;
          _teamName = teamName;
          _statsLoading = false;
        });
      }
    } catch (e) {
      print('Error loading stats: $e');
      if (mounted) {
        setState(() {
          _statsLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  /// Navigate with smooth fade transition
  void _navigateWithFade(Widget destination) {
    Navigator.of(context).push<void>(
      PageRouteBuilder<void>(
        pageBuilder: (context, animation, secondaryAnimation) => destination,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.03, 0.03); // Subtle upward slide
          const end = Offset.zero;
          const curve = Curves.easeOutCubic;

          final slideTween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          final fadeTween = Tween<double>(begin: 0.0, end: 1.0).chain(CurveTween(curve: curve));

          return SlideTransition(
            position: animation.drive(slideTween),
            child: FadeTransition(
              opacity: animation.drive(fadeTween),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  void _navigateToTab(int index, {int? tabIndex}) {
    // Special case for AI Chat screen
    if (index == -2) {
      _navigateWithFade(const AIChatScreen(startNewConversation: true));
      return;
    }

    // Special case for Teams Management page
    if (index == -3) {
      _navigateWithFade(const TeamsManagementPage());
      return;
    }

    // Special case for Hours screen
    if (index == -4) {
      _navigateWithFade(const HoursApprovalListScreen());
      return;
    }

    // Jobs screen - ExtractionScreen with Jobs tab
    if (index == 2) {
      _navigateWithFade(const ExtractionScreen(initialScreenIndex: 1));
      return;
    }

    // Chat screen - ConversationsScreen
    if (index == 3) {
      _navigateWithFade(ConversationsScreen());
      return;
    }

    // Catalog screen - ExtractionScreen with Catalog tab
    if (index == 4) {
      _navigateWithFade(const ExtractionScreen(initialScreenIndex: 4));
      return;
    }

    // Find the MainScreen and update its selected index
    final mainScreenState = context.findAncestorStateOfType<State>();
    if (mainScreenState != null && mainScreenState.mounted) {
      // Access parent's PageController if available
      if (mainScreenState.widget.runtimeType.toString() == 'MainScreen') {
        // If navigating to Create tab (index 1) with a specific tabIndex
        if (index == 1 && tabIndex != null) {
          // Navigate directly to ExtractionScreen with the specific tab
          Navigator.of(context).push<void>(
            MaterialPageRoute<void>(
              builder: (context) => ExtractionScreen(initialIndex: tabIndex),
            ),
          );
        } else {
          // Navigate to the main screen tab
          Navigator.of(context).pushReplacement<void, void>(
            PageRouteBuilder<void>(
              pageBuilder: (context, animation, secondaryAnimation) =>
                  MainScreen(initialIndex: index),
              transitionDuration: Duration.zero,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        top: false, // Allow AppBar to go under status bar
        bottom: false, // Handle bottom padding manually
        child: CustomScrollView(
          controller: _scrollController,
          physics: const ClampingScrollPhysics(),
          slivers: [
            _buildAnimatedAppBar(),
            _buildOverlappingStatsSection(),
            _buildQuickActionsSection(),
            _buildFeaturesGrid(),
            _buildRecentActivitySection(),
            // Add proper bottom padding for navigation bar
            SliverToBoxAdapter(
              child: SizedBox(
                height: 80, // Nav bar height (64) + small breathing room (16)
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedAppBar() {
    return SliverAppBar(
      expandedHeight: 280.0,
      floating: false,
      pinned: true,
      stretch: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      flexibleSpace: RepaintBoundary(
        child: LayoutBuilder(
        builder: (context, constraints) {
          final double expandRatio = ((constraints.maxHeight - kToolbarHeight) /
                                     (280.0 - kToolbarHeight)).clamp(0.0, 1.0);
          final double parallaxOffset = _scrollOffset * 0.5;

          return Stack(
            fit: StackFit.expand,
            children: [
              // Gradient background with parallax
              Positioned(
                top: -parallaxOffset,
                left: 0,
                right: 0,
                height: constraints.maxHeight + parallaxOffset,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF7C3AED),
                        Color(0xFF6366F1),
                        Color(0xFF8B5CF6),
                      ],
                      stops: [0.0, 0.5, 1.0],
                    ),
                  ),
                ),
              ),

              // Static decorative circles (no animation)
              Positioned(
                top: 50 - parallaxOffset * 0.3,
                right: -30,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withAlpha(20), // Fixed opacity
                  ),
                ),
              ),
              Positioned(
                top: 90 - parallaxOffset * 0.3,
                right: 30,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withAlpha(15), // Fixed opacity
                  ),
                ),
              ),

              // Content
              Positioned(
                left: 20,
                right: 20,
                bottom: 40,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Greeting with animation
                    AnimatedOpacity(
                      opacity: expandRatio > 0.5 ? expandRatio : 0.0,
                      duration: const Duration(milliseconds: 150),
                      child: AnimatedSlide(
                        offset: Offset(0, 1 - expandRatio),
                        duration: const Duration(milliseconds: 150),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Welcome back!',
                              style: TextStyle(
                                color: Color(0xE6FFFFFF), // 90% opacity white
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Manage your events',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.5,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 20),
                            // Search bar (expanded version)
                            AnimatedOpacity(
                              opacity: expandRatio > 0.5 ? 1.0 : 0.0,
                              duration: const Duration(milliseconds: 150),
                              child: Container(
                                height: 52,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x14000000), // 8% black
                                      blurRadius: 10,
                                      offset: Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: TextField(
                                  decoration: InputDecoration(
                                    hintText: 'Search events, teams, or chats...',
                                    hintStyle: TextStyle(
                                      color: Colors.grey.shade400,
                                      fontSize: 14,
                                    ),
                                    prefixIcon: const Icon(
                                      Icons.search,
                                      color: Color(0xFF7C3AED),
                                    ),
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 16,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Collapsed search bar
              Positioned(
                left: 20,
                right: 20,
                bottom: 8,
                child: AnimatedOpacity(
                  opacity: expandRatio < 0.5 ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 150),
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x14000000), // 8% black
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Search...',
                        hintStyle: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 13,
                        ),
                        prefixIcon: const Icon(
                          Icons.search,
                          color: Color(0xFF7C3AED),
                          size: 20,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
        ),
      ),
    );
  }

  Widget _buildOverlappingStatsSection() {
    return SliverToBoxAdapter(
      child: RepaintBoundary(
        child: Container(
          height: 70,
          margin: const EdgeInsets.only(left: 12, right: 12, top: 10, bottom: 10), // Natural spacing
          child: _statsLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                children: [
                  SizedBox(
                    width: 110,
                    child: StatsCard(
                      title: 'Jobs',
                      value: _upcomingJobsCount.toString(),
                      icon: Icons.work_outline,
                      color: const Color(0xFF6366F1),
                      subtitle: 'Upcoming',
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 110,
                    child: StatsCard(
                      title: 'Team Members',
                      value: _teamMembersCount.toString(),
                      icon: Icons.people_outline,
                      color: const Color(0xFF8B5CF6),
                      subtitle: _teamName,
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 110,
                    child: StatsCard(
                      title: 'Hours',
                      value: _weekHours.toString(),
                      icon: Icons.access_time,
                      color: const Color(0xFFF59E0B),
                      subtitle: 'This Week',
                    ),
                  ),
                ],
              ),
        ),
      ),
    );
  }

  Widget _buildQuickActionsSection() {
    return SliverToBoxAdapter(
      child: RepaintBoundary(
        child: Container(
          height: 100,
          margin: const EdgeInsets.only(left: 20, right: 20, top: 10, bottom: 10),
          child: ListView.builder(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          itemCount: _quickActions.length,
          itemBuilder: (context, index) {
            final action = _quickActions[index];
            return _buildQuickActionChip(action, index);
          },
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionChip(QuickAction action, int index) {
    return Container(
      margin: const EdgeInsets.only(right: 12),
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          // Navigate to AI Chat screen
          if (action.isAIChat) {
            _navigateWithFade(const AIChatScreen(startNewConversation: true));
          }
          // Navigate to ExtractionScreen with the specific tab
          else if (action.tabIndex != null) {
            _navigateWithFade(ExtractionScreen(initialIndex: action.tabIndex!));
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1A7C3AED), // 10% purple
                blurRadius: 10,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  action.icon,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                action.label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeaturesGrid() {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16), // Proper padding
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.15, // Taller cards to prevent text overflow
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final feature = _features[index];
            return _buildFeatureCard(feature, index);
          },
          childCount: _features.length,
        ),
      ),
    );
  }

  Widget _buildFeatureCard(FeatureItem feature, int index) {
    return RepaintBoundary(
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          // Navigate to the screen with optional tab index
          // Handles both positive indices (MainScreen tabs) and negative indices (special screens)
          _navigateToTab(feature.index, tabIndex: feature.tabIndex);
        },
        child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              feature.color,
              feature.accentColor,
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: feature.color.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
              spreadRadius: 0,
            ),
          ],
        ),
        child: Stack(
          children: [
            // Decorative gradient overlay circles for depth
            Positioned(
              top: -20,
              right: -20,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.1),
                ),
              ),
            ),
            Positioned(
              bottom: -10,
              left: -10,
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withOpacity(0.05),
                ),
              ),
            ),

            // AI badge for AI features
            if (feature.isAI)
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.4),
                      width: 1,
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_awesome, size: 10, color: Colors.white),
                      SizedBox(width: 4),
                      Text(
                        'AI',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Large prominent icon with glass effect
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 1.5,
                      ),
                    ),
                    child: Icon(
                      feature.icon,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  // Text content
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        feature.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        feature.description,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.85),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
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

  Widget _buildRecentActivitySection() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20), // Normal padding - SafeArea handles bottom
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Recent Activity',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 16),
            ...List.generate(3, (index) => _buildActivityCard(index)),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityCard(int index) {
    final activities = [
      {'title': 'New event created', 'subtitle': 'Roofing installation - 2:00 PM', 'icon': Icons.calendar_today},
      {'title': 'Message from John', 'subtitle': 'About tomorrow\'s schedule', 'icon': Icons.chat_bubble_outline},
      {'title': 'Team update', 'subtitle': '3 new members added', 'icon': Icons.group_add},
    ];

    final activity = activities[index];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000), // 4% black
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0x1A7C3AED), // 10% purple
                  Color(0x1A6366F1), // 10% purple
                ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              activity['icon'] as IconData,
              color: const Color(0xFF7C3AED),
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity['title'] as String,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  activity['subtitle'] as String,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.arrow_forward_ios,
            size: 14,
            color: Colors.grey.shade400,
          ),
        ],
      ),
    );
  }
}

class FeatureItem {
  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final Color accentColor;
  final int index;
  final int? tabIndex; // Optional tab index for ExtractionScreen
  final bool isAI;

  FeatureItem({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    required this.accentColor,
    required this.index,
    this.tabIndex,
    this.isAI = false,
  });
}

class QuickAction {
  final IconData icon;
  final String label;
  final int? tabIndex; // Optional tab index for ExtractionScreen
  final bool isAIChat; // Flag for AI Chat screen

  QuickAction({
    required this.icon,
    required this.label,
    this.tabIndex,
    this.isAIChat = false,
  });
}