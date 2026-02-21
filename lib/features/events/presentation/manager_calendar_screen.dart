import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:nexa/features/events/presentation/event_detail_screen.dart';
import 'package:nexa/features/extraction/services/event_service.dart';
import 'package:nexa/l10n/app_localizations.dart';
import 'package:nexa/shared/presentation/theme/app_colors.dart';
import 'package:table_calendar/table_calendar.dart';

// Three view modes for the schedule screen
enum _ViewMode { month, twoWeeks, agenda }

class ManagerCalendarScreen extends StatefulWidget {
  const ManagerCalendarScreen({super.key});

  @override
  State<ManagerCalendarScreen> createState() => _ManagerCalendarScreenState();
}

class _ManagerCalendarScreenState extends State<ManagerCalendarScreen> {
  late final EventService _eventService;

  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  _ViewMode _viewMode = _ViewMode.month;

  List<Map<String, dynamic>> _allEvents = [];
  Map<DateTime, List<Map<String, dynamic>>> _eventsByDay = {};
  bool _isLoading = true;
  String? _error;

  // Scroll controller used to jump to today in agenda mode
  final ScrollController _agendaScrollController = ScrollController();

  // Whether to show past events in the agenda (collapsed by default)
  bool _showPastEvents = false;

  // Current locale code for DateFormat (auto-updated in didChangeDependencies)
  String _locale = 'en';

  @override
  void initState() {
    super.initState();
    _eventService = EventService();
    _loadEvents();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _locale = Localizations.localeOf(context).languageCode;
  }

