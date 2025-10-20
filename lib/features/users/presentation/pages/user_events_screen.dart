import 'package:flutter/material.dart';
import 'package:nexa/l10n/app_localizations.dart';
import '../../../extraction/services/event_service.dart';
import '../../../events/presentation/event_detail_screen.dart';
import '../../../../core/widgets/custom_sliver_app_bar.dart';

class UserEventsScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  const UserEventsScreen({
    super.key,
    required this.user,
  });

  @override
  State<UserEventsScreen> createState() => _UserEventsScreenState();
}

class _UserEventsScreenState extends State<UserEventsScreen> {
  final EventService _eventService = EventService();
  List<Map<String, dynamic>>? _events;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadUserEvents();
  }

  Future<void> _loadUserEvents() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final userKey = '${widget.user['provider']}:${widget.user['subject']}';
      final events = await _eventService.fetchUserEvents(userKey);

      setState(() {
        _events = events;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final firstName = widget.user['first_name']?.toString() ?? '';
    final lastName = widget.user['last_name']?.toString() ?? '';
    final name = widget.user['name']?.toString() ?? '';
    final email = widget.user['email']?.toString() ?? '';
    final picture = widget.user['picture']?.toString();

    final displayName = [firstName, lastName].where((s) => s.isNotEmpty).join(' ');
    final fullDisplayName = displayName.isNotEmpty ? displayName : (name.isNotEmpty ? name : email);

    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surfaceContainerLowest,
      body: RefreshIndicator(
        onRefresh: _loadUserEvents,
        child: CustomScrollView(
          slivers: [
            CustomSliverAppBar(
              title: fullDisplayName,
              subtitle: email.isNotEmpty ? email : null,
              onBackPressed: () => Navigator.of(context).pop(),
              expandedHeight: 140.0,
              pinned: false,
              floating: true,
              snap: true,
            ),
            // Events List
            _buildSliverContent(),
          ],
        ),
      ),
    );
  }

  Widget _buildSliverContent() {
    if (_isLoading) {
      return const SliverFillRemaining(
        child: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_errorMessage != null) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red.shade300,
              ),
              const SizedBox(height: 16),
              Text(
                'Error loading events',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadUserEvents,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_events == null || _events!.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.event_busy,
                size: 64,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 16),
              Text(
                'No events found',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'This user is not linked to any events yet',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Split into upcoming and past events
    final now = DateTime.now();
    final upcoming = <Map<String, dynamic>>[];
    final pastByMonth = <String, List<Map<String, dynamic>>>{};

    for (final event in _events!) {
      final dateStr = event['date']?.toString() ?? '';
      if (dateStr.isNotEmpty) {
        try {
          final date = DateTime.parse(dateStr);
          if (date.isAfter(now)) {
            upcoming.add(event);
          } else {
            // Group past events by month
            final monthKey = '${date.year}-${date.month.toString().padLeft(2, '0')}';
            pastByMonth.putIfAbsent(monthKey, () => []).add(event);
          }
        } catch (_) {
          // If date parsing fails, add to a special "Unknown" group
          pastByMonth.putIfAbsent('unknown', () => []).add(event);
        }
      } else {
        // No date, add to "Unknown" group
        pastByMonth.putIfAbsent('unknown', () => []).add(event);
      }
    }

    // Sort months in descending order (most recent first)
    final sortedMonths = pastByMonth.keys.toList()
      ..sort((a, b) {
        if (a == 'unknown') return 1;
        if (b == 'unknown') return -1;
        return b.compareTo(a);
      });

    // Sort upcoming events (soonest first)
    upcoming.sort((a, b) {
      final dateStrA = a['date']?.toString() ?? '';
      final dateStrB = b['date']?.toString() ?? '';

      try {
        final dateA = DateTime.parse(dateStrA);
        final dateB = DateTime.parse(dateStrB);
        return dateA.compareTo(dateB); // Ascending order for upcoming
      } catch (_) {
        return 0;
      }
    });

    // Sort events within each month (newest first)
    for (final monthKey in sortedMonths) {
      pastByMonth[monthKey]!.sort((a, b) {
        final dateStrA = a['date']?.toString() ?? '';
        final dateStrB = b['date']?.toString() ?? '';

        try {
          final dateA = DateTime.parse(dateStrA);
          final dateB = DateTime.parse(dateStrB);
          return dateB.compareTo(dateA); // Descending order for past
        } catch (_) {
          return 0;
        }
      });
    }

    return SliverPadding(
      padding: const EdgeInsets.all(16),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          // Upcoming Events
          if (upcoming.isNotEmpty) ...[
            Row(
              children: [
                const Icon(
                  Icons.upcoming,
                  color: Color(0xFF059669),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Upcoming Events (${upcoming.length})',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...upcoming.map((event) => _buildEventCard(event, true)),
            const SizedBox(height: 24),
          ],

          // Past Events grouped by month
          ...sortedMonths.expand((monthKey) {
            final eventsInMonth = pastByMonth[monthKey]!;

            String monthLabel;
            if (monthKey == 'unknown') {
              monthLabel = 'Date Unknown';
            } else {
              try {
                final parts = monthKey.split('-');
                final year = int.parse(parts[0]);
                final month = int.parse(parts[1]);
                final date = DateTime(year, month);

                const monthNames = [
                  'January', 'February', 'March', 'April', 'May', 'June',
                  'July', 'August', 'September', 'October', 'November', 'December'
                ];

                monthLabel = '${monthNames[month - 1]} $year';
              } catch (_) {
                monthLabel = monthKey;
              }
            }

            return [
              Row(
                children: [
                  const Icon(
                    Icons.history,
                    color: Color(0xFF6B7280),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$monthLabel (${eventsInMonth.length})',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...eventsInMonth.map((event) => _buildEventCard(event, false)),
              const SizedBox(height: 24),
            ];
          }),
        ]),
      ),
    );
  }

  Widget _buildEventCard(Map<String, dynamic> event, bool isUpcoming) {
    final clientName = event['client_name']?.toString() ?? 'Client';
    final eventName = event['event_name']?.toString() ?? event['venue_name']?.toString() ?? AppLocalizations.of(context)!.untitledJob;
    final userRole = event['userRole']?.toString() ?? '';
    final dateStr = event['date']?.toString() ?? '';
    final city = event['city']?.toString() ?? '';
    final state = event['state']?.toString() ?? '';
    final location = [city, state].where((s) => s.isNotEmpty).join(', ');

    String formattedDate = '';
    if (dateStr.isNotEmpty) {
      try {
        final date = DateTime.parse(dateStr);
        formattedDate = '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      } catch (_) {
        formattedDate = dateStr;
      }
    }

    final statusColor = isUpcoming ? const Color(0xFF059669) : const Color(0xFF6B7280);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: statusColor.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => EventDetailScreen(
                event: event,
                onEventUpdated: _loadUserEvents,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with status badge
              Row(
                children: [
                  Expanded(
                    child: Text(
                      clientName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: statusColor.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      isUpcoming ? 'Upcoming' : 'Past',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              Text(
                eventName,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade700,
                ),
              ),

              const SizedBox(height: 12),

              // User's role
              if (userRole.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFFF59E0B).withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.work_outline,
                        size: 14,
                        color: Color(0xFFF59E0B),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        userRole,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFF59E0B),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Event details
              Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 14,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    formattedDate.isNotEmpty ? formattedDate : 'Date TBD',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  if (location.isNotEmpty) ...[
                    const SizedBox(width: 16),
                    Icon(
                      Icons.place,
                      size: 14,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        location,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
