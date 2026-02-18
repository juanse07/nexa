import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:nexa/shared/presentation/theme/app_colors.dart';

/// Animated gradient background with floating translucent orbs.
///
/// Matches the login page's navy gradient (`#2C3E50 → #1A252F`) and adds
/// slowly drifting gold/blue circles for visual depth. Uses a single
/// [AnimationController] driving a [CustomPainter] — no extra packages.
class OnboardingBackground extends StatefulWidget {
  final Widget child;

  const OnboardingBackground({super.key, required this.child});

  @override
  State<OnboardingBackground> createState() => _OnboardingBackgroundState();
}

class _OnboardingBackgroundState extends State<OnboardingBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.primaryPurple, // #2C3E50 navy
            Color(0xFF1A252F),       // darker navy
          ],
        ),
      ),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            painter: _OrbPainter(progress: _controller.value),
            child: child,
          );
        },
        child: widget.child,
      ),
    );
  }
}

/// Paints 6 translucent floating orbs that drift using sine functions.
///
/// Each orb has a unique phase, speed multiplier, base position, radius,
/// and color so the composition feels organic rather than mechanical.
class _OrbPainter extends CustomPainter {
  final double progress;

  _OrbPainter({required this.progress});

  static const _orbs = <_OrbConfig>[
    _OrbConfig(
      baseX: 0.15, baseY: 0.20,
      radius: 80, driftX: 30, driftY: 20,
      phase: 0.0, speed: 1.0,
      color: AppColors.primaryIndigo, // gold
      opacity: 0.08,
    ),
    _OrbConfig(
      baseX: 0.80, baseY: 0.15,
      radius: 60, driftX: 20, driftY: 25,
      phase: 0.3, speed: 1.3,
      color: AppColors.secondaryPurple, // blue
      opacity: 0.06,
    ),
    _OrbConfig(
      baseX: 0.50, baseY: 0.55,
      radius: 100, driftX: 35, driftY: 15,
      phase: 0.6, speed: 0.8,
      color: AppColors.primaryIndigo, // gold
      opacity: 0.05,
    ),
    _OrbConfig(
      baseX: 0.25, baseY: 0.75,
      radius: 50, driftX: 25, driftY: 30,
      phase: 0.9, speed: 1.1,
      color: AppColors.secondaryPurple, // blue
      opacity: 0.07,
    ),
    _OrbConfig(
      baseX: 0.70, baseY: 0.65,
      radius: 70, driftX: 20, driftY: 20,
      phase: 1.5, speed: 0.9,
      color: AppColors.primaryIndigo, // gold
      opacity: 0.06,
    ),
    _OrbConfig(
      baseX: 0.90, baseY: 0.85,
      radius: 55, driftX: 15, driftY: 25,
      phase: 2.0, speed: 1.2,
      color: AppColors.secondaryPurple, // blue
      opacity: 0.05,
    ),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    for (final orb in _orbs) {
      final t = progress * 2 * math.pi * orb.speed + orb.phase;
      final dx = orb.baseX * size.width + math.sin(t) * orb.driftX;
      final dy = orb.baseY * size.height + math.cos(t * 0.7) * orb.driftY;

      final paint = Paint()
        ..color = orb.color.withValues(alpha: orb.opacity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 40);

      canvas.drawCircle(Offset(dx, dy), orb.radius, paint);
    }
  }

  @override
  bool shouldRepaint(_OrbPainter oldDelegate) => oldDelegate.progress != progress;
}

class _OrbConfig {
  final double baseX, baseY;
  final double radius;
  final double driftX, driftY;
  final double phase, speed;
  final Color color;
  final double opacity;

  const _OrbConfig({
    required this.baseX,
    required this.baseY,
    required this.radius,
    required this.driftX,
    required this.driftY,
    required this.phase,
    required this.speed,
    required this.color,
    required this.opacity,
  });
}
