import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:nexa/core/network/api_client.dart';
import 'package:nexa/services/caricature_service.dart';
import 'package:nexa/shared/presentation/theme/app_colors.dart';

/// Icon mapping from backend icon names to Flutter IconData.
const _iconMap = <String, IconData>{
  // Hospitality & Events
  'local_bar': Icons.local_bar_rounded,
  'restaurant': Icons.restaurant_rounded,
  'security': Icons.security_rounded,
  'headphones': Icons.headphones_rounded,
  'emoji_people': Icons.emoji_people_rounded,
  'event_note': Icons.event_note_rounded,
  'soup_kitchen': Icons.soup_kitchen_rounded,
  'cleaning_services': Icons.cleaning_services_rounded,
  'liquor': Icons.liquor_rounded,
  'business_center': Icons.business_center_rounded,
  'camera_alt': Icons.camera_alt_rounded,
  'directions_car': Icons.directions_car_rounded,
  // Healthcare
  'medical_services': Icons.medical_services_rounded,
  'favorite': Icons.favorite_rounded,
  'healing': Icons.healing_rounded,
  'mood': Icons.mood_rounded,
  'pets': Icons.pets_rounded,
  'local_hospital': Icons.local_hospital_rounded,
  // Legal & Business
  'gavel': Icons.gavel_rounded,
  'calculate': Icons.calculate_rounded,
  'trending_up': Icons.trending_up_rounded,
  'home': Icons.home_rounded,
  'assessment': Icons.assessment_rounded,
  // Tech
  'code': Icons.code_rounded,
  'insights': Icons.insights_rounded,
  'design_services': Icons.design_services_rounded,
  // Trades & Construction
  'construction': Icons.construction_rounded,
  'electrical_services': Icons.electrical_services_rounded,
  'plumbing': Icons.plumbing_rounded,
  'build': Icons.build_rounded,
  'local_fire_department': Icons.local_fire_department_rounded,
  'carpenter': Icons.carpenter_rounded,
  'architecture': Icons.architecture_rounded,
  // Creative
  'music_note': Icons.music_note_rounded,
  'palette': Icons.palette_rounded,
  'videocam': Icons.videocam_rounded,
  'edit': Icons.edit_rounded,
  'checkroom': Icons.checkroom_rounded,
  // Emergency & Service
  'local_police': Icons.local_police_rounded,
  'flight': Icons.flight_rounded,
  'military_tech': Icons.military_tech_rounded,
  // Education
  'school': Icons.school_rounded,
  'history_edu': Icons.history_edu_rounded,
  // Sports & Fitness
  'sports': Icons.sports_rounded,
  'fitness_center': Icons.fitness_center_rounded,
  'self_improvement': Icons.self_improvement_rounded,
  // Science
  'science': Icons.science_rounded,
  'rocket_launch': Icons.rocket_launch_rounded,
  // Art style icons
  'sentiment_very_satisfied': Icons.sentiment_very_satisfied_rounded,
  'badge': Icons.badge_rounded,
  'brush': Icons.brush_rounded,
  'auto_awesome': Icons.auto_fix_high_rounded,
  'menu_book': Icons.menu_book_rounded,
  'movie': Icons.movie_rounded,
};

/// Category display order
const _categoryOrder = [
  'Hospitality & Events',
  'Healthcare',
  'Legal & Business',
  'Tech',
  'Trades & Construction',
  'Creative',
  'Emergency & Service',
  'Education',
  'Sports & Fitness',
  'Science',
];

/// Category icons for section headers
const _categoryIcons = <String, IconData>{
  'Hospitality & Events': Icons.nightlife_rounded,
  'Healthcare': Icons.local_hospital_rounded,
  'Legal & Business': Icons.business_rounded,
  'Tech': Icons.computer_rounded,
  'Trades & Construction': Icons.construction_rounded,
  'Creative': Icons.color_lens_rounded,
  'Emergency & Service': Icons.emergency_rounded,
  'Education': Icons.school_rounded,
  'Sports & Fitness': Icons.fitness_center_rounded,
  'Science': Icons.science_rounded,
};

/// Fun loading messages that cycle during generation.
const _loadingMessages = [
  'Setting the scene...',
  'Getting your look right...',
  'Adding the finishing touches...',
  'Almost there...',
  'Looking sharp...',
];

