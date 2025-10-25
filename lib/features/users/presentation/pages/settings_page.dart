import 'package:flutter/material.dart';
import 'package:nexa/services/notification_service.dart';
import '../../../../core/widgets/custom_sliver_app_bar.dart';

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
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
