import 'package:flutter/material.dart';

/// Web-friendly tab navigation widget that replaces TabBar on web platforms
/// Provides a horizontal button-style navigation that works better with mouse interactions
class WebTabNavigation extends StatelessWidget {
  final List<WebTab> tabs;
  final int selectedIndex;
  final ValueChanged<int> onTabSelected;
  final Color? backgroundColor;
  final Color? selectedColor;
  final Color? unselectedColor;

  const WebTabNavigation({
    required this.tabs,
    required this.selectedIndex,
    required this.onTabSelected,
    this.backgroundColor,
    this.selectedColor,
    this.unselectedColor,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveSelectedColor = selectedColor ?? theme.primaryColor;
    final effectiveUnselectedColor = unselectedColor ?? theme.colorScheme.onSurface.withOpacity(0.7);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.white,
        border: Border(
          bottom: BorderSide(
            color: theme.dividerColor.withOpacity(0.2),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          ...List.generate(tabs.length, (index) {
            final tab = tabs[index];
            final isSelected = index == selectedIndex;

            return Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => onTabSelected(index),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? effectiveSelectedColor.withOpacity(0.12)
                          : Colors.grey.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? effectiveSelectedColor
                            : Colors.grey.withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (tab.icon != null) ...[
                          Icon(
                            tab.icon,
                            size: 22,
                            color: isSelected
                                ? effectiveSelectedColor
                                : effectiveUnselectedColor,
                          ),
                          const SizedBox(width: 10),
                        ],
                        Text(
                          tab.text,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                            color: isSelected
                                ? effectiveSelectedColor
                                : effectiveUnselectedColor,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

/// Data class for web tab items
class WebTab {
  final String text;
  final IconData? icon;

  const WebTab({
    required this.text,
    this.icon,
  });
}