/// How many roles to show before the "See More" button
const _initialRoleCount = 12;

/// Predefined taglines grouped by role category + generics.
const _taglinesByCategory = <String, List<String>>{
  '_generic': [
    'Living the Dream',
    'Built Different',
    'On a Mission',
    'Level Up',
  ],
  'Hospitality & Events': [
    'Born to Host',
    'Making Nights Happen',
    'Service with Style',
    'The Life of the Party',
  ],
  'Healthcare': [
    'Saving Lives Daily',
    'Always On Call',
    'Heart of Gold',
    'Healing Hands',
  ],
  'Legal & Business': [
    'Closing Deals',
    'Boss Moves Only',
    'Making It Happen',
    'The Closer',
  ],
  'Tech': [
    'Code & Coffee',
    'Shipping It',
    'In My Element',
    'Ctrl+Alt+Dominate',
  ],
  'Trades & Construction': [
    'Built to Last',
    'Skilled Hands',
    'Getting It Done',
    'Hard Work Pays Off',
  ],
  'Creative': [
    'Creating Magic',
    'Art Is Life',
    'Born Creative',
    'Vision to Reality',
  ],
  'Emergency & Service': [
    'Courage Under Fire',
    'Serving with Honor',
    'Always Ready',
    'First to Respond',
  ],
  'Education': [
    'Shaping Minds',
    'Knowledge Is Power',
    'Born to Teach',
    'Inspiring Futures',
  ],
  'Sports & Fitness': [
    'No Days Off',
    'Beast Mode',
    'Stronger Every Day',
    'All In',
  ],
  'Science': [
    'For Science',
    'Exploring the Unknown',
    'Curious Mind',
    'Discovery Mode',
  ],
};

/// Bottom sheet for generating fun profile pictures.
class CaricatureGeneratorSheet extends StatefulWidget {
  const CaricatureGeneratorSheet({
    super.key,
    required this.currentPictureUrl,
    required this.onAccepted,
    this.userName,
    this.userLastName,
  });

  final String currentPictureUrl;
  final ValueChanged<String> onAccepted;
  final String? userName;
  final String? userLastName;

  @override
  State<CaricatureGeneratorSheet> createState() => _CaricatureGeneratorSheetState();
}

