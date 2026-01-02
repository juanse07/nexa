import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';
import '../../models/attendance_dashboard_models.dart';
import 'pulse_indicator.dart';

/// Staff attendance card with swipe actions
class StaffAttendanceCard extends StatelessWidget {
  final AttendanceRecord record;
  final VoidCallback onTap;
  final VoidCallback onViewHistory;
  final VoidCallback onForceClockOut;
  final bool showSwipeActions;

  const StaffAttendanceCard({
    super.key,
    required this.record,
    required this.onTap,
    required this.onViewHistory,
    required this.onForceClockOut,
    this.showSwipeActions = true,
  });

  @override
  Widget build(BuildContext context) {
    final card = _buildCard(context);

    if (!showSwipeActions) {
      return card;
    }

    return Slidable(
      key: ValueKey(record.userKey + record.clockInAt.toIso8601String()),
      startActionPane: ActionPane(
        motion: const BehindMotion(),
        extentRatio: 0.25,
        children: [
          SlidableAction(
            onPressed: (_) => onViewHistory(),
            backgroundColor: const Color(0xFF667eea),
            foregroundColor: Colors.white,
            icon: Icons.history,
            label: 'History',
            borderRadius: const BorderRadius.horizontal(
              left: Radius.circular(12),
            ),
          ),
        ],
      ),
      endActionPane: record.isWorking
          ? ActionPane(
              motion: const BehindMotion(),
              extentRatio: 0.25,
              children: [
                SlidableAction(
                  onPressed: (_) => onForceClockOut(),
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  icon: Icons.logout,
                  label: 'Clock Out',
                  borderRadius: const BorderRadius.horizontal(
                    right: Radius.circular(12),
                  ),
                ),
              ],
            )
          : null,
      child: card,
    );
  }

  Widget _buildCard(BuildContext context) {
    final timeFormat = DateFormat('h:mm a');
    final statusConfig = _getStatusConfig();

    return GestureDetector(
      onTap: onTap,
      onLongPress: () => _showQuickStats(context),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: Avatar, name, status
              Row(
                children: [
                  // Avatar
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: const Color(0xFF667eea),
                    backgroundImage: record.picture != null
                        ? NetworkImage(record.picture!)
                        : null,
                    child: record.picture == null
                        ? Text(
                            record.initials,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),

                  // Name and role
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          record.staffName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (record.role != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            record.role!,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Status badge
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      StatusBadge(
                        label: statusConfig.label,
                        color: statusConfig.color,
                        showPulse: record.isWorking,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        record.hoursWorkedFormatted,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Event name
              Row(
                children: [
                  Icon(
                    Icons.event_outlined,
                    size: 16,
                    color: Colors.grey[500],
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      record.eventName,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Time row
              Row(
                children: [
                  Icon(
                    Icons.access_time,
                    size: 16,
                    color: Colors.grey[500],
                  ),
                  const SizedBox(width: 6),
                  Text(
                    timeFormat.format(record.clockInAt.toLocal()),
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    ' → ',
                    style: TextStyle(color: Colors.grey[400]),
                  ),
                  Text(
                    record.clockOutAt != null
                        ? timeFormat.format(record.clockOutAt!.toLocal())
                        : '--:--',
                    style: TextStyle(
                      fontSize: 13,
                      color: record.clockOutAt != null
                          ? Colors.grey[700]
                          : Colors.grey[400],
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                  const Spacer(),

                  // Location indicator
                  if (record.clockInLocation != null) ...[
                    Icon(
                      Icons.location_on,
                      size: 14,
                      color: Colors.green[400],
                    ),
                    const SizedBox(width: 2),
                    Text(
                      'On-site',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.green[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      Icons.check_circle,
                      size: 12,
                      color: Colors.green[400],
                    ),
                  ],
                ],
              ),

              // Auto clock-out indicator
              if (record.autoClockOut) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 14,
                        color: Colors.orange[700],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Auto clocked-out',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.orange[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  _StatusConfig _getStatusConfig() {
    switch (record.displayStatus) {
      case AttendanceDisplayStatus.working:
        return _StatusConfig(
          label: 'Working',
          color: Colors.green,
        );
      case AttendanceDisplayStatus.completed:
        return _StatusConfig(
          label: 'Completed',
          color: Colors.grey,
        );
      case AttendanceDisplayStatus.flagged:
        return _StatusConfig(
          label: 'Flagged',
          color: Colors.orange,
        );
      case AttendanceDisplayStatus.noShow:
        return _StatusConfig(
          label: 'No-show',
          color: Colors.red,
        );
    }
  }

  void _showQuickStats(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(record.staffName),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatRow('Event', record.eventName),
            _buildStatRow('Role', record.role ?? 'Not specified'),
            _buildStatRow(
              'Clock-in',
              DateFormat('MMM d, h:mm a').format(record.clockInAt.toLocal()),
            ),
            if (record.clockOutAt != null)
              _buildStatRow(
                'Clock-out',
                DateFormat('MMM d, h:mm a').format(record.clockOutAt!.toLocal()),
              ),
            _buildStatRow('Duration', record.hoursWorkedFormatted),
            if (record.clockInLocation != null)
              _buildStatRow('Location', 'Verified on-site'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.grey[600]),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

class _StatusConfig {
  final String label;
  final Color color;

  _StatusConfig({required this.label, required this.color});
}
