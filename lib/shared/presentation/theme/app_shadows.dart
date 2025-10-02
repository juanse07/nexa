import 'package:flutter/material.dart';

/// Box shadow presets for the Nexa application.
///
/// This class provides predefined shadow configurations for different
/// elevation levels and use cases, ensuring consistent depth and layering
/// throughout the application.
class AppShadows {
  AppShadows._();

  // Base Shadow Color
  static const Color _shadowColor = Color(0x1A000000);
  static const Color _shadowColorDark = Color(0x33000000);
  static const Color _shadowColorLight = Color(0x0D000000);

  // Elevation Shadows
  /// No shadow (elevation 0)
  static const List<BoxShadow> none = [];

  /// Extra small shadow (elevation 1)
  /// Used for subtle depth on hover states
  static const List<BoxShadow> xs = [
    BoxShadow(
      color: _shadowColorLight,
      offset: Offset(0, 1),
      blurRadius: 2,
      spreadRadius: 0,
    ),
  ];

  /// Small shadow (elevation 2)
  /// Used for buttons, chips, and small cards
  static const List<BoxShadow> sm = [
    BoxShadow(
      color: _shadowColorLight,
      offset: Offset(0, 1),
      blurRadius: 3,
      spreadRadius: 0,
    ),
    BoxShadow(
      color: _shadowColorLight,
      offset: Offset(0, 1),
      blurRadius: 2,
      spreadRadius: 0,
    ),
  ];

  /// Medium shadow (elevation 4)
  /// Used for cards and elevated containers
  static const List<BoxShadow> md = [
    BoxShadow(
      color: _shadowColor,
      offset: Offset(0, 2),
      blurRadius: 4,
      spreadRadius: -1,
    ),
    BoxShadow(
      color: _shadowColorLight,
      offset: Offset(0, 4),
      blurRadius: 6,
      spreadRadius: -1,
    ),
  ];

  /// Large shadow (elevation 8)
  /// Used for floating action buttons and prominent cards
  static const List<BoxShadow> lg = [
    BoxShadow(
      color: _shadowColor,
      offset: Offset(0, 4),
      blurRadius: 6,
      spreadRadius: -1,
    ),
    BoxShadow(
      color: _shadowColorLight,
      offset: Offset(0, 8),
      blurRadius: 16,
      spreadRadius: -4,
    ),
  ];

  /// Extra large shadow (elevation 12)
  /// Used for modals, bottom sheets, and navigation drawers
  static const List<BoxShadow> xl = [
    BoxShadow(
      color: _shadowColor,
      offset: Offset(0, 10),
      blurRadius: 15,
      spreadRadius: -3,
    ),
    BoxShadow(
      color: _shadowColorLight,
      offset: Offset(0, 4),
      blurRadius: 6,
      spreadRadius: -2,
    ),
  ];

  /// Extra extra large shadow (elevation 16)
  /// Used for dialogs and popovers
  static const List<BoxShadow> xxl = [
    BoxShadow(
      color: _shadowColor,
      offset: Offset(0, 20),
      blurRadius: 25,
      spreadRadius: -5,
    ),
    BoxShadow(
      color: _shadowColorLight,
      offset: Offset(0, 10),
      blurRadius: 10,
      spreadRadius: -5,
    ),
  ];

  /// Extra extra extra large shadow (elevation 24)
  /// Used for dropdowns and menus
  static const List<BoxShadow> xxxl = [
    BoxShadow(
      color: _shadowColorDark,
      offset: Offset(0, 25),
      blurRadius: 50,
      spreadRadius: -12,
    ),
  ];

  // Specialized Shadows

  /// Button shadow
  /// Optimized for button elements
  static const List<BoxShadow> button = [
    BoxShadow(
      color: Color(0x1A6366F1),
      offset: Offset(0, 2),
      blurRadius: 4,
      spreadRadius: 0,
    ),
    BoxShadow(
      color: _shadowColorLight,
      offset: Offset(0, 1),
      blurRadius: 2,
      spreadRadius: 0,
    ),
  ];

  /// Button hover shadow
  /// Enhanced shadow for button hover states
  static const List<BoxShadow> buttonHover = [
    BoxShadow(
      color: Color(0x266366F1),
      offset: Offset(0, 4),
      blurRadius: 8,
      spreadRadius: 0,
    ),
    BoxShadow(
      color: _shadowColorLight,
      offset: Offset(0, 2),
      blurRadius: 4,
      spreadRadius: 0,
    ),
  ];

  /// Button pressed shadow
  /// Reduced shadow for button pressed states
  static const List<BoxShadow> buttonPressed = [
    BoxShadow(
      color: Color(0x0D6366F1),
      offset: Offset(0, 1),
      blurRadius: 2,
      spreadRadius: 0,
    ),
  ];

  /// Card shadow
  /// Optimized for card components
  static const List<BoxShadow> card = [
    BoxShadow(
      color: _shadowColor,
      offset: Offset(0, 2),
      blurRadius: 8,
      spreadRadius: -2,
    ),
    BoxShadow(
      color: _shadowColorLight,
      offset: Offset(0, 4),
      blurRadius: 4,
      spreadRadius: -2,
    ),
  ];

