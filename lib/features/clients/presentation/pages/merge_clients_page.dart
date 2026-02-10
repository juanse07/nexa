import 'package:flutter/material.dart';
import 'package:nexa/features/extraction/services/clients_service.dart';
import 'package:nexa/features/extraction/presentation/theme/extraction_theme.dart';

/// Page for finding and merging duplicate clients.
///
/// Flow:
///  1. Fetches duplicate groups from the backend (by name similarity).
///  2. For each group the user picks a "primary" (keep) client.
///  3. Remaining clients in the group are merged into the primary.
class MergeClientsPage extends StatefulWidget {
  const MergeClientsPage({super.key});

  @override
  State<MergeClientsPage> createState() => _MergeClientsPageState();
}

class _MergeClientsPageState extends State<MergeClientsPage> {
  final ClientsService _clientsService = ClientsService();

  bool _loading = true;
  String? _error;
  List<_DuplicateGroup> _groups = [];
  double _threshold = 0.6;
  bool _merging = false;

  @override
  void initState() {
    super.initState();
    _loadDuplicates();
  }

  Future<void> _loadDuplicates() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final raw = await _clientsService.fetchDuplicates(threshold: _threshold);
      final groups = raw.map((g) {
        final clients = (g['clients'] as List?)
                ?.whereType<Map<String, dynamic>>()
                .map((c) => _ClientItem(
                      id: (c['id'] ?? '').toString(),
                      name: (c['name'] ?? '').toString(),
                    ))
                .toList() ??
            [];
        final similarity = (g['similarity'] as num?)?.toDouble() ?? 0;
        return _DuplicateGroup(
          clients: clients,
          similarity: similarity,
          // Default: first client (alphabetically first) is the primary
          primaryId: clients.isNotEmpty ? clients.first.id : '',
        );
      }).toList();

      setState(() {
        _groups = groups;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _mergeGroup(_DuplicateGroup group) async {
    final duplicates =
        group.clients.where((c) => c.id != group.primaryId).toList();
    if (duplicates.isEmpty) return;

    final primaryName =
        group.clients.firstWhere((c) => c.id == group.primaryId).name;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Merge'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Keep: "$primaryName"',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(
              'Merge & delete ${duplicates.length} duplicate(s):',
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 4),
            ...duplicates.map((d) => Padding(
                  padding: const EdgeInsets.only(left: 12, top: 2),
                  child: Text('- ${d.name}',
                      style: const TextStyle(color: ExColors.errorDark)),
                )),
            const SizedBox(height: 12),
            Text(
              'All events and tariffs will be transferred to "$primaryName".',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: ExColors.techBlue,
              foregroundColor: Colors.white,
            ),
            child: const Text('Merge'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _merging = true);

    int merged = 0;
    for (final dup in duplicates) {
      try {
        await _clientsService.mergeClients(
          sourceClientId: dup.id,
          targetClientId: group.primaryId,
        );
        merged++;
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to merge "${dup.name}": $e'),
            backgroundColor: ExColors.errorDark,
          ),
        );
      }
    }

    if (!mounted) return;
    setState(() => _merging = false);

    if (merged > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Merged $merged client(s) into "$primaryName"'),
          backgroundColor: ExColors.successDark,
        ),
      );
      await _loadDuplicates();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ExColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Merge Duplicate Clients'),
        backgroundColor: ExColors.techBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _loading ? null : _loadDuplicates,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _merging
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Merging clients...'),
                ],
              ),
            )
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: ExColors.error),
              const SizedBox(height: 16),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadDuplicates,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ExColors.techBlue,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // Sensitivity slider
        _buildThresholdSlider(),
        const Divider(height: 1),
        // Groups list
        Expanded(
          child: _groups.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _groups.length,
                  itemBuilder: (context, index) =>
                      _buildGroupCard(_groups[index], index),
                ),
        ),
      ],
    );
  }

  Widget _buildThresholdSlider() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          const Icon(Icons.tune, size: 20, color: ExColors.textSecondary),
          const SizedBox(width: 8),
          Text(
            'Sensitivity: ${(_threshold * 100).round()}%',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: ExColors.textPrimary,
            ),
          ),
          Expanded(
            child: Slider(
              value: _threshold,
              min: 0.3,
              max: 0.95,
              divisions: 13,
              activeColor: ExColors.techBlue,
              onChanged: (v) => setState(() => _threshold = v),
              onChangeEnd: (_) => _loadDuplicates(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_outline,
              size: 64, color: Colors.green.shade300),
          const SizedBox(height: 16),
          const Text(
            'No duplicates found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: ExColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try lowering the sensitivity to find looser matches.',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupCard(_DuplicateGroup group, int index) {
    final simPercent = (group.similarity * 100).round();
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: ExColors.techBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Group ${index + 1}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: ExColors.techBlue,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _simColor(group.similarity).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$simPercent% similar',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: _simColor(group.similarity),
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  '${group.clients.length} clients',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Instruction
            Text(
              'Tap a client to set it as primary (kept):',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),

            // Client list
            ...group.clients.map((client) {
              final isPrimary = client.id == group.primaryId;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    group.primaryId = client.id;
                  });
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: isPrimary
                        ? ExColors.successDark.withValues(alpha: 0.08)
                        : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isPrimary
                          ? ExColors.successDark.withValues(alpha: 0.4)
                          : Colors.grey.shade200,
                      width: isPrimary ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isPrimary
                            ? Icons.star_rounded
                            : Icons.radio_button_unchecked,
                        color: isPrimary
                            ? ExColors.successDark
                            : Colors.grey.shade400,
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          client.name,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight:
                                isPrimary ? FontWeight.w600 : FontWeight.w400,
                            color: isPrimary
                                ? ExColors.textPrimary
                                : Colors.grey.shade700,
                          ),
                        ),
                      ),
                      if (isPrimary)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: ExColors.successDark,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'KEEP',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        )
                      else
                        Text(
                          'will be merged',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade400,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }),

            const SizedBox(height: 12),

            // Merge button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _mergeGroup(group),
                icon: const Icon(Icons.merge_type, size: 20),
                label: Text(
                  'Merge ${group.clients.length - 1} into "${group.clients.firstWhere((c) => c.id == group.primaryId).name}"',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ExColors.techBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _simColor(double similarity) {
    if (similarity >= 0.9) return ExColors.errorDark;
    if (similarity >= 0.75) return ExColors.warning;
    return ExColors.techBlue;
  }
}

// ─── Local models ──────────────────────────────────────────────────────────────

class _ClientItem {
  final String id;
  final String name;
  const _ClientItem({required this.id, required this.name});
}

class _DuplicateGroup {
  final List<_ClientItem> clients;
  final double similarity;
  String primaryId;

  _DuplicateGroup({
    required this.clients,
    required this.similarity,
    required this.primaryId,
  });
}
