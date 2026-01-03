import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

/// A responsive wrapper that constrains content width on web for better UX.
///
/// On web with wide screens, content is centered with a max width to prevent
/// overly stretched buttons, text fields, and other UI elements.
/// On mobile, content is displayed at full width.
///
/// Usage:
/// ```dart
/// WebContentWrapper(
///   maxWidth: 600, // For chat screens
///   child: YourContent(),
/// )
/// ```
class WebContentWrapper extends StatelessWidget {
  /// The child widget to wrap
  final Widget child;

  /// Maximum width for content on web (default: 800px)
  final double maxWidth;

  /// Horizontal padding on sides when constrained (default: 24px)
  final double horizontalPadding;

  /// Background color for the outer area (default: transparent)
  final Color? backgroundColor;

  const WebContentWrapper({
    super.key,
    required this.child,
    this.maxWidth = 800,
    this.horizontalPadding = 24,
    this.backgroundColor,
  });

  /// Preset for chat screens (narrower, more intimate)
  const WebContentWrapper.chat({
    super.key,
    required this.child,
    this.backgroundColor,
  })  : maxWidth = 700,
        horizontalPadding = 16;

  /// Preset for list screens (conversations, events list)
  const WebContentWrapper.list({
    super.key,
    required this.child,
    this.backgroundColor,
  })  : maxWidth = 800,
        horizontalPadding = 24;

  /// Preset for form screens (wider for forms with labels)
  const WebContentWrapper.form({
    super.key,
    required this.child,
    this.backgroundColor,
  })  : maxWidth = 600,
        horizontalPadding = 32;

  /// Preset for dashboard screens (wider for data-heavy content)
  const WebContentWrapper.dashboard({
    super.key,
    required this.child,
    this.backgroundColor,
  })  : maxWidth = 1200,
        horizontalPadding = 32;

  @override
  Widget build(BuildContext context) {
    // On mobile, return child directly without constraints
    if (!kIsWeb) {
      return child;
    }

    final screenWidth = MediaQuery.of(context).size.width;

    // On narrow web screens, also return child directly
    if (screenWidth <= maxWidth + (horizontalPadding * 2)) {
      return child;
    }

    // On wide web screens, center content with max width
    return Container(
      color: backgroundColor,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// A sliver version for use in CustomScrollView
class SliverWebContentWrapper extends StatelessWidget {
  final Widget sliver;
  final double maxWidth;
  final double horizontalPadding;

  const SliverWebContentWrapper({
    super.key,
    required this.sliver,
    this.maxWidth = 800,
    this.horizontalPadding = 24,
  });

  const SliverWebContentWrapper.chat({
    super.key,
    required this.sliver,
  })  : maxWidth = 700,
        horizontalPadding = 16;

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) {
      return sliver;
    }

    final screenWidth = MediaQuery.of(context).size.width;

    if (screenWidth <= maxWidth + (horizontalPadding * 2)) {
      return sliver;
    }

    // Calculate side padding to center content
    final sidePadding = (screenWidth - maxWidth) / 2;

    return SliverPadding(
      padding: EdgeInsets.symmetric(horizontal: sidePadding),
      sliver: sliver,
    );
  }
}
