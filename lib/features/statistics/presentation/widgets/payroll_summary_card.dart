import 'package:flutter/material.dart';
import '../../data/models/statistics_models.dart';

/// Payroll summary card with staff breakdown
class PayrollSummaryCard extends StatelessWidget {
  final PayrollReport payrollReport;
  final VoidCallback? onViewDetails;

  const PayrollSummaryCard({
    super.key,
    required this.payrollReport,
    this.onViewDetails,
  });

  @override
  Widget build(BuildContext context) {
    final summary = payrollReport.summary;
    final topEntries = payrollReport.entries.take(3).toList();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet,
                    color: Color(0xFF22C55E),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Payroll Summary',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        '${summary.staffCount} staff members',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onViewDetails != null)
                  TextButton(
                    onPressed: onViewDetails,
                    child: const Text(
                      'View All',
                      style: TextStyle(
                        color: Color(0xFF6366F1),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Summary stats row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: _StatItem(
                    label: 'Total Hours',
                    value: '${summary.totalHours.toStringAsFixed(0)}h',
                    icon: Icons.schedule,
                    color: const Color(0xFF3B82F6),
                  ),
                ),
                Container(
                  height: 40,
                  width: 1,
                  color: Colors.grey.shade200,
                ),
                Expanded(
                  child: _StatItem(
                    label: 'Total Payroll',
                    value: '\$${_formatNumber(summary.totalPayroll)}',
                    icon: Icons.attach_money,
                    color: const Color(0xFF22C55E),
                  ),
                ),
                Container(
                  height: 40,
                  width: 1,
                  color: Colors.grey.shade200,
                ),
                Expanded(
                  child: _StatItem(
                    label: 'Avg/Staff',
                    value: '\$${_formatNumber(summary.averagePerStaff)}',
                    icon: Icons.person,
                    color: const Color(0xFF8B5CF6),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),
          const Divider(height: 1),

          // Top earners preview
          if (topEntries.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Top Earners',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
            ),
            ...topEntries.asMap().entries.map((entry) {
              final index = entry.key;
              final payroll = entry.value;
              return _PayrollEntryTile(
                entry: payroll,
                isLast: index == topEntries.length - 1,
              );
            }),
          ] else
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'No payroll data for this period',
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _formatNumber(double value) {
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    }
    return value.toStringAsFixed(0);
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Colors.grey.shade800,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }
}

class _PayrollEntryTile extends StatelessWidget {
  final PayrollEntry entry;
  final bool isLast;

  const _PayrollEntryTile({
    required this.entry,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(
                bottom: BorderSide(color: Colors.grey.shade100),
              ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: Colors.grey.shade200,
            backgroundImage: entry.picture.isNotEmpty
                ? NetworkImage(entry.picture)
                : null,
            child: entry.picture.isEmpty
                ? Text(
                    entry.name.isNotEmpty ? entry.name[0].toUpperCase() : '?',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                      fontSize: 14,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
                Text(
                  '${entry.shifts} shifts • ${entry.hours.toStringAsFixed(0)}h',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '\$${entry.earnings.toStringAsFixed(0)}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: Color(0xFF22C55E),
            ),
          ),
        ],
      ),
    );
  }
}
