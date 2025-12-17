import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nexa/l10n/app_localizations.dart';

import '../services/event_service.dart';
import '../services/google_places_service.dart';
import '../widgets/modern_address_field.dart';
import 'package:nexa/shared/presentation/theme/app_colors.dart';

class PendingEditScreen extends StatefulWidget {
  final Map<String, dynamic> draft;
  final String draftId;

  const PendingEditScreen({
    super.key,
    required this.draft,
    required this.draftId,
  });

  @override
  State<PendingEditScreen> createState() => _PendingEditScreenState();
}

class _PendingEditScreenState extends State<PendingEditScreen> {
  final EventService _eventService = EventService();

  late final TextEditingController _eventNameCtrl;
  late final TextEditingController _clientNameCtrl;
  late final TextEditingController _venueNameCtrl;
  late final TextEditingController _venueAddressCtrl;
  late final TextEditingController _cityCtrl;
  late final TextEditingController _stateCtrl;
  late final TextEditingController _contactNameCtrl;
  late final TextEditingController _contactPhoneCtrl;
  late final TextEditingController _contactEmailCtrl;
  late final TextEditingController _notesCtrl;

  DateTime? _selectedDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final d = widget.draft;
    _eventNameCtrl = TextEditingController(text: (d['event_name'] ?? '').toString());
    _clientNameCtrl = TextEditingController(text: (d['client_name'] ?? '').toString());
    _venueNameCtrl = TextEditingController(text: (d['venue_name'] ?? '').toString());
    _venueAddressCtrl = TextEditingController(text: (d['venue_address'] ?? '').toString());
    _cityCtrl = TextEditingController(text: (d['city'] ?? '').toString());
    _stateCtrl = TextEditingController(text: (d['state'] ?? '').toString());
    _contactNameCtrl = TextEditingController(text: (d['contact_name'] ?? '').toString());
    _contactPhoneCtrl = TextEditingController(text: (d['contact_phone'] ?? '').toString());
    _contactEmailCtrl = TextEditingController(text: (d['contact_email'] ?? '').toString());
    _notesCtrl = TextEditingController(text: (d['notes'] ?? '').toString());

    // Parse existing date
    _selectedDate = _parseDate(d['date']?.toString());

