import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../../../../../shared/ui/widgets.dart';
import '../../theme/extraction_theme.dart';

/// Staff catalog tab widget
class StaffTabWidget extends StatelessWidget {
  final List<Map<String, dynamic>>? staff;
  final bool isLoading;
  final String? error;
  final Future<void> Function() onRefresh;
  final Widget Function(Map<String, dynamic>) buildStaffTile;
  final VoidCallback? onWebRefresh;

  const StaffTabWidget({
    super.key,
    required this.staff,
    required this.isLoading,
    this.error,
    required this.onRefresh,
    required this.buildStaffTile,
    this.onWebRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final items = staff ?? const [];

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: ExColors.techBlue,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(
          top: 36,
          left: 20,
          right: 20,
          bottom: 20,
        ),
        children: [
          // Web refresh button
          if (kIsWeb && onWebRefresh != null)
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 4),
                child: ElevatedButton.icon(
                  onPressed: onWebRefresh,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Refresh staff'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ExColors.techBlue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ),

          // Loading state
          if (isLoading && items.isEmpty)
            const Center(child: LoadingIndicator(text: 'Loading staff...')),

          // Error state
          if (error != null) ...[
            ErrorBanner(message: error!),
            const SizedBox(height: 12),
          ],

          // Empty state
          if (!isLoading && items.isEmpty && error == null)
            EmptyStateWidget(
              icon: Icons.people_outline,
              title: 'No staff members yet',
              subtitle: 'Invite team members to get started',
              iconColor: Colors.grey.shade400,
            ),

          // Staff list
          ...items.map(buildStaffTile),
        ],
      ),
    );
  }
}
