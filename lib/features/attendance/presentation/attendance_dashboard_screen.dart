import 'dart:ui';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:nexa/l10n/app_localizations.dart';
import 'package:nexa/shared/widgets/tappable_app_title.dart';
import 'package:nexa/shared/widgets/web_content_wrapper.dart';
import '../../statistics/data/models/statistics_models.dart';
import '../../statistics/data/services/statistics_service.dart';
import '../../statistics/presentation/widgets/ai_analysis_sheet.dart';
import '../models/attendance_dashboard_models.dart';
import '../services/attendance_dashboard_service.dart';
import 'widgets/attendance_hero_header.dart';
import 'widgets/live_staff_grid.dart';
import 'widgets/weekly_hours_chart.dart';
import 'widgets/staff_attendance_card.dart';
import 'widgets/attendance_filter_sheet.dart';
import 'flagged_attendance_screen.dart';

/// Premium attendance dashboard with live data visualization
class AttendanceDashboardScreen extends StatefulWidget {
  const AttendanceDashboardScreen({super.key});

  @override
  State<AttendanceDashboardScreen> createState() => _AttendanceDashboardScreenState();
}

class _AttendanceDashboardScreenState extends State<AttendanceDashboardScreen> {
  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _isAnalyzing = false;
  bool _fabExtended = true;

  AttendanceAnalytics _analytics = AttendanceAnalytics.empty;
  List<ClockedInStaff> _clockedInStaff = [];
  List<AttendanceRecord> _attendanceRecords = [];
  AttendanceFilters _filters = const AttendanceFilters();
  List<Map<String, dynamic>> _events = [];

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
      // Load all data in parallel
      final results = await Future.wait([
        AttendanceDashboardService.getAnalytics(
          startDate: _filters.dateRange?.start,
          endDate: _filters.dateRange?.end,
        ),
        AttendanceDashboardService.getCurrentlyClockedIn(),
        AttendanceDashboardService.getAttendanceReport(
          startDate: _filters.dateRange?.start,
          endDate: _filters.dateRange?.end,
          eventId: _filters.eventId,
        ),
      ]);

      if (!mounted) return;

