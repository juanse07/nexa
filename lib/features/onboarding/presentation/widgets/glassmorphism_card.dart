import 'dart:ui';
import 'package:flutter/material.dart';

/// Reusable frosted-glass card matching the pattern in
/// `attendance_hero_header.dart` — [ClipRRect] + [BackdropFilter] blur +
/// translucent white background + subtle white border.
///
/// Optional [accentColor] draws a 3px left border for step-state indication
/// (gold = active, green = complete, grey = locked).
class GlassmorphismCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final Color? accentColor;

  const GlassmorphismCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.borderRadius = 16,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border(
              left: accentColor != null
                  ? BorderSide(color: accentColor!, width: 3)
                  : BorderSide(color: Colors.white.withValues(alpha: 0.2)),
              top: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
              right: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
              bottom: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
