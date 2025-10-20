import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nexa/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:get_it/get_it.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
// import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mime/mime.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../features/auth/data/services/auth_service.dart';
import '../../../features/auth/presentation/pages/login_page.dart';
import '../../../shared/ui/widgets.dart';
import '../../../core/network/api_client.dart';
import '../../../core/widgets/custom_sliver_app_bar.dart';
import '../../../core/widgets/pinned_header_delegate.dart';
import '../../../core/utils/responsive_layout.dart';
import '../services/clients_service.dart';
import '../services/draft_service.dart';
import '../services/event_service.dart';
import '../services/extraction_service.dart';
import '../services/google_places_service.dart';
import '../services/pending_events_service.dart';
import '../services/roles_service.dart';
import '../services/tariffs_service.dart';
import '../services/users_service.dart';
import '../services/chat_event_service.dart';
import '../widgets/modern_address_field.dart';
import '../../extraction/widgets/chat_message_widget.dart';
import '../../extraction/widgets/chat_input_widget.dart';
import 'pending_publish_screen.dart';
import 'pending_edit_screen.dart';
import '../../users/presentation/pages/manager_profile_page.dart';
import '../../users/presentation/pages/user_events_screen.dart';
import '../../events/presentation/event_detail_screen.dart';
import '../../teams/presentation/pages/teams_management_page.dart';
import 'package:nexa/core/network/socket_manager.dart';
import '../../users/presentation/pages/settings_page.dart';
import '../../users/data/services/manager_service.dart';
import '../../hours_approval/presentation/hours_approval_list_screen.dart';
import '../../chat/presentation/conversations_screen.dart';
import '../../chat/data/services/chat_service.dart';
import '../../chat/domain/entities/conversation.dart';
import '../../chat/presentation/chat_screen.dart';

class ExtractionScreen extends StatefulWidget {
  const ExtractionScreen({super.key});

  @override
  State<ExtractionScreen> createState() => _ExtractionScreenState();
}

