import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For HapticFeedback
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../../../services/terminology_provider.dart';
import '../../../shared/services/error_display_service.dart';
import '../providers/chat_screen_state_provider.dart';
import '../services/chat_event_service.dart';
import '../services/event_service.dart';
import '../services/extraction_service.dart';
import '../services/file_processor_service.dart';
import '../utils/event_data_formatter.dart';
import '../widgets/chat_message_widget.dart';
import '../widgets/animated_chat_message_widget.dart';
import '../widgets/chat_input_widget.dart';
import '../widgets/image_preview_card.dart';
import '../widgets/document_preview_card.dart';
import '../widgets/event_confirmation_card.dart';
import '../widgets/batch_event_dialog.dart';
import 'extraction_screen.dart';
import 'pending_edit_screen.dart';
import '../../main/presentation/main_screen.dart';
import 'dart:async';
import 'package:nexa/shared/presentation/theme/app_colors.dart';

class AIChatScreen extends StatefulWidget {
  final bool startNewConversation;

  const AIChatScreen({
    super.key,
    this.startNewConversation = false,
  });

  @override
  State<AIChatScreen> createState() => _AIChatScreenState();
}

class _AIChatScreenState extends State<AIChatScreen>
    with TickerProviderStateMixin {
  // Services (still needed for non-provider functionality)
  final EventService _eventService = EventService();
  final ImagePicker _imagePicker = ImagePicker();

  // Provider (replaces 15+ state variables)
  late ChatScreenStateProvider _stateProvider;

  // Animation controllers (no longer used - kept for compatibility)
  late AnimationController _inputAnimationController;
  late Animation<Offset> _inputSlideAnimation;

  // Scroll-based chips visibility
  bool _showChips = true;
  double _lastScrollOffset = 0;

  @override
  void initState() {
    super.initState();

    // Initialize provider
    _stateProvider = ChatScreenStateProvider();

    // Initialize animation controllers
    _inputAnimationController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    )..forward(); // Start with input visible

    _inputSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.95), // 95% hidden (shows just a tiny hint)
      end: Offset.zero, // Fully visible
    ).animate(CurvedAnimation(
      parent: _inputAnimationController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    ));

    // Scroll behavior disabled for fixed input UX
    // _scrollBehavior initialization removed

    // Start new conversation if requested (e.g., from chat section)
    if (widget.startNewConversation) {
      _stateProvider.startNewConversation();
      _loadGreeting();
    } else if (_stateProvider.conversationHistory.isEmpty) {
      // Load greeting if conversation is empty
      _loadGreeting();
    }

    // Listen to provider changes
    _stateProvider.addListener(_onProviderStateChanged);

    // Listen to scroll for chips visibility
    _stateProvider.scrollController.addListener(_onScroll);
  }

  /// Handle provider state changes
  void _onProviderStateChanged() {
    setState(() {
      // Rebuild when provider state changes
    });
  }

  /// Handle scroll to hide/show chips bar
  void _onScroll() {
    if (!_stateProvider.scrollController.hasClients) return;

    final currentOffset = _stateProvider.scrollController.offset;
    final scrollingDown = currentOffset > _lastScrollOffset;
    final scrollingUp = currentOffset < _lastScrollOffset;

    if ((currentOffset - _lastScrollOffset).abs() > 10) {
      if (scrollingDown && _showChips && currentOffset > 50) {
        setState(() => _showChips = false);
      } else if (scrollingUp && !_showChips) {
        setState(() => _showChips = true);
      }
      _lastScrollOffset = currentOffset;
    }
  }

  @override
  void dispose() {
    _stateProvider.scrollController.removeListener(_onScroll);
    _stateProvider.removeListener(_onProviderStateChanged);
    _stateProvider.dispose(); // Disposes timers, file manager, scroll controller
    _inputAnimationController.dispose();
    super.dispose();
  }

  Future<void> _loadGreeting() async {
    await _stateProvider.loadGreeting();
    // Provider automatically notifies listeners
  }

  void _scrollToBottom({bool animated = false}) {
    if (!_stateProvider.scrollController.hasClients) return;

    // For CustomScrollView, we need to scroll to max extent (bottom)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_stateProvider.scrollController.hasClients) return;

      final maxScroll = _stateProvider.scrollController.position.maxScrollExtent;

      if (animated) {
        _stateProvider.scrollController.animateTo(
          maxScroll,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      } else {
        _stateProvider.scrollController.jumpTo(maxScroll);
      }
    });
  }

  /// Show bottom sheet to choose camera, gallery, or documents
  Future<void> _showImageSourceSelector() async {
    if (kIsWeb) {
      // Web doesn't support camera, just pick from files
      await _pickImagesFromGallery();
      return;
    }

    await showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.pop(context);
                _pickImageFromCamera();
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImagesFromGallery();
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf),
              title: const Text('Upload PDF Document'),
              subtitle: const Text('Extract shift data from PDF files'),
              onTap: () {
                Navigator.pop(context);
                _pickDocument();
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Pick image from camera
  Future<void> _pickImageFromCamera() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image != null) {
        final file = File(image.path);
        await _processImage(file);
      }
    } catch (e) {
      print('[AIChatScreen] Error picking image from camera: $e');
      if (mounted) {
        ErrorDisplayService.showError(context, 'Failed to capture photo: $e');
      }
    }
  }

  /// Pick multiple images from gallery
  Future<void> _pickImagesFromGallery() async {
    try {
      final List<XFile> images = await _imagePicker.pickMultiImage(
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      for (final image in images) {
        final file = File(image.path);
        await _processImage(file);
      }
    } catch (e) {
      print('[AIChatScreen] Error picking images from gallery: $e');
      if (mounted) {
        ErrorDisplayService.showError(context, 'Failed to select images: $e');
      }
    }
  }

  /// Pick document file (PDF only - matching Upload Data tab functionality)
  Future<void> _pickDocument() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: true, // Allow selecting multiple files at once
      );

      if (result != null && result.files.isNotEmpty) {
        // Process each selected file
        for (final platformFile in result.files) {
          if (platformFile.path != null) {
            final file = File(platformFile.path!);
            await _processDocument(file);
          }
        }
      }
    } catch (e) {
      print('[AIChatScreen] Error picking document: $e');
      if (mounted) {
        ErrorDisplayService.showError(context, 'Failed to select document: $e');
      }
    }
  }

  /// Process an image file: extract shift data using Vision API, present in chat for review
  Future<void> _processImage(File imageFile) async {
    try {
      // Process through provider (handles all state management)
      final structuredData = await _stateProvider.processImage(imageFile);

      if (structuredData != null) {
        // Present extracted data in AI chat for review
        final formattedText = EventDataFormatter.formatExtractedData(structuredData);
        await _stateProvider.sendMessage(
          'I extracted this information from your image:\n\n$formattedText'
        );
      }
    } catch (e) {
      print('[AIChatScreen] Error extracting from image: $e');
      if (mounted) {
        ErrorDisplayService.showError(context, 'Failed to extract from image: $e');
      }
    }
  }

  /// Process a PDF document: extract text, get structured data, present in chat for review
  Future<void> _processDocument(File documentFile) async {
    try {
      // Process through provider (handles all state management and PDF extraction)
      final structuredData = await _stateProvider.processDocument(documentFile);

      if (structuredData != null) {
        // Present extracted data in AI chat for review
        final formattedText = EventDataFormatter.formatExtractedData(structuredData);
        await _stateProvider.sendMessage(
          'I extracted this information from your PDF:\n\n$formattedText'
        );
      }
    } catch (e) {
      print('[AIChatScreen] Error extracting from document: $e');
      if (mounted) {
        ErrorDisplayService.showError(context, 'Failed to extract from PDF: $e');
      }
    }
  }

  /// Remove an image from the list
  void _removeImage(File imageFile) {
    _stateProvider.removeImage(imageFile);
  }

  /// Remove a document from the list
  void _removeDocument(File documentFile) {
    _stateProvider.removeDocument(documentFile);
  }

  /// Save extracted shift data as draft
  Future<void> _saveDraftEventFromExtraction() async {
    try {
      final currentData = _stateProvider.currentEventData;

      if (currentData.isEmpty) {
        throw Exception('No shift data to save');
      }

      // Save as draft event
      final payload = Map<String, dynamic>.from(currentData);
      payload['status'] = 'draft';
      await _eventService.createEvent(payload);

      if (mounted) {
        ErrorDisplayService.showSuccess(
          context,
          '✓ Shift saved to Pending Shifts',
        );

        // Send confirmation to chat
        await _stateProvider.sendMessage('✓ Shift saved successfully! You can find it in Pending Shifts.');
      }
    } catch (e) {
      print('[AIChatScreen] Error saving draft: $e');
      if (mounted) {
        ErrorDisplayService.showError(context, 'Failed to save shift: $e');
      }
    }
  }

  /// Start the confirmation timer with countdown (now handled by provider)
  void _startConfirmationTimer() {
    _stateProvider.showConfirmation(
      onAutoSave: _autoSaveAfterTimeout,
    );
  }

  /// Handle confirmation timeout - auto-save (now handled by provider timer)
  void _handleConfirmationTimeout() {
    // This is now handled by the timer manager in the provider
    _autoSaveAfterTimeout();
  }

  /// Auto-save when confirmation times out
  Future<void> _autoSaveAfterTimeout() async {
    final autoSaveMsg = ChatMessage(
      role: 'assistant',
      content: '⏱️ Confirmation timed out. Saving shift automatically...',
    );

    _stateProvider.chatService.addMessage(autoSaveMsg);
    await _saveEventToPending();
  }

  /// Handle user confirmation - save the event
  Future<void> _handleConfirmation() async {
    _stateProvider.hideConfirmation();
    _stateProvider.setLoading(true);

    await _saveEventToPending();

    // Start reset timer (5 seconds after save)
    _stateProvider.resetConfirmationState(
      onComplete: _resetChatSession,
    );
  }

  /// Save event to pending
  Future<void> _saveEventToPending() async {
    try {
      final eventData = {
        ..._stateProvider.currentEventData,
        'status': 'draft',
      };

      final createdEvent = await _eventService.createEvent(eventData);
      final eventId = createdEvent['_id'] ?? createdEvent['id'] ?? '';

      print('[AIChatScreen] ✓ Event saved to database as draft (ID: $eventId)');

      // Show success message
      final successMsg = ChatMessage(
        role: 'assistant',
        content: '✅ Shift saved to Pending Shifts!\n\n[LINK:📋 View in Pending]',
      );

      _stateProvider.chatService.addMessage(successMsg);
      _scrollToBottom(animated: true);

    } catch (e) {
      print('[AIChatScreen] ✗ Failed to save shift: $e');
      if (mounted) {
        ErrorDisplayService.showError(context, 'Failed to save shift: $e');
      }
    } finally {
      _stateProvider.setLoading(false);
    }
  }

  /// Handle edit button - open edit screen
  Future<void> _handleEdit() async {
    final eventData = _stateProvider.currentEventData;
    if (eventData.isEmpty) {
      ErrorDisplayService.showError(context, 'No event data to edit');
      return;
    }

    // Navigate to edit screen with current event data
    // Using a temporary ID since this is not yet saved
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (context) => _InlineEventEditScreen(
          eventData: eventData,
          onSave: (updatedData) {
            // Update the state provider with edited data
            _stateProvider.updateEventData(updatedData);
          },
        ),
      ),
    );

    // If user saved changes, the onSave callback already updated the data
    // The confirmation card will show updated data on rebuild
  }

  /// Handle cancel - discard shift
  void _handleCancel() {
    _stateProvider.hideConfirmation();
    _stateProvider.clearEventData();

    // Add cancellation message
    final cancelMsg = ChatMessage(
      role: 'assistant',
      content: '❌ Event discarded. Let me know if you need anything else!',
    );

    _stateProvider.chatService.addMessage(cancelMsg);
    _scrollToBottom(animated: true);
  }

  /// Reset chat session after save
  void _resetChatSession() {
    _stateProvider.startNewConversation();
    _loadGreeting();
  }

  /// Reset inactivity timer (now handled by provider)
  void _resetInactivityTimer() {
    _stateProvider.resetInactivityTimer();
  }

  /// Show batch creation dialog
  Future<void> _showBatchDialog() async {
    _stateProvider.hideConfirmation();

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return BatchEventDialog(
          templateEventData: _stateProvider.currentEventData,
          onCreateBatch: _createBatchEvents,
        );
      },
    );
  }

  /// Create multiple events with different dates
  Future<void> _createBatchEvents(List<DateTime> dates) async {
    if (dates.isEmpty) return;

    _stateProvider.setLoading(true);

    try {
      final template = Map<String, dynamic>.from(_stateProvider.currentEventData);

      // Create events with different dates
      final events = dates.map((date) {
        return {
          ...template,
          'date': date.toIso8601String(),
          'status': 'draft',
        };
      }).toList();

      print('[AIChatScreen] Attempting to create batch with ${events.length} events...');
      print('[AIChatScreen] Event dates: ${dates.map((d) => d.toIso8601String()).join(', ')}');

      final createdEvents = await _eventService.createBatchEvents(events);

      print('[AIChatScreen] ✓ Created ${createdEvents.length} events');
      print('[AIChatScreen] Created event IDs: ${createdEvents.map((e) => e['_id'] ?? e['id']).join(', ')}');

      // Show success message
      final successMsg = ChatMessage(
        role: 'assistant',
        content: '✅ Created ${createdEvents.length} recurring events!\n\n'
            '📅 Dates:\n${dates.map((d) => '• ${EventDataFormatter.formatDate(d.toIso8601String())}').join('\n')}\n\n'
            '[LINK:📋 View in Pending]',
      );

      _stateProvider.chatService.addMessage(successMsg);
      _scrollToBottom(animated: true);

      // Start reset timer (5 seconds after batch save)
      _stateProvider.resetConfirmationState(
        onComplete: _resetChatSession,
      );

    } catch (e) {
      print('[AIChatScreen] ✗ Failed to create batch events: $e');
      if (mounted) {
        ErrorDisplayService.showError(context, 'Failed to create recurring events: $e');
      }
    } finally {
      _stateProvider.setLoading(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final messages = _stateProvider.conversationHistory;
    final currentData = _stateProvider.currentEventData;
    final hasEventData = currentData.isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      body: Stack(
          children: [
            // Main content with fixed app bar
            CustomScrollView(
              controller: _stateProvider.scrollController,
              slivers: [
                // Fixed SliverAppBar (no animations)
                SliverAppBar(
                  backgroundColor: Colors.white,
                  elevation: 0.5,
                  floating: false,
                  snap: false,
                  pinned: true,
                  toolbarHeight: 56.0,
                  automaticallyImplyLeading: false,
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back, color: AppColors.charcoal),
                    onPressed: () {
                      // Navigate back to Jobs section (Pending tab)
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute<void>(
                          builder: (context) => const MainScreen(initialIndex: 0),
                        ),
                        (route) => false,
                      );
                    },
                  ),
                  title: const Text(
                    'AI Chat',
                    style: TextStyle(
                      color: AppColors.charcoal,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.3,
                    ),
                  ),
                  actions: [
                    // Manual Entry button (structured form)
                    IconButton(
                      icon: const Icon(Icons.edit_note, color: AppColors.successLight, size: 24),
                      tooltip: 'Manual Entry',
                      onPressed: () {
                        // Navigate to ExtractionScreen with uncommented dashboard
                        // Since dashboard is at index 0 but commented, we use initialScreenIndex: 0
                        // and uncomment it temporarily, OR we navigate to the form directly
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (context) => const ExtractionScreen(
                              initialScreenIndex: 0, // Dashboard with tabs
                              initialIndex: 2, // Manual Entry tab (0=Upload, 1=AI Chat, 2=Manual)
                            ),
                          ),
                        );
                      },
                      padding: const EdgeInsets.all(8),
                    ),
                  ],
                ),

                // Info banner as SliverToBoxAdapter
                SliverToBoxAdapter(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.blue.shade50,
                          Colors.purple.shade50,
                        ],
                      ),
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.grey.shade200,
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 16,
                          color: Colors.blue.shade700,
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Tell me about your event and I\'ll help you plan it!',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF4B5563),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Event data banner (if event is being created)
                if (hasEventData)
                  SliverToBoxAdapter(
                    child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.yellow, AppColors.pink],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.event, color: Colors.white, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          currentData['event_name']?.toString() ?? 'Creating event...',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
                  ),

                // Messages list as SliverList (not SliverFillRemaining to fix scroll issues)
                messages.isEmpty
                    ? const SliverFillRemaining(
                        child: Center(
                          child: CircularProgressIndicator(),
                        ),
                      )
                    : SliverPadding(
                        padding: const EdgeInsets.only(
                          left: 16,
                          right: 16,
                          top: 16,
                          bottom: 140, // Add bottom padding for input area and chips visibility
                        ),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final message = messages[index];

                              // Check if this is a confirmation card
                              if (message['content'] == '[CONFIRMATION_CARD]') {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: EventConfirmationCard(
                                    key: ValueKey('confirmation-$index'),
                                    eventData: _stateProvider.currentEventData,
                                    onConfirm: _handleConfirmation,
                                    onEdit: _handleEdit,
                                    onCancel: _handleCancel,
                                    onCreateSeries: _showBatchDialog,
                                    remainingSeconds: _stateProvider.showingConfirmation ? _stateProvider.confirmationSeconds : null,
                                  ),
                                );
                              }

                              // Use animated widget for AI responses
                              final isLastMessage = index == messages.length - 1;
                              final isAiMessage = message['role'] == 'assistant';
                              final shouldAnimate = isLastMessage && isAiMessage &&
                                  messages.length > 1; // Only animate if it's a response to user

                              // Scroll to bottom when last message appears
                              if (isLastMessage && shouldAnimate) {
                                WidgetsBinding.instance.addPostFrameCallback((_) {
                                  _scrollToBottom(animated: true);
                                });
                              }

                              // Convert Map to ChatMessage object for widget
                              final chatMessage = ChatMessage(
                                role: (message['role'] as String?) ?? 'user',
                                content: (message['content'] as String?) ?? '',
                              );

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: AnimatedChatMessageWidget(
                                  key: ValueKey('msg-$index'),
                                  message: chatMessage,
                                  showTypingAnimation: shouldAnimate,
                                  onTypingTick: shouldAnimate ? () {
                                    // Scroll to bottom as AI types each character
                                    WidgetsBinding.instance.addPostFrameCallback((_) {
                                      _scrollToBottom(animated: false);
                                    });
                                  } : null,
                                  onLinkTap: (linkText) async {
                                    if (linkText == 'Check Pending' || linkText == '📋 View in Pending') {
                                      // Clear conversation and navigate to Pending tab
                                      _stateProvider.startNewConversation();
                                      Navigator.pop(context, {'action': 'show_pending'});
                                    }
                                  },
                                ),
                              );
                            },
                            childCount: messages.length,
                          ),
                        ),
                      ),
              ],
            ),

            // Loading indicator overlay (positioned absolutely)
            if (_stateProvider.isLoading)
              Positioned(
                bottom: 100,
                left: 0,
                right: 0,
                child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.grey[400],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'AI is thinking...',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
              ),

            // Floating chips layer (positioned over messages, hides on scroll)
            if (!_stateProvider.isLoading && _stateProvider.selectedImages.isEmpty && _stateProvider.selectedDocuments.isEmpty)
              Positioned(
                left: 0,
                right: 0,
                bottom: 60 + (MediaQuery.of(context).padding.bottom > 0
                  ? MediaQuery.of(context).padding.bottom
                  : 8),
                child: AnimatedSlide(
                  duration: const Duration(milliseconds: 200),
                  offset: _showChips ? Offset.zero : const Offset(0, 1),
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: _showChips ? 1.0 : 0.0,
                    child: IgnorePointer(
                      ignoring: !_showChips,
                      child: Builder(
                        builder: (context) {
                          final terminology = context.read<TerminologyProvider>().singular;
                          return Container(
                            padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  AppColors.surfaceLight.withOpacity(0.3),
                                  AppColors.surfaceLight.withOpacity(0.6),
                                ],
                                stops: const [0.0, 0.5, 1.0],
                              ),
                            ),
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  _buildSuggestionChip(
                                    '📋 New ${terminology[0].toUpperCase()}${terminology.substring(1)}',
                                    'Help me to create a new $terminology and ask me for confirmation to save',
                                  ),
                                  const SizedBox(width: 8),
                                  _buildSuggestionChip(
                                    '🏢 New Client',
                                    'Add new client',
                                  ),
                                  const SizedBox(width: 8),
                                  _buildSuggestionChip(
                                    '👤 New Role',
                                    'Create new staff role',
                                  ),
                                  const SizedBox(width: 8),
                                  _buildSuggestionChip(
                                    '💵 New Tariff',
                                    'Set up new tariff. Tell me: rate, role, and client.',
                                  ),
                                ],
                              ),
                            ),
                          );
                        }
                      ),
                    ),
                  ),
                ),
              ),

            // Fixed input area positioned at bottom
            if (messages.isNotEmpty)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: EdgeInsets.fromLTRB(
                    12,
                    4,
                    12,
                    MediaQuery.of(context).padding.bottom > 0
                      ? MediaQuery.of(context).padding.bottom
                      : 8, // Bottom padding for safe area
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                        // Image preview cards
                        if (_stateProvider.selectedImages.isNotEmpty)
                          ..._stateProvider.selectedImages.map((imageFile) {
                            return ImagePreviewCard(
                              imageFile: imageFile,
                              status: _stateProvider.fileProcessingManager.getImageStatus(imageFile) ?? ExtractionStatus.pending,
                              errorMessage: _stateProvider.fileProcessingManager.getImageError(imageFile),
                              onRemove: () => _removeImage(imageFile),
                            );
                          }),
                        // Document preview cards
                        if (_stateProvider.selectedDocuments.isNotEmpty)
                          ..._stateProvider.selectedDocuments.map((documentFile) {
                            return DocumentPreviewCard(
                              documentFile: documentFile,
                              status: _stateProvider.fileProcessingManager.getDocumentStatus(documentFile) ?? ExtractionStatus.pending,
                              errorMessage: _stateProvider.fileProcessingManager.getDocumentError(documentFile),
                              onRemove: () => _removeDocument(documentFile),
                            );
                          }),

                        // Chat input
                        ChatInputWidget(
                          key: const ValueKey('chat-input'),
                          onAttachmentTap: _showImageSourceSelector,
                          onSendMessage: (message) async {
                            _stateProvider.setLoading(true);

                            try {
                              // Get user's terminology preference
                              final terminology = context.read<TerminologyProvider>().plural;
                              await _stateProvider.chatService.sendMessage(message, terminology: terminology);

                              // Show confirmation card if event is complete
                              if (_stateProvider.chatService.eventComplete && _stateProvider.currentEventData.isNotEmpty) {
                                print('[AIChatScreen] Event complete detected - showing confirmation card...');

                                // Add special marker message for confirmation card
                                final confirmationMsg = ChatMessage(
                                  role: 'system',
                                  content: '[CONFIRMATION_CARD]',
                                );

                                _stateProvider.chatService.addMessage(confirmationMsg);

                                // Start confirmation timer with countdown
                                _startConfirmationTimer();

                                // Reset inactivity timer
                                _resetInactivityTimer();
                              }

                              // Scroll to bottom after message
                              _scrollToBottom(animated: true);
                            } catch (e) {
                              if (!mounted) return;
                              ErrorDisplayService.showError(context, 'Error: ${e.toString()}');
                            } finally {
                              _stateProvider.setLoading(false);
                            }
                          },
                          isLoading: _stateProvider.isLoading,
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
    );
  }

  /// Build a friendly summary of the created event for display in chat
  String _buildEventSummary(Map<String, dynamic> eventData) {
    final buffer = StringBuffer();

    buffer.writeln('✅ Event Created!\n');

    // Event name
    final eventName = eventData['event_name'] ?? 'Unnamed Event';
    buffer.writeln('📋 $eventName');

    // Date
    final date = eventData['date'];
    if (date != null) {
      final formattedDate = _formatDate(date.toString());
      buffer.writeln('📅 $formattedDate');
    }

    // Client
    final client = eventData['client_name'];
    if (client != null) {
      buffer.writeln('🏢 $client');
    }

    // Roles
    final roles = eventData['roles'];
    if (roles is List && roles.isNotEmpty) {
      buffer.writeln('\n👥 Staff Needed:');
      for (final role in roles) {
        if (role is! Map) continue;
        final roleName = role['role']?.toString() ?? 'Staff';
        final count = role['count'] as int? ?? 0;
        final callTime = role['call_time'];
        final timeStr =
            callTime != null ? ' (arrive at ${_formatTime(callTime.toString())})' : '';
        buffer.writeln(
            '  • $count ${_capitalize(roleName)}${count > 1 ? 's' : ''}$timeStr');
      }
    }

    // Venue
    final venueName = eventData['venue_name'];
    final venueAddress = eventData['venue_address'];
    if (venueName != null || venueAddress != null) {
      buffer.writeln('\n📍 Venue:');
      if (venueName != null) {
        buffer.writeln('   $venueName');
      }
      if (venueAddress != null) {
        buffer.writeln('   $venueAddress');
      }
    }

    // Event times (if provided)
    final startTime = eventData['start_time'];
    final endTime = eventData['end_time'];
    if (startTime != null || endTime != null) {
      buffer.write('\n⏰ Event Time: ');
      if (startTime != null) {
        buffer.write(_formatTime(startTime.toString()));
      }
      if (endTime != null) {
        buffer.write(' - ${_formatTime(endTime.toString())}');
      }
      buffer.writeln();
    }

    buffer.writeln('\nSaved to Pending - ready to publish!');
    buffer.writeln('\n[LINK:Check Pending]');

    return buffer.toString();
  }

  /// Format ISO date string to human-readable format
  String _formatDate(String isoDate) {
    try {
      final date = DateTime.parse(isoDate);
      final months = [
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
        'December'
      ];
      return '${months[date.month - 1]} ${date.day}, ${date.year}';
    } catch (_) {
      return isoDate;
    }
  }

  /// Format 24-hour time to 12-hour format with AM/PM
  String _formatTime(String time24) {
    try {
      final parts = time24.split(':');
      final hour = int.parse(parts[0]);
      final minute = parts[1];
      final period = hour >= 12 ? 'PM' : 'AM';
      final hour12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
      return '$hour12:$minute $period';
    } catch (_) {
      return time24;
    }
  }

  /// Capitalize first letter of a string
  String _capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

  /// Build a suggestion chip for quick actions
  Widget _buildSuggestionChip(String label, String query) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.7),
            Colors.white.withOpacity(0.5),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.8),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () async {
            _stateProvider.setLoading(true);

            try {
              await _stateProvider.chatService.sendMessage(query);

              // Show confirmation card if event is complete
              if (_stateProvider.chatService.eventComplete && _stateProvider.currentEventData.isNotEmpty) {
                print('[AIChatScreen] Event complete detected - showing confirmation card...');

                // Add special marker message for confirmation card
                final confirmationMsg = ChatMessage(
                  role: 'system',
                  content: '[CONFIRMATION_CARD]',
                );

                _stateProvider.chatService.addMessage(confirmationMsg);

                // Start confirmation timer with countdown
                _startConfirmationTimer();

                // Reset inactivity timer
                _resetInactivityTimer();
              }

              // Scroll to bottom after message
              _scrollToBottom(animated: true);
            } catch (e) {
              if (!mounted) return;
              ErrorDisplayService.showError(context, 'Error: ${e.toString()}');
            } finally {
              _stateProvider.setLoading(false);
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.charcoal,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Inline edit screen for editing event data before saving
class _InlineEventEditScreen extends StatefulWidget {
  final Map<String, dynamic> eventData;
  final Function(Map<String, dynamic>) onSave;

  const _InlineEventEditScreen({
    required this.eventData,
    required this.onSave,
  });

  @override
  State<_InlineEventEditScreen> createState() => _InlineEventEditScreenState();
}

class _InlineEventEditScreenState extends State<_InlineEventEditScreen> {
  late final TextEditingController _eventNameCtrl;
  late final TextEditingController _clientNameCtrl;
  late final TextEditingController _venueNameCtrl;
  late final TextEditingController _venueAddressCtrl;
  late final TextEditingController _guestCountCtrl;

  DateTime? _selectedDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  List<Map<String, dynamic>> _roles = [];

  @override
  void initState() {
    super.initState();
    final d = widget.eventData;
    _eventNameCtrl = TextEditingController(text: (d['event_name'] ?? '').toString());
    _clientNameCtrl = TextEditingController(text: (d['client_name'] ?? '').toString());
    _venueNameCtrl = TextEditingController(text: (d['venue_name'] ?? '').toString());
    _venueAddressCtrl = TextEditingController(text: (d['venue_address'] ?? '').toString());
    _guestCountCtrl = TextEditingController(text: (d['guest_count'] ?? '').toString());

    // Parse date
    final dateStr = d['date']?.toString();
    if (dateStr != null && dateStr.isNotEmpty) {
      try {
        _selectedDate = DateTime.parse(dateStr);
      } catch (_) {}
    }

    // Parse times
    _startTime = _parseTime(d['start_time']?.toString());
    _endTime = _parseTime(d['end_time']?.toString());

    // Parse roles
    final rolesData = d['roles'];
    if (rolesData is List) {
      _roles = rolesData.map((r) => Map<String, dynamic>.from(r as Map)).toList();
    }
  }

  TimeOfDay? _parseTime(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return null;
    try {
      final parts = timeStr.split(':');
      if (parts.length >= 2) {
        return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      }
    } catch (_) {}
    return null;
  }

  String _formatTime(TimeOfDay? time) {
    if (time == null) return '';
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final firstDate = DateTime(2020, 1, 1);
    final lastDate = now.add(const Duration(days: 365 * 5));

    DateTime initialDate = _selectedDate ?? now;
    if (initialDate.isBefore(firstDate)) initialDate = now;
    if (initialDate.isAfter(lastDate)) initialDate = now;

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
              onSurface: AppColors.charcoal,
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
              onSurface: AppColors.charcoal,
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

  void _save() {
    final updatedData = Map<String, dynamic>.from(widget.eventData);
    updatedData['event_name'] = _eventNameCtrl.text.trim();
    updatedData['client_name'] = _clientNameCtrl.text.trim();
    updatedData['venue_name'] = _venueNameCtrl.text.trim();
    updatedData['venue_address'] = _venueAddressCtrl.text.trim();
    updatedData['guest_count'] = _guestCountCtrl.text.trim();
    updatedData['date'] = _formatDate(_selectedDate);
    updatedData['start_time'] = _formatTime(_startTime);
    updatedData['end_time'] = _formatTime(_endTime);
    updatedData['roles'] = _roles;

    widget.onSave(updatedData);
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _eventNameCtrl.dispose();
    _clientNameCtrl.dispose();
    _venueNameCtrl.dispose();
    _venueAddressCtrl.dispose();
    _guestCountCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: AppColors.navySpaceCadet,
        foregroundColor: Colors.white,
        title: const Text('Edit Event'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('Save', style: TextStyle(color: AppColors.warning, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildTextField('Event Name', _eventNameCtrl, Icons.celebration),
          const SizedBox(height: 16),
          _buildTextField('Client', _clientNameCtrl, Icons.business),
          const SizedBox(height: 16),
          _buildDatePicker(),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildTimePicker('Start Time', _startTime, true)),
              const SizedBox(width: 12),
              Expanded(child: _buildTimePicker('End Time', _endTime, false)),
            ],
          ),
          const SizedBox(height: 16),
          _buildTextField('Venue', _venueNameCtrl, Icons.location_on),
          const SizedBox(height: 16),
          _buildTextField('Address', _venueAddressCtrl, Icons.map),
          const SizedBox(height: 16),
          _buildTextField('Guest Count', _guestCountCtrl, Icons.groups, keyboardType: TextInputType.number),
          const SizedBox(height: 24),
          if (_roles.isNotEmpty) ...[
            const Text('Positions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            _buildRolesList(),
          ],
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.techBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Save Changes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, IconData icon, {TextInputType? keyboardType}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: AppColors.techBlue),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.techBlue, width: 2)),
          ),
        ),
      ],
    );
  }

  Widget _buildDatePicker() {
    final hasDate = _selectedDate != null;
    final displayText = hasDate
        ? '${_selectedDate!.month}/${_selectedDate!.day}/${_selectedDate!.year}'
        : 'Select date';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Date', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
        const SizedBox(height: 8),
        InkWell(
          onTap: _pickDate,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today, color: AppColors.techBlue),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    displayText,
                    style: TextStyle(
                      fontSize: 16,
                      color: hasDate ? Colors.black87 : Colors.grey.shade500,
                    ),
                  ),
                ),
                Icon(Icons.arrow_drop_down, color: Colors.grey.shade600),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimePicker(String label, TimeOfDay? time, bool isStart) {
    final hasTime = time != null;
    final displayText = hasTime ? time.format(context) : 'Select';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
        const SizedBox(height: 8),
        InkWell(
          onTap: () => _pickTime(isStart: isStart),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                Icon(Icons.access_time, color: isStart ? AppColors.success : AppColors.warning, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    displayText,
                    style: TextStyle(fontSize: 15, color: hasTime ? Colors.black87 : Colors.grey.shade500),
                  ),
                ),
                Icon(Icons.arrow_drop_down, color: Colors.grey.shade600, size: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRolesList() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          const Icon(Icons.person_outline, color: AppColors.techBlue, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(roleName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
          ),
          Container(
            decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: count > 1 ? () => _updateRoleCount(index, count - 1) : null,
                  icon: Icon(Icons.remove, size: 18, color: count > 1 ? AppColors.errorDark : Colors.grey),
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(8),
                ),
                SizedBox(
                  width: 32,
                  child: Text(count.toString(), textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
                IconButton(
                  onPressed: () => _updateRoleCount(index, count + 1),
                  icon: const Icon(Icons.add, size: 18, color: AppColors.success),
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(8),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _updateRoleCount(int index, int newCount) {
    if (newCount < 1) return;
    setState(() {
      _roles[index] = {..._roles[index], 'count': newCount};
    });
  }
}
