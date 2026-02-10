import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:nexa/l10n/app_localizations.dart';
import 'package:nexa/services/terminology_provider.dart';
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
import '../../../core/utils/formatters.dart';
import '../../../core/navigation/route_error_manager.dart';
import '../services/clients_service.dart';
import '../services/draft_service.dart';
import '../services/event_service.dart';
import '../services/extraction_service.dart';
import '../services/file_processor_service.dart';
import '../services/google_places_service.dart';
// import '../services/pending_events_service.dart'; // DEPRECATED: Now using backend draft events
import '../services/roles_service.dart';
import '../services/tariffs_service.dart';
import '../services/staff_service.dart';
import '../services/group_service.dart';
import '../services/users_service.dart';
import '../services/chat_event_service.dart';
import '../widgets/modern_address_field.dart';
import '../widgets/upload_container.dart';
import '../widgets/event_data_preview_card.dart';
import '../../extraction/widgets/chat_message_widget.dart';
import '../../extraction/widgets/chat_input_widget.dart';
import '../../extraction/widgets/event_confirmation_card.dart';
import '../widgets/batch_event_dialog.dart';
import 'widgets/extraction_widgets.dart';
import 'mixins/event_data_mixin.dart';
import 'pending_publish_screen.dart';
import 'package:nexa/shared/widgets/initials_avatar.dart';
import 'pending_edit_screen.dart';
import 'staff_detail_screen.dart';
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
import 'ai_chat_screen.dart';
import '../../../core/widgets/section_navigation_dropdown.dart';
import '../../../core/widgets/web_tab_navigation.dart';
import '../../main/presentation/main_screen.dart';
import 'package:nexa/shared/widgets/web_content_wrapper.dart';

enum _SortMode { dateAsc, dateDesc, lastCreated }

class ExtractionScreen extends StatefulWidget {
  final int initialIndex; // For Post a Job tab chips
  final int initialScreenIndex; // For main screen tabs (Post a Job=0, Events=1, etc.)
  final int initialEventsTabIndex; // For Events sub-tabs (Pending=0, Upcoming=1, Past=2)
  final ScrollController? scrollController; // Optional scroll controller for syncing with main screen
  final bool hideNavigationRail; // Hide navigation rail when used inside MainScreen

  const ExtractionScreen({
    super.key,
    this.initialIndex = 0,
    this.initialScreenIndex = 0,
    this.initialEventsTabIndex = 0,
    this.scrollController,
    this.hideNavigationRail = false,
  });

  @override
  State<ExtractionScreen> createState() => _ExtractionScreenState();
}