      setState(() {
        _analytics = results[0] as AttendanceAnalytics;
        _clockedInStaff = results[1] as List<ClockedInStaff>;
        _attendanceRecords = _applyFiltersToRecords(
          results[2] as List<AttendanceRecord>,
        );
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('[AttendanceDashboard] Load error: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.failedToLoadData}: $e')),
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

  List<AttendanceRecord> _applyFiltersToRecords(List<AttendanceRecord> records) {
    return records.where((record) {
      // Filter by status
      switch (_filters.status) {
        case AttendanceStatus.working:
          if (!record.isWorking) return false;
          break;
        case AttendanceStatus.completed:
          if (record.isWorking) return false;
          break;
        case AttendanceStatus.flagged:
          if (!record.isFlagged) return false;
          break;
        case AttendanceStatus.noShow:
          // Would need additional logic for no-shows
          break;
        case AttendanceStatus.all:
          break;
      }

      // Filter by staff
      if (_filters.staffUserKeys.isNotEmpty) {
        if (!_filters.staffUserKeys.contains(record.userKey)) return false;
      }

      return true;
    }).toList();
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        builder: (context, scrollController) => AttendanceFilterSheet(
          currentFilters: _filters,
          availableEvents: _events,
          onApply: (filters) {
            setState(() => _filters = filters);
            _loadData();
          },
          onClear: () {
            setState(() => _filters = const AttendanceFilters());
            _loadData();
          },
        ),
      ),
    );
  }

  void _navigateToFlaggedAttendance() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const FlaggedAttendanceScreen(),
      ),
    ).then((_) => _refresh());
  }

  void _showStaffQuickActions(ClockedInStaff staff) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => StaffQuickActionsSheet(
        staff: staff,
        onViewDetails: () {
          // TODO: Navigate to staff detail screen
          final l10n = AppLocalizations.of(context)!;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.viewingDetailsFor(staff.name))),
          );
        },
        onForceClockOut: () => _forceClockOut(staff),
      ),
    );
  }

  Future<void> _forceClockOut(ClockedInStaff staff) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.forceClockOut),
        content: Text(l10n.confirmClockOutMessage(staff.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(l10n.clockOut),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await AttendanceDashboardService.forceClockOut(
        eventId: staff.eventId,
        userKey: staff.userKey,
        note: 'Clocked out by manager from dashboard',
      );

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.staffClockedOutSuccessfully(staff.name)),
              backgroundColor: Colors.green,
            ),
          );
          _refresh();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.failedToClockOutStaff),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _forceClockOutRecord(AttendanceRecord record) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.forceClockOut),
        content: Text(l10n.confirmClockOutMessage(record.staffName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(l10n.clockOut),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final success = await AttendanceDashboardService.forceClockOut(
      eventId: record.eventId,
      userKey: record.userKey,
      note: 'Clocked out by manager from dashboard',
    );

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.staffClockedOutSuccessfully(record.staffName)),
            backgroundColor: Colors.green,
          ),
        );
        _refresh();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.failedToClockOutStaff),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showAIAnalysis() async {
    setState(() => _isAnalyzing = true);

    try {
      // Fetch stats data on-demand for AI analysis
      final results = await Future.wait([
        StatisticsService.getManagerSummary(),
        StatisticsService.getPayrollReport(),
        StatisticsService.getTopPerformers(),
      ]);

      if (!mounted) return;

      final sheetController = showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        isDismissible: true,
        builder: (ctx) => AIAnalysisSheet(
          statistics: results[0] as ManagerStatistics,
          payroll: results[1] as PayrollReport,
          topPerformers: results[2] as TopPerformersReport,
        ),
      );

      sheetController.whenComplete(() {
        if (mounted) setState(() => _isAnalyzing = false);
      });
    } catch (e) {
      debugPrint('[AttendanceDashboard] AI analysis error: $e');
      if (mounted) {
        setState(() => _isAnalyzing = false);
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.failedToLoadData}: $e')),
        );
      }
    }
  }

  Widget _buildValerioFab() {
    final l10n = AppLocalizations.of(context)!;
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

    return GestureDetector(
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
                                _isAnalyzing ? l10n.analyzing : l10n.aiAnalysis,
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Stack(
      children: [
        Scaffold(
      backgroundColor: Colors.grey[100],
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            // Hero header with collapsing behavior
            SliverAppBar(
              expandedHeight: 180,
              floating: false,
              pinned: true,
              backgroundColor: const Color(0xFF212C4A),
              flexibleSpace: FlexibleSpaceBar(
                background: AttendanceHeroHeader(
                  analytics: _analytics,
                  onFilterTap: _showFilterSheet,
                  onFlagsTap: _navigateToFlaggedAttendance,
                  isLoading: _isLoading,
                ),
                collapseMode: CollapseMode.parallax,
              ),
              title: TappableAppTitle.text(
                l10n.attendanceTitle,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                ),
              ),
              centerTitle: false,
              actions: [
                IconButton(
                  onPressed: _showFilterSheet,
                  icon: Stack(
                    children: [
                      const Icon(Icons.tune_rounded, color: Colors.white70),
                      if (_filters.hasActiveFilters)
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.redAccent,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),

            // Live staff grid
            _wrapSliver(SliverToBoxAdapter(
              child: LiveStaffGrid(
                staff: _clockedInStaff,
                onStaffTap: _showStaffQuickActions,
                isLoading: _isLoading,
              ),
            )),

            // Weekly hours chart
            _wrapSliver(SliverToBoxAdapter(
              child: WeeklyHoursChart(
                data: _analytics.weeklyHours,
                isLoading: _isLoading,
                onBarTap: (dayData) {
                  // TODO: Filter to show only that day's records
                  debugPrint('Tapped on ${dayData.date}');
                },
              ),
            )),

            // Section header for attendance list
            _wrapSliver(SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      l10n.recentActivity,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    if (_isRefreshing)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
                ),
              ),
            )),

            // Attendance records list
            if (_isLoading)
              _wrapSliver(SliverToBoxAdapter(
                child: _buildLoadingList(),
              ))
            else if (_attendanceRecords.isEmpty)
              _wrapSliver(SliverToBoxAdapter(
                child: _buildEmptyState(),
              ))
            else
              _wrapSliver(SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final record = _attendanceRecords[index];
                    return StaffAttendanceCard(
                      record: record,
                      onTap: () {
                        // TODO: Navigate to detail screen
                      },
                      onViewHistory: () {
                        // TODO: Navigate to history screen
                        final l10n = AppLocalizations.of(context)!;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(l10n.viewingHistoryFor(record.staffName)),
                          ),
                        );
                      },
                      onForceClockOut: () => _forceClockOutRecord(record),
                    );
                  },
                  childCount: _attendanceRecords.length,
                ),
              )),

            // Bottom padding
            const SliverToBoxAdapter(
              child: SizedBox(height: 100),
            ),
          ],
        ),
      ),

    ),
        Positioned(
          bottom: 100,
          right: 16,
          child: _buildValerioFab(),
        ),
      ],
    );
  }

  /// Wrap sliver with WebContentWrapper on web for centered max-width content
  Widget _wrapSliver(Widget sliver) {
    if (kIsWeb) {
      return SliverWebContentWrapper.chat(sliver: sliver);
    }
    return sliver;
  }

  Widget _buildLoadingList() {
    return Column(
      children: List.generate(
        3,
        (index) => Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          height: 120,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Center(
            child: CircularProgressIndicator(),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 64,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            l10n.noAttendanceRecords,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _filters.hasActiveFilters
                ? l10n.tryAdjustingFilters
                : l10n.recordsAppearWhenStaffClockIn,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
          if (_filters.hasActiveFilters) ...[
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                setState(() => _filters = const AttendanceFilters());
                _loadData();
              },
              child: Text(l10n.clearFilters),
            ),
          ],
        ],
      ),
    );
  }
}
