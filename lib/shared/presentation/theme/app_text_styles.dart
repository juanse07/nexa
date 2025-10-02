import 'package:flutter/material.dart';
import 'package:nexa/shared/presentation/theme/app_colors.dart';

/// Predefined text styles for the Nexa application.
///
/// This class provides a comprehensive set of text styles organized by
/// hierarchy and purpose, ensuring consistent typography throughout the app.
class AppTextStyles {
  AppTextStyles._();

  // Font Family
  static const String _fontFamily = 'SF Pro Display';

  // Heading Styles
  /// Heading 1 - Extra large heading
  /// Used for main page titles and hero sections
  static const TextStyle h1 = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 32,
    fontWeight: FontWeight.w700,
    height: 1.2,
    letterSpacing: -0.5,
    color: AppColors.textDark,
  );

  /// Heading 2 - Large heading
  /// Used for section titles and important headers
  static const TextStyle h2 = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 28,
    fontWeight: FontWeight.w700,
    height: 1.25,
    letterSpacing: -0.4,
    color: AppColors.textDark,
  );

  /// Heading 3 - Medium heading
  /// Used for card headers and subsection titles
  static const TextStyle h3 = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 24,
    fontWeight: FontWeight.w600,
    height: 1.3,
    letterSpacing: -0.3,
    color: AppColors.textDark,
  );

  /// Heading 4 - Small heading
  /// Used for dialog titles and list group headers
  static const TextStyle h4 = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.35,
    letterSpacing: -0.2,
    color: AppColors.textDark,
  );

  /// Heading 5 - Extra small heading
  /// Used for inline section headers
  static const TextStyle h5 = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 1.4,
    letterSpacing: -0.1,
    color: AppColors.textDark,
  );

  /// Heading 6 - Smallest heading
  /// Used for labels and minor headers
  static const TextStyle h6 = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.45,
    letterSpacing: 0,
    color: AppColors.textDark,
  );

  // Body Styles
  /// Body 1 - Large body text
  /// Used for main content and descriptions
  static const TextStyle body1 = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.5,
    letterSpacing: 0,
    color: AppColors.textDark,
  );

  /// Body 1 Medium - Large body text with medium weight
  static const TextStyle body1Medium = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w500,
    height: 1.5,
    letterSpacing: 0,
    color: AppColors.textDark,
  );

  /// Body 1 Semibold - Large body text with semibold weight
  static const TextStyle body1Semibold = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.5,
    letterSpacing: 0,
    color: AppColors.textDark,
  );

  /// Body 2 - Regular body text
  /// Used for standard content and list items
  static const TextStyle body2 = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.5,
    letterSpacing: 0,
    color: AppColors.textDark,
  );

  /// Body 2 Medium - Regular body text with medium weight
  static const TextStyle body2Medium = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.5,
    letterSpacing: 0,
    color: AppColors.textDark,
  );

  /// Body 2 Semibold - Regular body text with semibold weight
  static const TextStyle body2Semibold = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.5,
    letterSpacing: 0,
    color: AppColors.textDark,
  );

  /// Body Small - Small body text
  /// Used for secondary information and metadata
  static const TextStyle bodySmall = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.5,
    letterSpacing: 0,
    color: AppColors.textTertiary,
  );

  /// Body Small Medium - Small body text with medium weight
  static const TextStyle bodySmallMedium = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.5,
    letterSpacing: 0,
    color: AppColors.textTertiary,
  );

  // Label Styles
  /// Label Large - Large label text
  /// Used for prominent labels and tags
  static const TextStyle labelLarge = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.4,
    letterSpacing: 0.1,
    color: AppColors.textDark,
  );

  /// Label Medium - Regular label text
  /// Used for form labels and buttons
  static const TextStyle labelMedium = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    height: 1.4,
    letterSpacing: 0.1,
    color: AppColors.textDark,
  );

  /// Label Small - Small label text
  /// Used for tiny labels and badges
  static const TextStyle labelSmall = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    height: 1.4,
    letterSpacing: 0.1,
    color: AppColors.textDark,
  );

  // Caption Styles
  /// Caption - Caption text
  /// Used for hints, helper text, and timestamps
  static const TextStyle caption = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.4,
    letterSpacing: 0,
    color: AppColors.textMuted,
  );

  /// Caption Medium - Caption text with medium weight
  static const TextStyle captionMedium = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.4,
    letterSpacing: 0,
    color: AppColors.textMuted,
  );

  /// Overline - Small uppercase text
  /// Used for overline text and category labels
  static const TextStyle overline = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 10,
    fontWeight: FontWeight.w600,
    height: 1.4,
    letterSpacing: 1.0,
    color: AppColors.textMuted,
  );

  // Button Text Styles
  /// Button Large - Large button text
  static const TextStyle buttonLarge = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.2,
    letterSpacing: 0.2,
    color: Colors.white,
  );

  /// Button Medium - Regular button text
  static const TextStyle buttonMedium = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.2,
    letterSpacing: 0.2,
    color: Colors.white,
  );

  /// Button Small - Small button text
  static const TextStyle buttonSmall = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    height: 1.2,
    letterSpacing: 0.2,
    color: Colors.white,
  );

  // Link Styles
  /// Link - Regular link text
  static const TextStyle link = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.5,
    letterSpacing: 0,
    color: AppColors.primaryIndigo,
    decoration: TextDecoration.underline,
  );

  /// Link Small - Small link text
  static const TextStyle linkSmall = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.5,
    letterSpacing: 0,
    color: AppColors.primaryIndigo,
    decoration: TextDecoration.underline,
  );

  // Error Text Style
  /// Error text style
  static const TextStyle error = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.4,
    letterSpacing: 0,
    color: AppColors.error,
  );

  // Helper Methods

  /// Returns a text style with custom color
  static TextStyle withColor(TextStyle style, Color color) {
    return style.copyWith(color: color);
  }

  /// Returns a text style with custom font weight
  static TextStyle withWeight(TextStyle style, FontWeight weight) {
    return style.copyWith(fontWeight: weight);
  }

  /// Returns a text style with custom font size
  static TextStyle withSize(TextStyle style, double size) {
    return style.copyWith(fontSize: size);
  }
}
