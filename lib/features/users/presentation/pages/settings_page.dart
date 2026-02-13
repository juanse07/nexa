import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:nexa/services/terminology_provider.dart';
import '../../../../core/widgets/custom_sliver_app_bar.dart';
import '../../../../core/config/app_config.dart';
import '../../../auth/data/services/auth_service.dart';
import '../../../cities/data/models/city.dart';
import '../../../cities/presentation/cities_list_screen.dart';
import '../../../onboarding/presentation/manager_onboarding_screen.dart';
import '../../../onboarding/presentation/venue_list_screen.dart';
import '../../../venues/presentation/venue_form_screen.dart';
import '../../../../shared/presentation/theme/app_colors.dart';
import '../../../brand/presentation/widgets/brand_customization_card.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // Venue management
  String? _preferredCity; // DEPRECATED: kept for backward compatibility
  List<City> _cities = [];
  int _venueCount = 0;
  String? _venueUpdatedAt;
  bool _loadingVenues = false;

  // Terminology management
  String? _selectedTerminology;

  @override
  void initState() {
    super.initState();
    _loadVenueInfo();
    // Load current terminology after frame is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _selectedTerminology = context.read<TerminologyProvider>().terminology;
        });
      }
    });
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
                // Terminology Section
                Card(
                  elevation: 0,
                  color: theme.colorScheme.surfaceContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Consumer<TerminologyProvider>(
                      builder: (context, terminologyProvider, _) {
                        // Initialize selected terminology if not set
                        _selectedTerminology ??= terminologyProvider.terminology;

                        final bool hasChanges = _selectedTerminology != terminologyProvider.terminology;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.work_outline,
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Work Terminology',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'How do you prefer to call your work assignments?',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 16),
                            RadioListTile<String>(
                              title: const Text('Jobs'),
                              subtitle: const Text('e.g., "My Jobs", "Create Job"'),
                              value: 'Jobs',
                              groupValue: _selectedTerminology,
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() {
                                    _selectedTerminology = value;
                                  });
                                }
                              },
                            ),
                            RadioListTile<String>(
                              title: const Text('Shifts'),
                              subtitle: const Text('e.g., "My Shifts", "Create Shift"'),
                              value: 'Shifts',
                              groupValue: _selectedTerminology,
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() {
                                    _selectedTerminology = value;
                                  });
                                }
                              },
                            ),
                            RadioListTile<String>(
                              title: const Text('Events'),
                              subtitle: const Text('e.g., "My Events", "Create Event"'),
                              value: 'Events',
                              groupValue: _selectedTerminology,
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() {
                                    _selectedTerminology = value;
                                  });
                                }
                              },
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: hasChanges
                                    ? () async {
                                        await terminologyProvider.setTerminology(_selectedTerminology!);
                                        if (mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text('Terminology updated successfully!'),
                                              backgroundColor: Colors.green,
                                            ),
                                          );
                                        }
                                      }
                                    : null,
                                icon: const Icon(Icons.check),
                                label: const Text('Save Terminology'),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primaryContainer.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    size: 20,
                                    color: theme.colorScheme.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'This will update how work assignments appear throughout the app',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Brand Customization Section
                const BrandCustomizationCard(),
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
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.yellow,
                              foregroundColor: AppColors.navySpaceCadet,
                            ),
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
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.yellow,
                                foregroundColor: AppColors.navySpaceCadet,
                              ),
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
