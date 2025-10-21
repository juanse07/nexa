import 'package:flutter/material.dart';
import 'package:nexa/l10n/app_localizations.dart';
import 'package:intl/intl.dart';

import '../../../extraction/services/event_service.dart';

/// Elegant dialog for selecting and sending event invitations
class SendEventInvitationDialog extends StatefulWidget {
  const SendEventInvitationDialog({
    required this.targetName,
    required this.onSendInvitation,
    super.key,
  });

  final String targetName;
  final Function(String eventId, String roleId, Map<String, dynamic> eventData) onSendInvitation;

  @override
  State<SendEventInvitationDialog> createState() => _SendEventInvitationDialogState();
}

class _SendEventInvitationDialogState extends State<SendEventInvitationDialog> {
  final EventService _eventService = EventService();
  List<Map<String, dynamic>> _events = [];
  Map<String, dynamic>? _selectedEvent;
  String? _selectedRoleId;
  bool _loading = true;
  bool _sending = false;
  String? _error;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadEvents() async {
    try {
      setState(() {
        _loading = true;
        _error = null;
      });

      final events = await _eventService.fetchEvents();

      print('[INVITATION_DIALOG] Total events fetched: ${events.length}');

      // Filter only upcoming/future events
      final now = DateTime.now();
      final upcomingEvents = events.where((event) {
        // Support both 'start_date' and 'date' field names
        final dateField = event['start_date'] ?? event['date'];

        if (dateField != null) {
          try {
            final startDateStr = dateField as String;
            print('[INVITATION_DIALOG] Event: ${event['title'] ?? event['event_name']}');
            print('[INVITATION_DIALOG]   date field: $startDateStr');

            // Parse date - handles both "2026-03-15" and "2026-03-15T10:00:00.000Z" formats
            DateTime startDate;
            if (startDateStr.contains('T')) {
              startDate = DateTime.parse(startDateStr);
            } else {
              // If date only (no time), parse as date and set to start of day
              startDate = DateTime.parse('${startDateStr}T00:00:00.000Z');
            }

            final isFuture = startDate.isAfter(now);
            print('[INVITATION_DIALOG]   is future: $isFuture (now: $now, start: $startDate)');

            return isFuture;
          } catch (e) {
            print('[INVITATION_DIALOG]   ERROR parsing date: $e');
            return false;
          }
        }
        print('[INVITATION_DIALOG] Event ${event['title'] ?? event['event_name']} has no date field');
        return false;
      }).toList();

      print('[INVITATION_DIALOG] Upcoming events: ${upcomingEvents.length}');

      setState(() {
        _events = upcomingEvents;
        _loading = false;
      });
    } catch (e) {
      print('[INVITATION_DIALOG] ERROR loading events: $e');
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filteredEvents {
    if (_searchQuery.isEmpty) return _events;

    final query = _searchQuery.toLowerCase();
    return _events.where((event) {
      final title = (event['title'] as String?)?.toLowerCase() ?? '';
      final client = (event['client_name'] as String?)?.toLowerCase() ?? '';
      final venue = (event['venue_name'] as String?)?.toLowerCase() ?? '';
      return title.contains(query) || client.contains(query) || venue.contains(query);
    }).toList();
  }

  Future<void> _sendInvitation() async {
    if (_selectedEvent == null || _selectedRoleId == null) return;

    setState(() {
      _sending = true;
    });

    try {
      // Support both '_id' and 'id' field names
      final eventId = _selectedEvent!['_id'] as String? ?? _selectedEvent!['id'] as String;

      await widget.onSendInvitation(
        eventId,
        _selectedRoleId!,
        _selectedEvent!,
      );

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send invitation: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.event_available, color: Colors.white, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocalizations.of(context)!.sendJobInvitation,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          AppLocalizations.of(context)!.inviteToJob(widget.targetName),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? _buildError()
                      : _selectedEvent == null
                          ? _buildEventSelection()
                          : _buildRoleSelection(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadEvents,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventSelection() {
    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _searchQuery = value),
            decoration: InputDecoration(
              hintText: AppLocalizations.of(context)!.searchJobs,
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
            ),
          ),
        ),

        // Events list
        Expanded(
          child: _filteredEvents.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.work_off, size: 64, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      Text(
                        _searchQuery.isEmpty
                            ? 'No upcoming jobs'
                            : 'No jobs match your search',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _filteredEvents.length,
                  itemBuilder: (context, index) {
                    final event = _filteredEvents[index];
                    return _buildEventCard(event);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildEventCard(Map<String, dynamic> event) {
    // Use client name as the primary title since job titles are often missing
    final clientName = event['client_name'] as String? ?? 'Unknown Client';

    // Debug: Print available fields
    print('[INVITATION_DIALOG] Event fields: ${event.keys.toList()}');
    print('[INVITATION_DIALOG] start_time value: ${event['start_time']}');

    // Parse start date and time - support both 'start_date' and 'date' field names
    final startDateStr = (event['start_date'] ?? event['date']) as String?;
    DateTime? startDate;
    bool hasTimeComponent = false;

    if (startDateStr != null) {
      try {
        // Check if the date string includes time
        if (startDateStr.contains('T')) {
          startDate = DateTime.parse(startDateStr);
          // Check if time is actually specified (not midnight)
          if (startDate.hour != 0 || startDate.minute != 0) {
            hasTimeComponent = true;
          }
        } else {
          // Date only - check for separate start_time field (support both snake_case and camelCase)
          final startTimeStr = (event['start_time'] ?? event['startTime']) as String?;
          if (startTimeStr != null && startTimeStr.isNotEmpty) {
            print('[INVITATION_DIALOG] Found start_time: $startTimeStr');
            // Parse time in HH:MM format and combine with date
            final timeParts = startTimeStr.split(':');
            if (timeParts.length >= 2) {
              final hour = int.tryParse(timeParts[0]) ?? 0;
              final minute = int.tryParse(timeParts[1]) ?? 0;
              final dateOnly = DateTime.parse(startDateStr);
              startDate = DateTime(dateOnly.year, dateOnly.month, dateOnly.day, hour, minute);
              if (hour != 0 || minute != 0) {
                hasTimeComponent = true;
              }
            }
          } else {
            // No time component, just use date
            startDate = DateTime.parse(startDateStr);
          }
        }
      } catch (e) {
        print('[INVITATION_DIALOG] Error parsing date: $e');
      }
    }

    final venueName = event['venue_name'] as String?;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 0,
      child: InkWell(
        onTap: () => setState(() => _selectedEvent = event),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Client name as main title
              Row(
                children: [
                  const Icon(Icons.business, size: 18, color: Color(0xFF6366F1)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      clientName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF6366F1),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Venue and date/time info
              Row(
                children: [
                  // Venue
                  if (venueName != null) ...[
                    const Icon(Icons.location_on, size: 14, color: Color(0xFF059669)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        venueName,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF059669),
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ] else ...[
                    Expanded(
                      child: Text(
                        'No venue specified',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade500,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              // Date and time - always show
              Row(
                children: [
                  const Icon(Icons.calendar_today, size: 14, color: Color(0xFF8B5CF6)),
                  const SizedBox(width: 4),
                  if (startDate != null) ...[
                    Text(
                      DateFormat('MMM d, yyyy').format(startDate),
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF8B5CF6),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    // Only show time if we have a time component
                    if (hasTimeComponent) ...[
                      const SizedBox(width: 16),
                      const Icon(Icons.access_time, size: 14, color: Color(0xFF8B5CF6)),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat('h:mm a').format(startDate),
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF8B5CF6),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ] else
                    Expanded(
                      child: Text(
                        'No date specified',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade500,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleSelection() {
    final roles = _selectedEvent!['roles'] as List<dynamic>? ?? [];

    return Column(
      children: [
        // Back button and event info
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.grey.shade50,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => setState(() {
                      _selectedEvent = null;
                      _selectedRoleId = null;
                    }),
                    icon: const Icon(Icons.arrow_back),
                  ),
                  Expanded(
                    child: Text(
                      _selectedEvent!['title'] as String? ?? 'Event',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Select a role for the staff member:',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),

        // Roles list
        Expanded(
          child: roles.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.badge_outlined, size: 64, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      Text(
                        'No roles available for this job',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: roles.length,
                  itemBuilder: (context, index) {
                    final role = roles[index] as Map<String, dynamic>;
                    return _buildRoleCard(role);
                  },
                ),
        ),

        // Send button
        if (_selectedRoleId != null)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: FilledButton.icon(
              onPressed: _sending ? null : _sendInvitation,
              icon: _sending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send),
              label: Text(_sending ? 'Sending...' : 'Send Invitation'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                padding: const EdgeInsets.symmetric(vertical: 16),
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildRoleCard(Map<String, dynamic> role) {
    // Support multiple role data structures
    final roleId = role['_id'] as String? ??
                   role['role_id'] as String? ??
                   role['role'] as String?; // Use role name as ID if no ID field

    final roleName = role['role_name'] as String? ??
                     role['name'] as String? ??
                     role['role'] as String? ??
                     'Unknown Role';

    final quantity = role['quantity'] as int? ??
                     role['needed'] as int? ??
                     role['count'] as int? ??
                     0;

    final confirmedCount = (role['confirmed_user_ids'] as List<dynamic>?)?.length ??
                          (role['accepted_staff'] as List<dynamic>?)?.length ??
                          0;

    // Handle nested tariff structure
    final rate = role['rate'] as num? ??
                 role['pay_rate'] as num? ??
                 (role['tariff'] as Map<String, dynamic>?)?['rate'] as num?;

    final isSelected = _selectedRoleId == roleId;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? const Color(0xFF6366F1) : Colors.grey.shade200,
          width: isSelected ? 2 : 1,
        ),
      ),
      elevation: 0,
      color: isSelected ? const Color(0xFF6366F1).withOpacity(0.05) : null,
      child: InkWell(
        onTap: () => setState(() => _selectedRoleId = roleId),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF6366F1)
                      : const Color(0xFF6366F1).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.badge,
                  color: isSelected ? Colors.white : const Color(0xFF6366F1),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      roleName,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? const Color(0xFF6366F1) : null,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$confirmedCount/$quantity filled${rate != null ? ' • \$${rate.toStringAsFixed(2)}/hr' : ''}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                const Icon(
                  Icons.check_circle,
                  color: Color(0xFF6366F1),
                  size: 24,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
