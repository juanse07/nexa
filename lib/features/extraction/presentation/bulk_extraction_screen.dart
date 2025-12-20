import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../shared/presentation/theme/app_colors.dart';
import '../../../shared/services/error_display_service.dart';
import '../providers/bulk_extraction_provider.dart';
import '../../main/presentation/main_screen.dart';

/// Screen for bulk importing multiple files and creating events from them.
/// Supports PDFs and images with automatic AI extraction.
class BulkExtractionScreen extends StatefulWidget {
  const BulkExtractionScreen({super.key});

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
        ErrorDisplayService.showError(context, 'Failed to select files: $e');
      }
    }
  }

  Future<void> _startProcessing() async {
    HapticFeedback.mediumImpact();
    await _provider.processAllFiles();

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
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
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
            if (provider.isComplete) {
              return _buildCompletionView(provider);
            }
            if (provider.hasFiles) {
              return _buildProcessingView(provider);
            }
            return _buildEmptyState();
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
            if (provider.hasFiles && !provider.isProcessing && !provider.isComplete) {
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
              'Select multiple PDFs or images.\nAI will extract event details and\ncreate them automatically.',
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

  Widget _buildProcessingView(BulkExtractionProvider provider) {
    return Column(
      children: [
        // Progress header
        if (provider.isProcessing || provider.completedCount > 0)
          _buildProgressHeader(provider),

        // File list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: provider.files.length,
            itemBuilder: (context, index) {
              return _buildFileCard(provider.files[index], index, provider);
            },
          ),
        ),

        // Action buttons
        _buildBottomActions(provider),
      ],
    );
  }

  Widget _buildProgressHeader(BulkExtractionProvider provider) {
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
          // Circular progress
          SizedBox(
            width: 56,
            height: 56,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: provider.progress,
                  strokeWidth: 5,
                  backgroundColor: Colors.white24,
                  valueColor: const AlwaysStoppedAnimation(Colors.white),
                ),
                Text(
                  '${provider.completedCount}/${provider.totalFiles}',
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
          // Stats
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  provider.isProcessing ? 'Processing Files...' : 'Processing Paused',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (provider.successCount > 0) ...[
                      const Icon(Icons.check_circle, color: Colors.white70, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        '${provider.successCount} created',
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                    if (provider.successCount > 0 && provider.failedCount > 0)
                      const Text('  •  ', style: TextStyle(color: Colors.white54)),
                    if (provider.failedCount > 0) ...[
                      const Icon(Icons.error_outline, color: Colors.white70, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        '${provider.failedCount} failed',
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                    if (provider.successCount == 0 && provider.failedCount == 0)
                      Text(
                        '${provider.pendingCount} pending',
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                  ],
                ),
              ],
            ),
          ),
          // Processing indicator
          if (provider.isProcessing)
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
          // File type icon
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
          // File info
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
          // Status indicator
          _buildStatusIndicator(item.status),
          // Remove button (only when not processing)
          if (!provider.isProcessing && !provider.isComplete)
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

  Widget _buildBottomActions(BulkExtractionProvider provider) {
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
            // Add more files button
            if (!provider.isProcessing)
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
            if (!provider.isProcessing) const SizedBox(width: 12),
            // Process/Cancel button
            Expanded(
              flex: provider.isProcessing ? 1 : 2,
              child: provider.isProcessing
                  ? ElevatedButton.icon(
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
                    )
                  : Container(
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
                        onPressed: _startProcessing,
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

  Widget _buildCompletionView(BulkExtractionProvider provider) {
    final hasSuccess = provider.successCount > 0;
    final hasFailed = provider.failedCount > 0;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Success/partial success icon
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
            // Stats
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
            // Navigate to pending button
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
            // Import more button
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
