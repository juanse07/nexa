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

  const HoursAdjustDialog({
    super.key,
    required this.staffName,
    this.clockInAt,
    this.clockOutAt,
    this.estimatedHours,
    this.currentApprovedHours,
  });

  @override
  State<HoursAdjustDialog> createState() => _HoursAdjustDialogState();
}

class _HoursAdjustDialogState extends State<HoursAdjustDialog> {
  late TextEditingController _hoursController;
  late TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    final initialHours = widget.currentApprovedHours ?? widget.estimatedHours ?? 0.0;
    _hoursController = TextEditingController(text: initialHours.toStringAsFixed(2));
    _noteController = TextEditingController();
  }

  @override
  void dispose() {
    _hoursController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return AlertDialog(
      title: Text(l10n.adjustHoursFor(widget.staffName)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Digital times reference
            if (widget.clockInAt != null || widget.clockOutAt != null) ...[
              Text(
                l10n.digitalTimesReference,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceGray,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    if (widget.clockInAt != null)
                      _buildRefRow(
                        l10n.digitalClockIn,
                        DateFormat.jm().format(widget.clockInAt!),
                        Icons.login,
                      ),
                    if (widget.clockOutAt != null) ...[
                      if (widget.clockInAt != null) const SizedBox(height: 4),
                      _buildRefRow(
                        l10n.digitalClockOut,
                        DateFormat.jm().format(widget.clockOutAt!),
                        Icons.logout,
                      ),
                    ],
                    if (widget.estimatedHours != null) ...[
                      const SizedBox(height: 4),
                      _buildRefRow(
                        l10n.estimatedHoursLabel,
                        '${widget.estimatedHours!.toStringAsFixed(2)} hrs',
                        Icons.schedule,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Adjusted hours input
            TextField(
              controller: _hoursController,
              decoration: InputDecoration(
                labelText: l10n.adjustedHours,
                suffixText: 'hrs',
                border: const OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
            ),
            const SizedBox(height: 12),

            // Note input
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
          onPressed: () {
            final hours = double.tryParse(_hoursController.text.trim());
            if (hours == null || hours <= 0) return;
            Navigator.pop(
              context,
              HoursAdjustResult(
                hours: hours,
                note: _noteController.text.trim().isEmpty
                    ? null
                    : _noteController.text.trim(),
              ),
            );
          },
          child: Text(l10n.save),
        ),
      ],
    );
  }

  Widget _buildRefRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.textMuted),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(fontSize: 12, color: AppColors.textMuted),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
