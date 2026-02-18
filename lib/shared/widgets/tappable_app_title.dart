import 'package:flutter/material.dart';
import 'package:nexa/features/main/presentation/main_screen.dart';

/// A tappable AppBar title that navigates back to the main tab screen.
///
/// Tapping the title pops the entire navigation stack and lands on
/// [MainScreen] at [targetTabIndex] (defaults to 0 = Jobs). This gives
/// a consistent "tap title to go home" behavior across the entire app.
class TappableAppTitle extends StatelessWidget {
  final Widget child;
  final int targetTabIndex;

  const TappableAppTitle({
    super.key,
    required this.child,
    this.targetTabIndex = 0,
  });

  /// Convenience constructor for plain text titles.
  factory TappableAppTitle.text(
    String text, {
    Key? key,
    TextStyle? style,
    int targetTabIndex = 0,
  }) {
    return TappableAppTitle(
      key: key,
      targetTabIndex: targetTabIndex,
      child: Text(text, style: style),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _navigateHome(context),
      child: child,
    );
  }

  void _navigateHome(BuildContext context) {
    // If we're already at root and it's a MainScreen, just switch tab
    final navigator = Navigator.of(context);

    // Pop everything and go to MainScreen at the target tab
    navigator.pushAndRemoveUntil(
      PageRouteBuilder<void>(
        pageBuilder: (_, __, ___) => MainScreen(initialIndex: targetTabIndex),
        transitionDuration: const Duration(milliseconds: 200),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
      (route) => false,
    );
  }
}
