import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;

import 'image_preview_card.dart';

/// Full-width preview card for documents being processed for extraction
class DocumentPreviewCard extends StatelessWidget {
  final File documentFile;
  final ExtractionStatus status;
  final String? errorMessage;
  final VoidCallback onRemove;

  const DocumentPreviewCard({
    super.key,
    required this.documentFile,
    required this.status,
    this.errorMessage,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    // Get file size in KB or MB
    final fileSize = documentFile.lengthSync();
    final fileSizeStr = fileSize > 1024 * 1024
        ? '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB'
        : '${(fileSize / 1024).toStringAsFixed(0)} KB';

    // Get filename and extension
    final fileName = path.basename(documentFile.path);
    final extension = path.extension(documentFile.path).toLowerCase();

    // File type icon and color based on extension
    IconData fileIcon;
    Color fileIconColor;

    switch (extension) {
      case '.pdf':
        fileIcon = Icons.picture_as_pdf;
        fileIconColor = Colors.red.shade600;
        break;
      case '.xlsx':
      case '.xls':
        fileIcon = Icons.table_chart;
        fileIconColor = Colors.green.shade600;
        break;
      case '.docx':
      case '.doc':
        fileIcon = Icons.description;
        fileIconColor = Colors.blue.shade600;
        break;
      case '.txt':
        fileIcon = Icons.text_snippet;
        fileIconColor = Colors.grey.shade600;
        break;
      case '.csv':
        fileIcon = Icons.grid_on;
        fileIconColor = Colors.orange.shade600;
        break;
      default:
        fileIcon = Icons.insert_drive_file;
        fileIconColor = Colors.grey.shade600;
    }

    // Status color and icon
    Color statusColor;
    IconData? statusIcon;
    String statusText;

    switch (status) {
      case ExtractionStatus.pending:
        statusColor = Colors.grey.shade600;
        statusIcon = Icons.schedule;
        statusText = 'Pending';
        break;
      case ExtractionStatus.extracting:
        statusColor = Colors.blue;
        statusIcon = null; // Show spinner instead
        statusText = 'Extracting data...';
        break;
      case ExtractionStatus.completed:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        statusText = 'Extracted successfully';
        break;
      case ExtractionStatus.failed:
        statusColor = Colors.red;
        statusIcon = Icons.error;
        statusText = errorMessage ?? 'Extraction failed';
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: status == ExtractionStatus.extracting
              ? Colors.blue.shade300
              : Colors.grey.shade300,
          width: status == ExtractionStatus.extracting ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // File icon
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: fileIconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                fileIcon,
                size: 32,
                color: fileIconColor,
              ),
            ),
            const SizedBox(width: 12),

            // File info and status
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Filename
                  Text(
                    fileName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),

                  // File size and type
                  Text(
                    '${extension.toUpperCase().substring(1)} • $fileSizeStr',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Status row
                  Row(
                    children: [
                      // Status indicator (spinner or icon)
                      if (status == ExtractionStatus.extracting)
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                          ),
                        )
                      else if (statusIcon != null)
                        Icon(
                          statusIcon,
                          size: 14,
                          color: statusColor,
                        ),
                      const SizedBox(width: 6),

                      // Status text
                      Expanded(
                        child: Text(
                          statusText,
                          style: TextStyle(
                            fontSize: 12,
                            color: statusColor,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Remove button
            InkWell(
              onTap: onRemove,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  Icons.close,
                  size: 20,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
