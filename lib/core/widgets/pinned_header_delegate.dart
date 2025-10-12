import 'package:flutter/material.dart';

/// A simple persistent header delegate that pins a widget at the top
/// while allowing content below to scroll
class PinnedHeaderDelegate extends SliverPersistentHeaderDelegate {
  PinnedHeaderDelegate({
    required this.child,
    required this.height,
    this.safeAreaPadding = 0.0,
  });

  final Widget child;
  final double height;
  final double safeAreaPadding;

  @override
  double get minExtent => height + safeAreaPadding;

  @override
  double get maxExtent => height + safeAreaPadding;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return SizedBox.expand(child: child);
  }

  @override
  bool shouldRebuild(PinnedHeaderDelegate oldDelegate) {
    return height != oldDelegate.height ||
           child != oldDelegate.child ||
           safeAreaPadding != oldDelegate.safeAreaPadding;
  }
}
