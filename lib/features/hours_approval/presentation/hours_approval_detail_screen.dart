import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nexa/core/di/injection.dart';
import 'package:nexa/core/network/api_client.dart';
import 'package:nexa/features/hours_approval/presentation/widgets/event_hours_summary_card.dart';
import 'package:nexa/features/hours_approval/presentation/widgets/hours_adjust_dialog.dart';
import 'package:nexa/features/hours_approval/presentation/widgets/staff_hours_card.dart';
import 'package:nexa/features/hours_approval/services/timesheet_extraction_service.dart';
import 'package:nexa/l10n/app_localizations.dart';
import 'package:nexa/services/file_upload_service.dart';
import 'package:nexa/shared/presentation/theme/app_colors.dart';

class HoursApprovalDetailScreen extends StatefulWidget {
  final Map<String, dynamic> event;

  const HoursApprovalDetailScreen({
    super.key,
    required this.event,
  });

  @override
  State<HoursApprovalDetailScreen> createState() =>
      _HoursApprovalDetailScreenState();
}

class _HoursApprovalDetailScreenState extends State<HoursApprovalDetailScreen> {
  final TimesheetExtractionService _service = TimesheetExtractionService();
  final FileUploadService _uploadService = FileUploadService(getIt<ApiClient>());
  final ImagePicker _picker = ImagePicker();

  late Map<String, dynamic> _event;
  bool _isBulkApproving = false;
  bool _isAnalyzing = false;
  String? _error;

  // Track individually approved staff (optimistic UI)
  final Set<String> _locallyApproved = {};

  @override
  void initState() {
    super.initState();
    _event = Map<String, dynamic>.from(widget.event);
  }

  List<Map<String, dynamic>> get _acceptedStaff {
    final staff = _event['accepted_staff'] as List? ?? [];
    return staff.cast<Map<String, dynamic>>();
  }

  // Compute attendance info for a staff member
  _StaffAttendanceInfo _getAttendanceInfo(Map<String, dynamic> staff) {
    final attendance = staff['attendance'] as List?;
    if (attendance == null || attendance.isEmpty) {
      return _StaffAttendanceInfo(status: StaffAttendanceStatus.noData);
    }

    final lastSession = attendance.last as Map<String, dynamic>;
    final statusStr = lastSession['status']?.toString();
    final userKey = staff['userKey']?.toString() ?? '';

    // Check if locally approved this session
    if (_locallyApproved.contains(userKey) || statusStr == 'approved') {
      return _StaffAttendanceInfo(
        status: StaffAttendanceStatus.approved,
        clockInAt: _parseDateTime(lastSession['clockInAt']),
        clockOutAt: _parseDateTime(lastSession['clockOutAt']),
        estimatedHours: (lastSession['estimatedHours'] as num?)?.toDouble(),
        approvedHours: (lastSession['approvedHours'] as num?)?.toDouble(),
      );
    }

    if (statusStr == 'sheet_submitted') {
      return _StaffAttendanceInfo(
        status: StaffAttendanceStatus.sheet,
        clockInAt: _parseDateTime(lastSession['clockInAt']),
        clockOutAt: _parseDateTime(lastSession['clockOutAt']),
        estimatedHours: (lastSession['estimatedHours'] as num?)?.toDouble(),
        approvedHours: (lastSession['approvedHours'] as num?)?.toDouble(),
      );
    }

    final clockOutAt = _parseDateTime(lastSession['clockOutAt']);
    final clockInAt = _parseDateTime(lastSession['clockInAt']);

    if (clockOutAt != null) {
      return _StaffAttendanceInfo(
        status: StaffAttendanceStatus.clocked,
        clockInAt: clockInAt,
        clockOutAt: clockOutAt,
        estimatedHours: (lastSession['estimatedHours'] as num?)?.toDouble(),
        approvedHours: (lastSession['approvedHours'] as num?)?.toDouble(),
      );
    }

    if (clockInAt != null) {
      return _StaffAttendanceInfo(
        status: StaffAttendanceStatus.working,
        clockInAt: clockInAt,
      );
    }

    return _StaffAttendanceInfo(status: StaffAttendanceStatus.noData);
  }

  DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    try {
      return DateTime.parse(value.toString());
    } catch (_) {
      return null;
    }
  }

  // Count staff ready for bulk approval
  int get _readyToApproveCount {
    return _acceptedStaff.where((staff) {
      final info = _getAttendanceInfo(staff);
      return info.status == StaffAttendanceStatus.clocked ||
             info.status == StaffAttendanceStatus.sheet;
    }).length;
  }

  // Aggregate stats
  int get _clockedOutCount {
    return _acceptedStaff.where((staff) {
      final info = _getAttendanceInfo(staff);
      return info.status == StaffAttendanceStatus.clocked ||
             info.status == StaffAttendanceStatus.approved;
    }).length;
  }

  double get _totalEstimatedHours {
    double total = 0;
    for (final staff in _acceptedStaff) {
      final info = _getAttendanceInfo(staff);
      total += info.approvedHours ?? info.estimatedHours ?? 0;
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: AppBar(
        title: Text(l10n.approveHours),
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Event summary card
                EventHoursSummaryCard(
                  event: _event,
                  totalStaff: _acceptedStaff.length,
                  clockedOutCount: _clockedOutCount,
                  totalEstimatedHours: _totalEstimatedHours,
                ),
                const SizedBox(height: 16),

                // Error message
                if (_error != null) ...[
                  Card(
                    color: AppColors.surfaceRed,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline, color: AppColors.error, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _error!,
                              style: TextStyle(color: AppColors.error, fontSize: 13),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () => setState(() => _error = null),
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // AI analysis indicator
                if (_isAnalyzing) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 12),
                          Text(l10n.analyzingSignInSheetWithAi),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Staff list
                ..._acceptedStaff.map((staff) {
                  final info = _getAttendanceInfo(staff);
                  return StaffHoursCard(
                    staffMember: staff,
                    status: info.status,
                    clockInAt: info.clockInAt,
                    clockOutAt: info.clockOutAt,
                    estimatedHours: info.estimatedHours,
                    approvedHours: info.approvedHours,
                    onApprove: (info.status == StaffAttendanceStatus.clocked ||
                                info.status == StaffAttendanceStatus.sheet)
                        ? () => _approveIndividual(staff, info)
                        : null,
                    onEdit: (info.status == StaffAttendanceStatus.clocked ||
                             info.status == StaffAttendanceStatus.sheet)
                        ? () => _editStaffHours(staff, info)
                        : null,
                  );
                }),

                // Spacer for bottom bar
                const SizedBox(height: 80),
              ],
            ),
          ),

          // Bottom action bar
          _buildBottomBar(context, l10n),
        ],
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context, AppLocalizations l10n) {
    final readyCount = _readyToApproveCount;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: AppColors.backgroundWhite,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Approve All Ready button
            Expanded(
              flex: 3,
              child: FilledButton.icon(
                onPressed: readyCount > 0 && !_isBulkApproving
                    ? _bulkApprove
                    : null,
                icon: _isBulkApproving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_circle, size: 20),
                label: Text(l10n.approveAllReady(readyCount)),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.success,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Upload Sheet button
            Expanded(
              flex: 2,
              child: OutlinedButton.icon(
                onPressed: _isAnalyzing ? null : _uploadSheet,
                icon: const Icon(Icons.camera_alt, size: 20),
                label: Text(l10n.uploadSheet),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _approveIndividual(
    Map<String, dynamic> staff,
    _StaffAttendanceInfo info,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final name = staff['name']?.toString() ??
        '${staff['first_name'] ?? ''} ${staff['last_name'] ?? ''}'.trim();
    final hours = info.approvedHours ?? info.estimatedHours ?? 0.0;
    final userKey = staff['userKey']?.toString() ?? '';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.approveDigitalHours),
        content: Text(l10n.approveIndividualConfirm(
          hours.toStringAsFixed(2),
          name,
        )),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.success),
            child: Text(l10n.approveDigitalHours),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      final eventId = _event['_id'] ?? _event['id'];
      await _service.approveHours(
        eventId: eventId.toString(),
        userKey: userKey,
        approvedHours: hours,
        approvedBy: 'Manager',
      );

      setState(() {
        _locallyApproved.add(userKey);
        _error = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n.approvedStatus}: $name — ${hours.toStringAsFixed(2)} hrs'),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _error = '${l10n.failedToSubmitHours}: $e';
      });
    }
  }

  Future<void> _editStaffHours(
    Map<String, dynamic> staff,
    _StaffAttendanceInfo info,
  ) async {
    final name = staff['name']?.toString() ??
        '${staff['first_name'] ?? ''} ${staff['last_name'] ?? ''}'.trim();

    final result = await showDialog<HoursAdjustResult>(
      context: context,
      builder: (context) => HoursAdjustDialog(
        staffName: name,
        clockInAt: info.clockInAt,
        clockOutAt: info.clockOutAt,
        estimatedHours: info.estimatedHours,
        currentApprovedHours: info.approvedHours,
      ),
    );

    if (result == null || !mounted) return;

    final l10n = AppLocalizations.of(context)!;
    final userKey = staff['userKey']?.toString() ?? '';

    try {
      final eventId = _event['_id'] ?? _event['id'];
      await _service.approveHours(
        eventId: eventId.toString(),
        userKey: userKey,
        approvedHours: result.hours,
        approvedBy: 'Manager',
        notes: result.note,
      );

      setState(() {
        _locallyApproved.add(userKey);
        _error = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n.approvedStatus}: $name — ${result.hours.toStringAsFixed(2)} hrs'),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _error = '${l10n.failedToSubmitHours}: $e';
      });
    }
  }

  Future<void> _bulkApprove() async {
    final l10n = AppLocalizations.of(context)!;
    final readyCount = _readyToApproveCount;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.bulkApprove),
        content: Text(l10n.confirmApproveAll(readyCount)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.success),
            child: Text(l10n.approveAll),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() {
      _isBulkApproving = true;
      _error = null;
    });

    try {
      final eventId = _event['_id'] ?? _event['id'];
      final result = await _service.bulkApproveHours(
        eventId: eventId.toString(),
        approvedBy: 'Manager',
      );

      if (mounted) {
        // Mark all ready staff as locally approved
        for (final staff in _acceptedStaff) {
          final info = _getAttendanceInfo(staff);
          if (info.status == StaffAttendanceStatus.clocked ||
              info.status == StaffAttendanceStatus.sheet) {
            _locallyApproved.add(staff['userKey']?.toString() ?? '');
          }
        }

        setState(() {
          _isBulkApproving = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.hoursApprovedSuccess(result.approvedCount)),
            backgroundColor: AppColors.success,
          ),
        );

        // If all approved, pop with success
        if (_readyToApproveCount == 0) {
          Navigator.of(context).pop(true);
        }
      }
    } catch (e) {
      setState(() {
        _isBulkApproving = false;
        _error = '${l10n.failedToSubmitHours}: $e';
      });
    }
  }

  Future<void> _uploadSheet() async {
    final l10n = AppLocalizations.of(context)!;

    // Show source picker
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: Text(l10n.camera),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: Text(l10n.gallery),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image == null || !mounted) return;

      setState(() {
        _isAnalyzing = true;
        _error = null;
      });

      // Read and encode
      final bytes = await File(image.path).readAsBytes();
      final base64Image = base64Encode(bytes);
      final eventId = (_event['_id'] ?? _event['id']).toString();
      final filename = 'sheet_${DateTime.now().millisecondsSinceEpoch}.jpg';

      // Run R2 upload + AI analysis in parallel
      String sheetUrl = image.path; // fallback to local path
      final results = await Future.wait([
        _uploadService
            .uploadSignInSheetBytes(eventId, bytes, filename)
            .then((url) => sheetUrl = url)
            .catchError((_) => sheetUrl), // silently fall back
        _service.analyzeSignInSheet(
          eventId: eventId,
          imageBase64: base64Image,
        ),
      ]);

      final result = results[1] as TimesheetAnalysisResult;

      // Submit the extracted hours
      if (result.staffHours.isNotEmpty) {
        final hoursWithCalculation = result.staffHours.map((sh) {
          final calculated = sh.calculateHours();
          return sh.copyWith(approvedHours: calculated);
        }).toList();

        await _service.submitHours(
          eventId: eventId,
          staffHours: hoursWithCalculation,
          sheetPhotoUrl: sheetUrl,
          submittedBy: 'Manager',
        );

        // Refresh event data to show updated attendance
        // For now, show success and let user see the changes
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${result.staffHours.length} staff hours extracted from sheet',
              ),
              backgroundColor: AppColors.success,
            ),
          );
        }
      }

      setState(() {
        _isAnalyzing = false;
      });
    } catch (e) {
      setState(() {
        _isAnalyzing = false;
        _error = '${l10n.analysisFailed}: $e';
      });
    }
  }
}

class _StaffAttendanceInfo {
  final StaffAttendanceStatus status;
  final DateTime? clockInAt;
  final DateTime? clockOutAt;
  final double? estimatedHours;
  final double? approvedHours;

  const _StaffAttendanceInfo({
    required this.status,
    this.clockInAt,
    this.clockOutAt,
    this.estimatedHours,
    this.approvedHours,
  });
}
