import 'dart:io';

import 'package:flutter/material.dart';

/// Status of image extraction
enum ExtractionStatus {
  pending,
  extracting,
  completed,
  failed,
}

/// Full-width preview card for images being processed for OCR extraction
class ImagePreviewCard extends StatelessWidget {
  final File imageFile;
  final ExtractionStatus status;
  final String? errorMessage;
  final VoidCallback onRemove;

  const ImagePreviewCard({
    super.key,
    required this.imageFile,
    required this.status,
    this.errorMessage,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    // Get file size in KB or MB
    final fileSize = imageFile.lengthSync();
    final fileSizeStr = fileSize > 1024 * 1024
        ? '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB'
        : '${(fileSize / 1024).toStringAsFixed(0)} KB';

    // Get filename
    final fileName = imageFile.path.split('/').last;

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
        statusText = 'Extracting text...';
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
            // Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                imageFile,
                width: 60,
                height: 60,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 60,
                    height: 60,
                    color: Colors.grey.shade200,
                    child: Icon(
                      Icons.broken_image,
                      color: Colors.grey.shade400,
                    ),
                  );
                },
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

                  // File size
                  Text(
                    fileSizeStr,
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
