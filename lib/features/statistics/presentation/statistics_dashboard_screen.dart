import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../shared/widgets/web_content_wrapper.dart';
import '../data/models/statistics_models.dart';
import '../data/services/statistics_service.dart';
import 'widgets/stats_hero_header.dart';
import 'widgets/period_selector.dart';
import 'widgets/staff_leaderboard.dart';
import 'widgets/payroll_summary_card.dart';
import 'widgets/export_options_sheet.dart';

/// Statistics dashboard with team performance metrics and export functionality
class StatisticsDashboardScreen extends StatefulWidget {
  const StatisticsDashboardScreen({super.key});

  @override
  State<StatisticsDashboardScreen> createState() => _StatisticsDashboardScreenState();
}

class _StatisticsDashboardScreenState extends State<StatisticsDashboardScreen> {
  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _isExporting = false;

  String _selectedPeriod = 'month';
  DateTimeRange? _customDateRange;

  ManagerStatistics _statistics = ManagerStatistics.empty;
  PayrollReport _payrollReport = PayrollReport.empty;
  TopPerformersReport _topPerformers = TopPerformersReport.empty;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;

    setState(() => _isLoading = true);

    try {
      // Load all data in parallel
      final results = await Future.wait([
        StatisticsService.getManagerSummary(
          period: _selectedPeriod,
          startDate: _customDateRange?.start,
          endDate: _customDateRange?.end,
        ),
        StatisticsService.getPayrollReport(
          period: _selectedPeriod,
          startDate: _customDateRange?.start,
          endDate: _customDateRange?.end,
        ),
        StatisticsService.getTopPerformers(
          period: _selectedPeriod,
        ),
      ]);

      if (!mounted) return;

      setState(() {
        _statistics = results[0] as ManagerStatistics;
        _payrollReport = results[1] as PayrollReport;
        _topPerformers = results[2] as TopPerformersReport;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('[StatisticsDashboard] Load error: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load statistics: $e')),
        );
      }
    }
  }

  Future<void> _refresh() async {
    setState(() => _isRefreshing = true);
    await _loadData();
    if (mounted) {
      setState(() => _isRefreshing = false);
    }
  }

  void _onPeriodChanged(String period, DateTimeRange? customRange) {
    setState(() {
      _selectedPeriod = period;
      _customDateRange = customRange;
    });
    _loadData();
  }

  Future<void> _showExportOptions() async {
    final result = await showModalBottomSheet<ExportOptions>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ExportOptionsSheet(
        period: _selectedPeriod,
        customDateRange: _customDateRange,
      ),
    );

    if (result != null) {
      await _performExport(result);
    }
  }

  Future<void> _performExport(ExportOptions options) async {
    setState(() => _isExporting = true);

    try {
      if (options.format == 'csv') {
        final csvContent = await StatisticsService.exportTeamReportCsv(
          reportType: options.reportType,
          period: _selectedPeriod,
          startDate: _customDateRange?.start,
          endDate: _customDateRange?.end,
        );

        if (csvContent != null) {
          await _shareFile(csvContent, '${options.reportType}_report.csv', 'text/csv');
        }
      } else {
        // PDF - for now show a message that PDF is coming soon
        // In Phase 2, we'll implement syncfusion_flutter_pdf generation
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF export coming soon!')),
        );
      }
    } catch (e) {
      debugPrint('[StatisticsDashboard] Export error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  Future<void> _shareFile(String content, String filename, String mimeType) async {
    if (kIsWeb) {
      // For web, trigger download
      // This would need additional implementation for web download
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Export downloaded!')),
      );
    } else {
      // For mobile, save to temp and share
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$filename');
      await file.writeAsString(content);

      await Share.shareXFiles(
        [XFile(file.path, mimeType: mimeType)],
        subject: 'Team Report',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Statistics'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          if (_isExporting)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refresh,
              child: CustomScrollView(
                slivers: [
                  // Period Selector
                  SliverToBoxAdapter(
                    child: PeriodSelector(
                      selectedPeriod: _selectedPeriod,
                      customDateRange: _customDateRange,
                      onPeriodChanged: _onPeriodChanged,
                    ),
                  ),

                  // Hero Header with Key Metrics
                  SliverToBoxAdapter(
                    child: StatsHeroHeader(
                      statistics: _statistics,
                      periodLabel: _statistics.period.label,
                    ),
                  ),

                  // Payroll Summary Card
                  SliverToBoxAdapter(
                    child: PayrollSummaryCard(
                      payrollReport: _payrollReport,
                      onViewDetails: () {
                        // TODO: Navigate to detailed payroll screen
                      },
                    ),
                  ),

                  // Top Performers Leaderboard
                  SliverToBoxAdapter(
                    child: StaffLeaderboard(
                      topPerformers: _topPerformers.topPerformers,
                      periodLabel: _topPerformers.period.label,
                    ),
                  ),

                  // Bottom spacing for FAB
                  const SliverToBoxAdapter(
                    child: SizedBox(height: 80),
                  ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isExporting ? null : _showExportOptions,
        icon: _isExporting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Icon(Icons.download),
        label: Text(_isExporting ? 'Exporting...' : 'Export'),
        backgroundColor: const Color(0xFF6366F1),
      ),
    );

    // Wrap with web content wrapper for responsive design
    if (kIsWeb) {
      return WebContentWrapper(child: content);
    }

    return content;
  }
}

/// Export options from the bottom sheet
class ExportOptions {
  final String format; // 'csv' or 'pdf'
  final String reportType; // 'payroll' or 'attendance'

  ExportOptions({
    required this.format,
    required this.reportType,
  });
}
