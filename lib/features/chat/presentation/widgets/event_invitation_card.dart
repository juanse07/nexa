import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Elegant event invitation card for chat messages
/// Displays event details with accept/decline actions or response status
class EventInvitationCard extends StatelessWidget {
  const EventInvitationCard({
    required this.eventName,
    required this.roleName,
    required this.clientName,
    required this.startDate,
    required this.endDate,
    this.venueName,
    this.rate,
    this.currency = 'USD',
    this.status,
    this.respondedAt,
    this.onAccept,
    this.onDecline,
    this.isManager = false,
    super.key,
  });

  final String eventName;
  final String roleName;
  final String clientName;
  final DateTime startDate;
  final DateTime endDate;
  final String? venueName;
  final double? rate;
  final String currency;
  final String? status; // null, 'accepted', 'declined'
  final DateTime? respondedAt;
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;
  final bool isManager;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPending = status == null || status == 'pending';
    final isAccepted = status == 'accepted';
    final isDeclined = status == 'declined';

    // Color scheme based on status
    final borderColor = isAccepted
        ? const Color(0xFF059669)
        : isDeclined
            ? Colors.grey.shade400
            : const Color(0xFF6366F1);

    final backgroundColor = isAccepted
        ? const Color(0xFFF0FDF4)
        : isDeclined
            ? Colors.grey.shade50
            : Colors.white;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 2),
        boxShadow: [
          BoxShadow(
            color: borderColor.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isAccepted
                    ? [const Color(0xFF059669), const Color(0xFF10B981)]
                    : isDeclined
                        ? [Colors.grey.shade400, Colors.grey.shade500]
                        : [const Color(0xFF6366F1), const Color(0xFF8B5CF6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14),
                topRight: Radius.circular(14),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.event_available,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Text(
                  'EVENT INVITATION',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Event name
                Text(
                  eventName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 16),

                // Info chips
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildInfoChip(
                      icon: Icons.badge_outlined,
                      label: roleName,
                      color: theme.colorScheme.primary,
                    ),
                    _buildInfoChip(
                      icon: Icons.location_on_outlined,
                      label: venueName ?? 'Location TBD',
                      color: theme.colorScheme.secondary,
                    ),
                    _buildInfoChip(
                      icon: Icons.business_outlined,
                      label: clientName,
                      color: const Color(0xFF8B5CF6),
                    ),
                    _buildInfoChip(
                      icon: Icons.calendar_today_outlined,
                      label: DateFormat('MMM d, yyyy').format(startDate),
                      color: const Color(0xFF6366F1),
                    ),
                    _buildInfoChip(
                      icon: Icons.access_time_outlined,
                      label:
                          '${DateFormat('h:mm a').format(startDate)} - ${DateFormat('h:mm a').format(endDate)}',
                      color: const Color(0xFF8B5CF6),
                    ),
                    if (rate != null)
                      _buildInfoChip(
                        icon: Icons.attach_money,
                        label: '${rate!.toStringAsFixed(2)}/$currency/hr',
                        color: const Color(0xFF059669),
                      ),
                  ],
                ),
                const SizedBox(height: 20),

                // Divider
                Divider(color: Colors.grey.shade200, height: 1),
                const SizedBox(height: 20),

                // Actions or status
                if (isPending && !isManager) ...[
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: onAccept,
                          icon: const Icon(Icons.check_circle_outline, size: 20),
                          label: const Text('Accept'),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF059669),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: onDecline,
                          icon: const Icon(Icons.cancel_outlined, size: 20),
                          label: const Text('Decline'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.grey.shade700,
                            side: BorderSide(color: Colors.grey.shade300, width: 2),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else if (isPending && isManager) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.schedule,
                          color: Color(0xFFF59E0B),
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Waiting for response...',
                            style: TextStyle(
                              color: Colors.grey.shade800,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else if (isAccepted) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD1FAE5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.check_circle,
                          color: Color(0xFF059669),
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Accepted',
                                style: TextStyle(
                                  color: Color(0xFF065F46),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (respondedAt != null)
                                Text(
                                  'on ${DateFormat('MMM d').format(respondedAt!)} at ${DateFormat('h:mm a').format(respondedAt!)}',
                                  style: TextStyle(
                                    color: Colors.grey.shade700,
                                    fontSize: 12,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else if (isDeclined) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.cancel,
                          color: Colors.grey.shade600,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Declined',
                                style: TextStyle(
                                  color: Colors.grey.shade700,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (respondedAt != null)
                                Text(
                                  'on ${DateFormat('MMM d').format(respondedAt!)} at ${DateFormat('h:mm a').format(respondedAt!)}',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 12,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color.withOpacity(0.9),
            ),
          ),
        ],
      ),
    );
  }
}
