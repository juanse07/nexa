# Nexa Theme System

A comprehensive theming system for the Nexa Flutter application.

## Overview

This theme system provides a complete, consistent design language across the entire application with support for both light and dark modes.

## Files

- **app_theme.dart** - Main theme configuration with light and dark themes
- **app_colors.dart** - Color constants organized by category
- **app_text_styles.dart** - Predefined text styles for all text elements
- **app_dimensions.dart** - Spacing, sizing, and dimension constants
- **app_shadows.dart** - Box shadow presets for various elevation levels
- **theme.dart** - Convenience export file

## Usage

### Basic Setup

Import the theme in your main app file:

```dart
import 'package:nexa/shared/presentation/theme/theme.dart';

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nexa',
      theme: AppTheme.lightTheme(),
      darkTheme: AppTheme.darkTheme(),
      themeMode: ThemeMode.system,
      home: HomeScreen(),
    );
  }
}
```

### Using Colors

```dart
import 'package:nexa/shared/presentation/theme/theme.dart';

Container(
  color: AppColors.primaryIndigo,
  child: Text(
    'Hello',
    style: TextStyle(color: AppColors.textLight),
  ),
)
```

### Using Text Styles

```dart
import 'package:nexa/shared/presentation/theme/theme.dart';

Text(
  'Main Title',
  style: AppTextStyles.h1,
)

Text(
  'Body content',
  style: AppTextStyles.body1,
)

Text(
  'Small caption',
  style: AppTextStyles.caption,
)
```

### Using Dimensions

```dart
import 'package:nexa/shared/presentation/theme/theme.dart';

Container(
  padding: EdgeInsets.all(AppDimensions.paddingM),
  margin: EdgeInsets.symmetric(
    horizontal: AppDimensions.spacingL,
  ),
  decoration: BoxDecoration(
    borderRadius: BorderRadius.circular(AppDimensions.radiusL),
  ),
  child: Icon(
    Icons.home,
    size: AppDimensions.iconMl,
  ),
)
```

### Using Shadows

```dart
import 'package:nexa/shared/presentation/theme/theme.dart';

Container(
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(AppDimensions.radiusL),
    boxShadow: AppShadows.card,
  ),
  child: // ... card content
)

// For buttons
Container(
  decoration: BoxDecoration(
    color: AppColors.primaryIndigo,
    borderRadius: BorderRadius.circular(AppDimensions.radiusM),
    boxShadow: AppShadows.button,
  ),
)
```

### Customizing Text Styles

```dart
import 'package:nexa/shared/presentation/theme/theme.dart';

// Using helper methods
Text(
  'Custom text',
  style: AppTextStyles.withColor(
    AppTextStyles.h2,
    AppColors.primaryIndigo,
  ),
)

// Using copyWith
Text(
  'Another custom text',
  style: AppTextStyles.body1.copyWith(
    color: AppColors.error,
    fontWeight: FontWeight.w600,
  ),
)
```

### Using Opacity Helpers

```dart
import 'package:nexa/shared/presentation/theme/theme.dart';

Container(
  color: AppColors.primaryLight10, // Primary with 10% opacity
  child: // ... content
)

Container(
  color: AppColors.withOpacity(AppColors.success, 0.2),
  child: // ... content
)
```

## Color Palette

### Primary Colors
- **primaryIndigo**: `#6366F1` - Main brand color
- **primaryPurple**: `#430172` - Alternate brand color
- **secondaryPurple**: `#8B5CF6` - Accent color

### Status Colors
- **success**: `#059669` - Success states
- **error**: `#EF4444` - Error states
- **warning**: `#F59E0B` - Warning states
- **info**: `#0EA5E9` - Info states

### Surface Colors
- **surfaceLight**: `#F8FAFC` - Light background
- **backgroundWhite**: `#FFFFFF` - Pure white

### Text Colors
- **textDark**: `#0F172A` - Primary text (light mode)
- **textLight**: `#F8FAFC` - Primary text (dark mode)

## Text Style Hierarchy

