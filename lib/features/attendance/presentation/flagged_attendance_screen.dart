import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nexa/features/attendance/services/attendance_service.dart';

/// Screen for managers to review flagged attendance entries
class FlaggedAttendanceScreen extends StatefulWidget {
  const FlaggedAttendanceScreen({super.key});

  @override
  State<FlaggedAttendanceScreen> createState() => _FlaggedAttendanceScreenState();
}

class _FlaggedAttendanceScreenState extends State<FlaggedAttendanceScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _flaggedEntries = [];
  String _filterStatus = 'pending';

  @override
  void initState() {
    super.initState();
    _loadFlaggedAttendance();
  }

  Future<void> _loadFlaggedAttendance() async {
    setState(() => _isLoading = true);

    try {
      final entries = await AttendanceService.getFlaggedAttendance();
      setState(() {
        _flaggedEntries = entries
            .where((e) =>
                _filterStatus == 'all' || e['status'] == _filterStatus)
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load flagged attendance: $e')),
        );
      }
    }
  }

  Future<void> _reviewFlag(String flagId, String status, {String? notes}) async {
    try {
      final success = await AttendanceService.reviewFlaggedAttendance(
        flagId: flagId,
        status: status,
        reviewNotes: notes,
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Flag ${status == 'approved' ? 'approved' : 'dismissed'}'),
            backgroundColor: Colors.green,
          ),
        );
        await _loadFlaggedAttendance();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update flag'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _showReviewDialog(Map<String, dynamic> flag) {
    final TextEditingController notesController = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Review Flag'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildFlagDetails(flag),
              const SizedBox(height: 16),
              TextField(
                controller: notesController,
                decoration: InputDecoration(
                  labelText: 'Review Notes (optional)',
                  hintText: 'Add any notes about this review...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _reviewFlag(
                  flag['_id'] as String,
                  'dismissed',
                  notes: notesController.text.isEmpty ? null : notesController.text,
                );
              },
              style: TextButton.styleFrom(foregroundColor: Colors.orange),
              child: const Text('Dismiss'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _reviewFlag(
                  flag['_id'] as String,
                  'approved',
                  notes: notesController.text.isEmpty ? null : notesController.text,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text('Approve'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFlagDetails(Map<String, dynamic> flag) {
    final details = flag['details'] as Map<String, dynamic>?;
    final dateFormat = DateFormat('MMM d, h:mm a');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          flag['staffName'] as String? ?? 'Unknown Staff',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 4),
        Text(
          flag['eventName'] as String? ?? 'Unknown Event',
          style: TextStyle(color: Colors.grey[600]),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (details?['clockInAt'] != null)
                Text(
                  'Clock-In: ${dateFormat.format(DateTime.parse(details!['clockInAt'] as String))}',
                ),
              if (details?['clockOutAt'] != null)
                Text(
                  'Clock-Out: ${dateFormat.format(DateTime.parse(details!['clockOutAt'] as String))}',
                ),
              if (details?['actualDurationHours'] != null)
                Text(
                  'Duration: ${(details!['actualDurationHours'] as num).toStringAsFixed(1)} hours',
                ),
              if (details?['expectedDurationHours'] != null)
                Text(
                  'Expected: ${(details!['expectedDurationHours'] as num).toStringAsFixed(1)} hours',
                  style: TextStyle(color: Colors.grey[600]),
                ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Flagged Attendance'),
        backgroundColor: const Color(0xFF212C4A),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadFlaggedAttendance,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter chips
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Row(
              children: [
                _buildFilterChip('Pending', 'pending'),
                const SizedBox(width: 8),
                _buildFilterChip('Approved', 'approved'),
                const SizedBox(width: 8),
                _buildFilterChip('Dismissed', 'dismissed'),
                const SizedBox(width: 8),
                _buildFilterChip('All', 'all'),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Flagged entries list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _flaggedEntries.isEmpty
                    ? _buildEmptyState()
                    : _buildFlagList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _filterStatus == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() => _filterStatus = value);
          _loadFlaggedAttendance();
        }
      },
      selectedColor: const Color(0xFF1E3A8A).withOpacity(0.2),
      checkmarkColor: const Color(0xFF1E3A8A),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 80,
            color: Colors.green[300],
          ),
          const SizedBox(height: 16),
          Text(
            _filterStatus == 'pending'
                ? 'No pending flags!'
                : 'No flagged entries found',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _filterStatus == 'pending'
                ? 'All attendance entries look normal'
                : 'Try adjusting your filters',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlagList() {
    return RefreshIndicator(
      onRefresh: _loadFlaggedAttendance,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _flaggedEntries.length,
        itemBuilder: (context, index) {
          final flag = _flaggedEntries[index];
          return _buildFlagCard(flag);
        },
      ),
    );
  }

  Widget _buildFlagCard(Map<String, dynamic> flag) {
    final severity = flag['severity'] as String? ?? 'medium';
    final flagType = flag['flagType'] as String? ?? 'unknown';
    final status = flag['status'] as String? ?? 'pending';
    final details = flag['details'] as Map<String, dynamic>?;
    final createdAt = flag['createdAt'] != null
        ? DateTime.parse(flag['createdAt'] as String)
        : null;

    Color severityColor;
    IconData severityIcon;
    switch (severity) {
      case 'high':
        severityColor = Colors.red;
        severityIcon = Icons.error;
        break;
      case 'medium':
        severityColor = Colors.orange;
        severityIcon = Icons.warning;
        break;
      default:
        severityColor = Colors.yellow[700]!;
        severityIcon = Icons.info;
    }

    Color statusColor;
    switch (status) {
      case 'approved':
        statusColor = Colors.green;
        break;
      case 'dismissed':
        statusColor = Colors.grey;
        break;
      case 'investigating':
        statusColor = Colors.blue;
        break;
      default:
        statusColor = Colors.orange;
    }

    String flagTypeLabel;
    switch (flagType) {
      case 'unusual_hours':
        flagTypeLabel = 'Unusual Hours';
        break;
      case 'excessive_duration':
        flagTypeLabel = 'Excessive Duration';
        break;
      case 'late_clock_out':
        flagTypeLabel = 'Late Clock-Out';
        break;
      case 'location_mismatch':
        flagTypeLabel = 'Location Mismatch';
        break;
      default:
        flagTypeLabel = 'Unknown';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: status == 'pending' ? () => _showReviewDialog(flag) : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row with severity and status
              Row(
                children: [
                  Icon(severityIcon, color: severityColor, size: 20),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: severityColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      severity.toUpperCase(),
                      style: TextStyle(
                        color: severityColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Staff name and event
              Text(
                flag['staffName'] as String? ?? 'Unknown Staff',
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 4),
              Text(
                flag['eventName'] as String? ?? 'Unknown Event',
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 8),

              // Flag type badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  flagTypeLabel,
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Time details
              if (details != null) ...[
                Row(
                  children: [
                    Icon(Icons.access_time, size: 16, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text(
                      'Duration: ${(details['actualDurationHours'] as num?)?.toStringAsFixed(1) ?? '-'} hrs',
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                    if (details['expectedDurationHours'] != null) ...[
                      Text(
                        ' (expected ${(details['expectedDurationHours'] as num).toStringAsFixed(1)} hrs)',
                        style:
                            TextStyle(color: Colors.grey[500], fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ],

              // Timestamp
              if (createdAt != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.schedule, size: 14, color: Colors.grey[400]),
                    const SizedBox(width: 4),
                    Text(
                      DateFormat('MMM d, yyyy h:mm a').format(createdAt),
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    ),
                  ],
                ),
              ],

              // Review notes (if any)
              if (flag['reviewNotes'] != null &&
                  (flag['reviewNotes'] as String).isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.note, size: 16, color: Colors.blue[400]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          flag['reviewNotes'] as String,
                          style: TextStyle(
                            color: Colors.blue[700],
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Action buttons for pending flags
              if (status == 'pending') ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _reviewFlag(flag['_id'] as String, 'dismissed'),
                        icon: const Icon(Icons.close, size: 18),
                        label: const Text('Dismiss'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.orange,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _reviewFlag(flag['_id'] as String, 'approved'),
                        icon: const Icon(Icons.check, size: 18),
                        label: const Text('Approve'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
