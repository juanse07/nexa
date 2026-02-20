import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:nexa/l10n/app_localizations.dart';

import '../../../core/config/app_config.dart';
import '../../../shared/presentation/theme/app_colors.dart';
import '../../auth/data/services/auth_service.dart';
import '../../cities/data/models/city.dart';
import '../data/models/venue.dart';
import 'venue_form_screen.dart';

/// Tabbed venue screen with one tab per city
class TabbedVenueScreen extends StatefulWidget {
  const TabbedVenueScreen({super.key});

  @override
  State<TabbedVenueScreen> createState() => _TabbedVenueScreenState();
}

class _TabbedVenueScreenState extends State<TabbedVenueScreen>
    with TickerProviderStateMixin {
  bool _isLoading = true;
  List<City> _cities = [];
  List<Venue> _allVenues = [];
  String? _error;
  TabController? _tabController;

  // Search and filter state
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedSourceFilter; // null = all, 'ai', 'manual', 'places'

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _tabController?.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase().trim();
    });
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

      // Load cities from manager and venues from new endpoint in parallel
      final responses = await Future.wait([
        http.get(Uri.parse('$baseUrl/managers/me'), headers: headers),
        http.get(Uri.parse('$baseUrl/venues'), headers: headers),
      ]);

      final managerResponse = responses[0];
      final venuesResponse = responses[1];

      if (managerResponse.statusCode == 200 && venuesResponse.statusCode == 200) {
        final managerData = jsonDecode(managerResponse.body) as Map<String, dynamic>;
        final venuesData = jsonDecode(venuesResponse.body) as Map<String, dynamic>;

        // Load cities
        final citiesJson = managerData['cities'] as List?;
        final cities = (citiesJson ?? [])
            .map((json) => City.fromJson(json as Map<String, dynamic>))
            .toList();

        // Load venues from new endpoint
        final venuesList = venuesData['venues'] as List?;
        final venues = venuesList
                ?.map((v) => Venue.fromJson(v as Map<String, dynamic>))
                .toList() ??
            [];

        // Dispose old tab controller before creating new one
        _tabController?.dispose();
        _tabController = null;

        // Only create tab controller if there are cities
        TabController? newTabController;
        if (cities.isNotEmpty) {
          newTabController = TabController(length: cities.length, vsync: this);
        }

        setState(() {
          _cities = cities;
          _allVenues = venues;
          _tabController = newTabController;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = AppLocalizations.of(context)!.failedToLoadData;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  /// Get venues for a specific city with search and filter applied
  List<Venue> _getVenuesForCity(City city) {
    return _allVenues.where((venue) {
      // Filter by city
      if (venue.city.toLowerCase() != city.displayName.toLowerCase()) {
        return false;
      }

      // Filter by search query
      if (_searchQuery.isNotEmpty) {
        final nameMatch = venue.name.toLowerCase().contains(_searchQuery);
        final addressMatch = venue.address.toLowerCase().contains(_searchQuery);
        if (!nameMatch && !addressMatch) {
          return false;
        }
      }

      // Filter by source
      if (_selectedSourceFilter != null && venue.source != _selectedSourceFilter) {
        return false;
      }

      return true;
    }).toList();
  }

  /// Get count of venues by source for current city
  Map<String, int> _getSourceCounts(City city) {
    final cityVenues = _allVenues.where(
      (v) => v.city.toLowerCase() == city.displayName.toLowerCase()
    );
    return {
      'all': cityVenues.length,
      'ai': cityVenues.where((v) => v.source == 'ai').length,
      'manual': cityVenues.where((v) => v.source == 'manual').length,
      'places': cityVenues.where((v) => v.source == 'places').length,
    };
  }

  Future<void> _addVenue() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => const VenueFormScreen(),
      ),
    );

    if (result == true && mounted) {
      _loadData(); // Reload data after adding
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
      _loadData(); // Reload data after editing
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
          _loadData(); // Reload data after deletion
          _showSnackBar(AppLocalizations.of(context)!.venueRemovedSuccessfully, Colors.orange);
        }
      } else {
        final responseBody = jsonDecode(response.body);
        _showSnackBar(
            (responseBody['message'] as String?) ?? AppLocalizations.of(context)!.failedToDeleteVenue,
            Colors.red);
      }
    } catch (e) {
      _showSnackBar(e.toString(), Colors.red);
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
      badgeColor = AppColors.yellow;
      badgeIcon = Icons.smart_toy;
      badgeText = l10n.aiSource;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.15),
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

  Widget _buildFilterChip({
    required String label,
    required String? filterValue,
    required int count,
    required Color color,
    IconData? icon,
  }) {
    final isSelected = _selectedSourceFilter == filterValue;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        selected: isSelected,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        labelPadding: const EdgeInsets.symmetric(horizontal: 2),
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 12,
                color: isSelected ? Colors.white : color,
              ),
              const SizedBox(width: 3),
            ],
            Text(
              '$label ($count)',
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? Colors.white : Colors.grey[700],
              ),
            ),
          ],
        ),
        selectedColor: color,
        backgroundColor: Colors.grey[100],
        checkmarkColor: Colors.white,
        showCheckmark: false,
        onSelected: (selected) {
          setState(() {
            _selectedSourceFilter = selected ? filterValue : null;
          });
        },
      ),
    );
  }

  Widget _buildSearchAndFilters(City city) {
    final l10n = AppLocalizations.of(context)!;
    final counts = _getSourceCounts(city);

    return Container(
      color: Colors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Search box - compact
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
            child: SizedBox(
              height: 44,
              child: TextField(
                controller: _searchController,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: l10n.searchVenuesHint,
                  hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                  prefixIcon: Icon(Icons.search, color: Colors.grey[400], size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear, size: 18, color: Colors.grey[500]),
                          onPressed: () {
                            _searchController.clear();
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 0,
                  ),
                  isDense: true,
                ),
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ),
          // Filter chips - compact
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _buildFilterChip(
                  label: l10n.all,
                  filterValue: null,
                  count: counts['all'] ?? 0,
                  color: AppColors.navySpaceCadet,
                  icon: Icons.apps,
                ),
                _buildFilterChip(
                  label: l10n.aiSource,
                  filterValue: 'ai',
                  count: counts['ai'] ?? 0,
                  color: AppColors.yellow,
                  icon: Icons.smart_toy,
                ),
                _buildFilterChip(
                  label: l10n.manualSource,
                  filterValue: 'manual',
                  count: counts['manual'] ?? 0,
                  color: Colors.green,
                  icon: Icons.person,
                ),
                _buildFilterChip(
                  label: l10n.placesSource,
                  filterValue: 'places',
                  count: counts['places'] ?? 0,
                  color: AppColors.oceanBlue,
                  icon: Icons.place,
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildCityTab(City city) {
    final l10n = AppLocalizations.of(context)!;
    final allCityVenues = _allVenues.where(
      (v) => v.city.toLowerCase() == city.displayName.toLowerCase()
    ).toList();
    final filteredVenues = _getVenuesForCity(city);

    // Empty city state - no venues at all
    if (allCityVenues.isEmpty) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 48),
              Icon(Icons.location_off, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                l10n.noVenuesInCity(city.displayName),
                style: const TextStyle(fontSize: 18, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                l10n.addVenuesDescription,
                style: const TextStyle(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _addVenue,
                icon: const Icon(Icons.add),
                label: Text(l10n.addFirstVenue),
              ),
            ],
          ),
        ),
      );
    }

    // City has venues - show search/filter UI
    return GestureDetector(
      // Dismiss keyboard when tapping outside text field
      onTap: () => FocusScope.of(context).unfocus(),
      child: Column(
        children: [
          // Search and filters (pinned at top)
          _buildSearchAndFilters(city),

          // Results count badge (compact header)
          _buildResultsHeader(city, filteredVenues.length, allCityVenues.length),

          // Venue list or empty state
          Expanded(
            child: filteredVenues.isEmpty
                ? _buildEmptySearchState()
                : _buildVenueList(filteredVenues),
          ),
        ],
      ),
    );
  }

  /// Compact results header
  Widget _buildResultsHeader(City city, int filtered, int total) {
    final hasFilters = _searchQuery.isNotEmpty || _selectedSourceFilter != null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.navySpaceCadet.withValues(alpha: 0.03),
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Row(
        children: [
          // City badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: city.isTourist
                  ? AppColors.yellow.withValues(alpha: 0.15)
                  : AppColors.oceanBlue.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  city.isTourist ? Icons.tour : Icons.business,
                  size: 14,
                  color: city.isTourist ? AppColors.primaryPurple : AppColors.oceanBlue,
                ),
                const SizedBox(width: 4),
                Text(
                  city.displayName,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: city.isTourist ? AppColors.primaryPurple : AppColors.oceanBlue,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          // Venue count
          Text(
            hasFilters ? '$filtered of $total venues' : '$total venues',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  /// Empty state when search/filter returns no results
  Widget _buildEmptySearchState() {
    final l10n = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.search_off, size: 40, color: Colors.grey[400]),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.noVenuesMatch,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _selectedSourceFilter != null
                  ? l10n.tryDifferentFilterOrTerm
                  : l10n.tryDifferentSearchTerm,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _selectedSourceFilter = null;
                });
              },
              icon: const Icon(Icons.clear_all, size: 18),
              label: Text(l10n.clearFilters),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Venue list with dismiss and edit functionality
  Widget _buildVenueList(List<Venue> venues) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemCount: venues.length,
      separatorBuilder: (context, index) => const Divider(height: 24),
      itemBuilder: (context, index) {
        final venue = venues[index];

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
                      : AppColors.yellow,
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
              _loadData();
            },
          ),
        ],
        bottom: _cities.isNotEmpty && !_isLoading && _tabController != null
            ? TabBar(
                controller: _tabController,
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
                          _loadData();
                        },
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
                          Icon(Icons.location_city_outlined,
                              size: 64, color: Colors.grey.shade400),
                          const SizedBox(height: 16),
                          Text(
                            l10n.noCitiesAddedYet,
                            style: const TextStyle(fontSize: 18, color: Colors.grey),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            l10n.addCitiesFromSettings,
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : _tabController != null
                      ? TabBarView(
                          controller: _tabController,
                          children: _cities.map(_buildCityTab).toList(),
                        )
                      : const Center(child: CircularProgressIndicator()),
    );
  }
}
