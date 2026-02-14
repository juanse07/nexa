import 'dart:ui';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../../../shared/widgets/web_content_wrapper.dart';
import '../data/models/statistics_models.dart';
import '../data/services/statistics_service.dart';
import 'widgets/ai_analysis_sheet.dart';
import 'widgets/stats_hero_header.dart';
import 'widgets/period_selector.dart';
import 'widgets/staff_leaderboard.dart';
import 'widgets/payroll_summary_card.dart';

/// Statistics dashboard with team performance metrics and AI analysis
class StatisticsDashboardScreen extends StatefulWidget {
  const StatisticsDashboardScreen({super.key});

  @override
  State<StatisticsDashboardScreen> createState() => _StatisticsDashboardScreenState();
}

class _StatisticsDashboardScreenState extends State<StatisticsDashboardScreen> {
  bool _isLoading = true;
  bool _isAnalyzing = false;
  bool _fabExtended = true;

  String _selectedPeriod = 'month';
  DateTimeRange? _customDateRange;

  ManagerStatistics _statistics = ManagerStatistics.empty;
  PayrollReport _payrollReport = PayrollReport.empty;
  TopPerformersReport _topPerformers = TopPerformersReport.empty;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadData();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final extended = _scrollController.offset < 80;
    if (extended != _fabExtended) {
      setState(() => _fabExtended = extended);
    }
  }

  Future<void> _loadData() async {
    if (!mounted) return;

    setState(() => _isLoading = true);

    try {
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
    await _loadData();
  }

  void _onPeriodChanged(String period, DateTimeRange? customRange) {
    setState(() {
      _selectedPeriod = period;
      _customDateRange = customRange;
    });
    _loadData();
  }

  Future<void> _showAIAnalysis() async {
    setState(() => _isAnalyzing = true);

    final sheetController = showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      builder: (ctx) => AIAnalysisSheet(
        statistics: _statistics,
        payroll: _payrollReport,
        topPerformers: _topPerformers,
      ),
    );

    sheetController.whenComplete(() {
      if (mounted) setState(() => _isAnalyzing = false);
    });
  }

  Widget _buildValerioFab() {
    final icon = _isAnalyzing
        ? const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          )
        : ClipOval(
            child: Image.asset(
              'assets/ai_assistant_logo.png',
              width: 28,
              height: 28,
              fit: BoxFit.cover,
            ),
          );

    return Padding(
      padding: const EdgeInsets.only(bottom: 70, right: 4),
      child: GestureDetector(
        onTap: _isAnalyzing ? null : _showAIAnalysis,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              width: _fabExtended ? 168 : 52,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFF212C4A).withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.15),
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF212C4A).withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  icon,
                  Flexible(
                    child: AnimatedOpacity(
                      opacity: _fabExtended ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 150),
                      child: _fabExtended
                          ? Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: Text(
                                _isAnalyzing ? 'Analyzing...' : 'AI Analysis',
                                overflow: TextOverflow.clip,
                                maxLines: 1,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Stats'),
        backgroundColor: const Color(0xFF212C4A),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refresh,
              child: CustomScrollView(
                controller: _scrollController,
                slivers: [
                  SliverToBoxAdapter(
                    child: PeriodSelector(
                      selectedPeriod: _selectedPeriod,
                      customDateRange: _customDateRange,
                      onPeriodChanged: _onPeriodChanged,
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: StatsHeroHeader(
                      statistics: _statistics,
                      periodLabel: _statistics.period.label,
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: PayrollSummaryCard(
                      payrollReport: _payrollReport,
                      onViewDetails: () {
                        // TODO: Navigate to detailed payroll screen
                      },
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: StaffLeaderboard(
                      topPerformers: _topPerformers.topPerformers,
                      periodLabel: _topPerformers.period.label,
                    ),
                  ),
                  const SliverToBoxAdapter(
                    child: SizedBox(height: 80),
                  ),
                ],
              ),
            ),
      floatingActionButton: _isLoading ? null : _buildValerioFab(),
    );

    if (kIsWeb) {
      return WebContentWrapper(child: content);
    }
    return content;
  }
}
