import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

/// Responsive layout helper class for adaptive UI across different screen sizes
class ResponsiveLayout {
  /// Breakpoints for different device sizes
  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 900;
  static const double desktopBreakpoint = 1200;

  /// Check if the current device is mobile
  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < mobileBreakpoint;
  }

  /// Check if the current device is tablet
  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= mobileBreakpoint && width < desktopBreakpoint;
  }

  /// Check if the current device is desktop
  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= desktopBreakpoint;
  }

  /// Check if we should use desktop layout (web or large screens)
  static bool shouldUseDesktopLayout(BuildContext context) {
    return kIsWeb || MediaQuery.of(context).size.width >= tabletBreakpoint;
  }

  /// Get responsive value based on screen size
  static T responsive<T>({
    required BuildContext context,
    required T mobile,
    T? tablet,
    T? desktop,
  }) {
    if (isDesktop(context) && desktop != null) {
      return desktop;
    }
    if (isTablet(context) && tablet != null) {
      return tablet;
    }
    return mobile;
  }

  /// Get content max width for centered layouts
  static double getContentMaxWidth(BuildContext context) {
    if (isDesktop(context)) {
      return 1400; // Desktop max width
    }
    if (isTablet(context)) {
      return 900; // Tablet max width
    }
    return double.infinity; // Mobile full width
  }

  /// Get horizontal padding based on screen size
  static double getHorizontalPadding(BuildContext context) {
    if (isDesktop(context)) {
      return 32.0;
    }
    if (isTablet(context)) {
      return 24.0;
    }
    return 16.0;
  }

  /// Get number of columns for grid layouts
  static int getGridColumns(BuildContext context) {
    if (isDesktop(context)) {
      return 3;
    }
    if (isTablet(context)) {
      return 2;
    }
    return 1;
  }
}

/// Responsive builder widget for adaptive layouts
class ResponsiveBuilder extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget? desktop;

  const ResponsiveBuilder({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= ResponsiveLayout.desktopBreakpoint && desktop != null) {
          return desktop!;
        }
        if (constraints.maxWidth >= ResponsiveLayout.mobileBreakpoint && tablet != null) {
          return tablet!;
        }
        return mobile;
      },
    );
  }
}

/// Centered content container with max width for desktop
class ResponsiveContainer extends StatelessWidget {
  final Widget child;
  final double? maxWidth;
  final EdgeInsetsGeometry? padding;

  const ResponsiveContainer({
    super.key,
    required this.child,
    this.maxWidth,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: BoxConstraints(
          maxWidth: maxWidth ?? ResponsiveLayout.getContentMaxWidth(context),
        ),
        padding: padding ?? EdgeInsets.symmetric(
          horizontal: ResponsiveLayout.getHorizontalPadding(context),
        ),
        child: child,
      ),
    );
  }
}
