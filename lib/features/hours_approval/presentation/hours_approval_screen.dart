import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nexa/features/hours_approval/services/timesheet_extraction_service.dart';

class HoursApprovalScreen extends StatefulWidget {
  final Map<String, dynamic> event;

  const HoursApprovalScreen({
    super.key,
    required this.event,
  });

  @override
  State<HoursApprovalScreen> createState() => _HoursApprovalScreenState();
}

class _HoursApprovalScreenState extends State<HoursApprovalScreen> {
  final TimesheetExtractionService _service = TimesheetExtractionService();
  final ImagePicker _picker = ImagePicker();

  bool _isAnalyzing = false;
  bool _isSubmitting = false;
  List<StaffHours>? _extractedHours;
  String? _sheetPhotoPath;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Approve Hours'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Event info
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.event['event_name']?.toString() ?? 'Event',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.event['client_name']?.toString() ?? '',
                      style: theme.textTheme.bodyMedium,
                    ),
                    Text(
                      (widget.event['date']?.toString() ?? '').split('T').first,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Upload/Take photo section
            if (_sheetPhotoPath == null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Icon(
                        Icons.camera_alt,
                        size: 64,
                        color: theme.colorScheme.primary.withOpacity(0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Upload Sign-In Sheet',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Take a photo or upload the client\'s sign-in/out sheet',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ElevatedButton.icon(
                            onPressed: () => _pickImage(ImageSource.camera),
                            icon: const Icon(Icons.camera),
                            label: const Text('Camera'),
                          ),
                          ElevatedButton.icon(
                            onPressed: () => _pickImage(ImageSource.gallery),
                            icon: const Icon(Icons.photo_library),
                            label: const Text('Gallery'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // Show photo preview and analysis
            if (_sheetPhotoPath != null) ...[
              Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    Image.file(
                      File(_sheetPhotoPath!),
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Row(
                        children: [
                          TextButton.icon(
                            onPressed: () {
                              setState(() {
                                _sheetPhotoPath = null;
                                _extractedHours = null;
                                _error = null;
                              });
                            },
                            icon: const Icon(Icons.close),
                            label: const Text('Remove'),
                          ),
                          const Spacer(),
                          if (_extractedHours == null && !_isAnalyzing)
                            ElevatedButton.icon(
                              onPressed: _analyzeSheet,
                              icon: const Icon(Icons.auto_awesome),
                              label: const Text('Analyze with AI'),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Loading indicator
            if (_isAnalyzing)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Analyzing sign-in sheet with AI...'),
                    ],
                  ),
                ),
              ),

            // Error message
            if (_error != null)
              Card(
                color: theme.colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: theme.colorScheme.error,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _error!,
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Extracted hours list
            if (_extractedHours != null && _extractedHours!.isNotEmpty) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Extracted Staff Hours',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Review and edit before submitting',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              ..._extractedHours!.asMap().entries.map((entry) {
                final index = entry.key;
                final hours = entry.value;
                final calculatedHours = hours.calculateHours();

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    hours.name,
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    hours.role,
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () => _editStaffHours(index, hours),
                            ),
                          ],
                        ),
                        const Divider(),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Sign In',
                                    style: theme.textTheme.labelSmall,
                                  ),
                                  Text(hours.signInTime ?? 'N/A'),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Sign Out',
                                    style: theme.textTheme.labelSmall,
                                  ),
                                  Text(hours.signOutTime ?? 'N/A'),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (calculatedHours != null) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.schedule,
                                  size: 16,
                                  color: theme.colorScheme.onPrimaryContainer,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '$calculatedHours hours',
                                  style: TextStyle(
                                    color: theme.colorScheme.onPrimaryContainer,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        if (hours.notes != null && hours.notes!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Notes: ${hours.notes}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 16),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isSubmitting ? null : _submitForReview,
                      icon: const Icon(Icons.send),
                      label: const Text('Submit for Review'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _isSubmitting ? null : _bulkApprove,
                      icon: const Icon(Icons.check_circle),
                      label: const Text('Bulk Approve'),
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

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _sheetPhotoPath = image.path;
          _extractedHours = null;
          _error = null;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to pick image: $e';
      });
    }
  }

  Future<void> _analyzeSheet() async {
    if (_sheetPhotoPath == null) return;

    setState(() {
      _isAnalyzing = true;
      _error = null;
    });

    try {
      // Read image and convert to base64
      final bytes = await File(_sheetPhotoPath!).readAsBytes();
      final base64Image = base64Encode(bytes);

      // Call AI analysis
      final eventId = widget.event['_id'] ?? widget.event['id'];
      final result = await _service.analyzeSignInSheet(
        eventId: eventId.toString(),
        imageBase64: base64Image,
      );

      // Auto-calculate hours for each staff member
      final hoursWithCalculation = result.staffHours.map((sh) {
        final calculated = sh.calculateHours();
        return sh.copyWith(approvedHours: calculated);
      }).toList();

      setState(() {
        _extractedHours = hoursWithCalculation;
        _isAnalyzing = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Analysis failed: $e';
        _isAnalyzing = false;
      });
    }
  }

  Future<void> _editStaffHours(int index, StaffHours hours) async {
    final result = await showDialog<StaffHours>(
      context: context,
      builder: (context) => _EditHoursDialog(hours: hours),
    );

    if (result != null) {
      setState(() {
        _extractedHours![index] = result;
      });
    }
  }

  Future<void> _submitForReview() async {
    if (_extractedHours == null || _sheetPhotoPath == null) return;

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      final eventId = widget.event['_id'] ?? widget.event['id'];
      final result = await _service.submitHours(
        eventId: eventId.toString(),
        staffHours: _extractedHours!,
        sheetPhotoUrl: _sheetPhotoPath!,
        submittedBy: 'Manager', // TODO: Get actual user
      );

      if (mounted) {
        // Show match results
        if (result.unmatchedCount > 0) {
          await _showMatchResults(result);
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: result.processedCount > 0 ? Colors.green : Colors.orange,
          ),
        );

        if (result.processedCount > 0) {
          Navigator.of(context).pop(true);
        } else {
          setState(() {
            _isSubmitting = false;
          });
        }
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to submit: $e';
        _isSubmitting = false;
      });
    }
  }

  Future<void> _bulkApprove() async {
    if (_extractedHours == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bulk Approve'),
        content: Text(
          'Approve hours for all ${_extractedHours!.length} staff members?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Approve All'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      // First submit the hours
      final eventId = widget.event['_id'] ?? widget.event['id'];
      final submitResult = await _service.submitHours(
        eventId: eventId.toString(),
        staffHours: _extractedHours!,
        sheetPhotoUrl: _sheetPhotoPath!,
        submittedBy: 'Manager', // TODO: Get actual user
      );

      // Show match results if any didn't match
      if (submitResult.unmatchedCount > 0 && mounted) {
        await _showMatchResults(submitResult);
      }

      // If no hours were matched, don't proceed with approval
      if (submitResult.processedCount == 0) {
        if (mounted) {
          setState(() {
            _error = 'No hours were matched. Please check the names on the sheet.';
            _isSubmitting = false;
          });
        }
        return;
      }

      // Then bulk approve
      final approveResult = await _service.bulkApproveHours(
        eventId: eventId.toString(),
        approvedBy: 'Manager', // TODO: Get actual user
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(approveResult.message),
            backgroundColor: approveResult.approvedCount > 0 ? Colors.green : Colors.orange,
          ),
        );

        if (approveResult.approvedCount > 0) {
          Navigator.of(context).pop(true);
        } else {
          setState(() {
            _error = 'No hours were approved. Check match results above.';
            _isSubmitting = false;
          });
        }
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to bulk approve: $e';
        _isSubmitting = false;
      });
    }
  }

  Future<void> _showMatchResults(SubmitHoursResult result) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              result.unmatchedCount > 0 ? Icons.warning : Icons.check_circle,
              color: result.unmatchedCount > 0 ? Colors.orange : Colors.green,
            ),
            const SizedBox(width: 8),
            const Text('Name Matching Results'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${result.processedCount}/${result.totalCount} staff members matched',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: result.matchResults.length,
                  itemBuilder: (context, index) {
                    final match = result.matchResults[index];
                    return Card(
                      color: match.matched ? Colors.green[50] : Colors.red[50],
                      child: ListTile(
                        leading: Icon(
                          match.matched ? Icons.check_circle : Icons.error,
                          color: match.matched ? Colors.green : Colors.red,
                        ),
                        title: Text(match.extractedName),
                        subtitle: match.matched
                            ? Text(
                                'Matched to: ${match.matchedName} (${match.similarity}% match)\nRole: ${match.extractedRole}',
                              )
                            : Text(match.reason ?? 'No match found'),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

class _EditHoursDialog extends StatefulWidget {
  final StaffHours hours;

  const _EditHoursDialog({required this.hours});

  @override
  State<_EditHoursDialog> createState() => _EditHoursDialogState();
}

class _EditHoursDialogState extends State<_EditHoursDialog> {
  late TextEditingController _signInController;
  late TextEditingController _signOutController;
  late TextEditingController _hoursController;
  late TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    _signInController = TextEditingController(text: widget.hours.signInTime);
    _signOutController = TextEditingController(text: widget.hours.signOutTime);
    _hoursController = TextEditingController(
      text: widget.hours.approvedHours?.toString() ?? '',
    );
    _notesController = TextEditingController(text: widget.hours.notes);
  }

  @override
  void dispose() {
    _signInController.dispose();
    _signOutController.dispose();
    _hoursController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Edit Hours - ${widget.hours.name}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _signInController,
              decoration: const InputDecoration(
                labelText: 'Sign In Time',
                hintText: '5:00 PM',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _signOutController,
              decoration: const InputDecoration(
                labelText: 'Sign Out Time',
                hintText: '11:30 PM',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _hoursController,
              decoration: const InputDecoration(
                labelText: 'Approved Hours',
                hintText: '6.5',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes',
                hintText: 'Optional notes',
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final updated = widget.hours.copyWith(
              signInTime: _signInController.text.trim(),
              signOutTime: _signOutController.text.trim(),
              approvedHours: double.tryParse(_hoursController.text.trim()),
              notes: _notesController.text.trim(),
            );
            Navigator.pop(context, updated);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
