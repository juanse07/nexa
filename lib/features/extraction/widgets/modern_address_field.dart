import 'dart:async';

import 'package:flutter/material.dart';

import '../services/google_places_service.dart';

class ModernAddressField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final Function(PlaceDetails)? onPlaceSelected;
  final Function(String)? onAddressChanged;

  const ModernAddressField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.onPlaceSelected,
    this.onAddressChanged,
  });

  @override
  State<ModernAddressField> createState() => _ModernAddressFieldState();
}

class _ModernAddressFieldState extends State<ModernAddressField> {
  List<PlacePrediction> _predictions = [];
  bool _isLoading = false;

  Timer? _debounceTimer;
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _removeOverlay();
    super.dispose();
  }

  void _onTextChanged(String value) {
    widget.onAddressChanged?.call(value);

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (value.trim().length >= 3) {
        _searchPlaces(value.trim());
      } else {
        _clearPredictions();
      }
    });
  }

  Future<void> _searchPlaces(String query) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final predictions = await GooglePlacesService.getPlacePredictions(query);
      setState(() {
        _predictions = predictions;
        _isLoading = false;
      });

      if (predictions.isNotEmpty) {
        _showOverlay();
      } else {
        _removeOverlay();
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _removeOverlay();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Address search failed: ${e.toString()}'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
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
    widget.controller.text = prediction.description;
    _clearPredictions();

    // Get detailed place information
    try {
      final details = await GooglePlacesService.getPlaceDetails(
        prediction.placeId,
      );
      if (details != null) {
        widget.onPlaceSelected?.call(details);
      }
    } catch (e) {
      print('Error getting place details: $e');
    }
  }

  void _showOverlay() {
    _removeOverlay();

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: MediaQuery.of(context).size.width - 40, // Account for padding
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 60), // Position below the text field
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              constraints: const BoxConstraints(maxHeight: 200),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
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
                              color: const Color(
                                0xFF6366F1,
                              ).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.place,
                              size: 16,
                              color: Color(0xFF6366F1),
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
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                if (prediction.secondaryText.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    prediction.secondaryText,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
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

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(widget.icon, size: 16, color: Colors.grey.shade600),
              const SizedBox(width: 8),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: widget.controller,
            onChanged: _onTextChanged,
            onTap: () {
              if (_predictions.isNotEmpty) {
                _showOverlay();
              }
            },
            decoration: InputDecoration(
              hintText: 'Start typing an address...',
              hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 16),
              prefixIcon: Container(
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  widget.icon,
                  size: 20,
                  color: const Color(0xFF6366F1),
                ),
              ),
              suffixIcon: _isLoading
                  ? Container(
                      width: 20,
                      height: 20,
                      margin: const EdgeInsets.all(14),
                      child: const CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Color(0xFF6366F1),
                        ),
                      ),
                    )
                  : widget.controller.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        widget.controller.clear();
                        _clearPredictions();
                        widget.onAddressChanged?.call('');
                      },
                    )
                  : null,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(
                  color: Color(0xFF6366F1),
                  width: 2,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }
}
