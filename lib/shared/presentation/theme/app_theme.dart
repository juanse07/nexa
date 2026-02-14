import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nexa/shared/presentation/theme/app_colors.dart';
import 'package:nexa/shared/presentation/theme/app_dimensions.dart';
import 'package:nexa/shared/presentation/theme/app_text_styles.dart';

/// Central theme configuration for the Nexa application.
///
/// This class provides static methods to generate complete [ThemeData]
/// for both light and dark modes, ensuring consistent styling across
/// the entire application.
class AppTheme {
  AppTheme._();

  /// Returns the light theme configuration
  static ThemeData lightTheme() {
    return ThemeData(
      // Brightness
      brightness: Brightness.light,
      useMaterial3: true,

      // Color Scheme
      colorScheme: _lightColorScheme(),

      // Scaffold
      scaffoldBackgroundColor: AppColors.backgroundWhite,

      // App Bar Theme
      appBarTheme: _lightAppBarTheme(),

      // Text Theme
      textTheme: _textTheme(),

      // Primary Text Theme
      primaryTextTheme: _textTheme(),

      // Button Themes
      elevatedButtonTheme: _elevatedButtonTheme(),
      textButtonTheme: _textButtonTheme(),
      outlinedButtonTheme: _outlinedButtonTheme(),
      filledButtonTheme: _filledButtonTheme(),

      // Floating Action Button Theme
      floatingActionButtonTheme: _fabTheme(),

      // Input Decoration Theme
      inputDecorationTheme: _inputDecorationTheme(),

      // Card Theme
      cardTheme: _cardTheme(),

      // Chip Theme
      chipTheme: _chipTheme(),

      // Dialog Theme
      dialogTheme: _dialogTheme(),

      // Bottom Sheet Theme
      bottomSheetTheme: _bottomSheetTheme(),

      // Bottom Navigation Bar Theme
      bottomNavigationBarTheme: _bottomNavigationBarTheme(),

      // Navigation Bar Theme
      navigationBarTheme: _navigationBarTheme(),

      // Tab Bar Theme
      tabBarTheme: _tabBarTheme(),

      // Drawer Theme
      drawerTheme: _drawerTheme(),

      // List Tile Theme
      listTileTheme: _listTileTheme(),

      // Icon Theme
      iconTheme: _iconTheme(),
      primaryIconTheme: _primaryIconTheme(),

      // Divider Theme
      dividerTheme: _dividerTheme(),

      // Snackbar Theme
      snackBarTheme: _snackBarTheme(),

      // Progress Indicator Theme
      progressIndicatorTheme: _progressIndicatorTheme(),

      // Switch Theme
      switchTheme: _switchTheme(),

      // Checkbox Theme
      checkboxTheme: _checkboxTheme(),

      // Radio Theme
      radioTheme: _radioTheme(),

      // Slider Theme
      sliderTheme: _sliderTheme(),

      // Tooltip Theme
      tooltipTheme: _tooltipTheme(),

      // Badge Theme
      badgeTheme: _badgeTheme(),

      // Menu Theme
      menuTheme: _menuTheme(),

      // Popup Menu Theme
      popupMenuTheme: _popupMenuTheme(),

      // Splash and Highlight Colors
      splashColor: AppColors.primaryIndigo.withValues(alpha: 0.1),
      highlightColor: AppColors.primaryIndigo.withValues(alpha: 0.05),
      hoverColor: AppColors.primaryIndigo.withValues(alpha: 0.04),
      focusColor: AppColors.primaryIndigo.withValues(alpha: 0.12),

      // Disable default splash
      splashFactory: InkRipple.splashFactory,

      // Visual Density
      visualDensity: VisualDensity.adaptivePlatformDensity,
    );
  }

