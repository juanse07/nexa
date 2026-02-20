import 'package:flutter/material.dart';
import 'package:nexa/l10n/app_localizations.dart';

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
    final l10n = AppLocalizations.of(context)!;
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
                Text(
                  l10n.selectOrTypeCity,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
                labelText: l10n.country,
                prefixIcon: const Icon(Icons.public),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              ),
              isExpanded: true,
              items: [
                DropdownMenuItem<String>(value: null, child: Text(l10n.allCountries)),
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
                  labelText: l10n.stateProvince,
                  prefixIcon: const Icon(Icons.map),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: [
                  DropdownMenuItem<String>(value: null, child: Text(l10n.allStates)),
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
                labelText: l10n.typeOrSearchCity,
                hintText: l10n.enterAnyCityName,
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
                            Text(
                              l10n.useCustomCity,
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
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
              '${_filteredCities.length} ${l10n.suggestedCities}',
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
                            l10n.noMatchingCitiesSuggestions,
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            l10n.canTypeAnyCityAbove,
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
                                  label: Text(
                                    l10n.tourist,
                                    style: const TextStyle(fontSize: 10),
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

// Comprehensive city database - Focus on English, Spanish, Portuguese markets
final List<CityEntry> allCities = [
  // ========== UNITED STATES ==========
  // Colorado
  const CityEntry('Denver', 'United States', state: 'Colorado'),
  const CityEntry('Colorado Springs', 'United States', state: 'Colorado'),
  const CityEntry('Aurora', 'United States', state: 'Colorado'),
  const CityEntry('Fort Collins', 'United States', state: 'Colorado'),
  const CityEntry('Boulder', 'United States', state: 'Colorado'),
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
  const CityEntry('Winnipeg', 'Canada', state: 'Manitoba'),
  const CityEntry('Halifax', 'Canada', state: 'Nova Scotia'),

  // ========== UNITED KINGDOM ==========
  const CityEntry('London', 'United Kingdom'),
  const CityEntry('Manchester', 'United Kingdom'),
  const CityEntry('Birmingham', 'United Kingdom'),
  const CityEntry('Glasgow', 'United Kingdom'),
  const CityEntry('Edinburgh', 'United Kingdom'),
  const CityEntry('Liverpool', 'United Kingdom'),
  const CityEntry('Bristol', 'United Kingdom'),
  const CityEntry('Leeds', 'United Kingdom'),
  const CityEntry('Cardiff', 'United Kingdom'),
  const CityEntry('Belfast', 'United Kingdom'),
  const CityEntry('Oxford', 'United Kingdom', isTourist: true),
  const CityEntry('Cambridge', 'United Kingdom', isTourist: true),
  const CityEntry('Bath', 'United Kingdom', isTourist: true),

  // ========== AUSTRALIA ==========
  const CityEntry('Sydney', 'Australia'),
  const CityEntry('Melbourne', 'Australia'),
  const CityEntry('Brisbane', 'Australia'),
  const CityEntry('Perth', 'Australia'),
  const CityEntry('Adelaide', 'Australia'),
  const CityEntry('Gold Coast', 'Australia', isTourist: true),
  const CityEntry('Cairns', 'Australia', isTourist: true),
  const CityEntry('Byron Bay', 'Australia', isTourist: true),

  // ========== NEW ZEALAND (Suggested) ==========
  const CityEntry('Auckland', 'New Zealand'),
  const CityEntry('Wellington', 'New Zealand'),
  const CityEntry('Christchurch', 'New Zealand'),
  const CityEntry('Queenstown', 'New Zealand', isTourist: true),
  const CityEntry('Rotorua', 'New Zealand', isTourist: true),

  // ========== MEXICO ==========
  const CityEntry('Mexico City', 'Mexico'),
  const CityEntry('Guadalajara', 'Mexico'),
  const CityEntry('Monterrey', 'Mexico'),
  const CityEntry('Puebla', 'Mexico'),
  const CityEntry('Tijuana', 'Mexico'),
  const CityEntry('León', 'Mexico'),
  const CityEntry('Querétaro', 'Mexico'),
  const CityEntry('Mérida', 'Mexico'),
  const CityEntry('Cancún', 'Mexico', isTourist: true),
  const CityEntry('Playa del Carmen', 'Mexico', isTourist: true),
  const CityEntry('Cabo San Lucas', 'Mexico', isTourist: true),
  const CityEntry('Puerto Vallarta', 'Mexico', isTourist: true),
  const CityEntry('Tulum', 'Mexico', isTourist: true),
  const CityEntry('Cozumel', 'Mexico', isTourist: true),
  const CityEntry('Mazatlán', 'Mexico', isTourist: true),
  const CityEntry('Los Cabos', 'Mexico', isTourist: true),
  const CityEntry('San Miguel de Allende', 'Mexico', isTourist: true),
  const CityEntry('Oaxaca', 'Mexico', isTourist: true),

  // ========== COLOMBIA ==========
  const CityEntry('Bogotá', 'Colombia'),
  const CityEntry('Medellín', 'Colombia'),
  const CityEntry('Cali', 'Colombia'),
  const CityEntry('Barranquilla', 'Colombia'),
  const CityEntry('Cartagena', 'Colombia', isTourist: true),
  const CityEntry('Santa Marta', 'Colombia', isTourist: true),
  const CityEntry('Bucaramanga', 'Colombia'),
  const CityEntry('Pereira', 'Colombia'),
  const CityEntry('Manizales', 'Colombia'),
  const CityEntry('San Andrés', 'Colombia', isTourist: true),

  // ========== ECUADOR ==========
  const CityEntry('Quito', 'Ecuador'),
  const CityEntry('Guayaquil', 'Ecuador'),
  const CityEntry('Cuenca', 'Ecuador'),
  const CityEntry('Manta', 'Ecuador'),
  const CityEntry('Galápagos Islands', 'Ecuador', isTourist: true),
  const CityEntry('Montañita', 'Ecuador', isTourist: true),
  const CityEntry('Baños', 'Ecuador', isTourist: true),

  // ========== PERU ==========
  const CityEntry('Lima', 'Peru'),
  const CityEntry('Arequipa', 'Peru'),
  const CityEntry('Trujillo', 'Peru'),
  const CityEntry('Chiclayo', 'Peru'),
  const CityEntry('Cusco', 'Peru', isTourist: true),
  const CityEntry('Machu Picchu', 'Peru', isTourist: true),
  const CityEntry('Puno', 'Peru', isTourist: true),
  const CityEntry('Iquitos', 'Peru', isTourist: true),
  const CityEntry('Huaraz', 'Peru', isTourist: true),

  // ========== CHILE ==========
  const CityEntry('Santiago', 'Chile'),
  const CityEntry('Valparaíso', 'Chile'),
  const CityEntry('Viña del Mar', 'Chile'),
  const CityEntry('Concepción', 'Chile'),
  const CityEntry('La Serena', 'Chile'),
  const CityEntry('Antofagasta', 'Chile'),
  const CityEntry('Temuco', 'Chile'),
  const CityEntry('Puerto Varas', 'Chile', isTourist: true),
  const CityEntry('Pucón', 'Chile', isTourist: true),
  const CityEntry('San Pedro de Atacama', 'Chile', isTourist: true),
  const CityEntry('Puerto Natales', 'Chile', isTourist: true),

  // ========== COSTA RICA ==========
  const CityEntry('San José', 'Costa Rica'),
  const CityEntry('Alajuela', 'Costa Rica'),
  const CityEntry('Cartago', 'Costa Rica'),
  const CityEntry('Heredia', 'Costa Rica'),
  const CityEntry('Liberia', 'Costa Rica'),
  const CityEntry('Manuel Antonio', 'Costa Rica', isTourist: true),
  const CityEntry('Tamarindo', 'Costa Rica', isTourist: true),
  const CityEntry('Jacó', 'Costa Rica', isTourist: true),
  const CityEntry('La Fortuna', 'Costa Rica', isTourist: true),
  const CityEntry('Monteverde', 'Costa Rica', isTourist: true),

  // ========== ARGENTINA ==========
  const CityEntry('Buenos Aires', 'Argentina'),
  const CityEntry('Córdoba', 'Argentina'),
  const CityEntry('Rosario', 'Argentina'),
  const CityEntry('Mendoza', 'Argentina'),
  const CityEntry('La Plata', 'Argentina'),
  const CityEntry('Mar del Plata', 'Argentina', isTourist: true),
  const CityEntry('Bariloche', 'Argentina', isTourist: true),
  const CityEntry('Salta', 'Argentina', isTourist: true),
  const CityEntry('Ushuaia', 'Argentina', isTourist: true),
  const CityEntry('El Calafate', 'Argentina', isTourist: true),

  // ========== SPAIN ==========
  const CityEntry('Madrid', 'Spain'),
  const CityEntry('Barcelona', 'Spain'),
  const CityEntry('Valencia', 'Spain'),
  const CityEntry('Seville', 'Spain'),
  const CityEntry('Zaragoza', 'Spain'),
  const CityEntry('Málaga', 'Spain'),
  const CityEntry('Bilbao', 'Spain'),
  const CityEntry('Granada', 'Spain', isTourist: true),
  const CityEntry('Toledo', 'Spain', isTourist: true),
  const CityEntry('San Sebastián', 'Spain', isTourist: true),
  const CityEntry('Ibiza', 'Spain', isTourist: true),
  const CityEntry('Mallorca', 'Spain', isTourist: true),
  const CityEntry('Marbella', 'Spain', isTourist: true),

  // ========== BRAZIL ==========
  const CityEntry('São Paulo', 'Brazil'),
  const CityEntry('Rio de Janeiro', 'Brazil'),
  const CityEntry('Brasília', 'Brazil'),
  const CityEntry('Salvador', 'Brazil'),
  const CityEntry('Fortaleza', 'Brazil'),
  const CityEntry('Belo Horizonte', 'Brazil'),
  const CityEntry('Manaus', 'Brazil'),
  const CityEntry('Curitiba', 'Brazil'),
  const CityEntry('Recife', 'Brazil'),
  const CityEntry('Porto Alegre', 'Brazil'),
  const CityEntry('Florianópolis', 'Brazil', isTourist: true),
  const CityEntry('Búzios', 'Brazil', isTourist: true),
  const CityEntry('Foz do Iguaçu', 'Brazil', isTourist: true),
  const CityEntry('Fernando de Noronha', 'Brazil', isTourist: true),
  const CityEntry('Paraty', 'Brazil', isTourist: true),

  // ========== PORTUGAL ==========
  const CityEntry('Lisbon', 'Portugal'),
  const CityEntry('Porto', 'Portugal'),
  const CityEntry('Faro', 'Portugal'),
  const CityEntry('Braga', 'Portugal'),
  const CityEntry('Coimbra', 'Portugal'),
  const CityEntry('Funchal', 'Portugal', isTourist: true),
  const CityEntry('Sintra', 'Portugal', isTourist: true),
  const CityEntry('Lagos', 'Portugal', isTourist: true),
  const CityEntry('Algarve', 'Portugal', isTourist: true),
];
