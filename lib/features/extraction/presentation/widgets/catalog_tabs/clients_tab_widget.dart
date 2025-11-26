import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../../../../../shared/ui/widgets.dart';
import '../../theme/extraction_theme.dart';

/// Clients catalog tab widget
class ClientsTabWidget extends StatelessWidget {
  final List<Map<String, dynamic>>? clients;
  final bool isLoading;
  final String? error;
  final Future<void> Function() onRefresh;
  final Widget Function(Map<String, dynamic>) buildClientTile;
  final VoidCallback? onWebRefresh;

  const ClientsTabWidget({
    super.key,
    required this.clients,
    required this.isLoading,
    this.error,
    required this.onRefresh,
    required this.buildClientTile,
    this.onWebRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final items = clients ?? const [];

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
                  label: const Text('Refresh clients'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ExColors.techBlue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ),

          // Loading state
          if (isLoading && items.isEmpty)
            const Center(child: LoadingIndicator(text: 'Loading clients...')),

          // Error state
          if (error != null) ...[
            ErrorBanner(message: error!),
            const SizedBox(height: 12),
          ],

          // Empty state
          if (!isLoading && items.isEmpty && error == null)
            EmptyStateWidget(
              icon: Icons.business_outlined,
              title: 'No clients yet',
              subtitle: 'Add your first client to get started',
              iconColor: Colors.grey.shade400,
            ),

          // Client list
          ...items.map(buildClientTile),
        ],
      ),
    );
  }
}
