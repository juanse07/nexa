import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/presentation/theme/app_colors.dart';
import '../../../shared/services/error_display_service.dart';
import '../providers/bulk_extraction_provider.dart';
import '../../main/presentation/main_screen.dart';

/// Screen for bulk importing multiple files and creating events from them.
/// Supports PDFs and images with automatic AI extraction.
///
/// Use default constructor for the full file-selection flow.
/// Use [BulkExtractionScreen.preloaded] when events were already extracted
/// (e.g. from AI Chat image/PDF with multiple events).
class BulkExtractionScreen extends StatefulWidget {
  final File? preloadedFile;
  final List<Map<String, dynamic>>? preloadedEvents;

  const BulkExtractionScreen({super.key})
      : preloadedFile = null,
        preloadedEvents = null;

  const BulkExtractionScreen.preloaded({
    super.key,
    required this.preloadedFile,
    required this.preloadedEvents,
  });

  @override
  State<BulkExtractionScreen> createState() => _BulkExtractionScreenState();
}

class _BulkExtractionScreenState extends State<BulkExtractionScreen>
    with SingleTickerProviderStateMixin {
  late BulkExtractionProvider _provider;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _provider = BulkExtractionProvider();

    // Pulse animation for processing indicator
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    // If launched with pre-extracted data, skip to preview phase
    if (widget.preloadedFile != null && widget.preloadedEvents != null) {
      _provider.loadPreExtractedEvents(
        file: widget.preloadedFile!,
        events: widget.preloadedEvents!,
      );
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _provider.dispose();
    super.dispose();
  }

  Future<void> _selectFiles() async {
    HapticFeedback.selectionClick();

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'heic'],
        allowMultiple: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final files = result.files
            .where((f) => f.path != null)
            .map((f) => File(f.path!))
            .toList();

        _provider.addFiles(files);
      }
    } catch (e) {
      if (mounted) {
        ErrorDisplayService.showErrorFromException(context, e, prefix: 'Failed to select files');
      }
    }
  }

  Future<void> _startExtraction() async {
    HapticFeedback.mediumImpact();
    await _provider.extractAllFiles();
  }

  Future<void> _createEvents() async {
    HapticFeedback.mediumImpact();
    await _provider.createSelectedEvents();

    if (mounted && _provider.successCount > 0) {
      HapticFeedback.heavyImpact();
    }
  }

  void _cancelProcessing() {
    HapticFeedback.mediumImpact();
    _provider.cancel();
  }

  void _navigateToPending() {
    HapticFeedback.selectionClick();
    Navigator.of(context).pushAndRemoveUntil<void>(
      MaterialPageRoute<void>(
        builder: (context) => const MainScreen(initialIndex: 0),
      ),
      (route) => false,
    );
  }

  void _importMore() {
    HapticFeedback.selectionClick();
    _provider.reset();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _provider,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: _buildAppBar(),
        body: Consumer<BulkExtractionProvider>(
          builder: (context, provider, child) {
            switch (provider.phase) {
              case BulkPhase.selectFiles:
                if (provider.hasFiles) {
                  return _buildFileListView(provider);
                }
                return _buildEmptyState();
              case BulkPhase.extracting:
                return _buildExtractingView(provider);
              case BulkPhase.preview:
                return _buildPreviewView(provider);
              case BulkPhase.creating:
                return _buildCreatingView(provider);
              case BulkPhase.complete:
                return _buildCompletionView(provider);
            }
          },
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.navySpaceCadet,
      foregroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: const Text(
        'Bulk Import',
        style: TextStyle(fontWeight: FontWeight.w600),
      ),
      actions: [
        Consumer<BulkExtractionProvider>(
          builder: (context, provider, child) {
            if (provider.hasFiles && provider.phase == BulkPhase.selectFiles) {
              return IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () {
                  HapticFeedback.selectionClick();
                  provider.clearAll();
                },
                tooltip: 'Clear all',
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.techBlue.withValues(alpha: 0.1),
                    AppColors.oceanBlue.withValues(alpha: 0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                Icons.folder_copy_outlined,
                size: 80,
                color: AppColors.techBlue.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'Bulk Import Events',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Select multiple PDFs or images.\nAI will extract event details for\nyou to review before creating.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 40),
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.techBlue, AppColors.oceanBlue],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.techBlue.withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: _selectFiles,
                icon: const Icon(Icons.add_photo_alternate_outlined, size: 22),
                label: const Text('Select Files'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  textStyle: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Supports PDF, JPG, PNG, HEIC',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── File List (before extraction) ───

  Widget _buildFileListView(BulkExtractionProvider provider) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: provider.files.length,
            itemBuilder: (context, index) {
              return _buildFileCard(provider.files[index], index, provider);
            },
          ),
        ),
        _buildFileListActions(provider),
      ],
    );
  }

  Widget _buildFileListActions(BulkExtractionProvider provider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _selectFiles,
                icon: const Icon(Icons.add, size: 20),
                label: const Text('Add Files'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.techBlue,
                  side: const BorderSide(color: AppColors.techBlue),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.techBlue, AppColors.oceanBlue],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.techBlue.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: _startExtraction,
                  icon: const Icon(Icons.auto_awesome, size: 20),
                  label: Text('Extract ${provider.totalFiles} Files'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Extracting Phase ───

  Widget _buildExtractingView(BulkExtractionProvider provider) {
    return Column(
      children: [
        _buildProgressHeader(provider, 'Extracting Events...'),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: provider.files.length,
            itemBuilder: (context, index) {
              return _buildFileCard(provider.files[index], index, provider);
            },
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton.icon(
              onPressed: _cancelProcessing,
              icon: const Icon(Icons.stop, size: 20),
              label: const Text('Cancel'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.warning,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ─── Preview Phase ───

  Widget _buildPreviewView(BulkExtractionProvider provider) {
    final l10n = AppLocalizations.of(context)!;
    final allEvents = provider.allExtractedEvents;
    final allSelected = allEvents.every((e) => e.isSelected);

    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${provider.totalExtractedEvents} events found across ${provider.extractedFileCount} files',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Tap to edit individual events',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
              const SizedBox(height: 8),
              // Select all toggle + Edit All button
              Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      if (allSelected) {
                        provider.deselectAll();
                      } else {
                        provider.selectAll();
                      }
                    },
                    child: Row(
                      children: [
                        Icon(
                          allSelected
                              ? Icons.check_box
                              : Icons.check_box_outline_blank,
                          color: AppColors.techBlue,
                          size: 22,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          allSelected ? l10n.deselectAll : l10n.selectAll,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.techBlue,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: provider.selectedCount > 0
                        ? () => _showBulkEditSheet(context, provider)
                        : null,
                    icon: const Icon(Icons.edit_note, size: 18),
                    label: Text(l10n.editAllSelected),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.techBlue,
                      side: const BorderSide(color: AppColors.techBlue),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      textStyle: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // Event cards grouped by file
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: provider.files.length,
            itemBuilder: (context, fileIdx) {
              final file = provider.files[fileIdx];
              if (file.extractedEvents.isEmpty && file.status != BulkFileStatus.failed) {
                return const SizedBox.shrink();
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // File header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 8, 4, 6),
                    child: Row(
                      children: [
                        Icon(
                          file.isImage ? Icons.image_outlined : Icons.picture_as_pdf_outlined,
                          size: 16,
                          color: Colors.grey.shade500,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            file.fileName,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (file.status == BulkFileStatus.failed)
                          Text(
                            file.errorMessage ?? 'No events found',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.red,
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Event cards
                  ...file.extractedEvents.asMap().entries.map((entry) {
                    final eventIdx = entry.key;
                    final event = entry.value;
                    return _ExtractedEventCard(
                      event: event,
                      onToggle: () => provider.toggleEvent(fileIdx, eventIdx),
                      onTap: () => _editEvent(context, provider, fileIdx, eventIdx, event),
                    );
                  }),
                  const SizedBox(height: 8),
                ],
              );
            },
          ),
        ),

        // Bottom action bar
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: Container(
              decoration: BoxDecoration(
                gradient: provider.selectedCount > 0
                    ? const LinearGradient(
                        colors: [AppColors.techBlue, AppColors.oceanBlue],
                      )
                    : null,
                color: provider.selectedCount > 0 ? null : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(14),
              ),
              child: ElevatedButton.icon(
                onPressed: provider.selectedCount > 0 ? _createEvents : null,
                icon: const Icon(Icons.check_circle_outline, size: 20),
                label: Text('Create ${provider.selectedCount} Selected'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.transparent,
                  disabledForegroundColor: Colors.grey.shade500,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _editEvent(
    BuildContext context,
    BulkExtractionProvider provider,
    int fileIdx,
    int eventIdx,
    BulkExtractedEventItem event,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: _EventEditSheet(
          eventData: Map<String, dynamic>.from(event.data),
          onSave: (editedData) {
            provider.updateEventData(fileIdx, eventIdx, editedData);
          },
        ),
      ),
    );
  }

  void _showBulkEditSheet(
    BuildContext context,
    BulkExtractionProvider provider,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: _BulkEditBottomSheet(
          selectedCount: provider.selectedCount,
          onApply: (edits) => provider.applyBulkEdit(edits),
        ),
      ),
    );
  }

  // ─── Creating Phase ───

  Widget _buildCreatingView(BulkExtractionProvider provider) {
    final selected = provider.allExtractedEvents
        .where((e) => e.isSelected)
        .toList();
    final done = selected.where((e) => e.created || e.errorMessage != null).length;
    final progress = selected.isNotEmpty ? done / selected.length : 0.0;

    return Column(
      children: [
        LinearProgressIndicator(
          value: progress,
          backgroundColor: AppColors.techBlue.withValues(alpha: 0.15),
          color: AppColors.techBlue,
          minHeight: 3,
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: selected.length,
            itemBuilder: (context, index) {
              final e = selected[index];
              final title = _buildTitle(e.data);

              IconData icon;
              Color iconColor;
              if (e.created) {
                icon = Icons.check_circle;
                iconColor = AppColors.success;
              } else if (e.errorMessage != null) {
                icon = Icons.error;
                iconColor = AppColors.errorDark;
              } else {
                icon = Icons.hourglass_top;
                iconColor = Colors.orange;
              }

              return ListTile(
                leading: Icon(icon, color: iconColor, size: 22),
                title: Text(
                  title,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
                subtitle: e.errorMessage != null
                    ? Text(
                        e.errorMessage!,
                        style: const TextStyle(fontSize: 12, color: Colors.red),
                      )
                    : null,
                dense: true,
              );
            },
          ),
        ),
      ],
    );
  }

  // ─── Shared Helpers ───

  Widget _buildProgressHeader(BulkExtractionProvider provider, String label) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.techBlue, AppColors.oceanBlue],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.techBlue.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            height: 56,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: provider.extractionProgress,
                  strokeWidth: 5,
                  backgroundColor: Colors.white24,
                  valueColor: const AlwaysStoppedAnimation(Colors.white),
                ),
                Text(
                  '${provider.extractedFileCount}/${provider.totalFiles}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${provider.totalExtractedEvents} events found',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2 + _pulseController.value * 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFileCard(BulkFileItem item, int index, BulkExtractionProvider provider) {
    final isProcessing = item.status == BulkFileStatus.processing;
    final isSuccess = item.status == BulkFileStatus.success;
    final isFailed = item.status == BulkFileStatus.failed;

    Color borderColor = Colors.grey.shade300;
    if (isProcessing) borderColor = AppColors.techBlue;
    if (isSuccess) borderColor = AppColors.success;
    if (isFailed) borderColor = AppColors.errorDark;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: isProcessing
            ? [
                BoxShadow(
                  color: AppColors.techBlue.withValues(alpha: 0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: item.isImage
                  ? AppColors.oceanBlue.withValues(alpha: 0.1)
                  : AppColors.errorDark.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              item.isImage ? Icons.image_outlined : Icons.picture_as_pdf,
              size: 24,
              color: item.isImage ? AppColors.oceanBlue : AppColors.errorDark,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.fileName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                if (isFailed && item.errorMessage != null)
                  Text(
                    item.errorMessage!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.errorDark,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  )
                else
                  Text(
                    item.formattedSize,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                  ),
              ],
            ),
          ),
          _buildStatusIndicator(item.status),
          if (provider.phase == BulkPhase.selectFiles)
            IconButton(
              onPressed: () {
                HapticFeedback.selectionClick();
                provider.removeFile(index);
              },
              icon: Icon(
                Icons.close,
                size: 20,
                color: Colors.grey.shade400,
              ),
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusIndicator(BulkFileStatus status) {
    switch (status) {
      case BulkFileStatus.pending:
        return Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.hourglass_empty,
            size: 20,
            color: Colors.grey.shade400,
          ),
        );
      case BulkFileStatus.processing:
        return Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppColors.techBlue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.techBlue,
            ),
          ),
        );
      case BulkFileStatus.success:
        return Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.check_circle,
            size: 20,
            color: AppColors.success,
          ),
        );
      case BulkFileStatus.failed:
        return Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppColors.errorDark.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.error_outline,
            size: 20,
            color: AppColors.errorDark,
          ),
        );
    }
  }

  Widget _buildCompletionView(BulkExtractionProvider provider) {
    final hasSuccess = provider.successCount > 0;
    final hasFailed = provider.failedCount > 0;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: hasSuccess
                      ? [
                          AppColors.success.withValues(alpha: 0.15),
                          AppColors.success.withValues(alpha: 0.05),
                        ]
                      : [
                          AppColors.errorDark.withValues(alpha: 0.15),
                          AppColors.errorDark.withValues(alpha: 0.05),
                        ],
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                hasSuccess ? Icons.check_circle_outline : Icons.error_outline,
                size: 72,
                color: hasSuccess ? AppColors.success : AppColors.errorDark,
              ),
            ),
            const SizedBox(height: 28),
            Text(
              hasSuccess ? 'Import Complete!' : 'Import Failed',
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (hasSuccess) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle, color: AppColors.success, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          '${provider.successCount} created',
                          style: const TextStyle(
                            color: AppColors.success,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (hasSuccess && hasFailed) const SizedBox(width: 12),
                if (hasFailed) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.errorDark.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: AppColors.errorDark, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          '${provider.failedCount} failed',
                          style: const TextStyle(
                            color: AppColors.errorDark,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 40),
            if (hasSuccess)
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.techBlue, AppColors.oceanBlue],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.techBlue.withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: _navigateToPending,
                  icon: const Icon(Icons.visibility_outlined, size: 22),
                  label: const Text('View in Pending Tab'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: _importMore,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: const Text('Import More Files'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.techBlue,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Event Title Builder ───

String _buildTitle(Map<String, dynamic> data) {
  final rawTitle = data['event_name'] ?? data['title'];
  if (rawTitle != null && rawTitle.toString().trim().isNotEmpty) {
    return rawTitle.toString().trim();
  }
  final venue = (data['venue_name'] ?? data['location'])?.toString().trim() ?? '';
  final date = data['date']?.toString() ?? '';
  if (venue.isNotEmpty) return venue;
  if (date.isNotEmpty) {
    final parsed = DateTime.tryParse(date);
    if (parsed != null) return DateFormat('EEE, MMM d').format(parsed);
    return date;
  }
  return 'Event';
}

// ─── Extracted Event Card ───

class _ExtractedEventCard extends StatelessWidget {
  final BulkExtractedEventItem event;
  final VoidCallback onToggle;
  final VoidCallback onTap;

  const _ExtractedEventCard({
    required this.event,
    required this.onToggle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final data = event.data;
    final title = _buildTitle(data);
    final date = data['date']?.toString() ?? '';
    final startTime = data['start_time'] ?? '';
    final endTime = data['end_time'] ?? '';
    final venue = (data['venue_name'] ?? data['location'] ?? '').toString();

    String timeStr = '';
    if (startTime.toString().isNotEmpty) {
      timeStr = startTime.toString();
      if (endTime.toString().isNotEmpty) {
        timeStr += ' - ${endTime.toString()}';
      }
    }

    String dateStr = date;
    if (date.isNotEmpty) {
      final parsed = DateTime.tryParse(date);
      if (parsed != null) {
        dateStr = DateFormat('EEE, MMM d').format(parsed);
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 0,
      color: event.isSelected ? Colors.white : Colors.grey.shade100,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              GestureDetector(
                onTap: onToggle,
                child: Icon(
                  event.isSelected
                      ? Icons.check_box
                      : Icons.check_box_outline_blank,
                  color: event.isSelected
                      ? AppColors.techBlue
                      : Colors.grey.shade400,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: event.isSelected
                            ? AppColors.textDark
                            : Colors.grey.shade500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (dateStr.isNotEmpty) ...[
                          Icon(Icons.calendar_today,
                              size: 12, color: Colors.grey.shade500),
                          const SizedBox(width: 3),
                          Text(
                            dateStr,
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade600),
                          ),
                          const SizedBox(width: 10),
                        ],
                        if (timeStr.isNotEmpty) ...[
                          Icon(Icons.access_time,
                              size: 12, color: Colors.grey.shade500),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(
                              timeStr,
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey.shade600),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (venue.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        venue,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              Icon(Icons.edit_outlined, size: 16, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Single Event Edit Sheet (simple key-value editor) ───

class _EventEditSheet extends StatefulWidget {
  final Map<String, dynamic> eventData;
  final void Function(Map<String, dynamic>) onSave;

  const _EventEditSheet({required this.eventData, required this.onSave});

  @override
  State<_EventEditSheet> createState() => _EventEditSheetState();
}

class _EventEditSheetState extends State<_EventEditSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _venueController;
  late final TextEditingController _notesController;
  late final TextEditingController _uniformController;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  late DateTime _date;

  @override
  void initState() {
    super.initState();
    final d = widget.eventData;
    _nameController = TextEditingController(text: (d['event_name'] ?? d['title'] ?? '').toString());
    _venueController = TextEditingController(text: (d['venue_name'] ?? d['location'] ?? '').toString());
    _notesController = TextEditingController(text: (d['notes'] ?? '').toString());
    _uniformController = TextEditingController(text: (d['uniform'] ?? '').toString());

    _startTime = _parseTime(d['start_time']) ?? const TimeOfDay(hour: 9, minute: 0);
    _endTime = _parseTime(d['end_time']) ?? const TimeOfDay(hour: 17, minute: 0);
    _date = DateTime.tryParse(d['date']?.toString() ?? '') ?? DateTime.now();
  }

  TimeOfDay? _parseTime(dynamic val) {
    if (val == null) return null;
    final s = val.toString();
    final parts = s.split(':');
    if (parts.length >= 2) {
      final h = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      if (h != null && m != null) return TimeOfDay(hour: h, minute: m);
    }
    return null;
  }

  String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  void _save() {
    final data = Map<String, dynamic>.from(widget.eventData);
    data['event_name'] = _nameController.text.trim();
    data['venue_name'] = _venueController.text.trim();
    data['notes'] = _notesController.text.trim();
    data['uniform'] = _uniformController.text.trim();
    data['start_time'] = _formatTime(_startTime);
    data['end_time'] = _formatTime(_endTime);
    data['date'] = DateFormat('yyyy-MM-dd').format(_date);
    widget.onSave(data);
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _venueController.dispose();
    _notesController.dispose();
    _uniformController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Icon(Icons.edit_outlined, color: AppColors.techBlue, size: 22),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Edit Event',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textDark),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Column(
                children: [
                  TextField(
                    controller: _nameController,
                    decoration: InputDecoration(labelText: 'Event Name', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _date,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) setState(() => _date = picked);
                    },
                    child: InputDecorator(
                      decoration: InputDecoration(labelText: 'Date', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                      child: Text(DateFormat('EEE, MMM d, yyyy').format(_date)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final picked = await showTimePicker(context: context, initialTime: _startTime);
                            if (picked != null) setState(() => _startTime = picked);
                          },
                          child: InputDecorator(
                            decoration: InputDecoration(labelText: l10n.startTime, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                            child: Text(_startTime.format(context)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final picked = await showTimePicker(context: context, initialTime: _endTime);
                            if (picked != null) setState(() => _endTime = picked);
                          },
                          child: InputDecorator(
                            decoration: InputDecoration(labelText: l10n.endTime, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                            child: Text(_endTime.format(context)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _venueController,
                    decoration: InputDecoration(labelText: 'Venue', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _uniformController,
                    decoration: InputDecoration(labelText: 'Uniform', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _notesController,
                    maxLines: 2,
                    decoration: InputDecoration(labelText: l10n.notes, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                  ),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.techBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: Text(l10n.save),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Bulk Edit Bottom Sheet ───

class _BulkEditBottomSheet extends StatefulWidget {
  final int selectedCount;
  final void Function(Map<String, dynamic> edits) onApply;

  const _BulkEditBottomSheet({
    required this.selectedCount,
    required this.onApply,
  });

  @override
  State<_BulkEditBottomSheet> createState() => _BulkEditBottomSheetState();
}

class _BulkEditBottomSheetState extends State<_BulkEditBottomSheet> {
  bool _useStartTime = false;
  bool _useEndTime = false;
  bool _useVenue = false;
  bool _useUniform = false;
  bool _useNotes = false;
  bool _useContact = false;
  bool _useParking = false;

  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 17, minute: 0);
  final _venueController = TextEditingController();
  final _uniformController = TextEditingController();
  final _notesController = TextEditingController();
  final _contactController = TextEditingController();
  final _parkingController = TextEditingController();

  @override
  void dispose() {
    _venueController.dispose();
    _uniformController.dispose();
    _notesController.dispose();
    _contactController.dispose();
    _parkingController.dispose();
    super.dispose();
  }

  String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _pickTime(BuildContext context, bool isStart) async {
    final initial = isStart ? _startTime : _endTime;
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
          _useStartTime = true;
        } else {
          _endTime = picked;
          _useEndTime = true;
        }
      });
    }
  }

  void _apply() {
    final edits = <String, dynamic>{};
    if (_useStartTime) edits['start_time'] = _formatTime(_startTime);
    if (_useEndTime) edits['end_time'] = _formatTime(_endTime);
    if (_useVenue && _venueController.text.trim().isNotEmpty) {
      edits['venue_name'] = _venueController.text.trim();
    }
    if (_useUniform && _uniformController.text.trim().isNotEmpty) {
      edits['uniform'] = _uniformController.text.trim();
    }
    if (_useNotes && _notesController.text.trim().isNotEmpty) {
      edits['notes'] = _notesController.text.trim();
    }
    if (_useContact && _contactController.text.trim().isNotEmpty) {
      edits['contact_name'] = _contactController.text.trim();
    }
    if (_useParking && _parkingController.text.trim().isNotEmpty) {
      edits['parking_instructions'] = _parkingController.text.trim();
    }

    if (edits.isNotEmpty) {
      widget.onApply(edits);
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Icon(Icons.edit_note, color: AppColors.techBlue, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.bulkEditTitle,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.techBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${widget.selectedCount}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.techBlue,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                l10n.bulkEditHint,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),

          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                children: [
                  _ToggleFieldRow(
                    checked: _useStartTime,
                    onChecked: (v) => setState(() => _useStartTime = v),
                    label: l10n.startTime,
                    child: InkWell(
                      onTap: () => _pickTime(context, true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.access_time, size: 16, color: Colors.grey.shade600),
                            const SizedBox(width: 6),
                            Text(_startTime.format(context), style: const TextStyle(fontSize: 14)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  _ToggleFieldRow(
                    checked: _useEndTime,
                    onChecked: (v) => setState(() => _useEndTime = v),
                    label: l10n.endTime,
                    child: InkWell(
                      onTap: () => _pickTime(context, false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.access_time, size: 16, color: Colors.grey.shade600),
                            const SizedBox(width: 6),
                            Text(_endTime.format(context), style: const TextStyle(fontSize: 14)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  _ToggleFieldRow(
                    checked: _useVenue,
                    onChecked: (v) => setState(() => _useVenue = v),
                    label: 'Venue',
                    child: Expanded(
                      child: TextField(
                        controller: _venueController,
                        onTap: () => setState(() => _useVenue = true),
                        decoration: InputDecoration(
                          hintText: 'e.g. Grand Ballroom',
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ),
                  _ToggleFieldRow(
                    checked: _useUniform,
                    onChecked: (v) => setState(() => _useUniform = v),
                    label: 'Uniform',
                    child: Expanded(
                      child: TextField(
                        controller: _uniformController,
                        onTap: () => setState(() => _useUniform = true),
                        decoration: InputDecoration(
                          hintText: 'e.g. Black pants, white shirt',
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ),
                  _ToggleFieldRow(
                    checked: _useContact,
                    onChecked: (v) => setState(() => _useContact = v),
                    label: 'Contact',
                    child: Expanded(
                      child: TextField(
                        controller: _contactController,
                        onTap: () => setState(() => _useContact = true),
                        decoration: InputDecoration(
                          hintText: 'e.g. John Smith',
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ),
                  _ToggleFieldRow(
                    checked: _useParking,
                    onChecked: (v) => setState(() => _useParking = v),
                    label: 'Parking',
                    child: Expanded(
                      child: TextField(
                        controller: _parkingController,
                        onTap: () => setState(() => _useParking = true),
                        decoration: InputDecoration(
                          hintText: 'e.g. Staff lot behind building',
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ),
                  _ToggleFieldRow(
                    checked: _useNotes,
                    onChecked: (v) => setState(() => _useNotes = v),
                    label: l10n.notes,
                    child: Expanded(
                      child: TextField(
                        controller: _notesController,
                        onTap: () => setState(() => _useNotes = true),
                        maxLines: 2,
                        decoration: InputDecoration(
                          hintText: 'e.g. Arrive 15 min early',
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _apply,
                icon: const Icon(Icons.check, size: 20),
                label: Text('${l10n.applyToSelected} (${widget.selectedCount})'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.techBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToggleFieldRow extends StatelessWidget {
  final bool checked;
  final ValueChanged<bool> onChecked;
  final String label;
  final Widget child;

  const _ToggleFieldRow({
    required this.checked,
    required this.onChecked,
    required this.label,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: Checkbox(
              value: checked,
              onChanged: (v) => onChecked(v ?? false),
              activeColor: AppColors.techBlue,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: checked ? AppColors.textDark : Colors.grey.shade500,
              ),
            ),
          ),
          const SizedBox(width: 8),
          child,
        ],
      ),
    );
  }
}