  /// Card hover shadow
  /// Enhanced shadow for card hover states
  static const List<BoxShadow> cardHover = [
    BoxShadow(
      color: _shadowColor,
      offset: Offset(0, 4),
      blurRadius: 12,
      spreadRadius: -2,
    ),
    BoxShadow(
      color: _shadowColorLight,
      offset: Offset(0, 8),
      blurRadius: 8,
      spreadRadius: -4,
    ),
  ];

  /// Bottom sheet shadow
  /// Optimized for bottom sheets
  static const List<BoxShadow> bottomSheet = [
    BoxShadow(
      color: _shadowColorDark,
      offset: Offset(0, -4),
      blurRadius: 16,
      spreadRadius: 0,
    ),
  ];

  /// App bar shadow
  /// Subtle shadow for app bars
  static const List<BoxShadow> appBar = [
    BoxShadow(
      color: _shadowColorLight,
      offset: Offset(0, 2),
      blurRadius: 4,
      spreadRadius: 0,
    ),
  ];

  /// Modal shadow
  /// Deep shadow for modal overlays
  static const List<BoxShadow> modal = [
    BoxShadow(
      color: _shadowColorDark,
      offset: Offset(0, 12),
      blurRadius: 24,
      spreadRadius: -8,
    ),
    BoxShadow(
      color: _shadowColor,
      offset: Offset(0, 8),
      blurRadius: 16,
      spreadRadius: -4,
    ),
  ];

  /// Dropdown shadow
  /// Shadow for dropdown menus
  static const List<BoxShadow> dropdown = [
    BoxShadow(
      color: _shadowColor,
      offset: Offset(0, 4),
      blurRadius: 12,
      spreadRadius: -2,
    ),
    BoxShadow(
      color: _shadowColorLight,
      offset: Offset(0, 2),
      blurRadius: 4,
      spreadRadius: 0,
    ),
  ];

  /// Floating action button shadow
  /// Shadow for FAB
  static const List<BoxShadow> fab = [
    BoxShadow(
      color: Color(0x266366F1),
      offset: Offset(0, 4),
      blurRadius: 12,
      spreadRadius: 0,
    ),
    BoxShadow(
      color: _shadowColor,
      offset: Offset(0, 2),
      blurRadius: 4,
      spreadRadius: 0,
    ),
  ];

  /// Floating action button hover shadow
  /// Enhanced shadow for FAB hover states
  static const List<BoxShadow> fabHover = [
    BoxShadow(
      color: Color(0x336366F1),
      offset: Offset(0, 6),
      blurRadius: 16,
      spreadRadius: 0,
    ),
    BoxShadow(
      color: _shadowColor,
      offset: Offset(0, 4),
      blurRadius: 8,
      spreadRadius: 0,
    ),
  ];

  /// Inner shadow effect
  /// Creates an inset shadow appearance (use with caution)
  static const List<BoxShadow> inner = [
    BoxShadow(
      color: _shadowColorLight,
      offset: Offset(0, 2),
      blurRadius: 4,
      spreadRadius: -2,
    ),
  ];

  // Colored Shadows

  /// Primary colored shadow
  static const List<BoxShadow> primary = [
    BoxShadow(
      color: Color(0x1A6366F1),
      offset: Offset(0, 4),
      blurRadius: 12,
      spreadRadius: 0,
    ),
  ];

  /// Success colored shadow
  static const List<BoxShadow> success = [
    BoxShadow(
      color: Color(0x1A059669),
      offset: Offset(0, 4),
      blurRadius: 12,
      spreadRadius: 0,
    ),
  ];

  /// Error colored shadow
  static const List<BoxShadow> error = [
    BoxShadow(
      color: Color(0x1AEF4444),
      offset: Offset(0, 4),
      blurRadius: 12,
      spreadRadius: 0,
    ),
  ];

  /// Info colored shadow
  static const List<BoxShadow> info = [
    BoxShadow(
      color: Color(0x1A0EA5E9),
      offset: Offset(0, 4),
      blurRadius: 12,
      spreadRadius: 0,
    ),
  ];

  // Helper Methods

  /// Creates a custom shadow with specified parameters
  static List<BoxShadow> custom({
    required Color color,
    required Offset offset,
    required double blurRadius,
    double spreadRadius = 0,
  }) {
    return [
      BoxShadow(
        color: color,
        offset: offset,
        blurRadius: blurRadius,
        spreadRadius: spreadRadius,
      ),
    ];
  }

  /// Creates a layered shadow with two levels
  static List<BoxShadow> layered({
    required Color primaryColor,
    required Offset primaryOffset,
    required double primaryBlur,
    required Color secondaryColor,
    required Offset secondaryOffset,
    required double secondaryBlur,
  }) {
    return [
      BoxShadow(
        color: primaryColor,
        offset: primaryOffset,
        blurRadius: primaryBlur,
      ),
      BoxShadow(
        color: secondaryColor,
        offset: secondaryOffset,
        blurRadius: secondaryBlur,
      ),
    ];
  }
}
