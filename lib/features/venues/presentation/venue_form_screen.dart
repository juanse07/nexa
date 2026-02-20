import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:nexa/l10n/app_localizations.dart';

import '../../../core/config/app_config.dart';
import '../../../shared/presentation/theme/app_colors.dart';
import '../../auth/data/services/auth_service.dart';
import '../../extraction/services/google_places_service.dart';
import '../data/models/venue.dart';

/// Form screen for adding or editing a venue with Google Places integration
class VenueFormScreen extends StatefulWidget {
  final Venue? venue; // null for add mode, non-null for edit mode

  const VenueFormScreen({
    super.key,
    this.venue,
  });

  @override
  State<VenueFormScreen> createState() => _VenueFormScreenState();
}

class _VenueFormScreenState extends State<VenueFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _searchController = TextEditingController();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();

  // Google Places data
  List<PlacePrediction> _predictions = [];
  bool _isSearching = false;
  Timer? _debounceTimer;
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;

  // Selected place details
  String? _selectedPlaceId;
  double? _latitude;
  double? _longitude;

  // User location for biasing search results
  double? _userLat;
  double? _userLng;

  bool _isSaving = false;
  String? _errorMessage;
  bool _showDetails = false; // Show editable details after selection

  bool get isEditMode => widget.venue != null;

  @override
  void initState() {
    super.initState();
    _getUserLocation();
    if (isEditMode && widget.venue != null) {
      _nameController.text = widget.venue!.name;
      _addressController.text = widget.venue!.address;
      _cityController.text = widget.venue!.city;
      _stateController.text = widget.venue!.state ?? '';
      _selectedPlaceId = widget.venue!.placeId;
      _latitude = widget.venue!.latitude;
      _longitude = widget.venue!.longitude;
      _showDetails = true;
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _removeOverlay();
    _searchController.dispose();
    _nameController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    super.dispose();
  }

  /// Get user's current location for biasing search results
  Future<void> _getUserLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }

      if (permission == LocationPermission.deniedForever) return;

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 5),
        ),
      );

      if (mounted) {
        setState(() {
          _userLat = position.latitude;
          _userLng = position.longitude;
        });
      }
    } catch (_) {
      // Silently fail - will use default Denver location
    }
  }

  void _onSearchChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 400), () {
      if (value.trim().length >= 2) {
        _searchPlaces(value.trim());
      } else {
        _clearPredictions();
      }
    });
  }

  Future<void> _searchPlaces(String query) async {
    setState(() {
      _isSearching = true;
    });

    try {
      final predictions = await GooglePlacesService.getPlacePredictions(
        query,
        userLat: _userLat,
        userLng: _userLng,
      );
      if (mounted) {
        setState(() {
          _predictions = predictions;
          _isSearching = false;
        });

        if (predictions.isNotEmpty) {
          _showOverlay();
        } else {
          _removeOverlay();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
        _removeOverlay();
      }
    }
  }

  void _clearPredictions() {
    setState(() {
      _predictions = [];
    });
    _removeOverlay();
  }

  Future<void> _selectPlace(PlacePrediction prediction) async {
    _clearPredictions();
    _searchController.clear();

    // Show loading state
    setState(() {
      _isSearching = true;
    });

    try {
      final details = await GooglePlacesService.getPlaceDetails(prediction.placeId);
      if (details != null && mounted) {
        setState(() {
          _nameController.text = prediction.mainText;
          _addressController.text = details.formattedAddress;
          _cityController.text = details.addressComponents['city'] ?? '';
          _stateController.text = details.addressComponents['state'] ?? '';
          _selectedPlaceId = details.placeId;
          _latitude = details.latitude;
          _longitude = details.longitude;
          _showDetails = true;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppLocalizations.of(context)!.failedToGetPlaceDetails}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showOverlay() {
    _removeOverlay();

    final renderBox = context.findRenderObject() as RenderBox?;
    final size = renderBox?.size ?? Size.zero;

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: size.width - 32, // Match padding
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 70),
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              constraints: const BoxConstraints(maxHeight: 280),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                shrinkWrap: true,
                itemCount: _predictions.length,
                itemBuilder: (context, index) {
                  final prediction = _predictions[index];
                  return InkWell(
                    onTap: () => _selectPlace(prediction),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.oceanBlue.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.place,
                              size: 18,
                              color: AppColors.oceanBlue,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  prediction.mainText,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textDark,
                                  ),
                                ),
                                if (prediction.secondaryText.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    prediction.secondaryText,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  Future<void> _saveVenue() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final token = await AuthService.getJwt();
      if (token == null) {
        setState(() {
          _errorMessage = AppLocalizations.of(context)!.notAuthenticated;
          _isSaving = false;
        });
        return;
      }

      final baseUrl = AppConfig.instance.baseUrl;

      // Build venue data
      final venueData = {
        'name': _nameController.text.trim(),
        'address': _addressController.text.trim(),
        'city': _cityController.text.trim(),
        if (_stateController.text.trim().isNotEmpty)
          'state': _stateController.text.trim(),
        if (_selectedPlaceId != null) 'placeId': _selectedPlaceId,
        if (_latitude != null) 'latitude': _latitude,
        if (_longitude != null) 'longitude': _longitude,
        'source': _selectedPlaceId != null ? 'places' : 'manual',
      };

      final headers = {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };

      http.Response response;
      if (isEditMode && widget.venue?.id != null) {
        // PATCH for edit mode
        response = await http.patch(
          Uri.parse('$baseUrl/venues/${widget.venue!.id}'),
          headers: headers,
          body: jsonEncode(venueData),
        );
      } else {
        // POST for add mode
        response = await http.post(
          Uri.parse('$baseUrl/venues'),
          headers: headers,
          body: jsonEncode(venueData),
        );
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          // Check if venue was updated (orphaned venue case)
          final responseBody = jsonDecode(response.body);
          final wasUpdated = responseBody['wasUpdated'] == true;
          final cityCreated = responseBody['cityCreated'] == true;
          final message = responseBody['message'] as String?;

          // Show appropriate snackbar based on response
          final l10n = AppLocalizations.of(context)!;
          String snackMessage;
          if (wasUpdated && cityCreated) {
            snackMessage = message ?? l10n.venueUpdatedCityTabAdded;
          } else if (cityCreated) {
            snackMessage = l10n.venueAddedCityTabCreated;
          } else if (isEditMode) {
            snackMessage = l10n.venueUpdatedSuccessfully;
          } else {
            snackMessage = l10n.venueAddedSuccessfully;
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(snackMessage),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );

          Navigator.of(context).pop(true); // Return true to indicate success
        }
      } else {
        final responseBody = jsonDecode(response.body);
        setState(() {
          _errorMessage =
              (responseBody['message'] as String?) ?? AppLocalizations.of(context)!.failedToSaveVenue;
          _isSaving = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: $e';
        _isSaving = false;
      });
    }
  }

  void _clearSelection() {
    setState(() {
      _nameController.clear();
      _addressController.clear();
      _cityController.clear();
      _stateController.clear();
      _selectedPlaceId = null;
      _latitude = null;
      _longitude = null;
      _showDetails = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        _removeOverlay();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(isEditMode ? l10n.editVenue : l10n.addVenue),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              // Info card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.oceanBlue.withValues(alpha: 0.1),
                      AppColors.navySpaceCadet.withValues(alpha: 0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.oceanBlue.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.oceanBlue.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.search,
                        color: AppColors.oceanBlue,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        isEditMode
                            ? l10n.editVenueDetailsBelow
                            : l10n.searchVenueAutoFill,
                        style: TextStyle(
                          color: AppColors.navySpaceCadet,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Search field (only show in add mode or if no selection yet)
              if (!_showDetails) ...[
                CompositedTransformTarget(
                  link: _layerLink,
                  child: TextFormField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    decoration: InputDecoration(
                      labelText: l10n.searchVenue,
                      hintText: l10n.venueSearchExample,
                      prefixIcon: Container(
                        margin: const EdgeInsets.all(8),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.oceanBlue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.search,
                          color: AppColors.oceanBlue,
                          size: 20,
                        ),
                      ),
                      suffixIcon: _isSearching
                          ? Container(
                              width: 20,
                              height: 20,
                              margin: const EdgeInsets.all(14),
                              child: const CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  AppColors.oceanBlue,
                                ),
                              ),
                            )
                          : _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchController.clear();
                                    _clearPredictions();
                                  },
                                )
                              : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                    ),
                    textCapitalization: TextCapitalization.words,
                  ),
                ),
                const SizedBox(height: 16),

                // Manual entry option
                Center(
                  child: TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _showDetails = true;
                      });
                    },
                    icon: const Icon(Icons.edit, size: 18),
                    label: Text(l10n.enterManuallyInstead),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey.shade600,
                    ),
                  ),
                ),
              ],

              // Venue details (shown after selection or manual entry)
              if (_showDetails) ...[
                // Selected venue summary card
                if (_selectedPlaceId != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.green.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green.shade600),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            l10n.venueFoundGooglePlaces,
                            style: TextStyle(
                              color: Colors.green.shade800,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: _clearSelection,
                          child: Text(l10n.clear),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // Venue name field
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: l10n.venueName,
                    hintText: l10n.venueNameExample,
                    prefixIcon: const Icon(Icons.business),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                  ),
                  textCapitalization: TextCapitalization.words,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return l10n.pleaseEnterVenueName;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Address field
                TextFormField(
                  controller: _addressController,
                  decoration: InputDecoration(
                    labelText: l10n.addressRequired,
                    hintText: l10n.addressExample,
                    prefixIcon: const Icon(Icons.location_on),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                  ),
                  textCapitalization: TextCapitalization.words,
                  maxLines: 2,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return l10n.pleaseEnterAddress;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // City and State in a row
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        controller: _cityController,
                        decoration: InputDecoration(
                          labelText: '${l10n.city} *',
                          hintText: 'Denver',
                          prefixIcon: const Icon(Icons.location_city),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                        ),
                        textCapitalization: TextCapitalization.words,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return l10n.required;
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _stateController,
                        decoration: InputDecoration(
                          labelText: l10n.state,
                          hintText: 'CO',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                        ),
                        textCapitalization: TextCapitalization.characters,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],

              // Error message
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Save button (only show when details are visible)
              if (_showDetails) ...[
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: FilledButton.icon(
                    onPressed: _isSaving ? null : _saveVenue,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.oceanBlue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save),
                    label: Text(
                      _isSaving
                          ? l10n.saving
                          : (isEditMode ? l10n.saveChanges : l10n.addVenue),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
