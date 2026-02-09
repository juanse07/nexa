import 'package:flutter/material.dart';
import '../../models/attendance_dashboard_models.dart';

/// Bottom sheet for filtering attendance data
class AttendanceFilterSheet extends StatefulWidget {
  final AttendanceFilters currentFilters;
  final List<Map<String, dynamic>> availableEvents;
  final Function(AttendanceFilters) onApply;
  final VoidCallback onClear;

  const AttendanceFilterSheet({
    super.key,
    required this.currentFilters,
    required this.availableEvents,
    required this.onApply,
    required this.onClear,
  });

  @override
  State<AttendanceFilterSheet> createState() => _AttendanceFilterSheetState();
}

class _AttendanceFilterSheetState extends State<AttendanceFilterSheet> {
  late AttendanceFilters _filters;
  String _selectedDatePreset = 'last7Days';

  @override
  void initState() {
    super.initState();
    _filters = widget.currentFilters;
    _determineSelectedPreset();
  }

  void _determineSelectedPreset() {
    if (_filters.dateRange == null) {
      _selectedDatePreset = 'last7Days';
      return;
    }

    final range = _filters.dateRange!;
    final today = AttendanceFilters.today;
    final yesterday = AttendanceFilters.yesterday;
    final thisWeek = AttendanceFilters.thisWeek;
    final last7Days = AttendanceFilters.last7Days;

    if (_rangesEqual(range, today)) {
      _selectedDatePreset = 'today';
    } else if (_rangesEqual(range, yesterday)) {
      _selectedDatePreset = 'yesterday';
    } else if (_rangesEqual(range, thisWeek)) {
      _selectedDatePreset = 'thisWeek';
    } else if (_rangesEqual(range, last7Days)) {
      _selectedDatePreset = 'last7Days';
    } else {
      _selectedDatePreset = 'custom';
    }
  }

  bool _rangesEqual(DateTimeRange a, DateTimeRange b) {
    return a.start.year == b.start.year &&
        a.start.month == b.start.month &&
        a.start.day == b.start.day &&
        a.end.year == b.end.year &&
        a.end.month == b.end.month &&
        a.end.day == b.end.day;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
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
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Filter Attendance',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    widget.onClear();
                    Navigator.pop(context);
                  },
                  child: const Text('Clear All'),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Scrollable content
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date Range Section
                  _buildSectionHeader('Date Range'),
                  const SizedBox(height: 12),
                  _buildDatePresets(),

                  const SizedBox(height: 24),

                  // Event Filter Section
                  _buildSectionHeader('Event'),
                  const SizedBox(height: 12),
                  _buildEventDropdown(),

                  const SizedBox(height: 24),

                  // Status Filter Section
                  _buildSectionHeader('Status'),
                  const SizedBox(height: 12),
                  _buildStatusChips(),
                ],
              ),
            ),
          ),

          // Apply button
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    widget.onApply(_filters);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E3A8A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Apply Filters',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Colors.black87,
      ),
    );
  }

  Widget _buildDatePresets() {
    final presets = [
      ('today', 'Today'),
      ('yesterday', 'Yesterday'),
      ('thisWeek', 'This Week'),
      ('last7Days', 'Last 7 Days'),
      ('custom', 'Custom'),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: presets.map((preset) {
        final isSelected = _selectedDatePreset == preset.$1;
        return ChoiceChip(
          label: Text(preset.$2),
          selected: isSelected,
          onSelected: (selected) {
            if (selected) {
              setState(() {
                _selectedDatePreset = preset.$1;
                _filters = _filters.copyWith(
                  dateRange: _getDateRangeForPreset(preset.$1),
                );
              });

              if (preset.$1 == 'custom') {
                _showCustomDatePicker();
              }
            }
          },
          selectedColor: const Color(0xFF1E3A8A).withOpacity(0.2),
          checkmarkColor: const Color(0xFF1E3A8A),
          labelStyle: TextStyle(
            color: isSelected ? const Color(0xFF1E3A8A) : Colors.grey[700],
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        );
      }).toList(),
    );
  }

  DateTimeRange? _getDateRangeForPreset(String preset) {
    switch (preset) {
      case 'today':
        return AttendanceFilters.today;
      case 'yesterday':
        return AttendanceFilters.yesterday;
      case 'thisWeek':
        return AttendanceFilters.thisWeek;
      case 'last7Days':
        return AttendanceFilters.last7Days;
      case 'custom':
        return _filters.dateRange;
      default:
        return null;
    }
  }

  Future<void> _showCustomDatePicker() async {
    final now = DateTime.now();
    final result = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: now,
      initialDateRange: _filters.dateRange ??
          DateTimeRange(
            start: now.subtract(const Duration(days: 7)),
            end: now,
          ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF1E3A8A),
            ),
          ),
          child: child!,
        );
      },
    );

    if (result != null) {
      setState(() {
        _filters = _filters.copyWith(dateRange: result);
      });
    }
  }

  Widget _buildEventDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: _filters.eventId,
          isExpanded: true,
          hint: const Text('All Events'),
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('All Events'),
            ),
            ...widget.availableEvents.map((event) {
              return DropdownMenuItem<String?>(
                value: event['_id'] as String?,
                child: Text(
                  event['event_name'] as String? ?? 'Unknown Event',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }),
          ],
          onChanged: (value) {
            setState(() {
              _filters = _filters.copyWith(
                eventId: value,
                clearEventId: value == null,
              );
            });
          },
        ),
      ),
    );
  }

  Widget _buildStatusChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: AttendanceStatus.values.map((status) {
        final isSelected = _filters.status == status;
        return ChoiceChip(
          label: Text(status.label),
          selected: isSelected,
          onSelected: (selected) {
            if (selected) {
              setState(() {
                _filters = _filters.copyWith(status: status);
              });
            }
          },
          selectedColor: _getStatusColor(status).withOpacity(0.2),
          checkmarkColor: _getStatusColor(status),
          labelStyle: TextStyle(
            color: isSelected ? _getStatusColor(status) : Colors.grey[700],
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        );
      }).toList(),
    );
  }

  Color _getStatusColor(AttendanceStatus status) {
    switch (status) {
      case AttendanceStatus.all:
        return const Color(0xFF1E3A8A);
      case AttendanceStatus.working:
        return Colors.green;
      case AttendanceStatus.completed:
        return Colors.grey;
      case AttendanceStatus.flagged:
        return Colors.orange;
      case AttendanceStatus.noShow:
        return Colors.red;
    }
  }
}
