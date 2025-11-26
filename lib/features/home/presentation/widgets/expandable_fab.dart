import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'package:nexa/shared/presentation/theme/app_colors.dart';

class ExpandableFab extends StatefulWidget {
  const ExpandableFab({super.key});

  @override
  State<ExpandableFab> createState() => _ExpandableFabState();
}

class _ExpandableFabState extends State<ExpandableFab>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _expandAnimation;
  late Animation<double> _rotationAnimation;
  bool _isExpanded = false;

  final List<FabAction> _actions = [
    FabAction(icon: Icons.camera_alt, label: 'Scan', color: AppColors.techBlue),
    FabAction(icon: Icons.chat_bubble, label: 'AI Chat', color: AppColors.yellow),
    FabAction(icon: Icons.calendar_today, label: 'Event', color: AppColors.yellow),
    FabAction(icon: Icons.upload_file, label: 'Upload', color: AppColors.techBlue),
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _expandAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    );
    _rotationAnimation = Tween<double>(
      begin: 0,
      end: math.pi / 4,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    HapticFeedback.lightImpact();
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        // Background overlay when expanded
        if (_isExpanded)
          GestureDetector(
            onTap: _toggleExpanded,
            child: Container(
              color: const Color(0x66000000), // Fixed color when expanded
            ),
          ),

        // Action buttons
        ..._actions.asMap().entries.map((entry) {
          final index = entry.key;
          final action = entry.value;
          return _buildActionButton(action, index);
        }).toList(),

        // Main FAB
        AnimatedBuilder(
          animation: _rotationAnimation,
          builder: (context, child) {
            return Transform.rotate(
              angle: _rotationAnimation.value,
              child: FloatingActionButton(
                onPressed: _toggleExpanded,
                backgroundColor: AppColors.yellow,
                elevation: 8,
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.yellow, AppColors.techBlue],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x4DFFC107), // 30% purple
                        blurRadius: 20,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.add,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildActionButton(FabAction action, int index) {
    final double spacing = 70.0;
    final double delay = index * 0.05;

    return AnimatedBuilder(
      animation: _expandAnimation,
      builder: (context, child) {
        final double offset = (index + 1) * spacing * _expandAnimation.value;
        final double scale = _expandAnimation.value;
        final double opacity = _expandAnimation.value;

        return Positioned(
          bottom: offset,
          right: 0,
          child: Transform.scale(
            scale: scale,
            child: Opacity(
              opacity: opacity,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Label
                  if (_expandAnimation.value > 0.5)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [
                          BoxShadow(
                            color: AppColors.shadowBlack, // 10% black
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Text(
                        action.label,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textDark,
                        ),
                      ),
                    ),
                  // Button
                  FloatingActionButton.small(
                    heroTag: 'fab_action_$index',
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      _toggleExpanded();
                      // Handle action
                    },
                    backgroundColor: action.color,
                    elevation: 4,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            action.color,
                            action.color,
                          ],
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        action.icon,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class FabAction {
  final IconData icon;
  final String label;
  final Color color;

  FabAction({
    required this.icon,
    required this.label,
    required this.color,
  });
}
