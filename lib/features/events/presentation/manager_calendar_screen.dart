import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nexa/features/events/presentation/event_detail_screen.dart';
import 'package:nexa/features/extraction/services/event_service.dart';
import 'package:nexa/shared/presentation/theme/app_colors.dart';
import 'package:table_calendar/table_calendar.dart';

class ManagerCalendarScreen extends StatefulWidget {
  const ManagerCalendarScreen({super.key});

  @override
  State<ManagerCalendarScreen> createState() => _ManagerCalendarScreenState();
}

class _ManagerCalendarScreenState extends State<ManagerCalendarScreen> {
  late final EventService _eventService;

  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  CalendarFormat _calendarFormat = CalendarFormat.month;

  List<Map<String, dynamic>> _allEvents = [];
  Map<DateTime, List<Map<String, dynamic>>> _eventsByDay = {};
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _eventService = EventService();
    _loadEvents();
  }

  // ─── Data loading ────────────────────────────────────────────────────────

  Future<void> _loadEvents() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final events = await _eventService.fetchEvents();
      _groupEventsByDay(events);
      if (mounted) {
        setState(() {
          _allEvents = events;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _groupEventsByDay(List<Map<String, dynamic>> events) {
    final map = <DateTime, List<Map<String, dynamic>>>{};
    for (final event in events) {
      final rawDate = event['date']?.toString() ?? '';
      if (rawDate.isEmpty) continue;
      try {
        final dt = DateTime.parse(rawDate);
        final key = DateTime(dt.year, dt.month, dt.day);
        map[key] = [...(map[key] ?? []), event];
      } catch (_) {}
    }
    _eventsByDay = map;
  }

  List<Map<String, dynamic>> _eventsForDay(DateTime day) {
    final key = DateTime(day.year, day.month, day.day);
    return _eventsByDay[key] ?? [];
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'available':
        return AppColors.primaryIndigo; // gold
      case 'full':
        return AppColors.success; // green
      case 'completed':
        return AppColors.slateGray; // grey
      case 'pending':
      case 'draft':
        return AppColors.navySpaceCadet; // navy
      default:
        return AppColors.secondaryPurple;
    }
  }

  String _statusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'available':
        return 'OPEN';
      case 'full':
        return 'FULL';
      case 'completed':
        return 'DONE';
      case 'pending':
        return 'PENDING';
      case 'draft':
        return 'DRAFT';
      default:
        return status.toUpperCase();
    }
  }

  String _formatTime(String? rawTime) {
    if (rawTime == null || rawTime.isEmpty) return '--:--';
    // Handles "HH:MM" or "HH:MM:SS" or ISO strings
    try {
      final parts = rawTime.split(':');
      if (parts.length >= 2) {
        final h = int.parse(parts[0]);
        final m = int.parse(parts[1]);
        final suffix = h >= 12 ? 'PM' : 'AM';
        final displayH = h == 0 ? 12 : (h > 12 ? h - 12 : h);
        return '$displayH:${m.toString().padLeft(2, '0')} $suffix';
      }
    } catch (_) {}
    return rawTime;
  }

  String _formatSelectedDay(DateTime day) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final selected = DateTime(day.year, day.month, day.day);

    if (selected == today) return 'Today';
    if (selected == tomorrow) return 'Tomorrow';

    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final wd = weekdays[day.weekday - 1];
    return '$wd, ${months[day.month - 1]} ${day.day}';
  }

  String _staffingLabel(Map<String, dynamic> event) {
    final roles = (event['roles'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final accepted = (event['accepted_staff'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    int needed = 0;
    for (final r in roles) {
      needed += (r['quantity'] as num? ?? 1).toInt();
    }
    if (needed == 0) return '${accepted.length} staff';
    return '${accepted.length}/$needed staff';
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          _buildHeader(),
          _buildCalendar(),
          _buildDayDivider(),
          Expanded(child: _buildAgenda()),
        ],
      ),
    );
  }

  // ── Header (navy gradient AppBar) ────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.navySpaceCadet, AppColors.oceanBlue],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 12),
          child: Row(
            children: [
              const SizedBox(width: 4),
              const Icon(Icons.calendar_month_rounded,
                  color: AppColors.primaryIndigo, size: 22),
              const SizedBox(width: 10),
              const Text(
                'Schedule',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
              const Spacer(),
              // Format toggle: month / 2-week
              _FormatToggle(
                format: _calendarFormat,
                onToggle: (f) => setState(() => _calendarFormat = f),
              ),
              const SizedBox(width: 4),
              // Refresh
              IconButton(
                icon: _isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white70,
                        ),
                      )
                    : const Icon(Icons.refresh_rounded,
                        color: Colors.white70, size: 20),
                onPressed: _isLoading ? null : _loadEvents,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── TableCalendar ─────────────────────────────────────────────────────────

  Widget _buildCalendar() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.oceanBlue, Color(0xFF1E3A8A)],
        ),
      ),
      child: TableCalendar<Map<String, dynamic>>(
        firstDay: DateTime.utc(2020, 1, 1),
        lastDay: DateTime.utc(2030, 12, 31),
        focusedDay: _focusedDay,
        calendarFormat: _calendarFormat,
        selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
        eventLoader: _eventsForDay,
        startingDayOfWeek: StartingDayOfWeek.monday,
        onDaySelected: (selected, focused) {
          HapticFeedback.selectionClick();
          setState(() {
            _selectedDay = selected;
            _focusedDay = focused;
          });
        },
        onFormatChanged: (format) {
          setState(() => _calendarFormat = format);
        },
        onPageChanged: (focused) {
          setState(() => _focusedDay = focused);
        },
        daysOfWeekHeight: 28,
        rowHeight: 44,
        // ── Style ────────────────────────────────────────────────────────
        headerStyle: HeaderStyle(
          formatButtonVisible: false,
          titleCentered: true,
          leftChevronIcon: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.chevron_left_rounded,
                color: Colors.white, size: 18),
          ),
          rightChevronIcon: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.chevron_right_rounded,
                color: Colors.white, size: 18),
          ),
          titleTextStyle: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
          headerPadding:
              const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          decoration: const BoxDecoration(),
        ),
        daysOfWeekStyle: DaysOfWeekStyle(
          dowTextFormatter: (date, locale) {
            const labels = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
            return labels[date.weekday - 1];
          },
          weekdayStyle: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
          weekendStyle: TextStyle(
            color: Colors.white.withValues(alpha: 0.45),
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        calendarStyle: CalendarStyle(
          outsideDaysVisible: false,
          defaultTextStyle: const TextStyle(
              color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
          weekendTextStyle: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 13,
              fontWeight: FontWeight.w500),
          todayDecoration: BoxDecoration(
            color: AppColors.primaryIndigo,
            shape: BoxShape.circle,
          ),
          todayTextStyle: const TextStyle(
              color: AppColors.navySpaceCadet,
              fontSize: 13,
              fontWeight: FontWeight.w700),
          selectedDecoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.95),
            shape: BoxShape.circle,
          ),
          selectedTextStyle: const TextStyle(
              color: AppColors.navySpaceCadet,
              fontSize: 13,
              fontWeight: FontWeight.w700),
          outsideTextStyle: TextStyle(
              color: Colors.white.withValues(alpha: 0.2), fontSize: 13),
          markerDecoration: const BoxDecoration(
            color: AppColors.primaryIndigo,
            shape: BoxShape.circle,
          ),
          markersMaxCount: 3,
          markerSize: 5,
          markerMargin:
              const EdgeInsets.symmetric(horizontal: 0.6, vertical: 1),
          cellMargin: const EdgeInsets.all(4),
        ),
      ),
    );
  }

  // ── Day divider ───────────────────────────────────────────────────────────

  Widget _buildDayDivider() {
    final dayLabel = _formatSelectedDay(_selectedDay);
    final count = _eventsForDay(_selectedDay).length;

    return Container(
      color: const Color(0xFFF8FAFC),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          Text(
            dayLabel,
            style: const TextStyle(
              color: AppColors.navySpaceCadet,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(width: 8),
          if (count > 0)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primaryIndigo.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count ${count == 1 ? 'event' : 'events'}',
                style: const TextStyle(
                  color: AppColors.navySpaceCadet,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Agenda list ───────────────────────────────────────────────────────────

  Widget _buildAgenda() {
    if (_isLoading && _allEvents.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppColors.navySpaceCadet,
          strokeWidth: 2,
        ),
      );
    }

    if (_error != null && _allEvents.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_rounded,
                size: 40, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text('Could not load events',
                style: TextStyle(
                    color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _loadEvents,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final dayEvents = _eventsForDay(_selectedDay);

    if (dayEvents.isEmpty) {
      return _buildEmptyDay();
    }

    // Sort by start_time
    final sorted = [...dayEvents]..sort((a, b) {
        final ta = a['start_time']?.toString() ?? '';
        final tb = b['start_time']?.toString() ?? '';
        return ta.compareTo(tb);
      });

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
      itemCount: sorted.length,
      itemBuilder: (context, i) => _buildAgendaItem(sorted[i], i),
    );
  }

  Widget _buildEmptyDay() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selected = DateTime(_selectedDay.year, _selectedDay.month, _selectedDay.day);
    final isPast = selected.isBefore(today);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.navySpaceCadet.withValues(alpha: 0.06),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isPast ? Icons.event_available_rounded : Icons.free_breakfast_outlined,
              size: 36,
              color: AppColors.navySpaceCadet.withValues(alpha: 0.35),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            isPast ? 'No events this day' : 'Free day',
            style: TextStyle(
              color: AppColors.navySpaceCadet.withValues(alpha: 0.5),
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isPast ? 'Nothing was scheduled' : 'Nothing scheduled yet',
            style: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  // ── Individual agenda item ─────────────────────────────────────────────

  Widget _buildAgendaItem(Map<String, dynamic> event, int index) {
    final status = (event['status'] ?? 'draft').toString();
    final statusColor = _statusColor(status);
    final statusLabel = _statusLabel(status);
    final clientName = (event['client_name'] ?? 'Event').toString();
    final startTime = _formatTime(event['start_time']?.toString());
    final endTime = _formatTime(event['end_time']?.toString());
    final venueRaw = event['venue'];
    final venue = venueRaw is Map<String, dynamic>
        ? ((venueRaw['name'] ?? venueRaw['address'] ?? '') as Object).toString()
        : (venueRaw?.toString() ?? '');
    final staffing = _staffingLabel(event);

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => EventDetailScreen(event: event),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Time column ─────────────────────────────────────
            SizedBox(
              width: 58,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const SizedBox(height: 12),
                  Text(
                    startTime,
                    style: const TextStyle(
                      color: AppColors.navySpaceCadet,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (endTime != '--:--')
                    Text(
                      endTime,
                      style: TextStyle(
                        color: AppColors.navySpaceCadet.withValues(alpha: 0.45),
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // ── Status line ─────────────────────────────────────
            Column(
              children: [
                const SizedBox(height: 14),
                Container(
                  width: 3,
                  height: 50,
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 10),
            // ── Event card ───────────────────────────────────────
            Expanded(
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.navySpaceCadet.withValues(alpha: 0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            clientName,
                            style: const TextStyle(
                              color: AppColors.navySpaceCadet,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _StatusPill(label: statusLabel, color: statusColor),
                      ],
                    ),
                    if (venue.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.location_on_outlined,
                              size: 11,
                              color: Colors.grey.shade500),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              venue,
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 11,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.people_outline_rounded,
                            size: 11,
                            color: statusColor),
                        const SizedBox(width: 3),
                        Text(
                          staffing,
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        Icon(Icons.arrow_forward_ios_rounded,
                            size: 10, color: Colors.grey.shade400),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Sub-widgets ─────────────────────────────────────────────────────────────

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _FormatToggle extends StatelessWidget {
  final CalendarFormat format;
  final ValueChanged<CalendarFormat> onToggle;

  const _FormatToggle({required this.format, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final isMonth = format == CalendarFormat.month;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onToggle(isMonth ? CalendarFormat.twoWeeks : CalendarFormat.month);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: Colors.white.withValues(alpha: 0.2), width: 0.8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isMonth ? Icons.calendar_view_month_rounded : Icons.calendar_view_week_rounded,
              color: Colors.white,
              size: 14,
            ),
            const SizedBox(width: 4),
            Text(
              isMonth ? 'Month' : '2 Wks',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
