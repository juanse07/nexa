import 'package:flutter/material.dart';

/// Enhanced city picker with comprehensive list + free-form entry
class EnhancedCityPicker extends StatefulWidget {
  final String? initialCity;

  const EnhancedCityPicker({super.key, this.initialCity});

  @override
  State<EnhancedCityPicker> createState() => _EnhancedCityPickerState();
}

class _EnhancedCityPickerState extends State<EnhancedCityPicker> {
  final TextEditingController _searchController = TextEditingController();
  String? _selectedCountry;
  String? _selectedState;
  List<CityEntry> _filteredCities = [];
  bool _showCustomEntry = false;

  @override
  void initState() {
    super.initState();
    _filteredCities = allCities;
    if (widget.initialCity != null) {
      _searchController.text = widget.initialCity!;
      _filterCities();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterCities() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredCities = allCities;
        _showCustomEntry = false;
      } else {
        _filteredCities = allCities.where((city) {
          final matchesSearch = city.name.toLowerCase().contains(query) ||
              city.country.toLowerCase().contains(query) ||
              (city.state?.toLowerCase().contains(query) ?? false);
          final matchesCountry =
              _selectedCountry == null || city.country == _selectedCountry;
          final matchesState =
              _selectedState == null || city.state == _selectedState;
          return matchesSearch && matchesCountry && matchesState;
        }).toList();

        // Show custom entry if no exact match
        _showCustomEntry = !_filteredCities.any((city) =>
            city.name.toLowerCase() == query && city.country == _selectedCountry);
      }
    });
  }

  void _selectCity(CityEntry city) {
    final cityString = city.state != null
        ? '${city.name}, ${city.state}, ${city.country}'
        : '${city.name}, ${city.country}';
    Navigator.of(context).pop(cityString);
  }

  void _useCustomEntry() {
    final text = _searchController.text.trim();
    if (text.isNotEmpty) {
      Navigator.of(context).pop(text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uniqueCountries =
        allCities.map((c) => c.country).toSet().toList()..sort();

    final uniqueStates = _selectedCountry != null
        ? (allCities
            .where((c) => c.country == _selectedCountry && c.state != null)
            .map((c) => c.state!)
            .toSet()
            .toList()
          ..sort())
        : <String>[];

    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.85,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Header
            Row(
              children: [
                const Text(
                  'Select or Type City',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Country filter
            DropdownButtonFormField<String>(
              value: _selectedCountry,
              decoration: InputDecoration(
                labelText: 'Country',
                prefixIcon: const Icon(Icons.public),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: [
                const DropdownMenuItem<String>(value: null, child: Text('All Countries')),
                ...uniqueCountries.map((c) => DropdownMenuItem(value: c, child: Text(c))),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedCountry = value;
                  _selectedState = null;
                  _filterCities();
                });
              },
            ),

            // State filter (if country selected)
            if (uniqueStates.isNotEmpty) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _selectedState,
                decoration: InputDecoration(
                  labelText: 'State/Province',
                  prefixIcon: const Icon(Icons.map),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: [
                  const DropdownMenuItem<String>(value: null, child: Text('All States')),
                  ...uniqueStates.map((String s) => DropdownMenuItem<String>(value: s, child: Text(s))),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedState = value;
                    _filterCities();
                  });
                },
              ),
            ],

            const SizedBox(height: 12),

            // Search field
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Type or Search City',
                hintText: 'Enter any city name...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
              ),
              onChanged: (value) => _filterCities(),
            ),
            const SizedBox(height: 16),

            // Custom entry button
            if (_showCustomEntry && _searchController.text.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue),
                ),
                child: InkWell(
                  onTap: _useCustomEntry,
                  child: Row(
                    children: [
                      const Icon(Icons.add_location_alt, color: Colors.blue),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Use custom city:',
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                            Text(
                              '"${_searchController.text}"',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward, color: Colors.blue),
                    ],
                  ),
                ),
              ),

            if (_showCustomEntry) const SizedBox(height: 12),

            // Results count
            Text(
              '${_filteredCities.length} suggested cities',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            const SizedBox(height: 8),

            // City list
            Expanded(
              child: _filteredCities.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off, size: 48, color: Colors.grey[400]),
                          const SizedBox(height: 8),
                          Text(
                            'No matching cities in suggestions',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'You can type any city name above',
                            style: TextStyle(color: Colors.grey[500], fontSize: 12),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _filteredCities.length,
                      itemBuilder: (context, index) {
                        final city = _filteredCities[index];
                        return ListTile(
                          leading: CircleAvatar(
                            child: Text(city.name[0]),
                          ),
                          title: Text(city.name),
                          subtitle: city.state != null
                              ? Text('${city.state}, ${city.country}')
                              : Text(city.country),
                          trailing: city.isTourist
                              ? Chip(
                                  label: const Text(
                                    'Tourist',
                                    style: TextStyle(fontSize: 10),
                                  ),
                                  backgroundColor: Colors.orange.withOpacity(0.2),
                                  side: const BorderSide(color: Colors.orange),
                                )
                              : null,
                          onTap: () => _selectCity(city),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class CityEntry {
  final String name;
  final String country;
  final String? state;
  final bool isTourist;

  const CityEntry(this.name, this.country, {this.state, this.isTourist = false});
}

// Comprehensive city database with tourist destinations marked
final List<CityEntry> allCities = [
  // Colorado - Including ALL tourist destinations
  const CityEntry('Denver', 'United States', state: 'Colorado'),
  const CityEntry('Colorado Springs', 'United States', state: 'Colorado'),
  const CityEntry('Aurora', 'United States', state: 'Colorado'),
  const CityEntry('Fort Collins', 'United States', state: 'Colorado'),
  const CityEntry('Boulder', 'United States', state: 'Colorado'),

  // Colorado Tourist/Resort Cities
  const CityEntry('Vail', 'United States', state: 'Colorado', isTourist: true),
  const CityEntry('Aspen', 'United States', state: 'Colorado', isTourist: true),
  const CityEntry('Breckenridge', 'United States', state: 'Colorado', isTourist: true),
  const CityEntry('Telluride', 'United States', state: 'Colorado', isTourist: true),
  const CityEntry('Steamboat Springs', 'United States', state: 'Colorado', isTourist: true),
  const CityEntry('Winter Park', 'United States', state: 'Colorado', isTourist: true),
  const CityEntry('Keystone', 'United States', state: 'Colorado', isTourist: true),
  const CityEntry('Copper Mountain', 'United States', state: 'Colorado', isTourist: true),
  const CityEntry('Crested Butte', 'United States', state: 'Colorado', isTourist: true),
  const CityEntry('Estes Park', 'United States', state: 'Colorado', isTourist: true),
  const CityEntry('Central City', 'United States', state: 'Colorado', isTourist: true),
  const CityEntry('Black Hawk', 'United States', state: 'Colorado', isTourist: true),
  const CityEntry('Durango', 'United States', state: 'Colorado', isTourist: true),
  const CityEntry('Glenwood Springs', 'United States', state: 'Colorado', isTourist: true),
  const CityEntry('Manitou Springs', 'United States', state: 'Colorado', isTourist: true),
  const CityEntry('Ouray', 'United States', state: 'Colorado', isTourist: true),
  const CityEntry('Silverton', 'United States', state: 'Colorado', isTourist: true),

  // California
  const CityEntry('Los Angeles', 'United States', state: 'California'),
  const CityEntry('San Francisco', 'United States', state: 'California'),
  const CityEntry('San Diego', 'United States', state: 'California'),
  const CityEntry('San Jose', 'United States', state: 'California'),
  const CityEntry('Sacramento', 'United States', state: 'California'),
  const CityEntry('Oakland', 'United States', state: 'California'),
  const CityEntry('Fresno', 'United States', state: 'California'),
  const CityEntry('Long Beach', 'United States', state: 'California'),
  // California Tourist Cities
  const CityEntry('Napa', 'United States', state: 'California', isTourist: true),
  const CityEntry('Lake Tahoe', 'United States', state: 'California', isTourist: true),
  const CityEntry('Big Sur', 'United States', state: 'California', isTourist: true),
  const CityEntry('Palm Springs', 'United States', state: 'California', isTourist: true),
  const CityEntry('Carmel-by-the-Sea', 'United States', state: 'California', isTourist: true),
  const CityEntry('Santa Barbara', 'United States', state: 'California', isTourist: true),
  const CityEntry('Monterey', 'United States', state: 'California', isTourist: true),

  // New York
  const CityEntry('New York', 'United States', state: 'New York'),
  const CityEntry('Buffalo', 'United States', state: 'New York'),
  const CityEntry('Rochester', 'United States', state: 'New York'),
  const CityEntry('Albany', 'United States', state: 'New York'),
  const CityEntry('Syracuse', 'United States', state: 'New York'),
  const CityEntry('Niagara Falls', 'United States', state: 'New York', isTourist: true),
  const CityEntry('Lake Placid', 'United States', state: 'New York', isTourist: true),
  const CityEntry('Saratoga Springs', 'United States', state: 'New York', isTourist: true),

  // Texas
  const CityEntry('Houston', 'United States', state: 'Texas'),
  const CityEntry('San Antonio', 'United States', state: 'Texas'),
  const CityEntry('Dallas', 'United States', state: 'Texas'),
  const CityEntry('Austin', 'United States', state: 'Texas'),
  const CityEntry('Fort Worth', 'United States', state: 'Texas'),
  const CityEntry('El Paso', 'United States', state: 'Texas'),
  const CityEntry('South Padre Island', 'United States', state: 'Texas', isTourist: true),

  // Florida
  const CityEntry('Miami', 'United States', state: 'Florida'),
  const CityEntry('Orlando', 'United States', state: 'Florida', isTourist: true),
  const CityEntry('Tampa', 'United States', state: 'Florida'),
  const CityEntry('Jacksonville', 'United States', state: 'Florida'),
  const CityEntry('Key West', 'United States', state: 'Florida', isTourist: true),
  const CityEntry('Fort Lauderdale', 'United States', state: 'Florida'),
  const CityEntry('Naples', 'United States', state: 'Florida', isTourist: true),
  const CityEntry('Clearwater', 'United States', state: 'Florida', isTourist: true),
  const CityEntry('Panama City Beach', 'United States', state: 'Florida', isTourist: true),

  // Nevada
  const CityEntry('Las Vegas', 'United States', state: 'Nevada', isTourist: true),
  const CityEntry('Reno', 'United States', state: 'Nevada'),
  const CityEntry('Henderson', 'United States', state: 'Nevada'),

  // Arizona
  const CityEntry('Phoenix', 'United States', state: 'Arizona'),
  const CityEntry('Tucson', 'United States', state: 'Arizona'),
  const CityEntry('Mesa', 'United States', state: 'Arizona'),
  const CityEntry('Scottsdale', 'United States', state: 'Arizona'),
  const CityEntry('Sedona', 'United States', state: 'Arizona', isTourist: true),
  const CityEntry('Flagstaff', 'United States', state: 'Arizona', isTourist: true),

  // Washington
  const CityEntry('Seattle', 'United States', state: 'Washington'),
  const CityEntry('Spokane', 'United States', state: 'Washington'),
  const CityEntry('Tacoma', 'United States', state: 'Washington'),

  // Oregon
  const CityEntry('Portland', 'United States', state: 'Oregon'),
  const CityEntry('Eugene', 'United States', state: 'Oregon'),
  const CityEntry('Salem', 'United States', state: 'Oregon'),
  const CityEntry('Bend', 'United States', state: 'Oregon', isTourist: true),

  // Utah
  const CityEntry('Salt Lake City', 'United States', state: 'Utah'),
  const CityEntry('Park City', 'United States', state: 'Utah', isTourist: true),
  const CityEntry('Moab', 'United States', state: 'Utah', isTourist: true),

  // Hawaii
  const CityEntry('Honolulu', 'United States', state: 'Hawaii', isTourist: true),
  const CityEntry('Maui', 'United States', state: 'Hawaii', isTourist: true),
  const CityEntry('Kauai', 'United States', state: 'Hawaii', isTourist: true),
  const CityEntry('Kona', 'United States', state: 'Hawaii', isTourist: true),

  // Alaska
  const CityEntry('Anchorage', 'United States', state: 'Alaska'),
  const CityEntry('Juneau', 'United States', state: 'Alaska', isTourist: true),

  // Other Major US Cities
  const CityEntry('Chicago', 'United States', state: 'Illinois'),
  const CityEntry('Philadelphia', 'United States', state: 'Pennsylvania'),
  const CityEntry('Boston', 'United States', state: 'Massachusetts'),
  const CityEntry('Nashville', 'United States', state: 'Tennessee'),
  const CityEntry('Atlanta', 'United States', state: 'Georgia'),
  const CityEntry('Minneapolis', 'United States', state: 'Minnesota'),
  const CityEntry('Detroit', 'United States', state: 'Michigan'),
  const CityEntry('Baltimore', 'United States', state: 'Maryland'),
  const CityEntry('Washington DC', 'United States', state: 'District of Columbia'),
  const CityEntry('Charlotte', 'United States', state: 'North Carolina'),
  const CityEntry('Indianapolis', 'United States', state: 'Indiana'),
  const CityEntry('Columbus', 'United States', state: 'Ohio'),
  const CityEntry('Cleveland', 'United States', state: 'Ohio'),
  const CityEntry('Cincinnati', 'United States', state: 'Ohio'),
  const CityEntry('Pittsburgh', 'United States', state: 'Pennsylvania'),
  const CityEntry('Kansas City', 'United States', state: 'Missouri'),
  const CityEntry('St. Louis', 'United States', state: 'Missouri'),
  const CityEntry('Milwaukee', 'United States', state: 'Wisconsin'),
  const CityEntry('New Orleans', 'United States', state: 'Louisiana', isTourist: true),
  const CityEntry('Memphis', 'United States', state: 'Tennessee'),
  const CityEntry('Louisville', 'United States', state: 'Kentucky'),
  const CityEntry('Oklahoma City', 'United States', state: 'Oklahoma'),
  const CityEntry('Raleigh', 'United States', state: 'North Carolina'),
  const CityEntry('Savannah', 'United States', state: 'Georgia', isTourist: true),
  const CityEntry('Charleston', 'United States', state: 'South Carolina', isTourist: true),
  const CityEntry('Myrtle Beach', 'United States', state: 'South Carolina', isTourist: true),

  // Canada
  const CityEntry('Toronto', 'Canada', state: 'Ontario'),
  const CityEntry('Montreal', 'Canada', state: 'Quebec'),
  const CityEntry('Vancouver', 'Canada', state: 'British Columbia'),
  const CityEntry('Calgary', 'Canada', state: 'Alberta'),
  const CityEntry('Edmonton', 'Canada', state: 'Alberta'),
  const CityEntry('Ottawa', 'Canada', state: 'Ontario'),
  const CityEntry('Whistler', 'Canada', state: 'British Columbia', isTourist: true),
  const CityEntry('Banff', 'Canada', state: 'Alberta', isTourist: true),
  const CityEntry('Niagara Falls', 'Canada', state: 'Ontario', isTourist: true),
  const CityEntry('Quebec City', 'Canada', state: 'Quebec', isTourist: true),

  // Mexico
  const CityEntry('Mexico City', 'Mexico'),
  const CityEntry('Guadalajara', 'Mexico'),
  const CityEntry('Monterrey', 'Mexico'),
  const CityEntry('Cancún', 'Mexico', isTourist: true),
  const CityEntry('Playa del Carmen', 'Mexico', isTourist: true),
  const CityEntry('Cabo San Lucas', 'Mexico', isTourist: true),
  const CityEntry('Puerto Vallarta', 'Mexico', isTourist: true),
  const CityEntry('Tulum', 'Mexico', isTourist: true),

  // Add all international cities from before...
  const CityEntry('London', 'United Kingdom'),
  const CityEntry('Paris', 'France'),
  const CityEntry('Berlin', 'Germany'),
  const CityEntry('Madrid', 'Spain'),
  const CityEntry('Barcelona', 'Spain'),
  const CityEntry('Rome', 'Italy'),
  const CityEntry('Milan', 'Italy'),
  const CityEntry('Amsterdam', 'Netherlands'),
  const CityEntry('Brussels', 'Belgium'),
  const CityEntry('Zurich', 'Switzerland'),
  const CityEntry('Vienna', 'Austria'),
  const CityEntry('Tokyo', 'Japan'),
  const CityEntry('Seoul', 'South Korea'),
  const CityEntry('Sydney', 'Australia'),
  const CityEntry('Melbourne', 'Australia'),
  const CityEntry('Singapore', 'Singapore'),
  const CityEntry('Dubai', 'United Arab Emirates'),
  const CityEntry('São Paulo', 'Brazil'),
  const CityEntry('Buenos Aires', 'Argentina'),
];
