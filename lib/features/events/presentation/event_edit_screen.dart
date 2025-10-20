import 'package:flutter/material.dart';
import 'package:nexa/l10n/app_localizations.dart';
import '../../extraction/services/event_service.dart';
import '../../extraction/services/roles_service.dart';
import '../../extraction/widgets/modern_address_field.dart';
import '../../extraction/services/google_places_service.dart';

class EventEditScreen extends StatefulWidget {
  final Map<String, dynamic> event;

  const EventEditScreen({super.key, required this.event});

  @override
  State<EventEditScreen> createState() => _EventEditScreenState();
}

class _EventEditScreenState extends State<EventEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final EventService _eventService = EventService();
  final RolesService _rolesService = RolesService();

  late TextEditingController _eventNameController;
  late TextEditingController _clientNameController;
  late TextEditingController _dateController;
  late TextEditingController _startTimeController;
  late TextEditingController _endTimeController;
  late TextEditingController _venueNameController;
  late TextEditingController _venueAddressController;
  late TextEditingController _cityController;
  late TextEditingController _stateController;
  late TextEditingController _contactNameController;
  late TextEditingController _contactPhoneController;
  late TextEditingController _contactEmailController;
  late TextEditingController _headcountController;
  late TextEditingController _notesController;

  DateTime? _selectedDate;
  TimeOfDay? _selectedStartTime;
  TimeOfDay? _selectedEndTime;
  PlaceDetails? _selectedVenuePlace;

  List<Map<String, dynamic>> _roles = [];
  Map<String, TextEditingController> _roleCountControllers = {};

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _eventNameController = TextEditingController(text: widget.event['event_name']?.toString() ?? '');
    _clientNameController = TextEditingController(text: widget.event['client_name']?.toString() ?? '');
    _dateController = TextEditingController(text: widget.event['date']?.toString() ?? '');
    _startTimeController = TextEditingController(text: widget.event['start_time']?.toString() ?? '');
    _endTimeController = TextEditingController(text: widget.event['end_time']?.toString() ?? '');
    _venueNameController = TextEditingController(text: widget.event['venue_name']?.toString() ?? '');
    _venueAddressController = TextEditingController(text: widget.event['venue_address']?.toString() ?? '');
    _cityController = TextEditingController(text: widget.event['city']?.toString() ?? '');
    _stateController = TextEditingController(text: widget.event['state']?.toString() ?? '');
    _contactNameController = TextEditingController(text: widget.event['contact_name']?.toString() ?? '');
    _contactPhoneController = TextEditingController(text: widget.event['contact_phone']?.toString() ?? '');
    _contactEmailController = TextEditingController(text: widget.event['contact_email']?.toString() ?? '');
    _headcountController = TextEditingController(text: widget.event['headcount_total']?.toString() ?? '');
    _notesController = TextEditingController(text: widget.event['notes']?.toString() ?? '');

    // Parse date
    if (widget.event['date'] != null) {
      try {
        _selectedDate = DateTime.parse(widget.event['date'].toString());
      } catch (_) {}
    }

    // Parse times
    if (widget.event['start_time'] != null) {
      _selectedStartTime = _parseTime(widget.event['start_time'].toString());
    }
    if (widget.event['end_time'] != null) {
      _selectedEndTime = _parseTime(widget.event['end_time'].toString());
    }

    _loadRoles();
  }

  TimeOfDay? _parseTime(String timeStr) {
    try {
      final parts = timeStr.split(':');
      if (parts.length >= 2) {
        int hour = int.parse(parts[0]);
        int minute = int.parse(parts[1].split(' ')[0]);

        // Handle AM/PM if present
        if (timeStr.toLowerCase().contains('pm') && hour < 12) {
          hour += 12;
        } else if (timeStr.toLowerCase().contains('am') && hour == 12) {
          hour = 0;
        }

        return TimeOfDay(hour: hour, minute: minute);
      }
    } catch (_) {}
    return null;
  }

  Future<void> _loadRoles() async {
    try {
      final roles = await _rolesService.fetchRoles();
      setState(() => _roles = roles);

      // Initialize role count controllers from existing event roles
      final List<dynamic> existingRoles = (widget.event['roles'] is List)
          ? (widget.event['roles'] as List)
          : const [];

      for (final role in _roles) {
        final roleName = (role['name'] ?? '').toString();
        if (roleName.isEmpty) continue;

        // Find existing count for this role
        final existing = existingRoles.firstWhere(
          (r) => (r['role']?.toString() ?? '').toLowerCase() == roleName.toLowerCase(),
          orElse: () => null,
        );

        final count = existing != null ? (existing['count'] ?? 0).toString() : '0';
        _roleCountControllers[roleName] = TextEditingController(text: count);
      }
    } catch (e) {
      // Fail silently
    }
  }

  @override
  void dispose() {
    _eventNameController.dispose();
    _clientNameController.dispose();
    _dateController.dispose();
    _startTimeController.dispose();
    _endTimeController.dispose();
    _venueNameController.dispose();
    _venueAddressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _contactNameController.dispose();
    _contactPhoneController.dispose();
    _contactEmailController.dispose();
    _headcountController.dispose();
    _notesController.dispose();
    for (var controller in _roleCountControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _saveEvent() async {
    if (_formKey.currentState?.validate() != true) return;

    setState(() => _isSaving = true);

    try {
      // Try multiple ways to get the event ID
      String eventId = '';

      if (widget.event['id'] != null) {
        eventId = widget.event['id'].toString();
      } else if (widget.event['_id'] != null) {
        final idValue = widget.event['_id'];
        // Handle MongoDB ObjectId which might be a map
        if (idValue is Map && idValue['\$oid'] != null) {
          eventId = idValue['\$oid'].toString();
        } else if (idValue is String) {
          eventId = idValue;
        } else {
          eventId = idValue.toString();
        }
      }

      print('DEBUG: Attempting to update event with ID: $eventId');
      print('DEBUG: Event keys: ${widget.event.keys.toList()}');

      if (eventId.isEmpty || eventId == 'null') {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: Event ID is missing. Available keys: ${widget.event.keys.join(", ")}')),
        );
        setState(() => _isSaving = false);
        return;
      }

      final updates = <String, dynamic>{
        'event_name': _eventNameController.text.trim(),
        'client_name': _clientNameController.text.trim(),
        'venue_name': _venueNameController.text.trim(),
        'venue_address': _venueAddressController.text.trim(),
        'city': _cityController.text.trim(),
        'state': _stateController.text.trim(),
        'contact_name': _contactNameController.text.trim(),
        'contact_phone': _contactPhoneController.text.trim(),
        'contact_email': _contactEmailController.text.trim(),
        'notes': _notesController.text.trim(),
      };

      if (_selectedDate != null) {
        updates['date'] = _selectedDate!.toIso8601String();
      }

      if (_startTimeController.text.trim().isNotEmpty) {
        updates['start_time'] = _startTimeController.text.trim();
      }

      if (_endTimeController.text.trim().isNotEmpty) {
        updates['end_time'] = _endTimeController.text.trim();
      }

      if (_headcountController.text.trim().isNotEmpty) {
        updates['headcount_total'] = int.tryParse(_headcountController.text.trim()) ?? 0;
      }

      // Add place details if selected
      if (_selectedVenuePlace != null) {
        updates['venue_latitude'] = _selectedVenuePlace!.latitude;
        updates['venue_longitude'] = _selectedVenuePlace!.longitude;
        updates['google_maps_url'] =
            'https://www.google.com/maps/search/?api=1&query='
            '${Uri.encodeComponent(_selectedVenuePlace!.formattedAddress.isNotEmpty ? _selectedVenuePlace!.formattedAddress : '${_selectedVenuePlace!.latitude},${_selectedVenuePlace!.longitude}')}'
            '&query_place_id=${Uri.encodeComponent(_selectedVenuePlace!.placeId)}';
      }

      // Build roles array
      final roles = <Map<String, dynamic>>[];
      for (final entry in _roleCountControllers.entries) {
        final count = int.tryParse(entry.value.text.trim()) ?? 0;
        if (count > 0) {
          roles.add({'role': entry.key, 'count': count});
        }
      }
      if (roles.isNotEmpty) {
        updates['roles'] = roles;
      }

      await _eventService.updateEvent(eventId, updates);

      if (!mounted) return;

      // Show success confirmation dialog
      final shouldClose = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Success'),
          content: const Text('Event has been updated successfully!'),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
              ),
              child: const Text('OK'),
            ),
          ],
        ),
      );

      if (shouldClose == true && mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      print('DEBUG: Error updating event: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update event: $e'),
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Event'),
        backgroundColor: const Color(0xFF6366F1),
        foregroundColor: Colors.white,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(
              onPressed: _isSaving ? null : _saveEvent,
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Save',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Event Information
              _buildSectionTitle('Event Information', Icons.event),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _eventNameController,
                label: AppLocalizations.of(context)!.jobTitle,
                icon: Icons.celebration,
                isRequired: true,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _clientNameController,
                label: AppLocalizations.of(context)!.clientName,
                icon: Icons.person,
                isRequired: true,
              ),
              const SizedBox(height: 16),
              _buildDatePicker(),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _buildTimePicker(isStart: true)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildTimePicker(isStart: false)),
                ],
              ),

              const SizedBox(height: 32),

              // Venue Information
              _buildSectionTitle('Venue Information', Icons.location_on),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _venueNameController,
                label: AppLocalizations.of(context)!.locationName,
                icon: Icons.location_city,
              ),
              const SizedBox(height: 16),
              ModernAddressField(
                controller: _venueAddressController,
                label: AppLocalizations.of(context)!.address,
                icon: Icons.place,
                onPlaceSelected: (place) {
                  setState(() {
                    _selectedVenuePlace = place;
                    _venueAddressController.text = place.formattedAddress;
                  });
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: _cityController,
                      label: AppLocalizations.of(context)!.city,
                      icon: Icons.location_city,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTextField(
                      controller: _stateController,
                      label: AppLocalizations.of(context)!.state,
                      icon: Icons.map,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // Contact Information
              _buildSectionTitle('Contact Information', Icons.contact_phone),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _contactNameController,
                label: AppLocalizations.of(context)!.contactName,
                icon: Icons.person_outline,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _contactPhoneController,
                label: AppLocalizations.of(context)!.contactPhone,
                icon: Icons.phone,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _contactEmailController,
                label: AppLocalizations.of(context)!.contactEmail,
                icon: Icons.email,
                keyboardType: TextInputType.emailAddress,
              ),

              const SizedBox(height: 32),

              // Event Details
              _buildSectionTitle(AppLocalizations.of(context)!.jobDetails, Icons.info),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _headcountController,
                label: AppLocalizations.of(context)!.expectedHeadcount,
                icon: Icons.people,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _notesController,
                label: AppLocalizations.of(context)!.notes,
                icon: Icons.notes,
                maxLines: 4,
              ),

              const SizedBox(height: 32),

              // Roles Section
              _buildSectionTitle('Staff Roles Required', Icons.work),
              const SizedBox(height: 16),
              ..._roleCountControllers.entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildTextField(
                    controller: entry.value,
                    label: entry.key,
                    icon: Icons.people,
                    keyboardType: TextInputType.number,
                  ),
                );
              }),

              const SizedBox(height: 32),

              // Save Button
              ElevatedButton(
                onPressed: _isSaving ? null : _saveEvent,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Save Changes',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: const Color(0xFF6366F1)),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isRequired = false,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF6366F1)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2),
        ),
      ),
      validator: isRequired
          ? (value) {
              if (value == null || value.trim().isEmpty) {
                return '$label is required';
              }
              return null;
            }
          : null,
    );
  }

  Widget _buildDatePicker() {
    return InkWell(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: _selectedDate ?? DateTime.now(),
          firstDate: DateTime.now().subtract(const Duration(days: 30)),
          lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: const ColorScheme.light(
                  primary: Color(0xFF6366F1),
                  onPrimary: Colors.white,
                  surface: Colors.white,
                  onSurface: Color(0xFF0F172A),
                ),
              ),
              child: child!,
            );
          },
        );
        if (date != null) {
          setState(() {
            _selectedDate = date;
            _dateController.text =
                '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
          });
        }
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Date',
          prefixIcon: const Icon(Icons.calendar_today, color: Color(0xFF6366F1)),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
        ),
        child: Text(
          _selectedDate != null
              ? '${_selectedDate!.month}/${_selectedDate!.day}/${_selectedDate!.year}'
              : 'Select date',
          style: TextStyle(
            color: _selectedDate != null ? Colors.black : Colors.grey.shade600,
          ),
        ),
      ),
    );
  }

  Widget _buildTimePicker({required bool isStart}) {
    final controller = isStart ? _startTimeController : _endTimeController;
    final time = isStart ? _selectedStartTime : _selectedEndTime;
    final label = isStart ? 'Start Time' : 'End Time';

    return InkWell(
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: time ?? TimeOfDay.now(),
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: const ColorScheme.light(
                  primary: Color(0xFF6366F1),
                  onPrimary: Colors.white,
                  surface: Colors.white,
                  onSurface: Color(0xFF0F172A),
                ),
              ),
              child: child!,
            );
          },
        );
        if (picked != null) {
          setState(() {
            if (isStart) {
              _selectedStartTime = picked;
            } else {
              _selectedEndTime = picked;
            }
            controller.text = picked.format(context);
          });
        }
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.access_time, color: Color(0xFF6366F1)),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
        ),
        child: Text(
          time != null ? time.format(context) : 'Select time',
          style: TextStyle(
            color: time != null ? Colors.black : Colors.grey.shade600,
          ),
        ),
      ),
    );
  }
}
