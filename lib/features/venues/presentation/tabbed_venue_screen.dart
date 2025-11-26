import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../../core/config/app_config.dart';
import '../../auth/data/services/auth_service.dart';
import '../../cities/data/models/city.dart';
import '../data/models/venue.dart';
import 'venue_form_screen.dart';
import 'package:nexa/shared/presentation/theme/app_colors.dart';

/// Tabbed venue screen with one tab per city
class TabbedVenueScreen extends StatefulWidget {
  const TabbedVenueScreen({super.key});

  @override
  State<TabbedVenueScreen> createState() => _TabbedVenueScreenState();
}

class _TabbedVenueScreenState extends State<TabbedVenueScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  List<City> _cities = [];
  List<Venue> _allVenues = [];
  String? _error;
  TabController? _tabController;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final token = await AuthService.getJwt();
      if (token == null) {
        setState(() {
          _error = 'Not authenticated';
          _isLoading = false;
        });
        return;
      }

      final baseUrl = AppConfig.instance.baseUrl;
      final response = await http.get(
        Uri.parse('$baseUrl/managers/me'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;

        // Load cities
        final citiesJson = data['cities'] as List?;
        final cities = (citiesJson ?? [])
            .map((json) => City.fromJson(json as Map<String, dynamic>))
            .toList();

        // Load venues
        final venueList = data['venueList'] as List?;
        final venues = venueList
                ?.map((v) => Venue.fromJson(v as Map<String, dynamic>))
                .toList() ??
            [];

        // Dispose old tab controller before creating new one
        _tabController?.dispose();
        final newTabController = TabController(length: cities.length, vsync: this);

        setState(() {
          _cities = cities;
          _allVenues = venues;
          _tabController = newTabController;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Failed to load data';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  /// Get venues for a specific city
  List<Venue> _getVenuesForCity(City city) {
    return _allVenues
        .where((venue) => venue.cityName == city.name)
        .toList();
  }

  Future<void> _addVenue() async {
    if (_cities.isEmpty) return;

    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => const VenueFormScreen(),
      ),
    );

    if (result == true && mounted) {
      _loadData(); // Reload data after adding
      _showSnackBar('Venue added successfully!', Colors.green);
    }
  }

  Future<void> _editVenue(Venue venue, int globalIndex) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => VenueFormScreen(venue: venue, venueIndex: globalIndex),
      ),
    );

    if (result == true && mounted) {
      _loadData(); // Reload data after editing
      _showSnackBar('Venue updated successfully!', Colors.green);
    }
  }

  Future<void> _deleteVenue(int globalIndex) async {
    final confirmed = await _showDeleteConfirmationDialog(globalIndex);
    if (confirmed != true) return;

    try {
      final token = await AuthService.getJwt();
      if (token == null) {
        _showSnackBar('Not authenticated', Colors.red);
        return;
      }

      final baseUrl = AppConfig.instance.baseUrl;
      final response = await http.delete(
        Uri.parse('$baseUrl/managers/me/venues/$globalIndex'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        if (mounted) {
          _loadData(); // Reload data after deletion
          _showSnackBar('Venue removed successfully!', Colors.orange);
        }
      } else {
        final responseBody = jsonDecode(response.body);
        _showSnackBar(
            (responseBody['message'] as String?) ?? 'Failed to delete venue',
            Colors.red);
      }
    } catch (e) {
      _showSnackBar('Error: $e', Colors.red);
    }
  }

  Future<bool?> _showDeleteConfirmationDialog(int index) async {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        final venue = _allVenues[index];
        return AlertDialog(
          title: const Text('Remove Venue?'),
          content: Text(
            'Are you sure you want to remove "${venue.name}"?',
            style: const TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );
  }

  void _showSnackBar(String message, Color backgroundColor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildSourceBadge(Venue venue) {
    final isManual = venue.isManual;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isManual ? Colors.green.withOpacity(0.1) : Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isManual ? Colors.green : Colors.blue,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isManual ? Icons.person : Icons.smart_toy,
            size: 14,
            color: isManual ? Colors.green[700] : Colors.blue[700],
          ),
          const SizedBox(width: 4),
          Text(
            isManual ? 'Manual' : 'AI',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isManual ? Colors.green[900] : Colors.blue[900],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCityTab(City city) {
    final venues = _getVenuesForCity(city);

    if (venues.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.location_off, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                'No venues in ${city.displayName} yet',
                style: const TextStyle(fontSize: 18, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Add venues manually or discover them from Settings > Manage Cities',
                style: TextStyle(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _addVenue,
                icon: const Icon(Icons.add),
                label: const Text('Add First Venue'),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // Header with city and count
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          color: Theme.of(context).primaryColor.withOpacity(0.1),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                city.name,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    '${venues.length} venues',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: city.isTourist
                          ? AppColors.yellow.withOpacity(0.1)
                          : Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      city.isTourist ? 'Tourist City' : 'Metro Area',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: city.isTourist ? AppColors.primaryPurple : Colors.blue[700],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        // Venue list
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: venues.length,
            separatorBuilder: (context, index) => const Divider(height: 24),
            itemBuilder: (context, index) {
              final venue = venues[index];
              // Find global index for delete/edit operations
              final globalIndex = _allVenues.indexOf(venue);

              return Dismissible(
                key: Key('venue_$globalIndex'),
                direction: DismissDirection.endToStart,
                confirmDismiss: (direction) async {
                  return await _showDeleteConfirmationDialog(globalIndex);
                },
                onDismissed: (direction) {
                  _deleteVenue(globalIndex);
                },
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  color: Colors.red,
                  child: const Icon(
                    Icons.delete,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: venue.isManual
                        ? Colors.green
                        : Theme.of(context).primaryColor,
                    child: Icon(
                      venue.isManual ? Icons.person : Icons.smart_toy,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          venue.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      _buildSourceBadge(venue),
                    ],
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      venue.address,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ),
                  trailing: Icon(
                    Icons.edit,
                    color: Colors.grey[400],
                  ),
                  onTap: () => _editVenue(venue, globalIndex),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Venues'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() => _isLoading = true);
              _loadData();
            },
          ),
        ],
        bottom: _cities.isNotEmpty && !_isLoading && _tabController != null
            ? TabBar(
                controller: _tabController!,
                isScrollable: true,
                tabs: _cities
                    .map((city) => Tab(
                          text: city.displayName,
                          icon: Icon(
                            city.isTourist ? Icons.tour : Icons.business,
                            size: 18,
                          ),
                        ))
                    .toList(),
              )
            : null,
      ),
      floatingActionButton: _cities.isNotEmpty && !_isLoading
          ? FloatingActionButton.extended(
              onPressed: _addVenue,
              icon: const Icon(Icons.add),
              label: const Text('Add Venue'),
            )
          : null,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _isLoading = true;
                            _error = null;
                          });
                          _loadData();
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _cities.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.location_city_outlined,
                              size: 64, color: Colors.grey.shade400),
                          const SizedBox(height: 16),
                          const Text(
                            'No cities configured',
                            style: TextStyle(fontSize: 18, color: Colors.grey),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Add cities from Settings > Manage Cities',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : _tabController != null
                      ? TabBarView(
                          controller: _tabController!,
                          children: _cities.map(_buildCityTab).toList(),
                        )
                      : const Center(child: CircularProgressIndicator()),
    );
  }
}
