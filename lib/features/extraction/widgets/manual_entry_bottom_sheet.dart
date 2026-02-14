import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../shared/presentation/theme/app_colors.dart';
import '../../../shared/services/error_display_service.dart';
import '../services/clients_service.dart';
import '../services/event_service.dart';
import '../services/google_places_service.dart';
import '../services/roles_service.dart';
import 'modern_address_field.dart';

/// A lightweight bottom sheet for quick event creation without AI extraction.
/// Allows managers to manually enter essential event details.
class ManualEntryBottomSheet extends StatefulWidget {
  const ManualEntryBottomSheet({super.key});

  @override
  State<ManualEntryBottomSheet> createState() => _ManualEntryBottomSheetState();
}

class _ManualEntryBottomSheetState extends State<ManualEntryBottomSheet> {
  final EventService _eventService = EventService();
  final ClientsService _clientsService = ClientsService();
  final RolesService _rolesService = RolesService();

  // Form controllers
  final _clientNameCtrl = TextEditingController();
  final _venueAddressCtrl = TextEditingController();
  final _venueNameCtrl = TextEditingController();
  final _contactPhoneCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  // Keys for scrolling to specific fields
  final _addressFieldKey = GlobalKey();

  // Form state
  DateTime? _selectedDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  List<Map<String, dynamic>> _roles = [];

  // Google Places data
  double? _venueLatitude;
  double? _venueLongitude;
  String? _googleMapsUrl;
  String? _city;
  String? _state;

  // UI state
  bool _isSaving = false;

  // Clients for autocomplete
  List<String> _clientNames = [];
  bool _loadingClients = true;

  // Roles for position selection (loaded from API)
  List<String> _availableRoles = [];
  bool _loadingRoles = true;

  @override
  void initState() {
    super.initState();
    _loadClients();
    _loadRoles();
  }

