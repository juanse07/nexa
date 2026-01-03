import 'package:flutter/material.dart';
import '../statistics_dashboard_screen.dart';

/// Bottom sheet for selecting export options
class ExportOptionsSheet extends StatefulWidget {
  final String period;
  final DateTimeRange? customDateRange;

  const ExportOptionsSheet({
    super.key,
    required this.period,
    this.customDateRange,
  });

  @override
  State<ExportOptionsSheet> createState() => _ExportOptionsSheetState();
}

class _ExportOptionsSheetState extends State<ExportOptionsSheet> {
  String _selectedFormat = 'csv';
  String _selectedReportType = 'payroll';

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.download,
                      color: Color(0xFF6366F1),
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Export Report',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Choose format and report type',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Format selection
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Export Format',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _FormatOption(
                          icon: Icons.table_chart,
                          label: 'CSV',
                          description: 'Excel compatible',
                          isSelected: _selectedFormat == 'csv',
                          onTap: () => setState(() => _selectedFormat = 'csv'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _FormatOption(
                          icon: Icons.picture_as_pdf,
                          label: 'PDF',
                          description: 'Print ready',
                          isSelected: _selectedFormat == 'pdf',
                          onTap: () => setState(() => _selectedFormat = 'pdf'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Report type selection
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Report Type',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _ReportTypeOption(
                    icon: Icons.account_balance_wallet,
                    label: 'Payroll Report',
                    description: 'Staff earnings breakdown by hours and pay rate',
                    isSelected: _selectedReportType == 'payroll',
                    onTap: () => setState(() => _selectedReportType = 'payroll'),
                  ),
                  const SizedBox(height: 8),
                  _ReportTypeOption(
                    icon: Icons.access_time,
                    label: 'Attendance Report',
                    description: 'Clock-in/out times and hours worked',
                    isSelected: _selectedReportType == 'attendance',
                    onTap: () => setState(() => _selectedReportType = 'attendance'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Period info
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.date_range, size: 18, color: Colors.grey.shade600),
                    const SizedBox(width: 8),
                    Text(
                      _getPeriodLabel(),
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Export button
            Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(
                      context,
                      ExportOptions(
                        format: _selectedFormat,
                        reportType: _selectedReportType,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _selectedFormat == 'csv' ? Icons.table_chart : Icons.picture_as_pdf,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Export ${_selectedFormat.toUpperCase()}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getPeriodLabel() {
    switch (widget.period) {
      case 'week':
        return 'Last 7 days';
      case 'month':
        return 'This month';
      case 'year':
        return 'This year';
      case 'all':
        return 'All time';
      case 'custom':
        if (widget.customDateRange != null) {
          final start = widget.customDateRange!.start;
          final end = widget.customDateRange!.end;
          return '${start.month}/${start.day}/${start.year} - ${end.month}/${end.day}/${end.year}';
        }
        return 'Custom range';
      default:
        return 'This month';
    }
  }
}

class _FormatOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final String description;
  final bool isSelected;
  final VoidCallback onTap;

  const _FormatOption({
    required this.icon,
    required this.label,
    required this.description,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF6366F1).withOpacity(0.05) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF6366F1) : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 28,
              color: isSelected ? const Color(0xFF6366F1) : Colors.grey.shade600,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isSelected ? const Color(0xFF6366F1) : Colors.black87,
              ),
            ),
            Text(
              description,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportTypeOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final String description;
  final bool isSelected;
  final VoidCallback onTap;

  const _ReportTypeOption({
    required this.icon,
    required this.label,
    required this.description,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF6366F1).withOpacity(0.05) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF6366F1) : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF6366F1).withOpacity(0.1)
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: 20,
                color: isSelected ? const Color(0xFF6366F1) : Colors.grey.shade600,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isSelected ? const Color(0xFF6366F1) : Colors.black87,
                    ),
                  ),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle,
                color: Color(0xFF6366F1),
                size: 22,
              ),
          ],
        ),
      ),
    );
  }
}
