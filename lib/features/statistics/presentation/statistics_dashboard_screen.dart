import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../shared/widgets/web_content_wrapper.dart';
import '../data/models/statistics_models.dart';
import '../data/services/statistics_service.dart';
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
  bool _isRefreshing = false;
  bool _isAnalyzing = false;

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

  Future<void> _showAIAnalysis() async {
    setState(() => _isAnalyzing = true);

    // Show bottom sheet immediately with loading state
    final sheetController = showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      builder: (ctx) => _AIAnalysisSheet(
        statistics: _statistics,
        payroll: _payrollReport,
        topPerformers: _topPerformers,
      ),
    );

    // When sheet closes, reset analyzing state
    sheetController.whenComplete(() {
      if (mounted) setState(() => _isAnalyzing = false);
    });
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
      floatingActionButton: _isLoading
          ? null
          : Padding(
              padding: const EdgeInsets.only(bottom: 70),
              child: FloatingActionButton.extended(
                onPressed: _isAnalyzing ? null : _showAIAnalysis,
                icon: _isAnalyzing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.auto_awesome),
                label: Text(_isAnalyzing ? 'Analyzing...' : 'AI Analysis'),
                backgroundColor: const Color(0xFF212C4A),
              ),
            ),
    );

    if (kIsWeb) {
      return WebContentWrapper(child: content);
    }
    return content;
  }
}

/// Bottom sheet that fetches and displays AI analysis of the stats data.
class _AIAnalysisSheet extends StatefulWidget {
  const _AIAnalysisSheet({
    required this.statistics,
    required this.payroll,
    required this.topPerformers,
  });

  final ManagerStatistics statistics;
  final PayrollReport payroll;
  final TopPerformersReport topPerformers;

  @override
  State<_AIAnalysisSheet> createState() => _AIAnalysisSheetState();
}

class _AIAnalysisSheetState extends State<_AIAnalysisSheet> {
  bool _loading = true;
  bool _generating = false;
  String? _analysis;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchAnalysis();
  }

  Future<void> _fetchAnalysis() async {
    try {
      final result = await StatisticsService.getAIAnalysis(
        statistics: widget.statistics,
        payroll: widget.payroll,
        topPerformers: widget.topPerformers,
      );
      if (mounted) {
        setState(() {
          _analysis = result;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('[AIAnalysis] Error: $e');
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  Future<void> _downloadDoc(String format) async {
    if (_analysis == null) return;
    setState(() => _generating = true);

    try {
      final url = await StatisticsService.generateAnalysisDoc(
        analysis: _analysis!,
        statistics: widget.statistics,
        format: format,
      );

      if (mounted) {
        setState(() => _generating = false);
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      }
    } catch (e) {
      debugPrint('[AIAnalysis] Doc generation error: $e');
      if (mounted) {
        setState(() => _generating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 0.75;

    return Container(
      height: height,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF212C4A).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
                    color: Color(0xFF212C4A),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'AI Analysis',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF212C4A),
                        ),
                      ),
                      Text(
                        widget.statistics.period.label,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                if (_analysis != null && !_generating)
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.download_rounded, color: Color(0xFF212C4A)),
                    tooltip: 'Download report',
                    onSelected: _downloadDoc,
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(
                        value: 'pdf',
                        child: Row(
                          children: [
                            Icon(Icons.picture_as_pdf, size: 18, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Download PDF'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'docx',
                        child: Row(
                          children: [
                            Icon(Icons.description, size: 18, color: Colors.blue),
                            SizedBox(width: 8),
                            Text('Download Word'),
                          ],
                        ),
                      ),
                    ],
                  ),
                if (_generating)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Content
          Expanded(
            child: _loading
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(
                          color: Color(0xFF212C4A),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Analyzing your data...',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  )
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
                              const SizedBox(height: 12),
                              Text(
                                _error!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.red),
                              ),
                              const SizedBox(height: 16),
                              OutlinedButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _loading = true;
                                    _error = null;
                                  });
                                  _fetchAnalysis();
                                },
                                icon: const Icon(Icons.refresh, size: 18),
                                label: const Text('Retry'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : Markdown(
                        data: _analysis ?? '',
                        padding: const EdgeInsets.all(20),
                        styleSheet: MarkdownStyleSheet(
                          h1: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF212C4A),
                          ),
                          h2: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF212C4A),
                          ),
                          h3: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF374151),
                          ),
                          p: const TextStyle(
                            fontSize: 14,
                            height: 1.5,
                            color: Color(0xFF374151),
                          ),
                          listBullet: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF374151),
                          ),
                          strong: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF212C4A),
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
