import 'package:flutter/material.dart';
import 'package:nexa/l10n/app_localizations.dart';

/// Period selector widget with preset periods and custom date range
class PeriodSelector extends StatelessWidget {
  final String selectedPeriod;
  final DateTimeRange? customDateRange;
  final Function(String period, DateTimeRange? customRange) onPeriodChanged;

  const PeriodSelector({
    super.key,
    required this.selectedPeriod,
    this.customDateRange,
    required this.onPeriodChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _PeriodChip(
              label: l10n.week,
              isSelected: selectedPeriod == 'week',
              onTap: () => onPeriodChanged('week', null),
            ),
            const SizedBox(width: 8),
            _PeriodChip(
              label: l10n.month,
              isSelected: selectedPeriod == 'month',
              onTap: () => onPeriodChanged('month', null),
            ),
            const SizedBox(width: 8),
            _PeriodChip(
              label: l10n.year,
              isSelected: selectedPeriod == 'year',
              onTap: () => onPeriodChanged('year', null),
            ),
            const SizedBox(width: 8),
            _PeriodChip(
              label: l10n.allTime,
              isSelected: selectedPeriod == 'all',
              onTap: () => onPeriodChanged('all', null),
            ),
            const SizedBox(width: 8),
            _PeriodChip(
              label: customDateRange != null
                  ? _formatDateRange(customDateRange!)
                  : l10n.custom,
              isSelected: selectedPeriod == 'custom',
              icon: Icons.date_range,
              onTap: () => _showDatePicker(context),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateRange(DateTimeRange range) {
    final start = '${range.start.month}/${range.start.day}';
    final end = '${range.end.month}/${range.end.day}';
    return '$start - $end';
  }

  Future<void> _showDatePicker(BuildContext context) async {
    final now = DateTime.now();
    final result = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now,
      initialDateRange: customDateRange ??
          DateTimeRange(
            start: now.subtract(const Duration(days: 30)),
            end: now,
          ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF212C4A),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );

    if (result != null) {
      onPeriodChanged('custom', result);
    }
  }
}

class _PeriodChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final IconData? icon;
  final VoidCallback onTap;

  const _PeriodChip({
    required this.label,
    required this.isSelected,
    this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF212C4A) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF212C4A) : Colors.grey.shade300,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF212C4A).withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 16,
                color: isSelected ? Colors.white : Colors.grey.shade600,
              ),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey.shade700,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