  /// Returns the dark theme configuration
  static ThemeData darkTheme() {
    return ThemeData(
      // Brightness
      brightness: Brightness.dark,
      useMaterial3: true,

      // Color Scheme
      colorScheme: _darkColorScheme(),

      // Scaffold
      scaffoldBackgroundColor: AppColors.backgroundDark,

      // App Bar Theme
      appBarTheme: _darkAppBarTheme(),

      // Text Theme
      textTheme: _darkTextTheme(),

      // Primary Text Theme
      primaryTextTheme: _darkTextTheme(),

      // Button Themes
      elevatedButtonTheme: _elevatedButtonTheme(),
      textButtonTheme: _textButtonTheme(),
      outlinedButtonTheme: _outlinedButtonTheme(),
      filledButtonTheme: _filledButtonTheme(),

      // Floating Action Button Theme
      floatingActionButtonTheme: _fabTheme(),

      // Input Decoration Theme
      inputDecorationTheme: _darkInputDecorationTheme(),

      // Card Theme
      cardTheme: _darkCardTheme(),

      // Chip Theme
      chipTheme: _darkChipTheme(),

      // Dialog Theme
      dialogTheme: _darkDialogTheme(),

      // Bottom Sheet Theme
      bottomSheetTheme: _darkBottomSheetTheme(),

      // Bottom Navigation Bar Theme
      bottomNavigationBarTheme: _darkBottomNavigationBarTheme(),

      // Navigation Bar Theme
      navigationBarTheme: _darkNavigationBarTheme(),

      // Tab Bar Theme
      tabBarTheme: _darkTabBarTheme(),

      // Drawer Theme
      drawerTheme: _darkDrawerTheme(),

      // List Tile Theme
      listTileTheme: _darkListTileTheme(),

      // Icon Theme
      iconTheme: _darkIconTheme(),
      primaryIconTheme: _primaryIconTheme(),

      // Divider Theme
      dividerTheme: _darkDividerTheme(),

      // Snackbar Theme
      snackBarTheme: _darkSnackBarTheme(),

      // Progress Indicator Theme
      progressIndicatorTheme: _progressIndicatorTheme(),

      // Switch Theme
      switchTheme: _switchTheme(),

      // Checkbox Theme
      checkboxTheme: _checkboxTheme(),

      // Radio Theme
      radioTheme: _radioTheme(),

      // Slider Theme
      sliderTheme: _sliderTheme(),

      // Tooltip Theme
      tooltipTheme: _darkTooltipTheme(),

      // Badge Theme
      badgeTheme: _badgeTheme(),

      // Menu Theme
      menuTheme: _darkMenuTheme(),

      // Popup Menu Theme
      popupMenuTheme: _darkPopupMenuTheme(),

      // Splash and Highlight Colors
      splashColor: AppColors.primaryIndigo.withValues(alpha: 0.1),
      highlightColor: AppColors.primaryIndigo.withValues(alpha: 0.05),
      hoverColor: AppColors.primaryIndigo.withValues(alpha: 0.04),
      focusColor: AppColors.primaryIndigo.withValues(alpha: 0.12),

      // Disable default splash
      splashFactory: InkRipple.splashFactory,

      // Visual Density
      visualDensity: VisualDensity.adaptivePlatformDensity,
    );
  }

  // Color Schemes

  static ColorScheme _lightColorScheme() {
    return ColorScheme.light(
      primary: AppColors.primaryIndigo,
      onPrimary: Colors.white,
      primaryContainer: AppColors.primaryPurple,
      onPrimaryContainer: Colors.white,
      secondary: AppColors.secondaryPurple,
      onSecondary: Colors.white,
      secondaryContainer: AppColors.secondaryPurple,
      onSecondaryContainer: Colors.white,
      tertiary: AppColors.info,
      onTertiary: Colors.white,
      error: AppColors.error,
      onError: Colors.white,
      errorContainer: AppColors.surfaceRed,
      onErrorContainer: AppColors.error,
      surface: AppColors.backgroundWhite,
      onSurface: AppColors.textDark,
      surfaceContainerHighest: AppColors.surfaceLight,
      onSurfaceVariant: AppColors.textSecondary,
      outline: AppColors.border,
      outlineVariant: AppColors.borderLight,
      shadow: Colors.black.withValues(alpha: 0.1),
      scrim: Colors.black.withValues(alpha: 0.5),
      inverseSurface: AppColors.backgroundDark,
      onInverseSurface: AppColors.textLight,
      inversePrimary: AppColors.primaryIndigo,
    );
  }

  static ColorScheme _darkColorScheme() {
    return ColorScheme.dark(
      primary: AppColors.primaryIndigo,
      onPrimary: Colors.white,
      primaryContainer: AppColors.primaryPurple,
      onPrimaryContainer: Colors.white,
      secondary: AppColors.secondaryPurple,
      onSecondary: Colors.white,
      secondaryContainer: AppColors.secondaryPurple,
      onSecondaryContainer: Colors.white,
      tertiary: AppColors.info,
      onTertiary: Colors.white,
      error: AppColors.error,
      onError: Colors.white,
      errorContainer: AppColors.errorDark,
      onErrorContainer: Colors.white,
      surface: AppColors.backgroundDark,
      onSurface: AppColors.textLight,
      surfaceContainerHighest: AppColors.backgroundDarkSecondary,
      onSurfaceVariant: AppColors.textLightSecondary,
      outline: AppColors.borderDark,
      outlineVariant: AppColors.borderMedium,
      shadow: Colors.black.withValues(alpha: 0.3),
      scrim: Colors.black.withValues(alpha: 0.7),
      inverseSurface: AppColors.backgroundWhite,
      onInverseSurface: AppColors.textDark,
      inversePrimary: AppColors.primaryIndigo,
    );
  }

  // Text Themes

