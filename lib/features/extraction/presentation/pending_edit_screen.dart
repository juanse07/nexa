import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nexa/l10n/app_localizations.dart';

import '../services/clients_service.dart';
import '../services/event_service.dart';
import '../services/google_places_service.dart';
import '../services/roles_service.dart';
import '../widgets/modern_address_field.dart';
import 'package:nexa/shared/presentation/theme/app_colors.dart';
import 'package:nexa/shared/widgets/web_content_wrapper.dart';

class PendingEditScreen extends StatefulWidget {
  final Map<String, dynamic> draft;
  final String draftId;
  final String? title; // Optional custom title

  const PendingEditScreen({
    super.key,
    required this.draft,
    required this.draftId,
    this.title,
  });

  @override
  State<PendingEditScreen> createState() => _PendingEditScreenState();
}

class _PendingEditScreenState extends State<PendingEditScreen> {
  final EventService _eventService = EventService();
  final ClientsService _clientsService = ClientsService();
  final RolesService _rolesService = RolesService();

  List<String> _clientSuggestions = [];

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

  List<DateTime> _selectedDates = [];

  // Roles list - each role has 'role' (name) and 'count' (positions needed)
  List<Map<String, dynamic>> _roles = [];

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
    final existingDate = _parseDate(d['date']?.toString());
    if (existingDate != null) {
      _selectedDates = [DateTime(existingDate.year, existingDate.month, existingDate.day)];
    }

    // Use event-level times as fallback for events created before per-role times
    final eventStart = _parseTime(d['start_time']?.toString());
    final eventEnd   = _parseTime(d['end_time']?.toString());

    // Parse existing roles, inheriting event-level times as fallback for old data
    final rolesData = d['roles'];
    if (rolesData is List) {
      _roles = rolesData.map((r) {
        final roleStart = _parseTime(r['start_time']?.toString()) ?? eventStart;
        final roleEnd   = _parseTime(r['end_time']?.toString())   ?? eventEnd;
        return <String, dynamic>{
          'role': (r['role'] ?? r['name'] ?? '').toString(),
          'count': (r['count'] ?? r['headcount'] ?? 1) as int,
          'call_time': r['call_time']?.toString(),
          if (roleStart != null) 'role_start_time': roleStart,
          if (roleEnd   != null) 'role_end_time':   roleEnd,
        };
      }).toList();
    }

