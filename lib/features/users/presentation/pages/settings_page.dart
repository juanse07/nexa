import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:nexa/services/notification_service.dart';
import '../../../../core/widgets/custom_sliver_app_bar.dart';
import '../../../../core/config/app_config.dart';
import '../../../auth/data/services/auth_service.dart';
import '../../../cities/data/models/city.dart';
import '../../../cities/presentation/cities_list_screen.dart';
import '../../../onboarding/presentation/manager_onboarding_screen.dart';
import '../../../onboarding/presentation/venue_list_screen.dart';
import '../../../venues/presentation/venue_form_screen.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _sendingTest = false;
  bool _notificationsEnabled = true;
  bool _chatNotifications = true;
  bool _taskNotifications = true;
  bool _eventNotifications = true;
  bool _hoursNotifications = true;
  bool _systemNotifications = true;
  bool _marketingNotifications = false;

  // Venue management
  String? _preferredCity; // DEPRECATED: kept for backward compatibility
  List<City> _cities = [];
  int _venueCount = 0;
  String? _venueUpdatedAt;
  bool _loadingVenues = false;

  @override
  void initState() {
    super.initState();
    _loadVenueInfo();
  }

  /// Load current venue information from backend
  Future<void> _loadVenueInfo() async {
    try {
      final token = await AuthService.getJwt();
      if (token == null) return;

      final baseUrl = AppConfig.instance.baseUrl;
      final response = await http.get(
        Uri.parse('$baseUrl/managers/me'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200 && mounted) {
        final data = jsonDecode(response.body);
        setState(() {
          // Load cities (new multi-city structure)
          final citiesJson = data['cities'] as List?;
          _cities = (citiesJson ?? [])
              .map((json) => City.fromJson(json as Map<String, dynamic>))
              .toList();

          // Fallback to preferredCity for backward compatibility
          _preferredCity = data['preferredCity'] as String?;

          final venueList = data['venueList'] as List?;
          _venueCount = venueList?.length ?? 0;
          _venueUpdatedAt = data['venueListUpdatedAt'] as String?;
        });
      }
    } catch (e) {
      print('[Settings] Failed to load venue info: $e');
    }
  }

  /// Open venue discovery screen
  Future<void> _updateVenues() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => const ManagerOnboardingScreen(),
      ),
    );

    if (result == true && mounted) {
      // Reload venue info after update
      await _loadVenueInfo();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Venues updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _sendTestNotification() async {
    setState(() => _sendingTest = true);

    final success = await NotificationService().sendTestNotification();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Test notification sent successfully!'
                : 'Failed to send test notification',
          ),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
      setState(() => _sendingTest = false);
    }
  }

  Future<void> _updatePreferences() async {
    await NotificationService().updatePreferences({
      'chat': _chatNotifications,
      'tasks': _taskNotifications,
      'events': _eventNotifications,
      'hoursApproval': _hoursNotifications,
      'system': _systemNotifications,
      'marketing': _marketingNotifications,
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surfaceContainerLowest,
      body: CustomScrollView(
        slivers: [
          CustomSliverAppBar(
            title: 'Settings',
            subtitle: 'Manage your preferences',
            onBackPressed: () => Navigator.of(context).pop(),
            expandedHeight: 120.0,
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16.0),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Notifications Section
                Card(
                  elevation: 0,
                  color: theme.colorScheme.surfaceContainer,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            Icon(
                              Icons.notifications_outlined,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Push Notifications',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Master toggle
                      SwitchListTile(
                        title: const Text('Enable Notifications'),
                        subtitle: const Text('Receive push notifications'),
                        value: _notificationsEnabled,
                        onChanged: (value) {
                          setState(() => _notificationsEnabled = value);
                        },
                      ),
                      const Divider(indent: 16, endIndent: 16),
                      // Notification types
                      SwitchListTile(
                        title: const Text('Chat Messages'),
                        subtitle: const Text('New messages from staff'),
                        value: _chatNotifications && _notificationsEnabled,
                        onChanged: _notificationsEnabled
                            ? (value) {
                                setState(() => _chatNotifications = value);
                                _updatePreferences();
                              }
                            : null,
                      ),
                      SwitchListTile(
                        title: const Text('Task Assignments'),
                        subtitle: const Text('When tasks are assigned to staff'),
                        value: _taskNotifications && _notificationsEnabled,
                        onChanged: _notificationsEnabled
                            ? (value) {
                                setState(() => _taskNotifications = value);
                                _updatePreferences();
                              }
                            : null,
                      ),
                      SwitchListTile(
                        title: const Text('Event Updates'),
                        subtitle: const Text('Event reminders and changes'),
                        value: _eventNotifications && _notificationsEnabled,
                        onChanged: _notificationsEnabled
                            ? (value) {
                                setState(() => _eventNotifications = value);
                                _updatePreferences();
                              }
                            : null,
                      ),
                      SwitchListTile(
                        title: const Text('Hours Approval'),
                        subtitle: const Text('Timesheet submissions'),
                        value: _hoursNotifications && _notificationsEnabled,
                        onChanged: _notificationsEnabled
                            ? (value) {
                                setState(() => _hoursNotifications = value);
                                _updatePreferences();
                              }
                            : null,
                      ),
                      SwitchListTile(
                        title: const Text('System Alerts'),
                        subtitle: const Text('Important system notifications'),
                        value: _systemNotifications && _notificationsEnabled,
                        onChanged: _notificationsEnabled
                            ? (value) {
                                setState(() => _systemNotifications = value);
                                _updatePreferences();
                              }
                            : null,
                      ),
                      SwitchListTile(
                        title: const Text('Marketing'),
                        subtitle: const Text('Promotional messages and offers'),
                        value: _marketingNotifications && _notificationsEnabled,
                        onChanged: _notificationsEnabled
                            ? (value) {
                                setState(() => _marketingNotifications = value);
                                _updatePreferences();
                              }
                            : null,
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Test notification card
                Card(
                  elevation: 0,
                  color: theme.colorScheme.surfaceContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.bug_report_outlined,
                              color: theme.colorScheme.secondary,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Test Notifications',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Send a test notification to verify your device is properly configured.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _sendingTest || !_notificationsEnabled
                                ? null
                                : _sendTestNotification,
                            icon: _sendingTest
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.send),
                            label: Text(
                              _sendingTest
                                  ? 'Sending...'
                                  : 'Send Test Notification',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Venue Management Section
                Card(
                  elevation: 0,
                  color: theme.colorScheme.surfaceContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.location_city,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Location & Venues',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (_cities.isNotEmpty) ...[
                          _buildInfoRow(
                            icon: Icons.location_city,
                            label: _cities.length == 1 ? 'City' : 'Cities',
                            value: _cities.length == 1
                                ? _cities.first.name
                                : '${_cities.length} cities configured',
                            theme: theme,
                          ),
                          const SizedBox(height: 12),
                          _buildInfoRow(
                            icon: Icons.business,
                            label: 'Venues',
                            value: '$_venueCount discovered',
                            theme: theme,
                          ),
                          if (_venueUpdatedAt != null) ...[
                            const SizedBox(height: 12),
                            _buildInfoRow(
                              icon: Icons.update,
                              label: 'Last Updated',
                              value: _formatDate(_venueUpdatedAt!),
                              theme: theme,
                            ),
                          ],
                        ] else if (_preferredCity != null) ...[
                          // Fallback for backward compatibility with old single-city structure
                          _buildInfoRow(
                            icon: Icons.place,
                            label: 'City',
                            value: _preferredCity!,
                            theme: theme,
                          ),
                          const SizedBox(height: 12),
                          _buildInfoRow(
                            icon: Icons.business,
                            label: 'Venues',
                            value: '$_venueCount discovered',
                            theme: theme,
                          ),
                          if (_venueUpdatedAt != null) ...[
                            const SizedBox(height: 12),
                            _buildInfoRow(
                              icon: Icons.update,
                              label: 'Last Updated',
                              value: _formatDate(_venueUpdatedAt!),
                              theme: theme,
                            ),
                          ],
                        ] else ...[
                          Text(
                            'No cities configured yet. Add cities to discover venues and help the AI suggest accurate event locations in your area.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => const CitiesListScreen(),
                                ),
                              );
                              // Reload venue info after returning from cities management
                              if (mounted) {
                                await _loadVenueInfo();
                              }
                            },
                            icon: Icon(_cities.isNotEmpty || _preferredCity != null
                                ? Icons.location_city
                                : Icons.add_location_alt),
                            label: Text(_cities.isNotEmpty || _preferredCity != null
                                ? 'Manage Cities'
                                : 'Add Cities'),
                          ),
                        ),
                        if (_venueCount > 0) ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => const VenueListScreen(),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.list),
                              label: Text('View All $_venueCount Venues'),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: () async {
                                final result = await Navigator.of(context).push<bool>(
                                  MaterialPageRoute(
                                    builder: (context) => const VenueFormScreen(),
                                  ),
                                );
                                if (result == true && mounted) {
                                  _loadVenueInfo(); // Reload venue count
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Venue added successfully!'),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              },
                              icon: const Icon(Icons.add_location_alt),
                              label: const Text('Add New Venue'),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required ThemeData theme,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  String _formatDate(String isoDate) {
    try {
      final date = DateTime.parse(isoDate);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays == 0) {
        return 'Today';
      } else if (difference.inDays == 1) {
        return 'Yesterday';
      } else if (difference.inDays < 7) {
        return '${difference.inDays} days ago';
      } else if (difference.inDays < 30) {
        final weeks = (difference.inDays / 7).floor();
        return '$weeks ${weeks == 1 ? 'week' : 'weeks'} ago';
      } else {
        return '${date.month}/${date.day}/${date.year}';
      }
    } catch (e) {
      return 'Unknown';
    }
  }
}
