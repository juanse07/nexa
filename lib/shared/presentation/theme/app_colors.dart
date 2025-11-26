import 'package:flutter/material.dart';

/// Centralized color constants for the Nexa application.
///
/// This class provides a comprehensive color system organized by category,
/// including both light and dark mode variants for consistent theming
/// throughout the application.
class AppColors {
  AppColors._();

  // Primary Colors
  /// Primary brand color - Yellow/Gold
  static const Color primaryIndigo = Color(0xFFFFC107);

  /// Primary brand color - Navy Blue (alternate)
  static const Color primaryPurple = Color(0xFF2C3E50);

  /// Secondary blue for accents
  static const Color secondaryPurple = Color(0xFF3B82F6);

  /// Teal/Cyan for info, status, and secondary elements
  static const Color tealInfo = Color(0xFF00BCD4);

  /// Teal light variant for backgrounds
  static const Color tealLight = Color(0xFF26C6DA);

  // Surface Colors
  /// Light surface background
  static const Color surfaceLight = Color(0xFFF8FAFC);

  /// Very light surface for cards
  static const Color surfaceWhite = Color(0xFFFAFAFA);

  /// Light gray surface
  static const Color surfaceGray = Color(0xFFF1F5F9);

  /// Light blue surface
  static const Color surfaceBlue = Color(0xFFF0F9FF);

  /// Light red surface for errors
  static const Color surfaceRed = Color(0xFFFEF2F2);

  // Status Colors
  /// Success color - Green
  static const Color success = Color(0xFF059669);

  /// Success light variant
  static const Color successLight = Color(0xFF10B981);

  /// Error color - Red
  static const Color error = Color(0xFFEF4444);

  /// Error dark variant
  static const Color errorDark = Color(0xFFDC2626);

  /// Error border color
  static const Color errorBorder = Color(0xFFFECACA);

  /// Warning color - Amber
  static const Color warning = Color(0xFFF59E0B);

  /// Info color - Sky Blue
  static const Color info = Color(0xFF0EA5E9);

  /// Info dark variant
  static const Color infoDark = Color(0xFF0369A1);

  // Text Colors - Light Theme
  /// Primary text color for light theme
  static const Color textDark = Color(0xFF0F172A);

  /// Secondary text color for light theme
  static const Color textSecondary = Color(0xFF1E293B);

  /// Tertiary text color for light theme
  static const Color textTertiary = Color(0xFF475569);

  /// Muted text color
  static const Color textMuted = Color(0xFF6B7280);

  // Text Colors - Dark Theme
  /// Primary text color for dark theme
  static const Color textLight = Color(0xFFF8FAFC);

  /// Secondary text color for dark theme
  static const Color textLightSecondary = Color(0xFFE2E8F0);

  /// Tertiary text color for dark theme
  static const Color textLightTertiary = Color(0xFFCBD5E1);

  // Border Colors
  /// Default border color
  static const Color border = Color(0xFFE2E8F0);

  /// Light border color
  static const Color borderLight = Color(0xFFF1F5F9);

  /// Medium border color
  static const Color borderMedium = Color(0xFFCBD5E1);

  /// Dark border color
  static const Color borderDark = Color(0xFF94A3B8);

  /// Border grey (slightly different shade)
  static const Color borderGrey = Color(0xFFE5E7EB);

  // Background Colors
  /// White background
  static const Color backgroundWhite = Color(0xFFFFFFFF);

  /// Light background
  static const Color backgroundLight = Color(0xFFF8FAFC);

  /// Gray background
  static const Color backgroundGray = Color(0xFFF1F5F9);

  /// Dark background
  static const Color backgroundDark = Color(0xFF0F172A);

  /// Dark secondary background
  static const Color backgroundDarkSecondary = Color(0xFF1E293B);

  // Overlay Colors
  /// Black overlay with 50% opacity
  static const Color overlayBlack = Color(0x80000000);

  /// White overlay with 50% opacity
  static const Color overlayWhite = Color(0x80FFFFFF);

  // Extended Colors (from features)
  /// Purple accent color
  static const Color purple = Color(0xFF7A3AFB);

  /// Dark purple variant
  static const Color purpleDark = Color(0xFF5B27D8);

  /// Indigo purple
  static const Color indigoPurple = Color(0xFF4F46E5);

  /// Pink accent
  static const Color pink = Color(0xFFEC4899);

  /// Coral red
  static const Color coralRed = Color(0xFFFF6B6B);

  /// Coral orange
  static const Color coralOrange = Color(0xFFFF8E53);

  /// Navy space cadet
  static const Color navySpaceCadet = Color(0xFF212C4A);

  /// Ocean blue
  static const Color oceanBlue = Color(0xFF1E3A8A);

  /// Tech blue (alias for secondaryPurple)
  static const Color techBlue = secondaryPurple;

  /// Charcoal gray
  static const Color charcoal = Color(0xFF1F2937);

  /// Slate
  static const Color slate = Color(0xFF1E293B);

  /// Slate gray
  static const Color slateGray = Color(0xFF94A3B8);

  /// Medium gray
  static const Color greyMedium = Color(0xFF9CA3AF);

  /// Yellow (alias for primaryIndigo)
  static const Color yellow = primaryIndigo;

  // Form Colors
  /// Form fill light
  static const Color formFillLight = Color(0xFFF9FAFB);

  /// Form fill grey
  static const Color formFillGrey = Color(0xFFF3F4F6);

  /// Form fill slate
  static const Color formFillSlate = Color(0xFFF1F5F9);

  /// Form fill cyan
  static const Color formFillCyan = Color(0xFFF0F9FF);

  // Shadow & Overlay
  /// Shadow black
  static const Color shadowBlack = Color(0x1A000000);

  // Icon Colors
  /// Primary icon color
  static const Color iconPrimary = Color(0xFFFFC107);

  /// Success icon color
  static const Color iconSuccess = Color(0xFF059669);

  /// Error icon color
  static const Color iconError = Color(0xFFEF4444);

  /// Info icon color
  static const Color iconInfo = Color(0xFF0EA5E9);

  /// Muted icon color
  static const Color iconMuted = Color(0xFF94A3B8);

  // Gradient Colors
  /// Primary gradient start
  static const Color gradientPrimaryStart = Color(0xFFFFC107);

  /// Primary gradient end
  static const Color gradientPrimaryEnd = Color(0xFF3B82F6);

  /// Success gradient start
  static const Color gradientSuccessStart = Color(0xFF059669);

  /// Success gradient end
  static const Color gradientSuccessEnd = Color(0xFF10B981);

  // Divider Colors
  /// Light divider
  static const Color dividerLight = Color(0xFFF1F5F9);

  /// Medium divider
  static const Color divider = Color(0xFFE2E8F0);

  /// Dark divider
  static const Color dividerDark = Color(0xFFCBD5E1);

  // Opacity Helpers
  /// Returns a color with specified opacity (0.0 to 1.0)
  static Color withOpacity(Color color, double opacity) {
    return color.withValues(alpha: opacity);
  }

  /// Returns primary color with 10% opacity
  static Color get primaryLight10 => primaryIndigo.withValues(alpha: 0.1);

  /// Returns primary color with 20% opacity
  static Color get primaryLight20 => primaryIndigo.withValues(alpha: 0.2);

  /// Returns primary color with 30% opacity
  static Color get primaryLight30 => primaryIndigo.withValues(alpha: 0.3);

  /// Returns primary color with 50% opacity
  static Color get primaryLight50 => primaryIndigo.withValues(alpha: 0.5);
}
