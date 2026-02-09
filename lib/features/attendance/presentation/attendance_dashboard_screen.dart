import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:nexa/shared/widgets/web_content_wrapper.dart';
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

  AttendanceAnalytics _analytics = AttendanceAnalytics.empty;
  List<ClockedInStaff> _clockedInStaff = [];
  List<AttendanceRecord> _attendanceRecords = [];
  AttendanceFilters _filters = const AttendanceFilters();
  List<Map<String, dynamic>> _events = [];

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load data: $e')),
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Viewing details for ${staff.name}')),
          );
        },
        onForceClockOut: () => _forceClockOut(staff),
      ),
    );
  }

  Future<void> _forceClockOut(ClockedInStaff staff) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Force Clock-Out'),
        content: Text('Are you sure you want to clock out ${staff.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Clock Out'),
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
              content: Text('${staff.name} clocked out successfully'),
              backgroundColor: Colors.green,
            ),
          );
          _refresh();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to clock out staff'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _forceClockOutRecord(AttendanceRecord record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Force Clock-Out'),
        content: Text('Are you sure you want to clock out ${record.staffName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Clock Out'),
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
            content: Text('${record.staffName} clocked out successfully'),
            backgroundColor: Colors.green,
          ),
        );
        _refresh();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to clock out staff'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: CustomScrollView(
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
              title: const Text(
                'Attendance',
                style: TextStyle(
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
                    const Text(
                      'Recent Activity',
                      style: TextStyle(
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
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Viewing history for ${record.staffName}'),
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

      // Floating action button for export — extra bottom margin to clear MainScreen's overlaid nav bar
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 70),
        child: FloatingActionButton.extended(
          onPressed: _showExportOptions,
          backgroundColor: const Color(0xFF212C4A),
          icon: const Icon(Icons.download_rounded),
          label: const Text('Export'),
        ),
      ),
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
            'No attendance records',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _filters.hasActiveFilters
                ? 'Try adjusting your filters'
                : 'Records will appear here when staff clock in',
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
              child: const Text('Clear Filters'),
            ),
          ],
        ],
      ),
    );
  }

  void _showExportOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Export Attendance',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.table_chart, color: Colors.green),
              ),
              title: const Text('Export as CSV'),
              subtitle: const Text('Spreadsheet format'),
              onTap: () {
                Navigator.pop(context);
                _exportData('csv');
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.picture_as_pdf, color: Colors.red),
              ),
              title: const Text('Export as PDF'),
              subtitle: const Text('Formatted report'),
              onTap: () {
                Navigator.pop(context);
                _exportData('pdf');
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _exportData(String format) {
    // TODO: Implement export functionality
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Exporting as ${format.toUpperCase()}...')),
    );
  }
}
