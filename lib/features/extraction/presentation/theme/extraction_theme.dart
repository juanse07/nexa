import 'package:flutter/material.dart';

/// Centralized theme constants for the Extraction feature
///
/// This file contains all colors, gradients, text styles, and decorations used across
/// the extraction screens to ensure consistency and easy maintenance.
class ExtractionTheme {
  ExtractionTheme._();

  // ============================================================================
  // COLORS
  // ============================================================================

  // Brand colors
  static const Color yellow = Color(0xFFFFC107);
  static const Color techBlue = Color(0xFF3B82F6);
  static const Color navySpaceCadet = Color(0xFF212C4A);
  static const Color oceanBlue = Color(0xFF1E3A8A);

  // Status colors
  static const Color success = Color(0xFF10B981);
  static const Color successDark = Color(0xFF059669);
  static const Color error = Color(0xFFEF4444);
  static const Color errorDark = Color(0xFFDC2626);
  static const Color info = Color(0xFF00BCD4);
  static const Color warning = Color(0xFFFFC107);

  // Text colors
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF6B7280);

  // Background colors
  static const Color backgroundLight = Color(0xFFF8FAFC);
  static const Color backgroundWhite = Color(0xFFFFFFFF);
  static const Color backgroundGrey = Color(0xFFF8F9FA);

  // Capacity indicators
  static const Color capacityAvailable = Color(0xFF10B981);
  static const Color capacityWarning = Color(0xFFFFC107);
  static const Color capacityMedium = Color(0xFFF59E0B); // Amber/Orange for 50-90%
  static const Color capacityFull = Color(0xFFEF4444);

  // Privacy status colors
  static const Color privacyPublic = Color(0xFF10B981);
  static const Color privacyPrivate = Color(0xFF00BCD4);
  static const Color privacyMixed = Color(0xFF3B82F6);

  // Additional UI colors
  static const Color charcoal = Color(0xFF1F2937);
  static const Color slate = Color(0xFF1E293B);
  static const Color slateGray = Color(0xFF94A3B8); // For past/inactive items
  static const Color borderGrey = Color(0xFFE5E7EB);
  static const Color coralRed = Color(0xFFFF6B6B);
  static const Color coralOrange = Color(0xFFFF8E53);
  static const Color purple = Color(0xFF7A3AFB);
  static const Color purpleDark = Color(0xFF5B27D8);
  static const Color lavender = Color(0xFFA8A8A8); // Warm grey for accents (publish, navigation, dates)
  static const Color shadowBlack = Color(0x1A000000);

  // Form field colors
  static const Color formFillLight = Color(0xFFF9FAFB);
  static const Color formFillGrey = Color(0xFFF3F4F6);
  static const Color formFillSlate = Color(0xFFF1F5F9);
  static const Color formFillCyan = Color(0xFFF0F9FF);
  static const Color greyMedium = Color(0xFF9CA3AF);

  // Accent colors
  static const Color pink = Color(0xFFEC4899);
  static const Color indigoPurple = Color(0xFF4F46E5);
  static const Color skyBlue = Color(0xFF0EA5E9);

  // ============================================================================
  // GRADIENTS
  // ============================================================================

  /// Brand gradient: Yellow to Blue
  static const LinearGradient brand = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFC107), Color(0xFF3B82F6)],
  );

  /// Header gradient: Linear topLeft to bottomRight - Navy/Ocean Blue edges, Teal dominant center
  static const LinearGradient header = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      // Color(0xFF212C4A), // Navy (tiny edge)
      Color(0xFF1E3A8A), // Ocean Blue (small)
      Color(0xFF00838F), // Dark teal
      Color(0xFF00BCD4), // Medium teal (dominant)
      Color(0xFF26C6DA), // Light teal
      // Color(0xFF00BCD4), // Medium teal
      // Color(0xFF00838F), // Dark teal
      // Color(0xFF1E3A8A), // Ocean Blue (small)
      // Color(0xFF212C4A), // Navy (tiny edge)
    ],
    stops: [0.05, 0.35, 0.75, 1, ],
  );
}

/// Shorthand alias for ExtractionTheme
typedef ExColors = ExtractionTheme;