  @override
  void dispose() {
    _agendaScrollController.dispose();
    super.dispose();
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

  // Upcoming days (today or future), ascending
  List<DateTime> get _upcomingDays {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return (_eventsByDay.keys.toList()
          ..sort())
        .where((d) => !d.isBefore(today))
        .toList();
  }

  // Past days (before today), descending — most recent past first
  List<DateTime> get _pastDays {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return (_eventsByDay.keys.toList()
          ..sort())
        .where((d) => d.isBefore(today))
        .toList()
        .reversed
        .toList();
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'available':
        return AppColors.primaryIndigo;
      case 'full':
        return AppColors.success;
      case 'completed':
        return AppColors.slateGray;
      case 'pending':
      case 'draft':
        return AppColors.navySpaceCadet;
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

  String _formatDayLabel(DateTime day) {
    final l10n = AppLocalizations.of(context)!;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final d = DateTime(day.year, day.month, day.day);

    if (d == today) return l10n.calendarToday;
    if (d == tomorrow) return l10n.calendarTomorrow;

    return DateFormat('EEE, MMM d', _locale).format(day);
  }

  String _staffingLabel(Map<String, dynamic> event) {
    final roles =
        (event['roles'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final accepted =
        (event['accepted_staff'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    int needed = 0;
    for (final r in roles) {
      needed += (r['quantity'] as num? ?? 1).toInt();
    }
    if (needed == 0) return '${accepted.length} staff';
    return '${accepted.length}/$needed staff';
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  // Shared gradient — used by header AND calendar background
  static const _bgGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.navySpaceCadet, AppColors.oceanBlue],
  );

  @override
  Widget build(BuildContext context) {
    final isAgenda = _viewMode == _ViewMode.agenda;
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // Header + calendar share one continuous gradient surface
          _buildHeaderAndCalendar(),
          if (!isAgenda) _buildDayDivider(),
          Expanded(
            child: isAgenda ? _buildFullAgendaView() : _buildDayAgenda(),
          ),
        ],
      ),
    );
  }

  // ── Combined header + calendar in one gradient container ─────────────────

  Widget _buildHeaderAndCalendar() {
    final isAgenda = _viewMode == _ViewMode.agenda;
    return Container(
      decoration: const BoxDecoration(gradient: _bgGradient),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ── AppBar row ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
              child: Row(
                children: [
                  const SizedBox(width: 4),
                  const Icon(Icons.calendar_month_rounded,
                      color: AppColors.primaryIndigo, size: 22),
                  const SizedBox(width: 10),
                  Text(
                    AppLocalizations.of(context)!.navSchedule,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const Spacer(),
                  _ViewModeToggle(
                    mode: _viewMode,
                    onChanged: (m) {
                      HapticFeedback.selectionClick();
                      setState(() => _viewMode = m);
                    },
                  ),
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
            // ── TableCalendar (hidden in agenda mode) ──────────────────
            if (!isAgenda)
              Padding(
                // Small bottom padding so calendar blends into the white body
                padding: const EdgeInsets.only(bottom: 6),
                child: TableCalendar<Map<String, dynamic>>(
                  firstDay: DateTime.utc(2020, 1, 1),
                  lastDay: DateTime.utc(2030, 12, 31),
                  focusedDay: _focusedDay,
                  calendarFormat: _viewMode == _ViewMode.month
                      ? CalendarFormat.month
                      : CalendarFormat.twoWeeks,
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
                  onFormatChanged: (_) {},
                  onPageChanged: (focused) {
                    setState(() => _focusedDay = focused);
                  },
                  daysOfWeekHeight: 28,
                  rowHeight: 44,
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
                    headerPadding: const EdgeInsets.symmetric(
                        vertical: 8, horizontal: 8),
                    decoration: const BoxDecoration(),
                  ),
                  daysOfWeekStyle: DaysOfWeekStyle(
                    dowTextFormatter: (date, locale) {
                      const labels = [
                        'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'
                      ];
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
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w500),
                    weekendTextStyle: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 13,
                        fontWeight: FontWeight.w500),
                    todayDecoration: const BoxDecoration(
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
                        color: Colors.white.withValues(alpha: 0.2),
                        fontSize: 13),
                    markerDecoration: const BoxDecoration(
                      color: AppColors.primaryIndigo,
                      shape: BoxShape.circle,
                    ),
                    markersMaxCount: 3,
                    markerSize: 5,
                    markerMargin: const EdgeInsets.symmetric(
                        horizontal: 0.6, vertical: 1),
                    cellMargin: const EdgeInsets.all(4),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Day divider (shown in month/2-week modes) ─────────────────────────────

  Widget _buildDayDivider() {
    final dayLabel = _formatDayLabel(_selectedDay);
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

  // ── Single-day agenda (month / 2-week modes) ──────────────────────────────

  Widget _buildDayAgenda() {
    if (_isLoading && _allEvents.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(
            color: AppColors.navySpaceCadet, strokeWidth: 2),
      );
    }

    if (_error != null && _allEvents.isEmpty) {
      return _buildErrorState();
    }

    final dayEvents = _eventsForDay(_selectedDay);
    if (dayEvents.isEmpty) return _buildEmptyDay();

    final sorted = [...dayEvents]..sort((a, b) {
        final ta = a['start_time']?.toString() ?? '';
        final tb = b['start_time']?.toString() ?? '';
        return ta.compareTo(tb);
      });

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
      itemCount: sorted.length,
      itemBuilder: (ctx, i) => _buildAgendaItem(sorted[i]),
    );
  }

  // ── Full agenda view (agenda mode) ────────────────────────────────────────

  Widget _buildFullAgendaView() {
    if (_isLoading && _allEvents.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(
            color: AppColors.navySpaceCadet, strokeWidth: 2),
      );
    }

    if (_error != null && _allEvents.isEmpty) {
      return _buildErrorState();
    }

    final upcoming = _upcomingDays;
    final past = _pastDays;

    // Build flat item list: upcoming events first, then past (if expanded)
    final items = <_AgendaItem>[];

    // ── Upcoming ──────────────────────────────────────────────────────────
    if (upcoming.isEmpty) {
      items.add(const _AgendaItem.noUpcoming());
    } else {
      for (final day in upcoming) {
        items.add(_AgendaItem.header(day));
        final eventsOnDay = [...(_eventsByDay[day] ?? [])]
          ..sort((a, b) {
            final ta = a['start_time']?.toString() ?? '';
            final tb = b['start_time']?.toString() ?? '';
            return ta.compareTo(tb);
          });
        for (final e in eventsOnDay) {
          items.add(_AgendaItem.event(day, e));
        }
      }
    }

    // ── Past section toggle ───────────────────────────────────────────────
    if (past.isNotEmpty) {
      items.add(_AgendaItem.pastToggle(past.length));
      if (_showPastEvents) {
        for (final day in past) {
          items.add(_AgendaItem.header(day));
          final eventsOnDay = [...(_eventsByDay[day] ?? [])]
            ..sort((a, b) {
              final ta = a['start_time']?.toString() ?? '';
              final tb = b['start_time']?.toString() ?? '';
              return ta.compareTo(tb);
            });
          for (final e in eventsOnDay) {
            items.add(_AgendaItem.event(day, e));
          }
        }
      }
    }

    return ListView.builder(
      controller: _agendaScrollController,
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: items.length,
      itemBuilder: (ctx, i) {
        final item = items[i];
        if (item.isHeader) return _buildAgendaDateHeader(item.day!);
        if (item.isNoUpcoming) return _buildNoUpcomingTile();
        if (item.isPastToggle) return _buildPastToggle(item.pastCount!);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _buildAgendaItem(item.event!),
        );
      },
    );
  }

  Widget _buildNoUpcomingTile() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      child: Column(
        children: [
          Icon(Icons.event_available_rounded,
              size: 44,
              color: AppColors.navySpaceCadet.withValues(alpha: 0.18)),
          const SizedBox(height: 12),
          Text(
            AppLocalizations.of(context)!.noUpcomingEvents,
            style: TextStyle(
              color: AppColors.navySpaceCadet.withValues(alpha: 0.45),
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            AppLocalizations.of(context)!.scheduleIsClear,
            style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildPastToggle(int count) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _showPastEvents = !_showPastEvents);
      },
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.navySpaceCadet.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: AppColors.navySpaceCadet.withValues(alpha: 0.1)),
        ),
        child: Row(
          children: [
            Icon(
              _showPastEvents
                  ? Icons.expand_less_rounded
                  : Icons.expand_more_rounded,
              size: 18,
              color: AppColors.navySpaceCadet.withValues(alpha: 0.5),
            ),
            const SizedBox(width: 8),
            Text(
              _showPastEvents
                  ? AppLocalizations.of(context)!.hidePastEvents
                  : AppLocalizations.of(context)!.showPastDaysWithEvents(count),
              style: TextStyle(
                color: AppColors.navySpaceCadet.withValues(alpha: 0.6),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAgendaDateHeader(DateTime day) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(day.year, day.month, day.day);
    final isToday = d == today;
    final isPast = d.isBefore(today);

    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Row(
        children: [
          // Day-of-month circle
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isToday
                  ? AppColors.primaryIndigo
                  : isPast
                      ? AppColors.navySpaceCadet.withValues(alpha: 0.08)
                      : AppColors.navySpaceCadet.withValues(alpha: 0.06),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '${day.day}',
                style: TextStyle(
                  color: isToday
                      ? AppColors.navySpaceCadet
                      : isPast
                          ? AppColors.navySpaceCadet.withValues(alpha: 0.4)
                          : AppColors.navySpaceCadet,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isToday
                    ? AppLocalizations.of(context)!.calendarToday
                    : _weekdayName(day.weekday),
                style: TextStyle(
                  color: isToday
                      ? AppColors.primaryIndigo
                      : isPast
                          ? AppColors.navySpaceCadet.withValues(alpha: 0.4)
                          : AppColors.navySpaceCadet,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
              Text(
                _monthDayYear(day),
                style: TextStyle(
                  color: isPast
                      ? Colors.grey.shade400
                      : Colors.grey.shade500,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              height: 1,
              color: AppColors.border,
            ),
          ),
        ],
      ),
    );
  }

  String _weekdayName(int weekday) {
    // weekday: 1=Mon…7=Sun. Anchor to a known Monday and offset.
    final monday = DateTime(2025, 1, 6);
    return DateFormat('EEEE', _locale).format(monday.add(Duration(days: weekday - 1)));
  }

  String _monthDayYear(DateTime d) {
    return DateFormat.yMMMMd(_locale).format(d);
  }

  // ── Empty / error states ──────────────────────────────────────────────────

  Widget _buildEmptyDay() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selected =
        DateTime(_selectedDay.year, _selectedDay.month, _selectedDay.day);
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
              isPast
                  ? Icons.event_available_rounded
                  : Icons.free_breakfast_outlined,
              size: 36,
              color: AppColors.navySpaceCadet.withValues(alpha: 0.35),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            isPast
                ? AppLocalizations.of(context)!.noEventsThisDay
                : AppLocalizations.of(context)!.freeDayLabel,
            style: TextStyle(
              color: AppColors.navySpaceCadet.withValues(alpha: 0.5),
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isPast
                ? AppLocalizations.of(context)!.nothingWasScheduled
                : AppLocalizations.of(context)!.nothingScheduledYet,
            style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.wifi_off_rounded, size: 40, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(AppLocalizations.of(context)!.couldNotLoadEvents,
              style: TextStyle(
                  color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _loadEvents,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(AppLocalizations.of(context)!.retry),
          ),
        ],
      ),
    );
  }

  // ── Shared event card (used by both day and full-agenda views) ────────────

  Widget _buildAgendaItem(Map<String, dynamic> event) {
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
          MaterialPageRoute<void>(
            builder: (_) => EventDetailScreen(event: event),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Time column ───────────────────────────────────────
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
            // ── Colored status bar ────────────────────────────────
            Column(
              children: [
                const SizedBox(height: 14),
                Container(
                  width: 3,
                  height: 52,
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 10),
            // ── Event card ────────────────────────────────────────
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
                              size: 11, color: Colors.grey.shade500),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              venue,
                              style: TextStyle(
                                  color: Colors.grey.shade600, fontSize: 11),
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
                            size: 11, color: statusColor),
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

// ─── Flat item model for the full agenda ListView ─────────────────────────────

enum _AgendaItemType { header, event, noUpcoming, pastToggle }

class _AgendaItem {
  final _AgendaItemType type;
  final DateTime? day;
  final Map<String, dynamic>? event;
  final int? pastCount;

  const _AgendaItem.header(DateTime d)
      : type = _AgendaItemType.header,
        day = d,
        event = null,
        pastCount = null;

  const _AgendaItem.event(DateTime d, this.event)
      : type = _AgendaItemType.event,
        day = d,
        pastCount = null;

  const _AgendaItem.noUpcoming()
      : type = _AgendaItemType.noUpcoming,
        day = null,
        event = null,
        pastCount = null;

  const _AgendaItem.pastToggle(this.pastCount)
      : type = _AgendaItemType.pastToggle,
        day = null,
        event = null;

  bool get isHeader => type == _AgendaItemType.header;
  bool get isNoUpcoming => type == _AgendaItemType.noUpcoming;
  bool get isPastToggle => type == _AgendaItemType.pastToggle;
}

// ─── Sub-widgets ──────────────────────────────────────────────────────────────

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

// Three-pill segmented toggle for view mode
class _ViewModeToggle extends StatelessWidget {
  final _ViewMode mode;
  final ValueChanged<_ViewMode> onChanged;

  const _ViewModeToggle({required this.mode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: Colors.white.withValues(alpha: 0.18), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _pill(l10n.calendarViewMonth, _ViewMode.month, Icons.calendar_view_month_rounded),
          _pill(l10n.calendarViewTwoWeeks, _ViewMode.twoWeeks, Icons.calendar_view_week_rounded),
          _pill(l10n.calendarViewAgenda, _ViewMode.agenda, Icons.view_agenda_rounded),
        ],
      ),
    );
  }

  Widget _pill(String label, _ViewMode target, IconData icon) {
    final active = mode == target;
    return GestureDetector(
      onTap: () => onChanged(target),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: active
              ? Colors.white.withValues(alpha: 0.95)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 12,
              color: active
                  ? AppColors.navySpaceCadet
                  : Colors.white.withValues(alpha: 0.7),
            ),
            const SizedBox(width: 3),
            Text(
              label,
              style: TextStyle(
                color: active
                    ? AppColors.navySpaceCadet
                    : Colors.white.withValues(alpha: 0.7),
                fontSize: 10,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