class _CaricatureGeneratorSheetState extends State<CaricatureGeneratorSheet>
    with SingleTickerProviderStateMixin {
  late final CaricatureService _service;

  List<CaricatureRole> _roles = [];
  List<CaricatureArtStyle> _artStyles = [];
  bool _loadingStyles = true;
  String? _selectedRoleId;
  String? _selectedArtStyleId;
  String _selectedModel = 'dev'; // 'dev' = Standard, 'pro' = HD
  CaricatureResult? _preview; // base64 previews (not yet saved)
  int _selectedImageIndex = 0;
  PageController? _pageController;
  bool _generating = false;
  bool _accepting = false;
  String? _error;
  bool _showAllRoles = false;

  // Text overlay chips
  bool _includeNameChip = false;
  String? _selectedTagline;

  // Loading message rotation
  int _loadingMessageIndex = 0;
  Timer? _loadingMessageTimer;

  // Gentle button animation
  late AnimationController _btnController;
  late Animation<double> _btnScale;

  @override
  void initState() {
    super.initState();
    _service = CaricatureService(GetIt.I<ApiClient>());

    _btnController = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    )..repeat(reverse: true);
    _btnScale = Tween<double>(begin: 1.0, end: 1.03).animate(
      CurvedAnimation(parent: _btnController, curve: Curves.easeInOut),
    );

    _loadStyles();
  }

  @override
  @override
  void dispose() {
    _loadingMessageTimer?.cancel();
    _pageController?.dispose();
    _btnController.dispose();
    super.dispose();
  }

  Future<void> _loadStyles() async {
    try {
      final resp = await _service.getStyles();
      if (!mounted) return;
      setState(() {
        _roles = resp.roles;
        _artStyles = resp.artStyles;
        _loadingStyles = false;
        final firstRole = _roles.where((r) => !r.locked).firstOrNull;
        _selectedRoleId = firstRole?.id;
        final firstStyle = _artStyles.where((s) => !s.locked).firstOrNull;
        _selectedArtStyleId = firstStyle?.id;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingStyles = false;
        _error = 'Failed to load styles';
      });
    }
  }

  void _startLoadingMessages() {
    _loadingMessageIndex = 0;
    _loadingMessageTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!mounted || !_generating) {
        timer.cancel();
        return;
      }
      setState(() {
        _loadingMessageIndex = (_loadingMessageIndex + 1) % _loadingMessages.length;
      });
    });
  }

  Future<void> _generate({bool forceNew = false}) async {
    if (_selectedRoleId == null || _selectedArtStyleId == null) return;

    setState(() {
      _generating = true;
      _error = null;
      _preview = null;
      _selectedImageIndex = 0;
    });
    _pageController?.dispose();
    _pageController = PageController();

    _startLoadingMessages();
    unawaited(HapticFeedback.mediumImpact());

    try {
      final result = await _service.generate(
        _selectedRoleId!,
        _selectedArtStyleId!,
        model: _selectedModel,
        name: _includeNameChip ? _fullName : null,
        tagline: _selectedTagline,
        forceNew: forceNew,
      );
      if (!mounted) return;
      unawaited(HapticFeedback.heavyImpact());
      setState(() {
        _preview = result;
        _generating = false;
      });
      _loadingMessageTimer?.cancel();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _generating = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
      _loadingMessageTimer?.cancel();
    }
  }

  Future<void> _accept() async {
    if (_preview == null) return;
    setState(() => _accepting = true);
    HapticFeedback.mediumImpact();

    try {
      // Cache hit — URL already exists, skip upload
      if (_preview!.cached && _preview!.cachedUrl != null) {
        if (!mounted) return;
        widget.onAccepted(_preview!.cachedUrl!);
        Navigator.of(context).pop();
        return;
      }

      final saved = await _service.accept(_preview!, _selectedImageIndex);
      if (!mounted) return;
      widget.onAccepted(saved.url);
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _accepting = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _tryAnother() {
    _pageController?.dispose();
    _pageController = null;
    setState(() {
      _preview = null;
      _selectedImageIndex = 0;
      _error = null;
    });
  }

  /// Group roles by category, respecting _categoryOrder.
  Map<String, List<CaricatureRole>> _groupedRoles() {
    final map = <String, List<CaricatureRole>>{};
    for (final role in _roles) {
      map.putIfAbsent(role.category, () => []).add(role);
    }
    // Sort by category order
    final sorted = <String, List<CaricatureRole>>{};
    for (final cat in _categoryOrder) {
      if (map.containsKey(cat)) sorted[cat] = map[cat]!;
    }
    // Any remaining categories not in order
    for (final entry in map.entries) {
      if (!sorted.containsKey(entry.key)) sorted[entry.key] = entry.value;
    }
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              _buildHandle(),
              _buildHeader(),
              const Divider(height: 1, color: AppColors.border),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                  children: [
                    _buildRoleSection(),
                    const SizedBox(height: 22),
                    _buildStyleSection(),
                    const SizedBox(height: 18),
                    _buildModelSection(),
                    const SizedBox(height: 18),
                    _buildTextOverlaySection(),
                    const SizedBox(height: 24),
                    _buildPreview(),
                    const SizedBox(height: 20),
                    if (_error != null) _buildError(),
                    _buildAiDisclaimer(),
                    const SizedBox(height: 12),
                    _buildActions(),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHandle() {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: AppColors.borderMedium,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: AppColors.primaryPurple,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.camera_enhance_rounded, color: AppColors.primaryIndigo, size: 24),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Profile Glow Up',
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryPurple,
                    letterSpacing: -0.3,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Your role. Your style. Your look.',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceGray,
              borderRadius: BorderRadius.circular(10),
            ),
            child: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close_rounded, color: AppColors.textMuted, size: 20),
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              padding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleChip(CaricatureRole role) {
    final selected = role.id == _selectedRoleId;
    final icon = _iconMap[role.icon] ?? Icons.person_rounded;
    return GestureDetector(
      onTap: !_generating
          ? () {
              HapticFeedback.selectionClick();
              setState(() {
                _selectedRoleId = role.id;
                _preview = null;
              });
            }
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryPurple : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.primaryPurple : AppColors.border,
            width: 1.5,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.primaryPurple.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: selected ? AppColors.primaryIndigo : AppColors.textMuted,
            ),
            const SizedBox(width: 5),
            Text(
              role.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: selected ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleSection() {
    if (_loadingStyles) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.techBlue),
        ),
      );
    }

    if (!_showAllRoles) {
      // Collapsed: show first N roles as flat chips + "See More"
      final visibleRoles = _roles.take(_initialRoleCount).toList();
      final hiddenCount = _roles.length - _initialRoleCount;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.badge_outlined, size: 18, color: AppColors.primaryPurple.withValues(alpha: 0.7)),
              const SizedBox(width: 8),
              const Text(
                'Who are you today?',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryPurple,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              ...visibleRoles.map((role) => _buildRoleChip(role)),
              if (hiddenCount > 0)
                GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _showAllRoles = true);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: AppColors.primaryPurple.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.primaryPurple.withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.expand_more_rounded,
                          size: 16,
                          color: AppColors.primaryPurple,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'See $hiddenCount more',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryPurple,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      );
    }

    // Expanded: show all roles grouped by category
    final grouped = _groupedRoles();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.badge_outlined, size: 18, color: AppColors.primaryPurple.withValues(alpha: 0.7)),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Who are you today?',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryPurple,
                ),
              ),
            ),
            GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _showAllRoles = false);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.surfaceGray,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.expand_less_rounded, size: 16, color: AppColors.textMuted),
                    const SizedBox(width: 2),
                    Text(
                      'Less',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ...grouped.entries.expand((entry) => [
              // Category header
              Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 8),
                child: Row(
                  children: [
                    Icon(
                      _categoryIcons[entry.key] ?? Icons.category_rounded,
                      size: 14,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      entry.key,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMuted,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              // Chips for this category
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: entry.value.map((role) => _buildRoleChip(role)).toList(),
              ),
            ]),
      ],
    );
  }

  Widget _buildStyleSection() {
    if (_loadingStyles) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.palette_outlined, size: 18, color: AppColors.primaryPurple.withValues(alpha: 0.7)),
            const SizedBox(width: 8),
            const Text(
              'Pick your vibe',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryPurple,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: _artStyles.map((style) {
            final selected = style.id == _selectedArtStyleId;
            final icon = _iconMap[style.icon] ?? Icons.brush_rounded;

            return Expanded(
              child: GestureDetector(
                onTap: !_generating
                    ? () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _selectedArtStyleId = style.id;
                          _preview = null;
                        });
                      }
                    : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.primaryPurple : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: selected ? AppColors.primaryPurple : AppColors.border,
                      width: 1.5,
                    ),
                    boxShadow: selected
                        ? [
                            BoxShadow(
                              color: AppColors.primaryPurple.withValues(alpha: 0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Column(
                    children: [
                      Icon(
                        icon,
                        size: 20,
                        color: selected ? AppColors.primaryIndigo : AppColors.textMuted,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        style.label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: selected ? Colors.white : AppColors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildModelSection() {
    if (_loadingStyles) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.tune_rounded, size: 18, color: AppColors.primaryPurple.withValues(alpha: 0.7)),
            const SizedBox(width: 8),
            const Text(
              'Quality',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryPurple,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<String>(
            segments: const [
              ButtonSegment<String>(
                value: 'dev',
                label: Text('Standard'),
                icon: Icon(Icons.speed_rounded, size: 18),
              ),
              ButtonSegment<String>(
                value: 'pro',
                label: Text('HD'),
                icon: Icon(Icons.hd_rounded, size: 18),
              ),
            ],
            selected: {_selectedModel},
            onSelectionChanged: _generating
                ? null
                : (selection) {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _selectedModel = selection.first;
                      _preview = null;
                    });
                  },
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return AppColors.primaryPurple;
                }
                return Colors.white;
              }),
              foregroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return Colors.white;
                }
                return AppColors.textSecondary;
              }),
              side: WidgetStateProperty.all(
                const BorderSide(color: AppColors.border, width: 1.5),
              ),
              shape: WidgetStateProperty.all(
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              textStyle: WidgetStateProperty.all(
                const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
        if (_selectedModel == 'pro')
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              children: [
                Icon(Icons.auto_awesome_rounded, size: 13, color: AppColors.primaryIndigo),
                const SizedBox(width: 4),
                Text(
                  'Higher detail & better facial preservation',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// Full name from first + last.
  String? get _fullName {
    final first = widget.userName ?? '';
    final last = widget.userLastName ?? '';
    final full = [first, last].where((s) => s.isNotEmpty).join(' ');
    return full.isNotEmpty ? full : null;
  }

  /// Taglines for the currently selected role's category + generics.
  List<String> _availableTaglines() {
    final selectedRole = _roles.where((r) => r.id == _selectedRoleId).firstOrNull;
    final category = selectedRole?.category;
    final generic = _taglinesByCategory['_generic'] ?? <String>[];
    final roleSpecific = category != null ? (_taglinesByCategory[category] ?? <String>[]) : <String>[];
    return [...roleSpecific, ...generic];
  }

  Widget _buildTextOverlaySection() {
    if (_loadingStyles) return const SizedBox.shrink();

    final name = _fullName;
    final taglines = _availableTaglines();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.text_fields_rounded, size: 18, color: AppColors.primaryPurple.withValues(alpha: 0.7)),
            const SizedBox(width: 8),
            const Text(
              'Text in image',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryPurple,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.surfaceGray,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'Optional',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textMuted),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            // "None" chip — selected when no text options are active
            _buildToggleChip(
              label: 'None',
              selected: !_includeNameChip && _selectedTagline == null,
              icon: Icons.block_rounded,
              onTap: () => setState(() {
                _includeNameChip = false;
                _selectedTagline = null;
                _preview = null;
              }),
            ),
            // Name chip (first + last name from profile)
            if (name != null)
              _buildToggleChip(
                label: name,
                selected: _includeNameChip,
                icon: Icons.person_rounded,
                onTap: () => setState(() {
                  _includeNameChip = !_includeNameChip;
                  _preview = null;
                }),
              ),
            // Tagline chips
            ...taglines.map((tagline) => _buildToggleChip(
              label: tagline,
              selected: _selectedTagline == tagline,
              onTap: () => setState(() {
                _selectedTagline = _selectedTagline == tagline ? null : tagline;
                _preview = null;
              }),
            )),
          ],
        ),
      ],
    );
  }

  Widget _buildToggleChip({
    required String label,
    required bool selected,
    IconData? icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: !_generating ? () { HapticFeedback.selectionClick(); onTap(); } : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryPurple : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.primaryPurple : AppColors.border,
            width: 1.5,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.primaryPurple.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected)
              Padding(
                padding: const EdgeInsets.only(right: 5),
                child: Icon(Icons.check_rounded, size: 14, color: AppColors.primaryIndigo),
              )
            else if (icon != null)
              Padding(
                padding: const EdgeInsets.only(right: 5),
                child: Icon(icon, size: 14, color: AppColors.textMuted),
              ),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: selected ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview() {
    if (_generating) {
      return _buildGeneratingState();
    }

    if (_preview != null) {
      return _buildBeforeAfter();
    }

    // Initial state
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.surfaceGray,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primaryIndigo, width: 3),
            ),
            child: ClipOval(
              child: Image.network(
                widget.currentPictureUrl,
                width: 80,
                height: 80,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 80,
                  height: 80,
                  color: AppColors.surfaceGray,
                  child: const Icon(Icons.person, size: 40, color: AppColors.textMuted),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Ready for a new look?',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryPurple,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Hit the button and see the magic',
            style: TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildGeneratingState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      decoration: BoxDecoration(
        color: AppColors.surfaceGray,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          // Simple branded loading indicator
          SizedBox(
            width: 56,
            height: 56,
            child: CircularProgressIndicator(
              strokeWidth: 4,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primaryIndigo),
              backgroundColor: AppColors.primaryPurple.withValues(alpha: 0.15),
            ),
          ),
          const SizedBox(height: 24),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            child: Text(
              _loadingMessages[_loadingMessageIndex],
              key: ValueKey(_loadingMessageIndex),
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryPurple,
              ),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'This usually takes about 15 seconds',
            style: TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildBeforeAfter() {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 14),
          child: Text(
            'Looking good!',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryPurple,
            ),
          ),
        ),
        if (_preview!.cached)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.bolt_rounded, size: 12, color: AppColors.success),
                  const SizedBox(width: 4),
                  Text(
                    'From your history',
                    style: TextStyle(fontSize: 11, color: AppColors.success),
                  ),
                ],
              ),
            ),
          ),
        Row(
          children: [
            Expanded(child: _buildImageCard('Before', widget.currentPictureUrl, false)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryPurple,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_forward_rounded, color: AppColors.primaryIndigo, size: 16),
              ),
            ),
            Expanded(
              child: Column(
                children: [
                  const Text(
                    'After',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryPurple,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (_preview!.cached && _preview!.cachedUrl != null) ...[
                    // Cache hit — show the cached URL image
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(
                        _preview!.cachedUrl!,
                        height: 160,
                        width: 160,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          height: 160,
                          width: 160,
                          color: AppColors.surfaceGray,
                          child: const Icon(Icons.broken_image, size: 40),
                        ),
                      ),
                    ),
                  ] else ...[
                    // Normal flow — swipeable base64 previews
                    SizedBox(
                      height: 160,
                      child: PageView.builder(
                        controller: _pageController,
                        itemCount: _preview!.images.length,
                        onPageChanged: (i) => setState(() => _selectedImageIndex = i),
                        itemBuilder: (_, i) => _buildBase64Image(_preview!.images[i]),
                      ),
                    ),
                    if (_preview!.images.length > 1) ...[
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(_preview!.images.length, (i) {
                          final isSelected = i == _selectedImageIndex;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: isSelected ? 20 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: isSelected ? AppColors.primaryPurple : AppColors.border,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          );
                        }),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildImageCard(String label, String url, bool isResult) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isResult ? AppColors.primaryPurple : AppColors.textMuted,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isResult ? AppColors.primaryIndigo : AppColors.border,
              width: isResult ? 2.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isResult ? 0.1 : 0.04),
                blurRadius: isResult ? 10 : 4,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(isResult ? 13 : 16),
            child: Image.network(
              url,
              height: 160,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                height: 160,
                color: AppColors.surfaceGray,
                child: const Icon(Icons.broken_image, size: 32, color: AppColors.textMuted),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBase64Image(String base64Data) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primaryIndigo, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: Image.memory(
          base64Decode(base64Data),
          height: 160,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            height: 160,
            color: AppColors.surfaceGray,
            child: const Icon(Icons.broken_image, size: 32, color: AppColors.textMuted),
          ),
        ),
      ),
    );
  }

  Widget _buildBase64ImageCard(String label, String base64Data) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.primaryPurple,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primaryIndigo, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(13),
            child: Image.memory(
              base64Decode(base64Data),
              height: 160,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                height: 160,
                color: AppColors.surfaceGray,
                child: const Icon(Icons.broken_image, size: 32, color: AppColors.textMuted),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildError() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surfaceRed,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.errorBorder),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, size: 20, color: AppColors.error),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _error!,
                style: const TextStyle(fontSize: 13, color: AppColors.errorDark),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAiDisclaimer() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.info_outline_rounded, size: 14, color: AppColors.textMuted.withValues(alpha: 0.7)),
        const SizedBox(width: 6),
        Text(
          'AI-generated images may not be accurate',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textMuted.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildActions() {
    if (_preview != null) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _preview!.cached
                  ? () => _generate(forceNew: true)
                  : _tryAnother,
              icon: Icon(
                _preview!.cached ? Icons.auto_awesome_rounded : Icons.refresh_rounded,
                size: 18,
              ),
              label: Text(_preview!.cached ? 'Generate New' : 'Try Again'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                side: const BorderSide(color: AppColors.border),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: _accepting ? null : _accept,
              icon: _accepting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check_rounded, size: 20),
              label: Text(_accepting ? 'Saving...' : 'Use This Photo'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 2,
              ),
            ),
          ),
        ],
      );
    }

    final canGenerate = _selectedRoleId != null &&
        _selectedArtStyleId != null &&
        !_generating &&
        !_loadingStyles;

    return AnimatedBuilder(
      animation: _btnScale,
      builder: (context, child) {
        return Transform.scale(
          scale: canGenerate ? _btnScale.value : 1.0,
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: canGenerate ? _generate : null,
              icon: const Icon(Icons.camera_enhance_rounded, size: 20),
              label: const Text('Get My New Look'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryPurple,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.surfaceGray,
                disabledForegroundColor: AppColors.textMuted,
                padding: const EdgeInsets.symmetric(vertical: 18),
                textStyle: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: canGenerate ? 3 : 0,
                shadowColor: AppColors.primaryPurple.withValues(alpha: 0.4),
              ),
            ),
          ),
        );
      },
    );
  }
}
