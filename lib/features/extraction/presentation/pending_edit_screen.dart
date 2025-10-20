import 'package:flutter/material.dart';
import 'package:nexa/l10n/app_localizations.dart';

import '../services/pending_events_service.dart';

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
  final PendingEventsService _pendingService = PendingEventsService();

  late final TextEditingController _eventNameCtrl;
  late final TextEditingController _clientNameCtrl;
  late final TextEditingController _dateCtrl;
  late final TextEditingController _startTimeCtrl;
  late final TextEditingController _endTimeCtrl;
  late final TextEditingController _venueNameCtrl;
  late final TextEditingController _venueAddressCtrl;
  late final TextEditingController _cityCtrl;
  late final TextEditingController _stateCtrl;
  late final TextEditingController _contactNameCtrl;
  late final TextEditingController _contactPhoneCtrl;
  late final TextEditingController _contactEmailCtrl;
  late final TextEditingController _notesCtrl;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final d = widget.draft;
    _eventNameCtrl = TextEditingController(text: (d['event_name'] ?? '').toString());
    _clientNameCtrl = TextEditingController(text: (d['client_name'] ?? '').toString());
    _dateCtrl = TextEditingController(text: (d['date'] ?? '').toString());
    _startTimeCtrl = TextEditingController(text: (d['start_time'] ?? '').toString());
    _endTimeCtrl = TextEditingController(text: (d['end_time'] ?? '').toString());
    _venueNameCtrl = TextEditingController(text: (d['venue_name'] ?? '').toString());
    _venueAddressCtrl = TextEditingController(text: (d['venue_address'] ?? '').toString());
    _cityCtrl = TextEditingController(text: (d['city'] ?? '').toString());
    _stateCtrl = TextEditingController(text: (d['state'] ?? '').toString());
    _contactNameCtrl = TextEditingController(text: (d['contact_name'] ?? '').toString());
    _contactPhoneCtrl = TextEditingController(text: (d['contact_phone'] ?? '').toString());
    _contactEmailCtrl = TextEditingController(text: (d['contact_email'] ?? '').toString());
    _notesCtrl = TextEditingController(text: (d['notes'] ?? '').toString());
  }

  @override
  void dispose() {
    _eventNameCtrl.dispose();
    _clientNameCtrl.dispose();
    _dateCtrl.dispose();
    _startTimeCtrl.dispose();
    _endTimeCtrl.dispose();
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
      final updated = <String, dynamic>{
        ...widget.draft,
        'id': widget.draftId,
        'event_name': _eventNameCtrl.text.trim(),
        'client_name': _clientNameCtrl.text.trim(),
        'date': _dateCtrl.text.trim(),
        'start_time': _startTimeCtrl.text.trim(),
        'end_time': _endTimeCtrl.text.trim(),
        'venue_name': _venueNameCtrl.text.trim(),
        'venue_address': _venueAddressCtrl.text.trim(),
        'city': _cityCtrl.text.trim(),
        'state': _stateCtrl.text.trim(),
        'contact_name': _contactNameCtrl.text.trim(),
        'contact_phone': _contactPhoneCtrl.text.trim(),
        'contact_email': _contactEmailCtrl.text.trim(),
        'notes': _notesCtrl.text.trim(),
      };
      await _pendingService.saveDraft(updated);
      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Draft updated'),
          backgroundColor: Color(0xFF059669),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save: $e'),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Draft'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: const Text('Save'),
          ),
        ],
      ),
      body: AbsorbPointer(
        absorbing: _saving,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _section('Basics'),
            _input(AppLocalizations.of(context)!.jobTitle, _eventNameCtrl, icon: Icons.celebration),
            _input(AppLocalizations.of(context)!.client, _clientNameCtrl, icon: Icons.business),
            Row(
              children: [
                Expanded(child: _input('Date (YYYY-MM-DD)', _dateCtrl, icon: Icons.calendar_today)),
              ],
            ),
            Row(
              children: [
                Expanded(child: _input('Start Time', _startTimeCtrl, icon: Icons.schedule)),
                const SizedBox(width: 8),
                Expanded(child: _input('End Time', _endTimeCtrl, icon: Icons.schedule_send)),
              ],
            ),
            const SizedBox(height: 12),
            _section('Location'),
            _input(AppLocalizations.of(context)!.locationName, _venueNameCtrl, icon: Icons.place),
            _input(AppLocalizations.of(context)!.address, _venueAddressCtrl, icon: Icons.map),
            Row(
              children: [
                Expanded(child: _input('City', _cityCtrl, icon: Icons.location_city)),
                const SizedBox(width: 8),
                Expanded(child: _input('State', _stateCtrl, icon: Icons.public)),
              ],
            ),
            const SizedBox(height: 12),
            _section('Contact'),
            _input('Contact Name', _contactNameCtrl, icon: Icons.person),
            _input('Contact Phone', _contactPhoneCtrl, icon: Icons.phone),
            _input('Contact Email', _contactEmailCtrl, icon: Icons.email),
            const SizedBox(height: 12),
            _section('Notes'),
            _input('Notes', _notesCtrl, icon: Icons.notes, maxLines: 4),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.save),
              label: const Text('Save Changes'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Color(0xFF6B7280),
        ),
      ),
    );
  }

  Widget _input(String label, TextEditingController controller, {IconData? icon, int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: icon != null ? Icon(icon, size: 20) : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: const Color(0xFFF9FAFB),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }
}