    // Parse existing times
    _startTime = _parseTime(d['start_time']?.toString());
    _endTime = _parseTime(d['end_time']?.toString());
  }

  DateTime? _parseDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return null;
    try {
      // Handle ISO format (2026-01-07T00:00:00.000Z)
      if (dateStr.contains('T')) {
        return DateTime.parse(dateStr);
      }
      // Handle YYYY-MM-DD format
      return DateTime.parse(dateStr);
    } catch (_) {
      return null;
    }
  }

  TimeOfDay? _parseTime(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return null;
    try {
      // Handle HH:mm format
      final parts = timeStr.split(':');
      if (parts.length >= 2) {
        return TimeOfDay(
          hour: int.parse(parts[0]),
          minute: int.parse(parts[1]),
        );
      }
    } catch (_) {}
    return null;
  }

  String _formatTimeForSave(TimeOfDay? time) {
    if (time == null) return '';
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  String _formatDateForSave(DateTime? date) {
    if (date == null) return '';
    return DateFormat('yyyy-MM-dd').format(date);
  }

  @override
  void dispose() {
    _eventNameCtrl.dispose();
    _clientNameCtrl.dispose();
    _venueNameCtrl.dispose();
    _venueAddressCtrl.dispose();
    _cityCtrl.dispose();
    _stateCtrl.dispose();
    _contactNameCtrl.dispose();
    _contactPhoneCtrl.dispose();
    _contactEmailCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final updates = <String, dynamic>{
        'event_name': _eventNameCtrl.text.trim(),
        'client_name': _clientNameCtrl.text.trim(),
        'date': _formatDateForSave(_selectedDate),
        'start_time': _formatTimeForSave(_startTime),
        'end_time': _formatTimeForSave(_endTime),
        'venue_name': _venueNameCtrl.text.trim(),
        'venue_address': _venueAddressCtrl.text.trim(),
        'city': _cityCtrl.text.trim(),
        'state': _stateCtrl.text.trim(),
        'contact_name': _contactNameCtrl.text.trim(),
        'contact_phone': _contactPhoneCtrl.text.trim(),
        'contact_email': _contactEmailCtrl.text.trim(),
        'notes': _notesCtrl.text.trim(),
      };

      await _eventService.updateEvent(widget.draftId, updates);

      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Draft updated'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save: $e'),
          backgroundColor: AppColors.errorDark,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 3)),
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
    final initial = isStart ? _startTime : _endTime;
    final picked = await showTimePicker(
      context: context,
      initialTime: initial ?? const TimeOfDay(hour: 9, minute: 0),
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
      // Auto-fill city and state from place details
      if (details.addressComponents['city'] != null) {
        _cityCtrl.text = details.addressComponents['city']!;
      }
      if (details.addressComponents['state'] != null) {
        _stateCtrl.text = details.addressComponents['state']!;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: AppColors.navySpaceCadet,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Edit Draft',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: Text(
              'Save',
              style: TextStyle(
                color: _saving ? Colors.white38 : AppColors.warning,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      body: AbsorbPointer(
        absorbing: _saving,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Basics Section
            _sectionHeader('Basics'),
            const SizedBox(height: 12),
            _modernInput(
              label: l10n.jobTitle,
              controller: _eventNameCtrl,
              icon: Icons.celebration_outlined,
              hint: 'Enter event title',
            ),
            const SizedBox(height: 16),
            _modernInput(
              label: l10n.client,
              controller: _clientNameCtrl,
              icon: Icons.business_outlined,
              hint: 'Client or company name',
            ),
            const SizedBox(height: 16),

            // Date Picker
            _modernDatePicker(),
            const SizedBox(height: 16),

            // Time Pickers Row
            Row(
              children: [
                Expanded(child: _modernTimePicker(isStart: true)),
                const SizedBox(width: 12),
                Expanded(child: _modernTimePicker(isStart: false)),
              ],
            ),

            const SizedBox(height: 28),

            // Location Section
            _sectionHeader('Location'),
            const SizedBox(height: 12),
            _modernInput(
              label: l10n.locationName,
              controller: _venueNameCtrl,
              icon: Icons.place_outlined,
              hint: 'Venue name',
            ),
            const SizedBox(height: 16),

            // Modern Address Field with Google Places
            ModernAddressField(
              controller: _venueAddressCtrl,
              label: l10n.address,
              icon: Icons.map_outlined,
              onPlaceSelected: _onPlaceSelected,
            ),
            const SizedBox(height: 16),

            // City & State Row
            Row(
              children: [
                Expanded(
                  child: _modernInput(
                    label: 'City',
                    controller: _cityCtrl,
                    icon: Icons.location_city_outlined,
                    hint: 'City',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _modernInput(
                    label: 'State',
                    controller: _stateCtrl,
                    icon: Icons.public_outlined,
                    hint: 'State',
                  ),
                ),
              ],
            ),

            const SizedBox(height: 28),

            // Contact Section
            _sectionHeader('Contact'),
            const SizedBox(height: 12),
            _modernInput(
              label: 'Contact Name',
              controller: _contactNameCtrl,
              icon: Icons.person_outline,
              hint: 'Contact person',
            ),
            const SizedBox(height: 16),
            _modernInput(
              label: 'Contact Phone',
              controller: _contactPhoneCtrl,
              icon: Icons.phone_outlined,
              hint: 'Phone number',
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            _modernInput(
              label: 'Contact Email',
              controller: _contactEmailCtrl,
              icon: Icons.email_outlined,
              hint: 'Email address',
              keyboardType: TextInputType.emailAddress,
            ),

            const SizedBox(height: 28),

            // Notes Section
            _sectionHeader('Notes'),
            const SizedBox(height: 12),
            _modernInput(
              label: 'Notes',
              controller: _notesCtrl,
              icon: Icons.notes_outlined,
              hint: 'Additional notes or instructions',
              maxLines: 4,
            ),

            const SizedBox(height: 32),

            // Save Button
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.techBlue, AppColors.oceanBlue],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.techBlue.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(_saving ? 'Saving...' : 'Save Changes'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: AppColors.techBlue,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  Widget _modernInput({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    String? hint,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: Colors.grey.shade600),
            const SizedBox(width: 8),
            Text(
              label,
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
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
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

  Widget _modernDatePicker() {
    final hasDate = _selectedDate != null;
    final displayText = hasDate
        ? DateFormat('EEE, MMM d, yyyy').format(_selectedDate!)
        : 'Select date';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.calendar_today_outlined, size: 16, color: Colors.grey.shade600),
            const SizedBox(width: 8),
            Text(
              'Date',
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
        InkWell(
          onTap: _pickDate,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade300, width: 1.5),
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

  Widget _modernTimePicker({required bool isStart}) {
    final time = isStart ? _startTime : _endTime;
    final hasTime = time != null;
    final displayText = hasTime ? time.format(context) : 'Select';
    final label = isStart ? 'Start Time' : 'End Time';
    final icon = isStart ? Icons.schedule_outlined : Icons.schedule_send_outlined;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: Colors.grey.shade600),
            const SizedBox(width: 8),
            Text(
              label,
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
        InkWell(
          onTap: () => _pickTime(isStart: isStart),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade300, width: 1.5),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (isStart ? AppColors.success : AppColors.warning)
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    size: 18,
                    color: isStart ? AppColors.success : AppColors.warning,
                  ),
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
                  color: Colors.grey.shade600,
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
