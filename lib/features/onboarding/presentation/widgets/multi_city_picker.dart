import 'package:flutter/material.dart';
import 'package:nexa/features/cities/data/models/city.dart';
import 'package:nexa/features/onboarding/presentation/widgets/enhanced_city_picker.dart';

/// Multi-city picker that allows selecting multiple cities with tourist flags
class MultiCityPicker extends StatefulWidget {
  final List<City> initialCities;
  final Function(List<City>) onCitiesChanged;

  const MultiCityPicker({
    super.key,
    this.initialCities = const [],
    required this.onCitiesChanged,
  });

  @override
  State<MultiCityPicker> createState() => _MultiCityPickerState();
}

class _MultiCityPickerState extends State<MultiCityPicker> {
  late List<City> _selectedCities;

  @override
  void initState() {
    super.initState();
    _selectedCities = List.from(widget.initialCities);
  }

  Future<void> _addCity() async {
    // Open the existing EnhancedCityPicker
    final cityString = await showDialog<String>(
      context: context,
      builder: (context) => const EnhancedCityPicker(),
    );

    if (cityString != null && cityString.isNotEmpty) {
      // Check if city already exists
      if (_selectedCities.any((c) => c.name.toLowerCase() == cityString.toLowerCase())) {
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

      // Determine default tourist flag from allCities database
      final cityName = cityString.split(',').first.trim();
      final cityEntry = allCities.firstWhere(
        (entry) => entry.name.toLowerCase() == cityName.toLowerCase(),
        orElse: () => const CityEntry('', '', isTourist: false),
      );

      final newCity = City(
        name: cityString,
        isTourist: cityEntry.isTourist, // Smart default from database
      );

      setState(() {
        _selectedCities.add(newCity);
      });
      widget.onCitiesChanged(_selectedCities);
    }
  }

  void _removeCity(int index) {
    setState(() {
      _selectedCities.removeAt(index);
    });
    widget.onCitiesChanged(_selectedCities);
  }

  void _toggleTouristFlag(int index) {
    setState(() {
      _selectedCities[index] = _selectedCities[index].copyWith(
        isTourist: !_selectedCities[index].isTourist,
      );
    });
    widget.onCitiesChanged(_selectedCities);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Selected cities chips
        if (_selectedCities.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _selectedCities.asMap().entries.map((entry) {
              final index = entry.key;
              final city = entry.value;
              return _CityChip(
                city: city,
                onRemove: () => _removeCity(index),
                onToggleTourist: () => _toggleTouristFlag(index),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
        ],

        // Add city button
        OutlinedButton.icon(
          onPressed: _addCity,
          icon: const Icon(Icons.add_location_alt),
          label: Text(_selectedCities.isEmpty ? 'Add Your First City' : 'Add Another City'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          ),
        ),
      ],
    );
  }
}

/// Chip widget for displaying a city with tourist flag toggle and remove button
class _CityChip extends StatelessWidget {
  final City city;
  final VoidCallback onRemove;
  final VoidCallback onToggleTourist;

  const _CityChip({
    required this.city,
    required this.onRemove,
    required this.onToggleTourist,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // City name
          Icon(
            Icons.location_city,
            size: 16,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              city.name,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),

          // Tourist flag toggle
          InkWell(
            onTap: onToggleTourist,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: city.isTourist
                    ? Theme.of(context).colorScheme.tertiary
                    : Theme.of(context).colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    city.isTourist ? Icons.tour : Icons.business,
                    size: 12,
                    color: city.isTourist
                        ? Theme.of(context).colorScheme.onTertiary
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    city.isTourist ? 'Tourist' : 'Metro',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: city.isTourist
                          ? Theme.of(context).colorScheme.onTertiary
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),

          // Remove button
          InkWell(
            onTap: onRemove,
            borderRadius: BorderRadius.circular(12),
            child: Icon(
              Icons.close,
              size: 18,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}
