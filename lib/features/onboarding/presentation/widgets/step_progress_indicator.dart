import 'package:flutter/material.dart';
import 'package:nexa/shared/presentation/theme/app_colors.dart';

/// Animated progress indicator with **dot** and **bar** variants.
///
/// Dot variant (venue onboarding): small circles at the bottom of the screen.
/// Bar variant (business setup): segmented horizontal bar with gold fill + glow.
///
/// Both animate smoothly between steps using [AnimatedContainer] duration.
class StepProgressIndicator extends StatelessWidget {
  final int currentStep;
  final int totalSteps;
  final StepIndicatorVariant variant;
  final Color activeColor;
  final Color inactiveColor;

  const StepProgressIndicator({
    super.key,
    required this.currentStep,
    required this.totalSteps,
    this.variant = StepIndicatorVariant.dot,
    this.activeColor = AppColors.primaryIndigo, // gold
    this.inactiveColor = const Color(0x33FFFFFF), // white 20%
  });

  @override
  Widget build(BuildContext context) {
    return variant == StepIndicatorVariant.dot
        ? _buildDots()
        : _buildBar();
  }

  Widget _buildDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(totalSteps, (index) {
        final isActive = index <= currentStep;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: index == currentStep ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: isActive ? activeColor : inactiveColor,
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: activeColor.withValues(alpha: 0.4),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
        );
      }),
    );
  }

  Widget _buildBar() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final fillFraction = totalSteps > 0
            ? (currentStep + 1) / totalSteps
            : 0.0;

        return Container(
          height: 6,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(3),
            color: inactiveColor,
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeInOut,
              width: totalWidth * fillFraction,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                color: activeColor,
                boxShadow: [
                  BoxShadow(
                    color: activeColor.withValues(alpha: 0.5),
                    blurRadius: 8,
                    spreadRadius: 0,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

enum StepIndicatorVariant { dot, bar }
