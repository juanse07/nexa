import 'dart:ui';
import 'package:flutter/material.dart';
import '../../models/attendance_dashboard_models.dart';
import 'pulse_indicator.dart';

/// Hero header with gradient background and glassmorphism stat cards
class AttendanceHeroHeader extends StatelessWidget {
  final AttendanceAnalytics analytics;
  final VoidCallback onFilterTap;
  final VoidCallback onFlagsTap;
  final bool isLoading;

  const AttendanceHeroHeader({
    super.key,
    required this.analytics,
    required this.onFilterTap,
    required this.onFlagsTap,
    this.isLoading = false,
  });

  // Theme colors
  static const _navyBlue = Color(0xFF1A237E);
  static const _purpleAccent = Color(0xFF667eea);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_navyBlue, _purpleAccent],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title row with filter button
              Row(
                children: [
                  const PulseIndicator(
                    color: Colors.greenAccent,
                    size: 10,
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Live Attendance',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: onFilterTap,
                    icon: const Icon(
                      Icons.tune_rounded,
                      color: Colors.white70,
                    ),
                    tooltip: 'Filters',
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Stat cards row
              SizedBox(
                height: 90,
                child: Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        value: isLoading ? '--' : '${analytics.currentlyWorking}',
                        label: 'Working',
                        icon: Icons.person_outline,
                        iconColor: Colors.greenAccent,
                        showPulse: analytics.currentlyWorking > 0,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        value: isLoading ? '--' : analytics.todayTotalHours.toStringAsFixed(1),
                        label: 'Hours Today',
                        icon: Icons.access_time_rounded,
                        iconColor: Colors.amber,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: onFlagsTap,
                        child: _StatCard(
                          value: isLoading ? '--' : '${analytics.pendingFlags}',
                          label: 'Flags',
                          icon: Icons.flag_outlined,
                          iconColor: analytics.pendingFlags > 0
                              ? Colors.redAccent
                              : Colors.grey,
                          showBadge: analytics.pendingFlags > 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Glassmorphism stat card
class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color iconColor;
  final bool showPulse;
  final bool showBadge;

  const _StatCard({
    required this.value,
    required this.label,
    required this.icon,
    required this.iconColor,
    this.showPulse = false,
    this.showBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Icon(icon, color: iconColor, size: 18),
                  if (showPulse) ...[
                    const SizedBox(width: 6),
                    PulseIndicator(color: iconColor, size: 6),
                  ],
                  if (showBadge) ...[
                    const Spacer(),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.redAccent,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.redAccent.withOpacity(0.5),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Collapsible sliver version of the hero header
class SliverAttendanceHeroHeader extends StatelessWidget {
  final AttendanceAnalytics analytics;
  final VoidCallback onFilterTap;
  final VoidCallback onFlagsTap;
  final bool isLoading;

  const SliverAttendanceHeroHeader({
    super.key,
    required this.analytics,
    required this.onFilterTap,
    required this.onFlagsTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 200,
      floating: false,
      pinned: true,
      backgroundColor: const Color(0xFF1A237E),
      flexibleSpace: FlexibleSpaceBar(
        background: AttendanceHeroHeader(
          analytics: analytics,
          onFilterTap: onFilterTap,
          onFlagsTap: onFlagsTap,
          isLoading: isLoading,
        ),
        collapseMode: CollapseMode.pin,
      ),
      title: const Text(
        'Attendance',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
      actions: [
        IconButton(
          onPressed: onFilterTap,
          icon: const Icon(Icons.tune_rounded, color: Colors.white70),
        ),
      ],
    );
  }
}
