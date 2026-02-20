import 'package:flutter/material.dart';
import 'package:nexa/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:nexa/features/brand/data/providers/brand_provider.dart';
import 'package:nexa/features/subscription/presentation/pages/subscription_paywall_page.dart';
import 'doc_design_picker.dart';

/// Return type for the export options bottom sheet.
class ExportOptions {
  final String format;
  final String reportType;
  final String templateDesign;

  const ExportOptions({
    required this.format,
    required this.reportType,
    this.templateDesign = 'classic',
  });
}

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
  String _selectedDesign = 'classic';

  // For now, Pro is always true (matches brand_customization_card.dart pattern).
  final bool _isPro = true;

  @override
  void initState() {
    super.initState();
    // Read initial design from BrandProvider if available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        final brandProvider = context.read<BrandProvider>();
        setState(() {
          _selectedDesign = brandProvider.preferredDocDesign;
        });
      } catch (_) {
        // BrandProvider not in tree — keep default
      }
    });
  }

  void _onDesignSelected(String design) {
    if (!_isPro && design != 'plain') {
      // Show paywall for non-Pro users
      Navigator.push<void>(
        context,
        MaterialPageRoute<void>(builder: (_) => const SubscriptionPaywallPage()),
      );
      return;
    }
    setState(() => _selectedDesign = design);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
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
                        color: const Color(0xFF212C4A).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.download,
                        color: Color(0xFF212C4A),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.exportReport,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            l10n.chooseFormatAndReportType,
                            style: const TextStyle(
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

              // Report type selection
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.reportType,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _ReportTypeOption(
                      icon: Icons.account_balance_wallet,
                      label: l10n.payrollReportLabel,
                      description: l10n.payrollReportDescription,
                      isSelected: _selectedReportType == 'payroll',
                      onTap: () => setState(() => _selectedReportType = 'payroll'),
                    ),
                    const SizedBox(height: 8),
                    _ReportTypeOption(
                      icon: Icons.access_time,
                      label: l10n.attendanceReportLabel,
                      description: l10n.attendanceReportDescription,
                      isSelected: _selectedReportType == 'attendance',
                      onTap: () => setState(() => _selectedReportType = 'attendance'),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Document Style section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.documentStyle,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    DocDesignPicker(
                      selected: _selectedDesign,
                      isPro: _isPro,
                      onSelected: _onDesignSelected,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Format selection
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.exportFormat,
                      style: const TextStyle(
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
                            label: l10n.csvLabel,
                            description: l10n.excelCompatible,
                            isSelected: _selectedFormat == 'csv',
                            onTap: () => setState(() => _selectedFormat = 'csv'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _FormatOption(
                            icon: Icons.picture_as_pdf,
                            label: l10n.pdfLabel,
                            description: l10n.printReady,
                            isSelected: _selectedFormat == 'pdf',
                            onTap: () => setState(() => _selectedFormat = 'pdf'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

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
                        _getPeriodLabel(l10n),
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
                          templateDesign: _selectedDesign,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF212C4A),
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
                          l10n.exportFormatButton(_selectedFormat.toUpperCase()),
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
      ),
    );
  }

  String _getPeriodLabel(AppLocalizations l10n) {
    switch (widget.period) {
      case 'week':
        return l10n.lastSevenDays;
      case 'month':
        return l10n.thisMonth;
      case 'year':
        return l10n.thisYear;
      case 'all':
        return l10n.allTime;
      case 'custom':
        if (widget.customDateRange != null) {
          final start = widget.customDateRange!.start;
          final end = widget.customDateRange!.end;
          return '${start.month}/${start.day}/${start.year} - ${end.month}/${end.day}/${end.year}';
        }
        return l10n.customRange;
      default:
        return l10n.thisMonth;
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
          color: isSelected ? const Color(0xFF212C4A).withOpacity(0.05) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF212C4A) : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 28,
              color: isSelected ? const Color(0xFF212C4A) : Colors.grey.shade600,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isSelected ? const Color(0xFF212C4A) : Colors.black87,
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
          color: isSelected ? const Color(0xFF212C4A).withOpacity(0.05) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF212C4A) : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF212C4A).withOpacity(0.1)
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: 20,
                color: isSelected ? const Color(0xFF212C4A) : Colors.grey.shade600,
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
                      color: isSelected ? const Color(0xFF212C4A) : Colors.black87,
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
                color: Color(0xFF212C4A),
                size: 22,
              ),
          ],
        ),
      ),
    );
  }
}
