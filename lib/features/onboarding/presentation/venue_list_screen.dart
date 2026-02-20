import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:nexa/l10n/app_localizations.dart';

import '../../../core/config/app_config.dart';
import '../../../shared/presentation/theme/app_colors.dart';
import '../../auth/data/services/auth_service.dart';
import '../../cities/data/models/city.dart';
import '../../venues/data/models/venue.dart';
import '../../venues/presentation/tabbed_venue_screen.dart';
import '../../venues/presentation/venue_form_screen.dart';

class VenueListScreen extends StatefulWidget {
  const VenueListScreen({Key? key}) : super(key: key);

  @override
  State<VenueListScreen> createState() => _VenueListScreenState();
}

class _VenueListScreenState extends State<VenueListScreen> {
  bool _isLoading = true;
  String? _preferredCity;
  List<City> _cities = [];
  List<Venue> _venues = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadVenues();
  }

  Future<void> _loadVenues() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final token = await AuthService.getJwt();
      if (token == null) {
        setState(() {
          _error = AppLocalizations.of(context)!.notAuthenticated;
          _isLoading = false;
        });
        return;
      }

      final baseUrl = AppConfig.instance.baseUrl;
      final headers = {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };

      // Load manager data and venues in parallel
      final responses = await Future.wait([
        http.get(Uri.parse('$baseUrl/managers/me'), headers: headers),
        http.get(Uri.parse('$baseUrl/venues'), headers: headers),
      ]);

      final managerResponse = responses[0];
      final venuesResponse = responses[1];

      if (managerResponse.statusCode == 200 && venuesResponse.statusCode == 200) {
        final managerData = jsonDecode(managerResponse.body) as Map<String, dynamic>;
        final venuesData = jsonDecode(venuesResponse.body) as Map<String, dynamic>;

        // Check if manager has multiple cities configured
        final citiesJson = managerData['cities'] as List?;
        final cities = (citiesJson ?? [])
            .map((json) => City.fromJson(json as Map<String, dynamic>))
            .toList();

        // If multiple cities, navigate to tabbed view
        if (cities.length > 1 && mounted) {
          // Replace current route with tabbed view
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => const TabbedVenueScreen(),
            ),
          );
          return;
        }

        // Load venues from new endpoint
        final venuesList = venuesData['venues'] as List?;
        final venues = venuesList
                ?.map((v) => Venue.fromJson(v as Map<String, dynamic>))
                .toList() ??
            [];

        setState(() {
          _cities = cities;
          _preferredCity = managerData['preferredCity'] as String?;
          _venues = venues;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = AppLocalizations.of(context)!.failedToLoadVenues;
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

  Future<void> _addVenue() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => const VenueFormScreen(),
      ),
    );

    if (result == true && mounted) {
      _loadVenues(); // Reload list after adding
      _showSnackBar(AppLocalizations.of(context)!.venueAddedSuccessfully, Colors.green);
    }
  }

  Future<void> _editVenue(Venue venue) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => VenueFormScreen(venue: venue),
      ),
    );

    if (result == true && mounted) {
      _loadVenues(); // Reload list after editing
      _showSnackBar(AppLocalizations.of(context)!.venueUpdatedSuccessfully, Colors.green);
    }
  }

  Future<void> _deleteVenue(Venue venue) async {
    final confirmed = await _showDeleteConfirmationDialog(venue);
    if (confirmed != true) return;

    try {
      final token = await AuthService.getJwt();
      if (token == null) {
        _showSnackBar(AppLocalizations.of(context)!.notAuthenticated, Colors.red);
        return;
      }

      final baseUrl = AppConfig.instance.baseUrl;
      final response = await http.delete(
        Uri.parse('$baseUrl/venues/${venue.id}'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 204 || response.statusCode == 200) {
        if (mounted) {
          _loadVenues(); // Reload list after deletion
          _showSnackBar(AppLocalizations.of(context)!.venueRemovedSuccessfully, Colors.orange);
        }
      } else {
        final responseBody = jsonDecode(response.body);
        _showSnackBar(
            (responseBody['message'] as String?) ?? AppLocalizations.of(context)!.failedToDeleteVenue, Colors.red);
      }
    } catch (e) {
      _showSnackBar('Error: $e', Colors.red);
    }
  }

  Future<bool?> _showDeleteConfirmationDialog(Venue venue) async {
    final l10n = AppLocalizations.of(context)!;
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(l10n.removeVenueConfirmation),
          content: Text(
            l10n.confirmRemoveVenue(venue.name),
            style: const TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: Text(l10n.remove),
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
    final l10n = AppLocalizations.of(context)!;
    final isManual = venue.isManual;
    final isPlaces = venue.isFromPlaces;

    Color badgeColor;
    IconData badgeIcon;
    String badgeText;

    if (isPlaces) {
      badgeColor = AppColors.oceanBlue;
      badgeIcon = Icons.place;
      badgeText = l10n.placesSource;
    } else if (isManual) {
      badgeColor = Colors.green;
      badgeIcon = Icons.person;
      badgeText = l10n.manualSource;
    } else {
      badgeColor = AppColors.navySpaceCadet;
      badgeIcon = Icons.smart_toy;
      badgeText = l10n.aiSource;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: badgeColor,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            badgeIcon,
            size: 14,
            color: badgeColor,
          ),
          const SizedBox(width: 4),
          Text(
            badgeText,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: badgeColor,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.myVenues),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() => _isLoading = true);
              _loadVenues();
            },
          ),
        ],
      ),
      floatingActionButton: _venues.isNotEmpty && !_isLoading
          ? FloatingActionButton.extended(
              onPressed: _addVenue,
              icon: const Icon(Icons.add),
              label: Text(l10n.addVenue),
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
                          _loadVenues();
                        },
                        child: Text(l10n.retry),
                      ),
                    ],
                  ),
                )
              : _venues.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.location_off,
                              size: 64, color: Colors.grey),
                          const SizedBox(height: 16),
                          Text(
                            l10n.noVenuesYet,
                            style: const TextStyle(fontSize: 18, color: Colors.grey),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            l10n.addFirstVenueOrDiscover,
                            style: const TextStyle(color: Colors.grey),
                          ),
                          const SizedBox(height: 24),
                          FilledButton.icon(
                            onPressed: _addVenue,
                            icon: const Icon(Icons.add),
                            label: Text(l10n.addFirstVenue),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        // Header with city and count
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _cities.isNotEmpty
                                    ? _cities.first.name
                                    : (_preferredCity ?? l10n.yourArea),
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${_venues.length} ${l10n.venues.toLowerCase()}',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Venue list with swipe-to-delete
                        Expanded(
                          child: ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: _venues.length,
                            separatorBuilder: (context, index) =>
                                const Divider(height: 24),
                            itemBuilder: (context, index) {
                              final venue = _venues[index];
                              return Dismissible(
                                key: Key('venue_${venue.id}'),
                                direction: DismissDirection.endToStart,
                                confirmDismiss: (direction) async {
                                  return await _showDeleteConfirmationDialog(venue);
                                },
                                onDismissed: (direction) {
                                  _deleteVenue(venue);
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
                                    backgroundColor: venue.isFromPlaces
                                        ? AppColors.oceanBlue
                                        : venue.isManual
                                            ? Colors.green
                                            : AppColors.navySpaceCadet,
                                    child: Icon(
                                      venue.isFromPlaces
                                          ? Icons.place
                                          : venue.isManual
                                              ? Icons.person
                                              : Icons.smart_toy,
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
                                  onTap: () => _editVenue(venue),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
    );
  }
}
