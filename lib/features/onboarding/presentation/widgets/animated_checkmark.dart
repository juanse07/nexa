import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:nexa/shared/presentation/theme/app_colors.dart';

/// Animated checkmark that draws a circle first, then a checkmark stroke,
/// followed by optional burst particles radiating outward.
///
/// Uses two [AnimationController]s chained — circle+check draws over 0.8s,
/// then particles burst and fade over 0.6s.
class AnimatedCheckmark extends StatefulWidget {
  final double size;
  final Color color;
  final Color? particleColor;
  final bool showParticles;
  final VoidCallback? onComplete;

  const AnimatedCheckmark({
    super.key,
    this.size = 100,
    this.color = AppColors.primaryIndigo,
    this.particleColor,
    this.showParticles = true,
    this.onComplete,
  });

  @override
  State<AnimatedCheckmark> createState() => _AnimatedCheckmarkState();
}

class _AnimatedCheckmarkState extends State<AnimatedCheckmark>
    with TickerProviderStateMixin {
  late final AnimationController _drawController;
  late final AnimationController _particleController;

  @override
  void initState() {
    super.initState();

    _drawController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _drawController.addStatusListener((status) {
      if (status == AnimationStatus.completed && widget.showParticles) {
        _particleController.forward();
      }
    });

    _particleController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onComplete?.call();
      }
    });

    // Also handle no-particles case
    if (!widget.showParticles) {
      _drawController.addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          widget.onComplete?.call();
        }
      });
    }

    _drawController.forward();
  }

  @override
  void dispose() {
    _drawController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: Listenable.merge([_drawController, _particleController]),
        builder: (context, _) {
          return CustomPaint(
            painter: _CheckmarkPainter(
              drawProgress: _drawController.value,
              particleProgress: _particleController.value,
              color: widget.color,
              particleColor: widget.particleColor ?? widget.color,
              showParticles: widget.showParticles,
            ),
          );
        },
      ),
    );
  }
}

class _CheckmarkPainter extends CustomPainter {
  final double drawProgress;
  final double particleProgress;
  final Color color;
  final Color particleColor;
  final bool showParticles;

  _CheckmarkPainter({
    required this.drawProgress,
    required this.particleProgress,
    required this.color,
    required this.particleColor,
    required this.showParticles,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.42;

    // Phase 1: Circle draw (0.0 → 0.5 of drawProgress)
    final circleProgress = (drawProgress * 2).clamp(0.0, 1.0);
    if (circleProgress > 0) {
      final circlePaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0
        ..strokeCap = StrokeCap.round;

      final sweepAngle = circleProgress * 2 * math.pi;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2, // start from top
        sweepAngle,
        false,
        circlePaint,
      );
    }

    // Fill circle bg with subtle color once complete
    if (circleProgress >= 1.0) {
      final fillPaint = Paint()
        ..color = color.withValues(alpha: 0.1)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, radius, fillPaint);
    }

    // Phase 2: Checkmark stroke (0.5 → 1.0 of drawProgress)
    final checkProgress = ((drawProgress - 0.5) * 2).clamp(0.0, 1.0);
    if (checkProgress > 0) {
      final checkPaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      // Checkmark points relative to center
      final p1 = Offset(center.dx - radius * 0.35, center.dy + radius * 0.05);
      final p2 = Offset(center.dx - radius * 0.05, center.dy + radius * 0.35);
      final p3 = Offset(center.dx + radius * 0.40, center.dy - radius * 0.25);

      final path = Path();

      // First leg: p1 → p2 (0.0 → 0.4 of checkProgress)
      final leg1 = (checkProgress / 0.4).clamp(0.0, 1.0);
      path.moveTo(p1.dx, p1.dy);
      path.lineTo(
        p1.dx + (p2.dx - p1.dx) * leg1,
        p1.dy + (p2.dy - p1.dy) * leg1,
      );

      // Second leg: p2 → p3 (0.4 → 1.0 of checkProgress)
      if (checkProgress > 0.4) {
        final leg2 = ((checkProgress - 0.4) / 0.6).clamp(0.0, 1.0);
        path.lineTo(
          p2.dx + (p3.dx - p2.dx) * leg2,
          p2.dy + (p3.dy - p2.dy) * leg2,
        );
      }

      canvas.drawPath(path, checkPaint);
    }

    // Phase 3: Burst particles (after draw completes)
    if (showParticles && particleProgress > 0) {
      _drawParticles(canvas, center, radius, particleProgress);
    }
  }

  void _drawParticles(
    Canvas canvas, Offset center, double radius, double progress,
  ) {
    const particleCount = 8;
    final maxDist = radius * 1.6;
    final opacity = (1.0 - progress).clamp(0.0, 1.0);

    for (int i = 0; i < particleCount; i++) {
      final angle = (i / particleCount) * 2 * math.pi;
      final dist = radius * 0.6 + maxDist * progress;
      final dx = center.dx + math.cos(angle) * dist;
      final dy = center.dy + math.sin(angle) * dist;
      final r = 3.0 * (1.0 - progress * 0.5);

      final paint = Paint()
        ..color = particleColor.withValues(alpha: opacity * 0.6);

      canvas.drawCircle(Offset(dx, dy), r, paint);
    }
  }

  @override
  bool shouldRepaint(_CheckmarkPainter old) =>
      old.drawProgress != drawProgress ||
      old.particleProgress != particleProgress;
}