    // Load client suggestions
    _loadClientSuggestions();
  }

  Future<void> _loadClientSuggestions() async {
    try {
      final clients = await _clientsService.fetchClients();
      if (mounted) {
        setState(() {
          _clientSuggestions = clients
              .map((c) => c['name']?.toString() ?? '')
              .where((name) => name.isNotEmpty)
              .toList();
        });
      }
    } catch (e) {
      // Silently fail - autocomplete is a nice-to-have
      print('[PendingEditScreen] Failed to load client suggestions: $e');
    }
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

  int get _totalEventsToCreate => _selectedDates.length;

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final validRoles = _roles.where((r) =>
          r['role']?.toString().isNotEmpty == true &&
          (r['count'] as int? ?? 0) > 0).toList();

      final locationFields = <String, dynamic>{
        'event_name': _eventNameCtrl.text.trim(),
        'client_name': _clientNameCtrl.text.trim(),
        'venue_name': _venueNameCtrl.text.trim(),
        'venue_address': _venueAddressCtrl.text.trim(),
        'city': _cityCtrl.text.trim(),
        'state': _stateCtrl.text.trim(),
        'contact_name': _contactNameCtrl.text.trim(),
        'contact_phone': _contactPhoneCtrl.text.trim(),
        'contact_email': _contactEmailCtrl.text.trim(),
        'notes': _notesCtrl.text.trim(),
      };

      int newDraftsCreated = 0;

      // Always include per-role times
      final rolesPayload = validRoles.isNotEmpty
          ? validRoles.map((r) {
              final rs = r['role_start_time'] as TimeOfDay?;
              final re = r['role_end_time']   as TimeOfDay?;
              return <String, dynamic>{
                'role': r['role'],
                'count': r['count'],
                if (r['call_time'] != null) 'call_time': r['call_time'],
                if (rs != null) 'start_time': _formatTimeForSave(rs),
                if (re != null) 'end_time':   _formatTimeForSave(re),
              };
            }).toList()
          : null;

      // Derive event-level times for backward compat (staff app sorting)
      TimeOfDay? derivedStart, derivedEnd;
      for (final r in validRoles) {
        final rs = r['role_start_time'] as TimeOfDay?;
        final re = r['role_end_time']   as TimeOfDay?;
        if (rs != null && (derivedStart == null || rs.hour * 60 + rs.minute < derivedStart.hour * 60 + derivedStart.minute)) derivedStart = rs;
        if (re != null && (derivedEnd == null || re.hour * 60 + re.minute > derivedEnd.hour * 60 + derivedEnd.minute)) derivedEnd = re;
      }

      final baseFields = <String, dynamic>{
        ...locationFields,
        if (derivedStart != null) 'start_time': _formatTimeForSave(derivedStart),
        if (derivedEnd != null)   'end_time':   _formatTimeForSave(derivedEnd),
        if (rolesPayload != null) 'roles': rolesPayload,
      };

      // Update existing event with first date; create drafts for extra dates
      final firstDate = _selectedDates.isNotEmpty ? _selectedDates.first : null;
      await _eventService.updateEvent(widget.draftId, {
        ...baseFields,
        'date': _formatDateForSave(firstDate),
      });

      for (final date in _selectedDates.skip(1)) {
        await _eventService.createEvent(<String, dynamic>{
          ...baseFields,
          'date': _formatDateForSave(date),
          'status': 'draft',
        });
        newDraftsCreated++;
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);

      final baseMsg = widget.draft['status'] == 'draft' ? 'Draft updated' : 'Event updated';
      ScaffoldMessenger.of(context)..clearSnackBars()..showSnackBar(
        SnackBar(
          content: Text(newDraftsCreated > 0
              ? '$baseMsg + $newDraftsCreated new draft${newDraftsCreated > 1 ? 's' : ''} created'
              : baseMsg),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)..clearSnackBars()..showSnackBar(
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
    try {
      final now = DateTime.now();
      final firstDate = DateTime(2020, 1, 1); // Allow past dates for editing
      final lastDate = now.add(const Duration(days: 365 * 5));

      DateTime initialDate = _selectedDates.isNotEmpty ? _selectedDates.last : now;
      if (initialDate.isBefore(firstDate)) initialDate = firstDate;
      else if (initialDate.isAfter(lastDate)) initialDate = lastDate;

      final picked = await showDatePicker(
        context: context,
        initialDate: initialDate,
        firstDate: firstDate,
        lastDate: lastDate,
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
        final normalized = DateTime(picked.year, picked.month, picked.day);
        setState(() {
          final alreadyAdded = _selectedDates.any((d) =>
              d.year == normalized.year &&
              d.month == normalized.month &&
              d.day == normalized.day);
          if (!alreadyAdded) {
            _selectedDates.add(normalized);
            _selectedDates.sort();
          }
        });
      }
    } catch (e, stack) {
      print('[PendingEditScreen] Error showing date picker: $e');
      print(stack);
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
        title: Text(
          widget.title ?? (widget.draft['status'] == 'draft' ? 'Edit Draft' : 'Edit Event'),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: Text(
              _totalEventsToCreate > 1
                  ? 'Save + ${_totalEventsToCreate - 1} More'
                  : 'Save',
              style: TextStyle(
                color: _saving ? Colors.white38 : AppColors.warning,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      body: WebContentWrapper.form(
        child: AbsorbPointer(
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
            _buildClientAutocomplete(l10n),
            const SizedBox(height: 16),

            // Date Picker
            _modernDatePicker(),
            const SizedBox(height: 16),

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

            // Positions Section (Roles)
            if (_roles.isNotEmpty) ...[
              _sectionHeader('Positions', onAdd: _showCreateRoleDialog),
              const SizedBox(height: 12),
              _buildRolesEditor(),
              const SizedBox(height: 28),
            ],

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
                label: Text(
                  _saving
                      ? 'Saving...'
                      : _totalEventsToCreate > 1
                          ? 'Save + Create ${_totalEventsToCreate - 1} More'
                          : 'Save Changes',
                ),
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
      ),
    );
  }

  Widget _sectionHeader(String title, {VoidCallback? onAdd}) {
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
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
              letterSpacing: 0.3,
            ),
          ),
        ),
        if (onAdd != null)
          GestureDetector(
            onTap: onAdd,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.techBlue.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.techBlue.withValues(alpha: 0.25),
                  width: 1,
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add, size: 13, color: AppColors.techBlue),
                  SizedBox(width: 3),
                  Text(
                    'New',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.techBlue,
                    ),
                  ),
                ],
              ),
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

  /// Client name field with autocomplete suggestions
  Widget _buildClientAutocomplete(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.business_outlined, size: 16, color: Colors.grey.shade600),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l10n.client,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                  letterSpacing: 0.1,
                ),
              ),
            ),
            GestureDetector(
              onTap: _showCreateClientDialog,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.techBlue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.techBlue.withValues(alpha: 0.25),
                    width: 1,
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add, size: 13, color: AppColors.techBlue),
                    SizedBox(width: 3),
                    Text(
                      'New',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.techBlue,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Autocomplete<String>(
          initialValue: TextEditingValue(text: _clientNameCtrl.text),
          optionsBuilder: (TextEditingValue textEditingValue) {
            if (textEditingValue.text.isEmpty) {
              return const Iterable<String>.empty();
            }
            final query = textEditingValue.text.toLowerCase();
            return _clientSuggestions.where((client) =>
              client.toLowerCase().contains(query)
            ).take(5);
          },
          onSelected: (String selection) {
            _clientNameCtrl.text = selection;
          },
          fieldViewBuilder: (context, textController, focusNode, onFieldSubmitted) {
            // Sync with our controller
            textController.text = _clientNameCtrl.text;
            textController.addListener(() {
              if (_clientNameCtrl.text != textController.text) {
                _clientNameCtrl.text = textController.text;
              }
            });

            return TextFormField(
              controller: textController,
              focusNode: focusNode,
              onFieldSubmitted: (_) => onFieldSubmitted(),
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                hintText: 'Client or company name',
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
                elevation: 8,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 200, maxWidth: 350),
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
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
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

  Widget _modernDatePicker() {
    final hasDates = _selectedDates.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.calendar_today_outlined, size: 16, color: Colors.grey.shade600),
            const SizedBox(width: 8),
            Text(
              'Date(s)',
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

        // Selected date chips
        if (hasDates) ...[
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: _selectedDates.map((date) {
              return Chip(
                label: Text(DateFormat('EEE, MMM d').format(date)),
                deleteIcon: const Icon(Icons.close, size: 15),
                onDeleted: () => setState(() => _selectedDates.remove(date)),
                backgroundColor: AppColors.techBlue.withValues(alpha: 0.08),
                side: BorderSide(
                  color: AppColors.techBlue.withValues(alpha: 0.3),
                  width: 1.2,
                ),
                labelStyle: const TextStyle(
                  color: AppColors.techBlue,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
                deleteIconColor: AppColors.techBlue,
                padding: const EdgeInsets.symmetric(horizontal: 2),
                visualDensity: VisualDensity.compact,
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
        ],

        // Add date button
        InkWell(
          onTap: _pickDate,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                  child: Icon(
                    hasDates
                        ? Icons.add_circle_outline_rounded
                        : Icons.calendar_today_outlined,
                    size: 20,
                    color: AppColors.techBlue,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    hasDates ? 'Add another date' : 'Select date',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: hasDates
                          ? Colors.grey.shade600
                          : Colors.grey.shade500,
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

  /// Build the roles editor with +/- buttons for each position
  Widget _buildRolesEditor() {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade300, width: 1.5),
          ),
          child: Column(
            children: [
              // "Set same time for all" shorthand row
              InkWell(
                onTap: _setAllRoleTimes,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      Icon(Icons.schedule_outlined, size: 16, color: AppColors.techBlue),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Set same time for all positions',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.techBlue),
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.techBlue),
                    ],
                  ),
                ),
              ),
              Divider(height: 1, color: Colors.grey.shade200),
              for (int i = 0; i < _roles.length; i++) ...[
                if (i > 0) Divider(height: 1, color: Colors.grey.shade200),
                _buildRoleRow(i),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Add Position button
        OutlinedButton.icon(
          onPressed: _showAddPositionDialog,
          icon: const Icon(Icons.add, size: 20),
          label: const Text('Add Position'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.techBlue,
            side: BorderSide(color: AppColors.techBlue.withValues(alpha: 0.5)),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRoleRow(int index) {
    final role = _roles[index];
    final roleName = role['role']?.toString() ?? 'Position';
    final count = (role['count'] as int?) ?? 1;
    final roleStart = role['role_start_time'] as TimeOfDay?;
    final roleEnd = role['role_end_time'] as TimeOfDay?;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Delete button
              IconButton(
                onPressed: () => _confirmRemoveRole(index, roleName),
                icon: Icon(
                  Icons.close,
                  size: 18,
                  color: Colors.grey.shade500,
                ),
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(),
                splashRadius: 16,
                tooltip: 'Remove position',
              ),
              const SizedBox(width: 8),
              // Role icon
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
              // Role name
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
                    // Minus button
                    IconButton(
                      onPressed: count > 1 ? () => _updateRoleCount(index, count - 1) : null,
                      icon: Icon(
                        Icons.remove,
                        size: 18,
                        color: count > 1 ? AppColors.errorDark : Colors.grey.shade400,
                      ),
                      padding: const EdgeInsets.all(6),
                      constraints: const BoxConstraints(),
                      splashRadius: 18,
                    ),
                    // Count display
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
                    // Plus button
                    IconButton(
                      onPressed: () => _updateRoleCount(index, count + 1),
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
          // Per-role time pickers — always visible
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildRoleTimeTile(
                  label: 'Start',
                  time: roleStart,
                  fallback: null,
                  isStart: true,
                  onTap: () => _updateRoleTime(index, isStart: true),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildRoleTimeTile(
                  label: 'End',
                  time: roleEnd,
                  fallback: null,
                  isStart: false,
                  onTap: () => _updateRoleTime(index, isStart: false),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _updateRoleCount(int index, int newCount) {
    if (newCount < 1) return;
    setState(() {
      _roles[index] = {
        ..._roles[index],
        'count': newCount,
      };
    });
  }

  /// Show confirmation dialog before removing a position
  void _confirmRemoveRole(int index, String roleName) {
    // If it's the last role, show a different message
    if (_roles.length == 1) {
      ScaffoldMessenger.of(context)..clearSnackBars()..showSnackBar(
        const SnackBar(
          content: Text('Cannot remove the last position. At least one is required.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Position'),
        content: Text('Are you sure you want to remove "$roleName" from this event?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _removeRole(index);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.errorDark,
              foregroundColor: Colors.white,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  /// Remove a role from the list
  void _removeRole(int index) {
    setState(() {
      _roles.removeAt(index);
    });
  }

  /// Show dialog to add a new position
  void _showAddPositionDialog() {
    final controller = TextEditingController();
    final countController = TextEditingController(text: '1');

    // Common position types for quick selection
    final commonPositions = [
      'Bartender',
      'Server',
      'Busser',
      'Host',
      'Cook',
      'Dishwasher',
      'Event Staff',
      'Security',
      'Photographer',
      'DJ',
      'Valet',
      'Coat Check',
    ];

    // Filter out positions that already exist
    final existingRoles = _roles.map((r) => r['role']?.toString().toLowerCase()).toSet();
    final availablePositions = commonPositions
        .where((p) => !existingRoles.contains(p.toLowerCase()))
        .toList();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Position'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Quick selection chips
                if (availablePositions.isNotEmpty) ...[
                  const Text(
                    'Quick Select:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: availablePositions.take(6).map((position) {
                      return ActionChip(
                        label: Text(position),
                        onPressed: () {
                          controller.text = position;
                          setDialogState(() {});
                        },
                        backgroundColor: controller.text == position
                            ? AppColors.techBlue.withValues(alpha: 0.2)
                            : null,
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 12),
                ],
                // Custom position input
                TextField(
                  controller: controller,
                  decoration: const InputDecoration(
                    labelText: 'Position Name',
                    hintText: 'e.g., Bartender, Server',
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.words,
                  autofocus: availablePositions.isEmpty,
                ),
                const SizedBox(height: 16),
                // Count input
                Row(
                  children: [
                    const Text('How many needed: '),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 80,
                      child: TextField(
                        controller: countController,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final name = controller.text.trim();
                final count = int.tryParse(countController.text) ?? 1;

                if (name.isEmpty) {
                  ScaffoldMessenger.of(context)..clearSnackBars()..showSnackBar(
                    const SnackBar(
                      content: Text('Please enter a position name'),
                      backgroundColor: AppColors.warning,
                    ),
                  );
                  return;
                }

                // Check if position already exists
                if (existingRoles.contains(name.toLowerCase())) {
                  ScaffoldMessenger.of(context)..clearSnackBars()..showSnackBar(
                    SnackBar(
                      content: Text('"$name" already exists. Update the count instead.'),
                      backgroundColor: AppColors.warning,
                    ),
                  );
                  return;
                }

                Navigator.of(ctx).pop();
                _addRole(name, count > 0 ? count : 1);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.techBlue,
                foregroundColor: Colors.white,
              ),
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateRoleTime(int index, {required bool isStart}) async {
    final role = _roles[index];
    final current = (isStart ? role['role_start_time'] : role['role_end_time']) as TimeOfDay?;
    final picked = await showTimePicker(
      context: context,
      initialTime: current ?? const TimeOfDay(hour: 18, minute: 0),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.techBlue,
            onPrimary: Colors.white,
            surface: Colors.white,
            onSurface: AppColors.textDark,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _roles[index] = {
          ..._roles[index],
          if (isStart) 'role_start_time': picked else 'role_end_time': picked,
        };
      });
    }
  }

  Future<void> _setAllRoleTimes() async {
    final firstStart = _roles.isNotEmpty ? _roles.first['role_start_time'] as TimeOfDay? : null;
    final firstEnd   = _roles.isNotEmpty ? _roles.first['role_end_time']   as TimeOfDay? : null;
    final pickedStart = await showTimePicker(
      context: context,
      initialTime: firstStart ?? const TimeOfDay(hour: 18, minute: 0),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.techBlue,
            onPrimary: Colors.white,
            surface: Colors.white,
            onSurface: AppColors.textDark,
          ),
        ),
        child: child!,
      ),
    );
    if (pickedStart == null || !mounted) return;
    final pickedEnd = await showTimePicker(
      context: context,
      initialTime: firstEnd ?? const TimeOfDay(hour: 23, minute: 0),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.techBlue,
            onPrimary: Colors.white,
            surface: Colors.white,
            onSurface: AppColors.textDark,
          ),
        ),
        child: child!,
      ),
    );
    if (pickedEnd == null || !mounted) return;
    setState(() {
      _roles = _roles.map((r) => {...r, 'role_start_time': pickedStart, 'role_end_time': pickedEnd}).toList();
    });
  }

  Widget _buildRoleTimeTile({
    required String label,
    required TimeOfDay? time,
    required TimeOfDay? fallback,
    required VoidCallback onTap,
    required bool isStart,
  }) {
    final effective = time ?? fallback;
    final hasOwn = time != null;
    final color = isStart ? AppColors.success : AppColors.warning;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: hasOwn ? color.withValues(alpha: 0.06) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: hasOwn ? color.withValues(alpha: 0.35) : Colors.grey.shade300,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isStart ? Icons.schedule_outlined : Icons.schedule_send_outlined,
              size: 13,
              color: hasOwn ? color : Colors.grey.shade400,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade500,
                    ),
                  ),
                  Text(
                    effective != null
                        ? '${effective.format(context)}${!hasOwn ? ' ↑' : ''}'
                        : 'Tap to set',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: effective != null
                          ? (hasOwn ? AppColors.textDark : Colors.grey.shade500)
                          : Colors.grey.shade400,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCreateClientDialog() async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Client'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            hintText: 'Client or company name',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.techBlue,
              foregroundColor: Colors.white,
            ),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty || !mounted) return;
    try {
      final result = await _clientsService.createClient(name);
      final created = (result['name'] ?? name).toString();
      setState(() {
        if (!_clientSuggestions.any((c) => c.toLowerCase() == created.toLowerCase())) {
          _clientSuggestions.add(created);
        }
        _clientNameCtrl.text = created;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(
          content: Text('"$created" added to catalog'),
          backgroundColor: AppColors.success,
        ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(
          content: Text('Failed to create client: $e'),
          backgroundColor: AppColors.errorDark,
        ));
    }
  }

  Future<void> _showCreateRoleDialog() async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Position'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            hintText: 'e.g., Bartender, Chef, Security',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.techBlue,
              foregroundColor: Colors.white,
            ),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty || !mounted) return;
    try {
      await _rolesService.createRole(name);
      _addRole(name, 1);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(
          content: Text('"$name" added to catalog'),
          backgroundColor: AppColors.success,
        ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(
          content: Text('Failed to create position: $e'),
          backgroundColor: AppColors.errorDark,
        ));
    }
  }

  /// Add a new role to the list
  void _addRole(String name, int count) {
    setState(() {
      _roles.add({
        'role': name,
        'count': count,
      });
    });
  }
}