class _ExtractionScreenState extends State<ExtractionScreen>
    with TickerProviderStateMixin {
  String? extractedText;
  Map<String, dynamic>? structuredData;
  bool isLoading = false;
  String? errorMessage;

  int _selectedIndex = 0;
  late TabController _createTabController;
  late TabController _eventsTabController;
  late TabController _catalogTabController;

  // Events listing state
  List<Map<String, dynamic>>? _events;
  bool _isEventsLoading = false;
  String? _eventsError;
  List<Map<String, dynamic>>? _eventsUpcoming;
  List<Map<String, dynamic>>? _eventsPast;
  // Pending drafts
  List<Map<String, dynamic>> _pendingDrafts = const [];
  bool _isPendingLoading = false;
  String? _viewerUserKey; // provider:subject used to filter events

  // Bulk upload state
  bool _isBulkProcessing = false;
  List<Map<String, dynamic>> _bulkItems = const [];

  // Clients listing state
  List<Map<String, dynamic>>? _clients;
  bool _isClientsLoading = false;
  String? _clientsError;

  final _formKey = GlobalKey<FormState>();
  final _eventNameController = TextEditingController();
  final _clientNameController = TextEditingController();
  final _dateController = TextEditingController();
  final _startTimeController = TextEditingController();
  final _endTimeController = TextEditingController();

  DateTime? _selectedDate;
  TimeOfDay? _selectedStartTime;
  TimeOfDay? _selectedEndTime;
  PlaceDetails? _selectedVenuePlace;
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
  late final ClientsService _clientsService;
  late final RolesService _rolesService;
  final DraftService _draftService = DraftService();
  final PendingEventsService _pendingService = PendingEventsService();
  bool _lastStructuredFromUpload = false;

  // AI Chat state
  final ChatEventService _aiChatService = ChatEventService();
  bool _isAIChatLoading = false;
  final ScrollController _aiChatScrollController = ScrollController();

  // Profile avatar state
  late final ManagerService _managerService;
  String? _profilePictureUrl;

  // Timer for real-time updates
  Timer? _updateTimer;
  StreamSubscription<SocketEvent>? _socketSubscription;

  Widget _maybeWebRefreshButton({
    required VoidCallback onPressed,
    String label = 'Refresh',
    EdgeInsetsGeometry padding = EdgeInsets.zero,
  }) {
    if (!kIsWeb) return const SizedBox.shrink();
    return Padding(
      padding: padding,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.refresh, size: 18),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF6366F1),
          side: const BorderSide(color: Color(0xFF6366F1)),
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _createTabController = TabController(length: 4, vsync: this);
    _eventsTabController = TabController(length: 3, vsync: this);
    _catalogTabController = TabController(length: 3, vsync: this);
    _extractionService = ExtractionService();
    _eventService = EventService();
    _clientsService = ClientsService();
    _rolesService = RolesService();
    // Initialize ManagerService via GetIt
    final api = GetIt.I<ApiClient>();
    final storage = GetIt.I<FlutterSecureStorage>();
    _managerService = ManagerService(api, storage);
    _loadEvents();
    _loadClients();
    _loadRoles();
    _loadTariffs();
    _loadDraftIfAny();
    _loadPendingDrafts();
    _loadProfilePicture();
    _loadFavorites();
    _loadFirstUsersPage();
    _loadConversations();

    _socketSubscription = SocketManager.instance.events.listen((event) {
      if (!mounted) return;
      if (event.event.startsWith('event:')) {
        _loadEvents();
        _loadPendingDrafts();
      } else if (event.event.startsWith('team:')) {
        _loadClients();
        _loadRoles();
      } else if (event.event == 'chat:message') {
        _loadConversations();
      }
    });

    // Start timer for real-time updates
    _updateTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) {
        setState(() {
          // This will trigger a rebuild and update the time display
        });
      }
    });
  }

  @override
  void dispose() {
    _createTabController.dispose();
    _eventsTabController.dispose();
    _catalogTabController.dispose();
    _aiChatScrollController.dispose();
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
    _updateTimer?.cancel();
    _socketSubscription?.cancel();
    super.dispose();
  }

  Future<void> _openTeamsManagementPage() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const TeamsManagementPage()));
    if (!mounted) return;
    await _loadEvents();
  }

  Future<void> _loadDraftIfAny() async {
    final d = await _draftService.loadDraft();
    if (d == null) return;
    setState(() {
      structuredData = d;
      _eventNameController.text = (d['event_name'] ?? '').toString();
      _clientNameController.text = (d['client_name'] ?? '').toString();
      _dateController.text = (d['date'] ?? '').toString();
      _startTimeController.text = (d['start_time'] ?? '').toString();
      _endTimeController.text = (d['end_time'] ?? '').toString();
      _venueNameController.text = (d['venue_name'] ?? '').toString();
      _venueAddressController.text = (d['venue_address'] ?? '').toString();
      _cityController.text = (d['city'] ?? '').toString();
      _stateController.text = (d['state'] ?? '').toString();
      _contactNameController.text = (d['contact_name'] ?? '').toString();
      _contactPhoneController.text = (d['contact_phone'] ?? '').toString();
      _contactEmailController.text = (d['contact_email'] ?? '').toString();
      _headcountController.text = (d['headcount_total'] ?? '').toString();
      _notesController.text = (d['notes'] ?? '').toString();
    });
  }

  Future<void> _pickAndProcessFile() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
      extractedText = null;
      structuredData = null;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg', 'heic'],
        withData: kIsWeb,
      );
      if (result == null || result.files.isEmpty) {
        setState(() {
          isLoading = false;
        });
        return;
      }

      final platformFile = result.files.single;
      final bytes = await _resolvePlatformFileBytes(platformFile);
      final headerBytes = bytes.length > 20 ? bytes.sublist(0, 20) : bytes;
      final fileName = platformFile.name;
      final lowerName = fileName.toLowerCase();
      final lookupName = kIsWeb ? fileName : (platformFile.path ?? fileName);
      final mimeType =
          lookupMimeType(lookupName, headerBytes: headerBytes) ?? '';

      String text;
      if (mimeType.contains('pdf') || lowerName.endsWith('.pdf')) {
        text = await _extractTextFromPdfBytes(bytes);
      } else if (mimeType.startsWith('image/') ||
          lowerName.endsWith('.png') ||
          lowerName.endsWith('.jpg') ||
          lowerName.endsWith('.jpeg') ||
          lowerName.endsWith('.heic')) {
        text = '[[IMAGE_BASE64]]:${base64Encode(bytes)}';
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
      );
      // Exclude any client fields from the AI output; user must pick from our DB
      final sanitized = Map<String, dynamic>.from(response);
      sanitized.remove('client_name');
      sanitized.remove('client_company_name');
      sanitized.remove('third_party_company_name');
      _clientNameController.text = '';
      setState(() {
        structuredData = sanitized;
        isLoading = false;
        _lastStructuredFromUpload = true;
      });
      // Persist draft to allow switching tabs
      try {
        await _draftService.saveDraft(sanitized);
      } catch (_) {}
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  Future<Uint8List> _resolvePlatformFileBytes(PlatformFile file) async {
    if (file.bytes != null) {
      return file.bytes!;
    }
    if (!kIsWeb && file.path != null) {
      final ioFile = File(file.path!);
      return ioFile.readAsBytes();
    }
    throw Exception('Unable to read bytes for ${file.name}');
  }

  Future<Uint8List> _readBytesFromBulkItem(Map<String, dynamic> item) async {
    final dynamic rawBytes = item['bytes'];
    if (rawBytes is Uint8List) {
      return rawBytes;
    }
    final dynamic path = item['path'];
    if (!kIsWeb && path is String && path.isNotEmpty) {
      final ioFile = File(path);
      return ioFile.readAsBytes();
    }
    throw Exception('Unable to read bytes for ${item['name'] ?? 'file'}');
  }

  String _resolvePlatformFileId(PlatformFile file) {
    if (kIsWeb) {
      return file.identifier ?? '${file.name}_${file.hashCode}_${file.size}';
    }
    return file.identifier ??
        file.path ??
        '${file.name}_${file.hashCode}_${file.size}';
  }

  int _extractRoleCount(List<dynamic> roles, String keyword) {
    for (final dynamic item in roles) {
      if (item is Map<String, dynamic>) {
        final String name = (item['role'] ?? '').toString().toLowerCase();
        if (name.contains(keyword)) {
          final dynamic raw = item['count'];
          if (raw is int) return raw;
          final int? parsed = int.tryParse(raw?.toString() ?? '');
          if (parsed != null) return parsed;
        }
      }
    }
    return 0;
  }

  Future<Map<String, dynamic>?> _promptStaffCounts(
    Map<String, dynamic> payload,
  ) async {
    final List<dynamic> roles = (payload['roles'] is List)
        ? (payload['roles'] as List)
        : const [];

    // Get all available roles from database
    final availableRoles = _roles ?? [];

    // Create controllers for each available role
    final Map<String, TextEditingController> roleControllers = {};
    final Map<String, String> roleIds = {}; // Store role IDs for reference

    for (final role in availableRoles) {
      final roleId = (role['id'] ?? '').toString();
      final roleName = (role['name'] ?? '').toString();
      if (roleId.isEmpty || roleName.isEmpty) continue;

      // Try to find existing count for this role
      final existingCount = _extractRoleCount(roles, roleName.toLowerCase());
      roleControllers[roleName] = TextEditingController(
        text: existingCount.toString(),
      );
      roleIds[roleName] = roleId;
    }

    final String selectedClientName = _clientNameController.text.trim();

    Map<String, dynamic>? result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Staff needed'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Please confirm counts before saving. You can set 0 if not needed.',
                  style: TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.business, color: Color(0xFF6366F1)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          selectedClientName.isNotEmpty
                              ? selectedClientName
                              : 'No client selected',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // Dynamically create text fields for all roles
                ...roleControllers.entries.map((entry) {
                  final roleName = entry.key;
                  final controller = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: TextField(
                      controller: controller,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: roleName,
                        prefixIcon: const Icon(Icons.work_outline),
                      ),
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(null),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                // Collect all role counts
                final Map<String, int> counts = {};
                for (final entry in roleControllers.entries) {
                  final roleName = entry.key;
                  final controller = entry.value;
                  final count = int.tryParse(controller.text.trim()) ?? 0;
                  counts[roleName.toLowerCase()] = count < 0 ? 0 : count;
                }

                final String company = selectedClientName.isNotEmpty
                    ? selectedClientName
                    : (payload['client_name']?.toString() ?? '').trim();
                Navigator.of(
                  ctx,
                ).pop({'counts': counts, 'client_name': company});
              },
              child: const Text('Continue'),
            ),
          ],
        );
      },
    );

    return result;
  }

  List<Map<String, dynamic>> _mergeStaffCountsIntoRoles(
    List<dynamic> existing,
    Map<String, int> counts,
  ) {
    final List<Map<String, dynamic>> roles = existing
        .whereType<Map<String, dynamic>>()
        .toList(growable: true);

    // Get all available roles from database
    final availableRoles = _roles ?? [];

    // Create a set of role names (lowercase) that we're updating
    final updatingRoleNames = <String>{};
    for (final entry in counts.entries) {
      updatingRoleNames.add(entry.key.toLowerCase());
    }

    // Remove existing roles that match any of the roles we're updating
    roles.removeWhere((r) {
      final roleName = (r['role']?.toString() ?? '').toLowerCase();
      return updatingRoleNames.contains(roleName);
    });

    // Add new roles with counts > 0
    for (final entry in counts.entries) {
      final count = entry.value;
      if (count > 0) {
        // Find the proper case name from available roles
        final properCaseName =
            availableRoles
                .firstWhere(
                  (r) =>
                      (r['name']?.toString() ?? '').toLowerCase() == entry.key,
                  orElse: () => {'name': entry.key},
                )['name']
                ?.toString() ??
            entry.key;

        roles.add({'role': properCaseName, 'count': count});
      }
    }

    return roles;
  }

  Future<String> _extractTextFromPdfBytes(Uint8List bytes) async {
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
    // Custom validation for date picker
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.pleaseSelectDate),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
      return;
    }

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
        if (_selectedVenuePlace != null) ...{
          'venue_latitude': _selectedVenuePlace!.latitude,
          'venue_longitude': _selectedVenuePlace!.longitude,
          'google_maps_url':
              'https://www.google.com/maps/search/?api=1&query='
              '${Uri.encodeComponent(_selectedVenuePlace!.formattedAddress.isNotEmpty ? _selectedVenuePlace!.formattedAddress : '${_selectedVenuePlace!.latitude},${_selectedVenuePlace!.longitude}')}'
              '&query_place_id=${Uri.encodeComponent(_selectedVenuePlace!.placeId)}',
        },
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
        _lastStructuredFromUpload = false;
      });
      // Save draft for cross-tab persistence
      _draftService.saveDraft(manualData);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Details captured. Tap 'Save to Database' to persist."),
          backgroundColor: Color(0xFF059669),
        ),
      );
    }
  }

  /// Shows draft preview in a bottom sheet modal
  void _showDraftPreview(BuildContext context, Map<String, dynamic> currentData) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.3),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFF8F9FA),
                Color(0xFFFFFFFF),
              ],
            ),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Color(0x1A000000),
                blurRadius: 24,
                offset: Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            children: [
              // Drag handle
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF7C3AED),
                            Color(0xFF6366F1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.auto_awesome,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Event Draft',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            '${currentData.length} fields extracted',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_aiChatService.eventComplete)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.check_circle,
                              size: 14,
                              color: Color(0xFF10B981),
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Complete',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF10B981),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Content
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  children: [
                    ...currentData.entries.map((entry) {
                      final key = entry.key;
                      final value = entry.value;

                      // Format the label
                      final label = key
                          .split('_')
                          .map((word) =>
                              word[0].toUpperCase() + word.substring(1))
                          .join(' ');

                      // Format the value
                      String displayValue;
                      if (value is List) {
                        displayValue = value.map((role) {
                          if (role is Map) {
                            // AI uses 'role' field, but some other sources might use 'role_name'
                            final roleName = role['role'] ?? role['role_name'] ?? 'Unknown Role';
                            final callTime = role['call_time'] ?? '';
                            final count = role['count'];
                            String countStr = '';
                            if (count != null) {
                              final countValue = count is int ? count : int.tryParse(count.toString());
                              if (countValue != null && countValue != 0) {
                                countStr = ' (×$countValue)';
                              }
                            }
                            return '$roleName${callTime.isNotEmpty ? " at $callTime" : ""}$countStr';
                          }
                          return role.toString();
                        }).join('\n');
                      } else {
                        displayValue = value.toString();
                      }

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFF6366F1).withOpacity(0.1),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFF8B5CF6),
                                        Color(0xFF6366F1),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    label,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              displayValue,
                              style: const TextStyle(
                                fontSize: 15,
                                color: Color(0xFF0F172A),
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
              // Save button
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 12,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: SafeArea(
                  child: ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(context);

                      // Save to database as pending event
                      final id = await _pendingService.saveDraft(currentData);

                      if (!mounted) return;

                      setState(() {
                        structuredData = currentData;
                        extractedText = 'AI Chat extracted data';
                        errorMessage = null;
                        _lastStructuredFromUpload = false;
                        _aiChatService.startNewConversation();
                        final greeting = _aiChatService.getGreeting();
                      });

                      _draftService.saveDraft(currentData);

                      // Reload pending drafts to show the new one
                      await _loadPendingDrafts();

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(AppLocalizations.of(context)!.jobSavedToPending),
                          backgroundColor: const Color(0xFF059669),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.save, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Save to Pending',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getAppBarTitle() {
    final now = DateTime.now();
    final hour = now.hour;

    String greeting;
    if (hour < 12) {
      greeting = "Good Morning!";
    } else if (hour < 17) {
      greeting = "Good Afternoon!";
    } else {
      greeting = "Good Evening!";
    }

    switch (_selectedIndex) {
      case 0: // Create tab
        if (structuredData != null && structuredData!.isNotEmpty) {
          final eventName =
              structuredData!['event_name']?.toString() ?? 'Untitled Event';
          return eventName.length > 20
              ? '${eventName.substring(0, 20)}...'
              : eventName;
        }
        return greeting;
      case 1: // Events tab
        final pendingCount = _pendingDrafts.length;
        final upcomingCount = _eventsUpcoming?.length ?? 0;
        final pastCount = _eventsPast?.length ?? 0;
        final totalEvents = (pendingCount + upcomingCount + pastCount);
        return AppLocalizations.of(context)!.jobsTabLabel(
          pendingCount,
          upcomingCount,
          pastCount,
        );
      case 2: // Chat tab
        return "Chat";
      case 3: // Hours tab
        return "Hours Approval";
      case 4: // Catalog tab
        final clientsCount = _clients?.length ?? 0;
        final rolesCount = _roles?.length ?? 0;
        return "Catalog • $clientsCount clients, $rolesCount roles";
      default:
        return greeting;
    }
  }

  String _getAppBarSubtitle() {
    final now = DateTime.now();
    final weekday = [
      'Mon',
      'Tue',
      'Wed',
      'Thu',
      'Fri',
      'Sat',
      'Sun',
    ][now.weekday - 1];
    final month = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ][now.month - 1];
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final baseTime = "$weekday, $month ${now.day} at $timeStr";

    switch (_selectedIndex) {
      case 0: // Create tab
        if (structuredData != null && structuredData!.isNotEmpty) {
          final clientName = structuredData!['client_name']?.toString();
          final date = structuredData!['date']?.toString();
          if (clientName != null && clientName.isNotEmpty) {
            return date != null && date.isNotEmpty
                ? "$clientName • $date"
                : clientName;
          }
          return date ?? baseTime;
        }
        return baseTime;
      case 1: // Events tab
        final pendingCount = _pendingDrafts.length;
        final upcomingCount = _eventsUpcoming?.length ?? 0;
        final pastCount = _eventsPast?.length ?? 0;
        final totalEvents = (pendingCount + upcomingCount + pastCount);

        if (totalEvents > 0) {
          // Show the most relevant category first
          if (pendingCount > 0) {
            return AppLocalizations.of(context)!.pendingUpcomingStatus(
              pendingCount,
              upcomingCount,
              baseTime,
            );
          } else if (upcomingCount > 0) {
            return AppLocalizations.of(context)!.upcomingPastStatus(
              upcomingCount,
              pastCount,
              baseTime,
            );
          } else {
            return "$totalEvents total events • $baseTime";
          }
        }
        return baseTime;
      case 2: // Chat tab
        return "Messages and team members • $baseTime";
      case 3: // Hours tab
        return baseTime;
      case 4: // Catalog tab
        final clientsCount = _clients?.length ?? 0;
        final rolesCount = _roles?.length ?? 0;
        final tariffsCount = _tariffs?.length ?? 0;
        if (clientsCount > 0 || rolesCount > 0) {
          return "$clientsCount clients • $rolesCount roles • $tariffsCount tariffs • $baseTime";
        }
        return baseTime;
      default:
        return baseTime;
    }
  }

  List<Widget> _buildSliverContent() {
    switch (_selectedIndex) {
      case 0: // Create tab
        return _buildCreateSlivers();
      case 1: // Events tab
        return _buildEventsSlivers();
      case 2: // Chat tab
        return _buildChatSlivers();
      case 3: // Hours tab
        return _buildHoursSlivers();
      case 4: // Catalog tab
        return _buildCatalogSlivers();
      default:
        return [];
    }
  }

  List<Widget> _buildPinnedHeaders() {
    final topPadding = MediaQuery.of(context).padding.top;

    switch (_selectedIndex) {
      case 0: // Create tab - pin the TabBar
        return [
          SliverPersistentHeader(
            pinned: true,
            delegate: PinnedHeaderDelegate(
              height: 64.0,
              safeAreaPadding: topPadding,
              child: Material(
                elevation: 4.0,
                child: Container(
                  color: Colors.white,
                  child: SafeArea(
                    bottom: false,
                    child: TabBar(
                      controller: _createTabController,
                      tabs: const [
                        Tab(
                          icon: Icon(Icons.upload_file),
                          text: 'Upload Document',
                        ),
                        Tab(icon: Icon(Icons.edit), text: 'Manual Entry'),
                        Tab(
                          icon: Icon(Icons.cloud_upload),
                          text: 'Multi-Upload',
                        ),
                        Tab(icon: Icon(Icons.chat), text: 'AI Chat'),
                      ],
                      labelColor: Color(0xFF6366F1),
                      unselectedLabelColor: Colors.grey,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ];
      case 1: // Events tab - pin the TabBar
        return [
          SliverPersistentHeader(
            pinned: true,
            delegate: PinnedHeaderDelegate(
              height: 44.0,
              safeAreaPadding: topPadding,
              child: Material(
                elevation: 4.0,
                child: Container(
                  color: Colors.white,
                  child: SafeArea(
                    bottom: false,
                    child: TabBar(
                      controller: _eventsTabController,
                      tabs: const [
                        Tab(text: 'Pending'),
                        Tab(text: 'Upcoming'),
                        Tab(text: 'Past'),
                      ],
                      labelColor: Color(0xFF6366F1),
                      unselectedLabelColor: Colors.grey,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ];
      case 2: // Chat tab - pin the search bar
        return [
          SliverPersistentHeader(
            pinned: true,
            delegate: PinnedHeaderDelegate(
              height: 118.0,
              safeAreaPadding: topPadding,
              child: Material(
                elevation: 4.0,
                child: Container(
                  color: Colors.white,
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _userSearchCtrl,
                                  decoration: const InputDecoration(
                                    prefixIcon: Icon(Icons.search),
                                    hintText: 'Search name or email',
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                  ),
                                  onSubmitted: (_) => _loadFirstUsersPage(),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                onPressed: _loadFirstUsersPage,
                                icon: const Icon(Icons.refresh),
                                tooltip: 'Refresh',
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                FilterChip(
                                  selected: _selectedRole == null,
                                  label: const Text('All'),
                                  onSelected: (selected) {
                                    setState(() => _selectedRole = null);
                                  },
                                ),
                                const SizedBox(width: 8),
                                ..._favoriteRoleOptions.map(
                                  (role) => Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: FilterChip(
                                      selected: _selectedRole == role,
                                      label: Text(role),
                                      onSelected: (selected) {
                                        setState(
                                          () => _selectedRole = selected
                                              ? role
                                              : null,
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ];
      case 3: // Hours tab - no pinned header needed
        return [];
      case 4: // Catalog tab - pin the TabBar
        return [
          SliverPersistentHeader(
            pinned: true,
            delegate: PinnedHeaderDelegate(
              height: 44.0,
              safeAreaPadding: topPadding,
              child: Material(
                elevation: 4.0,
                child: Container(
                  color: Colors.white,
                  child: SafeArea(
                    bottom: false,
                    child: TabBar(
                      controller: _catalogTabController,
                      tabs: const [
                        Tab(text: 'Clients'),
                        Tab(text: 'Roles'),
                        Tab(text: 'Tariffs'),
                      ],
                      labelColor: Color(0xFF6366F1),
                      unselectedLabelColor: Colors.grey,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ];
      default:
        return [];
    }
  }

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0: // Create tab
        return TabBarView(
          controller: _createTabController,
          children: [
            _buildUploadTab(),
            _buildManualEntryTab(),
            _buildBulkUploadTab(),
            _buildChatTab(),
          ],
        );
      case 1: // Events tab
        return TabBarView(
          controller: _eventsTabController,
          children: [
            _pendingInner(),
            _eventsInner(_eventsUpcoming ?? const []),
            _pastEventsInner(_eventsPast ?? const []),
          ],
        );
      case 2: // Chat tab
        return _buildChatContent();
      case 3: // Hours tab
        return const HoursApprovalListScreen();
      case 4: // Catalog tab
        return TabBarView(
          controller: _catalogTabController,
          children: [_buildClientsTab(), _buildRolesTab(), _buildTariffsTab()],
        );
      default:
        return Container();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool useDesktopLayout = ResponsiveLayout.shouldUseDesktopLayout(
      context,
    );

    if (useDesktopLayout) {
      return _buildDesktopLayout(context);
    } else {
      return _buildMobileLayout(context);
    }
  }

  Widget _buildMobileLayout(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            CustomSliverAppBar(
              title: _getAppBarTitle(),
              subtitle: _getAppBarSubtitle(),
              expandedHeight: 120.0,
              titleFontSize: _selectedIndex == 1 ? 14.0 : null,
              subtitleFontSize: _selectedIndex == 1 ? 9.0 : null,
              actions: [
                _buildProfileMenu(context),
              ],
            ),
            ..._buildPinnedHeaders(),
          ];
        },
        body: _buildBody(),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [Color(0xFF7A3AFB), Color(0xFF5B27D8)],
          ),
        ),
        child: SafeArea(
          child: SizedBox(
            height: 56,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavButton(0, Icons.add_circle_outline, AppLocalizations.of(context)!.navCreate),
                _buildNavButton(1, Icons.view_module, AppLocalizations.of(context)!.navJobs),
                _buildNavButton(2, Icons.chat_bubble_outline, AppLocalizations.of(context)!.navChat),
                _buildNavButton(3, Icons.schedule, AppLocalizations.of(context)!.navHours),
                _buildNavButton(4, Icons.inventory_2, AppLocalizations.of(context)!.navCatalog),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopLayout(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Row(
        children: [
          // Side navigation rail
          _buildNavigationRail(context),
          // Main content area
          Expanded(
            child: Column(
              children: [
                // Top app bar for desktop
                _buildDesktopAppBar(context),
                // Content
                Expanded(
                  child: ResponsiveContainer(
                    maxWidth: 1600,
                    child: NestedScrollView(
                      headerSliverBuilder: (context, innerBoxIsScrolled) {
                        return [..._buildPinnedHeaders()];
                      },
                      body: _buildBody(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationRail(BuildContext context) {
    return Container(
      width: 240,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF7A3AFB), Color(0xFF5B27D8)],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          // Logo section
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Image.asset(
                    'assets/appbar_logo.png',
                    height: 32,
                    width: 32,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Nexa',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white24, height: 1),
          const SizedBox(height: 16),
          // Navigation items
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                children: [
                  _buildNavRailItem(
                    0,
                    Icons.add_circle_outline,
                    AppLocalizations.of(context)!.navCreate,
                  ),
                  _buildNavRailItem(1, Icons.view_module, AppLocalizations.of(context)!.navJobs),
                  _buildNavRailItem(2, Icons.chat_bubble_outline, AppLocalizations.of(context)!.navChat),
                  _buildNavRailItem(3, Icons.schedule, AppLocalizations.of(context)!.navHours),
                  _buildNavRailItem(4, Icons.inventory_2, AppLocalizations.of(context)!.navCatalog),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavRailItem(int index, IconData icon, String label) {
    final isSelected = _selectedIndex == index;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() {
              _selectedIndex = index;
            });
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isSelected
                  ? Colors.white.withOpacity(0.2)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: isSelected
                  ? Border.all(color: Colors.white.withOpacity(0.3), width: 1)
                  : null,
            ),
            child: Row(
              children: [
                Icon(icon, color: Colors.white, size: 22),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w500,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopAppBar(BuildContext context) {
    return Container(
      height: 70,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0),
        child: Row(
          children: [
            // Title section
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _getAppBarTitle(),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _getAppBarSubtitle(),
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
            // Actions
            Row(
              children: [
                IconButton(
                  tooltip: 'Manage teams',
                  icon: const Icon(Icons.groups_outlined),
                  onPressed: _openTeamsManagementPage,
                ),
                const SizedBox(width: 12),
                _buildProfileMenu(context),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavButton(int index, IconData icon, String label) {
    final isSelected = _selectedIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedIndex = index;
          });
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileMenu(BuildContext context) {
    final theme = Theme.of(context);
    return PopupMenuButton<String>(
      tooltip: 'Account',
      position: PopupMenuPosition.under,
      onSelected: (value) async {
        if (value == 'profile') {
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const ManagerProfilePage()));
        } else if (value == 'settings') {
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const SettingsPage()));
        } else if (value == 'teams') {
          _openTeamsManagementPage();
        } else if (value == 'logout') {
          await _handleLogout(context);
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem<String>(
          value: 'profile',
          child: ListTile(
            leading: Icon(Icons.account_circle),
            title: Text('My Profile'),
          ),
        ),
        const PopupMenuItem<String>(
          value: 'settings',
          child: ListTile(
            leading: Icon(Icons.settings),
            title: Text('Settings'),
          ),
        ),
        const PopupMenuItem<String>(
          value: 'teams',
          child: ListTile(
            leading: Icon(Icons.groups_outlined),
            title: Text('Manage Teams'),
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'logout',
          child: ListTile(leading: Icon(Icons.logout), title: Text('Logout')),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: _buildAvatarOrIcon(theme),
      ),
    );
  }

  Widget _buildAvatarOrIcon(ThemeData theme) {
    final url = _profilePictureUrl?.trim();
    final hasUrl = url != null && url.isNotEmpty;
    return CircleAvatar(
      radius: 16,
      backgroundColor: Colors.white24,
      backgroundImage: hasUrl ? NetworkImage(url!) : null,
      child: hasUrl ? null : const Icon(Icons.person, color: Colors.white),
    );
  }

  Future<void> _loadProfilePicture() async {
    try {
      final me = await _managerService.getMe();
      SocketManager.instance.registerManager(me.id);
      if (!mounted) return;
      setState(() {
        _profilePictureUrl = me.picture;
      });
    } catch (_) {
      // Silently ignore; avatar will fall back to icon
    }
  }

  Future<void> _handleLogout(BuildContext context) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      // Perform logout
      await AuthService.signOut();

      // Navigate to login page and remove all previous routes
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (route) => false,
        );
      }
    }
  }

  List<Widget> _buildCreateSlivers() {
    return [
      SliverToBoxAdapter(
        child: Container(
          color: Colors.white,
          child: TabBar(
            controller: _createTabController,
            tabs: const [
              Tab(icon: Icon(Icons.upload_file), text: 'Upload Document'),
              Tab(icon: Icon(Icons.edit), text: 'Manual Entry'),
              Tab(icon: Icon(Icons.cloud_upload), text: 'Multi-Upload'),
              Tab(icon: Icon(Icons.chat), text: 'AI Chat'),
            ],
            labelColor: Color(0xFF6366F1),
            unselectedLabelColor: Colors.grey,
          ),
        ),
      ),
      SliverFillRemaining(
        child: TabBarView(
          controller: _createTabController,
          children: [
            _buildUploadTab(),
            _buildManualEntryTab(),
            _buildBulkUploadTab(),
            _buildChatTab(),
          ],
        ),
      ),
    ];
  }

  Widget _buildCreateTab() {
    return SafeArea(
      child: DefaultTabController(
        length: 4,
        child: Column(
          children: [
            const TabBar(
              tabs: [
                Tab(icon: Icon(Icons.upload_file), text: 'Upload Document'),
                Tab(icon: Icon(Icons.edit), text: 'Manual Entry'),
                Tab(icon: Icon(Icons.cloud_upload), text: 'Multi-Upload'),
                Tab(icon: Icon(Icons.chat), text: 'AI Chat'),
              ],
              labelColor: Color(0xFF6366F1),
              unselectedLabelColor: Colors.grey,
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildUploadTab(),
                  _buildManualEntryTab(),
                  _buildBulkUploadTab(),
                  _buildChatTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBulkUploadTab() {
    return SingleChildScrollView(
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              HeaderCard(
                title: 'Multi-Upload',
                subtitle:
                    'Upload multiple PDFs or images and save each as a pending draft',
                icon: Icons.cloud_upload,
                gradientColors: const [Color(0xFF10B981), Color(0xFF3B82F6)],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ElevatedButton.icon(
                    onPressed: _isBulkProcessing
                        ? null
                        : () => _pickAndProcessMultipleFiles(append: false),
                    icon: const Icon(Icons.folder_open),
                    label: const Text('Select Files'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      foregroundColor: Colors.white,
                    ),
                  ),
                  if (_bulkItems.isNotEmpty)
                    ElevatedButton.icon(
                      onPressed: _isBulkProcessing
                          ? null
                          : () => _pickAndProcessMultipleFiles(append: true),
                      icon: const Icon(Icons.add),
                      label: const Text('Add More'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  if (_bulkItems.any((e) => e['data'] != null))
                    ElevatedButton.icon(
                      onPressed: _isBulkProcessing
                          ? null
                          : _confirmAllBulkToPending,
                      icon: const Icon(Icons.done_all),
                      label: const Text('Confirm All'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF059669),
                        foregroundColor: Colors.white,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Tip: Long-press to multi-select in the picker. Or use Add More to append.',
                style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
              ),
              const SizedBox(height: 16),
              if (_isBulkProcessing)
                const LoadingIndicator(text: 'Processing files...'),
              const SizedBox(height: 8),
              ..._bulkItems.asMap().entries.map((entry) {
                final int index = entry.key;
                final Map<String, dynamic> item = entry.value;
                final String name = (item['name'] ?? 'File').toString();
                final String status = (item['status'] ?? 'queued').toString();
                final Map<String, dynamic>? data = (item['data'] as Map?)
                    ?.cast<String, dynamic>();
                final String subtitle = data == null
                    ? status[0].toUpperCase() + status.substring(1)
                    : _summarizeEvent(data);
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: ListTile(
                    leading: Icon(
                      data != null
                          ? Icons.check_circle
                          : status == 'error'
                          ? Icons.error
                          : Icons.hourglass_bottom,
                      color: data != null
                          ? const Color(0xFF059669)
                          : status == 'error'
                          ? const Color(0xFFDC2626)
                          : const Color(0xFF6366F1),
                    ),
                    title: Text(name),
                    subtitle: Text(subtitle),
                    isThreeLine: false,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (data != null)
                          TextButton(
                            onPressed: () => _confirmSingleBulkToPending(index),
                            child: const Text('Confirm'),
                          ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Color(0xFFDC2626),
                          ),
                          onPressed: () {
                            setState(() {
                              _bulkItems = List.of(_bulkItems)..removeAt(index);
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  String _summarizeEvent(Map<String, dynamic> data) {
    final client = (data['client_name'] ?? '').toString();
    final name = (data['event_name'] ?? data['venue_name'] ?? 'Untitled')
        .toString();
    final date = (data['date'] ?? '').toString();
    return [
      name,
      if (date.isNotEmpty) date,
      if (client.isNotEmpty) client,
    ].join(' • ');
  }

  Future<void> _pickAndProcessMultipleFiles({required bool append}) async {
    if (!append) {
      setState(() {
        _bulkItems = const [];
      });
    }
    setState(() => _isBulkProcessing = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg', 'heic'],
        withData: kIsWeb,
      );
      if (result == null || result.files.isEmpty) {
        setState(() => _isBulkProcessing = false);
        return;
      }

      final picked = result.files.toList();
      final existing = List<Map<String, dynamic>>.from(_bulkItems);
      final startIndex = existing.length;
      // Append new entries, dedup by unique identifier
      final added = <Map<String, dynamic>>[];
      for (final f in picked) {
        final id = _resolvePlatformFileId(f);
        final already =
            existing.any((e) => e['id'] == id) ||
            added.any((e) => e['id'] == id);
        if (!already) {
          added.add({
            'id': id,
            'name': f.name,
            'path': kIsWeb ? null : f.path,
            'bytes': f.bytes,
            'status': 'queued',
          });
        }
      }
      if (added.isEmpty) {
        setState(() => _isBulkProcessing = false);
        return;
      }
      setState(() {
        _bulkItems = [...existing, ...added];
      });

      for (int idx = 0; idx < added.length; idx++) {
        final currentIndex = startIndex + idx;
        final original = Map<String, dynamic>.from(_bulkItems[currentIndex]);
        setState(() {
          _bulkItems = List.of(_bulkItems);
          _bulkItems[currentIndex] = {
            ..._bulkItems[currentIndex],
            'status': 'processing',
          };
        });
        try {
          final bytes = await _readBytesFromBulkItem(original);
          final headerBytes = bytes.length > 20 ? bytes.sublist(0, 20) : bytes;
          final name = (original['name']?.toString() ?? '');
          final lowerName = name.toLowerCase();
          final rawPath = (original['path']?.toString() ?? '');
          final lookupName = rawPath.isNotEmpty ? rawPath : name;
          final mimeType =
              lookupMimeType(lookupName, headerBytes: headerBytes) ?? '';
          String input;
          if (mimeType.contains('pdf') || lowerName.endsWith('.pdf')) {
            input = await _extractTextFromPdfBytes(bytes);
          } else if (mimeType.startsWith('image/') ||
              lowerName.endsWith('.png') ||
              lowerName.endsWith('.jpg') ||
              lowerName.endsWith('.jpeg') ||
              lowerName.endsWith('.heic')) {
            input = '[[IMAGE_BASE64]]:${base64Encode(bytes)}';
          } else {
            throw Exception('Unsupported type: $mimeType');
          }
          final response = await _extractionService.extractStructuredData(
            input: input,
          );
          setState(() {
            _bulkItems = List.of(_bulkItems);
            _bulkItems[currentIndex] = {
              ..._bulkItems[currentIndex],
              'status': 'done',
              'data': response,
              'bytes': null,
            };
          });
        } catch (_) {
          setState(() {
            _bulkItems = List.of(_bulkItems);
            _bulkItems[currentIndex] = {
              ..._bulkItems[currentIndex],
              'status': 'error',
              'bytes': null,
            };
          });
        }
      }
    } finally {
      if (mounted) setState(() => _isBulkProcessing = false);
    }
  }

  Future<void> _confirmSingleBulkToPending(int index) async {
    final Map<String, dynamic> item = _bulkItems[index];
    final Map<String, dynamic>? data = (item['data'] as Map?)
        ?.cast<String, dynamic>();
    if (data == null) return;
    final id = await _pendingService.saveDraft(data);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Saved to Pending (' + (item['name']?.toString() ?? 'File') + ')',
        ),
        backgroundColor: const Color(0xFF059669),
      ),
    );
    setState(() {
      _bulkItems = List.of(_bulkItems);
      _bulkItems.removeAt(index);
    });
    await _loadPendingDrafts();
  }

  Future<void> _confirmAllBulkToPending() async {
    final ready = _bulkItems
        .map((e) => (e['data'] as Map?)?.cast<String, dynamic>())
        .whereType<Map<String, dynamic>>()
        .toList();
    for (final d in ready) {
      await _pendingService.saveDraft(d);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('All ready items saved to Pending'),
        backgroundColor: Color(0xFF059669),
      ),
    );
    setState(() => _bulkItems = const []);
    await _loadPendingDrafts();
  }

  // Chat tab - combines users and conversations
  final UsersService _usersService = UsersService();
  final ChatService _chatService = ChatService();
  final TextEditingController _userSearchCtrl = TextEditingController();
  List<Map<String, dynamic>> _users = const [];
  List<Conversation> _conversations = <Conversation>[];
  String? _usersNextCursor;
  bool _isUsersLoading = false;
  bool _isConversationsLoading = false;
  Set<String> _favoriteUsers = {};
  String? _selectedRole;
  String _peopleFilter = 'all'; // 'all', 'with_chat', 'no_chat'

  // Get role options dynamically from loaded roles
  List<String> get _favoriteRoleOptions {
    final roles = _roles ?? [];
    return roles
        .map((r) => (r['name'] ?? '').toString())
        .where((name) => name.isNotEmpty)
        .toList();
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _favoriteUsers = prefs.getStringList('favorite_users')?.toSet() ?? {};
    });
  }

  Future<void> _saveFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('favorite_users', _favoriteUsers.toList());
  }

  void _toggleFavorite(String userId, String role) async {
    final key = '$userId:$role';
    setState(() {
      if (_favoriteUsers.contains(key)) {
        _favoriteUsers.remove(key);
      } else {
        _favoriteUsers.add(key);
      }
    });
    await _saveFavorites();
  }

  bool _isFavorite(String userId, String? role) {
    if (role == null) return false;
    return _favoriteUsers.contains('$userId:$role');
  }

  List<Map<String, dynamic>> get _filteredUsers {
    if (_selectedRole == null) {
      return _users;
    }
    return _users.where((u) {
      final userId = '${u['provider']}:${u['subject']}';
      return _isFavorite(userId, _selectedRole);
    }).toList();
  }

  Future<void> _loadFirstUsersPage() async {
    setState(() {
      _isUsersLoading = true;
      _users = const [];
      _usersNextCursor = null;
    });
    try {
      final res = await _usersService.fetchUsers(
        q: _userSearchCtrl.text.trim(),
        limit: 20,
      );
      final items =
          (res['items'] as List?)?.whereType<Map<String, dynamic>>().toList() ??
          const [];
      setState(() {
        _users = items;
        _usersNextCursor = res['nextCursor']?.toString();
        _isUsersLoading = false;
      });
    } catch (e) {
      setState(() {
        _isUsersLoading = false;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load users: $e'),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    }
  }

  Future<void> _loadMoreUsers() async {
    if (_usersNextCursor == null || _isUsersLoading) return;
    setState(() => _isUsersLoading = true);
    try {
      final res = await _usersService.fetchUsers(
        q: _userSearchCtrl.text.trim(),
        cursor: _usersNextCursor,
        limit: 20,
      );
      final items =
          (res['items'] as List?)?.whereType<Map<String, dynamic>>().toList() ??
          const [];
      setState(() {
        _users = [..._users, ...items];
        _usersNextCursor = res['nextCursor']?.toString();
        _isUsersLoading = false;
      });
    } catch (e) {
      setState(() => _isUsersLoading = false);
    }
  }

  // Load conversations for People tab
  Future<void> _loadConversations() async {
    try {
      setState(() => _isConversationsLoading = true);
      final conversations = await _chatService.fetchConversations();
      setState(() {
        _conversations = conversations;
        _isConversationsLoading = false;
      });
    } catch (e) {
      setState(() => _isConversationsLoading = false);
    }
  }

  // Build Chat slivers (merged Users + Chat)
  List<Widget> _buildChatSlivers() {
    return [
      SliverPersistentHeader(
        pinned: true,
        delegate: PinnedHeaderDelegate(
          height: 170.0,
          safeAreaPadding: MediaQuery.of(context).padding.top,
          child: Material(
            color: const Color(0xFFF8FAFC),
            elevation: 0,
            child: Column(
              children: [
                // Search bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _userSearchCtrl,
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.search),
                            hintText: 'Search people...',
                            border: OutlineInputBorder(),
                          ),
                          onSubmitted: (_) => _loadFirstUsersPage(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () {
                          _loadFirstUsersPage();
                          _loadConversations();
                        },
                        icon: const Icon(Icons.refresh),
                        tooltip: 'Refresh',
                      ),
                    ],
                  ),
                ),
                // Filter chips
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    children: [
                      ChoiceChip(
                        label: const Text('All'),
                        selected: _peopleFilter == 'all',
                        onSelected: (selected) {
                          if (selected) setState(() => _peopleFilter = 'all');
                        },
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('With Messages'),
                        selected: _peopleFilter == 'with_chat',
                        onSelected: (selected) {
                          if (selected) setState(() => _peopleFilter = 'with_chat');
                        },
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('No Messages'),
                        selected: _peopleFilter == 'no_chat',
                        onSelected: (selected) {
                          if (selected) setState(() => _peopleFilter = 'no_chat');
                        },
                      ),
                    ],
                  ),
                ),
                // Role filter dropdown
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    children: [
                      const Text('Filter by role: '),
                      const SizedBox(width: 8),
                      DropdownButton<String?>(
                        value: _selectedRole,
                        hint: const Text('All roles'),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('All roles'),
                          ),
                          ..._favoriteRoleOptions.map((role) {
                            return DropdownMenuItem<String?>(
                              value: role,
                              child: Text(role),
                            );
                          }),
                        ],
                        onChanged: (value) {
                          setState(() => _selectedRole = value);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      SliverFillRemaining(child: _buildChatContent()),
    ];
  }

  Widget _buildChatContent() {
    // Combine conversations and users intelligently
    final conversationUserKeys = _conversations
        .map((c) => c.userKey ?? c.managerId ?? '')
        .where((key) => key.isNotEmpty)
        .toSet();

    // Filter users to exclude those with conversations (no duplicates)
    List<Map<String, dynamic>> displayUsers = [];
    if (_peopleFilter == 'all' || _peopleFilter == 'no_chat') {
      displayUsers = _filteredUsers.where((u) {
        final userKey = '${u['provider']}:${u['subject']}';
        // Always exclude users who have conversations
        if (conversationUserKeys.contains(userKey)) {
          return false;
        }
        if (_peopleFilter == 'no_chat') {
          return true; // Already excluded conversation users above
        }
        return _peopleFilter == 'all';
      }).toList();
    }

    final showConversations = _peopleFilter == 'with_chat' || _peopleFilter == 'all';
    final conversationsCount = showConversations ? _conversations.length : 0;

    // Calculate item count: header(s) + conversations + users + load more
    int itemCount = 0;
    if (conversationsCount > 0) itemCount += 1 + conversationsCount; // header + conversations
    if (displayUsers.isNotEmpty) itemCount += 1 + displayUsers.length; // header + users
    itemCount += 1; // load more button

    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.pixels >= n.metrics.maxScrollExtent - 200) {
          _loadMoreUsers();
        }
        return false;
      },
      child: ListView.builder(
        itemCount: itemCount,
        itemBuilder: (ctx, idx) {
          int currentIdx = idx;

          // Conversations section
          if (conversationsCount > 0) {
            if (currentIdx == 0) {
              return _buildSectionHeader('Messages', conversationsCount);
            }
            currentIdx--;

            if (currentIdx < conversationsCount) {
              return _buildConversationTile(_conversations[currentIdx]);
            }
            currentIdx -= conversationsCount;
          }

          // Users section
          if (displayUsers.isNotEmpty) {
            if (currentIdx == 0) {
              return _buildSectionHeader('All Users', displayUsers.length);
            }
            currentIdx--;

            if (currentIdx < displayUsers.length) {
              return _buildUserTile(displayUsers[currentIdx]);
            }
            currentIdx -= displayUsers.length;
          }

          // Load more button
          if (_isUsersLoading) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (_usersNextCursor != null) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: TextButton(
                  onPressed: _loadMoreUsers,
                  child: const Text('Load more'),
                ),
              ),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title, int count) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      color: const Color(0xFFF8FAFC),
      child: Text(
        '$title ($count)',
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Color(0xFF6B7280),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildConversationTile(Conversation conversation) {
    return ListTile(
      leading: CircleAvatar(
        backgroundImage: conversation.displayPicture != null
            ? NetworkImage(conversation.displayPicture!)
            : null,
        child: conversation.displayPicture == null
            ? const Icon(Icons.person)
            : null,
      ),
      title: Text(conversation.displayName),
      subtitle: Text(
        conversation.lastMessagePreview ?? '',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: conversation.lastMessageAt != null
          ? Text(
              _formatTimeAgo(conversation.lastMessageAt!),
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            )
          : null,
      onTap: () {
        Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (_) => ChatScreen(
              targetId: conversation.userKey ?? conversation.managerId!,
              targetName: conversation.displayName,
              targetPicture: conversation.displayPicture,
              conversationId: conversation.id,
            ),
          ),
        ).then((_) => _loadConversations());
      },
    );
  }

  Widget _buildUserTile(Map<String, dynamic> u) {
    final userId = '${u['provider']}:${u['subject']}';
    final name = u['name']?.toString() ?? '';
    final email = u['email']?.toString() ?? '';
    final picture = u['picture']?.toString();
    final roles = (u['roles'] as List?)?.whereType<String>().toList() ?? const [];

    return ListTile(
      leading: CircleAvatar(
        backgroundImage: picture != null ? NetworkImage(picture) : null,
        child: picture == null ? const Icon(Icons.person) : null,
      ),
      title: Text(name.isNotEmpty ? name : email),
      subtitle: Text(
        roles.isNotEmpty ? roles.join(', ') : email,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Favorite button (if role selected)
          if (_selectedRole != null)
            IconButton(
              icon: Icon(
                _isFavorite(userId, _selectedRole)
                    ? Icons.star
                    : Icons.star_border,
                color: _isFavorite(userId, _selectedRole)
                    ? Colors.amber
                    : null,
              ),
              onPressed: () => _toggleFavorite(userId, _selectedRole!),
              tooltip: _isFavorite(userId, _selectedRole)
                  ? 'Remove from $_selectedRole favorites'
                  : 'Add to $_selectedRole favorites',
            ),
          // More options menu
          PopupMenuButton<String>(
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'view',
                child: ListTile(
                  leading: Icon(Icons.event),
                  title: Text('View Events'),
                ),
              ),
              ...(_selectedRole == null
                      ? _favoriteRoleOptions
                      : [_selectedRole!])
                  .map(
                    (role) => PopupMenuItem(
                      value: 'favorite:$role',
                      child: ListTile(
                        leading: Icon(
                          _isFavorite(userId, role)
                              ? Icons.star
                              : Icons.star_border,
                          color: _isFavorite(userId, role)
                              ? Colors.amber
                              : null,
                        ),
                        title: Text(
                          '${_isFavorite(userId, role) ? 'Remove from' : 'Add to'} $role favorites',
                        ),
                      ),
                    ),
                  ),
            ],
            onSelected: (value) {
              if (value == 'view') {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => UserEventsScreen(user: u),
                  ),
                );
              } else if (value.startsWith('favorite:')) {
                final role = value.substring('favorite:'.length);
                _toggleFavorite(userId, role);
              }
            },
          ),
        ],
      ),
      onTap: () {
        Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (_) => ChatScreen(
              targetId: userId,
              targetName: name.isNotEmpty ? name : email,
              targetPicture: picture,
            ),
          ),
        ).then((_) => _loadConversations());
      },
    );
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  Widget _buildUsersTab() {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _userSearchCtrl,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search),
                          hintText: 'Search name or email',
                          border: OutlineInputBorder(),
                        ),
                        onSubmitted: (_) => _loadFirstUsersPage(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _loadFirstUsersPage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      icon: const Icon(Icons.search),
                      label: const Text('Search'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      FilterChip(
                        selected: _selectedRole == null,
                        label: const Text('All'),
                        onSelected: (selected) {
                          setState(() => _selectedRole = null);
                        },
                      ),
                      const SizedBox(width: 8),
                      ..._favoriteRoleOptions.map(
                        (role) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            selected: _selectedRole == role,
                            label: Text(role),
                            onSelected: (selected) {
                              setState(
                                () => _selectedRole = selected ? role : null,
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: _buildUsersContent()),
        ],
      ),
    );
  }

  Widget _buildUsersContent() {
    return _filteredUsers.isEmpty && _selectedRole != null && !_isUsersLoading
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.star_border, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text(
                  'No favorite $_selectedRole yet',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Star users to add them to this list',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                ),
              ],
            ),
          )
        : NotificationListener<ScrollNotification>(
            onNotification: (n) {
              if (n.metrics.pixels >= n.metrics.maxScrollExtent - 200) {
                _loadMoreUsers();
              }
              return false;
            },
            child: ListView.builder(
              itemCount: _filteredUsers.length + 1,
              itemBuilder: (ctx, idx) {
                if (idx == _filteredUsers.length) {
                  if (_isUsersLoading) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (_usersNextCursor == null) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: TextButton(
                        onPressed: _loadMoreUsers,
                        child: const Text('Load more'),
                      ),
                    ),
                  );
                }
                final u = _filteredUsers[idx];
                final userId = '${u['provider']}:${u['subject']}';
                final name = u['name']?.toString() ?? '';
                final email = u['email']?.toString() ?? '';
                final appId = u['app_id']?.toString() ?? '';
                final firstName = u['first_name']?.toString() ?? '';
                final lastName = u['last_name']?.toString() ?? '';
                final displayName = [
                  firstName,
                  lastName,
                ].where((s) => s.isNotEmpty).join(' ');
                final picture = u['picture']?.toString();

                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: picture != null
                        ? NetworkImage(picture)
                        : null,
                    child: picture == null ? const Icon(Icons.person) : null,
                  ),
                  title: Text(
                    displayName.isNotEmpty
                        ? displayName
                        : (name.isNotEmpty ? name : email),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (email.isNotEmpty) Text(email),
                      if (appId.isNotEmpty)
                        Text(
                          'ID: $appId',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_selectedRole != null)
                        IconButton(
                          icon: Icon(
                            _isFavorite(userId, _selectedRole)
                                ? Icons.star
                                : Icons.star_border,
                            color: _isFavorite(userId, _selectedRole)
                                ? Colors.amber
                                : null,
                          ),
                          onPressed: () =>
                              _toggleFavorite(userId, _selectedRole!),
                          tooltip: _isFavorite(userId, _selectedRole)
                              ? 'Remove from $_selectedRole favorites'
                              : 'Add to $_selectedRole favorites',
                        ),
                      PopupMenuButton<String>(
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'view',
                            child: ListTile(
                              leading: Icon(Icons.event),
                              title: Text('View events'),
                            ),
                          ),
                          ...(_selectedRole == null
                                  ? _favoriteRoleOptions
                                  : [_selectedRole!])
                              .map(
                                (role) => PopupMenuItem(
                                  value: 'favorite:$role',
                                  child: ListTile(
                                    leading: Icon(
                                      _isFavorite(userId, role)
                                          ? Icons.star
                                          : Icons.star_border,
                                      color: _isFavorite(userId, role)
                                          ? Colors.amber
                                          : null,
                                    ),
                                    title: Text(
                                      '${_isFavorite(userId, role) ? 'Remove from' : 'Add to'} $role favorites',
                                    ),
                                  ),
                                ),
                              ),
                        ],
                        onSelected: (value) async {
                          if (value == 'view') {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => UserEventsScreen(user: u),
                              ),
                            );
                          } else if (value.startsWith('favorite:')) {
                            final role = value.substring('favorite:'.length);
                            _toggleFavorite(userId, role);
                          }
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          );
  }

  Widget _buildUploadTab() {
    return SingleChildScrollView(
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              HeaderCard(
                title: AppLocalizations.of(context)!.jobDataExtractor,
                subtitle: AppLocalizations.of(context)!.uploadPdfToExtract,
                icon: Icons.auto_awesome,
                gradientColors: const [Color(0xFF6366F1), Color(0xFF8B5CF6)],
              ),
              const SizedBox(height: 24),
              ActionCard(
                title: 'Upload Document',
                description:
                    'Select a PDF or image file to extract event details automatically using AI',
                icon: Icons.upload_file,
                actionText: isLoading ? 'Processing...' : 'Choose File',
                onPressed: _pickAndProcessFile,
                isLoading: isLoading,
                color: const Color(0xFF6366F1),
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
                        color: Colors.black.withOpacity(0.05),
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
              // Hide extracted text preview in Upload flow
              if (structuredData != null) ...[
                InfoCard(
                  title: AppLocalizations.of(context)!.jobDetails,
                  icon: Icons.event_note,
                  child: _buildEventDetails(structuredData!),
                ),
                const SizedBox(height: 12),
                // Allow quick adjustments for date and time before saving
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200, width: 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Adjust Date & Time',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _pickDateForUpload,
                            icon: const Icon(Icons.calendar_today, size: 16),
                            label: Text(
                              _dateController.text.isNotEmpty
                                  ? _dateController.text
                                  : (structuredData!['date']?.toString() ??
                                        'Pick date'),
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => _pickTimeForUpload(isStart: true),
                            icon: const Icon(Icons.access_time, size: 16),
                            label: Text(
                              _startTimeController.text.isNotEmpty
                                  ? _startTimeController.text
                                  : (structuredData!['start_time']
                                            ?.toString() ??
                                        'Start time'),
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => _pickTimeForUpload(isStart: false),
                            icon: const Icon(
                              Icons.access_time_filled,
                              size: 16,
                            ),
                            label: Text(
                              _endTimeController.text.isNotEmpty
                                  ? _endTimeController.text
                                  : (structuredData!['end_time']?.toString() ??
                                        'End time'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      // Build payload from current structured data
                      final Map<String, dynamic> payload =
                          Map<String, dynamic>.from(structuredData!);
                      // Ensure client is attached from selection if it exists
                      final selClient = _clientNameController.text.trim();
                      if (selClient.isNotEmpty) {
                        payload['client_name'] = selClient;
                      }
                      // Save to pending
                      final id = await _pendingService.saveDraft(payload);
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Saved to Pending'),
                          backgroundColor: Color(0xFF059669),
                        ),
                      );
                      await _draftService.clearDraft();
                    },
                    icon: const Icon(Icons.save, size: 18),
                    label: const Text('Save to Pending'),
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
      ),
    );
  }

  // Helpers for adjusting date/time in Upload flow
  DateTime? _parseStructuredDate() {
    final v = structuredData?["date"]?.toString();
    if (v == null || v.isEmpty) return null;
    try {
      return DateTime.parse(v);
    } catch (_) {
      return null;
    }
  }

  TimeOfDay? _parseStructuredTime(String key) {
    final v = structuredData?[key]?.toString();
    if (v == null || v.isEmpty) return null;
    final parts = v.split(':');
    if (parts.length >= 2) {
      final h = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      if (h != null && m != null) return TimeOfDay(hour: h, minute: m);
    }
    return null;
  }

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickDateForUpload() async {
    final initial = _parseStructuredDate() ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 5)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (picked != null) {
      setState(() {
        structuredData = {...?structuredData, 'date': _fmtDate(picked)};
        _selectedDate = picked;
        _dateController.text = _fmtDate(picked);
      });
      _draftService.saveDraft(structuredData!);
    }
  }

  Future<void> _pickTimeForUpload({required bool isStart}) async {
    final key = isStart ? 'start_time' : 'end_time';
    final initial = _parseStructuredTime(key) ?? TimeOfDay.now();
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked != null) {
      final formatted = picked.format(context);
      setState(() {
        structuredData = {...?structuredData, key: formatted};
        if (isStart) {
          _selectedStartTime = picked;
          _startTimeController.text = formatted;
        } else {
          _selectedEndTime = picked;
          _endTimeController.text = formatted;
        }
      });
      _draftService.saveDraft(structuredData!);
    }
  }

  TimeOfDay? _parseTimeOfDayString(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return null;
    final lower = trimmed.toLowerCase();
    final match = RegExp(r'(\d{1,2})(?::(\d{2}))?').firstMatch(lower);
    if (match == null) return null;
    int hour = int.parse(match.group(1)!);
    final int minute = int.parse(match.group(2) ?? '0');
    if (lower.contains('pm') && hour < 12) {
      hour += 12;
    } else if (lower.contains('am') && hour == 12) {
      hour = 0;
    }
    if (hour >= 0 && hour < 24 && minute >= 0 && minute < 60) {
      return TimeOfDay(hour: hour, minute: minute);
    }
    return null;
  }

  DateTime? _eventDateTime(Map<String, dynamic> event, {bool useEnd = false}) {
    final rawDate = event['date']?.toString();
    if (rawDate == null || rawDate.isEmpty) return null;
    try {
      final date = DateTime.parse(rawDate);
      final rawTime =
          (useEnd ? event['end_time'] : event['start_time'])?.toString() ?? '';
      final parsedTime = _parseTimeOfDayString(rawTime);
      if (parsedTime != null) {
        return DateTime(
          date.year,
          date.month,
          date.day,
          parsedTime.hour,
          parsedTime.minute,
        );
      }
      return date;
    } catch (_) {
      return null;
    }
  }

  int _compareEventsAscending(Map<String, dynamic> a, Map<String, dynamic> b) {
    final DateTime? aDate = _eventDateTime(a);
    final DateTime? bDate = _eventDateTime(b);
    if (aDate == null && bDate == null) {
      return (a['event_name'] ?? '').toString().compareTo(
        (b['event_name'] ?? '').toString(),
      );
    }
    if (aDate == null) return 1;
    if (bDate == null) return -1;
    final cmp = aDate.compareTo(bDate);
    if (cmp != 0) return cmp;
    return (a['event_name'] ?? '').toString().compareTo(
      (b['event_name'] ?? '').toString(),
    );
  }

  int _compareEventsDescending(Map<String, dynamic> a, Map<String, dynamic> b) {
    final DateTime? aDate = _eventDateTime(a);
    final DateTime? bDate = _eventDateTime(b);
    if (aDate == null && bDate == null) {
      return (a['event_name'] ?? '').toString().compareTo(
        (b['event_name'] ?? '').toString(),
      );
    }
    if (aDate == null) return 1;
    if (bDate == null) return -1;
    final cmp = bDate.compareTo(aDate);
    if (cmp != 0) return cmp;
    return (a['event_name'] ?? '').toString().compareTo(
      (b['event_name'] ?? '').toString(),
    );
  }

  Future<void> _loadEvents() async {
    setState(() {
      _isEventsLoading = true;
      _eventsError = null;
    });
    try {
      final items = await _eventService.fetchEvents(userKey: _viewerUserKey);
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
        _eventsUpcoming = upcoming;
        _eventsPast = past;
        _isEventsLoading = false;
      });
    } catch (e) {
      setState(() {
        _eventsError = e.toString();
        _isEventsLoading = false;
      });
    }
  }

  List<Widget> _buildEventsSlivers() {
    final List<Map<String, dynamic>> all = _events ?? const [];
    final List<Map<String, dynamic>> upcoming = _eventsUpcoming ?? const [];
    final List<Map<String, dynamic>> past = _eventsPast ?? const [];

    return [
      SliverPersistentHeader(
        pinned: true,
        delegate: PinnedHeaderDelegate(
          height: 48.0,
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                Expanded(
                  child: TabBar(
                    controller: _eventsTabController,
                    tabs: const [
                      Tab(text: 'Pending'),
                      Tab(text: 'Upcoming'),
                      Tab(text: 'Past'),
                    ],
                    labelColor: const Color(0xFF6366F1),
                    unselectedLabelColor: Colors.grey,
                  ),
                ),
                if (kIsWeb)
                  _maybeWebRefreshButton(
                    onPressed: _loadEvents,
                    label: 'Refresh',
                  ),
              ],
            ),
          ),
        ),
      ),
      SliverFillRemaining(
        child: TabBarView(
          controller: _eventsTabController,
          children: [
            _pendingInner(),
            _eventsInner(upcoming),
            _pastEventsInner(past),
          ],
        ),
      ),
    ];
  }

  List<Widget> _buildUsersSlivers() {
    return [
      SliverPersistentHeader(
        pinned: true,
        delegate: PinnedHeaderDelegate(
          height: 120.0,
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _userSearchCtrl,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search),
                          hintText: 'Search name or email',
                          border: OutlineInputBorder(),
                        ),
                        onSubmitted: (_) => _loadFirstUsersPage(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _loadFirstUsersPage,
                      icon: const Icon(Icons.refresh),
                      tooltip: 'Refresh',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      FilterChip(
                        selected: _selectedRole == null,
                        label: const Text('All'),
                        onSelected: (selected) {
                          setState(() => _selectedRole = null);
                        },
                      ),
                      const SizedBox(width: 8),
                      ..._favoriteRoleOptions.map(
                        (role) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            selected: _selectedRole == role,
                            label: Text(role),
                            onSelected: (selected) {
                              setState(
                                () => _selectedRole = selected ? role : null,
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      SliverFillRemaining(child: _buildUsersContent()),
    ];
  }

  List<Widget> _buildHoursSlivers() {
    return [SliverFillRemaining(child: const HoursApprovalListScreen())];
  }

  List<Widget> _buildCatalogSlivers() {
    return [
      SliverPersistentHeader(
        pinned: true,
        delegate: PinnedHeaderDelegate(
          height: 48.0,
          child: Container(
            color: Colors.white,
            child: TabBar(
              controller: _catalogTabController,
              tabs: const [
                Tab(text: 'Clients'),
                Tab(text: 'Roles'),
                Tab(text: 'Tariffs'),
              ],
              labelColor: Color(0xFF6366F1),
              unselectedLabelColor: Colors.grey,
            ),
          ),
        ),
      ),
      SliverFillRemaining(
        child: TabBarView(
          controller: _catalogTabController,
          children: [_buildClientsTab(), _buildRolesTab(), _buildTariffsTab()],
        ),
      ),
    ];
  }

  Widget _buildEventsTab() {
    final List<Map<String, dynamic>> all = _events ?? const [];
    final List<Map<String, dynamic>> upcoming = _eventsUpcoming ?? const [];
    final List<Map<String, dynamic>> past = _eventsPast ?? const [];
    return SafeArea(
      child: DefaultTabController(
        length: 3,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  const Expanded(
                    child: TabBar(
                      tabs: [
                        Tab(text: 'Pending'),
                        Tab(text: 'Upcoming'),
                        Tab(text: 'Past'),
                      ],
                      labelColor: Color(0xFF6366F1),
                      unselectedLabelColor: Colors.grey,
                    ),
                  ),
                  if (kIsWeb)
                    _maybeWebRefreshButton(
                      onPressed: _loadEvents,
                      label: 'Refresh',
                    ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _pendingInner(),
                  _eventsInner(upcoming),
                  _pastEventsInner(past),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pastEventsInner(List<Map<String, dynamic>> items) {
    final sortedItems = [...items]..sort(_compareEventsDescending);
    // Group past events by month
    final pastByMonth = <String, List<Map<String, dynamic>>>{};

    for (final event in sortedItems) {
      final dateStr = event['date']?.toString() ?? '';
      if (dateStr.isNotEmpty) {
        try {
          final date = DateTime.parse(dateStr);
          final monthKey =
              '${date.year}-${date.month.toString().padLeft(2, '0')}';
          pastByMonth.putIfAbsent(monthKey, () => []).add(event);
        } catch (_) {
          pastByMonth.putIfAbsent('unknown', () => []).add(event);
        }
      } else {
        pastByMonth.putIfAbsent('unknown', () => []).add(event);
      }
    }

    // Sort months in descending order (most recent first)
    final sortedMonths = pastByMonth.keys.toList()
      ..sort((a, b) {
        if (a == 'unknown') return 1;
        if (b == 'unknown') return -1;
        return b.compareTo(a);
      });

    return RefreshIndicator(
      onRefresh: _loadEvents,
      color: const Color(0xFF6366F1),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double width = constraints.maxWidth;
          int crossAxisCount = 1;
          if (width >= 1200) {
            crossAxisCount = 3;
          } else if (width >= 900) {
            crossAxisCount = 2;
          }

          if (_isEventsLoading && sortedItems.isEmpty) {
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
              if (kIsWeb)
                Align(
                  alignment: Alignment.centerRight,
                  child: _maybeWebRefreshButton(
                    onPressed: _loadEvents,
                    label: 'Refresh',
                  ),
                ),
              if (kIsWeb) const SizedBox(height: 12),
              if (_eventsError != null) ...[
                ErrorBanner(message: _eventsError!),
                const SizedBox(height: 12),
              ],
              if (!_isEventsLoading &&
                  sortedItems.isEmpty &&
                  _eventsError == null)
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey.shade100, width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                        spreadRadius: -4,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Icon(
                          Icons.event_available_outlined,
                          color: const Color(0xFF6366F1),
                          size: 48,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'No Past Events',
                        style: TextStyle(
                          color: const Color(0xFF0F172A),
                          fontWeight: FontWeight.w700,
                          fontSize: 20,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        kIsWeb
                            ? 'Click Refresh to update.'
                            : 'Pull to refresh.',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 15,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (kIsWeb)
                        _maybeWebRefreshButton(
                          onPressed: _loadEvents,
                          label: 'Refresh',
                          padding: const EdgeInsets.only(top: 12),
                        ),
                    ],
                  ),
                ),
              if (sortedItems.isNotEmpty)
                ...sortedMonths.expand((monthKey) {
                  final eventsInMonth = List<Map<String, dynamic>>.from(
                    pastByMonth[monthKey]!,
                  )..sort(_compareEventsDescending);

                  String monthLabel;
                  if (monthKey == 'unknown') {
                    monthLabel = 'Date Unknown';
                  } else {
                    try {
                      final parts = monthKey.split('-');
                      final year = int.parse(parts[0]);
                      final month = int.parse(parts[1]);

                      const monthNames = [
                        'January',
                        'February',
                        'March',
                        'April',
                        'May',
                        'June',
                        'July',
                        'August',
                        'September',
                        'October',
                        'November',
                        'December',
                      ];

                      monthLabel = '${monthNames[month - 1]} $year';
                    } catch (_) {
                      monthLabel = monthKey;
                    }
                  }

                  final header = Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 16),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.calendar_month,
                          color: Color(0xFF6B7280),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$monthLabel (${eventsInMonth.length})',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                  );

                  if (crossAxisCount > 1) {
                    return [
                      header,
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 2.5,
                        ),
                        itemCount: eventsInMonth.length,
                        itemBuilder: (context, index) =>
                            _buildEventCard(eventsInMonth[index]),
                      ),
                    ];
                  }

                  return [
                    header,
                    ...eventsInMonth.map(
                      (event) => _buildEventCard(event, showMargin: true),
                    ),
                  ];
                }),
            ],
          );
        },
      ),
    );
  }

  Widget _eventsInner(List<Map<String, dynamic>> items) {
    final sortedItems = [...items]..sort(_compareEventsAscending);
    return RefreshIndicator(
      onRefresh: _loadEvents,
      color: const Color(0xFF6366F1),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double width = constraints.maxWidth;
          int crossAxisCount = 1;
          if (width >= 1200) {
            crossAxisCount = 3;
          } else if (width >= 900) {
            crossAxisCount = 2;
          } else if (width >= 600) {
            crossAxisCount = 2;
          }

          if (_isEventsLoading && sortedItems.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              children: [
                if (kIsWeb)
                  Align(
                    alignment: Alignment.centerRight,
                    child: _maybeWebRefreshButton(
                      onPressed: _loadEvents,
                      label: 'Refresh',
                    ),
                  ),
                if (kIsWeb) const SizedBox(height: 12),
                const Center(
                  child: LoadingIndicator(text: 'Loading events...'),
                ),
              ],
            );
          }

          // Use grid layout for wider screens
          if (crossAxisCount > 1 && sortedItems.isNotEmpty) {
            return CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                if (kIsWeb)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: _maybeWebRefreshButton(
                          onPressed: _loadEvents,
                          label: 'Refresh',
                        ),
                      ),
                    ),
                  ),
                SliverPadding(
                  padding: const EdgeInsets.all(20),
                  sliver: SliverGrid(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _buildEventCard(sortedItems[index]),
                      childCount: sortedItems.length,
                    ),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 2.5,
                    ),
                  ),
                ),
              ],
            );
          }

          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            children: [
              if (kIsWeb)
                Align(
                  alignment: Alignment.centerRight,
                  child: _maybeWebRefreshButton(
                    onPressed: _loadEvents,
                    label: 'Refresh',
                  ),
                ),
              if (kIsWeb) const SizedBox(height: 12),
              if (_eventsError != null) ...[
                ErrorBanner(message: _eventsError!),
                const SizedBox(height: 12),
              ],
              if (!_isEventsLoading &&
                  sortedItems.isEmpty &&
                  _eventsError == null)
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey.shade100, width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                        spreadRadius: -4,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Icon(
                          Icons.event_available_outlined,
                          color: const Color(0xFF6366F1),
                          size: 48,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'No Events',
                        style: TextStyle(
                          color: const Color(0xFF0F172A),
                          fontWeight: FontWeight.w700,
                          fontSize: 20,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        kIsWeb
                            ? 'Click Refresh to update.'
                            : 'Pull to refresh.',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 15,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (kIsWeb)
                        _maybeWebRefreshButton(
                          onPressed: _loadEvents,
                          label: 'Refresh',
                          padding: const EdgeInsets.only(top: 12),
                        ),
                    ],
                  ),
                ),
              if (sortedItems.isNotEmpty)
                Column(
                  children: sortedItems
                      .map((item) => _buildEventCard(item, showMargin: true))
                      .toList(),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _loadPendingDrafts() async {
    setState(() {
      _isPendingLoading = true;
    });
    final items = await _pendingService.list();
    setState(() {
      _pendingDrafts = items;
      _isPendingLoading = false;
    });
  }

  Widget _pendingInner() {
    return RefreshIndicator(
      onRefresh: _loadPendingDrafts,
      color: const Color(0xFF6366F1),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          if (kIsWeb)
            Align(
              alignment: Alignment.centerRight,
              child: _maybeWebRefreshButton(
                onPressed: _loadPendingDrafts,
                label: 'Refresh drafts',
              ),
            ),
          if (kIsWeb) const SizedBox(height: 12),
          if (_isPendingLoading && _pendingDrafts.isEmpty)
            const Center(child: LoadingIndicator(text: 'Loading drafts...')),
          if (_pendingDrafts.isEmpty && !_isPendingLoading)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('No pending drafts'),
                  if (kIsWeb) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Click Refresh drafts to check again.',
                      style: TextStyle(color: Colors.grey.shade600),
                      textAlign: TextAlign.center,
                    ),
                    _maybeWebRefreshButton(
                      onPressed: _loadPendingDrafts,
                      label: 'Refresh drafts',
                      padding: const EdgeInsets.only(top: 12),
                    ),
                  ],
                ],
              ),
            ),
          ..._pendingDrafts.map((d) {
            final data =
                (d['data'] as Map?)?.cast<String, dynamic>() ??
                <String, dynamic>{};
            final client = (data['client_name'] ?? '').toString();
            final name =
                (data['event_name'] ?? data['venue_name'] ?? 'Untitled')
                    .toString();
            final date = (data['date'] ?? '').toString();
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: ListTile(
                title: Text(client.isNotEmpty ? client : 'Client'),
                subtitle: Text(
                  [
                    name,
                    date,
                  ].where((s) => s.toString().isNotEmpty).join(' • '),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                      onPressed: () async {
                        final data =
                            (d['data'] as Map?)?.cast<String, dynamic>() ??
                            <String, dynamic>{};
                        final id = (d['id'] ?? '').toString();
                        if (!mounted) return;
                        final changed = await Navigator.of(context).push<bool>(
                          MaterialPageRoute(
                            builder: (_) =>
                                PendingEditScreen(draft: data, draftId: id),
                          ),
                        );
                        if (changed == true) {
                          await _loadPendingDrafts();
                        }
                      },
                      child: const Text('Edit'),
                    ),
                    TextButton(
                      onPressed: () async {
                        final data =
                            (d['data'] as Map?)?.cast<String, dynamic>() ??
                            <String, dynamic>{};
                        final id = (d['id'] ?? '').toString();
                        if (!mounted) return;
                        final changed = await Navigator.of(context).push<bool>(
                          MaterialPageRoute(
                            builder: (_) =>
                                PendingPublishScreen(draft: data, draftId: id),
                          ),
                        );
                        if (changed == true) {
                          await _loadPendingDrafts();
                        }
                      },
                      child: const Text('Publish'),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Color(0xFFDC2626)),
                      onPressed: () async {
                        final id = (d['id'] ?? '').toString();
                        if (id.isEmpty) return;
                        await _pendingService.deleteDraft(id);
                        await _loadPendingDrafts();
                      },
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Future<void> _loadClients() async {
    setState(() {
      _isClientsLoading = true;
      _clientsError = null;
    });
    try {
      final items = await _clientsService.fetchClients();
      setState(() {
        _clients = items;
        _isClientsLoading = false;
      });
    } catch (e) {
      setState(() {
        _clientsError = e.toString();
        _isClientsLoading = false;
      });
    }
  }

  Widget _buildClientsTab() {
    final List<Map<String, dynamic>> items = _clients ?? const [];
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _loadClients,
        color: const Color(0xFF6366F1),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          children: [
            HeaderCard(
              title: 'Clients',
              subtitle: 'Manage third-party clients for quick selection',
              icon: Icons.business,
              gradientColors: const [Color(0xFF6366F1), Color(0xFF8B5CF6)],
            ),
            if (kIsWeb)
              Align(
                alignment: Alignment.centerRight,
                child: _maybeWebRefreshButton(
                  onPressed: _loadClients,
                  label: 'Refresh clients',
                  padding: const EdgeInsets.only(top: 12),
                ),
              ),
            if (kIsWeb) const SizedBox(height: 4),
            const SizedBox(height: 16),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: () async {
                    final name = await _promptNewClientName();
                    if (name == null) return;
                    try {
                      await _clientsService.createClient(name);
                      await _loadClients();
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Client created'),
                          backgroundColor: Color(0xFF059669),
                        ),
                      );
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Failed to create client: $e'),
                          backgroundColor: const Color(0xFFDC2626),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Add Client'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_isClientsLoading && items.isEmpty)
              const Center(child: LoadingIndicator(text: 'Loading clients...')),
            if (_clientsError != null) ...[
              ErrorBanner(message: _clientsError!),
              const SizedBox(height: 12),
            ],
            ...items.map((c) => _clientListTile(c)),
          ],
        ),
      ),
    );
  }

  Widget _buildCatalogTab() {
    return SafeArea(
      child: DefaultTabController(
        length: 3,
        child: Column(
          children: [
            const TabBar(
              tabs: [
                Tab(text: 'Clients'),
                Tab(text: 'Roles'),
                Tab(text: 'Tariffs'),
              ],
              labelColor: Color(0xFF6366F1),
              unselectedLabelColor: Colors.grey,
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildClientsTab(),
                  _buildRolesTab(),
                  _buildTariffsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Tariffs UI state
  final TariffsService _tariffsService = TariffsService();
  List<Map<String, dynamic>>? _tariffs;
  bool _isTariffsLoading = false;
  String? _tariffsError;
  String? _selectedClientIdForTariffs;
  String? _selectedRoleIdForTariffs;

  Future<void> _loadTariffs() async {
    setState(() {
      _isTariffsLoading = true;
      _tariffsError = null;
    });
    try {
      final items = await _tariffsService.fetchTariffs(
        clientId: _selectedClientIdForTariffs,
        roleId: _selectedRoleIdForTariffs,
      );
      setState(() {
        _tariffs = items;
        _isTariffsLoading = false;
      });
    } catch (e) {
      setState(() {
        _tariffsError = e.toString();
        _isTariffsLoading = false;
      });
    }
  }

  Widget _buildTariffsTab() {
    final clients = _clients ?? const [];
    final roles = _roles ?? const [];
    final tariffs = _tariffs ?? const [];
    final isWeb = ResponsiveLayout.shouldUseDesktopLayout(context);

    return RefreshIndicator(
      onRefresh: () async {
        await _loadClients();
        await _loadRoles();
        await _loadTariffs();
      },
      color: const Color(0xFF6366F1),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(ResponsiveLayout.getHorizontalPadding(context)),
        children: [
          // Header with create button
          Row(
            children: [
              Expanded(
                child: Text(
                  'Tariff Management',
                  style: TextStyle(
                    fontSize: isWeb ? 24 : 20,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1F2937),
                  ),
                ),
              ),
              if (kIsWeb)
                _maybeWebRefreshButton(
                  onPressed: () async {
                    await _loadClients();
                    await _loadRoles();
                    await _loadTariffs();
                  },
                  label: 'Refresh',
                  padding: const EdgeInsets.only(right: 8),
                ),
              ElevatedButton.icon(
                onPressed: () => _showCreateTariffDialog(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF059669),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(
                    horizontal: isWeb ? 24 : 16,
                    vertical: isWeb ? 16 : 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                icon: const Icon(Icons.add_circle_outline, size: 20),
                label: Text(
                  isWeb ? 'Create Tariff' : 'Create',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Filter card
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE5E7EB)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            padding: EdgeInsets.all(isWeb ? 24 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.filter_list,
                        color: Color(0xFF6366F1),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Filter Tariffs',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1F2937),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Filter by client or role to narrow results',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_selectedClientIdForTariffs != null ||
                        _selectedRoleIdForTariffs != null)
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _selectedClientIdForTariffs = null;
                            _selectedRoleIdForTariffs = null;
                          });
                          _loadTariffs();
                        },
                        icon: const Icon(Icons.clear, size: 16),
                        label: const Text('Clear'),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFFDC2626),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),

                // Responsive layout for filters
                isWeb
                    ? Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _selectedClientIdForTariffs,
                              hint: const Text('All Clients'),
                              items: [
                                const DropdownMenuItem(
                                  value: null,
                                  child: Text('All Clients'),
                                ),
                                ...clients.map(
                                  (c) => DropdownMenuItem(
                                    value: (c['id'] ?? '').toString(),
                                    child: Text(
                                      (c['name'] ?? '').toString(),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ],
                              onChanged: (v) {
                                setState(() => _selectedClientIdForTariffs = v);
                                _loadTariffs();
                              },
                              decoration: InputDecoration(
                                labelText: 'Filter by Client',
                                prefixIcon: const Icon(
                                  Icons.business,
                                  size: 20,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                filled: true,
                                fillColor: const Color(0xFFF9FAFB),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 16,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _selectedRoleIdForTariffs,
                              hint: const Text('All Roles'),
                              items: [
                                const DropdownMenuItem(
                                  value: null,
                                  child: Text('All Roles'),
                                ),
                                ...roles.map(
                                  (r) => DropdownMenuItem(
                                    value: (r['id'] ?? '').toString(),
                                    child: Text(
                                      (r['name'] ?? '').toString(),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ],
                              onChanged: (v) {
                                setState(() => _selectedRoleIdForTariffs = v);
                                _loadTariffs();
                              },
                              decoration: InputDecoration(
                                labelText: 'Filter by Role',
                                prefixIcon: const Icon(
                                  Icons.work_outline,
                                  size: 20,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                filled: true,
                                fillColor: const Color(0xFFF9FAFB),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 16,
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    : Column(
                        children: [
                          DropdownButtonFormField<String>(
                            value: _selectedClientIdForTariffs,
                            hint: const Text('All Clients'),
                            items: [
                              const DropdownMenuItem(
                                value: null,
                                child: Text('All Clients'),
                              ),
                              ...clients.map(
                                (c) => DropdownMenuItem(
                                  value: (c['id'] ?? '').toString(),
                                  child: Text(
                                    (c['name'] ?? '').toString(),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ],
                            onChanged: (v) {
                              setState(() => _selectedClientIdForTariffs = v);
                              _loadTariffs();
                            },
                            decoration: InputDecoration(
                              labelText: 'Filter by Client',
                              prefixIcon: const Icon(Icons.business, size: 20),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: const Color(0xFFF9FAFB),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            value: _selectedRoleIdForTariffs,
                            hint: const Text('All Roles'),
                            items: [
                              const DropdownMenuItem(
                                value: null,
                                child: Text('All Roles'),
                              ),
                              ...roles.map(
                                (r) => DropdownMenuItem(
                                  value: (r['id'] ?? '').toString(),
                                  child: Text(
                                    (r['name'] ?? '').toString(),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ],
                            onChanged: (v) {
                              setState(() => _selectedRoleIdForTariffs = v);
                              _loadTariffs();
                            },
                            decoration: InputDecoration(
                              labelText: 'Filter by Role',
                              prefixIcon: const Icon(
                                Icons.work_outline,
                                size: 20,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: const Color(0xFFF9FAFB),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Loading & Error states
          if (_isTariffsLoading && tariffs.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(48.0),
                child: LoadingIndicator(text: 'Loading tariffs...'),
              ),
            ),
          if (_tariffsError != null) ...[
            ErrorBanner(message: _tariffsError!),
            const SizedBox(height: 12),
          ],

          // Tariffs list header with count
          if (!_isTariffsLoading && tariffs.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${tariffs.length} Tariff${tariffs.length != 1 ? 's' : ''}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF6366F1),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Empty state
          if (!_isTariffsLoading && tariffs.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(48.0),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.attach_money,
                        size: 64,
                        color: Color(0xFF9CA3AF),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No tariffs found',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _selectedClientIdForTariffs != null ||
                              _selectedRoleIdForTariffs != null
                          ? 'Try adjusting your filters or create a new tariff'
                          : 'Create your first tariff to get started',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),

          // Tariffs grid/list (responsive)
          if (tariffs.isNotEmpty)
            isWeb
                ? GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: ResponsiveLayout.getGridColumns(context),
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 2.5,
                    ),
                    itemCount: tariffs.length,
                    itemBuilder: (context, index) =>
                        _tariffTile(tariffs[index]),
                  )
                : Column(children: tariffs.map((t) => _tariffTile(t)).toList()),
        ],
      ),
    );
  }

  Widget _tariffTile(Map<String, dynamic> t) {
    final id = (t['id'] ?? '').toString();
    final clientId = (t['clientId'] ?? '').toString();
    final roleId = (t['roleId'] ?? '').toString();
    final roleName = (_roles ?? [])
        .firstWhere(
          (r) => (r['id'] ?? '') == roleId,
          orElse: () => const {},
        )['name']
        ?.toString();
    final clientName = (_clients ?? [])
        .firstWhere(
          (c) => (c['id'] ?? '') == clientId,
          orElse: () => const {},
        )['name']
        ?.toString();
    final rate = (t['rate'] ?? 0).toString();
    final currency = (t['currency'] ?? 'USD').toString();
    final isWeb = ResponsiveLayout.shouldUseDesktopLayout(context);

    return Container(
      margin: EdgeInsets.only(bottom: isWeb ? 0 : 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(isWeb ? 20 : 16),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(isWeb ? 12 : 10),
              decoration: BoxDecoration(
                color: const Color(0xFF059669).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.attach_money,
                color: const Color(0xFF059669),
                size: isWeb ? 28 : 24,
              ),
            ),
            SizedBox(width: isWeb ? 20 : 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$clientName',
                    style: TextStyle(
                      fontSize: isWeb ? 17 : 16,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1F2937),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.work_outline,
                        size: 14,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          roleName ?? 'Unknown Role',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '\$$rate $currency/hr',
                      style: TextStyle(
                        fontSize: isWeb ? 15 : 14,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF6366F1),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: isWeb ? 12 : 8),
            // Edit button
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              color: const Color(0xFF6366F1),
              iconSize: isWeb ? 24 : 22,
              tooltip: 'Edit tariff',
              onPressed: () => _showEditTariffDialog(
                tariffId: id,
                clientId: clientId,
                roleId: roleId,
                currentRate: double.tryParse(rate) ?? 0.0,
              ),
            ),
            // Delete button
            IconButton(
              icon: const Icon(Icons.delete_outline),
              color: const Color(0xFFDC2626),
              iconSize: isWeb ? 24 : 22,
              tooltip: 'Delete tariff',
              onPressed: () => _confirmDeleteTariff(id),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCreateTariffDialog() async {
    final clients = _clients ?? const [];
    final roles = _roles ?? const [];

    if (clients.isEmpty || roles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add clients and roles first'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    String? selectedClientId;
    String? selectedRoleId;
    final rateController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF059669).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.add_circle_outline,
                  color: Color(0xFF059669),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Text('Create Tariff'),
            ],
          ),
          content: SizedBox(
            width: ResponsiveLayout.shouldUseDesktopLayout(context)
                ? 500
                : double.maxFinite,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Client dropdown
                  DropdownButtonFormField<String>(
                    value: selectedClientId,
                    decoration: InputDecoration(
                      labelText: 'Client *',
                      prefixIcon: const Icon(Icons.business, size: 20),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF9FAFB),
                    ),
                    items: clients
                        .map(
                          (c) => DropdownMenuItem(
                            value: (c['id'] ?? '').toString(),
                            child: Text((c['name'] ?? '').toString()),
                          ),
                        )
                        .toList(),
                    onChanged: (v) =>
                        setDialogState(() => selectedClientId = v),
                    validator: (v) => v == null ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  // Role dropdown
                  DropdownButtonFormField<String>(
                    value: selectedRoleId,
                    decoration: InputDecoration(
                      labelText: 'Role *',
                      prefixIcon: const Icon(Icons.work_outline, size: 20),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF9FAFB),
                    ),
                    items: roles
                        .map(
                          (r) => DropdownMenuItem(
                            value: (r['id'] ?? '').toString(),
                            child: Text((r['name'] ?? '').toString()),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setDialogState(() => selectedRoleId = v),
                    validator: (v) => v == null ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  // Rate field
                  TextFormField(
                    controller: rateController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Hourly Rate *',
                      prefixIcon: const Icon(Icons.attach_money, size: 20),
                      hintText: 'e.g., 25.00',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF9FAFB),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Required';
                      if (double.tryParse(v) == null) return 'Invalid number';
                      if (double.parse(v) <= 0) return 'Must be positive';
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                if (formKey.currentState?.validate() ?? false) {
                  Navigator.of(ctx).pop(true);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.check, size: 20),
              label: const Text('Create'),
            ),
          ],
        ),
      ),
    );

    final clientId = selectedClientId;
    final roleId = selectedRoleId;
    if (result == true && clientId != null && roleId != null) {
      final rate = double.tryParse(rateController.text);
      if (rate == null) return;

      try {
        await _tariffsService.upsertTariff(
          clientId: clientId,
          roleId: roleId,
          rate: rate,
        );
        await _loadTariffs();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tariff created successfully'),
            backgroundColor: Color(0xFF059669),
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create tariff: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  Future<void> _showEditTariffDialog({
    required String tariffId,
    required String clientId,
    required String roleId,
    required double currentRate,
  }) async {
    final clients = _clients ?? const [];
    final roles = _roles ?? const [];

    final clientName =
        clients
            .firstWhere(
              (c) => (c['id'] ?? '') == clientId,
              orElse: () => const {},
            )['name']
            ?.toString() ??
        'Unknown';

    final roleName =
        roles
            .firstWhere(
              (r) => (r['id'] ?? '') == roleId,
              orElse: () => const {},
            )['name']
            ?.toString() ??
        'Unknown';

    final rateController = TextEditingController(text: currentRate.toString());
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.edit_outlined,
                color: Color(0xFF6366F1),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(child: Text('Edit Tariff')),
          ],
        ),
        content: SizedBox(
          width: ResponsiveLayout.shouldUseDesktopLayout(context)
              ? 500
              : double.maxFinite,
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Display client and role (read-only)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.business,
                            size: 18,
                            color: Color(0xFF6B7280),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              clientName,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1F2937),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.work_outline,
                            size: 18,
                            color: Color(0xFF6B7280),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              roleName,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1F2937),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Rate field
                TextFormField(
                  controller: rateController,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Hourly Rate *',
                    prefixIcon: const Icon(Icons.attach_money, size: 20),
                    hintText: 'e.g., 25.00',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Required';
                    if (double.tryParse(v) == null) return 'Invalid number';
                    if (double.parse(v) <= 0) return 'Must be positive';
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.of(ctx).pop(true);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.check, size: 20),
            label: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == true) {
      final rate = double.tryParse(rateController.text);
      if (rate == null) return;

      try {
        await _tariffsService.upsertTariff(
          clientId: clientId,
          roleId: roleId,
          rate: rate,
        );
        await _loadTariffs();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tariff updated successfully'),
            backgroundColor: Color(0xFF059669),
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update tariff: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  Future<void> _confirmDeleteTariff(String tariffId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFDC2626).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.warning_outlined,
                color: Color(0xFFDC2626),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Text('Delete Tariff'),
          ],
        ),
        content: const Text(
          'Are you sure you want to delete this tariff? This action cannot be undone.',
          style: TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.delete_outline, size: 20),
            label: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _tariffsService.deleteTariff(tariffId);
        await _loadTariffs();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tariff deleted successfully'),
            backgroundColor: Color(0xFF059669),
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete tariff: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  Future<double?> _promptRate() async {
    final controller = TextEditingController();
    final str = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Set rate'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Rate (e.g., 25.00)'),
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
      ),
    );
    if (str == null) return null;
    return double.tryParse(str);
  }

  // Roles UI (similar to Clients)
  List<Map<String, dynamic>>? _roles;
  bool _isRolesLoading = false;
  String? _rolesError;

  Future<void> _loadRoles() async {
    setState(() {
      _isRolesLoading = true;
      _rolesError = null;
    });
    try {
      final items = await _rolesService.fetchRoles();
      setState(() {
        _roles = items;
        _isRolesLoading = false;
      });
    } catch (e) {
      setState(() {
        _rolesError = e.toString();
        _isRolesLoading = false;
      });
    }
  }

  Widget _buildRolesTab() {
    final items = _roles ?? const [];
    return RefreshIndicator(
      onRefresh: _loadRoles,
      color: const Color(0xFF6366F1),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          if (kIsWeb)
            Align(
              alignment: Alignment.centerRight,
              child: _maybeWebRefreshButton(
                onPressed: _loadRoles,
                label: 'Refresh roles',
                padding: const EdgeInsets.only(bottom: 12),
              ),
            ),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: () async {
                  final name = await _promptNewNamedItem(
                    'New Role',
                    'Role name',
                  );
                  if (name == null) return;
                  try {
                    await _rolesService.createRole(name);
                    await _loadRoles();
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to create role: $e'),
                        backgroundColor: const Color(0xFFDC2626),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.add),
                label: const Text('Add Role'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_isRolesLoading && items.isEmpty)
            const Center(child: LoadingIndicator(text: 'Loading roles...')),
          if (_rolesError != null) ...[
            ErrorBanner(message: _rolesError!),
            const SizedBox(height: 12),
          ],
          ...items.map((r) => _roleListTile(r)),
        ],
      ),
    );
  }

  Widget _roleListTile(Map<String, dynamic> role) {
    final String id = (role['id'] ?? '').toString();
    final String name = (role['name'] ?? '').toString();
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200, width: 1),
      ),
      child: ListTile(
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
        leading: const Icon(Icons.assignment_ind, color: Color(0xFF6366F1)),
        trailing: PopupMenuButton<String>(
          onSelected: (value) async {
            if (value == 'rename') {
              final newName = await _promptNewNamedItem(
                'Rename Role',
                'Role name',
                initial: name,
              );
              if (newName == null) return;
              try {
                await _rolesService.renameRole(id, newName);
                await _loadRoles();
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to rename: $e'),
                    backgroundColor: const Color(0xFFDC2626),
                  ),
                );
              }
            } else if (value == 'delete') {
              final ok = await _confirmDeleteClient(name);
              if (ok != true) return;
              try {
                await _rolesService.deleteRole(id);
                await _loadRoles();
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to delete: $e'),
                    backgroundColor: const Color(0xFFDC2626),
                  ),
                );
              }
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem(value: 'rename', child: Text('Rename')),
            PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        ),
      ),
    );
  }

  Future<String?> _promptNewNamedItem(
    String title,
    String label, {
    String? initial,
  }) async {
    final controller = TextEditingController(text: initial ?? '');
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(labelText: label),
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
      ),
    );
  }

  Widget _clientListTile(Map<String, dynamic> client) {
    final String id = (client['id'] ?? '').toString();
    final String name = (client['name'] ?? '').toString();
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200, width: 1),
      ),
      child: ListTile(
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
        leading: const Icon(Icons.business, color: Color(0xFF6366F1)),
        trailing: PopupMenuButton<String>(
          onSelected: (value) async {
            if (value == 'rename') {
              final newName = await _promptRenameClient(name);
              if (newName == null) return;
              try {
                await _clientsService.renameClient(id, newName);
                await _loadClients();
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to rename: $e'),
                    backgroundColor: const Color(0xFFDC2626),
                  ),
                );
              }
            } else if (value == 'delete') {
              final ok = await _confirmDeleteClient(name);
              if (ok != true) return;
              try {
                await _clientsService.deleteClient(id);
                await _loadClients();
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to delete: $e'),
                    backgroundColor: const Color(0xFFDC2626),
                  ),
                );
              }
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem(value: 'rename', child: Text('Rename')),
            PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        ),
      ),
    );
  }

  Future<String?> _promptNewClientName() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Client'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Client name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  Future<String?> _promptRenameClient(String current) async {
    final controller = TextEditingController(text: current);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Client'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Client name'),
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
      ),
    );
  }

  Future<bool?> _confirmDeleteClient(String name) async {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Client?'),
        content: Text("Are you sure you want to delete '$name' ?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _openGoogleMaps(String address, String googleMapsUrl) async {
    // Prefer the google_maps_url if available (has place_id), otherwise use address
    final String urlString = googleMapsUrl.isNotEmpty
        ? googleMapsUrl
        : 'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(address)}';

    final Uri url = Uri.parse(urlString);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open Google Maps')),
        );
      }
    }
  }

  Future<void> _shareEvent(Map<String, dynamic> event) async {
    final String clientName = (event['client_name'] ?? 'Client').toString();
    final String venueName = (event['venue_name'] ?? AppLocalizations.of(context)!.location).toString();
    final String date = (event['date'] ?? '').toString();
    final String time = (event['start_time'] ?? '').toString();

    String shareText = AppLocalizations.of(context)!.shareJobPrefix(clientName);
    shareText += '\n${AppLocalizations.of(context)!.location}: $venueName\n';
    if (date.isNotEmpty) shareText += '${AppLocalizations.of(context)!.date}: $date\n';
    if (time.isNotEmpty) shareText += '${AppLocalizations.of(context)!.time}: $time';

    await Clipboard.setData(ClipboardData(text: shareText));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.jobDetailsCopied)),
      );
    }
  }

  Widget _buildEventCard(Map<String, dynamic> e, {bool showMargin = false}) {
    // Extract essential data
    final String clientName = (e['client_name'] ?? 'Client').toString();
    final String venueName = (e['venue_name'] ?? AppLocalizations.of(context)!.locationTbd).toString();
    final String venueAddress = (e['venue_address'] ?? '').toString();
    final String googleMapsUrl = (e['google_maps_url'] ?? '').toString();

    String dateStr = '';
    String displayDate = '';
    bool isUpcoming = false;
    final dynamic rawDate = e['date'];
    if (rawDate is String && rawDate.isNotEmpty) {
      try {
        final d = DateTime.parse(rawDate);
        final now = DateTime.now();
        isUpcoming = !d.isBefore(DateTime(now.year, now.month, now.day));
        dateStr =
            '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

        // Format date as "Mon, Jan 15"
        final months = [
          'Jan',
          'Feb',
          'Mar',
          'Apr',
          'May',
          'Jun',
          'Jul',
          'Aug',
          'Sep',
          'Oct',
          'Nov',
          'Dec',
        ];
        final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        displayDate = '${days[d.weekday - 1]}, ${months[d.month - 1]} ${d.day}';
      } catch (_) {
        dateStr = rawDate;
        displayDate = rawDate;
      }
    }

    final String startTime = (e['start_time'] ?? '').toString();

    final statusColor = isUpcoming
        ? const Color(0xFF6366F1)
        : const Color(0xFF94A3B8);

    return GestureDetector(
      onTap: () async {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => EventDetailScreen(
              event: e,
              onEventUpdated: () => _loadEvents(),
            ),
          ),
        );
        await _loadEvents();
      },
      child: Container(
        margin: showMargin
            ? const EdgeInsets.only(bottom: 12)
            : EdgeInsets.zero,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Event details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Client name
                  Text(
                    clientName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.2,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Date
                  if (displayDate.isNotEmpty) ...[
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 14,
                          color: statusColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          displayDate,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: statusColor,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                  ],
                  // Venue
                  Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 14,
                        color: Colors.grey.shade500,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          venueName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade600,
                            height: 1.2,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Navigate button
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          _openGoogleMaps(
                            venueAddress.isNotEmpty ? venueAddress : venueName,
                            googleMapsUrl,
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Icon(
                            Icons.directions,
                            size: 20,
                            color: const Color(0xFF6366F1),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      // Copy button
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          _shareEvent(e);
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Icon(
                            Icons.copy,
                            size: 18,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (startTime.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    // Time
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 14,
                          color: Colors.grey.shade500,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          startTime,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade600,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _modernMiniInfo({
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.15), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildManualEntryTab() {
    return SingleChildScrollView(
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800),
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                HeaderCard(
                  title: 'Manual Entry',
                  subtitle: AppLocalizations.of(context)!.enterJobDetailsManually,
                  icon: Icons.edit_note,
                  gradientColors: const [Color(0xFF059669), Color(0xFF10B981)],
                ),
                const SizedBox(height: 24),
                FormSection(
                  title: AppLocalizations.of(context)!.jobInformation,
                  icon: Icons.event,
                  children: [
                    LabeledTextField(
                      controller: _eventNameController,
                      label: AppLocalizations.of(context)!.jobTitle,
                      icon: Icons.celebration,
                      isRequired: true,
                    ),
                    const SizedBox(height: 16),
                    LabeledTextField(
                      controller: _clientNameController,
                      label: AppLocalizations.of(context)!.clientName,
                      icon: Icons.person,
                      isRequired: true,
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () async {
                          await _openClientPicker();
                        },
                        icon: const Icon(Icons.business),
                        label: const Text('Pick from Clients'),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF6366F1),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildModernDatePicker(),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildModernTimePicker(
                            label: AppLocalizations.of(context)!.startTime,
                            icon: Icons.access_time,
                            selectedTime: _selectedStartTime,
                            onTimeSelected: (time) {
                              setState(() {
                                _selectedStartTime = time;
                                _startTimeController.text = time.format(
                                  context,
                                );
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildModernTimePicker(
                            label: AppLocalizations.of(context)!.endTime,
                            icon: Icons.access_time_filled,
                            selectedTime: _selectedEndTime,
                            onTimeSelected: (time) {
                              setState(() {
                                _selectedEndTime = time;
                                _endTimeController.text = time.format(context);
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Container(), // Spacer
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: LabeledTextField(
                            controller: _headcountController,
                            label: AppLocalizations.of(context)!.headcount,
                            icon: Icons.people,
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                FormSection(
                  title: AppLocalizations.of(context)!.locationInformation,
                  icon: Icons.location_on,
                  children: [
                    LabeledTextField(
                      controller: _venueNameController,
                      label: AppLocalizations.of(context)!.locationName,
                      icon: Icons.business,
                    ),
                    const SizedBox(height: 16),
                    ModernAddressField(
                      controller: _venueAddressController,
                      label: AppLocalizations.of(context)!.address,
                      icon: Icons.place,
                      onPlaceSelected: (placeDetails) {
                        setState(() {
                          _selectedVenuePlace = placeDetails;
                          // Auto-fill city and state from the selected place
                          if (placeDetails
                                  .addressComponents['city']
                                  ?.isNotEmpty ==
                              true) {
                            _cityController.text =
                                placeDetails.addressComponents['city']!;
                          }
                          if (placeDetails
                                  .addressComponents['state']
                                  ?.isNotEmpty ==
                              true) {
                            _stateController.text =
                                placeDetails.addressComponents['state']!;
                          }
                        });

                        // Show success feedback
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Row(
                              children: [
                                const Icon(
                                  Icons.check_circle,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Address selected and city/state auto-filled',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            backgroundColor: const Color(0xFF059669),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: LabeledTextField(
                            controller: _cityController,
                            label: AppLocalizations.of(context)!.city,
                            icon: Icons.location_city,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: LabeledTextField(
                            controller: _stateController,
                            label: AppLocalizations.of(context)!.state,
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
                      label: AppLocalizations.of(context)!.contactName,
                      icon: Icons.person_outline,
                    ),
                    const SizedBox(height: 16),
                    LabeledTextField(
                      controller: _contactPhoneController,
                      label: AppLocalizations.of(context)!.phoneNumber,
                      icon: Icons.phone,
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 16),
                    LabeledTextField(
                      controller: _contactEmailController,
                      label: AppLocalizations.of(context)!.email,
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
                      label: AppLocalizations.of(context)!.notes,
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
                        : () async {
                            final Map<String, dynamic> payload =
                                Map<String, dynamic>.from(structuredData!);
                            final selClient = _clientNameController.text.trim();
                            if (selClient.isNotEmpty) {
                              payload['client_name'] = selClient;
                            }
                            await _pendingService.saveDraft(payload);
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Saved to Pending'),
                                backgroundColor: Color(0xFF059669),
                              ),
                            );
                            await _draftService.clearDraft();
                          },
                    icon: const Icon(Icons.save, size: 18),
                    label: const Text('Save to Pending'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                if (structuredData != null) ...[
                  InfoCard(
                    title: AppLocalizations.of(context)!.jobDetails,
                    icon: Icons.event_note,
                    child: _buildEventDetails(structuredData!),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChatTab() {
    final messages = _aiChatService.conversationHistory;
    final currentData = _aiChatService.currentEventData;

    return Column(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(28),
              bottomRight: Radius.circular(28),
            ),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 800),
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Stack(
                  children: [
                    HeaderCard(
                      title: 'AI Chat Assistant',
                      subtitle: AppLocalizations.of(context)!.createJobsThroughAI,
                      icon: Icons.auto_awesome,
                      gradientColors: const [Color(0xFF8B5CF6), Color(0xFFEC4899)],
                    ),
                    // Clear chat button - only show if there are messages
                    if (messages.isNotEmpty)
                      Positioned(
                        right: 16,
                        top: 16,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () {
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Clear Chat?'),
                                  content: const Text(
                                    'This will delete the current conversation and any unsaved event data.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        Navigator.pop(context);
                                        setState(() {
                                          _aiChatService.startNewConversation();
                                        });
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Chat cleared'),
                                            duration: Duration(seconds: 2),
                                          ),
                                        );
                                      },
                                      child: const Text(
                                        'Clear',
                                        style: TextStyle(color: Colors.red),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.9),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.delete_outline,
                                    size: 18,
                                    color: Colors.grey.shade700,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Clear',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 8),
                // Floating draft preview button
                if (currentData.isNotEmpty)
                  Align(
                    alignment: Alignment.centerRight,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(24),
                        onTap: () => _showDraftPreview(context, currentData),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.4),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.auto_awesome, size: 18, color: Colors.white),
                                const SizedBox(width: 8),
                                const Text(
                                  'View Draft',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (_aiChatService.eventComplete) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.3),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.check, size: 12, color: Colors.white),
                                  ),
                                ],
                              ],
                            ),
                          ),
                      ),
                    ),
                  ),
                // Chat messages
                Expanded(
                  child: messages.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(60),
                                ),
                                child: const Icon(
                                  Icons.chat_bubble_outline,
                                  size: 60,
                                  color: Color(0xFF8B5CF6),
                                ),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                'Start a Conversation',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade800,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'The AI will guide you through creating an event',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 32),
                              // Beautiful gradient button - constrained for mobile
                              ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth: MediaQuery.of(context).size.width - 48,
                                ),
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(30),
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFF7C3AED), // Light purple
                                        Color(0xFF6366F1), // Medium purple
                                        Color(0xFF4F46E5), // Darker purple
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF7C3AED).withOpacity(0.4),
                                        blurRadius: 20,
                                        offset: const Offset(0, 10),
                                        spreadRadius: 0,
                                      ),
                                    ],
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(30),
                                      onTap: () {
                                        setState(() {
                                          _aiChatService.startNewConversation();
                                          final greeting = _aiChatService.getGreeting();
                                          // Scroll to bottom after greeting
                                          WidgetsBinding.instance
                                              .addPostFrameCallback((_) {
                                            if (_aiChatScrollController.hasClients) {
                                              _aiChatScrollController.animateTo(
                                                _aiChatScrollController
                                                    .position.maxScrollExtent,
                                                duration:
                                                    const Duration(milliseconds: 300),
                                                curve: Curves.easeOut,
                                              );
                                            }
                                          });
                                        });
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 24,
                                          vertical: 16,
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: Colors.white.withOpacity(0.2),
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: const Icon(
                                                Icons.auto_awesome,
                                                color: Colors.white,
                                                size: 22,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            const Flexible(
                                              child: Text(
                                                'Start New Conversation',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600,
                                                  letterSpacing: 0.3,
                                                ),
                                                textAlign: TextAlign.center,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          controller: _aiChatScrollController,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: messages.length,
                          itemBuilder: (context, index) {
                            return ChatMessageWidget(
                              message: messages[index],
                              userProfilePicture: _profilePictureUrl,
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
        ),
        // Only show input widget when conversation has started
        ColoredBox(
          color: Colors.transparent,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            switchInCurve: Curves.easeInOut,
            switchOutCurve: Curves.easeInOut,
            transitionBuilder: (child, animation) {
              return SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 1),
                  end: Offset.zero,
                ).animate(animation),
                child: FadeTransition(
                  opacity: animation,
                  child: child,
                ),
              );
            },
            child: messages.isNotEmpty
                ? ChatInputWidget(
                    key: const ValueKey('chat-input'),
                    onSendMessage: (message) async {
            setState(() {
              _isAIChatLoading = true;
            });

            try {
              final response =
                  await _aiChatService.sendMessage(message);

              // Scroll to bottom after message
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (_aiChatScrollController.hasClients) {
                  _aiChatScrollController.animateTo(
                    _aiChatScrollController.position.maxScrollExtent,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                  );
                }
              });

              // Only save when event is complete (not after every message)
              // This prevents duplicate saves during conversation
              if (_aiChatService.eventComplete && _aiChatService.currentEventData.isNotEmpty) {
                // Event complete - it will be saved when user clicks "Save to Pending" button
                // No auto-save here to avoid duplicates
              }
            } catch (e) {
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error: ${e.toString()}'),
                  backgroundColor: Colors.red,
                ),
              );
            } finally {
              if (mounted) {
                setState(() {
                  _isAIChatLoading = false;
                });
              }
            }
          },
          isLoading: _isAIChatLoading,
        )
              : const SizedBox.shrink(
                  key: ValueKey('empty'),
                ),
          ),
        ),
      ],
    );
  }

  Widget _buildEventDetails(Map<String, dynamic> data) {
    final List<dynamic> acceptedStaff = (data['accepted_staff'] is List)
        ? (data['accepted_staff'] as List)
        : const [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (data['event_name'] != null)
          DetailRow(
            label: AppLocalizations.of(context)!.job,
            value: data['event_name'],
            icon: Icons.celebration,
          ),
        if (data['client_name'] != null)
          DetailRow(
            label: AppLocalizations.of(context)!.client,
            value: data['client_name'],
            icon: Icons.person,
          ),
        if (data['date'] != null)
          DetailRow(
            label: AppLocalizations.of(context)!.date,
            value: data['date'],
            icon: Icons.calendar_today,
          ),
        if (data['start_time'] != null && data['end_time'] != null)
          DetailRow(
            label: AppLocalizations.of(context)!.time,
            value: '${data['start_time']} - ${data['end_time']}',
            icon: Icons.access_time,
          ),
        if (data['venue_name'] != null)
          DetailRow(
            label: AppLocalizations.of(context)!.location,
            value: data['venue_name'],
            icon: Icons.location_on,
          ),
        if (data['venue_address'] != null)
          DetailRow(
            label: AppLocalizations.of(context)!.address,
            value: data['venue_address'],
            icon: Icons.place,
          ),
        if (data['contact_phone'] != null)
          DetailRow(
            label: AppLocalizations.of(context)!.phone,
            value: data['contact_phone'],
            icon: Icons.phone,
          ),
        if (data['headcount_total'] != null)
          DetailRow(
            label: AppLocalizations.of(context)!.headcount,
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
        if (acceptedStaff.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text(
            'Accepted Staff',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 8),
          ...acceptedStaff.map((member) {
            String displayName;
            String? status;
            String? roleLabel;
            if (member is Map<String, dynamic>) {
              final m = member;
              displayName =
                  (m['name'] ??
                          m['first_name'] ??
                          m['email'] ??
                          m['subject'] ??
                          m['userKey'] ??
                          'Member')
                      .toString();
              status = m['response']?.toString();
              final r = (m['role'] ?? '').toString();
              roleLabel = r.isNotEmpty ? r : null;
            } else if (member is String) {
              displayName = member;
            } else {
              displayName = member.toString();
            }
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F9FF),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.person, color: Color(0xFF0EA5E9), size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      roleLabel != null
                          ? "$displayName — $roleLabel"
                          : displayName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (status != null)
                    Text(
                      status,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                ],
              ),
            );
          }),
        ],
        // Hidden: raw JSON dialog link is not needed for end users
      ],
    );
  }

  Future<void> _saveCurrentEvent() async {
    if (structuredData == null) return;
    final Map<String, dynamic> payload = Map<String, dynamic>.from(
      structuredData!,
    );

    // If payload came from file extraction (no interactive place pick), try to
    // enrich address fields using Places: add lat/lng and a google_maps_url
    // so downstream flows can open the exact place.
    try {
      final hasCoords =
          payload.containsKey('venue_latitude') ||
          payload.containsKey('venue_longitude');
      final String addr = (payload['venue_address'] ?? payload['venue'] ?? '')
          .toString()
          .trim();
      if (!hasCoords && addr.isNotEmpty && _selectedVenuePlace == null) {
        final details = await GooglePlacesService.resolveAddressToPlaceDetails(
          addr,
        );
        if (details != null) {
          payload['venue_latitude'] = details.latitude;
          payload['venue_longitude'] = details.longitude;
          payload['google_maps_url'] =
              'https://www.google.com/maps/search/?api=1&query='
              '${Uri.encodeComponent(details.formattedAddress.isNotEmpty ? details.formattedAddress : '${details.latitude},${details.longitude}')}'
              '&query_place_id=${Uri.encodeComponent(details.placeId)}';
          // Optionally backfill city/state if missing
          if ((payload['city'] ?? '').toString().trim().isEmpty &&
              (details.addressComponents['city'] ?? '').isNotEmpty) {
            payload['city'] = details.addressComponents['city'];
          }
          if ((payload['state'] ?? '').toString().trim().isEmpty &&
              (details.addressComponents['state'] ?? '').isNotEmpty) {
            payload['state'] = details.addressComponents['state'];
          }
        }
      }
    } catch (_) {}

    // Ask for staff counts (bartenders/servers/dishwashers) before saving
    final Map<String, dynamic>? promptResult = await _promptStaffCounts(
      payload,
    );
    if (promptResult == null) {
      return; // user cancelled
    }
    final Map<String, int> counts =
        (promptResult['counts'] as Map?)?.map<String, int>(
          (key, value) =>
              MapEntry(key.toString(), int.tryParse(value.toString()) ?? 0),
        ) ??
        <String, int>{};
    final String confirmedClientName =
        (promptResult['client_name']?.toString() ?? '').trim();
    if (confirmedClientName.isNotEmpty) {
      payload['client_name'] = confirmedClientName;
    }
    final List<dynamic> existingRoles = (payload['roles'] is List)
        ? (payload['roles'] as List)
        : const [];
    payload['roles'] = _mergeStaffCountsIntoRoles(existingRoles, counts);
    // Normalize date: backend accepts ISO or Date; try to ensure ISO string
    final date = payload['date'];
    if (date is String && date.isNotEmpty) {
      try {
        final parsed = DateTime.parse(date);
        payload['date'] = parsed.toIso8601String();
      } catch (_) {}
    }
    // Sanitize and validate contact_email locally to avoid backend 400
    if (payload.containsKey('contact_email')) {
      final dynamic raw = payload['contact_email'];
      final String email = (raw?.toString() ?? '').trim();
      if (email.isEmpty) {
        payload.remove('contact_email');
      } else {
        final RegExp emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
        if (!emailRegex.hasMatch(email)) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please enter a valid email address'),
              backgroundColor: Color(0xFFDC2626),
            ),
          );
          return;
        }
        payload['contact_email'] = email.toLowerCase();
      }
    }
    try {
      await _eventService.createEvent(payload);
      // Refresh events list and navigate to Events tab so the user can see it immediately
      await _loadEvents();
      if (!mounted) return;
      setState(() {
        _selectedIndex = 1; // Navigate to Events tab
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Event saved to database'),
          backgroundColor: Color(0xFF059669),
        ),
      );
      // Clear draft after successful save
      await _draftService.clearDraft();
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

  Future<void> _openClientPicker() async {
    // Ensure latest clients
    await _loadClients();
    final List<Map<String, dynamic>> items = _clients ?? const [];
    final TextEditingController newClientCtrl = TextEditingController();
    final String? picked = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setStateDialog) {
            return AlertDialog(
              title: const Text('Select Client'),
              content: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (items.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: Text('No clients yet. Create one below.'),
                      ),
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final c = items[index];
                          return ListTile(
                            leading: const Icon(Icons.business),
                            title: Text((c['name'] ?? '').toString()),
                            onTap: () => Navigator.of(
                              ctx,
                            ).pop((c['name'] ?? '').toString()),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: newClientCtrl,
                      decoration: const InputDecoration(
                        labelText: 'New client name',
                        prefixIcon: Icon(Icons.add_business),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Close'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final name = newClientCtrl.text.trim();
                    if (name.isEmpty) return;
                    try {
                      await _clientsService.createClient(name);
                      Navigator.of(ctx).pop(name);
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Failed to create client: $e'),
                          backgroundColor: const Color(0xFFDC2626),
                        ),
                      );
                    }
                  },
                  child: const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );
    if (picked != null && picked.isNotEmpty) {
      setState(() {
        _clientNameController.text = picked;
      });
    }
  }

  Widget _buildModernDatePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.calendar_today, size: 16, color: Colors.grey.shade600),
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
            const Text(
              ' *',
              style: TextStyle(
                color: Color(0xFFEF4444),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: _selectedDate ?? DateTime.now(),
              firstDate: DateTime.now().subtract(const Duration(days: 30)),
              lastDate: DateTime.now().add(const Duration(days: 365)),
              builder: (context, child) {
                return Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: const ColorScheme.light(
                      primary: Color(0xFF6366F1),
                      onPrimary: Colors.white,
                      surface: Colors.white,
                      onSurface: Color(0xFF0F172A),
                    ),
                    dialogTheme: DialogThemeData(backgroundColor: Colors.white),
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
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _selectedDate != null
                    ? const Color(0xFF6366F1).withValues(alpha: 0.3)
                    : Colors.grey.shade300,
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.calendar_today,
                    size: 20,
                    color: Color(0xFF6366F1),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _selectedDate != null
                        ? '${_getMonthName(_selectedDate!.month)} ${_selectedDate!.day}, ${_selectedDate!.year}'
                        : 'Select a date',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: _selectedDate != null
                          ? const Color(0xFF0F172A)
                          : Colors.grey.shade500,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_drop_down,
                  color: Colors.grey.shade400,
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildModernTimePicker({
    required String label,
    required IconData icon,
    required TimeOfDay? selectedTime,
    required void Function(TimeOfDay) onTimeSelected,
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
        InkWell(
          onTap: () async {
            final time = await showTimePicker(
              context: context,
              initialTime: selectedTime ?? TimeOfDay.now(),
              builder: (context, child) {
                return Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: const ColorScheme.light(
                      primary: Color(0xFF6366F1),
                      onPrimary: Colors.white,
                      surface: Colors.white,
                      onSurface: Color(0xFF0F172A),
                    ),
                    dialogTheme: DialogThemeData(backgroundColor: Colors.white),
                  ),
                  child: child!,
                );
              },
            );
            if (time != null) {
              onTimeSelected(time);
            }
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selectedTime != null
                    ? const Color(0xFF6366F1).withValues(alpha: 0.3)
                    : Colors.grey.shade300,
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 20, color: const Color(0xFF6366F1)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    selectedTime != null
                        ? selectedTime.format(context)
                        : 'Select time',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: selectedTime != null
                          ? const Color(0xFF0F172A)
                          : Colors.grey.shade500,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_drop_down,
                  color: Colors.grey.shade400,
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _getMonthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return months[month - 1];
  }
}
