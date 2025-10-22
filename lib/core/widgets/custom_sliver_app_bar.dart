import 'package:flutter/material.dart';

/// Custom clipper for beautiful curved appbar shape with smooth elliptical bottom-right corner
class AppBarClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    final width = size.width;
    final height = size.height;

    // Start from top-left corner
    path.moveTo(0, 0);

    // Top edge - straight across
    path.lineTo(width, 0);

    // Right edge - go down but stop before the corner for the curve
    path.lineTo(width, height - 30);

    // Beautiful elliptical rounded bottom-right corner
    // Using cubicTo for ultra-smooth curve with minimal curve
    path.cubicTo(
      width, height - 15, // First control point - ease out from vertical
      width - 15, height, // Second control point - ease into horizontal
      width - 30, height, // End point - curved inward (minimal curve)
    );

    // Bottom edge - straight across to left
    path.lineTo(0, height);

    // Close the path back to top-left
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

/// Reusable collapsible SliverAppBar with custom clip shape
class CustomSliverAppBar extends StatelessWidget {
  final String title;
  final String? subtitle;
  final double expandedHeight;
  final bool floating;
  final bool pinned;
  final bool snap;
  final Color? backgroundColor;
  final List<Color>? gradientColors;
  final VoidCallback? onBackPressed;
  final List<Widget>? actions;
  final double? titleFontSize;
  final double? subtitleFontSize;

  const CustomSliverAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.expandedHeight = 120.0,
    this.floating = true,
    this.pinned = false,
    this.snap = true,
    this.backgroundColor,
    this.gradientColors,
    this.onBackPressed,
    this.actions,
    this.titleFontSize,
    this.subtitleFontSize,
  });

  @override
  Widget build(BuildContext context) {
    final defaultGradientColors = gradientColors ?? [
      const Color(0xFF7A3AFB),
      const Color(0xFF5B27D8),
    ];

    return SliverAppBar(
      pinned: pinned,
      floating: floating,
      snap: snap,
      expandedHeight: expandedHeight,
      backgroundColor: backgroundColor ?? Colors.transparent,
      elevation: 0,
      leading: onBackPressed != null
          ? IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
              onPressed: onBackPressed,
            )
          : null,
      actions: actions,
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Purple gradient background with custom clip
            ClipPath(
              clipper: AppBarClipper(),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: defaultGradientColors,
                  ),
                ),
              ),
            ),
            // Decorative purple shapes layer
            ClipPath(
              clipper: AppBarClipper(),
              child: Stack(
                children: [
                  Positioned(
                    top: -40,
                    right: -20,
                    child: Container(
                      width: 180,
                      height: 180,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF9D7EF0).withOpacity(0.15),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 20,
                    left: -30,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF8B5CF6).withOpacity(0.12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Title and stats
            Positioned(
              left: 20,
              right: 20,
              bottom: 8,
              child: SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: titleFontSize ?? 18,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.3,
                        height: 1.2,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.85),
                          fontSize: subtitleFontSize ?? 11,
                          fontWeight: FontWeight.w400,
                          letterSpacing: 0.1,
                          height: 1.3,
                        ),
                      ),
                    ],
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
