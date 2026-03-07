import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nexa/l10n/app_localizations.dart';
import 'package:nexa/shared/presentation/theme/app_colors.dart';

class HoursAdjustResult {
  final double hours;
  final String? note;

  const HoursAdjustResult({required this.hours, this.note});
}

class HoursAdjustDialog extends StatefulWidget {
  final String staffName;
  final DateTime? clockInAt;
  final DateTime? clockOutAt;
  final double? estimatedHours;
  final double? currentApprovedHours;
  final String? eventStartTime;
  final String? eventEndTime;

  const HoursAdjustDialog({
    super.key,
    required this.staffName,
    this.clockInAt,
    this.clockOutAt,
    this.estimatedHours,
    this.currentApprovedHours,
    this.eventStartTime,
    this.eventEndTime,
  });

  @override
  State<HoursAdjustDialog> createState() => _HoursAdjustDialogState();
}

class _HoursAdjustDialogState extends State<HoursAdjustDialog> {
  late TimeOfDay _clockIn;
  late TimeOfDay _clockOut;
  late bool _deductBreak;
  late TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    _clockIn = _initTime(widget.clockInAt, widget.eventStartTime) ??
        const TimeOfDay(hour: 9, minute: 0);
    _clockOut = _initTime(widget.clockOutAt, widget.eventEndTime) ??
        const TimeOfDay(hour: 17, minute: 0);
    _deductBreak = _grossHours > 5.0;
    _noteController = TextEditingController();
  }

  /// Parse initial time from clock DateTime or event time string (e.g. "18:00").
  TimeOfDay? _initTime(DateTime? clockTime, String? eventTime) {
    if (clockTime != null) {
      return TimeOfDay.fromDateTime(clockTime);
    }
    if (eventTime != null && eventTime.contains(':')) {
      final parts = eventTime.split(':');
      final hour = int.tryParse(parts[0]);
      final minute = int.tryParse(parts[1]);
      if (hour != null && minute != null) {
        return TimeOfDay(hour: hour, minute: minute);
      }
    }
    return null;
  }

  /// Gross hours between clock in and clock out, handling overnight shifts.
  double get _grossHours {
    final inMinutes = _clockIn.hour * 60 + _clockIn.minute;
    final outMinutes = _clockOut.hour * 60 + _clockOut.minute;
    var diff = outMinutes - inMinutes;
    if (diff <= 0) diff += 24 * 60; // overnight
    return diff / 60.0;
  }

  double get _finalHours {
    final gross = _grossHours;
    return gross - (_deductBreak ? 0.5 : 0.0);
  }

  void _onTimesChanged() {
    setState(() {
      _deductBreak = _grossHours > 5.0;
    });
  }

  Future<void> _pickClockIn() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _clockIn,
    );
    if (picked != null) {
      _clockIn = picked;
      _onTimesChanged();
    }
  }

  Future<void> _pickClockOut() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _clockOut,
    );
    if (picked != null) {
      _clockOut = picked;
      _onTimesChanged();
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final gross = _grossHours;
    final finalH = _finalHours;

    return AlertDialog(
      title: Text(l10n.adjustHoursFor(widget.staffName)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Clock In row
            _buildTimeRow(
              label: l10n.clockInTime,
              icon: Icons.login,
              time: _clockIn,
              onTap: _pickClockIn,
            ),
            const SizedBox(height: 8),

            // Clock Out row
            _buildTimeRow(
              label: l10n.clockOutTime,
              icon: Icons.logout,
              time: _clockOut,
              onTap: _pickClockOut,
            ),
            const SizedBox(height: 16),

            // Gross hours
            _buildInfoRow(
              label: l10n.grossHours,
              value: '${gross.toStringAsFixed(2)} hrs',
              color: AppColors.textMuted,
            ),
            const SizedBox(height: 8),

            // Break checkbox
            CheckboxListTile(
              value: _deductBreak,
              onChanged: (v) => setState(() => _deductBreak = v ?? false),
              title: Text(
                l10n.deduct30MinBreak,
                style: theme.textTheme.bodyMedium,
              ),
              dense: true,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
            ),
            const SizedBox(height: 8),

            // Final hours
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: finalH > 0
                    ? AppColors.success.withValues(alpha: 0.1)
                    : AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l10n.finalHours,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${finalH.toStringAsFixed(2)} hrs',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: finalH > 0 ? AppColors.success : AppColors.error,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Note
            TextField(
              controller: _noteController,
              decoration: InputDecoration(
                labelText: l10n.noteOptional,
                border: const OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: finalH > 0
              ? () {
                  Navigator.pop(
                    context,
                    HoursAdjustResult(
                      hours: finalH,
                      note: _noteController.text.trim().isEmpty
                          ? null
                          : _noteController.text.trim(),
                    ),
                  );
                }
              : null,
          child: Text(l10n.save),
        ),
      ],
    );
  }

  Widget _buildTimeRow({
    required String label,
    required IconData icon,
    required TimeOfDay time,
    required VoidCallback onTap,
  }) {
    final l10n = AppLocalizations.of(context)!;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceGray,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.navySpaceCadet),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontSize: 14),
              ),
            ),
            Text(
              time.format(context),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.edit, size: 16, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required String label,
    required String value,
    Color? color,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 13, color: color ?? AppColors.textMuted),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: color ?? AppColors.textMuted,
          ),
        ),
      ],
    );
  }
}
