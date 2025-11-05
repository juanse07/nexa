import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For HapticFeedback
import 'package:image_picker/image_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../services/chat_event_service.dart';
import '../services/event_service.dart';
import '../services/extraction_service.dart';
import '../services/file_processor_service.dart';
import '../widgets/chat_message_widget.dart';
import '../widgets/chat_input_widget.dart';
import '../widgets/image_preview_card.dart';
import '../widgets/document_preview_card.dart';
import '../widgets/event_confirmation_card.dart';
import '../widgets/batch_event_dialog.dart';
import 'extraction_screen.dart';
import 'dart:async';

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
  final ChatEventService _aiChatService = ChatEventService();
  final EventService _eventService = EventService();
  final ExtractionService _extractionService = ExtractionService();
  final ImagePicker _imagePicker = ImagePicker();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;

  // Confirmation flow state
  bool _showingConfirmation = false;
  Timer? _confirmationTimer;
  Timer? _resetTimer;
  Timer? _inactivityTimer;
  int _confirmationSeconds = 90; // Changed from 30s to 90s (1.5 minutes)

  // Scroll animation state
  late AnimationController _inputAnimationController;
  late Animation<Offset> _inputSlideAnimation;
  bool _isInputVisible = true;
  Timer? _autoShowTimer;

  // Image handling state
  final List<File> _selectedImages = [];
  final Map<File, ExtractionStatus> _imageStatuses = {};
  final Map<File, String?> _imageErrors = {};

  // Document handling state
  final List<File> _selectedDocuments = [];
  final Map<File, ExtractionStatus> _documentStatuses = {};
  final Map<File, String?> _documentErrors = {};

  @override
  void initState() {
    super.initState();

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

    // Start new conversation if requested (e.g., from chat section)
    if (widget.startNewConversation) {
      _aiChatService.startNewConversation();
      _loadGreeting();
    } else if (_aiChatService.conversationHistory.isEmpty) {
      // Load greeting if conversation is empty
      _loadGreeting();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _inputAnimationController.dispose();
    _confirmationTimer?.cancel();
    _resetTimer?.cancel();
    _inactivityTimer?.cancel();
    _autoShowTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadGreeting() async {
    await _aiChatService.getGreeting();
    setState(() {
      // Greeting is already added by getGreeting()
    });
  }

  void _scrollToBottom({bool animated = false}) {
    if (!_scrollController.hasClients) return;

    if (animated) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } else {
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    }
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
              subtitle: const Text('Extract event data from PDF files'),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to capture photo: $e'),
            backgroundColor: Colors.red,
          ),
        );
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to select images: $e'),
            backgroundColor: Colors.red,
          ),
        );
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to select document: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Process an image file: extract event data using Vision API, present in chat for review
  Future<void> _processImage(File imageFile) async {
    // Add image to list with pending status
    setState(() {
      _selectedImages.add(imageFile);
      _imageStatuses[imageFile] = ExtractionStatus.pending;
    });

    // Start extraction
    setState(() {
      _imageStatuses[imageFile] = ExtractionStatus.extracting;
    });

    try {
      // Read image bytes and convert to base64
      final bytes = await imageFile.readAsBytes();
      final base64String = base64Encode(bytes);
      final processedInput = '[[IMAGE_BASE64]]:$base64String';

      // Call extraction API (uses Groq: Llama 4 Scout for images, Llama 3.1 for text)
      final structuredData = await _extractionService.extractStructuredData(
        input: processedInput,
      );

      // Mark as completed
      setState(() {
        _imageStatuses[imageFile] = ExtractionStatus.completed;
      });

      // Auto-remove image from list after successful extraction
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          setState(() {
            _selectedImages.remove(imageFile);
            _imageStatuses.remove(imageFile);
            _imageErrors.remove(imageFile);
          });
        }
      });

      // Present extracted data in AI chat for review with Save button
      final formattedText = _formatExtractedData(structuredData);
      await _aiChatService.sendMessage(
        'I extracted this information from your image:\n\n$formattedText'
      );

      // Store the extracted data in the chat service for the save action
      _aiChatService.updateEventData(structuredData);

      setState(() {});
    } catch (e) {
      print('[AIChatScreen] Error extracting from image: $e');
      setState(() {
        _imageStatuses[imageFile] = ExtractionStatus.failed;
        _imageErrors[imageFile] = e.toString();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to extract from image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Process a PDF document: extract text, get structured data, present in chat for review
  Future<void> _processDocument(File documentFile) async {
    // Add document to list with pending status
    setState(() {
      _selectedDocuments.add(documentFile);
      _documentStatuses[documentFile] = ExtractionStatus.pending;
    });

    // Start extraction
    setState(() {
      _documentStatuses[documentFile] = ExtractionStatus.extracting;
    });

    try {
      // Read PDF bytes
      final bytes = await documentFile.readAsBytes();

      // Extract text from PDF using Syncfusion
      final extractedText = await _extractTextFromPdf(bytes);

      if (extractedText.trim().isEmpty) {
        throw Exception('No text found in PDF. The PDF might be scanned or image-based.');
      }

      // Send extracted text to extraction API to get structured event data
      final structuredData = await _extractionService.extractStructuredData(
        input: extractedText,
      );

      // Mark as completed
      setState(() {
        _documentStatuses[documentFile] = ExtractionStatus.completed;
      });

      // Auto-remove document from list after successful extraction
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          setState(() {
            _selectedDocuments.remove(documentFile);
            _documentStatuses.remove(documentFile);
            _documentErrors.remove(documentFile);
          });
        }
      });

      // Present extracted data in AI chat for review with Save button
      final formattedText = _formatExtractedData(structuredData);
      await _aiChatService.sendMessage(
        'I extracted this information from your PDF:\n\n$formattedText'
      );

      // Store the extracted data in the chat service for the save action
      _aiChatService.updateEventData(structuredData);

      setState(() {});
    } catch (e) {
      print('[AIChatScreen] Error extracting from document: $e');
      setState(() {
        _documentStatuses[documentFile] = ExtractionStatus.failed;
        _documentErrors[documentFile] = e.toString();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to extract from PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Extract text from PDF bytes using Syncfusion PDF library
  Future<String> _extractTextFromPdf(Uint8List bytes) async {
    final document = PdfDocument(inputBytes: bytes);
    final extractor = PdfTextExtractor(document);
    final buffer = StringBuffer();

    for (int i = 0; i < document.pages.count; i++) {
      buffer.writeln(extractor.extractText(startPageIndex: i, endPageIndex: i));
    }

    document.dispose();
    return buffer.toString();
  }

  /// Format extracted data as readable text
  String _formatExtractedData(Map<String, dynamic> data) {
    final buffer = StringBuffer();

    if (data['event_name'] != null && data['event_name'].toString().isNotEmpty) {
      buffer.writeln('Event: ${data['event_name']}');
    }
    if (data['client_name'] != null && data['client_name'].toString().isNotEmpty) {
      buffer.writeln('Client: ${data['client_name']}');
    }
    if (data['date'] != null && data['date'].toString().isNotEmpty) {
      buffer.writeln('Date: ${data['date']}');
    }
    if (data['venue'] != null && data['venue'].toString().isNotEmpty) {
      buffer.writeln('Venue: ${data['venue']}');
    }
    if (data['location'] != null && data['location'].toString().isNotEmpty) {
      buffer.writeln('Location: ${data['location']}');
    }
    if (data['call_time'] != null && data['call_time'].toString().isNotEmpty) {
      buffer.writeln('Call Time: ${data['call_time']}');
    }
    if (data['setup_time'] != null && data['setup_time'].toString().isNotEmpty) {
      buffer.writeln('Setup Time: ${data['setup_time']}');
    }
    if (data['headcount'] != null && data['headcount'].toString().isNotEmpty) {
      buffer.writeln('Headcount: ${data['headcount']}');
    }
    if (data['attire'] != null && data['attire'].toString().isNotEmpty) {
      buffer.writeln('Attire: ${data['attire']}');
    }

    // Add roles if present
    final roles = data['roles'];
    if (roles != null && roles is List && roles.isNotEmpty) {
      buffer.writeln('\nStaff Roles:');
      for (final role in roles) {
        if (role is Map) {
          final roleName = role['role_name'] ?? role['role'] ?? '';
          final count = role['count'] ?? role['quantity'] ?? '';
          if (roleName.toString().isNotEmpty) {
            buffer.writeln('- $roleName${count.toString().isNotEmpty ? ' ($count)' : ''}');
          }
        }
      }
    }

    return buffer.toString().trim();
  }

  /// Remove an image from the list
  void _removeImage(File imageFile) {
    setState(() {
      _selectedImages.remove(imageFile);
      _imageStatuses.remove(imageFile);
      _imageErrors.remove(imageFile);
    });
  }

  /// Remove a document from the list
  void _removeDocument(File documentFile) {
    setState(() {
      _selectedDocuments.remove(documentFile);
      _documentStatuses.remove(documentFile);
      _documentErrors.remove(documentFile);
    });
  }

  /// Save extracted event data as draft
  Future<void> _saveDraftEventFromExtraction() async {
    try {
      final currentData = _aiChatService.currentEventData;

      if (currentData.isEmpty) {
        throw Exception('No event data to save');
      }

      // Save as draft event
      final payload = Map<String, dynamic>.from(currentData);
      payload['status'] = 'draft';
      await _eventService.createEvent(payload);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Event saved to Pending Events'),
            backgroundColor: Color(0xFF059669),
            duration: Duration(seconds: 2),
          ),
        );

        // Send confirmation to chat
        await _aiChatService.sendMessage('✓ Event saved successfully! You can find it in Pending Events.');
        setState(() {});
      }
    } catch (e) {
      print('[AIChatScreen] Error saving draft: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save event: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Start the confirmation timer with countdown
  void _startConfirmationTimer() {
    _confirmationTimer?.cancel();
    _confirmationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        _confirmationSeconds--;
      });

      if (_confirmationSeconds <= 0) {
        timer.cancel();
        _handleConfirmationTimeout();
      }
    });
  }

  /// Handle confirmation timeout - auto-save
  void _handleConfirmationTimeout() {
    if (!_showingConfirmation) return;

    setState(() {
      _showingConfirmation = false;
    });

    // Auto-save after timeout
    _autoSaveAfterTimeout();
  }

  /// Auto-save when confirmation times out
  Future<void> _autoSaveAfterTimeout() async {
    final autoSaveMsg = ChatMessage(
      role: 'assistant',
      content: '⏱️ Confirmation timed out. Saving event automatically...',
    );

    setState(() {
      _aiChatService.addMessage(autoSaveMsg);
    });

    await _saveEventToPending();
  }

  /// Handle user confirmation - save the event
  Future<void> _handleConfirmation() async {
    _confirmationTimer?.cancel();

    setState(() {
      _showingConfirmation = false;
      _isLoading = true;
    });

    await _saveEventToPending();

    // Start reset timer (5 seconds after save)
    _resetTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        _resetChatSession();
      }
    });
  }

  /// Save event to pending
  Future<void> _saveEventToPending() async {
    try {
      final eventData = {
        ..._aiChatService.currentEventData,
        'status': 'draft',
      };

      final createdEvent = await _eventService.createEvent(eventData);
      final eventId = createdEvent['_id'] ?? createdEvent['id'] ?? '';

      print('[AIChatScreen] ✓ Event saved to database as draft (ID: $eventId)');

      // Show success message
      final successMsg = ChatMessage(
        role: 'assistant',
        content: '✅ Event saved to Pending Events!\n\n[LINK:📋 View in Pending]',
      );

      setState(() {
        _aiChatService.addMessage(successMsg);
      });

      _scrollToBottom(animated: true);

    } catch (e) {
      print('[AIChatScreen] ✗ Failed to save event: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save event: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Handle edit button - continue conversation
  void _handleEdit() {
    _confirmationTimer?.cancel();

    setState(() {
      _showingConfirmation = false;
    });

    // Add message indicating user wants to edit
    final editMsg = ChatMessage(
      role: 'assistant',
      content: '✏️ Sure! What would you like to change?',
    );

    setState(() {
      _aiChatService.addMessage(editMsg);
    });

    _scrollToBottom(animated: true);
  }

  /// Handle cancel - discard event
  void _handleCancel() {
    _confirmationTimer?.cancel();

    setState(() {
      _showingConfirmation = false;
      _aiChatService.clearCurrentEventData();
    });

    // Add cancellation message
    final cancelMsg = ChatMessage(
      role: 'assistant',
      content: '❌ Event discarded. Let me know if you need anything else!',
    );

    setState(() {
      _aiChatService.addMessage(cancelMsg);
    });

    _scrollToBottom(animated: true);
  }

  /// Reset chat session after save
  void _resetChatSession() {
    _aiChatService.startNewConversation();
    _loadGreeting();

    setState(() {
      _selectedImages.clear();
      _selectedDocuments.clear();
      _imageStatuses.clear();
      _documentStatuses.clear();
      _imageErrors.clear();
      _documentErrors.clear();
    });
  }

  /// Reset inactivity timer
  void _resetInactivityTimer() {
    _inactivityTimer?.cancel();

    if (_showingConfirmation || _aiChatService.currentEventData.isEmpty) {
      return;
    }

    _inactivityTimer = Timer(const Duration(minutes: 2), () {
      if (mounted && _showingConfirmation) {
        _autoSaveAfterTimeout();
      }
    });
  }

  /// Handle scroll notifications for animations
  bool _handleScrollNotification(ScrollNotification notification) {
    // Handle different notification types
    if (notification is ScrollStartNotification) {
      // Cancel auto-show timer when user starts scrolling
      _autoShowTimer?.cancel();
      return false;
    }

    if (notification is ScrollEndNotification) {
      // Start auto-show timer when scrolling ends
      _autoShowTimer?.cancel();
      _autoShowTimer = Timer(const Duration(seconds: 15), () {
        if (!_isInputVisible && mounted) {
          _showInput();
        }
      });

      // Check if at bottom when scroll ends
      final isAtBottom = _scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 100;

      if (isAtBottom && !_isInputVisible) {
        _showInput();
      }
      return false;
    }

    // Only process ScrollUpdateNotification
    if (notification is! ScrollUpdateNotification) return false;

    final scrollDelta = notification.scrollDelta ?? 0;

    // Skip if no actual movement
    if (scrollDelta.abs() < 5) return false;

    // Check if we're at the bottom of the list
    final isAtBottom = _scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 100;

    // Always show input when at bottom
    if (isAtBottom) {
      if (!_isInputVisible) {
        _showInput();
      }
      return false;
    }

    // Simple direction-based logic with threshold
    const scrollThreshold = 10.0;

    if (scrollDelta > scrollThreshold && _isInputVisible) {
      // Scrolling down - hide input
      _hideInput();
    } else if (scrollDelta < -scrollThreshold && !_isInputVisible) {
      // Scrolling up - show input
      _showInput();
    }

    return false;
  }

  void _hideInput() {
    if (!_isInputVisible) return;
    setState(() {
      _isInputVisible = false;
    });
    _inputAnimationController.reverse();
    // Removed haptic feedback to prevent excessive vibration
  }

  void _showInput() {
    if (_isInputVisible) return;
    setState(() {
      _isInputVisible = true;
    });
    _inputAnimationController.forward();
    // Removed haptic feedback to prevent excessive vibration
  }

  /// Show batch creation dialog
  Future<void> _showBatchDialog() async {
    _confirmationTimer?.cancel();

    setState(() {
      _showingConfirmation = false;
    });

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return BatchEventDialog(
          templateEventData: _aiChatService.currentEventData,
          onCreateBatch: _createBatchEvents,
        );
      },
    );
  }

  /// Create multiple events with different dates
  Future<void> _createBatchEvents(List<DateTime> dates) async {
    if (dates.isEmpty) return;

    setState(() {
      _isLoading = true;
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

      print('[AIChatScreen] Attempting to create batch with ${events.length} events...');
      print('[AIChatScreen] Event dates: ${dates.map((d) => d.toIso8601String()).join(', ')}');

      final createdEvents = await _eventService.createBatchEvents(events);

      print('[AIChatScreen] ✓ Created ${createdEvents.length} events');
      print('[AIChatScreen] Created event IDs: ${createdEvents.map((e) => e['_id'] ?? e['id']).join(', ')}');

      // Show success message
      final successMsg = ChatMessage(
        role: 'assistant',
        content: '✅ Created ${createdEvents.length} recurring events!\n\n'
            '📅 Dates:\n${dates.map((d) => '• ${_formatDate(d.toIso8601String())}').join('\n')}\n\n'
            '[LINK:📋 View in Pending]',
      );

      setState(() {
        _aiChatService.addMessage(successMsg);
      });

      _scrollToBottom(animated: true);

      // Start reset timer (5 seconds after batch save)
      _resetTimer = Timer(const Duration(seconds: 5), () {
        if (mounted) {
          _resetChatSession();
        }
      });

    } catch (e) {
      print('[AIChatScreen] ✗ Failed to create batch events: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create recurring events: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final messages = _aiChatService.conversationHistory;
    final currentData = _aiChatService.currentEventData;
    final hasEventData = currentData.isNotEmpty;

    return NotificationListener<ScrollNotification>(
      onNotification: _handleScrollNotification,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: Stack(
          children: [
            // Main content with fixed app bar
            CustomScrollView(
              controller: _scrollController,
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
                    icon: const Icon(Icons.arrow_back, color: Color(0xFF1F2937)),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  title: const Text(
                    'AI Chat',
                    style: TextStyle(
                      color: Color(0xFF1F2937),
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.3,
                    ),
                  ),
                  actions: [
                    // Manual Entry button (structured form)
                    IconButton(
                      icon: const Icon(Icons.edit_note, color: Color(0xFF10B981), size: 24),
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
                    // AI Model toggle (LLAMA vs GPT-OSS)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: PopupMenuButton<String>(
                        onSelected: (value) {
                      setState(() {
                        _aiChatService.setModelPreference(value);
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Switched to ${value == 'llama' ? 'Llama 3.1 8B' : 'GPT-OSS 20B'}',
                          ),
                          duration: const Duration(seconds: 2),
                          backgroundColor: value == 'llama' ? Colors.purple : Colors.black,
                        ),
                      );
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'llama',
                        child: Row(
                          children: [
                            Icon(
                              Icons.bolt,
                              size: 18,
                              color: _aiChatService.modelPreference == 'llama'
                                  ? Colors.purple
                                  : Colors.grey,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'LLAMA (Fast)',
                              style: TextStyle(
                                fontWeight: _aiChatService.modelPreference == 'llama'
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                            if (_aiChatService.modelPreference == 'llama')
                              const SizedBox(width: 8),
                            if (_aiChatService.modelPreference == 'llama')
                              const Icon(Icons.check, size: 16, color: Colors.purple),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'gpt-oss',
                        child: Row(
                          children: [
                            Icon(
                              Icons.psychology,
                              size: 18,
                              color: _aiChatService.modelPreference == 'gpt-oss'
                                  ? Colors.black
                                  : Colors.grey,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'GPT-OSS 20B (Powerful)',
                              style: TextStyle(
                                fontWeight: _aiChatService.modelPreference == 'gpt-oss'
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                            if (_aiChatService.modelPreference == 'gpt-oss')
                              const SizedBox(width: 8),
                            if (_aiChatService.modelPreference == 'gpt-oss')
                              const Icon(Icons.check, size: 16, color: Colors.black),
                          ],
                        ),
                      ),
                    ],
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: _aiChatService.modelPreference == 'llama'
                            ? Colors.purple.withValues(alpha: 0.12)
                            : Colors.black.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _aiChatService.modelPreference == 'llama'
                              ? Colors.purple.withValues(alpha: 0.3)
                              : Colors.black.withValues(alpha: 0.2),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _aiChatService.modelPreference == 'llama'
                                ? Icons.bolt
                                : Icons.psychology,
                            size: 14,
                            color: _aiChatService.modelPreference == 'llama'
                                ? Colors.purple.shade700
                                : Colors.black,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _aiChatService.modelPreference == 'llama' ? 'LLAMA' : 'GPT-OSS',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _aiChatService.modelPreference == 'llama'
                                  ? Colors.purple.shade700
                                  : Colors.black,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.arrow_drop_down,
                            size: 16,
                            color: _aiChatService.modelPreference == 'llama'
                                ? Colors.purple.shade700
                                : Colors.black,
                          ),
                        ],
                      ),
                    ),
                  ),
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
                  colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
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
                          bottom: 120, // Add bottom padding for input area visibility
                        ),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final message = messages[index];

                              // Check if this is a confirmation card
                              if (message.content == '[CONFIRMATION_CARD]') {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: EventConfirmationCard(
                                    key: ValueKey('confirmation-$index'),
                                    eventData: _aiChatService.currentEventData,
                                    onConfirm: _handleConfirmation,
                                    onEdit: _handleEdit,
                                    onCancel: _handleCancel,
                                    onCreateSeries: _showBatchDialog,
                                    remainingSeconds: _showingConfirmation ? _confirmationSeconds : null,
                                  ),
                                );
                              }

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: ChatMessageWidget(
                                  key: ValueKey('msg-$index'),
                                  message: message,
                                  onLinkTap: (linkText) async {
                                    if (linkText == 'Check Pending' || linkText == '📋 View in Pending') {
                                      // Clear conversation and navigate to Pending tab
                                      _aiChatService.startNewConversation();
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
            if (_isLoading)
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

            // Animated input area positioned at bottom
            if (messages.isNotEmpty)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SlideTransition(
                  position: _inputSlideAnimation,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 8), // Added bottom padding
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
                        // Add a visual hint bar when partially hidden
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          width: _isInputVisible ? 0 : 30,
                          height: _isInputVisible ? 0 : 3,
                          margin: EdgeInsets.only(bottom: _isInputVisible ? 0 : 4),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                  // Image preview cards
                  if (_selectedImages.isNotEmpty)
                    ..._selectedImages.map((imageFile) {
                      return ImagePreviewCard(
                        imageFile: imageFile,
                        status: _imageStatuses[imageFile] ?? ExtractionStatus.pending,
                        errorMessage: _imageErrors[imageFile],
                        onRemove: () => _removeImage(imageFile),
                      );
                    }).toList(),
                  // Document preview cards
                  if (_selectedDocuments.isNotEmpty)
                    ..._selectedDocuments.map((documentFile) {
                      return DocumentPreviewCard(
                        documentFile: documentFile,
                        status: _documentStatuses[documentFile] ?? ExtractionStatus.pending,
                        errorMessage: _documentErrors[documentFile],
                        onRemove: () => _removeDocument(documentFile),
                      );
                    }).toList(),

                  // Quick action suggestion chips (for common manager tasks)
                  if (!_isLoading && _selectedImages.isEmpty && _selectedDocuments.isEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildSuggestionChip(
                              '📋 New Event',
                              'Create new event. Tell me: how many staff roles needed, start time, end time, and venue.',
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
                    ),

                  // Chat input
                  ChatInputWidget(
                    key: const ValueKey('chat-input'),
                    onAttachmentTap: _showImageSourceSelector,
                    onSendMessage: (message) async {
                  setState(() {
                    _isLoading = true;
                  });

                  try {
                    await _aiChatService.sendMessage(message);

                    // Show confirmation card if event is complete
                    if (_aiChatService.eventComplete && _aiChatService.currentEventData.isNotEmpty) {
                      print('[AIChatScreen] Event complete detected - showing confirmation card...');

                      // Add special marker message for confirmation card
                      final confirmationMsg = ChatMessage(
                        role: 'system',
                        content: '[CONFIRMATION_CARD]',
                      );

                      setState(() {
                        _aiChatService.addMessage(confirmationMsg);
                        _showingConfirmation = true;
                        _confirmationSeconds = 90; // Reset to 90 seconds
                      });

                      // Start confirmation timer with countdown
                      _startConfirmationTimer();

                      // Reset inactivity timer
                      _resetInactivityTimer();
                    }

                    // Scroll to bottom after message
                    _scrollToBottom(animated: true);
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
                        _isLoading = false;
                      });
                    }
                  }
                },
                isLoading: _isLoading,
              ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
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
    return ActionChip(
      label: Text(label),
      onPressed: () async {
        setState(() {
          _isLoading = true;
        });

        try {
          await _aiChatService.sendMessage(query);

          // Show confirmation card if event is complete
          if (_aiChatService.eventComplete && _aiChatService.currentEventData.isNotEmpty) {
            print('[AIChatScreen] Event complete detected - showing confirmation card...');

            // Add special marker message for confirmation card
            final confirmationMsg = ChatMessage(
              role: 'system',
              content: '[CONFIRMATION_CARD]',
            );

            setState(() {
              _aiChatService.addMessage(confirmationMsg);
              _showingConfirmation = true;
              _confirmationSeconds = 90; // Reset to 90 seconds
            });

            // Start confirmation timer with countdown
            _startConfirmationTimer();

            // Reset inactivity timer
            _resetInactivityTimer();
          }

          // Scroll to bottom after message
          _scrollToBottom(animated: true);
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
              _isLoading = false;
            });
          }
        }
      },
      backgroundColor: Colors.white,
      side: BorderSide(color: Colors.grey.shade300, width: 1),
      labelStyle: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: Color(0xFF475569),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      elevation: 0,
      pressElevation: 2,
    );
  }
}
