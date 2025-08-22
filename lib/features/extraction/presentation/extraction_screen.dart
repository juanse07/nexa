import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mime/mime.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../../../shared/ui/widgets.dart';
import '../services/event_service.dart';
import '../services/extraction_service.dart';

class ExtractionScreen extends StatefulWidget {
  const ExtractionScreen({super.key});

  @override
  State<ExtractionScreen> createState() => _ExtractionScreenState();
}

class _ExtractionScreenState extends State<ExtractionScreen>
    with SingleTickerProviderStateMixin {
  String? extractedText;
  Map<String, dynamic>? structuredData;
  bool isLoading = false;
  String? errorMessage;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  String? userApiKey;

  late TabController _tabController;

  // Events listing state
  List<Map<String, dynamic>>? _events;
  bool _isEventsLoading = false;
  String? _eventsError;

  final _formKey = GlobalKey<FormState>();
  final _eventNameController = TextEditingController();
  final _clientNameController = TextEditingController();
  final _dateController = TextEditingController();
  final _startTimeController = TextEditingController();
  final _endTimeController = TextEditingController();
  final _venueNameController = TextEditingController();
  final _venueAddressController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _contactNameController = TextEditingController();
  final _contactPhoneController = TextEditingController();
  final _contactEmailController = TextEditingController();
  final _headcountController = TextEditingController();
  final _notesController = TextEditingController();

  late final ExtractionService _extractionService;
  late final EventService _eventService;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _extractionService = ExtractionService();
    _eventService = EventService();
    _loadEvents();
  }

  @override
  void dispose() {
    _tabController.dispose();
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
    super.dispose();
  }

  Future<void> _pickAndProcessFile() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
      extractedText = null;
      structuredData = null;
    });

    try {
      final ok = await _ensureApiKey();
      if (!ok) {
        setState(() {
          isLoading = false;
          errorMessage = 'Please enter a valid OpenAI API key to continue.';
        });
        return;
      }
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg', 'heic'],
      );
      if (result == null || result.files.isEmpty) {
        setState(() {
          isLoading = false;
        });
        return;
      }

      final path = result.files.single.path;
      if (path == null) {
        throw Exception('No file path found');
      }

      final file = File(path);
      final mimeType = lookupMimeType(path) ?? '';

      String text = '';
      if (mimeType.contains('pdf') || path.toLowerCase().endsWith('.pdf')) {
        text = await _extractTextFromPdf(file);
      } else if (mimeType.startsWith('image/')) {
        final bytes = await file.readAsBytes();
        final base64Image = base64Encode(bytes);
        text = '[[IMAGE_BASE64]]:$base64Image';
      } else {
        throw Exception('Unsupported file type: $mimeType');
      }

      setState(() {
        extractedText = text.length > 2000
            ? '${text.substring(0, 2000)}... [truncated]'
            : text;
      });

      final response = await _extractionService.extractStructuredData(
        input: text,
        apiKey: userApiKey ?? dotenv.env['OPENAI_API_KEY'] ?? '',
      );
      setState(() {
        structuredData = response;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  Future<bool> _ensureApiKey() async {
    userApiKey = await _secureStorage.read(key: 'OPENAI_API_KEY');
    if (userApiKey != null && userApiKey!.isNotEmpty) return true;

    final envKey = dotenv.env['OPENAI_API_KEY'];
    if (envKey != null && envKey.isNotEmpty) {
      userApiKey = envKey;
      return true;
    }

    if (!mounted) return false;
    final entered = await _promptForApiKey(context);
    if (entered != null && entered.isNotEmpty) {
      await _secureStorage.write(key: 'OPENAI_API_KEY', value: entered);
      userApiKey = entered;
      return true;
    }
    return false;
  }

  Future<String?> _promptForApiKey(BuildContext context) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Enter OpenAI API Key'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: 'sk-... (stored securely on this device)',
            ),
            obscureText: true,
            enableSuggestions: false,
            autocorrect: false,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<String> _extractTextFromPdf(File file) async {
    final bytes = await file.readAsBytes();
    final document = PdfDocument(inputBytes: bytes);
    final extractor = PdfTextExtractor(document);
    final buffer = StringBuffer();
    for (int i = 0; i < document.pages.count; i++) {
      buffer.writeln(extractor.extractText(startPageIndex: i, endPageIndex: i));
    }
    document.dispose();
    return buffer.toString();
  }

  void _submitManualEntry() {
    if (_formKey.currentState!.validate()) {
      final manualData = {
        'event_name': _eventNameController.text.trim(),
        'client_name': _clientNameController.text.trim(),
        'date': _dateController.text.trim(),
        'start_time': _startTimeController.text.trim(),
        'end_time': _endTimeController.text.trim(),
        'venue_name': _venueNameController.text.trim(),
        'venue_address': _venueAddressController.text.trim(),
        'city': _cityController.text.trim(),
        'state': _stateController.text.trim(),
        'country': 'USA',
        'contact_name': _contactNameController.text.trim(),
        'contact_phone': _contactPhoneController.text.trim(),
        'contact_email': _contactEmailController.text.trim(),
        'headcount_total': int.tryParse(_headcountController.text.trim()),
        'notes': _notesController.text.trim(),
        'roles': [],
      };

      manualData.removeWhere(
        (key, value) =>
            value == null || value == '' || (value is int && value == 0),
      );

      setState(() {
        structuredData = manualData;
        extractedText = 'Manually entered data';
        errorMessage = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Event details saved successfully!'),
          backgroundColor: Color(0xFF059669),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Nexa',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 24),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        elevation: 0,
        shadowColor: Colors.transparent,
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.upload_file), text: 'Upload Document'),
            Tab(icon: Icon(Icons.edit), text: 'Manual Entry'),
            Tab(icon: Icon(Icons.view_module), text: 'Events'),
          ],
          labelColor: const Color(0xFF6366F1),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF6366F1),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildUploadTab(),
          _buildManualEntryTab(),
          _buildEventsTab(),
        ],
      ),
    );
  }

  Widget _buildUploadTab() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Icon(Icons.auto_awesome, color: Colors.white, size: 32),
                  const SizedBox(height: 12),
                  const Text(
                    'Event Data Extractor',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Upload a PDF or image to extract catering event details',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: isLoading ? null : _pickAndProcessFile,
                icon: Icon(
                  isLoading ? Icons.hourglass_empty : Icons.upload_file,
                  size: 20,
                ),
                label: Text(
                  isLoading ? 'Processing...' : 'Pick PDF or Image',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF6366F1),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (isLoading) ...[
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const LoadingIndicator(
                  text: 'Analyzing document with AI...',
                ),
              ),
              const SizedBox(height: 20),
            ],
            if (errorMessage != null) ...[
              ErrorBanner(message: errorMessage!),
              const SizedBox(height: 20),
            ],
            if (extractedText != null &&
                !extractedText!.startsWith('[[IMAGE_BASE64]]')) ...[
              InfoCard(
                title: 'Extracted Text Preview',
                icon: Icons.text_snippet,
                child: Container(
                  height: 200,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      extractedText!,
                      style: const TextStyle(
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
            if (structuredData != null) ...[
              InfoCard(
                title: 'Event Details',
                icon: Icons.event_note,
                child: _buildEventDetails(structuredData!),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: () => _saveCurrentEvent(),
                  icon: const Icon(Icons.cloud_upload, size: 18),
                  label: const Text('Save to Database'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _loadEvents() async {
    setState(() {
      _isEventsLoading = true;
      _eventsError = null;
    });
    try {
      final items = await _eventService.fetchEvents();
      // Sort: upcoming soonest -> oldest past -> no date
      DateTime? parseDate(Map<String, dynamic> e) {
        final dynamic v = e['date'];
        if (v is String && v.isNotEmpty) {
          try {
            return DateTime.parse(v);
          } catch (_) {}
        }
        return null;
      }

      final DateTime now = DateTime.now();
      final List<Map<String, dynamic>> upcoming = [];
      final List<Map<String, dynamic>> past = [];
      final List<Map<String, dynamic>> noDate = [];

      for (final e in items) {
        final d = parseDate(e);
        if (d == null) {
          noDate.add(e);
        } else if (!d.isBefore(DateTime(now.year, now.month, now.day))) {
          upcoming.add(e);
        } else {
          past.add(e);
        }
      }

      int ascByDate(Map<String, dynamic> a, Map<String, dynamic> b) {
        final DateTime da = parseDate(a)!;
        final DateTime db = parseDate(b)!;
        return da.compareTo(db);
      }

      upcoming.sort(ascByDate); // soonest first
      past.sort((a, b) => ascByDate(b, a)); // most recent past first

      final List<Map<String, dynamic>> sorted = [
        ...upcoming,
        ...past,
        ...noDate,
      ];
      setState(() {
        _events = sorted;
        _isEventsLoading = false;
      });
    } catch (e) {
      setState(() {
        _eventsError = e.toString();
        _isEventsLoading = false;
      });
    }
  }

  Widget _buildEventsTab() {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _loadEvents,
        color: const Color(0xFF6366F1),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double width = constraints.maxWidth;
            int crossAxisCount = 1;
            if (width >= 1200) {
              crossAxisCount = 4;
            } else if (width >= 900) {
              crossAxisCount = 3;
            } else if (width >= 600) {
              crossAxisCount = 2;
            }

            final List<Map<String, dynamic>> items = _events ?? const [];

            if (_isEventsLoading && items.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                children: const [
                  Center(child: LoadingIndicator(text: 'Loading events...')),
                ],
              );
            }

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              children: [
                if (_eventsError != null) ...[
                  ErrorBanner(message: _eventsError!),
                  const SizedBox(height: 12),
                ],
                if (!_isEventsLoading && items.isEmpty && _eventsError == null)
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.inbox,
                          color: Colors.grey.shade400,
                          size: 28,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No events found',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Create an event from the other tabs or pull to refresh.',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                if (items.isNotEmpty)
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.8,
                    ),
                    itemCount: items.length,
                    itemBuilder: (context, index) =>
                        _buildEventCard(items[index]),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildEventCard(Map<String, dynamic> e) {
    String title = (e['event_name'] ?? e['venue_name'] ?? 'Untitled Event')
        .toString();
    String subtitle = (e['client_name'] ?? '').toString();
    String dateStr = '';
    final dynamic rawDate = e['date'];
    if (rawDate is String && rawDate.isNotEmpty) {
      try {
        final d = DateTime.parse(rawDate);
        dateStr =
            '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      } catch (_) {
        dateStr = rawDate;
      }
    }
    final String location = [
      e['city'],
      e['state'],
    ].where((v) => v != null && v.toString().isNotEmpty).join(', ');
    final int? headcount = (e['headcount_total'] is int)
        ? e['headcount_total'] as int
        : int.tryParse((e['headcount_total'] ?? '').toString());
    final List<dynamic> roles = (e['roles'] is List)
        ? (e['roles'] as List)
        : const [];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.event,
                  color: Color(0xFF6366F1),
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            runSpacing: 6,
            spacing: 10,
            children: [
              if (subtitle.isNotEmpty)
                _miniInfo(icon: Icons.person, text: subtitle),
              if (dateStr.isNotEmpty)
                _miniInfo(icon: Icons.calendar_today, text: dateStr),
              if (location.isNotEmpty)
                _miniInfo(icon: Icons.place, text: location),
              if (headcount != null)
                _miniInfo(icon: Icons.people, text: 'HC $headcount'),
            ],
          ),
          if (roles.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 24,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemBuilder: (context, index) {
                  final r = roles[index] as Map<String, dynamic>? ?? {};
                  final String rName = (r['role'] ?? 'Role').toString();
                  final String rCount = (r['count'] ?? '').toString();
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      rCount.isNotEmpty ? '$rName ($rCount)' : rName,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF334155),
                      ),
                    ),
                  );
                },
                separatorBuilder: (context, _) => const SizedBox(width: 8),
                itemCount: roles.length,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _miniInfo({required IconData icon, required String text}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey.shade600),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildManualEntryTab() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              HeaderCard(
                title: 'Manual Entry',
                subtitle: 'Enter event details manually for precise control',
                icon: Icons.edit_note,
                gradientColors: const [Color(0xFF059669), Color(0xFF10B981)],
              ),
              const SizedBox(height: 24),
              FormSection(
                title: 'Event Information',
                icon: Icons.event,
                children: [
                  LabeledTextField(
                    controller: _eventNameController,
                    label: 'Event Name',
                    icon: Icons.celebration,
                    isRequired: true,
                  ),
                  const SizedBox(height: 16),
                  LabeledTextField(
                    controller: _clientNameController,
                    label: 'Client Name',
                    icon: Icons.person,
                    isRequired: true,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: LabeledTextField(
                          controller: _dateController,
                          label: 'Date (YYYY-MM-DD)',
                          icon: Icons.calendar_today,
                          isRequired: true,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: LabeledTextField(
                          controller: _headcountController,
                          label: 'Headcount',
                          icon: Icons.people,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: LabeledTextField(
                          controller: _startTimeController,
                          label: 'Start Time',
                          icon: Icons.access_time,
                          placeholder: 'HH:MM',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: LabeledTextField(
                          controller: _endTimeController,
                          label: 'End Time',
                          icon: Icons.access_time_filled,
                          placeholder: 'HH:MM',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              FormSection(
                title: 'Venue Information',
                icon: Icons.location_on,
                children: [
                  LabeledTextField(
                    controller: _venueNameController,
                    label: 'Venue Name',
                    icon: Icons.business,
                  ),
                  const SizedBox(height: 16),
                  LabeledTextField(
                    controller: _venueAddressController,
                    label: 'Address',
                    icon: Icons.place,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: LabeledTextField(
                          controller: _cityController,
                          label: 'City',
                          icon: Icons.location_city,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: LabeledTextField(
                          controller: _stateController,
                          label: 'State',
                          icon: Icons.map,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              FormSection(
                title: 'Contact Information',
                icon: Icons.contact_phone,
                children: [
                  LabeledTextField(
                    controller: _contactNameController,
                    label: 'Contact Name',
                    icon: Icons.person_outline,
                  ),
                  const SizedBox(height: 16),
                  LabeledTextField(
                    controller: _contactPhoneController,
                    label: 'Phone Number',
                    icon: Icons.phone,
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 16),
                  LabeledTextField(
                    controller: _contactEmailController,
                    label: 'Email',
                    icon: Icons.email,
                    keyboardType: TextInputType.emailAddress,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              FormSection(
                title: 'Additional Notes',
                icon: Icons.note,
                children: [
                  LabeledTextField(
                    controller: _notesController,
                    label: 'Notes',
                    icon: Icons.notes,
                    maxLines: 3,
                    placeholder: 'Special requirements, setup details, etc.',
                  ),
                ],
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _submitManualEntry,
                icon: const Icon(Icons.save, size: 20),
                label: const Text(
                  'Save Event Details',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF059669),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: structuredData == null
                      ? null
                      : () => _saveCurrentEvent(),
                  icon: const Icon(Icons.cloud_upload, size: 18),
                  label: const Text('Save to Database'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              if (structuredData != null) ...[
                InfoCard(
                  title: 'Event Details',
                  icon: Icons.event_note,
                  child: _buildEventDetails(structuredData!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEventDetails(Map<String, dynamic> data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (data['event_name'] != null)
          DetailRow(
            label: 'Event',
            value: data['event_name'],
            icon: Icons.celebration,
          ),
        if (data['client_name'] != null)
          DetailRow(
            label: 'Client',
            value: data['client_name'],
            icon: Icons.person,
          ),
        if (data['date'] != null)
          DetailRow(
            label: 'Date',
            value: data['date'],
            icon: Icons.calendar_today,
          ),
        if (data['start_time'] != null && data['end_time'] != null)
          DetailRow(
            label: 'Time',
            value: '${data['start_time']} - ${data['end_time']}',
            icon: Icons.access_time,
          ),
        if (data['venue_name'] != null)
          DetailRow(
            label: 'Venue',
            value: data['venue_name'],
            icon: Icons.location_on,
          ),
        if (data['venue_address'] != null)
          DetailRow(
            label: 'Address',
            value: data['venue_address'],
            icon: Icons.place,
          ),
        if (data['contact_phone'] != null)
          DetailRow(
            label: 'Phone',
            value: data['contact_phone'],
            icon: Icons.phone,
          ),
        if (data['headcount_total'] != null)
          DetailRow(
            label: 'Headcount',
            value: data['headcount_total'].toString(),
            icon: Icons.people,
          ),
        if (data['roles'] != null && data['roles'] is List) ...[
          const SizedBox(height: 16),
          const Text(
            'Roles Needed',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 8),
          ...((data['roles'] as List).map(
            (role) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFF6366F1),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${role['role'] ?? 'Unknown'} (${role['count'] ?? 0})',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (role['call_time'] != null)
                    Text(
                      role['call_time'],
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                ],
              ),
            ),
          )),
        ],
        const SizedBox(height: 16),
        TextButton.icon(
          onPressed: () {
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Raw JSON Data'),
                content: SingleChildScrollView(
                  child: Text(
                    const JsonEncoder.withIndent('  ').convert(data),
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Close'),
                  ),
                ],
              ),
            );
          },
          icon: const Icon(Icons.code, size: 16),
          label: const Text('View Raw JSON'),
          style: TextButton.styleFrom(foregroundColor: const Color(0xFF6366F1)),
        ),
      ],
    );
  }

  Future<void> _saveCurrentEvent() async {
    if (structuredData == null) return;
    final Map<String, dynamic> payload = Map<String, dynamic>.from(
      structuredData!,
    );
    // Normalize date: backend accepts ISO or Date; try to ensure ISO string
    final date = payload['date'];
    if (date is String && date.isNotEmpty) {
      try {
        final parsed = DateTime.parse(date);
        payload['date'] = parsed.toIso8601String();
      } catch (_) {}
    }
    try {
      await _eventService.createEvent(payload);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Event saved to database'),
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
    }
  }
}
