import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nexa/l10n/app_localizations.dart';
import 'package:nexa/shared/presentation/theme/app_colors.dart';

enum StaffAttendanceStatus {
  clocked,   // has clockOutAt, ready to approve
  working,   // has clockInAt but no clockOutAt
  noData,    // no attendance records
  sheet,     // has sheet data from OCR
  approved,  // already approved
}

class StaffHoursCard extends StatelessWidget {
  final Map<String, dynamic> staffMember;
  final StaffAttendanceStatus status;
  final DateTime? clockInAt;
  final DateTime? clockOutAt;
  final double? estimatedHours;
  final double? approvedHours;
  final VoidCallback? onApprove;
  final VoidCallback? onEdit;

  const StaffHoursCard({
    super.key,
    required this.staffMember,
    required this.status,
    this.clockInAt,
    this.clockOutAt,
    this.estimatedHours,
    this.approvedHours,
    this.onApprove,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final name = staffMember['name']?.toString() ??
        '${staffMember['first_name'] ?? ''} ${staffMember['last_name'] ?? ''}'.trim();
    final role = staffMember['role']?.toString() ?? '';
    final picture = staffMember['picture']?.toString();

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: _statusBorderColor,
          width: status == StaffAttendanceStatus.approved ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            // Header row: avatar, name, role, status badge
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundImage: picture != null ? NetworkImage(picture) : null,
                  backgroundColor: AppColors.surfaceGray,
                  child: picture == null && name.isNotEmpty
                      ? Text(
                          name[0].toUpperCase(),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name.isEmpty ? 'Unknown' : name,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (role.isNotEmpty)
                        Text(
                          role,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.textMuted,
                          ),
                        ),
                    ],
                  ),
                ),
                _buildStatusBadge(context, l10n),
              ],
            ),

            // Clock times row (if data exists)
            if (status != StaffAttendanceStatus.noData) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.surfaceGray,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    if (clockInAt != null) ...[
                      _buildTimeChip(
                        context,
                        icon: Icons.login,
                        label: l10n.digitalClockIn,
                        time: _formatTime(clockInAt!),
                        color: AppColors.info,
                      ),
                      const SizedBox(width: 12),
                    ],
                    if (clockOutAt != null) ...[
                      _buildTimeChip(
                        context,
                        icon: Icons.logout,
                        label: l10n.digitalClockOut,
                        time: _formatTime(clockOutAt!),
                        color: AppColors.success,
                      ),
                      const SizedBox(width: 12),
                    ],
                    if (estimatedHours != null || approvedHours != null)
                      _buildTimeChip(
                        context,
                        icon: Icons.schedule,
                        label: l10n.estimatedHoursLabel,
                        time: '${(approvedHours ?? estimatedHours)!.toStringAsFixed(2)} hrs',
                        color: AppColors.warning,
                      ),
                  ],
                ),
              ),
            ],

            // Action buttons (only for non-approved staff with data)
            if (status == StaffAttendanceStatus.clocked ||
                status == StaffAttendanceStatus.sheet) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (onEdit != null)
                    TextButton.icon(
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit, size: 16),
                      label: Text(l10n.adjustHours),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.textTertiary,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  const SizedBox(width: 8),
                  if (onApprove != null)
                    FilledButton.icon(
                      onPressed: onApprove,
                      icon: const Icon(Icons.check, size: 16),
                      label: Text(l10n.approveDigitalHours),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.success,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                ],
              ),
            ],

            // Approved display
            if (status == StaffAttendanceStatus.approved) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Icon(Icons.check_circle, size: 16, color: AppColors.success),
                  const SizedBox(width: 4),
                  Text(
                    '${l10n.approvedStatus}: ${(approvedHours ?? estimatedHours ?? 0).toStringAsFixed(2)} hrs',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.success,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],

            // Working indicator
            if (status == StaffAttendanceStatus.working) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.info,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    l10n.currentlyWorking,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.info,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color get _statusBorderColor {
    switch (status) {
      case StaffAttendanceStatus.clocked:
        return AppColors.success.withValues(alpha: 0.4);
      case StaffAttendanceStatus.working:
        return AppColors.info.withValues(alpha: 0.4);
      case StaffAttendanceStatus.noData:
        return AppColors.borderLight;
      case StaffAttendanceStatus.sheet:
        return AppColors.warning.withValues(alpha: 0.4);
      case StaffAttendanceStatus.approved:
        return AppColors.success;
    }
  }

  Widget _buildStatusBadge(BuildContext context, AppLocalizations l10n) {
    String label;
    Color bgColor;
    Color fgColor;
    IconData icon;

    switch (status) {
      case StaffAttendanceStatus.clocked:
        label = l10n.clockedStatus;
        bgColor = AppColors.success.withValues(alpha: 0.1);
        fgColor = AppColors.success;
        icon = Icons.check_circle_outline;
      case StaffAttendanceStatus.working:
        label = l10n.workingStatus;
        bgColor = AppColors.info.withValues(alpha: 0.1);
        fgColor = AppColors.info;
        icon = Icons.play_circle_outline;
      case StaffAttendanceStatus.noData:
        label = l10n.noAttendanceData;
        bgColor = AppColors.surfaceGray;
        fgColor = AppColors.textMuted;
        icon = Icons.remove_circle_outline;
      case StaffAttendanceStatus.sheet:
        label = l10n.sheetHoursStatus;
        bgColor = AppColors.warning.withValues(alpha: 0.1);
        fgColor = AppColors.warning;
        icon = Icons.description;
      case StaffAttendanceStatus.approved:
        label = l10n.approvedStatus;
        bgColor = AppColors.success.withValues(alpha: 0.1);
        fgColor = AppColors.success;
        icon = Icons.verified;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fgColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: fgColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeChip(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String time,
    required Color color,
  }) {
    return Expanded(
      child: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            time,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    return DateFormat.jm().format(dt);
  }
}