  static TextTheme _textTheme() {
    return TextTheme(
      displayLarge: AppTextStyles.h1,
      displayMedium: AppTextStyles.h2,
      displaySmall: AppTextStyles.h3,
      headlineLarge: AppTextStyles.h3,
      headlineMedium: AppTextStyles.h4,
      headlineSmall: AppTextStyles.h5,
      titleLarge: AppTextStyles.h4,
      titleMedium: AppTextStyles.h5,
      titleSmall: AppTextStyles.h6,
      bodyLarge: AppTextStyles.body1,
      bodyMedium: AppTextStyles.body2,
      bodySmall: AppTextStyles.bodySmall,
      labelLarge: AppTextStyles.labelLarge,
      labelMedium: AppTextStyles.labelMedium,
      labelSmall: AppTextStyles.labelSmall,
    );
  }

  static TextTheme _darkTextTheme() {
    return TextTheme(
      displayLarge: AppTextStyles.h1.copyWith(color: AppColors.textLight),
      displayMedium: AppTextStyles.h2.copyWith(color: AppColors.textLight),
      displaySmall: AppTextStyles.h3.copyWith(color: AppColors.textLight),
      headlineLarge: AppTextStyles.h3.copyWith(color: AppColors.textLight),
      headlineMedium: AppTextStyles.h4.copyWith(color: AppColors.textLight),
      headlineSmall: AppTextStyles.h5.copyWith(color: AppColors.textLight),
      titleLarge: AppTextStyles.h4.copyWith(color: AppColors.textLight),
      titleMedium: AppTextStyles.h5.copyWith(color: AppColors.textLight),
      titleSmall: AppTextStyles.h6.copyWith(color: AppColors.textLight),
      bodyLarge: AppTextStyles.body1.copyWith(color: AppColors.textLight),
      bodyMedium: AppTextStyles.body2.copyWith(color: AppColors.textLight),
      bodySmall: AppTextStyles.bodySmall.copyWith(
        color: AppColors.textLightTertiary,
      ),
      labelLarge: AppTextStyles.labelLarge.copyWith(color: AppColors.textLight),
      labelMedium: AppTextStyles.labelMedium.copyWith(
        color: AppColors.textLight,
      ),
      labelSmall: AppTextStyles.labelSmall.copyWith(color: AppColors.textLight),
    );
  }

  // App Bar Themes

