import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../../core/config/app_config.dart';
import '../../auth/data/services/auth_service.dart';
import '../../venues/data/models/venue.dart';
import '../../venues/presentation/venue_form_screen.dart';

class VenueListScreen extends StatefulWidget {
  const VenueListScreen({Key? key}) : super(key: key);

  @override
  State<VenueListScreen> createState() => _VenueListScreenState();
}

class _VenueListScreenState extends State<VenueListScreen> {
  bool _isLoading = true;
  String? _preferredCity;
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
        setState(() {
          _preferredCity = data['preferredCity'] as String?;
          final venueList = data['venueList'] as List?;
          _venues = venueList
                  ?.map((v) => Venue.fromJson(v as Map<String, dynamic>))
                  .toList() ??
              [];
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Failed to load venues';
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
      _showSnackBar('Venue added successfully!', Colors.green);
    }
  }

  Future<void> _editVenue(Venue venue, int index) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => VenueFormScreen(venue: venue, venueIndex: index),
      ),
    );

    if (result == true && mounted) {
      _loadVenues(); // Reload list after editing
      _showSnackBar('Venue updated successfully!', Colors.green);
    }
  }

  Future<void> _deleteVenue(int index) async {
    final confirmed = await _showDeleteConfirmationDialog(index);
    if (confirmed != true) return;

    try {
      final token = await AuthService.getJwt();
      if (token == null) {
        _showSnackBar('Not authenticated', Colors.red);
        return;
      }

      final baseUrl = AppConfig.instance.baseUrl;
      final response = await http.delete(
        Uri.parse('$baseUrl/managers/me/venues/$index'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        if (mounted) {
          _loadVenues(); // Reload list after deletion
          _showSnackBar('Venue removed successfully!', Colors.orange);
        }
      } else {
        final responseBody = jsonDecode(response.body);
        _showSnackBar(
            (responseBody['message'] as String?) ?? 'Failed to delete venue', Colors.red);
      }
    } catch (e) {
      _showSnackBar('Error: $e', Colors.red);
    }
  }

  Future<bool?> _showDeleteConfirmationDialog(int index) async {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        final venue = _venues[index];
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
              _loadVenues();
            },
          ),
        ],
      ),
      floatingActionButton: _venues.isNotEmpty && !_isLoading
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
                          _loadVenues();
                        },
                        child: const Text('Retry'),
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
                          const Text(
                            'No venues yet',
                            style: TextStyle(fontSize: 18, color: Colors.grey),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Add your first venue or run venue discovery',
                            style: TextStyle(color: Colors.grey),
                          ),
                          const SizedBox(height: 24),
                          FilledButton.icon(
                            onPressed: _addVenue,
                            icon: const Icon(Icons.add),
                            label: const Text('Add First Venue'),
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
                          color: Theme.of(context).primaryColor.withOpacity(0.1),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _preferredCity ?? 'Your Area',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${_venues.length} venues',
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
                                key: Key('venue_$index'),
                                direction: DismissDirection.endToStart,
                                confirmDismiss: (direction) async {
                                  return await _showDeleteConfirmationDialog(index);
                                },
                                onDismissed: (direction) {
                                  _deleteVenue(index);
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
                                      venue.isManual
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
                                  onTap: () => _editVenue(venue, index),
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
