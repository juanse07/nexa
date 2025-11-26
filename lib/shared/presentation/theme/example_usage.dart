// ignore_for_file: unused_element

import 'package:flutter/material.dart';
import 'package:nexa/shared/presentation/theme/theme.dart';
import 'package:nexa/shared/presentation/theme/app_colors.dart';

/// Example file demonstrating proper usage of the Nexa theme system.
///
/// This file is for reference only and should not be imported in production code.
class ThemeExamples {
  ThemeExamples._();

  /// Example: Using AppColors
  static Widget colorExample() {
    return Container(
      color: AppColors.primaryIndigo,
      child: Column(
        children: [
          Text(
            'Primary Text',
            style: TextStyle(color: AppColors.textLight),
          ),
          Container(
            color: AppColors.success,
            child: Text('Success', style: TextStyle(color: Colors.white)),
          ),
          Container(
            color: AppColors.error,
            child: Text('Error', style: TextStyle(color: Colors.white)),
          ),
          // Using opacity helpers
          Container(
            color: AppColors.primaryLight10,
            child: Text('Light Primary'),
          ),
        ],
      ),
    );
  }

  /// Example: Using AppTextStyles
  static Widget textStyleExample() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Heading 1', style: AppTextStyles.h1),
        Text('Heading 2', style: AppTextStyles.h2),
        Text('Heading 3', style: AppTextStyles.h3),
        Text('Body text', style: AppTextStyles.body1),
        Text('Small body text', style: AppTextStyles.body2),
        Text('Caption text', style: AppTextStyles.caption),
        // Customizing styles
        Text(
          'Custom styled text',
          style: AppTextStyles.body1.copyWith(
            color: AppColors.primaryIndigo,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  /// Example: Using AppDimensions
  static Widget dimensionsExample() {
    return Container(
      padding: EdgeInsets.all(AppDimensions.paddingM),
      margin: EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingL,
        vertical: AppDimensions.spacingM,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(AppDimensions.radiusL),
      ),
      child: Column(
        children: [
          Icon(
            Icons.star,
            size: AppDimensions.iconMl,
            color: AppColors.iconPrimary,
          ),
          SizedBox(height: AppDimensions.spacingS),
          Text('Content', style: AppTextStyles.body1),
        ],
      ),
    );
  }

  /// Example: Card with shadows
  static Widget cardWithShadowExample() {
    return Container(
      margin: EdgeInsets.all(AppDimensions.cardMargin),
      padding: EdgeInsets.all(AppDimensions.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.backgroundWhite,
        borderRadius: BorderRadius.circular(AppDimensions.radiusL),
        boxShadow: AppShadows.card,
        border: Border.all(
          color: AppColors.borderLight,
          width: AppDimensions.borderThin,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Card Title', style: AppTextStyles.h4),
          SizedBox(height: AppDimensions.spacingS),
          Text(
            'Card content with proper spacing and styling',
            style: AppTextStyles.body2,
          ),
        ],
      ),
    );
  }

  /// Example: Custom button
  static Widget customButtonExample() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primaryIndigo,
        borderRadius: BorderRadius.circular(AppDimensions.radiusM),
        boxShadow: AppShadows.button,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppDimensions.radiusM),
          onTap: () {},
          child: Container(
            height: AppDimensions.buttonHeightM,
            padding: EdgeInsets.symmetric(
              horizontal: AppDimensions.paddingL,
            ),
            alignment: Alignment.center,
            child: Text(
              'Custom Button',
              style: AppTextStyles.buttonMedium,
            ),
          ),
        ),
      ),
    );
  }

  /// Example: Form field with theme
  static Widget formFieldExample() {
    return TextFormField(
      decoration: InputDecoration(
        labelText: 'Email Address',
        labelStyle: AppTextStyles.labelMedium,
        hintText: 'Enter your email',
        hintStyle: AppTextStyles.body2.copyWith(
          color: AppColors.textMuted,
        ),
        prefixIcon: Icon(
          Icons.email_outlined,
          size: AppDimensions.iconM,
          color: AppColors.iconPrimary,
        ),
        filled: true,
        fillColor: AppColors.surfaceLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusM),
          borderSide: BorderSide(
            color: AppColors.border,
            width: AppDimensions.border,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusM),
          borderSide: BorderSide(
            color: AppColors.primaryIndigo,
            width: AppDimensions.borderThick,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusM),
          borderSide: BorderSide(
            color: AppColors.error,
            width: AppDimensions.border,
          ),
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: AppDimensions.paddingM,
          vertical: AppDimensions.paddingSm,
        ),
      ),
      style: AppTextStyles.body1,
    );
  }

  /// Example: Status badge
  static Widget statusBadgeExample(String text, bool isSuccess) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppDimensions.chipPaddingH,
        vertical: AppDimensions.chipPaddingV,
      ),
      decoration: BoxDecoration(
        color: isSuccess
            ? AppColors.success.withValues(alpha: 0.1)
            : AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
        border: Border.all(
          color: isSuccess ? AppColors.success : AppColors.error,
          width: AppDimensions.borderThin,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isSuccess ? Icons.check_circle : Icons.error,
            size: AppDimensions.iconS,
            color: isSuccess ? AppColors.success : AppColors.error,
          ),
          SizedBox(width: AppDimensions.spacingXs),
          Text(
            text,
            style: AppTextStyles.labelSmall.copyWith(
              color: isSuccess ? AppColors.success : AppColors.error,
            ),
          ),
        ],
      ),
    );
  }

  /// Example: Avatar with size variants
  static Widget avatarExample() {
    return Row(
      children: [
        CircleAvatar(
          radius: AppDimensions.avatarXs / 2,
          backgroundColor: AppColors.primaryIndigo,
          child: Icon(
            Icons.person,
            size: AppDimensions.iconXs,
            color: Colors.white,
          ),
        ),
        SizedBox(width: AppDimensions.spacingS),
        CircleAvatar(
          radius: AppDimensions.avatarM / 2,
          backgroundColor: AppColors.primaryIndigo,
          child: Icon(
            Icons.person,
            size: AppDimensions.iconM,
            color: Colors.white,
          ),
        ),
        SizedBox(width: AppDimensions.spacingS),
        CircleAvatar(
          radius: AppDimensions.avatarL / 2,
          backgroundColor: AppColors.primaryIndigo,
          child: Icon(
            Icons.person,
            size: AppDimensions.iconL,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  /// Example: List tile with theme
  static Widget listTileExample() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: AppDimensions.spacingM),
      decoration: BoxDecoration(
        color: AppColors.backgroundWhite,
        borderRadius: BorderRadius.circular(AppDimensions.radiusM),
        border: Border.all(
          color: AppColors.borderLight,
          width: AppDimensions.borderThin,
        ),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(
          horizontal: AppDimensions.listTilePaddingH,
          vertical: AppDimensions.listTilePaddingV,
        ),
        leading: CircleAvatar(
          backgroundColor: AppColors.primaryIndigo.withValues(alpha: 0.1),
          child: Icon(
            Icons.folder,
            color: AppColors.primaryIndigo,
            size: AppDimensions.iconM,
          ),
        ),
        title: Text('List Item Title', style: AppTextStyles.body1Medium),
        subtitle: Text('Subtitle text', style: AppTextStyles.body2),
        trailing: Icon(
          Icons.chevron_right,
          size: AppDimensions.iconM,
          color: AppColors.iconMuted,
        ),
      ),
    );
  }

  /// Example: Dialog with theme
  static Widget dialogExample(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.backgroundWhite,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
      ),
      title: Text('Dialog Title', style: AppTextStyles.h4),
      content: Text(
        'This is the dialog content with proper theming.',
        style: AppTextStyles.body2,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Cancel',
            style: AppTextStyles.buttonMedium.copyWith(
              color: AppColors.textMuted,
            ),
          ),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryIndigo,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusM),
            ),
          ),
          child: Text('Confirm', style: AppTextStyles.buttonMedium),
        ),
      ],
    );
  }

  /// Example: Complete screen layout
  static Widget completeScreenExample() {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: Text('Theme Example', style: AppTextStyles.h5),
        backgroundColor: AppColors.primaryPurple,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(AppDimensions.paddingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Heading', style: AppTextStyles.h2),
            SizedBox(height: AppDimensions.spacingS),
            Text(
              'This is a complete example of using the theme system.',
              style: AppTextStyles.body1,
            ),
            SizedBox(height: AppDimensions.spacingL),
            cardWithShadowExample(),
            SizedBox(height: AppDimensions.spacingM),
            formFieldExample(),
            SizedBox(height: AppDimensions.spacingM),
            customButtonExample(),
            SizedBox(height: AppDimensions.spacingM),
            listTileExample(),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: AppColors.primaryIndigo,
        child: Icon(Icons.add, size: AppDimensions.iconMl),
      ),
    );
  }
}
