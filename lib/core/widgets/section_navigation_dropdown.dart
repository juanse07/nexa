import 'package:flutter/material.dart';

/// A reusable navigation dropdown widget that can be used across different screens
/// Supports both fixed and scroll-responsive modes
class SectionNavigationDropdown extends StatelessWidget {
  final bool isFixed;
  final double? scrollOffset;
  final String selectedSection;
  final void Function(String) onNavigate;

  const SectionNavigationDropdown({
    super.key,
    required this.selectedSection,
    required this.onNavigate,
    this.isFixed = true,
    this.scrollOffset,
  });

  @override
  Widget build(BuildContext context) {
    // For fixed mode, always use the opaque style
    // For scroll-responsive mode, calculate opacity based on scroll offset
    final bool isScrolled = !isFixed && (scrollOffset ?? 0) > 50;
    final double opacity = isFixed ? 0.2 : (isScrolled ? 0.95 : 0.15);
    final double height = isFixed ? 40 : (isScrolled ? 40 : 52);
    final Color iconColor = Colors.white;
    final Color textColor = Colors.white;
    final double iconSize = isFixed || isScrolled ? 16 : 18;
    final double fontSize = isFixed || isScrolled ? 16 : 16;
    final double horizontalPadding = isFixed || isScrolled ? 12 : 16;
    final double borderRadius = isFixed || isScrolled ? 12 : 16;

    return Container(
      height: height,
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(opacity),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: null,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedSection,
          icon: Icon(
            Icons.keyboard_arrow_down,
            color: iconColor,
            size: isFixed || isScrolled ? 20 : 24,
          ),
          dropdownColor: const Color(0xFF7C3AED),
          style: TextStyle(
            color: textColor,
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
          ),
          isExpanded: true,
          menuMaxHeight: 400,
          alignment: AlignmentDirectional.bottomStart,
          items: [
            DropdownMenuItem(
              value: 'Jobs',
              child: Row(
                children: [
                  Icon(Icons.work_outline, color: iconColor, size: iconSize),
                  const SizedBox(width: 8),
                  Text('Jobs'),
                ],
              ),
            ),
            DropdownMenuItem(
              value: 'Clients',
              child: Row(
                children: [
                  Icon(Icons.business, color: iconColor, size: iconSize),
                  const SizedBox(width: 8),
                  Text('Clients'),
                ],
              ),
            ),
            DropdownMenuItem(
              value: 'Teams',
              child: Row(
                children: [
                  Icon(Icons.group, color: iconColor, size: iconSize),
                  const SizedBox(width: 8),
                  Text('Teams'),
                ],
              ),
            ),
            DropdownMenuItem(
              value: 'Catalog',
              child: Row(
                children: [
                  Icon(Icons.inventory_2_outlined, color: iconColor, size: iconSize),
                  const SizedBox(width: 8),
                  Text('Catalog'),
                ],
              ),
            ),
            DropdownMenuItem(
              value: 'AI Chat',
              child: Row(
                children: [
                  Icon(Icons.auto_awesome, color: iconColor, size: iconSize),
                  const SizedBox(width: 8),
                  Text('AI Chat'),
                ],
              ),
            ),
          ],
          onChanged: (String? newValue) {
            if (newValue != null) {
              onNavigate(newValue);
            }
          },
        ),
      ),
    );
  }
}
