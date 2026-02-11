import 'dart:async';

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

/// Bottom sheet for generating fun profile pictures.
class CaricatureGeneratorSheet extends StatefulWidget {
  const CaricatureGeneratorSheet({
    super.key,
    required this.currentPictureUrl,
    required this.onAccepted,
  });

  final String currentPictureUrl;
  final ValueChanged<String> onAccepted;

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
  String? _generatedUrl;
  bool _generating = false;
  String? _error;
  bool _showAllRoles = false;

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
  void dispose() {
    _loadingMessageTimer?.cancel();
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

  Future<void> _generate() async {
    if (_selectedRoleId == null || _selectedArtStyleId == null) return;

    setState(() {
      _generating = true;
      _error = null;
      _generatedUrl = null;
    });

    _startLoadingMessages();
    unawaited(HapticFeedback.mediumImpact());

    try {
      final result = await _service.generate(_selectedRoleId!, _selectedArtStyleId!);
      if (!mounted) return;
      unawaited(HapticFeedback.heavyImpact());
      setState(() {
        _generatedUrl = result.url;
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

  void _accept() {
    if (_generatedUrl == null) return;
    HapticFeedback.mediumImpact();
    widget.onAccepted(_generatedUrl!);
    Navigator.of(context).pop();
  }

  void _tryAnother() {
    setState(() {
      _generatedUrl = null;
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
                    const SizedBox(height: 24),
                    _buildPreview(),
                    const SizedBox(height: 20),
                    if (_error != null) _buildError(),
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
                _generatedUrl = null;
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
                          _generatedUrl = null;
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

  Widget _buildPreview() {
    if (_generating) {
      return _buildGeneratingState();
    }

    if (_generatedUrl != null) {
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
            Expanded(child: _buildImageCard('After', _generatedUrl!, true)),
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

  Widget _buildActions() {
    if (_generatedUrl != null) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _tryAnother,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Try Again'),
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
              onPressed: _accept,
              icon: const Icon(Icons.check_rounded, size: 20),
              label: const Text('Use This Photo'),
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