  Future<void> _loadClients() async {
    try {
      final clients = await _clientsService.fetchClients();
      if (mounted) {
        setState(() {
          _clientNames = clients
              .map((c) => c['name']?.toString() ?? '')
              .where((name) => name.isNotEmpty)
              .toList();
          _loadingClients = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingClients = false);
      }
    }
  }

  Future<void> _loadRoles() async {
    try {
      final roles = await _rolesService.fetchRoles();
      if (mounted) {
        setState(() {
          _availableRoles = roles
              .map((r) => r['name']?.toString() ?? '')
              .where((name) => name.isNotEmpty)
              .toList();
          _loadingRoles = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingRoles = false);
      }
    }
  }

  @override
  void dispose() {
    _clientNameCtrl.dispose();
    _venueAddressCtrl.dispose();
    _venueNameCtrl.dispose();
    _contactPhoneCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  /// Scroll to make the address field visible at the top with room for dropdown
  void _scrollToAddressField() {
    final context = _addressFieldKey.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        alignment: 0.0, // Align to top of viewport
      );
    }
  }

  bool get _isValid {
    return _clientNameCtrl.text.trim().isNotEmpty &&
           _selectedDate != null &&
           _roles.isNotEmpty &&
           _roles.any((r) => (r['count'] as int? ?? 0) > 0);
  }

  String _formatDateForSave(DateTime? date) {
    if (date == null) return '';
    return DateFormat('yyyy-MM-dd').format(date);
  }

  String _formatTimeForSave(TimeOfDay? time) {
    if (time == null) return '';
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _pickDate() async {
    HapticFeedback.selectionClick();
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365 * 2)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.techBlue,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: AppColors.textDark,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickTime({required bool isStart}) async {
    HapticFeedback.selectionClick();
    final initial = isStart ? _startTime : _endTime;
    final picked = await showTimePicker(
      context: context,
      initialTime: initial ?? const TimeOfDay(hour: 18, minute: 0),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.techBlue,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: AppColors.textDark,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  void _onPlaceSelected(PlaceDetails details) {
    setState(() {
      _venueAddressCtrl.text = details.formattedAddress;
      _venueLatitude = details.latitude;
      _venueLongitude = details.longitude;
      _googleMapsUrl = 'https://www.google.com/maps/search/?api=1&query=${details.latitude},${details.longitude}';
      _city = details.addressComponents['city'];
      _state = details.addressComponents['state'];
      // Auto-fill venue name from address
      if (_venueNameCtrl.text.isEmpty) {
        final street = details.addressComponents['street'];
        if (street != null && street.isNotEmpty) {
          _venueNameCtrl.text = street;
        } else {
          final firstPart = details.formattedAddress.split(',').first.trim();
          if (firstPart.isNotEmpty) _venueNameCtrl.text = firstPart;
        }
      }
    });
  }

  void _toggleRole(String roleName) {
    HapticFeedback.selectionClick();
    setState(() {
      final existingIndex = _roles.indexWhere(
        (r) => r['role']?.toString().toLowerCase() == roleName.toLowerCase()
      );

      if (existingIndex >= 0) {
        // Remove if exists
        _roles.removeAt(existingIndex);
      } else {
        // Add with count of 1
        _roles.add({'role': roleName, 'count': 1});
      }
    });
  }

  void _updateRoleCount(int index, int delta) {
    HapticFeedback.selectionClick();
    setState(() {
      final currentCount = (_roles[index]['count'] as int? ?? 1);
      final newCount = currentCount + delta;
      if (newCount <= 0) {
        _roles.removeAt(index);
      } else {
        _roles[index] = {..._roles[index], 'count': newCount};
      }
    });
  }

  Future<void> _save() async {
    if (!_isValid) {
      ErrorDisplayService.showError(
        context,
        'Please fill in client name, date, and at least one position'
      );
      return;
    }

    setState(() => _isSaving = true);
    HapticFeedback.mediumImpact();

    try {
      final payload = <String, dynamic>{
        'client_name': _clientNameCtrl.text.trim(),
        'date': _formatDateForSave(_selectedDate),
        'status': 'draft',
        'roles': _roles.where((r) =>
          r['role']?.toString().isNotEmpty == true &&
          (r['count'] as int? ?? 0) > 0
        ).map((r) => {
          'role': r['role'],
          'count': r['count'],
        }).toList(),
      };

      // Add optional fields
      if (_startTime != null) {
        payload['start_time'] = _formatTimeForSave(_startTime);
      }
      if (_endTime != null) {
        payload['end_time'] = _formatTimeForSave(_endTime);
      }
      if (_venueAddressCtrl.text.trim().isNotEmpty) {
        payload['venue_address'] = _venueAddressCtrl.text.trim();
      }
      if (_venueLatitude != null) {
        payload['venue_latitude'] = _venueLatitude;
      }
      if (_venueLongitude != null) {
        payload['venue_longitude'] = _venueLongitude;
      }
      if (_googleMapsUrl != null) {
        payload['google_maps_url'] = _googleMapsUrl;
      }
      if (_city != null) {
        payload['city'] = _city;
      }
      if (_state != null) {
        payload['state'] = _state;
      }
      if (_venueNameCtrl.text.trim().isNotEmpty) {
        payload['venue_name'] = _venueNameCtrl.text.trim();
      }
      if (_contactPhoneCtrl.text.trim().isNotEmpty) {
        payload['contact_phone'] = _contactPhoneCtrl.text.trim();
      }
      if (_notesCtrl.text.trim().isNotEmpty) {
        payload['notes'] = _notesCtrl.text.trim();
      }

      await _eventService.createEvent(payload);

      if (!mounted) return;

      HapticFeedback.heavyImpact();
      Navigator.of(context).pop(true); // Return true to indicate success

    } on SubscriptionLimitException catch (e) {
      if (!mounted) return;
      ErrorDisplayService.showError(context, e.message);
    } catch (e) {
      if (!mounted) return;
      ErrorDisplayService.showError(context, 'Failed to create event: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF8FAFC),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Drag handle
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.techBlue, AppColors.oceanBlue],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.edit_note_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Quick Event Entry',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textDark,
                            ),
                          ),
                          Text(
                            'Create event without AI extraction',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(Icons.close, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // Form content - scrollable with keyboard handling
              Expanded(
                child: ListView(
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.fromLTRB(
                    20,
                    20,
                    20,
                    MediaQuery.of(context).viewInsets.bottom + 100, // Extra space for keyboard + dropdown
                  ),
                  children: [
                    // Client Name (Required) - with autocomplete
                    _buildClientAutocomplete(),
                    const SizedBox(height: 20),

                    // Date (Required)
                    _buildDatePicker(),
                    const SizedBox(height: 20),

                    // Time Range
                    Row(
                      children: [
                        Expanded(child: _buildTimePicker(isStart: true)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildTimePicker(isStart: false)),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Venue Address - with key for scroll targeting
                    Container(
                      key: _addressFieldKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionLabel('Venue Address', Icons.place_outlined),
                          const SizedBox(height: 8),
                          ModernAddressField(
                            controller: _venueAddressCtrl,
                            label: '',
                            icon: Icons.map_outlined,
                            onPlaceSelected: _onPlaceSelected,
                            onAddressChanged: (value) {
                              // Scroll to show dropdown when user starts typing
                              if (value.length == 1) {
                                _scrollToAddressField();
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Roles Section (Required)
                    _buildSectionLabel('Positions Needed', Icons.people_outline, isRequired: true),
                    const SizedBox(height: 12),
                    _buildRolesChips(),
                    const SizedBox(height: 12),
                    if (_roles.isNotEmpty) _buildSelectedRoles(),

                    const SizedBox(height: 24),

                    // Optional fields divider
                    Row(
                      children: [
                        Expanded(child: Divider(color: Colors.grey.shade300)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'Optional Details',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ),
                        Expanded(child: Divider(color: Colors.grey.shade300)),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Location Name (auto-filled from address)
                    _buildInputField(
                      label: 'Location Name',
                      controller: _venueNameCtrl,
                      icon: Icons.business_outlined,
                      hint: 'Auto-filled from address',
                    ),
                    const SizedBox(height: 16),

                    // Contact Phone
                    _buildInputField(
                      label: 'Contact Phone',
                      controller: _contactPhoneCtrl,
                      icon: Icons.phone_outlined,
                      hint: 'Optional',
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 16),

                    // Notes
                    _buildInputField(
                      label: 'Notes',
                      controller: _notesCtrl,
                      icon: Icons.notes_outlined,
                      hint: 'Special requirements, setup details, etc.',
                      maxLines: 3,
                    ),

                    const SizedBox(height: 32),

                    // Save Button
                    _buildSaveButton(),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Client name field with autocomplete suggestions
  Widget _buildClientAutocomplete() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel('Client Name', Icons.business_outlined, isRequired: true),
        const SizedBox(height: 8),
        Autocomplete<String>(
          optionsBuilder: (TextEditingValue textEditingValue) {
            if (textEditingValue.text.isEmpty) {
              return const Iterable<String>.empty();
            }
            final query = textEditingValue.text.toLowerCase();
            return _clientNames.where((client) =>
              client.toLowerCase().contains(query)
            );
          },
          onSelected: (String selection) {
            _clientNameCtrl.text = selection;
            setState(() {});
          },
          fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
            // Sync with our controller
            if (controller.text != _clientNameCtrl.text) {
              controller.text = _clientNameCtrl.text;
            }
            controller.addListener(() {
              if (_clientNameCtrl.text != controller.text) {
                _clientNameCtrl.text = controller.text;
                setState(() {});
              }
            });

            return TextFormField(
              controller: controller,
              focusNode: focusNode,
              decoration: InputDecoration(
                hintText: _loadingClients ? 'Loading clients...' : 'Enter or select client name',
                hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 16),
                prefixIcon: Container(
                  margin: const EdgeInsets.all(12),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.techBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.business_outlined, size: 20, color: AppColors.techBlue),
                ),
                suffixIcon: _clientNames.isNotEmpty
                    ? Icon(Icons.arrow_drop_down, color: Colors.grey.shade500)
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
                  borderSide: const BorderSide(color: AppColors.techBlue, width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: AppColors.textDark,
              ),
            );
          },
          optionsViewBuilder: (context, onSelected, options) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: MediaQuery.of(context).size.width - 80,
                  constraints: const BoxConstraints(maxHeight: 200),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shrinkWrap: true,
                    itemCount: options.length,
                    itemBuilder: (context, index) {
                      final option = options.elementAt(index);
                      return ListTile(
                        dense: true,
                        leading: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.techBlue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(
                            Icons.business,
                            size: 16,
                            color: AppColors.techBlue,
                          ),
                        ),
                        title: Text(
                          option,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        onTap: () => onSelected(option),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSectionLabel(String label, IconData icon, {bool isRequired = false}) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
        if (isRequired) ...[
          const SizedBox(width: 4),
          Text(
            '*',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.errorDark,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required String hint,
    bool isRequired = false,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel(label, icon, isRequired: isRequired),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          onChanged: (_) => setState(() {}),
          keyboardType: keyboardType,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 16),
            prefixIcon: Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.techBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 20, color: AppColors.techBlue),
            ),
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
              borderSide: const BorderSide(color: AppColors.techBlue, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: AppColors.textDark,
          ),
        ),
      ],
    );
  }

  Widget _buildDatePicker() {
    final hasDate = _selectedDate != null;
    final displayText = hasDate
        ? DateFormat('EEE, MMM d, yyyy').format(_selectedDate!)
        : 'Select date';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel('Event Date', Icons.calendar_today_outlined, isRequired: true),
        const SizedBox(height: 8),
        InkWell(
          onTap: _pickDate,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: hasDate ? Colors.grey.shade300 : AppColors.warning.withValues(alpha: 0.5),
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.techBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.calendar_today_outlined,
                    size: 20,
                    color: AppColors.techBlue,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    displayText,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: hasDate ? AppColors.textDark : Colors.grey.shade500,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_drop_down_rounded,
                  color: Colors.grey.shade600,
                  size: 28,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimePicker({required bool isStart}) {
    final time = isStart ? _startTime : _endTime;
    final hasTime = time != null;
    final displayText = hasTime ? time.format(context) : 'Select';
    final label = isStart ? 'Start Time' : 'End Time';
    final icon = isStart ? Icons.schedule_outlined : Icons.schedule_send_outlined;
    final color = isStart ? AppColors.success : AppColors.warning;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: Colors.grey.shade600),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () => _pickTime(isStart: isStart),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade300, width: 1.5),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(icon, size: 16, color: color),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    displayText,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: hasTime ? AppColors.textDark : Colors.grey.shade500,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_drop_down_rounded,
                  color: Colors.grey.shade500,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRolesChips() {
    if (_loadingRoles) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.grey.shade400,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Loading roles...',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
            ),
          ],
        ),
      );
    }

    if (_availableRoles.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(
          'No roles available. Add roles in Settings.',
          style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
        ),
      );
    }

    final selectedRoles = _roles.map((r) => r['role']?.toString().toLowerCase()).toSet();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _availableRoles.map((role) {
        final isSelected = selectedRoles.contains(role.toLowerCase());
        return FilterChip(
          label: Text(role),
          selected: isSelected,
          onSelected: (_) => _toggleRole(role),
          backgroundColor: Colors.white,
          selectedColor: AppColors.techBlue.withValues(alpha: 0.15),
          checkmarkColor: AppColors.techBlue,
          labelStyle: TextStyle(
            color: isSelected ? AppColors.techBlue : Colors.grey.shade700,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
          side: BorderSide(
            color: isSelected ? AppColors.techBlue : Colors.grey.shade300,
            width: 1.5,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        );
      }).toList(),
    );
  }

  Widget _buildSelectedRoles() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade300, width: 1.5),
      ),
      child: Column(
        children: [
          for (int i = 0; i < _roles.length; i++) ...[
            if (i > 0) Divider(height: 1, color: Colors.grey.shade200),
            _buildRoleRow(i),
          ],
        ],
      ),
    );
  }

  Widget _buildRoleRow(int index) {
    final role = _roles[index];
    final roleName = role['role']?.toString() ?? 'Position';
    final count = (role['count'] as int?) ?? 1;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.techBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.person_outline,
              size: 18,
              color: AppColors.techBlue,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              roleName,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
          ),
          // Count controls
          Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: () => _updateRoleCount(index, -1),
                  icon: Icon(
                    Icons.remove,
                    size: 18,
                    color: count > 1 ? AppColors.errorDark : Colors.grey.shade400,
                  ),
                  padding: const EdgeInsets.all(6),
                  constraints: const BoxConstraints(),
                  splashRadius: 18,
                ),
                Container(
                  constraints: const BoxConstraints(minWidth: 32),
                  alignment: Alignment.center,
                  child: Text(
                    count.toString(),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => _updateRoleCount(index, 1),
                  icon: const Icon(
                    Icons.add,
                    size: 18,
                    color: AppColors.success,
                  ),
                  padding: const EdgeInsets.all(6),
                  constraints: const BoxConstraints(),
                  splashRadius: 18,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return Container(
      decoration: BoxDecoration(
        gradient: _isValid
            ? const LinearGradient(
                colors: [AppColors.techBlue, AppColors.oceanBlue],
              )
            : null,
        color: _isValid ? null : Colors.grey.shade300,
        borderRadius: BorderRadius.circular(16),
        boxShadow: _isValid
            ? [
                BoxShadow(
                  color: AppColors.techBlue.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: ElevatedButton.icon(
        onPressed: _isSaving || !_isValid ? null : _save,
        icon: _isSaving
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.add_task_rounded),
        label: Text(_isSaving ? 'Creating...' : 'Save to Pending'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          shadowColor: Colors.transparent,
          disabledBackgroundColor: Colors.transparent,
          disabledForegroundColor: Colors.white60,
          padding: const EdgeInsets.symmetric(vertical: 16),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
