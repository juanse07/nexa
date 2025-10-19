import 'package:flutter/material.dart';
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
        if (event['start_date'] != null) {
          try {
            final startDateStr = event['start_date'] as String;
            print('[INVITATION_DIALOG] Event: ${event['title']}');
            print('[INVITATION_DIALOG]   start_date: $startDateStr');

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
        print('[INVITATION_DIALOG] Event ${event['title']} has no start_date');
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
      return title.contains(query) || client.contains(query);
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
                        const Text(
                          'Send Event Invitation',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'Invite ${widget.targetName} to an event',
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
              hintText: 'Search events...',
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
                      Icon(Icons.event_busy, size: 64, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      Text(
                        _searchQuery.isEmpty
                            ? 'No upcoming events'
                            : 'No events match your search',
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
    final title = event['title'] as String? ?? 'Untitled Event';
    final clientName = event['client_name'] as String? ?? 'Unknown Client';
    final startDate = event['start_date'] != null
        ? DateTime.parse(event['start_date'] as String)
        : null;
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
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildChip(Icons.business, clientName, const Color(0xFF6366F1)),
                  if (startDate != null)
                    _buildChip(
                      Icons.calendar_today,
                      DateFormat('MMM d, yyyy').format(startDate),
                      const Color(0xFF8B5CF6),
                    ),
                  if (venueName != null)
                    _buildChip(Icons.location_on, venueName, const Color(0xFF059669)),
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
                'Select a role to invite staff member for:',
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
                        'No roles available for this event',
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
    final roleId = role['_id'] as String? ?? role['role_id'] as String?;
    final roleName = role['role_name'] as String? ?? 'Unknown Role';
    final quantity = role['quantity'] as int? ?? 0;
    final confirmedCount = (role['confirmed_user_ids'] as List<dynamic>?)?.length ?? 0;
    final rate = role['rate'] as num?;
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