class _ExtractionScreenState extends State<ExtractionScreen>
    with TickerProviderStateMixin, EventDataMixin {
  String? extractedText;
  Map<String, dynamic>? structuredData;
  bool isLoading = false;
  String? errorMessage;

  int _selectedIndex = 1; // Start with Jobs section (dashboard commented out)
  late TabController _createTabController; // Back to TabController for Post a Job tabs
  late TabController _eventsTabController;
  late TabController _catalogTabController;

  // Events listing state
  List<Map<String, dynamic>>? _events;
  bool _isEventsLoading = false;
  String? _eventsError;
  List<Map<String, dynamic>>? _eventsPending;
  List<Map<String, dynamic>>? _eventsAvailable;
  List<Map<String, dynamic>>? _eventsFull;
  List<Map<String, dynamic>>? _eventsCompleted;
  List<Map<String, dynamic>>? _eventsExpired;

  // Search & sort state
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isSearchActive = false;
  Timer? _searchDebounce;
  _SortMode _sortMode = _SortMode.dateAsc; // default: job date ascending (current behavior)

  // Pending drafts (for the old draft section - will be deprecated)
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

  // Staff listing state
  List<Map<String, dynamic>>? _staffMembers;
  bool _isStaffLoading = false;
  String? _staffError;
  String _staffSearchQuery = '';
  String? _staffFilterRole;
  String? _staffFilterGroup;
  bool _staffFilterFavorite = false;
  List<Map<String, dynamic>> _staffGroups = [];
  late final StaffService _staffService;
  late final GroupService _groupService;

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
  final _zipController = TextEditingController();
  final _contactNameController = TextEditingController();
  final _contactPhoneController = TextEditingController();
  final _contactEmailController = TextEditingController();
  final _headcountController = TextEditingController();
  final _notesController = TextEditingController();

  // Role count controllers for manual entry
  final Map<String, TextEditingController> _roleCountControllers = {};

  late final ExtractionService _extractionService;
  late final EventService _eventService;
  late final ClientsService _clientsService;
  late final RolesService _rolesService;
  late final FileProcessorService _fileProcessorService;
  final DraftService _draftService = DraftService();
  // final PendingEventsService _pendingService = PendingEventsService(); // DEPRECATED: Now using backend
  bool _lastStructuredFromUpload = false;

  // AI Chat state
  final ChatEventService _aiChatService = ChatEventService();
  bool _isAIChatLoading = false;
  final ScrollController _aiChatScrollController = ScrollController();
  bool _showAIChatHeader = true;
  double _lastScrollOffset = 0;

  // Profile avatar state
  late final ManagerService _managerService;
  String? _profilePictureUrl;
  String? _profileFirstName;
  String? _profileLastName;

  // Timer for real-time updates
  Timer? _updateTimer;
  StreamSubscription<SocketEvent>? _socketSubscription;

  // Merge mode state
  bool _isMergeMode = false;
  final Set<String> _mergeSelectedIds = {};
  bool _isMerging = false;

  // Animation controllers for header hide/show effect
  late AnimationController _headerController;
  late Animation<double> _headerAnimation;
  bool _isHeaderVisible = true;
  Timer? _autoShowTimer;
  ScrollController? _mainScrollController;
  double _lastMainScrollOffset = 0;
  DateTime _lastScrollTime = DateTime.now();

  // Floating "New Job" chip state
  bool _isJobChipExpanded = true;

  // Performance optimization constants
  static const Duration _animationDuration = Duration(milliseconds: 200);
  static const double _scrollThreshold = 3.0;
  static const double _velocityThreshold = 120.0;
  static const Duration _autoShowDelay = Duration(milliseconds: 30000);

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
          foregroundColor: ExColors.techBlue,
          side: const BorderSide(color: ExColors.techBlue),
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialScreenIndex; // Set main screen tab
    _createTabController = TabController(length: 3, vsync: this, initialIndex: widget.initialIndex);
    _eventsTabController = TabController(length: 4, vsync: this, initialIndex: widget.initialEventsTabIndex);
    _catalogTabController = TabController(length: 4, vsync: this);
    _searchController.addListener(_onSearchChanged);

    // Initialize animation controllers for header hide/show
    _headerController = AnimationController(
      duration: _animationDuration,
      vsync: this,
    );

    _headerAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(
      parent: _headerController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    ));

    // Start with header visible
    _headerController.forward();
    _mainScrollController = widget.scrollController;

    // Add listeners for tab navigation updates
    _createTabController.addListener(() {
      // Show header when switching tabs
      if (_createTabController.indexIsChanging) {
        _showHeader();
      }
      // Trigger setState to rebuild slivers with new tab content
      setState(() {});
    });
    _eventsTabController.addListener(() {
      // Show header when switching tabs
      if (_eventsTabController.indexIsChanging) {
        _showHeader();
      }
      // Always update state when tab changes to refresh content
      setState(() {});
    });
    _catalogTabController.addListener(() {
      // Show header when switching tabs
      if (_catalogTabController.indexIsChanging) {
        _showHeader();
        // Exit merge mode when switching catalog sub-tabs
        if (_isMergeMode) {
          _exitMergeMode();
        }
      }
      if (kIsWeb) {
        setState(() {});
      }
    });

    _extractionService = ExtractionService();
    _eventService = EventService();
    _clientsService = ClientsService();
    _rolesService = RolesService();
    _fileProcessorService = FileProcessorService(extractionService: _extractionService);
    // Initialize ManagerService via GetIt
    final api = GetIt.I<ApiClient>();
    final storage = GetIt.I<FlutterSecureStorage>();
    _managerService = ManagerService(api, storage);
    _staffService = StaffService();
    _groupService = GroupService();
    _loadStaffGroups();
    _loadEvents();
    _loadClients();
    _loadRoles();
    _loadTariffs();
    _loadStaff();
    _loadDraftIfAny();
    _loadPendingDrafts();
    _loadProfilePicture();
    _loadFavorites();
    _loadFirstUsersPage();
    _loadConversations();

    _socketSubscription = SocketManager.instance.events.listen((event) {
      if (!mounted) return;
      if (event.event.startsWith('event:')) {
        // Use delta sync for real-time updates (don't show loading indicator)
        print('[Socket] Event update received: ${event.event}');
        _loadEvents(showLoading: false);
        _loadPendingDrafts();
      } else if (event.event.startsWith('team:')) {
        _loadClients();
        _loadRoles();
      } else if (event.event == 'chat:message') {
        _loadConversations();
      }
    });

    // Add scroll listener for AI Chat header hide/show
    _aiChatScrollController.addListener(_handleAIChatScroll);

    // Start timer for periodic delta sync (every 1 minute)
    _updateTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) {
        print('[Timer] Periodic delta sync');
        // Use delta sync to fetch any changes (don't show loading indicator)
        _loadEvents(showLoading: false);
        setState(() {
          // This will trigger a rebuild and update the time display
        });
      }
    });
  }

  void _handleAIChatScroll() {
    if (!_aiChatScrollController.hasClients) return;

    final currentScrollOffset = _aiChatScrollController.offset;
    final scrollingDown = currentScrollOffset > _lastScrollOffset;
    final scrollingUp = currentScrollOffset < _lastScrollOffset;

    // Only hide/show header on mobile
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = !kIsWeb || screenWidth < 600;

    if (isMobile) {
      // Hide header when scrolling down past 50px
      if (scrollingDown && currentScrollOffset > 50 && _showAIChatHeader) {
        setState(() {
          _showAIChatHeader = false;
        });
      }
      // Show header when scrolling up or at the top
      else if ((scrollingUp || currentScrollOffset < 50) && !_showAIChatHeader) {
        setState(() {
          _showAIChatHeader = true;
        });
      }
    } else {
      // Always show header on desktop
      if (!_showAIChatHeader) {
        setState(() {
          _showAIChatHeader = true;
        });
      }
    }

    _lastScrollOffset = currentScrollOffset;
  }

  @override
  void dispose() {
    _createTabController.dispose();
    _eventsTabController.dispose();
    _catalogTabController.dispose();
    _aiChatScrollController.dispose();
    _headerController.dispose();
    _autoShowTimer?.cancel();
    _eventNameController.dispose();
    _clientNameController.dispose();
    _dateController.dispose();
    _startTimeController.dispose();
    _endTimeController.dispose();
    _venueNameController.dispose();
    _venueAddressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _zipController.dispose();
    _contactNameController.dispose();
    _contactPhoneController.dispose();
    _contactEmailController.dispose();
    _headcountController.dispose();
    _notesController.dispose();
    for (final controller in _roleCountControllers.values) {
      controller.dispose();
    }
    _updateTimer?.cancel();
    _socketSubscription?.cancel();
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _handleScroll(ScrollNotification notification) {
    // Skip header animation for catalog tab - always show header
    if (_selectedIndex == 4) {
      if (!_isHeaderVisible) {
        _showHeader();
      }
      return;
    }

    // Only handle scroll updates from the main scrollable
    if (notification is! ScrollUpdateNotification) return;

    // Ignore horizontal scroll events (like PageView swipes between tabs)
    if (notification.metrics.axis != Axis.vertical) return;

    // Check if we have enough content to warrant hiding header
    final maxScroll = notification.metrics.maxScrollExtent;
    if (maxScroll < 400) { // Less than 400px of scrollable content (about 5 cards)
      _showHeader(); // Always show header when content is minimal
      return;
    }

    final now = DateTime.now();
    final timeDiff = now.difference(_lastScrollTime).inMilliseconds;

    if (timeDiff == 0) return;

    final scrollDelta = notification.scrollDelta ?? 0;
    final metrics = notification.metrics;

    // Calculate velocity (pixels per second)
    final velocity = (scrollDelta / timeDiff) * 1000;

    // Cancel any pending auto-show timer
    _autoShowTimer?.cancel();

    // Always show when at the top
    if (metrics.pixels <= 0) {
      _showHeader();
      return;
    }

    // Velocity-based detection for more responsive feel
    final shouldHide = velocity > _velocityThreshold ||
                       (scrollDelta > _scrollThreshold && velocity > 0);
    final shouldShow = velocity < -_velocityThreshold ||
                       (scrollDelta < -_scrollThreshold && velocity < 0);

    if (shouldHide && _isHeaderVisible) {
      _hideHeader();
    } else if (shouldShow && !_isHeaderVisible) {
      _showHeader();
    }

    // Handle "New Job" chip expansion/collapse (Gmail-style)
    // Only on Jobs/Events tab (_selectedIndex == 1)
    if (_selectedIndex == 1) {
      if (shouldHide && _isJobChipExpanded) {
        setState(() {
          _isJobChipExpanded = false; // Collapse to icon only
        });
      } else if ((shouldShow || metrics.pixels <= 50) && !_isJobChipExpanded) {
        setState(() {
          _isJobChipExpanded = true; // Expand to show text
        });
      }
    }

    // Auto-show after scroll stops (like Facebook)
    _autoShowTimer = Timer(_autoShowDelay, () {
      if (!_isHeaderVisible && mounted) {
        _showHeader();
      }
      // Auto-expand chip after scroll stops
      if (!_isJobChipExpanded && _selectedIndex == 1 && mounted) {
        setState(() {
          _isJobChipExpanded = true;
        });
      }
    });

    _lastMainScrollOffset = metrics.pixels;
    _lastScrollTime = now;
  }

  void _showHeader() {
    if (!_isHeaderVisible) {
      HapticFeedback.selectionClick();
      setState(() {
        _isHeaderVisible = true;
      });
      _headerController.forward();
    }
  }

  void _hideHeader() {
    if (_isHeaderVisible) {
      HapticFeedback.selectionClick();
      setState(() {
        _isHeaderVisible = false;
      });
      _headerController.reverse();
    }
  }

  // ── Merge mode helpers ──────────────────────────────────────────────
  void _toggleMergeMode() {
    setState(() {
      _isMergeMode = !_isMergeMode;
      if (!_isMergeMode) _mergeSelectedIds.clear();
    });
  }

  void _toggleMergeSelection(String id) {
    setState(() {
      if (_mergeSelectedIds.contains(id)) {
        _mergeSelectedIds.remove(id);
      } else {
        _mergeSelectedIds.add(id);
      }
    });
  }

  void _exitMergeMode() {
    setState(() {
      _isMergeMode = false;
      _mergeSelectedIds.clear();
    });
  }

  Future<void> _executeMerge(String targetId) async {
    final tabIndex = _catalogTabController.index;
    final sourceIds = _mergeSelectedIds.where((id) => id != targetId).toList();
    if (sourceIds.isEmpty) return;

    setState(() => _isMerging = true);
    try {
      switch (tabIndex) {
        case 0:
          await _clientsService.mergeClients(sourceIds: sourceIds, targetId: targetId);
          break;
        case 1:
          await _rolesService.mergeRoles(sourceIds: sourceIds, targetId: targetId);
          break;
        case 2:
          await _tariffsService.mergeTariffs(sourceIds: sourceIds, targetId: targetId);
          break;
      }
      _exitMergeMode();
      // Reload all catalog data
      await Future.wait([_loadClients(), _loadRoles(), _loadTariffs()]);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Merged ${sourceIds.length + 1} items successfully'),
          backgroundColor: ExColors.successDark,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Merge failed: $e'),
          backgroundColor: ExColors.errorDark,
        ),
      );
    } finally {
      if (mounted) setState(() => _isMerging = false);
    }
  }

  void _showMergeTargetDialog() {
    final tabIndex = _catalogTabController.index;
    final selectedIds = _mergeSelectedIds.toList();

    // Build item list from the selected IDs
    List<Map<String, dynamic>> selectedItems = [];
    if (tabIndex == 0) {
      selectedItems = (_clients ?? []).where((c) => selectedIds.contains((c['id'] ?? '').toString())).toList();
    } else if (tabIndex == 1) {
      selectedItems = (_roles ?? []).where((r) => selectedIds.contains((r['id'] ?? '').toString())).toList();
    } else if (tabIndex == 2) {
      selectedItems = (_tariffs ?? []).where((t) => selectedIds.contains((t['id'] ?? '').toString())).toList();
    }

    if (selectedItems.length < 2) return;

    String? chosenTargetId;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: ExColors.techBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.call_merge, color: ExColors.techBlue, size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(child: Text('Select item to keep', style: TextStyle(fontSize: 18))),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tap the item you want to KEEP. Others will be merged into it and deleted.',
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 16),
                  ...selectedItems.map((item) {
                    final id = (item['id'] ?? '').toString();
                    final isTarget = chosenTargetId == id;
                    String label;
                    if (tabIndex == 2) {
                      // Tariff: show client / role - rate
                      final clientId = (item['clientId'] ?? '').toString();
                      final roleId = (item['roleId'] ?? '').toString();
                      final clientName = (_clients ?? []).firstWhere(
                        (c) => (c['id'] ?? '') == clientId,
                        orElse: () => const {},
                      )['name']?.toString() ?? 'Unknown';
                      final roleName = (_roles ?? []).firstWhere(
                        (r) => (r['id'] ?? '') == roleId,
                        orElse: () => const {},
                      )['name']?.toString() ?? 'Unknown';
                      final rate = (item['rate'] ?? 0).toString();
                      final currency = (item['currency'] ?? 'USD').toString();
                      label = '$clientName / $roleName — \$$rate $currency/hr';
                    } else {
                      label = (item['name'] ?? '').toString();
                    }

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => setDialogState(() => chosenTargetId = id),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: isTarget ? ExColors.techBlue.withOpacity(0.08) : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isTarget ? ExColors.techBlue : Colors.grey.shade300,
                              width: isTarget ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  label,
                                  style: TextStyle(
                                    fontWeight: isTarget ? FontWeight.w700 : FontWeight.w500,
                                    fontSize: 14,
                                    color: isTarget ? ExColors.techBlue : ExColors.charcoal,
                                  ),
                                ),
                              ),
                              if (isTarget)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: ExColors.successDark,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'KEEP',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: chosenTargetId == null || _isMerging
                    ? null
                    : () {
                        Navigator.of(ctx).pop();
                        _executeMerge(chosenTargetId!);
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: ExColors.techBlue,
                  foregroundColor: Colors.white,
                ),
                child: _isMerging
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Merge'),
              ),
            ],
          );
        },
      ),
    );
  }
  // ── End merge mode helpers ─────────────────────────────────────────

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
      _eventNameController.text = (d['shift_name'] ?? '').toString();
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

      // Use FileProcessorService to handle all processing
      final processResult = await _fileProcessorService.processFile(platformFile);

      if (!processResult.success) {
        setState(() {
          errorMessage = processResult.error;
          isLoading = false;
        });
        return;
      }

      _clientNameController.text = '';
      setState(() {
        extractedText = processResult.extractedText;
        structuredData = processResult.structuredData;
        isLoading = false;
        _lastStructuredFromUpload = true;
      });

      // Persist draft to allow switching tabs
      if (processResult.structuredData != null) {
        await saveDraft(processResult.structuredData!);
      }
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
                    color: ExColors.backgroundLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.business, color: ExColors.techBlue),
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
          backgroundColor: ExColors.error,
        ),
      );
      return;
    }

    if (_formKey.currentState!.validate()) {
      final manualData = {
        'shift_name': _eventNameController.text.trim(),
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
          backgroundColor: ExColors.successDark,
        ),
      );
    }
  }

  /// Build manual entry data from form fields
  Map<String, dynamic>? _buildManualEntryData() {
    // Custom validation for date picker
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.pleaseSelectDate),
          backgroundColor: ExColors.error,
        ),
      );
      return null;
    }

    if (!_formKey.currentState!.validate()) {
      return null;
    }

    final manualData = <String, dynamic>{
      'event_name': _eventNameController.text.trim(),
      'client_name': _clientNameController.text.trim(),
      'date': _selectedDate!.toIso8601String(),
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
      'status': 'draft',
    };

    // Build roles array from role count controllers
    final roles = <Map<String, dynamic>>[];
    for (final entry in _roleCountControllers.entries) {
      final count = int.tryParse(entry.value.text.trim()) ?? 0;
      if (count > 0) {
        roles.add({'role': entry.key, 'count': count});
      }
    }
    if (roles.isNotEmpty) {
      manualData['roles'] = roles;
    }

    manualData.removeWhere(
      (key, value) =>
          value == null || value == '' || (value is int && value == 0),
    );

    return manualData;
  }

  /// Save manual entry directly to pending (single step)
  Future<void> _saveManualEntryToPending() async {
    final payload = _buildManualEntryData();
    if (payload == null) return;

    setState(() {
      isLoading = true;
    });

    try {
      await _eventService.createEvent(payload);
      if (!mounted) return;

      _showSuccessBanner(context, 'Saved to Pending!');
      _clearManualEntryForm();
      await _loadEvents();

      // Navigate to Events tab to show the new event
      setState(() {
        _selectedIndex = 1; // Events tab
        _eventsTabController.animateTo(0); // Pending subtab
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  /// Show batch dialog for manual entry recurring series
  Future<void> _showManualEntryBatchDialog() async {
    final templateData = _buildManualEntryData();
    if (templateData == null) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return BatchEventDialog(
          templateEventData: templateData,
          onCreateBatch: _createManualEntryBatchEvents,
        );
      },
    );
  }

  /// Create multiple events from manual entry with different dates
  Future<void> _createManualEntryBatchEvents(List<DateTime> dates) async {
    if (dates.isEmpty) return;

    final template = _buildManualEntryData();
    if (template == null) return;

    setState(() {
      isLoading = true;
    });

    try {
      // Create events with different dates
      final events = dates.map((date) {
        return {
          ...template,
          'date': date.toIso8601String(),
          'status': 'draft',
        };
      }).toList();

      print('[ExtractionScreen] Creating manual entry batch with ${events.length} events...');

      final createdEvents = await _eventService.createBatchEvents(events);

      print('[ExtractionScreen] ✓ Created ${createdEvents.length} events');

      // Show success message
      _showSuccessBanner(context, 'Created ${createdEvents.length} recurring events!');
      _clearManualEntryForm();
      await _loadEvents();

      // Navigate to Events tab
      setState(() {
        _selectedIndex = 1; // Events tab
        _eventsTabController.animateTo(0); // Pending subtab
      });

    } catch (e) {
      print('[ExtractionScreen] ✗ Failed to create batch events: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create recurring events: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  /// Clear the manual entry form
  void _clearManualEntryForm() {
    _eventNameController.clear();
    _clientNameController.clear();
    _dateController.clear();
    _startTimeController.clear();
    _endTimeController.clear();
    _venueNameController.clear();
    _venueAddressController.clear();
    _cityController.clear();
    _stateController.clear();
    _contactNameController.clear();
    _contactPhoneController.clear();
    _contactEmailController.clear();
    _headcountController.clear();
    _notesController.clear();
    _selectedDate = null;
    _selectedStartTime = null;
    _selectedEndTime = null;
    _selectedVenuePlace = null;
    structuredData = null;
    // Reset role count controllers to 0
    for (final controller in _roleCountControllers.values) {
      controller.text = '0';
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
                ExColors.backgroundGrey,
                ExColors.backgroundWhite,
              ],
            ),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: ExColors.shadowBlack,
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
                            ExColors.yellow,
                            ExColors.techBlue,
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
                              color: ExColors.textPrimary,
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
                          color: ExColors.success.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.check_circle,
                              size: 14,
                              color: ExColors.success,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Complete',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: ExColors.success,
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
                            final callTimeRaw = role['call_time'];
                            final callTime = callTimeRaw?.toString() ?? '';
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
                            color: ExColors.info.withOpacity(0.1),
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
                                        ExColors.yellow,
                                        ExColors.techBlue,
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
                                color: ExColors.textPrimary,
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

                      // Save to backend as draft event
                      try {
                        final draftPayload = {
                          ...currentData,
                          'status': 'draft', // Set status to draft
                        };
                        final createdEvent = await _eventService.createEvent(draftPayload);
                        final id = createdEvent['id'] ?? createdEvent['_id'];

                        if (!mounted) return;

                        _aiChatService.startNewConversation();
                        await _aiChatService.getGreeting();

                        setState(() {
                          structuredData = currentData;
                          extractedText = 'AI Chat extracted data';
                          errorMessage = null;
                          _lastStructuredFromUpload = false;
                        });

                        _draftService.saveDraft(currentData);

                        // Reload events to show the new one
                        await _loadEvents();
                      } catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Failed to save draft: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(AppLocalizations.of(context)!.jobSavedToPending),
                          backgroundColor: ExColors.successDark,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ExColors.techBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.save, size: 20),
                        SizedBox(width: 8),
                        Text(
                          AppLocalizations.of(context)!.saveToPending,
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
      case 0: // Post a Job tab
        if (structuredData != null && structuredData!.isNotEmpty) {
          final eventName =
              structuredData!['shift_name']?.toString() ?? 'Untitled Event';
          return eventName.length > 20
              ? '${eventName.substring(0, 20)}...'
              : eventName;
        }
        return greeting;
      case 1: // Events tab
        return context.read<TerminologyProvider>().plural;
      case 2: // Chat tab
        return "Chat";
      case 3: // Hours tab
        return "Hours Approval";
      case 4: // Catalog tab
        return 'Catalog';
      default:
        return greeting;
    }
  }

  String _getCurrentSectionName() {
    final terminology = context.read<TerminologyProvider>().plural;
    switch (_selectedIndex) {
      case 0:
        return terminology; // Create is treated as part of Jobs
      case 1:
        return terminology;
      case 4:
        return 'Catalog';
      default:
        return terminology;
    }
  }

  Future<void> _handleNavigationDropdown(String section) async {
    HapticFeedback.lightImpact();
    final terminology = context.read<TerminologyProvider>().plural;

    if (section == terminology) {
      section = 'Jobs'; // Normalize to 'Jobs' for logic purposes
    }

    switch (section) {
      case 'Jobs':
        // If already on Jobs section (index 0 or 1), just switch to Events tab (index 1)
        if (_selectedIndex == 0 || _selectedIndex == 1) {
          setState(() {
            _selectedIndex = 1; // Switch to Events/Jobs tab
          });
        } else {
          // Navigate to Jobs tab from other sections
          await RouteErrorManager.instance.navigateSafely(
            context,
            () => const MainScreen(initialIndex: 2),
            replace: true,
          );
        }
        break;
      case 'Clients':
        // Navigate to Catalog tab (MainScreen index 4)
        await RouteErrorManager.instance.navigateSafely(
          context,
          () => const MainScreen(initialIndex: 4),
          replace: true,
        );
        break;
      case 'Teams':
        // Navigate to Teams Management (separate screen, not a main tab)
        await RouteErrorManager.instance.navigateSafely(
          context,
          () => const TeamsManagementPage(),
        );
        break;
      case 'Catalog':
        // Navigate to Catalog tab (MainScreen index 4)
        await RouteErrorManager.instance.navigateSafely(
          context,
          () => const MainScreen(initialIndex: 4),
          replace: true,
        );
        break;
      case 'AI Chat':
        // Navigate to AI Chat screen (separate screen, not a main tab)
        final result = await RouteErrorManager.instance.navigateSafely(
          context,
          () => const AIChatScreen(),
        );
        // Handle "Check Pending" navigation
        if (result != null && result is Map && result['action'] == 'show_pending') {
          setState(() {
            _selectedIndex = 1; // Switch to Events tab
            _eventsTabController.animateTo(0); // Switch to Pending sub-tab
          });
          await _loadPendingDrafts(); // Refresh pending list
        }
        break;
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
      case 0: // Post a Job tab
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
        return baseTime;
      case 2: // Chat tab
        return "${AppLocalizations.of(context)!.messagesAndTeamMembers} • $baseTime";
      case 3: // Hours tab
        return baseTime;
      case 4: // Catalog tab
        return baseTime;
      default:
        return baseTime;
    }
  }

  List<Widget> _buildSliverContent() {
    final slivers = switch (_selectedIndex) {
      0 => _buildCreateSlivers(), // Post a Job tab (uncommented for Manual Entry access)
      1 => _buildEventsSlivers(), // Events tab
      2 => _buildChatSlivers(), // Chat tab
      3 => _buildHoursSlivers(), // Hours tab
      4 => _buildCatalogSlivers(), // Catalog tab
      _ => <Widget>[],
    };

    // On web, wrap each sliver with centered max-width constraint
    if (kIsWeb) {
      return slivers.map((sliver) => SliverWebContentWrapper.chat(sliver: sliver)).toList();
    }

    return slivers;
  }

  List<Widget> _buildPinnedHeaders() {
    final topPadding = MediaQuery.of(context).padding.top;

    switch (_selectedIndex) {
      case 0: // Post a Job tab - pin the chip selector (uncommented for Manual Entry)
        return [
          SliverPersistentHeader(
            pinned: true,
            delegate: PinnedHeaderDelegate(
              height: 46.0,
              safeAreaPadding: topPadding, // This handles the notch when pinned
              child: Container(
                color: Colors.white,
                child: SafeArea(
                  top: false, // Don't double-add top padding
                  bottom: false,
                  child: Container(
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
                    child: kIsWeb
                        ? WebTabNavigation(
                            tabs: [
                              WebTab(icon: Icons.upload_file, text: AppLocalizations.of(context)!.uploadData),
                              WebTab(icon: Icons.auto_awesome, text: AppLocalizations.of(context)!.aiChat),
                              WebTab(icon: Icons.edit, text: AppLocalizations.of(context)!.manualEntry),
                            ],
                            selectedIndex: _createTabController.index,
                            onTabSelected: (index) {
                              setState(() {
                                _createTabController.animateTo(index);
                              });
                            },
                            selectedColor: ExColors.yellow, // Yellow
                          )
                        : TabBar(
                            controller: _createTabController,
                            tabs: [
                              Tab(icon: Icon(Icons.upload_file), text: AppLocalizations.of(context)!.uploadData),
                              Tab(icon: Icon(Icons.auto_awesome), text: AppLocalizations.of(context)!.aiChat),
                              Tab(icon: Icon(Icons.edit), text: AppLocalizations.of(context)!.manualEntry),
                            ],
                            labelColor: ExColors.yellow, // Yellow
                            unselectedLabelColor: Colors.grey,
                            indicatorColor: ExColors.yellow, // Yellow
                          ),
                  ),
                ),
              ),
            ),
          ),
        ];
      case 1: // Events tab - pin the chip bar navigation (desktop: opaque)
        return [
          SliverPersistentHeader(
            pinned: true,
            delegate: PinnedHeaderDelegate(
              height: 58.0,
              safeAreaPadding: topPadding,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    bottom: BorderSide(
                      color: ExColors.borderGrey.withValues(alpha: 0.5),
                      width: 0.5,
                    ),
                  ),
                ),
                child: SafeArea(
                  top: false,
                  bottom: false,
                  child: _buildJobsSearchSortBar(
                    pendingCount: _filterEvents(_eventsPending).length,
                    availableCount: _filterEvents(_eventsAvailable).length,
                    fullCount: _filterEvents(_eventsFull).length,
                    completedCount: _filterEvents(_eventsCompleted).length,
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
                                  decoration: InputDecoration(
                                    prefixIcon: Icon(Icons.search),
                                    hintText: AppLocalizations.of(context)!.searchNameOrEmail,
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
                                  label: Text(AppLocalizations.of(context)!.all),
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
      case 4: // Catalog tab - pin the chip bar navigation
        return [
          SliverPersistentHeader(
            pinned: true,
            delegate: PinnedHeaderDelegate(
              height: 50.0,
              safeAreaPadding: topPadding,
              child: Container(
                color: Colors.white,
                child: SafeArea(
                  top: false,
                  bottom: false,
                  child: Container(
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
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildFilterChipBar(
                            labels: ['Clients', 'Roles', 'Tariffs', 'Staff'],
                            counts: [
                              _clients?.length ?? 0,
                              _roles?.length ?? 0,
                              _tariffs?.length ?? 0,
                              _staffMembers?.length ?? 0,
                            ],
                            selectedIndex: _catalogTabController.index,
                            onSelected: (index) {
                              setState(() {
                                _catalogTabController.animateTo(index);
                              });
                            },
                            activeColor: ExColors.navySpaceCadet,
                          ),
                        ),
                        if (_catalogTabController.index < 3)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: IconButton(
                              icon: Icon(
                                _isMergeMode ? Icons.close : Icons.call_merge,
                                color: _isMergeMode ? ExColors.errorDark : ExColors.techBlue,
                                size: 22,
                              ),
                              tooltip: _isMergeMode ? 'Exit merge mode' : 'Merge duplicates',
                              onPressed: _toggleMergeMode,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                            ),
                          ),
                      ],
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
      case 0: // Post a Job tab
        return TabBarView(
          controller: _createTabController,
          children: [
            _buildUploadTab(),
            _buildChatTab(),
            _buildManualEntryTab(),
          ],
        );
      case 1: // Events tab
        // For desktop/web, render events directly based on selected tab index
        // This avoids nested scrollable conflicts with NestedScrollView
        print('[RENDER] Events tab - controller index: ${_eventsTabController.index}, Completed items: ${_eventsCompleted?.length ?? 0}');
        final filteredPending = _filterEvents(_eventsPending);
        final filteredAvailable = _filterEvents(_eventsAvailable);
        final filteredFull = _filterEvents(_eventsFull);
        final filteredCompleted = _filterEvents(_eventsCompleted);
        if (kIsWeb || ResponsiveLayout.shouldUseDesktopLayout(context)) {
          // Directly return the content for the selected tab
          switch (_eventsTabController.index) {
            case 0:
              print('[RENDER] Showing PENDING: ${filteredPending.length} items');
              return _eventsInner(filteredPending, header: _buildExpiredEventsBanner(_eventsExpired?.length ?? 0)); // Pending tab
            case 1:
              print('[RENDER] Showing POSTED: ${filteredAvailable.length} items');
              return _eventsInner(filteredAvailable, header: _buildExpiredEventsBanner(_eventsExpired?.length ?? 0)); // Posted tab
            case 2:
              print('[RENDER] Showing FULL: ${filteredFull.length} items');
              return _eventsInner(filteredFull); // Full tab
            case 3:
              print('[RENDER] Showing COMPLETED: ${filteredCompleted.length} items');
              return _eventsInner(filteredCompleted); // Completed tab
            default:
              return _eventsInner(filteredPending);
          }
        } else {
          // For mobile, use TabBarView for swipe gestures
          return TabBarView(
            controller: _eventsTabController,
            children: [
              _eventsInner(filteredPending, header: _buildExpiredEventsBanner(_eventsExpired?.length ?? 0)), // Pending tab
              _eventsInner(filteredAvailable, header: _buildExpiredEventsBanner(_eventsExpired?.length ?? 0)), // Posted tab
              _eventsInner(filteredFull), // Full tab
              _eventsInner(filteredCompleted), // Completed tab
            ],
          );
        }
      case 2: // Chat tab
        return _buildChatContent();
      case 3: // Hours tab
        return const HoursApprovalListScreen();
      case 4: // Catalog tab
        // For web/desktop, render catalog directly with TabBarView
        if (kIsWeb || ResponsiveLayout.shouldUseDesktopLayout(context)) {
          return Stack(
            children: [
              TabBarView(
                controller: _catalogTabController,
                children: [
                  _buildClientsInner(),
                  _buildRolesInner(),
                  _buildTariffsInner(),
                  _buildStaffInner(),
                ],
              ),
              // Floating Action Button for adding items (hide during merge mode)
              if (!_isMergeMode)
                Positioned(
                  bottom: 120,
                  right: 20,
                  child: FloatingActionButton(
                    onPressed: _showAddItemDialog,
                    backgroundColor: Colors.white.withOpacity(0.9),
                    elevation: 4,
                    child: const Icon(
                      Icons.add,
                      color: ExColors.yellow,
                      size: 28,
                    ),
                  ),
                ),
              // Merge action button
              if (_isMergeMode && _mergeSelectedIds.length >= 2)
                Positioned(
                  bottom: 120,
                  left: 20,
                  right: 20,
                  child: Center(
                    child: ElevatedButton.icon(
                      onPressed: _isMerging ? null : _showMergeTargetDialog,
                      icon: _isMerging
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.call_merge),
                      label: Text('Merge ${_mergeSelectedIds.length} items'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ExColors.techBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                        elevation: 6,
                      ),
                    ),
                  ),
                ),
            ],
          );
        }
        // Mobile uses slivers
        return Container();
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
    final statusBarHeight = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: ExColors.backgroundLight,
      body: RefreshIndicator(
        onRefresh: () async {
          // Only refresh events when on Events tab
          if (_selectedIndex == 1) {
            await _refreshEvents();
          }
          // Could add refresh logic for other tabs here if needed
        },
        // Customize colors to match app theme
        color: ExColors.techBlue,
        backgroundColor: Colors.white,
        child: NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            _handleScroll(notification);
            return false;
          },
          child: Stack(
            children: [
              // Main scrollable content - Full screen
              CustomScrollView(
                controller: _mainScrollController,
                slivers: [
                // Top padding to show first card below header initially
                // Only add padding for tabs that use sliver content (not Catalog which uses TabBarView)
                if (_selectedIndex != 4)
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: statusBarHeight + 120, // Dynamic based on device + header height
                    ),
                  ),
                ..._buildSliverContent(),
                // Add bottom padding for last card (only for tabs with sliver content)
                if (_selectedIndex != 4)
                  const SliverToBoxAdapter(
                    child: SizedBox(
                      height: 100, // Bottom padding for scrolling past bottom bar
                    ),
                  ),
              ],
            ),

              // Animated app bar (overlaid) - Facebook style with persistent safe area
              Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: AnnotatedRegion<SystemUiOverlayStyle>(
                value: const SystemUiOverlayStyle(
                  statusBarColor: Colors.transparent,
                  statusBarIconBrightness: Brightness.light,
                  statusBarBrightness: Brightness.dark,
                ),
                child: RepaintBoundary(
                  child: AnimatedBuilder(
                    animation: _headerAnimation,
                    builder: (context, child) {
                      return Container(
                        decoration: const BoxDecoration(
                          // Navy dominant gradient with subtle ocean blue accent
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              ExColors.navySpaceCadet, // Navy (dominant)
                              ExColors.navySpaceCadet, // Navy extended
                              ExColors.oceanBlue, // Ocean blue (subtle accent)
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Safe area background - always visible, extends to absolute top
                            SizedBox(
                              height: statusBarHeight,
                            ),
                            // Animated toolbar content - shrinks and fades
                            if (_headerAnimation.value > 0.01)
                              ClipRect(
                                child: Align(
                                  alignment: Alignment.topCenter,
                                  heightFactor: _headerAnimation.value,
                                  child: Opacity(
                                    opacity: _headerAnimation.value,
                                    child: SizedBox(
                                      height: kToolbarHeight,
                                      child: Row(
                                        children: [
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: Text(
                                              _getAppBarTitle(),
                                              style: const TextStyle(
                                                color: ExColors.yellow,
                                                fontSize: 24,
                                                fontWeight: FontWeight.w800,
                                                letterSpacing: 0.5,
                                                shadows: [
                                                  Shadow(
                                                    color: Colors.black26,
                                                    offset: Offset(0, 2),
                                                    blurRadius: 4,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          _buildProfileMenu(context),
                                          const SizedBox(width: 8),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),

            // Animated tab selector (overlaid)
            AnimatedBuilder(
              animation: _headerAnimation,
              builder: (context, child) {
                // Position dynamically based on toolbar height
                final toolbarHeight = kToolbarHeight * _headerAnimation.value;

                return Positioned(
                  top: statusBarHeight + toolbarHeight,
                  left: 0,
                  right: 0,
                  child: RepaintBoundary(
                    child: IgnorePointer(
                      ignoring: _headerAnimation.value < 0.1, // Ignore when almost invisible
                      child: Opacity(
                        opacity: _headerAnimation.value,
                        child: child,
                      ),
                    ),
                  ),
                );
              },
              child: _buildTabSelector(),
            ),

            // Floating "New Job" chip for Events/Jobs tab (like email apps)
            if (_selectedIndex == 1)
              Positioned(
                bottom: 100, // Above bottom nav
                right: 16,
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AIChatScreen(),
                      ),
                    );
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    padding: EdgeInsets.symmetric(
                      horizontal: _isJobChipExpanded ? 18 : 14,
                      vertical: _isJobChipExpanded ? 10 : 14,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.75),
                      borderRadius: BorderRadius.circular(_isJobChipExpanded ? 28 : 28),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.4),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                        BoxShadow(
                          color: ExColors.yellow.withOpacity(0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ClipRect(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: ExColors.textSecondary,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: ExColors.textSecondary.withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.add_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                            AnimatedSize(
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeInOut,
                              child: _isJobChipExpanded
                                  ? Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const SizedBox(width: 8),
                                        Text(
                                          'New ${context.read<TerminologyProvider>().singular}',
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            color: ExColors.textSecondary,
                                            letterSpacing: -0.2,
                                          ),
                                        ),
                                      ],
                                    )
                                  : const SizedBox.shrink(),
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
        ),
      ),
    );
  }

  Widget _buildTabSelector() {
    // ===== DASHBOARD (POST A JOB) TAB SELECTOR COMMENTED OUT - SAVED FOR FUTURE USE =====
    // // Post a Job tab - floating header card
    // if (_selectedIndex == 0) {
    //   return Container(
    //     margin: const EdgeInsets.all(16),
    //     decoration: BoxDecoration(
    //       borderRadius: BorderRadius.circular(16),
    //       boxShadow: [
    //         BoxShadow(
    //           color: Colors.black.withOpacity(0.1),
    //           blurRadius: 10,
    //           offset: const Offset(0, 4),
    //         ),
    //       ],
    //     ),
    //     child: Column(
    //       mainAxisSize: MainAxisSize.min,
    //       children: [
    //         Container(
    //           padding: const EdgeInsets.all(16),
    //           decoration: const BoxDecoration(
    //             gradient: LinearGradient(
    //               colors: [Color(0xFFD4AF37), Color(0xFFFFD700)], // Golden gradient
    //               begin: Alignment.topLeft,
    //               end: Alignment.bottomRight,
    //             ),
    //             borderRadius: BorderRadius.only(
    //               topLeft: Radius.circular(16),
    //               topRight: Radius.circular(16),
    //             ),
    //           ),
    //           child: Row(
    //             children: [
    //               Container(
    //                 padding: const EdgeInsets.all(12),
    //                 decoration: BoxDecoration(
    //                   color: Colors.white.withOpacity(0.2),
    //                   borderRadius: BorderRadius.circular(12),
    //                 ),
    //                 child: const Icon(Icons.add_circle_outline, color: Colors.white, size: 24),
    //               ),
    //               const SizedBox(width: 12),
    //               Expanded(
    //                 child: Column(
    //                   crossAxisAlignment: CrossAxisAlignment.start,
    //                   children: [
    //                     const Text(
    //                       'Post a New Job',
    //                       style: TextStyle(
    //                         color: Colors.white,
    //                         fontSize: 18,
    //                         fontWeight: FontWeight.w600,
    //                       ),
    //                     ),
    //                     const SizedBox(height: 4),
    //                     Text(
    //                       'Upload, create with AI, or enter manually',
    //                       style: TextStyle(
    //                         color: Colors.white.withOpacity(0.9),
    //                         fontSize: 12,
    //                       ),
    //                     ),
    //                   ],
    //                 ),
    //               ),
    //             ],
    //           ),
    //         ),
    //         Container(
    //           decoration: const BoxDecoration(
    //             color: Colors.white,
    //             borderRadius: BorderRadius.only(
    //               bottomLeft: Radius.circular(16),
    //               bottomRight: Radius.circular(16),
    //             ),
    //           ),
    //           child: TabBar(
    //             controller: _createTabController,
    //             tabs: [
    //               Tab(icon: Icon(Icons.upload_file), text: AppLocalizations.of(context)!.uploadData),
    //               Tab(icon: Icon(Icons.auto_awesome), text: AppLocalizations.of(context)!.aiChat),
    //               Tab(icon: Icon(Icons.edit), text: AppLocalizations.of(context)!.manualEntry),
    //             ],
    //             labelColor: ExColors.yellow,
    //             unselectedLabelColor: Colors.grey,
    //             indicatorColor: ExColors.yellow,
    //           ),
    //         ),
    //       ],
    //     ),
    //   );
    // }
    // ===== END DASHBOARD TAB SELECTOR =====

    // Events/Jobs tab - compact chip bar with search & sort (frosted glass)
    if (_selectedIndex == 1) {
      final pendingCount = _filterEvents(_eventsPending).length;
      final availableCount = _filterEvents(_eventsAvailable).length;
      final fullCount = _filterEvents(_eventsFull).length;
      final pastCount = _filterEvents(_eventsCompleted).length;

      return ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.7),
              border: Border(
                bottom: BorderSide(
                  color: ExColors.borderGrey.withValues(alpha: 0.4),
                  width: 0.5,
                ),
              ),
            ),
            child: _buildJobsSearchSortBar(
              pendingCount: pendingCount,
              availableCount: availableCount,
              fullCount: fullCount,
              completedCount: pastCount,
            ),
          ),
        ),
      );
    }

    // Catalog tab - compact chip bar
    if (_selectedIndex == 4) {
      final clientsCount = _clients?.length ?? 0;
      final rolesCount = _roles?.length ?? 0;
      final tariffsCount = _tariffs?.length ?? 0;
      final staffCount = _staffMembers?.length ?? 0;

      return Row(
        children: [
          Expanded(
            child: _buildFilterChipBar(
              labels: ['Clients', 'Roles', 'Tariffs', 'Staff'],
              counts: [clientsCount, rolesCount, tariffsCount, staffCount],
              selectedIndex: _catalogTabController.index,
              onSelected: (index) {
                setState(() {
                  _catalogTabController.animateTo(index);
                });
              },
              activeColor: ExColors.navySpaceCadet,
            ),
          ),
          if (_catalogTabController.index < 3)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: IconButton(
                icon: Icon(
                  _isMergeMode ? Icons.close : Icons.call_merge,
                  color: _isMergeMode ? ExColors.errorDark : ExColors.techBlue,
                  size: 22,
                ),
                tooltip: _isMergeMode ? 'Exit merge mode' : 'Merge duplicates',
                onPressed: _toggleMergeMode,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
            ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildFilterChipBar({
    required List<String> labels,
    required List<int> counts,
    required int selectedIndex,
    required ValueChanged<int> onSelected,
    required Color activeColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(labels.length, (index) {
            final isActive = index == selectedIndex;
            return Padding(
              padding: EdgeInsets.only(right: index < labels.length - 1 ? 8 : 0),
              child: GestureDetector(
                onTap: () => onSelected(index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isActive ? const Color(0xFF1B2A4A) : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isActive ? const Color(0xFF1B2A4A) : Colors.grey[300]!,
                    ),
                  ),
                  child: Text(
                    '${labels[index]} (${counts[index]})',
                    style: TextStyle(
                      color: isActive ? Colors.white : ExColors.textPrimary,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildDesktopLayout(BuildContext context) {
    return Scaffold(
      backgroundColor: ExColors.backgroundLight,
      body: Stack(
        children: [
          Row(
            children: [
              // Navigation Rail - hide when used inside MainScreen
              if (!widget.hideNavigationRail)
                _buildNavigationRail(context),
              // Content
              Expanded(
                child: Column(
                  children: [
                    // Desktop app bar - only show when navigation rail is hidden (used inside MainScreen)
                    if (widget.hideNavigationRail)
                      _buildDesktopAppBar(context),
                    // Main content
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
          // Floating "New Job" button for Jobs tab
          if (_selectedIndex == 1)
            Positioned(
              bottom: 40,
              right: 40,
              child: FloatingActionButton.extended(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AIChatScreen(),
                    ),
                  );
                },
                backgroundColor: ExColors.yellow,
                elevation: 8,
                icon: const Icon(Icons.add_rounded, color: Colors.white),
                label: Text(
                  'New ${context.read<TerminologyProvider>().singular}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
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
        gradient: ExtractionTheme.header,
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
                  // ===== DASHBOARD (POST A JOB) COMMENTED OUT - SAVED FOR FUTURE USE =====
                  // _buildNavRailItem(
                  //   0,
                  //   Icons.add_circle_outline,
                  //   AppLocalizations.of(context)!.navCreate,
                  // ),
                  // ===== END DASHBOARD NAVIGATION =====
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
              // Reset chip to expanded when switching to Jobs tab
              if (index == 1) {
                _isJobChipExpanded = true;
              }
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
                      color: ExColors.textPrimary,
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
            // Reset chip to expanded when switching to Jobs tab
            if (index == 1) {
              _isJobChipExpanded = true;
            }
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

  // Removed _buildCompactChip - now using TabBar instead

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
    return InitialsAvatar(
      imageUrl: _profilePictureUrl,
      firstName: _profileFirstName,
      lastName: _profileLastName,
      radius: 16,
    );
  }

  Future<void> _loadProfilePicture() async {
    try {
      final me = await _managerService.getMe();
      SocketManager.instance.registerManager(me.id);
      if (!mounted) return;
      setState(() {
        _profilePictureUrl = me.picture;
        _profileFirstName = me.firstName;
        _profileLastName = me.lastName;
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
        await RouteErrorManager.instance.navigateSafely(
          context,
          () => const LoginPage(),
          clearStack: true,
        );
      }
    }
  }

  List<Widget> _buildCreateSlivers() {
    // Return the current tab's content directly as slivers
    switch (_createTabController.index) {
      case 0: // Upload tab
        return [
          SliverToBoxAdapter(
            child: _buildUploadTab(),
          ),
        ];
      case 1: // AI Chat tab
        return _buildAIChatSlivers();
      case 2: // Manual Entry tab
        // Return manual entry form as slivers for full-screen scrolling
        return _buildManualEntrySlivers();
      default:
        return [
          SliverToBoxAdapter(
            child: Container(),
          ),
        ];
    }
  }

  List<Widget> _buildAIChatSlivers() {
    // Get the viewport height to create a fixed height container
    final viewportHeight = MediaQuery.of(context).size.height -
        MediaQuery.of(context).padding.top -
        200 - // Header height
        100; // Bottom padding

    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(top: 20, bottom: 20),
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 800),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              height: viewportHeight.clamp(400, double.infinity),
              child: _buildChatTab(),
            ),
          ),
        ),
      ),
    ];
  }

  List<Widget> _buildManualEntrySlivers() {
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(top: 20, bottom: 20),
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 800),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _buildManualEntryForm(),
            ),
          ),
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
            TabBar(
              tabs: [
                Tab(icon: Icon(Icons.upload_file), text: AppLocalizations.of(context)!.uploadData),
                Tab(icon: Icon(Icons.edit), text: AppLocalizations.of(context)!.manualEntry),
                Tab(icon: Icon(Icons.cloud_upload), text: AppLocalizations.of(context)!.multiUpload),
                Tab(icon: Icon(Icons.chat), text: AppLocalizations.of(context)!.aiChat),
              ],
              labelColor: ExColors.techBlue,
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
                gradientColors: const [ExColors.info, ExColors.techBlue], // Teal to blue
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
                    label: Text(AppLocalizations.of(context)!.selectFiles),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ExColors.techBlue,
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
                        backgroundColor: ExColors.techBlue,
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
                        backgroundColor: ExColors.successDark,
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
                          ? ExColors.successDark
                          : status == 'error'
                          ? ExColors.errorDark
                          : ExColors.techBlue,
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
                            color: ExColors.errorDark,
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
    final name = (data['shift_name'] ?? data['venue_name'] ?? 'Untitled')
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
        final id = _fileProcessorService.resolvePlatformFileId(f);
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

        // Use FileProcessorService for bulk item processing
        final processResult = await _fileProcessorService.processBulkItem(original);

        if (processResult.success) {
          setState(() {
            _bulkItems = List.of(_bulkItems);
            _bulkItems[currentIndex] = {
              ..._bulkItems[currentIndex],
              'status': 'done',
              'data': processResult.structuredData,
              'bytes': null,
            };
          });
        } else {
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

    final fileName = item['name']?.toString() ?? 'File';
    await saveToPendingWithFeedback(
      data,
      customMessage: 'Saved to Pending ($fileName)',
    );

    if (!mounted) return;
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
      await saveToPending(d);
    }
    if (!mounted) return;
    showSuccessSnackBar('All ready items saved to Pending');
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
      // Use userKey if available (from /chat/contacts), otherwise construct from provider:subject (from /users)
      final userId = u['userKey']?.toString() ?? '${u['provider']}:${u['subject']}';
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
      // Use ChatService.fetchContacts() instead of UsersService.fetchUsers()
      // This endpoint returns only team members and includes conversation status
      final contacts = await _chatService.fetchContacts(
        searchQuery: _userSearchCtrl.text.trim().isNotEmpty
          ? _userSearchCtrl.text.trim()
          : null,
      );
      setState(() {
        _users = contacts;
        _usersNextCursor = null; // Contacts endpoint doesn't use pagination yet
        _isUsersLoading = false;
      });
    } catch (e) {
      setState(() {
        _isUsersLoading = false;
      });
      if (!mounted) return;

      // Show user-friendly error message
      final errorMsg = e.toString().contains('don\'t have any team members')
        ? 'You don\'t have any team members yet. Create an invite link to add members to your team!'
        : 'Failed to load contacts: $e';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMsg),
          backgroundColor: e.toString().contains('don\'t have any team members')
            ? ExColors.techBlue // Blue for info
            : ExColors.errorDark, // Red for errors
        ),
      );
    }
  }

  Future<void> _loadMoreUsers() async {
    // Contacts endpoint doesn't support pagination yet
    // This method is kept for compatibility but does nothing
    // In the future, if pagination is added to /chat/contacts, implement it here
    return;
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
            color: ExColors.backgroundLight,
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
                        label: Text(AppLocalizations.of(context)!.all),
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
        // Use userKey if available (from /chat/contacts), otherwise construct from provider:subject (from /users)
        final userKey = u['userKey']?.toString() ?? '${u['provider']}:${u['subject']}';
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
      color: ExColors.backgroundLight,
      child: Text(
        '$title ($count)',
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: ExColors.textSecondary,
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
    // Use userKey if available (from /chat/contacts), otherwise construct from provider:subject (from /users)
    final userId = u['userKey']?.toString() ?? '${u['provider']}:${u['subject']}';
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
              PopupMenuItem(
                value: 'view',
                child: ListTile(
                  leading: Icon(Icons.event),
                  title: Text(AppLocalizations.of(context)!.viewJobs),
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
                        decoration: InputDecoration(
                          prefixIcon: Icon(Icons.search),
                          hintText: AppLocalizations.of(context)!.searchNameOrEmail,
                          border: OutlineInputBorder(),
                        ),
                        onSubmitted: (_) => _loadFirstUsersPage(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _loadFirstUsersPage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ExColors.techBlue,
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
                        label: Text(AppLocalizations.of(context)!.all),
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
    // Show empty state when no users AND not loading
    if (_users.isEmpty && !_isUsersLoading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.people_outline, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                'No team members yet',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Create an invite link to add members to your team!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  // Navigate to Teams tab
                  setState(() => _selectedIndex = 2);
                },
                icon: const Icon(Icons.group_add),
                label: const Text('Go to Teams'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ExColors.techBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Show favorite filter empty state
    if (_filteredUsers.isEmpty && _selectedRole != null && !_isUsersLoading) {
      return Center(
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
      );
    }

    return NotificationListener<ScrollNotification>(
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
                // Use userKey if available (from /chat/contacts), otherwise construct from provider:subject (from /users)
                final userId = u['userKey']?.toString() ?? '${u['provider']}:${u['subject']}';
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
              Row(
                children: [
                  Expanded(
                    child: ActionCard(
                      title: 'Single Upload',
                      description: 'Upload one PDF or image file',
                      icon: Icons.upload_file,
                      actionText: isLoading ? 'Processing...' : 'Choose 1 File',
                      onPressed: _pickAndProcessFile,
                      isLoading: isLoading,
                      color: ExColors.techBlue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ActionCard(
                      title: 'Multi Upload',
                      description: 'Upload multiple files at once',
                      icon: Icons.folder_open,
                      actionText: _isBulkProcessing ? 'Processing...' : 'Choose Multiple Files',
                      onPressed: () => _pickAndProcessMultipleFiles(append: false),
                      isLoading: _isBulkProcessing,
                      color: ExColors.yellow,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (_bulkItems.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Uploaded Files (${_bulkItems.length})',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (_bulkItems.any((e) => e['data'] != null))
                            ElevatedButton.icon(
                              onPressed: _isBulkProcessing ? null : _confirmAllBulkToPending,
                              icon: const Icon(Icons.done_all, size: 18),
                              label: const Text('Confirm All'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: ExColors.successDark,
                                foregroundColor: Colors.white,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ..._bulkItems.asMap().entries.map((entry) {
                        final int index = entry.key;
                        final Map<String, dynamic> item = entry.value;
                        final String name = (item['name'] ?? 'File').toString();
                        final String status = (item['status'] ?? 'queued').toString();
                        final Map<String, dynamic>? data = (item['data'] as Map?)?.cast<String, dynamic>();
                        final String subtitle = data == null
                            ? status[0].toUpperCase() + status.substring(1)
                            : _summarizeEvent(data);
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: ListTile(
                            dense: true,
                            leading: Icon(
                              data != null ? Icons.check_circle : status == 'error' ? Icons.error : Icons.hourglass_bottom,
                              color: data != null ? ExColors.successDark : status == 'error' ? ExColors.errorDark : ExColors.techBlue,
                              size: 20,
                            ),
                            title: Text(name, style: const TextStyle(fontSize: 13)),
                            subtitle: Text(subtitle, style: const TextStyle(fontSize: 11)),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (data != null)
                                  TextButton(
                                    onPressed: () => _confirmSingleBulkToPending(index),
                                    child: const Text('Confirm', style: TextStyle(fontSize: 12)),
                                  ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 18),
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
                const SizedBox(height: 20),
              ],
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

                      // Save to backend as draft
                      try {
                        payload['status'] = 'draft';
                        final createdEvent = await _eventService.createEvent(payload);
                        if (!mounted) return;

                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Saved to Pending'),
                            backgroundColor: ExColors.successDark,
                          ),
                        );
                        await _draftService.clearDraft();
                        await _loadEvents();
                        // Navigate to Events tab to show the new event
                        setState(() {
                          _selectedIndex = 1; // Events tab
                          _eventsTabController.animateTo(0); // Pending subtab
                        });
                      } catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Failed to save: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.save, size: 18),
                    label: Text(AppLocalizations.of(context)!.saveToPending),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ExColors.techBlue,
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
      return (a['shift_name'] ?? '').toString().compareTo(
        (b['shift_name'] ?? '').toString(),
      );
    }
    if (aDate == null) return 1;
    if (bDate == null) return -1;
    final cmp = aDate.compareTo(bDate);
    if (cmp != 0) return cmp;
    return (a['shift_name'] ?? '').toString().compareTo(
      (b['shift_name'] ?? '').toString(),
    );
  }

  int _compareEventsDescending(Map<String, dynamic> a, Map<String, dynamic> b) {
    final DateTime? aDate = _eventDateTime(a);
    final DateTime? bDate = _eventDateTime(b);
    if (aDate == null && bDate == null) {
      return (a['shift_name'] ?? '').toString().compareTo(
        (b['shift_name'] ?? '').toString(),
      );
    }
    if (aDate == null) return 1;
    if (bDate == null) return -1;
    final cmp = bDate.compareTo(aDate);
    if (cmp != 0) return cmp;
    return (a['shift_name'] ?? '').toString().compareTo(
      (b['shift_name'] ?? '').toString(),
    );
  }

  // =========================================================================
  // SEARCH & SORT HELPERS
  // =========================================================================

  List<Map<String, dynamic>> _filterEvents(List<Map<String, dynamic>>? events) {
    if (events == null) return const [];
    if (_searchQuery.isEmpty) return events;
    return events.where((event) {
      // Match against core text fields
      final fields = [
        event['client_name'],
        event['shift_name'],
        event['venue_name'],
        event['venue_address'],
        event['start_time'],
        event['end_time'],
      ];
      for (final f in fields) {
        if (f != null && f.toString().toLowerCase().contains(_searchQuery)) {
          return true;
        }
      }
      // Match formatted date (e.g. "Mar", "2025-03")
      final rawDate = event['date']?.toString();
      if (rawDate != null && rawDate.isNotEmpty) {
        if (rawDate.toLowerCase().contains(_searchQuery)) return true;
        try {
          final dt = DateTime.parse(rawDate);
          // Month names
          const months = [
            'january', 'february', 'march', 'april', 'may', 'june',
            'july', 'august', 'september', 'october', 'november', 'december',
          ];
          const monthsShort = [
            'jan', 'feb', 'mar', 'apr', 'may', 'jun',
            'jul', 'aug', 'sep', 'oct', 'nov', 'dec',
          ];
          final monthIdx = dt.month - 1;
          if (months[monthIdx].contains(_searchQuery) ||
              monthsShort[monthIdx].contains(_searchQuery)) {
            return true;
          }
          // Day of month
          if (dt.day.toString() == _searchQuery) return true;
        } catch (_) {}
      }
      // Match role names
      final roles = (event['roles'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      for (final role in roles) {
        if ((role['role'] ?? '').toString().toLowerCase().contains(_searchQuery)) {
          return true;
        }
      }
      // Match accepted staff names
      final staff = (event['accepted_staff'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      for (final s in staff) {
        final name = (s['name'] ?? s['user_name'] ?? '').toString().toLowerCase();
        if (name.contains(_searchQuery)) return true;
      }
      return false;
    }).toList();
  }

  List<Map<String, dynamic>> _sortEvents(List<Map<String, dynamic>> events) {
    final sorted = [...events];
    switch (_sortMode) {
      case _SortMode.dateAsc:
        sorted.sort(_compareEventsAscending);
        break;
      case _SortMode.dateDesc:
        sorted.sort(_compareEventsDescending);
        break;
      case _SortMode.lastCreated:
        sorted.sort((a, b) {
          // MongoDB ObjectIDs are time-sortable; fallback to createdAt
          final aId = (a['_id'] ?? a['createdAt'] ?? '').toString();
          final bId = (b['_id'] ?? b['createdAt'] ?? '').toString();
          return bId.compareTo(aId); // descending = newest first
        });
        break;
    }
    return sorted;
  }

  void _onSearchChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _searchQuery = _searchController.text.toLowerCase().trim();
        });
      }
    });
  }

  void _dismissSearch() {
    _searchController.clear();
    setState(() {
      _isSearchActive = false;
      _searchQuery = '';
    });
  }

  /// Unified search/sort bar used in both mobile pinned header and desktop tab bar.
  Widget _buildJobsSearchSortBar({
    required int pendingCount,
    required int availableCount,
    required int fullCount,
    required int completedCount,
  }) {
    // Chips use padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10)
    // Match that vertical padding so search aligns with chip row position
    return SizedBox(
      height: 58,
      child: AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      switchInCurve: Curves.easeInOut,
      switchOutCurve: Curves.easeInOut,
      transitionBuilder: (child, animation) {
        final isSearch = child.key == const ValueKey('search');
        // Chips → Search: chips scale down 1.0→0.95, search scales up 0.95→1.0
        final scaleTween = isSearch
            ? Tween<double>(begin: 0.95, end: 1.0)
            : Tween<double>(begin: 0.95, end: 1.0);
        final slideTween = isSearch
            ? Tween<Offset>(begin: const Offset(0.08, 0.0), end: Offset.zero)
            : Tween<Offset>(begin: const Offset(-0.03, 0.0), end: Offset.zero);
        return SlideTransition(
          position: slideTween.animate(CurvedAnimation(
            parent: animation,
            curve: Curves.easeInOut,
          )),
          child: ScaleTransition(
            scale: scaleTween.animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeInOut,
            )),
            child: FadeTransition(
              opacity: CurvedAnimation(parent: animation, curve: Curves.easeIn),
              child: child,
            ),
          ),
        );
      },
      child: _isSearchActive
        ? Padding(
            key: const ValueKey('search'),
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
            child: Row(
              children: [
                // Back button — slides in from left
                TweenAnimationBuilder<Offset>(
                  tween: Tween<Offset>(begin: const Offset(-0.3, 0), end: Offset.zero),
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  builder: (context, offset, child) => FractionalTranslation(
                    translation: offset,
                    child: child,
                  ),
                  child: _buildToolButton(
                    icon: Icons.arrow_back_rounded,
                    onTap: _dismissSearch,
                  ),
                ),
                const SizedBox(width: 8),
                // Search field — chip-sized with rounded pill shape
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 12),
                          child: Icon(Icons.search_rounded, size: 16, color: ExColors.slateGray),
                        ),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            autofocus: true,
                            textAlignVertical: TextAlignVertical.center,
                            decoration: InputDecoration(
                              hintText: 'Search jobs...',
                              hintStyle: TextStyle(
                                color: ExColors.slateGray,
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                              ),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                            ),
                            style: TextStyle(
                              fontSize: 14,
                              color: ExColors.textPrimary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        if (_searchQuery.isNotEmpty)
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () {
                                _searchController.clear();
                                _onSearchChanged();
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(6),
                                child: Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    color: ExColors.navySpaceCadet.withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.close_rounded, size: 13, color: ExColors.navySpaceCadet),
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(width: 6),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                _buildSortButton(),
              ],
            ),
          )
        : Row(
            key: const ValueKey('chips'),
            children: [
              Expanded(
                child: _buildFilterChipBar(
                  labels: ['Pending', 'Posted', 'Full', 'Completed'],
                  counts: [pendingCount, availableCount, fullCount, completedCount],
                  selectedIndex: _eventsTabController.index,
                  onSelected: (index) {
                    setState(() {
                      _eventsTabController.animateTo(index);
                    });
                  },
                  activeColor: ExColors.navySpaceCadet,
                ),
              ),
              _buildToolButton(
                icon: Icons.search_rounded,
                onTap: () => setState(() { _isSearchActive = true; }),
              ),
              const SizedBox(width: 4),
              _buildSortButton(),
              const SizedBox(width: 8),
            ],
          ),
    ),
    );
  }

  /// Flat tool button — no background, border, or shadow
  Widget _buildToolButton({
    required IconData icon,
    required VoidCallback onTap,
    bool isActive = false,
  }) {
    return IconButton(
      icon: Icon(
        icon,
        size: 18,
        color: isActive ? ExColors.navySpaceCadet : Colors.grey[500],
      ),
      onPressed: onTap,
      splashRadius: 20,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
    );
  }

  Widget _buildSortButton() {
    final isCustomSort = _sortMode != _SortMode.dateAsc;
    return PopupMenuButton<_SortMode>(
      tooltip: 'Sort jobs',
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 12,
      color: Colors.white,
      offset: const Offset(0, 42),
      onSelected: (mode) => setState(() => _sortMode = mode),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(
          Icons.swap_vert_rounded,
          size: 18,
          color: isCustomSort ? ExColors.navySpaceCadet : Colors.grey[500],
        ),
      ),
      itemBuilder: (_) => [
        _buildSortMenuItem(_SortMode.dateAsc, 'Job Date', Icons.arrow_upward_rounded),
        _buildSortMenuItem(_SortMode.dateDesc, 'Job Date', Icons.arrow_downward_rounded),
        _buildSortMenuItem(_SortMode.lastCreated, 'Last Created', Icons.schedule_rounded),
      ],
    );
  }

  PopupMenuItem<_SortMode> _buildSortMenuItem(_SortMode mode, String label, IconData icon) {
    final isSelected = _sortMode == mode;
    return PopupMenuItem<_SortMode>(
      value: mode,
      height: 44,
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: isSelected
                  ? ExColors.navySpaceCadet.withValues(alpha: 0.1)
                  : ExColors.formFillSlate,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 15,
              color: isSelected ? ExColors.navySpaceCadet : ExColors.slateGray,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? ExColors.navySpaceCadet : ExColors.textPrimary,
              ),
            ),
          ),
          if (isSelected)
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: ExColors.navySpaceCadet,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_rounded, size: 12, color: Colors.white),
            ),
        ],
      ),
    );
  }

  /// Show past events in a bottom sheet
  Widget _buildExpiredEventsBanner(int count) {
    if (count == 0) return const SizedBox.shrink();
    return GestureDetector(
      onTap: _showExpiredEvents,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.orange.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: Colors.orange.shade700,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$count expired unfulfilled event${count == 1 ? '' : 's'}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.orange.shade900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Past events that were never fully staffed',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange.shade700,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: Colors.orange.shade700,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  void _showExpiredEvents() {
    final expiredEvents = List<Map<String, dynamic>>.from(_eventsExpired ?? []);
    final parentContext = context;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (context, scrollController) => Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Column(
              children: [
                // Handle bar
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
                      Icon(Icons.warning_amber_rounded, size: 24, color: Colors.orange.shade700),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Expired Unfulfilled (${expiredEvents.length})',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (expiredEvents.isNotEmpty)
                        TextButton.icon(
                          icon: const Icon(Icons.delete_sweep, size: 20, color: ExColors.errorDark),
                          label: const Text('Delete All', style: TextStyle(color: ExColors.errorDark, fontSize: 13)),
                          onPressed: () async {
                            final count = expiredEvents.length;
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Delete All Expired Events'),
                                content: Text('Delete all $count expired event${count == 1 ? '' : 's'}? This cannot be undone.'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, false),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, true),
                                    child: const Text('Delete All', style: TextStyle(color: ExColors.errorDark)),
                                  ),
                                ],
                              ),
                            );
                            if (confirm != true) return;

                            try {
                              for (final event in List<Map<String, dynamic>>.from(expiredEvents)) {
                                final eventId = (event['_id'] ?? event['id'] ?? '').toString();
                                if (eventId.isNotEmpty) {
                                  await _eventService.deleteEvent(eventId);
                                }
                              }
                              await _loadEvents();
                              if (!mounted) return;
                              Navigator.pop(bottomSheetContext);
                              ScaffoldMessenger.of(parentContext).showSnackBar(
                                SnackBar(content: Text('$count expired event${count == 1 ? '' : 's'} deleted')),
                              );
                            } catch (e) {
                              if (!mounted) return;
                              ScaffoldMessenger.of(parentContext).showSnackBar(
                                SnackBar(
                                  content: Text('Failed to delete: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          },
                        ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(bottomSheetContext),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                // Expired events list
                Expanded(
                  child: expiredEvents.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.event_busy, size: 64, color: Colors.grey),
                              SizedBox(height: 16),
                              Text(
                                'No expired events',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          controller: scrollController,
                          padding: const EdgeInsets.all(20),
                          itemCount: expiredEvents.length,
                          itemBuilder: (context, index) {
                            final event = expiredEvents[index];
                            final eventId = (event['_id'] ?? event['id'] ?? '').toString();
                            return Dismissible(
                              key: Key(eventId.isNotEmpty ? eventId : 'expired_$index'),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20),
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(Icons.delete, color: Colors.red.shade700),
                              ),
                              confirmDismiss: (direction) async {
                                return await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Delete Event'),
                                    content: const Text('Are you sure you want to delete this expired event?'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context, false),
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () => Navigator.pop(context, true),
                                        child: const Text('Delete', style: TextStyle(color: ExColors.errorDark)),
                                      ),
                                    ],
                                  ),
                                );
                              },
                              onDismissed: (direction) async {
                                setSheetState(() {
                                  expiredEvents.removeAt(index);
                                });
                                try {
                                  await _eventService.deleteEvent(eventId);
                                  await _loadEvents();
                                  if (!mounted) return;
                                  if (expiredEvents.isEmpty) {
                                    Navigator.pop(bottomSheetContext);
                                  }
                                } catch (e) {
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(parentContext).showSnackBar(
                                    SnackBar(
                                      content: Text('Failed to delete: $e'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              },
                              child: _buildEventCard(event, showMargin: true),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showPastEvents() {
    final pastEvents = _eventsCompleted ?? [];

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            children: [
              // Handle bar
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
                    const Icon(Icons.history, size: 24),
                    const SizedBox(width: 12),
                    Text(
                      'Past Events (${pastEvents.length})',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Past events list
              Expanded(
                child: pastEvents.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.event_busy, size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text(
                              'No past events',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.all(20),
                        itemCount: pastEvents.length,
                        itemBuilder: (context, index) {
                          return _buildEventCard(pastEvents[index], showMargin: true);
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Check if an event has open positions
  bool _hasOpenPositions(Map<String, dynamic> event) {
    final roles = (event['roles'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final acceptedStaff = (event['accepted_staff'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    // Calculate total needed across all roles
    int totalNeeded = 0;
    for (final role in roles) {
      totalNeeded += (role['count'] as int?) ?? 0;
    }

    // Calculate total accepted staff
    final totalAccepted = acceptedStaff.where((s) => s['response'] == 'accept').length;

    return totalAccepted < totalNeeded;
  }

  /// Calculate event capacity (filled vs total)
  Map<String, int> _calculateCapacity(Map<String, dynamic> event) {
    final roles = (event['roles'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final acceptedStaff = (event['accepted_staff'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    int totalNeeded = 0;
    for (final role in roles) {
      totalNeeded += (role['count'] as int?) ?? 0;
    }

    final totalFilled = acceptedStaff.where((s) => s['response'] == 'accept').length;

    return {'filled': totalFilled, 'total': totalNeeded};
  }

  /// Determine privacy status: 'private', 'public', or 'mix'
  String _getPrivacyStatus(Map<String, dynamic> event) {
    // Read from database field if available
    final visibilityType = event['visibilityType']?.toString();
    if (visibilityType != null) {
      // Map database values to display values
      if (visibilityType == 'private_public') {
        return 'private_public';
      }
      return visibilityType; // 'private' or 'public'
    }

    // Fallback to calculated logic for events without visibilityType field
    final status = (event['status'] ?? 'draft').toString();

    // Draft events are always private
    if (status == 'draft') {
      return 'private';
    }

    // For published events, check if had invitations before publishing
    if (status == 'published') {
      final publishedAtRaw = event['publishedAt'];
      final acceptedStaff = (event['accepted_staff'] as List?)?.cast<Map<String, dynamic>>() ?? [];

      if (publishedAtRaw != null && acceptedStaff.isNotEmpty) {
        try {
          final publishedAt = DateTime.parse(publishedAtRaw.toString());

          // Check if any staff accepted before the event was published
          for (final staff in acceptedStaff) {
            final respondedAtRaw = staff['respondedAt'];
            if (respondedAtRaw != null) {
              try {
                final respondedAt = DateTime.parse(respondedAtRaw.toString());
                if (respondedAt.isBefore(publishedAt)) {
                  return 'private_public'; // Had private invitations before publishing
                }
              } catch (_) {}
            }
          }
        } catch (_) {}
      }

      return 'public'; // Published without prior private invitations
    }

    // Fallback for other statuses
    return 'private';
  }

  /// Get privacy indicator color
  Color _getPrivacyColor(String privacyStatus) {
    switch (privacyStatus) {
      case 'private':
        return ExColors.techBlue; // Indigo
      case 'public':
        return ExColors.successDark; // Green
      case 'private_public':
      case 'mix': // Legacy fallback
        return ExColors.capacityMedium; // Amber/Orange
      default:
        return Colors.grey;
    }
  }

  /// Get capacity indicator color based on percentage filled
  Color _getCapacityColor(int filled, int total) {
    if (total == 0) return Colors.grey;

    final percentage = (filled / total) * 100;

    if (percentage >= 90) {
      return ExColors.errorDark; // Red
    } else if (percentage >= 50) {
      return ExColors.capacityMedium; // Orange
    } else {
      return ExColors.successDark; // Green
    }
  }

  /// Merges delta changes into existing events list
  /// Returns a new list with updates applied
  List<Map<String, dynamic>> _mergeDeltaEvents(
    List<Map<String, dynamic>> existing,
    List<Map<String, dynamic>> changes,
  ) {
    // Create a map for quick lookup by event ID
    final Map<String, Map<String, dynamic>> eventMap = {};

    // Add all existing events to the map
    for (final event in existing) {
      final id = (event['_id'] ?? event['id'])?.toString();
      if (id != null) {
        eventMap[id] = event;
      }
    }

    // Apply changes (updates or new events)
    for (final change in changes) {
      final id = (change['_id'] ?? change['id'])?.toString();
      if (id != null) {
        eventMap[id] = change; // Replace existing or add new
        print('[_mergeDeltaEvents] Updated/added event: $id');
      }
    }

    // Convert back to list
    return eventMap.values.toList();
  }

  /// Refreshes events with a full sync (forces complete reload)
  Future<void> _refreshEvents() async {
    print('[_refreshEvents] Force full sync');
    _eventService.clearLastSyncTimestamp();
    await _loadEvents();
  }

  /// Loads events with delta sync support for efficient updates
  Future<void> _loadEvents({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _isEventsLoading = true;
        _eventsError = null;
      });
    }
    try {
      print('[_loadEvents] Fetching events with userKey: $_viewerUserKey');

      // Use delta sync to only fetch changes
      final result = await _eventService.fetchEventsWithSync(
        userKey: _viewerUserKey,
        useDeltaSync: true,
      );

      print('[_loadEvents] Received: $result');

      List<Map<String, dynamic>> items;

      if (result.isDeltaSync && _events != null) {
        // Merge delta changes into existing events
        print('[_loadEvents] Merging ${result.events.length} delta changes');
        items = _mergeDeltaEvents(_events!, result.events);
      } else {
        // Full sync - replace everything
        print('[_loadEvents] Full sync with ${result.events.length} events');
        items = result.events;
      }

      // Helper: Parse date from event
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

      // Filter events into tabs (mutually exclusive)
      final List<Map<String, dynamic>> pending = [];
      final List<Map<String, dynamic>> available = [];
      final List<Map<String, dynamic>> full = [];
      final List<Map<String, dynamic>> past = [];
      final List<Map<String, dynamic>> expired = [];

      for (final e in items) {
        final status = (e['status'] ?? 'draft').toString();
        final d = parseDate(e);
        final eventName = (e['shift_name'] ?? e['client_name'] ?? 'Unknown').toString();
        final eventId = (e['_id'] ?? e['id'] ?? 'unknown').toString();

        // Check if event is past (FIXED: normalize both dates to midnight to avoid timezone issues)
        final bool isPast;
        if (d != null) {
          final eventDate = DateTime(d.year, d.month, d.day);
          final todayDate = DateTime(now.year, now.month, now.day);
          isPast = eventDate.isBefore(todayDate);
        } else {
          isPast = false;
        }

        // Debug: Log each event's status and classification with date details
        print('[EVENT] "$eventName" (ID: ${eventId.substring(0, 8)}...)');
        print('  Raw date: ${e['date']}');
        print('  Parsed date: $d');
        if (d != null) {
          print('  Event date normalized: ${DateTime(d.year, d.month, d.day)}');
          print('  Today date normalized: ${DateTime(now.year, now.month, now.day)}');
        }
        final hasOpenPos = _hasOpenPositions(e);
        final isFull = status == 'fulfilled' || !hasOpenPos;
        print('  Status: "$status", isPast: $isPast, hasOpenPositions: $hasOpenPos, isFull: $isFull');
        print('  → Will go to: ${status == 'draft' ? 'PENDING' : (status == 'completed' || (status == 'cancelled' && isPast) || (isFull && isPast)) ? 'COMPLETED' : isFull ? 'FULL' : 'POSTED'}');

        // Tab logic (priority order):
        // 1. Pending = draft events only
        // 2. Posted = published/confirmed events (accepting staff)
        // 3. Full = fulfilled status (all positions filled, event upcoming)
        // 4. Completed = finished events (status completed or past events)
        // Note: Backend now consistently sets 'fulfilled' status when positions are filled

        final visibilityType = e['visibilityType']?.toString() ?? 'unknown';

        if (status == 'draft') {
          // True drafts - not published yet
          pending.add(e);
          print('  → Classified as: PENDING (draft)');
        } else if (isFull && isPast) {
          // Completed = ONLY events that are both full AND past due
          // Events must have all positions filled to be considered "completed"
          past.add(e);
          print('  → Classified as: COMPLETED (isFull: $isFull, isPast: $isPast)');
        } else if (isFull) {
          // Full events that are NOT past (upcoming full events)
          full.add(e);
          print('  → Classified as: FULL (upcoming full event)');
        } else if (status == 'published' || status == 'confirmed' || status == 'in_progress' || status == 'completed') {
          // Published/confirmed/in-progress/completed events that are NOT full
          if (isPast) {
            // Past + not full → expired unfulfilled
            expired.add(e);
            print('  → Classified as: EXPIRED (past + not fully staffed)');
          } else {
            available.add(e);
            if (status == 'completed') {
              print('  → Classified as: POSTED (completed but not full - needs attention)');
            } else if (visibilityType == 'private') {
              print('  → Classified as: POSTED (published - private)');
            } else {
              print('  → Classified as: POSTED (published - public)');
            }
          }
        } else if (status == 'cancelled') {
          // Cancelled events go to Pending (as historical record)
          pending.add(e);
          print('  → Classified as: PENDING (cancelled event)');
        } else {
          // Fallback for other statuses
          pending.add(e);
          print('  → Classified as: PENDING (fallback for status: $status)');
        }
      }

      // Sort by date
      int ascByDate(Map<String, dynamic> a, Map<String, dynamic> b) {
        final da = parseDate(a);
        final db = parseDate(b);
        if (da == null && db == null) return 0;
        if (da == null) return 1;
        if (db == null) return -1;
        return da.compareTo(db);
      }

      pending.sort(ascByDate);
      available.sort(ascByDate);
      full.sort(ascByDate);
      past.sort((a, b) => ascByDate(b, a)); // most recent first
      expired.sort((a, b) => ascByDate(b, a)); // most recent first

      // IMPORTANT: Include ALL events (including completed) so delta sync
      // can properly merge changes. Previously completed events were excluded
      // which caused them to disappear after delta sync.
      final List<Map<String, dynamic>> allEvents = [
        ...pending,
        ...available,
        ...full,
        ...past,
        ...expired,
      ];

      // Debug: Log the filtered counts
      print('[EVENTS DEBUG] Filtered: ${pending.length} pending, ${available.length} posted, ${full.length} full, ${past.length} past, ${expired.length} expired');
      if (full.isNotEmpty) {
        print('[EVENTS DEBUG] Full events: ${full.map((e) => e['name']).toList()}');
      }
      if (past.isNotEmpty) {
        print('[EVENTS DEBUG] Completed events: ${past.map((e) => e['name']).toList()}');
      }

      setState(() {
        _events = allEvents;
        _eventsPending = pending;
        _eventsAvailable = available;
        _eventsFull = full;
        _eventsCompleted = past;
        _eventsExpired = expired;
        _isEventsLoading = false;
      });

      print('');
      print('╔════════════════════════════════════════════════════════════════╗');
      print('║                    EVENTS CATEGORIZATION SUMMARY               ║');
      print('╠════════════════════════════════════════════════════════════════╣');
      print('║ PENDING (${pending.length}): ${pending.map((e) => e['shift_name'] ?? e['client_name']).toList()}');
      print('║ POSTED (${available.length}): ${available.map((e) => e['shift_name'] ?? e['client_name']).toList()}');
      print('║ FULL (${full.length}): ${full.map((e) => e['shift_name'] ?? e['client_name']).toList()}');
      print('║ COMPLETED (${past.length}): ${past.map((e) => e['shift_name'] ?? e['client_name']).toList()}');
      print('╚════════════════════════════════════════════════════════════════╝');
      print('');
    } catch (e) {
      setState(() {
        _eventsError = e.toString();
        _isEventsLoading = false;
      });
    }
  }

  List<Widget> _buildEventsSlivers() {
    final List<Map<String, dynamic>> pending = _filterEvents(_eventsPending);
    final List<Map<String, dynamic>> available = _filterEvents(_eventsAvailable);
    final List<Map<String, dynamic>> full = _filterEvents(_eventsFull);
    final List<Map<String, dynamic>> completed = _filterEvents(_eventsCompleted);

    // Return the current tab's content directly as slivers
    List<Map<String, dynamic>> currentTabEvents;
    switch (_eventsTabController.index) {
      case 0:
        currentTabEvents = pending;
        break;
      case 1:
        currentTabEvents = available;
        break;
      case 2:
        currentTabEvents = full;
        break;
      case 3:
        currentTabEvents = completed;
        break;
      default:
        currentTabEvents = pending;
    }

    // Build expired banner for Pending tab (case 0) and Posted tab (case 1)
    final bool showExpiredBanner = _eventsTabController.index == 0 || _eventsTabController.index == 1;
    final int expiredCount = _eventsExpired?.length ?? 0;

    // Build event cards as individual slivers for proper scrolling
    if (currentTabEvents.isEmpty) {
      return [
        if (showExpiredBanner && expiredCount > 0)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _buildExpiredEventsBanner(expiredCount),
            ),
          ),
        SliverToBoxAdapter(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                'No ${context.read<TerminologyProvider>().plural.toLowerCase()} found',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
            ),
          ),
        ),
      ];
    }

    return [
      if (showExpiredBanner && expiredCount > 0)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: _buildExpiredEventsBanner(expiredCount),
          ),
        ),
      SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final event = currentTabEvents[index];
            return _buildEventCard(event);
          },
          childCount: currentTabEvents.length,
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
                        decoration: InputDecoration(
                          prefixIcon: Icon(Icons.search),
                          hintText: AppLocalizations.of(context)!.searchNameOrEmail,
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
                        label: Text(AppLocalizations.of(context)!.all),
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
    final statusBarHeight = MediaQuery.of(context).padding.top;
    return [
      // Top padding to position catalog content below floating header + chip bar
      SliverToBoxAdapter(
        child: SizedBox(height: statusBarHeight + 120), // Dynamic: status bar + toolbar + chip bar
      ),
      SliverFillRemaining(
        child: Stack(
          children: [
            TabBarView(
              controller: _catalogTabController,
              children: [_buildClientsInner(), _buildRolesInner(), _buildTariffsInner(), _buildStaffInner()],
            ),
            // Floating Action Button (hide during merge mode)
            if (!_isMergeMode)
              Positioned(
                bottom: 120,
                right: 20,
                child: FloatingActionButton(
                  onPressed: _showAddItemDialog,
                  backgroundColor: Colors.white.withOpacity(0.8),
                  elevation: 2,
                  child: const Icon(
                    Icons.add,
                    color: Colors.grey,
                    size: 24,
                  ),
                ),
              ),
            // Merge action button
            if (_isMergeMode && _mergeSelectedIds.length >= 2)
              Positioned(
                bottom: 120,
                left: 20,
                right: 20,
                child: Center(
                  child: ElevatedButton.icon(
                    onPressed: _isMerging ? null : _showMergeTargetDialog,
                    icon: _isMerging
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.call_merge),
                    label: Text('Merge ${_mergeSelectedIds.length} items'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ExColors.techBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                      elevation: 6,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ];
  }

  void _showAddItemDialog() {
    // Determine which tab is currently active
    final int currentIndex = _catalogTabController.index;
    String title = '';
    String hintText = '';

    switch (currentIndex) {
      case 0: // Clients tab
        title = 'New Client';
        hintText = 'Client name';
        break;
      case 1: // Roles tab
        title = 'New Role';
        hintText = 'Role name';
        break;
      case 2: // Tariffs tab
        _showCreateTariffDialog();
        return;
      case 3: // Staff tab — staff are added via team invites, not catalog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Staff members are added through team invites'),
            backgroundColor: ExColors.techBlue,
          ),
        );
        return;
    }

    _promptNewNamedItem(title, hintText).then((name) {
      if (name == null) return;

      switch (currentIndex) {
        case 0: // Clients
          _clientsService.createClient(name).then((_) {
            _loadClients();
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Client created'),
                backgroundColor: ExColors.successDark,
              ),
            );
          }).catchError((e) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error creating client: $e'),
                backgroundColor: ExColors.errorDark,
              ),
            );
          });
          break;
        case 1: // Roles
          _rolesService.createRole(name).then((_) {
            _loadRoles();
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Role created'),
                backgroundColor: ExColors.successDark,
              ),
            );
          }).catchError((e) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error creating role: $e'),
                backgroundColor: ExColors.errorDark,
              ),
            );
          });
          break;
      }
    });
  }

  Widget _buildEventsTab() {
    final List<Map<String, dynamic>> all = _events ?? const [];
    final List<Map<String, dynamic>> pending = _filterEvents(_eventsPending);
    final List<Map<String, dynamic>> available = _filterEvents(_eventsAvailable);
    final List<Map<String, dynamic>> full = _filterEvents(_eventsFull);
    final List<Map<String, dynamic>> past = _filterEvents(_eventsCompleted);
    return SafeArea(
      child: DefaultTabController(
        length: 3,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TabBar(
                      tabs: [
                        Tab(text: AppLocalizations.of(context)!.pending),
                        Tab(text: AppLocalizations.of(context)!.upcoming),
                        Tab(text: AppLocalizations.of(context)!.past),
                      ],
                      labelColor: ExColors.techBlue,
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
                  _eventsInner(pending), // Pending tab
                  _eventsInner(available), // Available tab
                  _eventsInner(full), // Full tab
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
      color: ExColors.techBlue,
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
                          color: ExColors.info.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Icon(
                          Icons.event_available_outlined,
                          color: ExColors.techBlue,
                          size: 48,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'No Past Events',
                        style: TextStyle(
                          color: ExColors.textPrimary,
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
                          color: ExColors.textSecondary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$monthLabel (${eventsInMonth.length})',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: ExColors.textPrimary,
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

  Widget _eventsInner(List<Map<String, dynamic>> items, {Widget? header}) {
    print('[EVENTS INNER] Received ${items.length} items');
    final sortedItems = _sortEvents(items);
    return RefreshIndicator(
      onRefresh: _loadEvents,
      color: ExColors.techBlue,
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
                if (header != null)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                      child: header,
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
                      childAspectRatio: 1.8,
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
              if (header != null) header,
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
                          color: ExColors.info.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Icon(
                          Icons.event_available_outlined,
                          color: ExColors.techBlue,
                          size: 48,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'No Events',
                        style: TextStyle(
                          color: ExColors.textPrimary,
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

    try {
      // Fetch draft events from backend (status == 'draft')
      final allEvents = await _eventService.fetchEvents();

      // Filter to only draft status events
      final drafts = allEvents.where((event) {
        final status = event['status']?.toString() ?? '';
        return status == 'draft';
      }).toList();

      setState(() {
        _pendingDrafts = drafts;
        _isPendingLoading = false;
      });
    } catch (e) {
      setState(() {
        _isPendingLoading = false;
      });
      print('[_loadPendingDrafts] Error: $e');
    }
  }

  Widget _pendingInner() {
    return RefreshIndicator(
      onRefresh: _loadPendingDrafts,
      color: ExColors.techBlue,
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
            // Backend events have data at top level (not wrapped in 'data' field)
            final client = (d['client_name'] ?? '').toString();
            final name =
                (d['shift_name'] ?? d['venue_name'] ?? 'Untitled')
                    .toString();
            final dateRaw = (d['date'] ?? '').toString();
            final dateFormatted = dateRaw.isNotEmpty
                ? Formatters.formatDateString(dateRaw)
                : '';
            final id = (d['id'] ?? d['_id'] ?? '').toString();
            final status = (d['status'] ?? 'draft').toString();

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: status == 'fulfilled'
                    ? ExColors.successDark
                    : Colors.grey.shade200,
                  width: status == 'fulfilled' ? 2 : 1,
                ),
              ),
              child: ListTile(
                leading: status == 'fulfilled'
                    ? Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: ExColors.successDark.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_circle,
                          color: ExColors.successDark,
                          size: 24,
                        ),
                      )
                    : null,
                title: Row(
                  children: [
                    Expanded(
                      child: Text(client.isNotEmpty ? client : 'Client'),
                    ),
                    if (status == 'fulfilled')
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: ExColors.successDark,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Fulfilled',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
                subtitle: Text(
                  [
                    name,
                    dateFormatted,
                  ].where((s) => s.toString().isNotEmpty).join(' • '),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                      onPressed: () async {
                        if (!mounted) return;
                        final changed = await Navigator.of(context).push<bool>(
                          MaterialPageRoute(
                            builder: (_) =>
                                PendingEditScreen(draft: d, draftId: id),
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
                        if (!mounted) return;
                        final changed = await Navigator.of(context).push<bool>(
                          MaterialPageRoute(
                            builder: (_) =>
                                PendingPublishScreen(draft: d, draftId: id),
                          ),
                        );
                        if (changed == true) {
                          // Refresh both pending drafts AND posted events
                          await Future.wait([
                            _loadPendingDrafts(),
                            _loadEvents(),
                          ]);
                        }
                      },
                      child: const Text('Publish'),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: ExColors.errorDark),
                      onPressed: () async {
                        final id = (d['id'] ?? d['_id'] ?? '').toString();
                        if (id.isEmpty) return;

                        // Delete from backend
                        try {
                          await _eventService.deleteEvent(id);
                          await _loadPendingDrafts();
                        } catch (e) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Failed to delete: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
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
    return RefreshIndicator(
      onRefresh: _loadClients,
      color: ExColors.techBlue,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
          children: [
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
                          backgroundColor: ExColors.successDark,
                        ),
                      );
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Failed to create client: $e'),
                          backgroundColor: ExColors.errorDark,
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Add Client'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ExColors.techBlue,
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
      );
  }

  Widget _buildClientsInner() {
    final List<Map<String, dynamic>> items = _clients ?? const [];
    return RefreshIndicator(
      onRefresh: _loadClients,
      color: ExColors.techBlue,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(
          top: 16,
          left: 20,
          right: 20,
          bottom: 100, // Clear bottom nav bar
        ),
        children: [
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
          if (_isClientsLoading && items.isEmpty)
            const Center(child: LoadingIndicator(text: 'Loading clients...')),
          if (_clientsError != null) ...[
            ErrorBanner(message: _clientsError!),
            const SizedBox(height: 12),
          ],
          if (!_isClientsLoading && items.isEmpty && _clientsError == null)
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
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.business_outlined,
                    size: 48,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No clients yet',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add your first client to get started',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
          ...items.map((c) => _clientListTile(c)),
        ],
      ),
    );
  }

  Widget _buildRolesInner() {
    final items = _roles ?? const [];
    return RefreshIndicator(
      onRefresh: _loadRoles,
      color: ExColors.techBlue,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(
          top: 16,
          left: 20,
          right: 20,
          bottom: 100, // Clear bottom nav bar
        ),
        children: [
          if (kIsWeb)
            Align(
              alignment: Alignment.centerRight,
              child: _maybeWebRefreshButton(
                onPressed: _loadRoles,
                label: 'Refresh roles',
                padding: const EdgeInsets.only(top: 12),
              ),
            ),
          if (kIsWeb) const SizedBox(height: 4),
          if (_isRolesLoading && items.isEmpty)
            const Center(child: LoadingIndicator(text: 'Loading roles...')),
          if (_rolesError != null) ...[
            ErrorBanner(message: _rolesError!),
            const SizedBox(height: 12),
          ],
          if (!_isRolesLoading && items.isEmpty && _rolesError == null)
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
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.work_outline,
                    size: 48,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No roles yet',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add your first role to get started',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
          ...items.map((r) => _roleListTile(r)),
        ],
      ),
    );
  }

  Widget _buildTariffsInner() {
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
      color: ExColors.techBlue,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(
          top: 16,
          left: 20,
          right: 20,
          bottom: 100, // Clear bottom nav bar
        ),
        children: [
          if (kIsWeb)
            Align(
              alignment: Alignment.centerRight,
              child: _maybeWebRefreshButton(
                onPressed: () async {
                  await _loadClients();
                  await _loadRoles();
                  await _loadTariffs();
                },
                label: 'Refresh tariffs',
                padding: const EdgeInsets.only(top: 12),
              ),
            ),
          if (kIsWeb) const SizedBox(height: 4),
          // Client and Role Filters
          Padding(
            padding: const EdgeInsets.only(top: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
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
                      value: c['id']?.toString(),
                      child: Text(c['name']?.toString() ?? 'Unnamed Client'),
                    ),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedClientIdForTariffs = value;
                  });
                  _loadTariffs();
                },
                decoration: const InputDecoration(
                  labelText: 'Client',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
                      value: r['id']?.toString(),
                      child: Text(r['name']?.toString() ?? 'Unnamed Role'),
                    ),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedRoleIdForTariffs = value;
                  });
                  _loadTariffs();
                },
                decoration: const InputDecoration(
                  labelText: 'Role',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
              ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_isTariffsLoading && tariffs.isEmpty)
            const Center(child: LoadingIndicator(text: 'Loading tariffs...')),
          if (_tariffsError != null) ...[
            ErrorBanner(message: _tariffsError!),
            const SizedBox(height: 12),
          ],
          if (!_isTariffsLoading && tariffs.isEmpty && _tariffsError == null)
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
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.attach_money,
                    size: 48,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No tariffs yet',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Create your first tariff to set pricing',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
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
                    itemBuilder: (context, index) => _tariffTile(tariffs[index]),
                  )
                : Column(children: tariffs.map((t) => _tariffTile(t)).toList()),
        ],
      ),
    );
  }

  // ============================================================================
  // STAFF TAB
  // ============================================================================

  Future<void> _loadStaffGroups() async {
    try {
      final groups = await _groupService.fetchGroups();
      if (mounted) setState(() => _staffGroups = groups);
    } catch (_) {}
  }

  Future<void> _loadStaff() async {
    setState(() {
      _isStaffLoading = true;
      _staffError = null;
    });
    try {
      final result = await _staffService.fetchStaff(
        q: _staffSearchQuery.isNotEmpty ? _staffSearchQuery : null,
        favorite: _staffFilterFavorite ? true : null,
        groupId: _staffFilterGroup,
      );
      final items = (result['items'] as List<dynamic>?)
          ?.map((e) => e as Map<String, dynamic>)
          .toList() ?? [];
      setState(() {
        _staffMembers = items;
        _isStaffLoading = false;
      });
    } catch (e) {
      setState(() {
        _staffError = e.toString();
        _isStaffLoading = false;
      });
    }
  }

  Widget _buildStaffInner() {
    List<Map<String, dynamic>> items = _staffMembers ?? const [];

    // Client-side role filter
    if (_staffFilterRole != null && _staffFilterRole!.isNotEmpty) {
      items = items.where((s) {
        final roles = (s['roles'] as List<dynamic>?) ?? [];
        return roles.any((r) => r.toString().toLowerCase() == _staffFilterRole!.toLowerCase());
      }).toList();
    }

    // Collect all unique role names for filter chips
    final allRoles = <String>{};
    for (final s in _staffMembers ?? []) {
      final roles = (s['roles'] as List<dynamic>?) ?? [];
      for (final r in roles) {
        if (r != null && r.toString().isNotEmpty) allRoles.add(r.toString());
      }
    }

    return RefreshIndicator(
      onRefresh: _loadStaff,
      color: ExColors.techBlue,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(
          top: 16,
          left: 20,
          right: 20,
          bottom: 100,
        ),
        children: [
          if (kIsWeb)
            Align(
              alignment: Alignment.centerRight,
              child: _maybeWebRefreshButton(
                onPressed: _loadStaff,
                label: 'Refresh staff',
                padding: const EdgeInsets.only(top: 12),
              ),
            ),
          if (kIsWeb) const SizedBox(height: 4),
          // Search bar
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search staff...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _staffSearchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          setState(() => _staffSearchQuery = '');
                          _loadStaff();
                        },
                      )
                    : null,
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
                  borderSide: const BorderSide(color: ExColors.techBlue),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                filled: true,
                fillColor: Colors.white,
              ),
              onChanged: (value) {
                _staffSearchQuery = value;
              },
              onSubmitted: (_) => _loadStaff(),
            ),
          ),
          // Role filter chips
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildStaffFilterChip('All', _staffFilterRole == null && !_staffFilterFavorite && _staffFilterGroup == null, () {
                  setState(() {
                    _staffFilterRole = null;
                    _staffFilterFavorite = false;
                    _staffFilterGroup = null;
                  });
                  _loadStaff();
                }),
                const SizedBox(width: 8),
                _buildStaffFilterChip(
                  'Favorites',
                  _staffFilterFavorite,
                  () {
                    setState(() {
                      _staffFilterFavorite = !_staffFilterFavorite;
                      _staffFilterRole = null;
                      _staffFilterGroup = null;
                    });
                    _loadStaff();
                  },
                  icon: Icons.star,
                ),
                ..._staffGroups.map((group) {
                  final gid = (group['id'] ?? '').toString();
                  final name = (group['name'] ?? '').toString();
                  final colorHex = group['color'] as String?;
                  return Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: _buildStaffFilterChip(
                      name,
                      _staffFilterGroup == gid,
                      () {
                        setState(() {
                          _staffFilterGroup = _staffFilterGroup == gid ? null : gid;
                          _staffFilterRole = null;
                          _staffFilterFavorite = false;
                        });
                        _loadStaff();
                      },
                      chipColor: _parseHexColor(colorHex),
                    ),
                  );
                }),
                ...allRoles.map((role) => Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: _buildStaffFilterChip(role, _staffFilterRole == role, () {
                        setState(() {
                          _staffFilterRole = _staffFilterRole == role ? null : role;
                          _staffFilterFavorite = false;
                          _staffFilterGroup = null;
                        });
                      }),
                    )),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Loading
          if (_isStaffLoading && items.isEmpty)
            const Center(child: LoadingIndicator(text: 'Loading staff...')),
          // Error
          if (_staffError != null) ...[
            ErrorBanner(message: _staffError!),
            const SizedBox(height: 12),
          ],
          // Empty
          if (!_isStaffLoading && items.isEmpty && _staffError == null)
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
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Icon(Icons.people_outline, size: 48, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    'No staff members yet',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Invite team members to get started',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
          // List
          ...items.map((s) => _buildStaffListTile(s)),
        ],
      ),
    );
  }

  Color? _parseHexColor(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    try {
      final cleaned = hex.replaceFirst('#', '');
      return Color(int.parse('FF$cleaned', radix: 16));
    } catch (_) {
      return null;
    }
  }

  Widget _buildStaffFilterChip(String label, bool isSelected, VoidCallback onTap, {IconData? icon, Color? chipColor}) {
    final activeColor = chipColor ?? ExColors.navySpaceCadet;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? activeColor : (chipColor?.withOpacity(0.5) ?? Colors.grey.shade300),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: isSelected ? Colors.white : Colors.amber),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isSelected ? Colors.white : (chipColor ?? ExColors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStaffListTile(Map<String, dynamic> staff) {
    final name = staff['name'] as String? ??
        '${staff['first_name'] ?? ''} ${staff['last_name'] ?? ''}'.trim();
    final roles = (staff['roles'] as List<dynamic>?) ?? [];
    final isFav = staff['isFavorite'] == true;
    final shiftCount = staff['shiftCount'] as int? ?? 0;
    final picture = staff['picture'] as String?;
    final email = staff['email'] as String?;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => StaffDetailScreen(staff: staff),
              ),
            ).then((_) => _loadStaff());
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade100),
            ),
            clipBehavior: Clip.hardEdge,
            child: Row(
              children: [
                UserAvatar(
                  imageUrl: picture,
                  fullName: name,
                  email: email,
                  radius: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${name.isEmpty ? 'Unknown' : name}${isFav ? ' ⭐' : ''}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: ExColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [
                          if (roles.isNotEmpty) roles.take(2).join(', '),
                          if (roles.length > 2) '+${roles.length - 2}',
                          if (shiftCount > 0) '$shiftCount shifts',
                          if ((staff['groups'] as List<dynamic>?)?.isNotEmpty == true)
                            '${(staff['groups'] as List<dynamic>).length} groups',
                        ].join(' · '),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCatalogTab() {
    return SafeArea(
      child: DefaultTabController(
        length: 4,
        child: Column(
          children: [
            const TabBar(
              tabs: [
                Tab(text: 'Clients'),
                Tab(text: 'Roles'),
                Tab(text: 'Tariffs'),
                Tab(text: 'Staff'),
              ],
              labelColor: ExColors.techBlue,
              unselectedLabelColor: Colors.grey,
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildClientsTab(),
                  _buildRolesTab(),
                  _buildTariffsTab(),
                  _buildStaffInner(),
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
      color: ExColors.techBlue,
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
                    color: ExColors.charcoal,
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
                  backgroundColor: ExColors.successDark,
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
              border: Border.all(color: ExColors.borderGrey),
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
                        color: ExColors.info.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.filter_list,
                        color: ExColors.techBlue,
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
                              color: ExColors.charcoal,
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
                          foregroundColor: ExColors.errorDark,
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
                                fillColor: ExColors.formFillLight,
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
                                fillColor: ExColors.formFillLight,
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
                              fillColor: ExColors.formFillLight,
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
                              fillColor: ExColors.formFillLight,
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
                      color: ExColors.info.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${tariffs.length} Tariff${tariffs.length != 1 ? 's' : ''}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: ExColors.techBlue,
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
                        color: ExColors.formFillGrey,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.attach_money,
                        size: 64,
                        color: ExColors.greyMedium,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No tariffs found',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: ExColors.textSecondary,
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
    final bool isSelected = _mergeSelectedIds.contains(id);

    return GestureDetector(
      onTap: _isMergeMode ? () => _toggleMergeSelection(id) : null,
      child: Container(
        margin: EdgeInsets.only(bottom: isWeb ? 0 : 12),
        decoration: BoxDecoration(
          color: _isMergeMode && isSelected ? ExColors.techBlue.withOpacity(0.06) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _isMergeMode && isSelected ? ExColors.techBlue : ExColors.borderGrey,
            width: _isMergeMode && isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(isWeb ? 20 : 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (_isMergeMode)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Checkbox(
                        value: isSelected,
                        onChanged: (_) => _toggleMergeSelection(id),
                        activeColor: ExColors.techBlue,
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: ExColors.successDark.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.attach_money,
                        color: ExColors.successDark,
                        size: 22,
                      ),
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$clientName',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: ExColors.charcoal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          roleName ?? 'Unknown Role',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: ExColors.info.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '\$$rate $currency/hr',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: ExColors.techBlue,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (!_isMergeMode) ...[
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      color: ExColors.techBlue,
                      iconSize: 20,
                      tooltip: 'Edit',
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints(),
                      onPressed: () => _showEditTariffDialog(
                        tariffId: id,
                        clientId: clientId,
                        roleId: roleId,
                        currentRate: double.tryParse(rate) ?? 0.0,
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      color: ExColors.errorDark,
                      iconSize: 20,
                      tooltip: 'Delete',
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints(),
                      onPressed: () => _confirmDeleteTariff(id),
                    ),
                  ],
                ],
              ),
            ],
          ),
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
          backgroundColor: ExColors.errorDark,
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
                  color: ExColors.successDark.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.add_circle_outline,
                  color: ExColors.successDark,
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
                      fillColor: ExColors.formFillLight,
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
                      fillColor: ExColors.formFillLight,
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
                      fillColor: ExColors.formFillLight,
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
                backgroundColor: ExColors.successDark,
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
            backgroundColor: ExColors.successDark,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create tariff: $e'),
            backgroundColor: ExColors.errorDark,
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
                color: ExColors.info.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.edit_outlined,
                color: ExColors.techBlue,
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
                    color: ExColors.formFillGrey,
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
                            color: ExColors.textSecondary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              clientName,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: ExColors.charcoal,
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
                            color: ExColors.textSecondary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              roleName,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: ExColors.charcoal,
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
              backgroundColor: ExColors.techBlue,
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
            backgroundColor: ExColors.successDark,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update tariff: $e'),
            backgroundColor: ExColors.errorDark,
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
                color: ExColors.errorDark.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.warning_outlined,
                color: ExColors.errorDark,
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
              backgroundColor: ExColors.errorDark,
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
            backgroundColor: ExColors.successDark,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete tariff: $e'),
            backgroundColor: ExColors.errorDark,
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

        // Initialize role count controllers for manual entry form
        for (final role in items) {
          final roleName = (role['name'] ?? '').toString();
          if (roleName.isNotEmpty && !_roleCountControllers.containsKey(roleName)) {
            _roleCountControllers[roleName] = TextEditingController(text: '0');
          }
        }
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
      color: ExColors.techBlue,
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
                        backgroundColor: ExColors.errorDark,
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.add),
                label: const Text('Add Role'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ExColors.techBlue,
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
    final bool isSelected = _mergeSelectedIds.contains(id);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: _isMergeMode && isSelected ? ExColors.techBlue.withOpacity(0.06) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isMergeMode && isSelected ? ExColors.techBlue : Colors.grey.shade200,
          width: _isMergeMode && isSelected ? 2 : 1,
        ),
      ),
      child: ListTile(
        onTap: _isMergeMode ? () => _toggleMergeSelection(id) : null,
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
        leading: _isMergeMode
            ? AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Checkbox(
                  key: ValueKey('merge_role_$id'),
                  value: isSelected,
                  onChanged: (_) => _toggleMergeSelection(id),
                  activeColor: ExColors.techBlue,
                ),
              )
            : const Icon(Icons.assignment_ind, color: ExColors.techBlue),
        trailing: _isMergeMode
            ? null
            : PopupMenuButton<String>(
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
                          backgroundColor: ExColors.errorDark,
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
                          backgroundColor: ExColors.errorDark,
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
    final bool isSelected = _mergeSelectedIds.contains(id);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: _isMergeMode && isSelected ? ExColors.techBlue.withOpacity(0.06) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isMergeMode && isSelected ? ExColors.techBlue : Colors.grey.shade200,
          width: _isMergeMode && isSelected ? 2 : 1,
        ),
      ),
      child: ListTile(
        onTap: _isMergeMode ? () => _toggleMergeSelection(id) : null,
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
        leading: _isMergeMode
            ? AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Checkbox(
                  key: ValueKey('merge_client_$id'),
                  value: isSelected,
                  onChanged: (_) => _toggleMergeSelection(id),
                  activeColor: ExColors.techBlue,
                ),
              )
            : const Icon(Icons.business, color: ExColors.techBlue),
        trailing: _isMergeMode
            ? null
            : PopupMenuButton<String>(
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
                          backgroundColor: ExColors.errorDark,
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
                          backgroundColor: ExColors.errorDark,
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

  Future<void> _makeJobPublic(Map<String, dynamic> event) async {
    final eventId = (event['_id'] ?? event['id']).toString();
    final clientName = (event['client_name'] ?? 'this job').toString();

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Make Job Public'),
        content: Text(
          'Make "$clientName" visible to the entire team?\n\n'
          'This will publish the job publicly so all team members can see and accept it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: ExColors.successDark,
            ),
            child: const Text('Make Public'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
              SizedBox(width: 12),
              Text('Publishing job...'),
            ],
          ),
          duration: Duration(seconds: 2),
        ),
      );

      // Publish event to whole team (no specific audience)
      await _eventService.publishEvent(eventId);

      if (!mounted) return;

      // Show success message
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$clientName is now public!'),
          backgroundColor: ExColors.successDark,
          behavior: SnackBarBehavior.floating,
        ),
      );

      // Reload events to reflect the change
      await _loadEvents();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to publish job: ${e.toString()}'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _buildEventCard(Map<String, dynamic> e, {bool showMargin = false}) {
    // Extract essential data
    final String clientName = (e['client_name'] ?? 'Client').toString();
    final String venueName = (e['venue_name'] ?? '').toString();
    final String venueAddress = (e['venue_address'] ?? '').toString();
    final String googleMapsUrl = (e['google_maps_url'] ?? '').toString();
    final String status = (e['status'] ?? 'draft').toString();

    // Determine if venue is missing
    final localizations = AppLocalizations.of(context);
    final locationTbdText = localizations?.locationTbd ?? 'Location TBD';
    final bool isVenueMissing = venueName.isEmpty ||
        venueName.toLowerCase() == 'location tbd' ||
        venueName == locationTbdText;

    String displayDate = '';
    bool isDateMissing = true;
    final dynamic rawDate = e['date'];
    if (rawDate is String && rawDate.isNotEmpty) {
      try {
        final d = DateTime.parse(rawDate);
        isDateMissing = false;

        // Format date as "Mon, Jan 15"
        final months = [
          'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
          'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
        ];
        final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        displayDate = '${days[d.weekday - 1]}, ${months[d.month - 1]} ${d.day}';
      } catch (_) {
        displayDate = rawDate;
        isDateMissing = false;
      }
    }

    // Time handling - both start and end
    final String startTime = (e['start_time'] ?? '').toString();
    final String endTime = (e['end_time'] ?? '').toString();
    final bool isStartTimeMissing = startTime.isEmpty;
    final bool isEndTimeMissing = endTime.isEmpty;

    // Build time display string
    String timeDisplay;
    if (startTime.isNotEmpty && endTime.isNotEmpty) {
      timeDisplay = '$startTime - $endTime';
    } else if (startTime.isNotEmpty) {
      timeDisplay = startTime;
    } else {
      timeDisplay = 'Time TBD';
    }

    // Check if event is expired unfulfilled (past + has open positions + not draft/cancelled)
    bool isExpiredUnfulfilled = false;
    if (rawDate is String && rawDate.isNotEmpty && status != 'draft' && status != 'cancelled') {
      try {
        final d = DateTime.parse(rawDate);
        final eventDate = DateTime(d.year, d.month, d.day);
        final todayDate = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
        if (eventDate.isBefore(todayDate) && _hasOpenPositions(e)) {
          isExpiredUnfulfilled = true;
        }
      } catch (_) {}
    }

    // Extract roles for display
    final roles = (e['roles'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final bool isRolesMissing = roles.isEmpty ||
        roles.every((r) => ((r['count'] as int?) ?? 0) == 0);

    // Build roles display string
    String rolesDisplay = '';
    if (!isRolesMissing) {
      final roleStrings = roles
          .where((r) => ((r['count'] as int?) ?? 0) > 0)
          .map((r) => '${r['role']} (${r['count']})')
          .toList();
      rolesDisplay = roleStrings.join(', ');
    }

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
            ? const EdgeInsets.only(bottom: 10)
            : EdgeInsets.zero,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200, width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row: Client name + action buttons
              Row(
                children: [
                  // Client name
                  Expanded(
                    child: Text(
                      clientName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: ExColors.textPrimary,
                        letterSpacing: -0.2,
                        height: 1.2,
                      ),
                    ),
                  ),
                  // Action buttons
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Edit button
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () async {
                          final eventId = (e['_id'] ?? e['id'] ?? '').toString();
                          if (eventId.isEmpty) return;
                          if (!mounted) return;
                          final changed = await Navigator.of(context).push<bool>(
                            MaterialPageRoute(
                              builder: (_) => PendingEditScreen(
                                draft: e,
                                draftId: eventId,
                              ),
                            ),
                          );
                          if (changed == true) {
                            await _loadEvents();
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Icon(
                            Icons.edit_outlined,
                            size: 18,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ),
                      // Directions button
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          _openGoogleMaps(
                            venueAddress.isNotEmpty ? venueAddress : venueName,
                            googleMapsUrl,
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Icon(
                            Icons.directions_outlined,
                            size: 18,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ),
                      // Copy button
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          _shareEvent(e);
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Icon(
                            Icons.copy_outlined,
                            size: 16,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ),
                      // AI assistant button
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () async {
                          if (!mounted) return;
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => AIChatScreen(eventData: e),
                            ),
                          );
                          await _loadEvents();
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Image.asset(
                            'assets/ai_assistant_logo.png',
                            width: 24,
                            height: 24,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              // Divider
              Divider(
                height: 16,
                color: Colors.grey.shade200,
              ),

              // Date and Time row
              Row(
                children: [
                  // Date
                  Expanded(
                    child: _buildCardInfoRow(
                      icon: Icons.calendar_today_outlined,
                      text: isDateMissing ? 'Date TBD' : displayDate,
                      isMissing: isDateMissing,
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Time
                  Expanded(
                    child: _buildCardInfoRow(
                      icon: Icons.access_time,
                      text: timeDisplay,
                      isMissing: isStartTimeMissing,
                      showEndTimeWarning: !isStartTimeMissing && isEndTimeMissing,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 4),

              // Address row
              _buildCardInfoRow(
                icon: Icons.location_on_outlined,
                text: isVenueMissing ? 'Address TBD' : venueName,
                isMissing: isVenueMissing,
              ),

              const SizedBox(height: 4),

              // Roles row
              _buildCardInfoRow(
                icon: Icons.people_outline,
                text: isRolesMissing ? 'No roles defined' : rolesDisplay,
                isMissing: isRolesMissing,
                maxLines: 2,
              ),

              const SizedBox(height: 8),

              // Badges row (capacity + privacy) - more subtle
              Builder(
                builder: (context) {
                  final capacity = _calculateCapacity(e);
                  final filled = capacity['filled'] ?? 0;
                  final total = capacity['total'] ?? 0;
                  final capacityColor = _getCapacityColor(filled, total);
                  final isFull = filled >= total && total > 0;

                  final privacyStatus = _getPrivacyStatus(e);
                  final privacyColor = _getPrivacyColor(privacyStatus);
                  final privacyLabel = privacyStatus == 'private'
                      ? 'Private'
                      : privacyStatus == 'public'
                          ? 'Public'
                          : 'Private+Public';

                  return Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      // Capacity badge - subtle style
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: capacityColor.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: capacityColor.withValues(alpha: 0.2),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isFull ? Icons.check_circle_outline : Icons.people_outline,
                              size: 11,
                              color: capacityColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isFull ? 'Full' : '$filled/$total',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: capacityColor,
                                height: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Privacy badge (for published events only)
                      if (status == 'published')
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: privacyColor.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: privacyColor.withValues(alpha: 0.2),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                privacyStatus == 'private'
                                    ? Icons.lock_outline
                                    : privacyStatus == 'public'
                                        ? Icons.public
                                        : Icons.groups_outlined,
                                size: 11,
                                color: privacyColor,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                privacyLabel,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  color: privacyColor,
                                  height: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      // Expired unfulfilled badge
                      if (isExpiredUnfulfilled)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.orange.withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.warning_amber_rounded,
                                size: 11,
                                color: Colors.orange.shade700,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Expired',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.orange.shade700,
                                  height: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  );
                },
              ),

              // Action buttons for pending/draft events (only true drafts, not sent to staff yet)
              if (status == 'draft' && ((e['accepted_staff'] as List?)?.isEmpty ?? true)) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final eventId = (e['_id'] ?? e['id'] ?? '').toString();
                          if (eventId.isEmpty) return;
                          if (!mounted) return;
                          final changed = await Navigator.of(context).push<bool>(
                            MaterialPageRoute(
                              builder: (_) => PendingPublishScreen(
                                draft: e,
                                draftId: eventId,
                              ),
                            ),
                          );
                          if (changed == true) {
                            await _loadEvents();
                          }
                        },
                        icon: const Icon(Icons.campaign_outlined, size: 16),
                        label: const Text('Publish'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.grey.shade700,
                          side: BorderSide(color: Colors.grey.shade300),
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          textStyle: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(Icons.delete_outline, color: Colors.grey.shade500, size: 20),
                      onPressed: () async {
                        final eventId = (e['_id'] ?? e['id'] ?? '').toString();
                        if (eventId.isEmpty) return;

                        // Confirm deletion
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Delete Event'),
                            content: const Text('Are you sure you want to delete this draft event?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('Delete', style: TextStyle(color: ExColors.errorDark)),
                              ),
                            ],
                          ),
                        );

                        if (confirm != true) return;

                        try {
                          await _eventService.deleteEvent(eventId);
                          await _loadEvents();
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Event deleted')),
                          );
                        } catch (e) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Failed to delete: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Helper method to build consistent info rows in event cards
  Widget _buildCardInfoRow({
    required IconData icon,
    required String text,
    bool isMissing = false,
    bool showEndTimeWarning = false,
    int maxLines = 1,
  }) {
    final Color iconColor = isMissing ? ExColors.warning : Colors.grey.shade500;
    final Color textColor = isMissing ? ExColors.warning : Colors.grey.shade600;

    return Row(
      crossAxisAlignment: maxLines > 1 ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Icon(
          isMissing ? Icons.warning_amber_rounded : icon,
          size: 14,
          color: iconColor,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Row(
            children: [
              Flexible(
                child: Text(
                  text,
                  maxLines: maxLines,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: textColor,
                    fontStyle: isMissing ? FontStyle.italic : FontStyle.normal,
                    height: 1.3,
                  ),
                ),
              ),
              if (showEndTimeWarning) ...[
                const SizedBox(width: 4),
                Icon(
                  Icons.warning_amber_rounded,
                  size: 12,
                  color: ExColors.warning.withValues(alpha: 0.7),
                ),
              ],
            ],
          ),
        ),
      ],
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

  Widget _buildManualEntryForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // AI Chat button - compact, right-aligned
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (context) => const AIChatScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.auto_awesome, size: 18),
              label: const Text('AI Chat'),
              style: TextButton.styleFrom(
                foregroundColor: ExColors.techBlue,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              ),
            ),
          ),
          FormSection(
            title: 'Shift Information',
            icon: Icons.event,
            children: [
              // Integrated Client Selector with Autocomplete
              _buildClientSelector(),
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
                          _startTimeController.text = time.format(context);
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
            ],
          ),
          const SizedBox(height: 16),
          FormSection(
            title: AppLocalizations.of(context)!.locationInformation,
            icon: Icons.location_on,
            children: [
              // Address FIRST with auto-fill
              ModernAddressField(
                controller: _venueAddressController,
                label: AppLocalizations.of(context)!.address,
                icon: Icons.place,
                onPlaceSelected: (placeDetails) {
                  setState(() {
                    _selectedVenuePlace = placeDetails;
                    // Auto-fill city from selected place
                    if (placeDetails.addressComponents['city']?.isNotEmpty == true) {
                      _cityController.text = placeDetails.addressComponents['city']!;
                    }
                    // Auto-fill state
                    if (placeDetails.addressComponents['state']?.isNotEmpty == true) {
                      _stateController.text = placeDetails.addressComponents['state']!;
                    }
                    // Auto-fill zip code
                    if (placeDetails.addressComponents['postal_code']?.isNotEmpty == true) {
                      _zipController.text = placeDetails.addressComponents['postal_code']!;
                    }
                    // Auto-fill location name from street address or first part of formatted address
                    if (placeDetails.addressComponents['street']?.isNotEmpty == true) {
                      _venueNameController.text = placeDetails.addressComponents['street']!;
                    } else if (placeDetails.formattedAddress.isNotEmpty) {
                      // Use first part of address (before first comma) as location name
                      final firstPart = placeDetails.formattedAddress.split(',').first.trim();
                      if (firstPart.isNotEmpty) {
                        _venueNameController.text = firstPart;
                      }
                    }
                  });

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.white, size: 20),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Address selected - fields auto-filled',
                              style: TextStyle(fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                      backgroundColor: ExColors.successDark,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              // City, State, Zip in a row
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: LabeledTextField(
                      controller: _cityController,
                      label: AppLocalizations.of(context)!.city,
                      icon: Icons.location_city,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: LabeledTextField(
                      controller: _stateController,
                      label: AppLocalizations.of(context)!.state,
                      icon: Icons.map,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: LabeledTextField(
                      controller: _zipController,
                      label: 'Zip',
                      icon: Icons.markunread_mailbox_outlined,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Location Name LAST (auto-inferred)
              LabeledTextField(
                controller: _venueNameController,
                label: AppLocalizations.of(context)!.locationName,
                icon: Icons.business,
                placeholder: 'Auto-filled from address',
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Simplified Contact section - phone only
          FormSection(
            title: 'Contact',
            icon: Icons.phone,
            children: [
              LabeledTextField(
                controller: _contactPhoneController,
                label: AppLocalizations.of(context)!.phoneNumber,
                icon: Icons.phone,
                keyboardType: TextInputType.phone,
                placeholder: 'Optional',
              ),
            ],
          ),
          const SizedBox(height: 16),
          FormSection(
            title: AppLocalizations.of(context)!.additionalNotes,
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
          const SizedBox(height: 16),
          // Staff Roles Section with +/- buttons
          FormSection(
            title: 'Staff Roles Required',
            icon: Icons.badge,
            children: [
              if (_isRolesLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_roleCountControllers.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Icon(Icons.info_outline, color: Colors.grey.shade400, size: 32),
                      const SizedBox(height: 8),
                      Text(
                        'No roles defined yet. Add roles in the Catalog tab.',
                        style: TextStyle(color: Colors.grey.shade600),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              else
                ..._roleCountControllers.entries.map((entry) {
                  return _buildManualEntryRoleRow(entry.key, entry.value);
                }),
            ],
          ),
          const SizedBox(height: 24),
          // Primary action: Save directly to Pending
          ElevatedButton.icon(
            onPressed: _saveManualEntryToPending,
            icon: const Icon(Icons.check, size: 20),
            label: Text(
              AppLocalizations.of(context)!.saveToPending,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: ExColors.successDark,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
          ),
          const SizedBox(height: 12),
          // Secondary action: Create recurring series
          TextButton.icon(
            onPressed: _showManualEntryBatchDialog,
            icon: const Icon(Icons.calendar_month, size: 18),
            label: const Text('Create Recurring Series'),
            style: TextButton.styleFrom(foregroundColor: ExColors.techBlue),
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
    );
  }

  /// Builds an integrated client selector with autocomplete and create-new functionality
  Widget _buildClientSelector() {
    final clientList = _clients ?? [];

    return Autocomplete<Map<String, dynamic>>(
      optionsBuilder: (TextEditingValue textEditingValue) {
        final query = textEditingValue.text.toLowerCase().trim();
        if (query.isEmpty) {
          // Show all clients when empty
          return clientList.take(10);
        }

        final matches = clientList.where((client) {
          final name = (client['name'] ?? '').toString().toLowerCase();
          return name.contains(query);
        }).toList();

        // If no exact match exists, add "Create new" option
        final exactMatch = matches.any((c) =>
          (c['name'] ?? '').toString().toLowerCase() == query);

        if (!exactMatch && query.isNotEmpty) {
          matches.add({'name': query, '_isNew': true});
        }

        return matches.take(10);
      },
      displayStringForOption: (client) => client['name']?.toString() ?? '',
      fieldViewBuilder: (context, textController, focusNode, onFieldSubmitted) {
        // Sync with our main controller
        if (_clientNameController.text.isNotEmpty && textController.text.isEmpty) {
          textController.text = _clientNameController.text;
        }
        textController.addListener(() {
          _clientNameController.text = textController.text;
        });

        return Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Icon(Icons.person, color: ExColors.techBlue, size: 20),
              ),
              Expanded(
                child: TextField(
                  controller: textController,
                  focusNode: focusNode,
                  decoration: InputDecoration(
                    hintText: 'Type client name or select...',
                    hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 15),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  ),
                  style: const TextStyle(fontSize: 15),
                  onSubmitted: (_) => onFieldSubmitted(),
                ),
              ),
              // Dropdown button to show all options
              IconButton(
                icon: Icon(Icons.arrow_drop_down, color: Colors.grey.shade600),
                onPressed: () {
                  // Clear and refocus to show all options
                  textController.clear();
                  focusNode.requestFocus();
                },
                splashRadius: 20,
              ),
            ],
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
              constraints: const BoxConstraints(maxHeight: 250, maxWidth: 350),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final client = options.elementAt(index);
                  final isNew = client['_isNew'] == true;
                  final name = client['name']?.toString() ?? '';

                  return ListTile(
                    leading: Icon(
                      isNew ? Icons.add_circle_outline : Icons.business,
                      color: isNew ? ExColors.techBlue : Colors.grey.shade600,
                      size: 20,
                    ),
                    title: Text(
                      isNew ? 'Create "$name"' : name,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isNew ? FontWeight.w600 : FontWeight.w500,
                        color: isNew ? ExColors.techBlue : Colors.grey.shade800,
                      ),
                    ),
                    dense: true,
                    onTap: () => onSelected(client),
                  );
                },
              ),
            ),
          ),
        );
      },
      onSelected: (client) {
        final name = client['name']?.toString() ?? '';
        _clientNameController.text = name;

        // If creating a new client
        if (client['_isNew'] == true) {
          // Optionally create the client in backend
          _clientsService.createClient(name).then((_) {
            _loadClients();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Client "$name" created'),
                backgroundColor: ExColors.successDark,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }).catchError((e) {
            // Still use the name even if backend creation fails
            debugPrint('Error creating client: $e');
          });
        }
      },
    );
  }

  /// Builds a role row with +/- buttons for the manual entry form
  Widget _buildManualEntryRoleRow(String roleName, TextEditingController controller) {
    final count = int.tryParse(controller.text) ?? 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          // Role icon
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: ExColors.techBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.person_outline,
              size: 18,
              color: ExColors.techBlue,
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
                color: Colors.black87,
              ),
            ),
          ),
          // Count controls with +/- buttons
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
                  onPressed: count > 0
                    ? () {
                        setState(() {
                          controller.text = (count - 1).toString();
                        });
                      }
                    : null,
                  icon: Icon(
                    Icons.remove,
                    size: 18,
                    color: count > 0 ? ExColors.errorDark : Colors.grey.shade400,
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
                      color: Colors.black87,
                    ),
                  ),
                ),
                // Plus button
                IconButton(
                  onPressed: () {
                    setState(() {
                      controller.text = (count + 1).toString();
                    });
                  },
                  icon: const Icon(
                    Icons.add,
                    size: 18,
                    color: ExColors.successDark,
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

  Widget _buildManualEntryTab() {
    return SingleChildScrollView(
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800),
          padding: const EdgeInsets.all(20),
          child: _buildManualEntryForm(),
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
                // Clear chat button - only show if there are messages
                if (messages.isNotEmpty && _showAIChatHeader)
                  Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 12),
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
                            child: Icon(
                              Icons.delete_outline,
                              size: 18,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                // Floating draft preview button (hidden when event is auto-saved)
                if (currentData.isNotEmpty && !_aiChatService.eventComplete)
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
                                colors: [ExColors.yellow, ExColors.pink],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: ExColors.yellow.withValues(alpha: 0.4),
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
                                  color: ExColors.yellow.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(60),
                                ),
                                child: const Icon(
                                  Icons.chat_bubble_outline,
                                  size: 60,
                                  color: ExColors.yellow,
                                ),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                AppLocalizations.of(context)!.startConversation,
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade800,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                AppLocalizations.of(context)!.aiWillGuideYou,
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
                                        ExColors.yellow, // Light purple
                                        ExColors.techBlue, // Medium purple
                                        ExColors.indigoPurple, // Darker purple
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: ExColors.yellow.withOpacity(0.4),
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
                                      onTap: () async {
                                        // On mobile, launch full-screen AI chat
                                        if (!kIsWeb) {
                                          final result = await Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (_) => const AIChatScreen(startNewConversation: true),
                                            ),
                                          );
                                          // Handle "Check Pending" navigation
                                          if (result != null && result is Map && result['action'] == 'show_pending') {
                                            setState(() {
                                              _selectedIndex = 1; // Switch to Events tab
                                              _eventsTabController.animateTo(0); // Switch to Pending sub-tab
                                            });
                                            await _loadPendingDrafts(); // Refresh pending list
                                          } else {
                                            // Refresh state after returning
                                            setState(() {});
                                          }
                                        } else {
                                          // On web, show inline chat
                                          _aiChatService.startNewConversation();
                                          await _aiChatService.getGreeting();

                                          setState(() {
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
                                        }
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
                                            Flexible(
                                              child: Text(
                                                AppLocalizations.of(context)!.startNewConversation,
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
        // Show pending update previews
        _buildUpdatePreviewCards(),
        // Show event confirmation card when event is complete
        if (_aiChatService.eventComplete && _aiChatService.currentEventData.isNotEmpty)
          EventConfirmationCard(
            eventData: _aiChatService.currentEventData,
            onConfirm: () async {
              // Save event to drafts
              final currentData = Map<String, dynamic>.from(_aiChatService.currentEventData);
              setState(() {
                structuredData = currentData;
                extractedText = 'AI Chat extracted data';
                errorMessage = null;
                _lastStructuredFromUpload = false;
              });

              _draftService.saveDraft(currentData);
              await _loadPendingDrafts();

              _showSuccessBanner(context, 'Event created and saved to pending!');

              // Clear the event data and start a new conversation
              _aiChatService.clearCurrentEventData();
              _aiChatService.startNewConversation();

              setState(() {});
            },
            onEdit: () {
              // User can continue chatting to edit the event
              _showSuccessBanner(context, 'Continue chatting to make changes!');
            },
            onCancel: () {
              // Clear the current event and start over
              _aiChatService.clearCurrentEventData();
              _aiChatService.startNewConversation();
              setState(() {});
            },
            onCreateSeries: _showBatchDialog,
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
                ? Padding(
                    padding: const EdgeInsets.only(left: 8, right: 12, bottom: 6),
                    child: Row(
                      children: [
                        // AI Provider toggle button - only visible on web
                        if (kIsWeb) ...[
                          Container(
                            decoration: BoxDecoration(
                              color: _aiChatService.modelPreference == 'llama'
                                  ? Colors.purple
                                  : Colors.black,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(8),
                                onTap: () {
                                  setState(() {
                                    final newModel = _aiChatService.modelPreference == 'llama' ? 'gpt-oss' : 'llama';
                                    _aiChatService.setModelPreference(newModel);
                                  });
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Using ${_aiChatService.modelPreference == 'llama' ? 'Llama 3.1 8B' : 'GPT-OSS 20B'} model'),
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(4),
                                  child: Icon(
                                    _aiChatService.modelPreference == 'llama' ? Icons.bolt : Icons.psychology,
                                    color: Colors.white,
                                    size: 14,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        // Chat input
                        Expanded(
                          child: ChatInputWidget(
                            key: const ValueKey('chat-input'),
                            onSendMessage: (message) async {
            setState(() {
              _isAIChatLoading = true;
            });

            try {
              final response =
                  await _aiChatService.sendMessage(message);

              print('[ExtractionScreen] AI response received');
              print('[ExtractionScreen] Response content: ${response.content}');
              print('[ExtractionScreen] Pending updates count: ${_aiChatService.pendingUpdates.length}');

              // Check if an update was auto-applied (response contains success confirmation)
              if (response.content.contains('EVENT_UPDATE')) {
                // Show beautiful success banner
                if (mounted) {
                  _showSuccessBanner(context, 'Event updated successfully!');
                }
              }

              // Scroll to bottom after message (or show confirmation card if event is complete)
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (_aiChatScrollController.hasClients) {
                  _aiChatScrollController.animateTo(
                    _aiChatScrollController.position.maxScrollExtent,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                  );
                }
              });

              // Force UI refresh to show any pending updates (fallback)
              if (mounted) {
                setState(() {
                  print('[ExtractionScreen] setState called to refresh UI');
                });
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
        ),
                        ),
                      ],
                    ),
                  )
              : const SizedBox.shrink(
                  key: ValueKey('empty'),
                ),
          ),
        ),
      ],
    );
  }

  Widget _buildUpdatePreviewCards() {
    final pendingUpdates = _aiChatService.pendingUpdates;
    print('[ExtractionScreen._buildUpdatePreviewCards] Called with ${pendingUpdates.length} pending updates');

    if (pendingUpdates.isEmpty) {
      print('[ExtractionScreen._buildUpdatePreviewCards] No pending updates, returning empty widget');
      return const SizedBox.shrink();
    }

    print('[ExtractionScreen._buildUpdatePreviewCards] Building ${pendingUpdates.length} update cards');
    return Container(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: pendingUpdates.map((update) {
          final eventId = update['eventId'] as String? ?? '';
          final updates = update['updates'] as Map<String, dynamic>? ?? {};
          final summary = update['summary'] as String? ?? 'Update event';

          // Find the event name from existing events for display
          String eventName = 'Event';
          final existingEvent = _aiChatService.existingEvents.firstWhere(
            (e) => (e['_id'] ?? e['id']) == eventId,
            orElse: () => {},
          );
          if (existingEvent.isNotEmpty) {
            final nameRaw = existingEvent['shift_name'] ?? existingEvent['name'];
            eventName = nameRaw?.toString() ?? 'Event';
          }

          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.orange.shade300, width: 2),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.update, color: Colors.orange.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Update: $eventName',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.orange.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    summary,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 8),
                  Text(
                    'Changes:',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...updates.entries.map((entry) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Icon(
                            Icons.arrow_forward,
                            size: 16,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${entry.key}: ${entry.value}',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _aiChatService.removePendingUpdate(update);
                          });
                        },
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () async {
                          try {
                            await _aiChatService.applyUpdate(update);
                            if (mounted) {
                              setState(() {});
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Updated $eventName successfully!'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Failed to update: ${e.toString()}'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange.shade700,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Apply Changes'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEventDetails(Map<String, dynamic> data) {
    final List<dynamic> acceptedStaff = (data['accepted_staff'] is List)
        ? (data['accepted_staff'] as List)
        : const [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (data['shift_name'] != null)
          DetailRow(
            label: AppLocalizations.of(context)!.shift,
            value: data['shift_name'].toString(),
            icon: Icons.celebration,
          ),
        if (data['client_name'] != null)
          DetailRow(
            label: AppLocalizations.of(context)!.client,
            value: data['client_name'].toString(),
            icon: Icons.person,
          ),
        if (data['date'] != null)
          DetailRow(
            label: AppLocalizations.of(context)!.date,
            value: data['date'].toString(),
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
            value: data['venue_name'].toString(),
            icon: Icons.location_on,
          ),
        if (data['venue_address'] != null)
          DetailRow(
            label: AppLocalizations.of(context)!.address,
            value: data['venue_address'].toString(),
            icon: Icons.place,
          ),
        if (data['contact_phone'] != null)
          DetailRow(
            label: AppLocalizations.of(context)!.phone,
            value: data['contact_phone'].toString(),
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
              color: ExColors.slate,
            ),
          ),
          const SizedBox(height: 8),
          ...((data['roles'] as List).map(
            (role) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ExColors.formFillSlate,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: ExColors.techBlue,
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
                      role['call_time'].toString(),
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
              color: ExColors.slate,
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
                color: ExColors.formFillCyan,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.person, color: ExColors.skyBlue, size: 18),
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
              backgroundColor: ExColors.errorDark,
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
          backgroundColor: ExColors.successDark,
        ),
      );
      // Clear draft after successful save
      await _draftService.clearDraft();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save: $e'),
          backgroundColor: ExColors.errorDark,
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
                          backgroundColor: ExColors.errorDark,
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
                color: ExColors.error,
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
                      primary: ExColors.techBlue,
                      onPrimary: Colors.white,
                      surface: Colors.white,
                      onSurface: ExColors.textPrimary,
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
                    ? ExColors.techBlue.withValues(alpha: 0.3)
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
                    color: ExColors.techBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.calendar_today,
                    size: 20,
                    color: ExColors.techBlue,
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
                          ? ExColors.textPrimary
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
                      primary: ExColors.techBlue,
                      onPrimary: Colors.white,
                      surface: Colors.white,
                      onSurface: ExColors.textPrimary,
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
                    ? ExColors.techBlue.withValues(alpha: 0.3)
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
                    color: ExColors.techBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 20, color: ExColors.techBlue),
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
                          ? ExColors.textPrimary
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

  /// Show batch creation dialog for recurring events
  Future<void> _showBatchDialog() async {
    final currentData = _aiChatService.currentEventData;
    if (currentData.isEmpty) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return BatchEventDialog(
          templateEventData: currentData,
          onCreateBatch: _createBatchEvents,
        );
      },
    );
  }

  /// Create multiple events with different dates
  Future<void> _createBatchEvents(List<DateTime> dates) async {
    if (dates.isEmpty) return;

    setState(() {
      isLoading = true;
    });

    try {
      final template = Map<String, dynamic>.from(_aiChatService.currentEventData);

      // Create events with different dates
      final events = dates.map((date) {
        return {
          ...template,
          'date': date.toIso8601String(),
          'status': 'draft',
        };
      }).toList();

      print('[ExtractionScreen] Creating batch with ${events.length} events...');

      final createdEvents = await _eventService.createBatchEvents(events);

      print('[ExtractionScreen] ✓ Created ${createdEvents.length} events');

      // Show success message
      _showSuccessBanner(context, 'Created ${createdEvents.length} recurring events!');

      // Clear the event data and start a new conversation
      _aiChatService.clearCurrentEventData();
      _aiChatService.startNewConversation();

      // Reload pending drafts to show new events
      await _loadPendingDrafts();

      setState(() {});

    } catch (e) {
      print('[ExtractionScreen] ✗ Failed to create batch events: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create recurring events: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  /// Show a beautiful translucent success banner
  void _showSuccessBanner(BuildContext context, String message) {
    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 16,
        left: 16,
        right: 16,
        child: _AnimatedSuccessBanner(
          message: message,
          onDismiss: () {
            overlayEntry.remove();
          },
        ),
      ),
    );

    overlay.insert(overlayEntry);

    // Auto-dismiss after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (overlayEntry.mounted) {
        overlayEntry.remove();
      }
    });
  }
}

/// Animated success banner widget
class _AnimatedSuccessBanner extends StatefulWidget {
  final String message;
  final VoidCallback onDismiss;

  const _AnimatedSuccessBanner({
    required this.message,
    required this.onDismiss,
  });

  @override
  State<_AnimatedSuccessBanner> createState() => _AnimatedSuccessBannerState();
}

class _AnimatedSuccessBannerState extends State<_AnimatedSuccessBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    ));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.green.shade400.withOpacity(0.95),
                  Colors.green.shade600.withOpacity(0.95),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.green.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    widget.message,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 20),
                  onPressed: () {
                    _controller.reverse().then((_) {
                      widget.onDismiss();
                    });
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
