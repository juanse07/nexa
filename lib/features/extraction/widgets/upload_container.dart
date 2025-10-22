import 'package:flutter/material.dart';

/// Standard container wrapper for upload tab content
/// Provides consistent layout: ScrollView + Center + MaxWidth constraint + Padding
class UploadContainer extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry padding;

  const UploadContainer({
    super.key,
    required this.child,
    this.maxWidth = 800,
    this.padding = const EdgeInsets.all(20),
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Center(
        child: Container(
          constraints: BoxConstraints(maxWidth: maxWidth),
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}