  static AppBarTheme _lightAppBarTheme() {
    return AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 2,
      centerTitle: false,
      backgroundColor: AppColors.primaryPurple,
      foregroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      iconTheme: IconThemeData(
        color: Colors.white,
        size: AppDimensions.iconMl,
      ),
      actionsIconTheme: IconThemeData(
        color: Colors.white,
        size: AppDimensions.iconMl,
      ),
      titleTextStyle: TextStyle(
        fontFamily: AppTextStyles.fontFamily,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: Colors.white,
        letterSpacing: -0.2,
      ),
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarBrightness: Brightness.dark,
        statusBarIconBrightness: Brightness.light,
        statusBarColor: Colors.transparent,
      ),
    );
  }

  static AppBarTheme _darkAppBarTheme() {
    return AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 2,
      centerTitle: false,
      backgroundColor: AppColors.backgroundDarkSecondary,
      foregroundColor: AppColors.textLight,
      surfaceTintColor: Colors.transparent,
      iconTheme: IconThemeData(
        color: AppColors.textLight,
        size: AppDimensions.iconMl,
      ),
      actionsIconTheme: IconThemeData(
        color: AppColors.textLight,
        size: AppDimensions.iconMl,
      ),
      titleTextStyle: TextStyle(
        fontFamily: AppTextStyles.fontFamily,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: AppColors.textLight,
        letterSpacing: -0.2,
      ),
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarBrightness: Brightness.light,
        statusBarIconBrightness: Brightness.light,
        statusBarColor: Colors.transparent,
      ),
    );
  }

  // Button Themes

  static ElevatedButtonThemeData _elevatedButtonTheme() {
    return ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primaryIndigo,
        foregroundColor: Colors.white,
        elevation: 2,
        shadowColor: AppColors.primaryIndigo.withValues(alpha: 0.3),
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.paddingL,
          vertical: AppDimensions.paddingSm,
        ),
        minimumSize: const Size(
          AppDimensions.buttonMinWidth,
          AppDimensions.buttonHeightM,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusM),
        ),
        textStyle: AppTextStyles.buttonMedium,
      ),
    );
  }

  static TextButtonThemeData _textButtonTheme() {
    return TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primaryIndigo,
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.paddingM,
          vertical: AppDimensions.paddingSm,
        ),
        minimumSize: const Size(
          AppDimensions.buttonMinWidth,
          AppDimensions.buttonHeightM,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusM),
        ),
        textStyle: AppTextStyles.buttonMedium,
      ),
    );
  }

  static OutlinedButtonThemeData _outlinedButtonTheme() {
    return OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primaryIndigo,
        side: const BorderSide(
          color: AppColors.primaryIndigo,
          width: AppDimensions.border,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.paddingL,
          vertical: AppDimensions.paddingSm,
        ),
        minimumSize: const Size(
          AppDimensions.buttonMinWidth,
          AppDimensions.buttonHeightM,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusM),
        ),
        textStyle: AppTextStyles.buttonMedium,
      ),
    );
  }

  static FilledButtonThemeData _filledButtonTheme() {
    return FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primaryIndigo,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.paddingL,
          vertical: AppDimensions.paddingSm,
        ),
        minimumSize: const Size(
          AppDimensions.buttonMinWidth,
          AppDimensions.buttonHeightM,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusM),
        ),
        textStyle: AppTextStyles.buttonMedium,
      ),
    );
  }

  static FloatingActionButtonThemeData _fabTheme() {
    return const FloatingActionButtonThemeData(
      backgroundColor: AppColors.primaryIndigo,
      foregroundColor: Colors.white,
      elevation: 6,
      focusElevation: 8,
      hoverElevation: 8,
      highlightElevation: 12,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(
          Radius.circular(AppDimensions.radiusXl),
        ),
      ),
    );
  }

  // Input Decoration Themes

  static InputDecorationTheme _inputDecorationTheme() {
    return InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surfaceLight,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingM,
        vertical: AppDimensions.paddingSm,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusM),
        borderSide: const BorderSide(
          color: AppColors.border,
          width: AppDimensions.border,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusM),
        borderSide: const BorderSide(
          color: AppColors.border,
          width: AppDimensions.border,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusM),
        borderSide: const BorderSide(
          color: AppColors.primaryIndigo,
          width: AppDimensions.borderThick,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusM),
        borderSide: const BorderSide(
          color: AppColors.error,
          width: AppDimensions.border,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusM),
        borderSide: const BorderSide(
          color: AppColors.error,
          width: AppDimensions.borderThick,
        ),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusM),
        borderSide: const BorderSide(
          color: AppColors.borderLight,
          width: AppDimensions.border,
        ),
      ),
      labelStyle: AppTextStyles.body2.copyWith(color: AppColors.textMuted),
      floatingLabelStyle: AppTextStyles.body2.copyWith(
        color: AppColors.primaryIndigo,
      ),
      helperStyle: AppTextStyles.caption,
      hintStyle: AppTextStyles.body2.copyWith(color: AppColors.textMuted),
      errorStyle: AppTextStyles.error,
      prefixIconColor: AppColors.iconMuted,
      suffixIconColor: AppColors.iconMuted,
    );
  }

  static InputDecorationTheme _darkInputDecorationTheme() {
    return InputDecorationTheme(
      filled: true,
      fillColor: AppColors.backgroundDarkSecondary,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingM,
        vertical: AppDimensions.paddingSm,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusM),
        borderSide: const BorderSide(
          color: AppColors.borderDark,
          width: AppDimensions.border,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusM),
        borderSide: const BorderSide(
          color: AppColors.borderDark,
          width: AppDimensions.border,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusM),
        borderSide: const BorderSide(
          color: AppColors.primaryIndigo,
          width: AppDimensions.borderThick,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusM),
        borderSide: const BorderSide(
          color: AppColors.error,
          width: AppDimensions.border,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusM),
        borderSide: const BorderSide(
          color: AppColors.error,
          width: AppDimensions.borderThick,
        ),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusM),
        borderSide: const BorderSide(
          color: AppColors.borderMedium,
          width: AppDimensions.border,
        ),
      ),
      labelStyle: AppTextStyles.body2.copyWith(
        color: AppColors.textLightTertiary,
      ),
      floatingLabelStyle: AppTextStyles.body2.copyWith(
        color: AppColors.primaryIndigo,
      ),
      helperStyle: AppTextStyles.caption.copyWith(
        color: AppColors.textLightTertiary,
      ),
      hintStyle: AppTextStyles.body2.copyWith(
        color: AppColors.textLightTertiary,
      ),
      errorStyle: AppTextStyles.error,
      prefixIconColor: AppColors.iconMuted,
      suffixIconColor: AppColors.iconMuted,
    );
  }

  // Card Theme

  static CardThemeData _cardTheme() {
    return CardThemeData(
      elevation: AppDimensions.cardElevationM,
      color: AppColors.backgroundWhite,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusL),
        side: const BorderSide(
          color: AppColors.borderLight,
          width: AppDimensions.borderThin,
        ),
      ),
      margin: const EdgeInsets.all(AppDimensions.cardMargin),
      clipBehavior: Clip.antiAlias,
    );
  }

  static CardThemeData _darkCardTheme() {
    return CardThemeData(
      elevation: AppDimensions.cardElevationM,
      color: AppColors.backgroundDarkSecondary,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.black.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusL),
        side: const BorderSide(
          color: AppColors.borderDark,
          width: AppDimensions.borderThin,
        ),
      ),
      margin: const EdgeInsets.all(AppDimensions.cardMargin),
      clipBehavior: Clip.antiAlias,
    );
  }

  // Chip Theme

  static ChipThemeData _chipTheme() {
    return ChipThemeData(
      backgroundColor: AppColors.surfaceLight,
      deleteIconColor: AppColors.textMuted,
      disabledColor: AppColors.borderLight,
      selectedColor: AppColors.primaryIndigo.withValues(alpha: 0.1),
      secondarySelectedColor: AppColors.primaryIndigo.withValues(alpha: 0.1),
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.chipPaddingH,
        vertical: AppDimensions.chipPaddingV,
      ),
      labelStyle: AppTextStyles.labelMedium,
      secondaryLabelStyle: AppTextStyles.labelMedium,
      brightness: Brightness.light,
      elevation: 0,
      pressElevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusM),
        side: const BorderSide(
          color: AppColors.border,
          width: AppDimensions.borderThin,
        ),
      ),
    );
  }

  static ChipThemeData _darkChipTheme() {
    return ChipThemeData(
      backgroundColor: AppColors.backgroundDarkSecondary,
      deleteIconColor: AppColors.textLightTertiary,
      disabledColor: AppColors.borderDark,
      selectedColor: AppColors.primaryIndigo.withValues(alpha: 0.2),
      secondarySelectedColor: AppColors.primaryIndigo.withValues(alpha: 0.2),
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.chipPaddingH,
        vertical: AppDimensions.chipPaddingV,
      ),
      labelStyle: AppTextStyles.labelMedium.copyWith(
        color: AppColors.textLight,
      ),
      secondaryLabelStyle: AppTextStyles.labelMedium.copyWith(
        color: AppColors.textLight,
      ),
      brightness: Brightness.dark,
      elevation: 0,
      pressElevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusM),
        side: const BorderSide(
          color: AppColors.borderDark,
          width: AppDimensions.borderThin,
        ),
      ),
    );
  }

  // Dialog Theme

  static DialogThemeData _dialogTheme() {
    return DialogThemeData(
      backgroundColor: AppColors.backgroundWhite,
      surfaceTintColor: Colors.transparent,
      elevation: AppDimensions.cardElevationXl,
      shadowColor: Colors.black.withValues(alpha: 0.2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
      ),
      titleTextStyle: AppTextStyles.h4,
      contentTextStyle: AppTextStyles.body2,
      actionsPadding: const EdgeInsets.all(AppDimensions.paddingM),
      iconColor: AppColors.iconPrimary,
    );
  }

  static DialogThemeData _darkDialogTheme() {
    return DialogThemeData(
      backgroundColor: AppColors.backgroundDarkSecondary,
      surfaceTintColor: Colors.transparent,
      elevation: AppDimensions.cardElevationXl,
      shadowColor: Colors.black.withValues(alpha: 0.4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
      ),
      titleTextStyle: AppTextStyles.h4.copyWith(color: AppColors.textLight),
      contentTextStyle: AppTextStyles.body2.copyWith(color: AppColors.textLight),
      actionsPadding: const EdgeInsets.all(AppDimensions.paddingM),
      iconColor: AppColors.iconPrimary,
    );
  }

  // Bottom Sheet Theme

  static BottomSheetThemeData _bottomSheetTheme() {
    return const BottomSheetThemeData(
      backgroundColor: AppColors.backgroundWhite,
      surfaceTintColor: Colors.transparent,
      elevation: AppDimensions.cardElevationXl,
      modalBackgroundColor: AppColors.backgroundWhite,
      modalElevation: AppDimensions.cardElevationXl,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimensions.bottomSheetRadius),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      constraints: BoxConstraints(
        maxWidth: AppDimensions.containerMaxWidthL,
      ),
    );
  }

  static BottomSheetThemeData _darkBottomSheetTheme() {
    return const BottomSheetThemeData(
      backgroundColor: AppColors.backgroundDarkSecondary,
      surfaceTintColor: Colors.transparent,
      elevation: AppDimensions.cardElevationXl,
      modalBackgroundColor: AppColors.backgroundDarkSecondary,
      modalElevation: AppDimensions.cardElevationXl,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimensions.bottomSheetRadius),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      constraints: BoxConstraints(
        maxWidth: AppDimensions.containerMaxWidthL,
      ),
    );
  }

  // Bottom Navigation Bar Theme

  static BottomNavigationBarThemeData _bottomNavigationBarTheme() {
    return BottomNavigationBarThemeData(
      backgroundColor: AppColors.backgroundWhite,
      elevation: 8,
      selectedItemColor: AppColors.primaryIndigo,
      unselectedItemColor: AppColors.textMuted,
      selectedIconTheme: const IconThemeData(
        size: AppDimensions.iconMl,
        color: AppColors.primaryIndigo,
      ),
      unselectedIconTheme: const IconThemeData(
        size: AppDimensions.iconMl,
        color: AppColors.textMuted,
      ),
      selectedLabelStyle: AppTextStyles.labelSmall.copyWith(
        color: AppColors.primaryIndigo,
      ),
      unselectedLabelStyle: AppTextStyles.labelSmall.copyWith(
        color: AppColors.textMuted,
      ),
      type: BottomNavigationBarType.fixed,
      enableFeedback: true,
    );
  }

  static BottomNavigationBarThemeData _darkBottomNavigationBarTheme() {
    return BottomNavigationBarThemeData(
      backgroundColor: AppColors.backgroundDarkSecondary,
      elevation: 8,
      selectedItemColor: AppColors.primaryIndigo,
      unselectedItemColor: AppColors.textLightTertiary,
      selectedIconTheme: const IconThemeData(
        size: AppDimensions.iconMl,
        color: AppColors.primaryIndigo,
      ),
      unselectedIconTheme: const IconThemeData(
        size: AppDimensions.iconMl,
        color: AppColors.textLightTertiary,
      ),
      selectedLabelStyle: AppTextStyles.labelSmall.copyWith(
        color: AppColors.primaryIndigo,
      ),
      unselectedLabelStyle: AppTextStyles.labelSmall.copyWith(
        color: AppColors.textLightTertiary,
      ),
      type: BottomNavigationBarType.fixed,
      enableFeedback: true,
    );
  }

  // Navigation Bar Theme

  static NavigationBarThemeData _navigationBarTheme() {
    return NavigationBarThemeData(
      backgroundColor: AppColors.backgroundWhite,
      elevation: 0,
      height: AppDimensions.bottomNavHeight,
      indicatorColor: AppColors.primaryIndigo.withValues(alpha: 0.1),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AppTextStyles.labelSmall.copyWith(
            color: AppColors.primaryIndigo,
          );
        }
        return AppTextStyles.labelSmall.copyWith(color: AppColors.textMuted);
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(
            size: AppDimensions.iconMl,
            color: AppColors.primaryIndigo,
          );
        }
        return const IconThemeData(
          size: AppDimensions.iconMl,
          color: AppColors.textMuted,
        );
      }),
    );
  }

  static NavigationBarThemeData _darkNavigationBarTheme() {
    return NavigationBarThemeData(
      backgroundColor: AppColors.backgroundDarkSecondary,
      elevation: 0,
      height: AppDimensions.bottomNavHeight,
      indicatorColor: AppColors.primaryIndigo.withValues(alpha: 0.2),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AppTextStyles.labelSmall.copyWith(
            color: AppColors.primaryIndigo,
          );
        }
        return AppTextStyles.labelSmall.copyWith(
          color: AppColors.textLightTertiary,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(
            size: AppDimensions.iconMl,
            color: AppColors.primaryIndigo,
          );
        }
        return const IconThemeData(
          size: AppDimensions.iconMl,
          color: AppColors.textLightTertiary,
        );
      }),
    );
  }

  // Tab Bar Theme

  static TabBarThemeData _tabBarTheme() {
    return TabBarThemeData(
      labelColor: AppColors.primaryIndigo,
      unselectedLabelColor: AppColors.textMuted,
      labelStyle: AppTextStyles.labelLarge,
      unselectedLabelStyle: AppTextStyles.labelLarge,
      indicator: const UnderlineTabIndicator(
        borderSide: BorderSide(
          color: AppColors.primaryIndigo,
          width: AppDimensions.borderThick,
        ),
      ),
      indicatorSize: TabBarIndicatorSize.label,
      dividerColor: AppColors.divider,
      overlayColor: WidgetStateProperty.all(
        AppColors.primaryIndigo.withValues(alpha: 0.1),
      ),
    );
  }

  static TabBarThemeData _darkTabBarTheme() {
    return TabBarThemeData(
      labelColor: AppColors.primaryIndigo,
      unselectedLabelColor: AppColors.textLightTertiary,
      labelStyle: AppTextStyles.labelLarge,
      unselectedLabelStyle: AppTextStyles.labelLarge,
      indicator: const UnderlineTabIndicator(
        borderSide: BorderSide(
          color: AppColors.primaryIndigo,
          width: AppDimensions.borderThick,
        ),
      ),
      indicatorSize: TabBarIndicatorSize.label,
      dividerColor: AppColors.dividerDark,
      overlayColor: WidgetStateProperty.all(
        AppColors.primaryIndigo.withValues(alpha: 0.1),
      ),
    );
  }

  // Drawer Theme

  static DrawerThemeData _drawerTheme() {
    return const DrawerThemeData(
      backgroundColor: AppColors.backgroundWhite,
      surfaceTintColor: Colors.transparent,
      elevation: AppDimensions.cardElevationXl,
      width: 280,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(AppDimensions.radiusXl),
          bottomRight: Radius.circular(AppDimensions.radiusXl),
        ),
      ),
    );
  }

  static DrawerThemeData _darkDrawerTheme() {
    return const DrawerThemeData(
      backgroundColor: AppColors.backgroundDarkSecondary,
      surfaceTintColor: Colors.transparent,
      elevation: AppDimensions.cardElevationXl,
      width: 280,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(AppDimensions.radiusXl),
          bottomRight: Radius.circular(AppDimensions.radiusXl),
        ),
      ),
    );
  }

  // List Tile Theme

  static ListTileThemeData _listTileTheme() {
    return ListTileThemeData(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.listTilePaddingH,
        vertical: AppDimensions.listTilePaddingV,
      ),
      minVerticalPadding: AppDimensions.listTilePaddingV,
      iconColor: AppColors.iconMuted,
      textColor: AppColors.textDark,
      titleTextStyle: AppTextStyles.body1Medium,
      subtitleTextStyle: AppTextStyles.body2.copyWith(
        color: AppColors.textSecondary,
      ),
      leadingAndTrailingTextStyle: AppTextStyles.body2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusM),
      ),
    );
  }

  static ListTileThemeData _darkListTileTheme() {
    return ListTileThemeData(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.listTilePaddingH,
        vertical: AppDimensions.listTilePaddingV,
      ),
      minVerticalPadding: AppDimensions.listTilePaddingV,
      iconColor: AppColors.iconMuted,
      textColor: AppColors.textLight,
      titleTextStyle: AppTextStyles.body1Medium.copyWith(
        color: AppColors.textLight,
      ),
      subtitleTextStyle: AppTextStyles.body2.copyWith(
        color: AppColors.textLightSecondary,
      ),
      leadingAndTrailingTextStyle: AppTextStyles.body2.copyWith(
        color: AppColors.textLight,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusM),
      ),
    );
  }

  // Icon Themes

  static IconThemeData _iconTheme() {
    return const IconThemeData(
      color: AppColors.textDark,
      size: AppDimensions.iconMl,
    );
  }

  static IconThemeData _darkIconTheme() {
    return const IconThemeData(
      color: AppColors.textLight,
      size: AppDimensions.iconMl,
    );
  }

  static IconThemeData _primaryIconTheme() {
    return const IconThemeData(
      color: AppColors.iconPrimary,
      size: AppDimensions.iconMl,
    );
  }

  // Divider Theme

  static DividerThemeData _dividerTheme() {
    return const DividerThemeData(
      color: AppColors.divider,
      thickness: AppDimensions.divider,
      space: AppDimensions.spacingM,
    );
  }

  static DividerThemeData _darkDividerTheme() {
    return const DividerThemeData(
      color: AppColors.dividerDark,
      thickness: AppDimensions.divider,
      space: AppDimensions.spacingM,
    );
  }

  // Snackbar Theme

  static SnackBarThemeData _snackBarTheme() {
    return SnackBarThemeData(
      backgroundColor: AppColors.textDark,
      contentTextStyle: AppTextStyles.body2.copyWith(color: Colors.white),
      elevation: AppDimensions.cardElevationL,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.snackbarRadius),
      ),
      behavior: SnackBarBehavior.floating,
      actionTextColor: AppColors.primaryIndigo,
    );
  }

  static SnackBarThemeData _darkSnackBarTheme() {
    return SnackBarThemeData(
      backgroundColor: AppColors.backgroundDarkSecondary,
      contentTextStyle: AppTextStyles.body2.copyWith(
        color: AppColors.textLight,
      ),
      elevation: AppDimensions.cardElevationL,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.snackbarRadius),
      ),
      behavior: SnackBarBehavior.floating,
      actionTextColor: AppColors.primaryIndigo,
    );
  }

  // Progress Indicator Theme

  static ProgressIndicatorThemeData _progressIndicatorTheme() {
    return const ProgressIndicatorThemeData(
      color: AppColors.primaryIndigo,
      linearTrackColor: AppColors.borderLight,
      circularTrackColor: AppColors.borderLight,
    );
  }

  // Switch Theme

  static SwitchThemeData _switchTheme() {
    return SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AppColors.primaryIndigo;
        }
        return AppColors.borderMedium;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AppColors.primaryIndigo.withValues(alpha: 0.5);
        }
        return AppColors.borderLight;
      }),
      overlayColor: WidgetStateProperty.all(
        AppColors.primaryIndigo.withValues(alpha: 0.1),
      ),
    );
  }

  // Checkbox Theme

  static CheckboxThemeData _checkboxTheme() {
    return CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AppColors.primaryIndigo;
        }
        return Colors.transparent;
      }),
      checkColor: WidgetStateProperty.all(Colors.white),
      overlayColor: WidgetStateProperty.all(
        AppColors.primaryIndigo.withValues(alpha: 0.1),
      ),
      side: const BorderSide(
        color: AppColors.border,
        width: AppDimensions.borderThick,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusS),
      ),
    );
  }

  // Radio Theme

  static RadioThemeData _radioTheme() {
    return RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AppColors.primaryIndigo;
        }
        return AppColors.border;
      }),
      overlayColor: WidgetStateProperty.all(
        AppColors.primaryIndigo.withValues(alpha: 0.1),
      ),
    );
  }

  // Slider Theme

  static SliderThemeData _sliderTheme() {
    return const SliderThemeData(
      activeTrackColor: AppColors.primaryIndigo,
      inactiveTrackColor: AppColors.borderLight,
      thumbColor: AppColors.primaryIndigo,
      overlayColor: Color(0x1A6366F1),
      valueIndicatorColor: AppColors.primaryIndigo,
      valueIndicatorTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  // Tooltip Theme

  static TooltipThemeData _tooltipTheme() {
    return TooltipThemeData(
      decoration: BoxDecoration(
        color: AppColors.textDark.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(AppDimensions.radiusS),
      ),
      textStyle: AppTextStyles.caption.copyWith(color: Colors.white),
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingSm,
        vertical: AppDimensions.paddingXs,
      ),
      margin: const EdgeInsets.all(AppDimensions.spacingS),
      preferBelow: true,
      verticalOffset: AppDimensions.spacingS,
      waitDuration: const Duration(milliseconds: 500),
    );
  }

  static TooltipThemeData _darkTooltipTheme() {
    return TooltipThemeData(
      decoration: BoxDecoration(
        color: AppColors.backgroundDarkSecondary,
        borderRadius: BorderRadius.circular(AppDimensions.radiusS),
        border: Border.all(
          color: AppColors.borderDark,
          width: AppDimensions.borderThin,
        ),
      ),
      textStyle: AppTextStyles.caption.copyWith(color: AppColors.textLight),
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingSm,
        vertical: AppDimensions.paddingXs,
      ),
      margin: const EdgeInsets.all(AppDimensions.spacingS),
      preferBelow: true,
      verticalOffset: AppDimensions.spacingS,
      waitDuration: const Duration(milliseconds: 500),
    );
  }

  // Badge Theme

  static BadgeThemeData _badgeTheme() {
    return const BadgeThemeData(
      backgroundColor: AppColors.error,
      textColor: Colors.white,
      smallSize: 6,
      largeSize: 16,
      textStyle: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w600,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: 4,
        vertical: 2,
      ),
    );
  }

  // Menu Theme

  static MenuThemeData _menuTheme() {
    return MenuThemeData(
      style: MenuStyle(
        backgroundColor: WidgetStateProperty.all(AppColors.backgroundWhite),
        surfaceTintColor: WidgetStateProperty.all(Colors.transparent),
        elevation: WidgetStateProperty.all(AppDimensions.cardElevationL),
        padding: WidgetStateProperty.all(
          const EdgeInsets.symmetric(vertical: AppDimensions.paddingS),
        ),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusM),
          ),
        ),
      ),
    );
  }

  static MenuThemeData _darkMenuTheme() {
    return MenuThemeData(
      style: MenuStyle(
        backgroundColor: WidgetStateProperty.all(
          AppColors.backgroundDarkSecondary,
        ),
        surfaceTintColor: WidgetStateProperty.all(Colors.transparent),
        elevation: WidgetStateProperty.all(AppDimensions.cardElevationL),
        padding: WidgetStateProperty.all(
          const EdgeInsets.symmetric(vertical: AppDimensions.paddingS),
        ),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusM),
          ),
        ),
      ),
    );
  }

  // Popup Menu Theme

  static PopupMenuThemeData _popupMenuTheme() {
    return PopupMenuThemeData(
      color: AppColors.backgroundWhite,
      surfaceTintColor: Colors.transparent,
      elevation: AppDimensions.cardElevationL,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusM),
      ),
      textStyle: AppTextStyles.body2,
    );
  }

  static PopupMenuThemeData _darkPopupMenuTheme() {
    return PopupMenuThemeData(
      color: AppColors.backgroundDarkSecondary,
      surfaceTintColor: Colors.transparent,
      elevation: AppDimensions.cardElevationL,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusM),
      ),
      textStyle: AppTextStyles.body2.copyWith(color: AppColors.textLight),
    );
  }
}
