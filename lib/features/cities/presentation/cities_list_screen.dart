import 'package:flutter/material.dart';
import 'package:nexa/features/cities/data/models/city.dart';
import 'package:nexa/features/cities/data/services/city_service.dart';
import 'package:nexa/features/onboarding/presentation/widgets/enhanced_city_picker.dart';
import 'package:nexa/core/di/injection.dart';

/// Screen for managing cities in manager profile
class CitiesListScreen extends StatefulWidget {
  const CitiesListScreen({super.key});

  @override
  State<CitiesListScreen> createState() => _CitiesListScreenState();
}

class _CitiesListScreenState extends State<CitiesListScreen> {
  final _cityService = getIt<CityService>();
  List<City> _cities = [];
  Map<String, bool> _discoveringVenues = {}; // Track discovery state per city
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCities();
  }

  Future<void> _loadCities() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final cities = await _cityService.getCities();
      setState(() {
        _cities = cities;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load cities: ${e.toString()}';
        _loading = false;
      });
    }
  }

  Future<void> _addCity() async {
    // Open city picker
    final cityString = await showDialog<String>(
      context: context,
      builder: (context) => const EnhancedCityPicker(),
    );

    if (cityString == null || cityString.isEmpty) return;

    // Check if city already exists
    if (_cities.any((c) => c.name.toLowerCase() == cityString.toLowerCase())) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This city is already in your list'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    // Determine default tourist flag
    final cityName = cityString.split(',').first.trim();
    final cityEntry = allCities.firstWhere(
      (entry) => entry.name.toLowerCase() == cityName.toLowerCase(),
      orElse: () => const CityEntry('', '', isTourist: false),
    );

    final newCity = City(
      name: cityString,
      isTourist: cityEntry.isTourist,
    );

    try {
      final updatedCities = await _cityService.addCity(newCity);
      setState(() {
        _cities = updatedCities;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added $cityString'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add city: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _toggleTouristFlag(int index) async {
    final city = _cities[index];
    final updatedCity = city.copyWith(isTourist: !city.isTourist);

    try {
      final updatedCities = await _cityService.updateCity(index, updatedCity);
      setState(() {
        _cities = updatedCities;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update city: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteCity(int index) async {
    final city = _cities[index];

    // Confirm deletion
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete City'),
        content: Text(
          'Delete ${city.name}?\n\nThis will also remove all venues associated with this city.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final result = await _cityService.deleteCity(index);
      setState(() {
        _cities = result.cities;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Deleted ${city.name}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete city: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _discoverVenues(City city) async {
    setState(() {
      _discoveringVenues[city.name] = true;
    });

    try {
      final result = await _cityService.discoverVenues(city);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Discovered ${result.venueCount} venues for ${city.name}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to discover venues: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _discoveringVenues.remove(city.name);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Cities'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadCities,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadCities,
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
                          Icon(
                            Icons.location_city_outlined,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No cities added yet',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Add your first city to discover venues',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Colors.grey.shade600,
                                ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _cities.length,
                      itemBuilder: (context, index) {
                        final city = _cities[index];
                        final isDiscovering = _discoveringVenues[city.name] == true;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // City name and delete button
                                Row(
                                  children: [
                                    Icon(
                                      Icons.location_city,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        city.name,
                                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline),
                                      color: Colors.red.shade400,
                                      onPressed: () => _deleteCity(index),
                                      tooltip: 'Delete city',
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                // Tourist toggle
                                InkWell(
                                  onTap: () => _toggleTouristFlag(index),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: city.isTourist
                                          ? Theme.of(context).colorScheme.tertiaryContainer
                                          : Theme.of(context).colorScheme.surfaceVariant,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          city.isTourist ? Icons.tour : Icons.business,
                                          size: 18,
                                          color: city.isTourist
                                              ? Theme.of(context).colorScheme.onTertiaryContainer
                                              : Theme.of(context).colorScheme.onSurfaceVariant,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          city.isTourist
                                              ? 'Tourist City (strict search)'
                                              : 'Metro Area (broad search)',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                            color: city.isTourist
                                                ? Theme.of(context).colorScheme.onTertiaryContainer
                                                : Theme.of(context).colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Icon(
                                          Icons.edit,
                                          size: 14,
                                          color: city.isTourist
                                              ? Theme.of(context).colorScheme.onTertiaryContainer
                                              : Theme.of(context).colorScheme.onSurfaceVariant,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),

                                // Discover venues button
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: isDiscovering ? null : () => _discoverVenues(city),
                                    icon: isDiscovering
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(strokeWidth: 2),
                                          )
                                        : const Icon(Icons.search),
                                    label: Text(
                                      isDiscovering ? 'Discovering...' : 'Discover Venues',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addCity,
        icon: const Icon(Icons.add_location_alt),
        label: const Text('Add City'),
      ),
    );
  }
}
