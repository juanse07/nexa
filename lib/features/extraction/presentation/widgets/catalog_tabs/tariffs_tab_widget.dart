import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../../../../../shared/ui/widgets.dart';
import '../../theme/extraction_theme.dart';

/// Tariffs catalog tab widget
class TariffsTabWidget extends StatelessWidget {
  final List<Map<String, dynamic>>? tariffs;
  final bool isLoading;
  final String? error;
  final Future<void> Function() onRefresh;
  final Widget Function(Map<String, dynamic>) buildTariffTile;
  final VoidCallback? onWebRefresh;

  const TariffsTabWidget({
    super.key,
    required this.tariffs,
    required this.isLoading,
    this.error,
    required this.onRefresh,
    required this.buildTariffTile,
    this.onWebRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final items = tariffs ?? const [];

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
                  label: const Text('Refresh tariffs'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ExColors.techBlue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ),

          // Loading state
          if (isLoading && items.isEmpty)
            const Center(child: LoadingIndicator(text: 'Loading tariffs...')),

          // Error state
          if (error != null) ...[
            ErrorBanner(message: error!),
            const SizedBox(height: 12),
          ],

          // Empty state
          if (!isLoading && items.isEmpty && error == null)
            EmptyStateWidget(
              icon: Icons.attach_money,
              title: 'No tariffs yet',
              subtitle: 'Add your first tariff to get started',
              iconColor: Colors.grey.shade400,
            ),

          // Tariffs list
          ...items.map(buildTariffTile),
        ],
      ),
    );
  }
}
