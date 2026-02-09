import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/attendance_service.dart';

/// Screen for managers to bulk clock-in multiple staff members at once
class BulkClockInScreen extends StatefulWidget {
  final Map<String, dynamic> event;

  const BulkClockInScreen({
    super.key,
    required this.event,
  });

  @override
  State<BulkClockInScreen> createState() => _BulkClockInScreenState();
}

class _BulkClockInScreenState extends State<BulkClockInScreen> {
  final Set<String> _selectedUserKeys = {};
  final TextEditingController _noteController = TextEditingController();
  bool _isSubmitting = false;

  List<Map<String, dynamic>> get _acceptedStaff {
    final staff = widget.event['accepted_staff'] as List<dynamic>?;
    return staff?.cast<Map<String, dynamic>>() ?? [];
  }

  String get _eventName =>
      widget.event['event_name'] as String? ??
      widget.event['shift_name'] as String? ??
      'Event';

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  void _toggleSelection(String userKey) {
    setState(() {
      if (_selectedUserKeys.contains(userKey)) {
        _selectedUserKeys.remove(userKey);
      } else {
        _selectedUserKeys.add(userKey);
      }
    });
  }

  void _selectAll() {
    setState(() {
      if (_selectedUserKeys.length == _acceptedStaff.length) {
        _selectedUserKeys.clear();
      } else {
        _selectedUserKeys.clear();
        for (final staff in _acceptedStaff) {
          final userKey = staff['userKey'] as String?;
          if (userKey != null) {
            _selectedUserKeys.add(userKey);
          }
        }
      }
    });
  }

  bool _isAlreadyClockedIn(Map<String, dynamic> staff) {
    final attendance = staff['attendance'] as List<dynamic>?;
    if (attendance == null || attendance.isEmpty) return false;

    final lastAttendance = attendance.last as Map<String, dynamic>;
    return lastAttendance['clockOutAt'] == null;
  }

  Future<void> _performBulkClockIn() async {
    if (_selectedUserKeys.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one staff member')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final response = await AttendanceService.bulkClockIn(
        eventId: widget.event['_id'] as String,
        userKeys: _selectedUserKeys.toList(),
        note: _noteController.text.isEmpty ? null : _noteController.text,
      );

      if (response != null && mounted) {
        final successful = response['successful'] as int? ?? 0;
        final total = response['total'] as int? ?? 0;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully clocked in $successful of $total staff'),
            backgroundColor: Colors.green,
          ),
        );

        // Show results dialog
        _showResultsDialog(response);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to perform bulk clock-in'),
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
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _showResultsDialog(Map<String, dynamic> response) {
    final results = response['results'] as List<dynamic>?;
    if (results == null) return;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Bulk Clock-In Results'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: results.length,
              itemBuilder: (context, index) {
                final result = results[index] as Map<String, dynamic>;
                final status = result['status'] as String?;
                final isSuccess = status == 'success';
                final staffName = result['staffName'] as String? ?? 'Unknown';

                return ListTile(
                  leading: Icon(
                    isSuccess ? Icons.check_circle : Icons.error,
                    color: isSuccess ? Colors.green : Colors.red,
                  ),
                  title: Text(staffName),
                  subtitle: Text(
                    result['message'] as String? ?? status ?? '',
                    style: TextStyle(
                      color: isSuccess ? Colors.grey : Colors.red,
                    ),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context, true); // Return success to previous screen
              },
              child: const Text('Done'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final eventDate = widget.event['date'] != null
        ? DateTime.parse(widget.event['date'] as String)
        : null;
    final dateFormat = DateFormat('EEEE, MMMM d, yyyy');

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Bulk Clock-In'),
        backgroundColor: const Color(0xFF212C4A),
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: _selectAll,
            child: Text(
              _selectedUserKeys.length == _acceptedStaff.length
                  ? 'Deselect All'
                  : 'Select All',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Event info card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _eventName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (eventDate != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today,
                          size: 16, color: Colors.grey),
                      const SizedBox(width: 8),
                      Text(
                        dateFormat.format(eventDate),
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ],
                if (widget.event['venue_address'] != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.location_on,
                          size: 16, color: Colors.grey),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.event['venue_address'] as String,
                          style: TextStyle(color: Colors.grey[600]),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Staff selection list
          Expanded(
            child: _acceptedStaff.isEmpty
                ? const Center(
                    child: Text('No accepted staff for this event'),
                  )
                : ListView.builder(
                    itemCount: _acceptedStaff.length,
                    itemBuilder: (context, index) {
                      final staff = _acceptedStaff[index];
                      return _buildStaffTile(staff);
                    },
                  ),
          ),

          // Note field and submit button
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: SafeArea(
              child: Column(
                children: [
                  TextField(
                    controller: _noteController,
                    decoration: InputDecoration(
                      labelText: 'Override Note (optional)',
                      hintText: 'e.g., Group check-in at entrance',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.note_alt),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _selectedUserKeys.isEmpty || _isSubmitting
                          ? null
                          : _performBulkClockIn,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E3A8A),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        disabledBackgroundColor: Colors.grey[300],
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text(
                              'Clock In ${_selectedUserKeys.length} Staff',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStaffTile(Map<String, dynamic> staff) {
    final userKey = staff['userKey'] as String?;
    final isSelected = userKey != null && _selectedUserKeys.contains(userKey);
    final isAlreadyClockedIn = _isAlreadyClockedIn(staff);

    final name = staff['name'] as String? ??
        '${staff['first_name'] ?? ''} ${staff['last_name'] ?? ''}'.trim();
    final role = staff['role'] as String?;
    final picture = staff['picture'] as String?;

    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 1),
      child: ListTile(
        onTap: isAlreadyClockedIn || userKey == null
            ? null
            : () => _toggleSelection(userKey),
        leading: Stack(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: const Color(0xFF1E3A8A),
              backgroundImage: picture != null ? NetworkImage(picture) : null,
              child: picture == null
                  ? Text(
                      (name.isNotEmpty ? name[0] : '?').toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontSize: 18),
                    )
                  : null,
            ),
            if (isAlreadyClockedIn)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check,
                    size: 14,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
        title: Text(
          name.isEmpty ? 'Unknown' : name,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: isAlreadyClockedIn ? Colors.grey : Colors.black,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (role != null)
              Text(
                role,
                style: TextStyle(color: Colors.grey[600]),
              ),
            if (isAlreadyClockedIn)
              const Text(
                'Already clocked in',
                style: TextStyle(
                  color: Colors.green,
                  fontStyle: FontStyle.italic,
                  fontSize: 12,
                ),
              ),
          ],
        ),
        trailing: isAlreadyClockedIn
            ? Icon(Icons.check_circle, color: Colors.green[400])
            : Checkbox(
                value: isSelected,
                onChanged: userKey == null
                    ? null
                    : (value) => _toggleSelection(userKey),
                activeColor: const Color(0xFF1E3A8A),
              ),
      ),
    );
  }
}
