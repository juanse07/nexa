import 'package:flutter/material.dart';
import 'package:nexa/features/cities/data/models/city.dart';
import 'package:nexa/features/cities/data/services/city_service.dart';
import 'package:nexa/features/onboarding/presentation/widgets/enhanced_city_picker.dart';
import 'package:nexa/core/di/injection.dart';
import 'package:nexa/l10n/app_localizations.dart';

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
        _error = '${AppLocalizations.of(context)!.failedToLoadCities}: ${e.toString()}';
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
          SnackBar(
            content: Text(AppLocalizations.of(context)!.cityAlreadyInList),
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
            content: Text(AppLocalizations.of(context)!.addedCity(cityString)),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppLocalizations.of(context)!.failedToAddCity}: ${e.toString()}'),
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
            content: Text('${AppLocalizations.of(context)!.failedToUpdateCity}: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteCity(int index) async {
    final city = _cities[index];

    // Confirm deletion
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteCity),
        content: Text(
          l10n.confirmDeleteCity(city.name),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l10n.delete),
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
            content: Text(AppLocalizations.of(context)!.deletedCity(city.name)),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppLocalizations.of(context)!.failedToDeleteCity}: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _discoverVenues(City city) async {
    final l10n = AppLocalizations.of(context)!;
    // Show confirmation dialog warning about wait time
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.discoverVenues),
        content: Text(
          l10n.discoverVenuesWarning(city.name),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.startSearch),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _discoveringVenues[city.name] = true;
    });

    try {
      final result = await _cityService.discoverVenues(city);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.discoveredVenuesCount(result.venueCount, city.name)),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppLocalizations.of(context)!.failedToDiscoverVenues}: ${e.toString()}'),
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
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.manageCities),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadCities,
            tooltip: l10n.refresh,
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
                        child: Text(l10n.retry),
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
                            l10n.noCitiesAddedYet,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            l10n.addFirstCityDiscover,
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
                                      tooltip: l10n.deleteCity,
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
                                              ? l10n.touristCityStrictSearch
                                              : l10n.metroAreaBroadSearch,
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
                                      isDiscovering ? l10n.searchingWeb : l10n.discoverVenues,
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
        label: Text(l10n.addCity),
      ),
    );
  }
}
