import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nexa/l10n/app_localizations.dart';
import 'package:nexa/shared/presentation/theme/app_colors.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:nexa/features/payroll/data/services/payroll_export_service.dart';
import 'package:nexa/features/payroll/presentation/employee_mapping_screen.dart';

class PayrollExportScreen extends StatefulWidget {
  const PayrollExportScreen({super.key});

  @override
  State<PayrollExportScreen> createState() => _PayrollExportScreenState();
}

class _PayrollExportScreenState extends State<PayrollExportScreen> {
  final _service = PayrollExportService();

  // Period selection
  late DateTime _startDate;
  late DateTime _endDate;

  // State
  bool _isLoading = false;
  bool _isExporting = false;
  String? _error;
  PayrollPreview? _preview;
  PayrollConfig? _config;
  PayrollFormat _selectedFormat = PayrollFormat.generic;

  @override
  void initState() {
    super.initState();
    // Default to current month
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, 1);
    _endDate = DateTime(now.year, now.month + 1, 0);
    _loadData();
  }

  String _fmt(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  Future<void> _loadData() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final results = await Future.wait([
        _service.getPayrollConfig(),
        _service.fetchPreview(startDate: _fmt(_startDate), endDate: _fmt(_endDate)),
      ]);
      final config = results[0] as PayrollConfig;
      final preview = results[1] as PayrollPreview;

      // Auto-select format from provider config
      final format = switch (config.provider) {
        'adp' => PayrollFormat.adp,
        'paychex' => PayrollFormat.paychex,
        _ => PayrollFormat.generic,
      };

      setState(() {
        _config = config;
        _preview = preview;
        _selectedFormat = format;
        _isLoading = false;
      });
    } catch (e) {
      setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  Future<void> _loadPreview() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final preview = await _service.fetchPreview(
        startDate: _fmt(_startDate),
        endDate: _fmt(_endDate),
      );
      setState(() { _preview = preview; _isLoading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primaryPurple,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _loadPreview();
    }
  }

  Future<void> _exportCsv() async {
    setState(() => _isExporting = true);
    try {
      final result = await _service.exportCsv(
        startDate: _fmt(_startDate),
        endDate: _fmt(_endDate),
        format: _selectedFormat,
        companyCode: _config?.companyCode,
      );

      if (!mounted) return;

      // Inform about unmapped staff but don't block the export
      if (result.unmappedStaff.isNotEmpty && _selectedFormat != PayrollFormat.generic) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${result.unmappedStaff.length} staff exported with name as ID (not mapped)',
            ),
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Map',
              onPressed: _navigateToMappings,
            ),
          ),
        );
      }
      _openDownloadUrl(result.url);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  void _navigateToMappings() async {
    await Navigator.push(context,
      MaterialPageRoute<void>(builder: (_) => const EmployeeMappingScreen()));
    // Reload data when returning from mapping screen
    _loadData();
  }

  Future<void> _openDownloadUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open download link')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: AppBar(
        title: Text(l10n.payrollReportLabel),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.navySpaceCadet,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.navySpaceCadet),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          TextButton.icon(
            onPressed: _navigateToMappings,
            icon: const Icon(Icons.people_outline, size: 20),
            label: const Text('Mappings'),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : _buildContent(l10n),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(_error!, textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: _loadData, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(AppLocalizations l10n) {
    final preview = _preview;
    final config = _config;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // First-time setup card
          if (config != null && !config.isConfigured)
            _buildSetupCard(),
          if (config != null && !config.isConfigured)
            const SizedBox(height: 16),

          // Period selector
          _buildPeriodCard(),
          const SizedBox(height: 16),

          // Summary cards
          if (preview != null) ...[
            _buildSummaryRow(preview.summary, l10n),

            // OT stats row (only when overtime exists)
            if (preview.overtimeStats != null && preview.overtimeStats!.hasOvertime) ...[
              const SizedBox(height: 12),
              _buildOvertimeRow(preview.overtimeStats!),
            ],
            const SizedBox(height: 16),

            // Unapproved hours warning
            if (preview.unapprovedStaffShifts.isNotEmpty)
              _buildUnapprovedWarning(preview.unapprovedStaffShifts),
            if (preview.unapprovedStaffShifts.isNotEmpty)
              const SizedBox(height: 16),

            // Mapping status
            if (preview.mappingStats.unmapped > 0)
              _buildMappingWarning(preview.mappingStats),
            if (preview.mappingStats.unmapped > 0)
              const SizedBox(height: 16),

            // Format selection
            _buildFormatSelector(),
            const SizedBox(height: 16),

            // Staff list
            _buildStaffList(preview.entries),
            const SizedBox(height: 24),

            // Export button
            _buildExportButton(l10n),
            const SizedBox(height: 32),
          ],

          if (preview != null && preview.entries.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 48),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey[300]),
                    const SizedBox(height: 16),
                    Text(l10n.noPayrollDataForPeriod,
                        style: TextStyle(fontSize: 16, color: Colors.grey[500])),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSetupCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceBlue,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.secondaryPurple.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.secondaryPurple.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.settings_outlined, color: AppColors.secondaryPurple, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Set Up Payroll Provider',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                        color: AppColors.navySpaceCadet)),
                const SizedBox(height: 2),
                Text('Select your payroll system and map your staff for CSV export',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: _navigateToMappings,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.secondaryPurple,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              minimumSize: Size.zero,
            ),
            child: const Text('Set Up', style: TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodCard() {
    return GestureDetector(
      onTap: _pickDateRange,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surfaceBlue,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.calendar_month, color: AppColors.secondaryPurple, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Pay Period',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  const SizedBox(height: 2),
                  Text(
                    '${DateFormat.MMMd().format(_startDate)} - ${DateFormat.MMMd().format(_endDate)}',
                    style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600,
                      color: AppColors.navySpaceCadet,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(PayrollSummary summary, AppLocalizations l10n) {
    return Row(
      children: [
        Expanded(child: _summaryCard(
          l10n.totalPayroll,
          '\$${summary.totalPayroll.toStringAsFixed(2)}',
          Icons.payments_outlined,
          AppColors.success,
        )),
        const SizedBox(width: 12),
        Expanded(child: _summaryCard(
          'Total Hours',
          summary.totalHours.toStringAsFixed(1),
          Icons.schedule,
          AppColors.secondaryPurple,
        )),
        const SizedBox(width: 12),
        Expanded(child: _summaryCard(
          'Staff',
          '${summary.staffCount}',
          Icons.people_outline,
          AppColors.tealInfo,
        )),
      ],
    );
  }

  Widget _summaryCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(value,
            style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.w700, color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(label,
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildOvertimeRow(OvertimeStats stats) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFED7AA)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFFED7AA).withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.timer_outlined, color: Color(0xFFD97706), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Overtime Detected',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                        color: Color(0xFF92400E))),
                Text(
                  '${stats.staffWithOT} staff · ${stats.totalOTHours.toStringAsFixed(1)} OT hours',
                  style: const TextStyle(fontSize: 12, color: Color(0xFFB45309)),
                ),
              ],
            ),
          ),
          Text(
            '\$${stats.totalOTEarnings.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFFD97706),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMappingWarning(MappingStats stats) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFED7AA)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${stats.unmapped} of ${stats.totalStaff} staff not mapped to payroll provider',
              style: const TextStyle(fontSize: 13, color: Color(0xFF92400E)),
            ),
          ),
          TextButton(
            onPressed: _navigateToMappings,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: Size.zero,
            ),
            child: const Text('Map', style: TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _buildUnapprovedWarning(List<UnapprovedShiftWarning> warnings) {
    // Count unique staff members
    final uniqueStaff = warnings.map((w) => w.userKey).toSet();
    // Count unique events
    final uniqueEvents = warnings.map((w) => w.eventName).toSet();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        children: [
          const Icon(Icons.schedule_outlined, color: Color(0xFFDC2626), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${uniqueStaff.length} staff across ${uniqueEvents.length} events have unapproved hours',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF991B1B),
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Excluded from export. Review hours before exporting.',
                  style: TextStyle(fontSize: 12, color: Color(0xFFB91C1C)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormatSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Export Format',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                      color: AppColors.navySpaceCadet)),
              if (_config != null && _config!.isConfigured) ...[
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.secondaryPurple.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Auto: ${_config!.providerLabel}',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                        color: AppColors.secondaryPurple),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          _formatOption(
            PayrollFormat.generic,
            'Generic CSV',
            'Human-readable, works with any system',
            Icons.table_chart_outlined,
          ),
          _formatOption(
            PayrollFormat.adp,
            'ADP Workforce Now',
            'PRcccEPI import format',
            Icons.business,
          ),
          _formatOption(
            PayrollFormat.paychex,
            'Paychex Flex',
            'Paychex import CSV format',
            Icons.account_balance_outlined,
          ),
        ],
      ),
    );
  }

  Widget _formatOption(PayrollFormat format, String title, String subtitle, IconData icon) {
    final isSelected = _selectedFormat == format;
    return GestureDetector(
      onTap: () => setState(() => _selectedFormat = format),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.secondaryPurple.withValues(alpha: 0.06)
              : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.secondaryPurple : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20,
                color: isSelected ? AppColors.secondaryPurple : Colors.grey[500]),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600,
                    color: isSelected ? AppColors.secondaryPurple : AppColors.navySpaceCadet,
                  )),
                  Text(subtitle, style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary,
                  )),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: AppColors.secondaryPurple, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildStaffList(List<PayrollEntry> entries) {
    if (entries.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Text('Staff Breakdown (${entries.length})',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                    color: AppColors.navySpaceCadet)),
          ),
          ...entries.take(20).map((e) => _staffTile(e)),
          if (entries.length > 20)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Center(
                child: Text('+ ${entries.length - 20} more',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _staffTile(PayrollEntry entry) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.borderLight)),
      ),
      child: Row(
        children: [
          // Mapping indicator
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: entry.isMapped ? AppColors.success : AppColors.warning,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(entry.name,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis),
                    ),
                    if (entry.hasOvertime) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFED7AA),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'OT ${entry.otHours.toStringAsFixed(1)}h',
                          style: const TextStyle(
                            fontSize: 10, fontWeight: FontWeight.w700,
                            color: Color(0xFF92400E),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  '${entry.roles.join(", ")} · ${entry.shifts} shifts · ${entry.hours}h',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          Text(
            '\$${entry.earnings.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.success,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExportButton(AppLocalizations l10n) {
    return SizedBox(
      height: 52,
      child: FilledButton.icon(
        onPressed: _isExporting ? null : _exportCsv,
        icon: _isExporting
            ? const SizedBox(width: 18, height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.file_download_outlined),
        label: Text(_isExporting ? 'Exporting...' : l10n.exportReport,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primaryPurple,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }
}
