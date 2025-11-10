import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../../core/config/app_config.dart';
import '../../auth/data/services/auth_service.dart';
import '../data/models/venue.dart';

/// Form screen for adding or editing a venue
class VenueFormScreen extends StatefulWidget {
  final Venue? venue; // null for add mode, non-null for edit mode
  final int? venueIndex; // Required for edit mode

  const VenueFormScreen({
    super.key,
    this.venue,
    this.venueIndex,
  });

  @override
  State<VenueFormScreen> createState() => _VenueFormScreenState();
}

class _VenueFormScreenState extends State<VenueFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();

  bool _isSaving = false;
  String? _errorMessage;

  bool get isEditMode => widget.venue != null;

  @override
  void initState() {
    super.initState();
    if (isEditMode && widget.venue != null) {
      _nameController.text = widget.venue!.name;
      _addressController.text = widget.venue!.address;
      _cityController.text = widget.venue!.city;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    super.dispose();
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
          _errorMessage = 'Not authenticated';
          _isSaving = false;
        });
        return;
      }

      final baseUrl = AppConfig.instance.baseUrl;
      final body = jsonEncode({
        'name': _nameController.text.trim(),
        'address': _addressController.text.trim(),
        'city': _cityController.text.trim(),
      });

      final headers = {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };

      http.Response response;
      if (isEditMode && widget.venueIndex != null) {
        // PATCH for edit mode
        response = await http.patch(
          Uri.parse('$baseUrl/managers/me/venues/${widget.venueIndex}'),
          headers: headers,
          body: body,
        );
      } else {
        // POST for add mode
        response = await http.post(
          Uri.parse('$baseUrl/managers/me/venues'),
          headers: headers,
          body: body,
        );
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          Navigator.of(context).pop(true); // Return true to indicate success
        }
      } else {
        final responseBody = jsonDecode(response.body);
        setState(() {
          _errorMessage = (responseBody['message'] as String?) ?? 'Failed to save venue';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditMode ? 'Edit Venue' : 'Add Venue'),
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
            // Info card for manual venue
            Card(
              color: Colors.green.withOpacity(0.1),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    Icon(Icons.person, color: Colors.green[700]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        isEditMode
                            ? 'Edit venue details'
                            : 'Manually added venues are preserved when running venue discovery',
                        style: TextStyle(
                          color: Colors.green[900],
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Venue name field
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Venue Name *',
                hintText: 'e.g., Ball Arena',
                prefixIcon: const Icon(Icons.business),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
              ),
              textCapitalization: TextCapitalization.words,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a venue name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Address field
            TextFormField(
              controller: _addressController,
              decoration: InputDecoration(
                labelText: 'Address *',
                hintText: 'e.g., 1000 Chopper Cir, Denver, CO 80204',
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
                  return 'Please enter an address';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // City field
            TextFormField(
              controller: _cityController,
              decoration: InputDecoration(
                labelText: 'City *',
                hintText: 'e.g., Denver',
                prefixIcon: const Icon(Icons.location_city),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
              ),
              textCapitalization: TextCapitalization.words,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a city';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),

            // Error message
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
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

            // Save button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton.icon(
                onPressed: _isSaving ? null : _saveVenue,
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
                      ? 'Saving...'
                      : (isEditMode ? 'Save Changes' : 'Add Venue'),
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