- **h1** - 32px, Bold - Main titles
- **h2** - 28px, Bold - Section titles
- **h3** - 24px, Semibold - Card headers
- **h4** - 20px, Semibold - Dialog titles
- **h5** - 18px, Semibold - Inline headers
- **h6** - 16px, Semibold - Labels
- **body1** - 16px, Regular - Main content
- **body2** - 14px, Regular - Standard content
- **bodySmall** - 12px, Regular - Secondary info
- **caption** - 12px, Regular - Hints and helper text
- **labelLarge** - 14px, Semibold - Prominent labels
- **labelMedium** - 12px, Semibold - Form labels
- **labelSmall** - 11px, Semibold - Small labels

## Common Dimensions

### Spacing
- **spacingXs**: 4px
- **spacingS**: 8px
- **spacingM**: 16px
- **spacingL**: 24px
- **spacingXl**: 32px

### Border Radius
- **radiusS**: 4px
- **radiusM**: 8px
- **radiusL**: 12px
- **radiusXl**: 16px

### Icon Sizes
- **iconS**: 16px
- **iconM**: 20px
- **iconMl**: 24px
- **iconL**: 28px
- **iconXl**: 32px

### Button Heights
- **buttonHeightS**: 32px
- **buttonHeightM**: 40px
- **buttonHeightL**: 48px
- **buttonHeightXl**: 56px

## Shadow Presets

- **xs** - Subtle hover states
- **sm** - Buttons, chips
- **md** - Cards, containers
- **lg** - FABs, prominent cards
- **xl** - Modals, bottom sheets
- **xxl** - Dialogs, popovers
- **card** - Optimized for cards
- **button** - Optimized for buttons
- **modal** - Deep shadow for modals

## Best Practices

1. **Always use the theme system** - Don't hardcode colors, sizes, or styles
2. **Use const constructors** - All theme values are const for performance
3. **Leverage existing styles** - Use predefined text styles and modify with copyWith if needed
4. **Maintain consistency** - Use the same spacing values throughout the app
5. **Test both themes** - Always verify your UI works in both light and dark modes

## Examples

### Creating a Card

```dart
Card(
  margin: EdgeInsets.all(AppDimensions.cardMargin),
  child: Padding(
    padding: EdgeInsets.all(AppDimensions.cardPadding),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Card Title',
          style: AppTextStyles.h4,
        ),
        SizedBox(height: AppDimensions.spacingS),
        Text(
          'Card content goes here',
          style: AppTextStyles.body2,
        ),
      ],
    ),
  ),
)
```

### Creating a Button

```dart
ElevatedButton(
  style: ElevatedButton.styleFrom(
    backgroundColor: AppColors.primaryIndigo,
    foregroundColor: Colors.white,
    minimumSize: Size(
      AppDimensions.buttonWidthM,
      AppDimensions.buttonHeightM,
    ),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppDimensions.radiusM),
    ),
  ),
  onPressed: () {},
  child: Text('Button', style: AppTextStyles.buttonMedium),
)
```

### Creating a Form Field

```dart
TextFormField(
  decoration: InputDecoration(
    labelText: 'Email',
    labelStyle: AppTextStyles.labelMedium,
    hintText: 'Enter your email',
    hintStyle: AppTextStyles.body2.copyWith(
      color: AppColors.textMuted,
    ),
    prefixIcon: Icon(
      Icons.email,
      size: AppDimensions.iconM,
      color: AppColors.iconPrimary,
    ),
    filled: true,
    fillColor: AppColors.surfaceLight,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppDimensions.radiusM),
      borderSide: BorderSide(color: AppColors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppDimensions.radiusM),
      borderSide: BorderSide(
        color: AppColors.primaryIndigo,
        width: AppDimensions.borderThick,
      ),
    ),
  ),
)
```

## Migration

When migrating existing code to use this theme system:

1. Replace hardcoded colors with `AppColors.*`
2. Replace hardcoded text styles with `AppTextStyles.*`
3. Replace hardcoded dimensions with `AppDimensions.*`
4. Add shadows using `AppShadows.*`
5. Ensure all components work in both light and dark themes

## Contributing

When adding new theme values:

1. Add constants to the appropriate file (colors, dimensions, etc.)
2. Include documentation comments
3. Follow the existing naming conventions
4. Test in both light and dark modes
5. Update this README if adding new categories
