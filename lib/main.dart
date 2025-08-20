import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:mime/mime.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // Continue without .env so the app still boots
  }
  runApp(const NexaApp());
}

class NexaApp extends StatelessWidget {
  const NexaApp({super.key});
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(title: 'Nexa', home: ExtractionHome());
  }
}

class ExtractionHome extends StatefulWidget {
  const ExtractionHome({super.key});

  @override
  State<ExtractionHome> createState() => _ExtractionHomeState();
}

class _ExtractionHomeState extends State<ExtractionHome>
    with SingleTickerProviderStateMixin {
  String? extractedText;
  Map<String, dynamic>? structuredData;
  bool isLoading = false;
  String? errorMessage;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  String? userApiKey;

  late TabController _tabController;

  // Manual entry form controllers
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
      // Ensure we have an API key
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
        // For images, send as base64 to the API and ask for OCR+extraction
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

      final response = await _extractStructuredData(text);
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

    // Fallback to .env for dev
    final envKey = dotenv.env['OPENAI_API_KEY'];
    if (envKey != null && envKey.isNotEmpty) {
      userApiKey = envKey;
      return true;
    }

    // Prompt user to enter a key
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

  Future<Map<String, dynamic>> _extractStructuredData(String input) async {
    final apiKey = userApiKey ?? dotenv.env['OPENAI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('Missing OpenAI API key.');
    }

    // If the input starts with our special image marker, route to vision model
    final isImage = input.startsWith('[[IMAGE_BASE64]]:');
    final visionModel = dotenv.env['OPENAI_VISION_MODEL'] ?? 'gpt-4o-mini';
    final textModel = dotenv.env['OPENAI_TEXT_MODEL'] ?? 'gpt-4o-mini';

    final uri = Uri.parse(
      dotenv.env['OPENAI_BASE_URL'] ??
          'https://api.openai.com/v1/chat/completions',
    );

    final systemPrompt =
        'You are a structured information extractor for catering event staffing. Extract fields: event_name, client_name, date (ISO 8601), start_time, end_time, venue_name, venue_address, city, state, country, contact_name, contact_phone, contact_email, setup_time, uniform, notes, headcount_total, roles (list of {role, count, call_time}), pay_rate_info. Return strict JSON.';

    Map<String, dynamic> messages;
    if (isImage) {
      final base64Image = input.substring('[[IMAGE_BASE64]]:'.length);
      messages = {
        'model': visionModel,
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          {
            'role': 'user',
            'content': [
              {
                'type': 'text',
                'text':
                    'Extract structured event staffing info and return only JSON.',
              },
              {
                'type': 'image_url',
                'image_url': {'url': 'data:image/png;base64,$base64Image'},
              },
            ],
          },
        ],
        'temperature': 0,
        'max_tokens': 800,
      };
    } else {
      messages = {
        'model': textModel,
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          {
            'role': 'user',
            'content': 'Extract JSON from the following text:\n\n$input',
          },
        ],
        'temperature': 0,
        'max_tokens': 800,
      };
    }

    final headers = {
      HttpHeaders.authorizationHeader: 'Bearer $apiKey',
      HttpHeaders.contentTypeHeader: 'application/json',
    };
    final orgId = dotenv.env['OPENAI_ORG_ID'];
    if (orgId != null && orgId.isNotEmpty) {
      headers['OpenAI-Organization'] = orgId;
    }

    final httpResponse = await _postWithRetries(uri, headers, messages);
    if (httpResponse.statusCode >= 300) {
      if (httpResponse.statusCode == 429) {
        throw Exception(
          'OpenAI API error 429 (rate limit or quota). Add billing, slow down requests, or try later. Details: ${httpResponse.body}',
        );
      }
      throw Exception(
        'OpenAI API error (${httpResponse.statusCode}): ${httpResponse.body}',
      );
    }

    final decoded = jsonDecode(httpResponse.body) as Map<String, dynamic>;
    String content;
    try {
      content = decoded['choices'][0]['message']['content'] as String;
    } catch (_) {
      content = httpResponse.body;
    }

    // Try to parse JSON from content
    final start = content.indexOf('{');
    final end = content.lastIndexOf('}');
    if (start != -1 && end != -1 && end > start) {
      final jsonSlice = content.substring(start, end + 1);
      return jsonDecode(jsonSlice) as Map<String, dynamic>;
    }
    throw Exception('Failed to parse JSON from response: $content');
  }

  Future<http.Response> _postWithRetries(
    Uri uri,
    Map<String, String> headers,
    Map<String, dynamic> body,
  ) async {
    const int maxAttempts = 3;
    int attempt = 0;
    while (true) {
      attempt += 1;
      try {
        final response = await http.post(
          uri,
          headers: headers,
          body: jsonEncode(body),
        );
        if (response.statusCode == 429 || response.statusCode >= 500) {
          if (attempt < maxAttempts) {
            final backoffSeconds = 1 << (attempt - 1);
            await Future.delayed(Duration(seconds: backoffSeconds));
            continue;
          }
        }
        return response;
      } catch (e) {
        if (attempt >= maxAttempts) rethrow;
        final backoffSeconds = 1 << (attempt - 1);
        await Future.delayed(Duration(seconds: backoffSeconds));
      }
    }
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

      // Remove empty fields
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
          ],
          labelColor: const Color(0xFF6366F1),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF6366F1),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildUploadTab(), _buildManualEntryTab()],
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
            // Header Card
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
                    color: const Color(0xFF6366F1).withOpacity(0.2),
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
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Upload Button
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
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

            // Loading indicator
            if (isLoading) ...[
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFF6366F1),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Analyzing document with AI...',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Error message
            if (errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Color(0xFFEF4444),
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        errorMessage!,
                        style: const TextStyle(
                          color: Color(0xFFEF4444),
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Extracted text preview
            if (extractedText != null &&
                !extractedText!.startsWith('[[IMAGE_BASE64]]')) ...[
              _buildCard(
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
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Structured result
            if (structuredData != null) ...[
              _buildCard(
                title: 'Event Details',
                icon: Icons.event_note,
                child: _buildEventDetails(structuredData!),
              ),
            ],
          ],
        ),
      ),
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
              // Header Card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF059669), Color(0xFF10B981)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF059669).withOpacity(0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Icon(Icons.edit_note, color: Colors.white, size: 32),
                    const SizedBox(height: 12),
                    const Text(
                      'Manual Entry',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Enter event details manually for precise control',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Event Information Section
              _buildFormSection(
                title: 'Event Information',
                icon: Icons.event,
                children: [
                  _buildTextField(
                    controller: _eventNameController,
                    label: 'Event Name',
                    icon: Icons.celebration,
                    required: true,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _clientNameController,
                    label: 'Client Name',
                    icon: Icons.person,
                    required: true,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: _dateController,
                          label: 'Date (YYYY-MM-DD)',
                          icon: Icons.calendar_today,
                          required: true,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTextField(
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
                        child: _buildTextField(
                          controller: _startTimeController,
                          label: 'Start Time',
                          icon: Icons.access_time,
                          placeholder: 'HH:MM',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTextField(
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

              // Venue Information Section
              _buildFormSection(
                title: 'Venue Information',
                icon: Icons.location_on,
                children: [
                  _buildTextField(
                    controller: _venueNameController,
                    label: 'Venue Name',
                    icon: Icons.business,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
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
                        child: _buildTextField(
                          controller: _cityController,
                          label: 'City',
                          icon: Icons.location_city,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTextField(
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

              // Contact Information Section
              _buildFormSection(
                title: 'Contact Information',
                icon: Icons.contact_phone,
                children: [
                  _buildTextField(
                    controller: _contactNameController,
                    label: 'Contact Name',
                    icon: Icons.person_outline,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _contactPhoneController,
                    label: 'Phone Number',
                    icon: Icons.phone,
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _contactEmailController,
                    label: 'Email',
                    icon: Icons.email,
                    keyboardType: TextInputType.emailAddress,
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Notes Section
              _buildFormSection(
                title: 'Additional Notes',
                icon: Icons.note,
                children: [
                  _buildTextField(
                    controller: _notesController,
                    label: 'Notes',
                    icon: Icons.notes,
                    maxLines: 3,
                    placeholder: 'Special requirements, setup details, etc.',
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Submit Button
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
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
              ),
              const SizedBox(height: 20),

              // Results Display
              if (structuredData != null) ...[
                _buildCard(
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

  Widget _buildFormSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF059669).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: const Color(0xFF059669), size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? placeholder,
    bool required = false,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: required
          ? (value) {
              if (value == null || value.trim().isEmpty) {
                return '$label is required';
              }
              return null;
            }
          : null,
      decoration: InputDecoration(
        labelText: label + (required ? ' *' : ''),
        hintText: placeholder,
        prefixIcon: Icon(icon, color: const Color(0xFF059669)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF059669), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFEF4444), width: 2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFEF4444), width: 2),
        ),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
    );
  }

  Widget _buildCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: const Color(0xFF6366F1), size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _buildEventDetails(Map<String, dynamic> data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (data['event_name'] != null)
          _buildDetailRow('Event', data['event_name'], Icons.celebration),
        if (data['client_name'] != null)
          _buildDetailRow('Client', data['client_name'], Icons.person),
        if (data['date'] != null)
          _buildDetailRow('Date', data['date'], Icons.calendar_today),
        if (data['start_time'] != null && data['end_time'] != null)
          _buildDetailRow(
            'Time',
            '${data['start_time']} - ${data['end_time']}',
            Icons.access_time,
          ),
        if (data['venue_name'] != null)
          _buildDetailRow('Venue', data['venue_name'], Icons.location_on),
        if (data['venue_address'] != null)
          _buildDetailRow('Address', data['venue_address'], Icons.place),
        if (data['contact_phone'] != null)
          _buildDetailRow('Phone', data['contact_phone'], Icons.phone),
        if (data['headcount_total'] != null)
          _buildDetailRow(
            'Headcount',
            data['headcount_total'].toString(),
            Icons.people,
          ),

        // Roles section
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

        // Raw JSON toggle
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

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF6366F1)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
