import 'package:flutter/material.dart';

class ApplicantListTile extends StatelessWidget {
  const ApplicantListTile({
    super.key,
    required this.applicant,
    required this.onApprove,
    required this.onDeny,
    this.isLoading = false,
  });

  final Map<String, dynamic> applicant;
  final VoidCallback onApprove;
  final VoidCallback onDeny;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final name = (applicant['name'] ?? '').toString();
    final email = (applicant['email'] ?? '').toString();
    final appliedAt = applicant['appliedAt']?.toString() ?? '';

    final displayName = name.isNotEmpty
        ? name
        : email.isNotEmpty
            ? email
            : 'Unknown applicant';

    String formattedDate = '';
    if (appliedAt.isNotEmpty) {
      try {
        final date = DateTime.parse(appliedAt);
        final now = DateTime.now();
        final diff = now.difference(date);
        if (diff.inMinutes < 60) {
          formattedDate = '${diff.inMinutes}m ago';
        } else if (diff.inHours < 24) {
          formattedDate = '${diff.inHours}h ago';
        } else {
          formattedDate = '${diff.inDays}d ago';
        }
      } catch (_) {
        formattedDate = appliedAt;
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.orange.shade100,
              child: Icon(Icons.person_add, color: Colors.orange.shade700),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  if (email.isNotEmpty && name.isNotEmpty)
                    Text(
                      email,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  if (formattedDate.isNotEmpty)
                    Text(
                      'Applied $formattedDate',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                ],
              ),
            ),
            if (isLoading)
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else ...[
              IconButton(
                onPressed: onDeny,
                icon: const Icon(Icons.close),
                color: Colors.red,
                tooltip: 'Deny',
                style: IconButton.styleFrom(
                  backgroundColor: Colors.red.shade50,
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                onPressed: onApprove,
                icon: const Icon(Icons.check),
                color: Colors.green,
                tooltip: 'Approve',
                style: IconButton.styleFrom(
                  backgroundColor: Colors.green.shade50,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
