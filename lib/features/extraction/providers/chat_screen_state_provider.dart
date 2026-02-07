import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/chat_timer_manager.dart';
import '../services/file_processing_manager.dart';
import '../services/chat_event_service.dart';
import '../services/extraction_service.dart';

/// Consolidated state management for AI Chat Screen
///
/// Manages all screen state in one place:
/// - Loading states
/// - Confirmation flow
/// - Timer management
/// - File processing
/// - Input visibility
/// - Scroll controller
///
/// Replaces 15+ scattered state variables with centralized provider.
class ChatScreenStateProvider with ChangeNotifier {
  // Services
  final ChatTimerManager timerManager;
  final FileProcessingManager fileProcessingManager;
  final ChatEventService chatService;
  final ScrollController scrollController;

  // Loading state
  bool _isLoading = false;

  // Confirmation flow state
  bool _showingConfirmation = false;
  int _confirmationSeconds = 30;

  // Input visibility state
  bool _isInputVisible = true;

  // Constructor
  ChatScreenStateProvider({
    ChatTimerConfig? timerConfig,
    ExtractionService? extractionService,
    ChatEventService? chatService,
    ScrollController? scrollController,
  })  : timerManager = ChatTimerManager(
            config: timerConfig ?? ChatTimerConfig.defaultConfig),
        fileProcessingManager = FileProcessingManager(
            extractionService: extractionService),
        chatService = chatService ?? ChatEventService(),
        scrollController = scrollController ?? ScrollController() {
    // Set up file processing event listener
    fileProcessingManager.setEventCallback(_handleFileProcessingEvent);
  }

  // Getters
  bool get isLoading => _isLoading;
  bool get showingConfirmation => _showingConfirmation;
  int get confirmationSeconds => _confirmationSeconds;
  bool get isInputVisible => _isInputVisible;
  bool get hasEventData => chatService.currentEventData.isNotEmpty;

  // File processing getters (delegate to manager)
  List<File> get selectedImages => fileProcessingManager.selectedImages;
  List<File> get selectedDocuments => fileProcessingManager.selectedDocuments;
  bool get isProcessingFiles => fileProcessingManager.isProcessing;
  int get totalFiles => fileProcessingManager.totalFiles;

  /// Set loading state
  void setLoading(bool value) {
    if (_isLoading != value) {
      _isLoading = value;
      notifyListeners();
    }
  }

  /// Show confirmation card with countdown timer
  void showConfirmation({
    required VoidCallback onAutoSave,
  }) {
    if (_showingConfirmation) return;

    _showingConfirmation = true;
    notifyListeners();

    // Start confirmation countdown timer
    timerManager.startConfirmationTimer(
      onTick: (secondsRemaining) {
        _confirmationSeconds = secondsRemaining;
        notifyListeners();
      },
      onComplete: () {
        _showingConfirmation = false;
        notifyListeners();
        onAutoSave();
      },
    );

    // Start inactivity timer (hides confirmation if no activity)
    timerManager.startInactivityTimer(
      onTimeout: () {
        if (_showingConfirmation) {
          hideConfirmation();
        }
      },
    );
  }

  /// Hide confirmation card
  void hideConfirmation() {
    if (!_showingConfirmation) return;

    _showingConfirmation = false;
    timerManager.cancel(ChatTimerType.confirmation);
    timerManager.cancel(ChatTimerType.inactivity);
    notifyListeners();
  }

  /// Reset confirmation state after save/discard
  void resetConfirmationState({required VoidCallback onComplete}) {
    hideConfirmation();

    timerManager.startResetTimer(
      onComplete: () {
        chatService.clearCurrentEventData();
        notifyListeners();
        onComplete();
      },
    );
  }

  /// Show input field
  void showInput() {
    if (_isInputVisible) return;
    _isInputVisible = true;
    notifyListeners();
  }

  /// Hide input field
  void hideInput() {
    if (!_isInputVisible) return;
    _isInputVisible = false;
    notifyListeners();
  }

  /// Toggle input visibility
  void toggleInput() {
    _isInputVisible = !_isInputVisible;
    notifyListeners();
  }

  /// Process an image file
  Future<Map<String, dynamic>?> processImage(File file) async {
    try {
      final result = await fileProcessingManager.processImage(file);
      return result;
    } catch (e) {
      rethrow;
    }
  }

  /// Process a document file
  Future<Map<String, dynamic>?> processDocument(File file) async {
    try {
      final result = await fileProcessingManager.processDocument(file);
      return result;
    } catch (e) {
      rethrow;
    }
  }

  /// Remove an image
  void removeImage(File file) {
    fileProcessingManager.removeImage(file);
  }

  /// Remove a document
  void removeDocument(File file) {
    fileProcessingManager.removeDocument(file);
  }

  /// Clear all files
  void clearAllFiles() {
    fileProcessingManager.clearAll();
  }

  /// Send a message through chat service
  Future<void> sendMessage(String message) async {
    setLoading(true);
    try {
      await chatService.sendMessage(message);
    } finally {
      setLoading(false);
    }
  }

  /// Update event data in chat service
  void updateEventData(Map<String, dynamic> data) {
    chatService.updateEventData(data);
    notifyListeners();
  }

  /// Clear event data
  void clearEventData() {
    chatService.clearCurrentEventData();
    notifyListeners();
  }

  /// Get conversation history
  List<Map<String, dynamic>> get conversationHistory {
    final history = chatService.conversationHistory;
    // Convert to List<Map<String, dynamic>>
    return history.map((msg) {
      if (msg is Map<String, dynamic>) {
        return msg;
      }
      // Convert ChatMessage to Map
      final chatMsg = msg as ChatMessage;
      return {
        'role': chatMsg.role ?? 'user',
        'content': chatMsg.content ?? '',
        if (chatMsg.reasoning != null) 'reasoning': chatMsg.reasoning,
      };
    }).toList().cast<Map<String, dynamic>>();
  }

  /// Get current event data
  Map<String, dynamic> get currentEventData => chatService.currentEventData;

  /// Add a message to chat and notify listeners (ensures UI rebuild)
  /// Use this instead of chatService.addMessage() when you need immediate UI update
  void addMessageAndNotify(ChatMessage message) {
    chatService.addMessage(message);
    notifyListeners();
  }

  /// Start a new conversation
  void startNewConversation() {
    chatService.startNewConversation();
    hideConfirmation();
    clearAllFiles();
    notifyListeners();
  }

  /// Load greeting message
  Future<void> loadGreeting() async {
    await chatService.getGreeting();
    notifyListeners();
  }

  /// Reset inactivity timer (call on user interaction)
  void resetInactivityTimer() {
    if (_showingConfirmation) {
      // Restart inactivity timer
      timerManager.cancel(ChatTimerType.inactivity);
      timerManager.startInactivityTimer(
        onTimeout: () {
          if (_showingConfirmation) {
            hideConfirmation();
          }
        },
      );
    }
  }

  /// Handle file processing events
  void _handleFileProcessingEvent(
    FileProcessingEvent event,
    File file,
    Map<String, dynamic>? extractedData,
  ) {
    // Notify listeners when file processing events occur
    notifyListeners();

    // If extraction completed, update event data
    if (event == FileProcessingEvent.extractionCompleted && extractedData != null) {
      updateEventData(extractedData);
    }
  }

  @override
  void dispose() {
    timerManager.dispose();
    fileProcessingManager.dispose();
    scrollController.dispose();
    super.dispose();
  }
}

// Extension for easier access in widgets
extension ChatScreenStateContext on BuildContext {
  ChatScreenStateProvider get chatScreenState => Provider.of<ChatScreenStateProvider>(this, listen: false);
  ChatScreenStateProvider get watchChatScreenState => Provider.of<ChatScreenStateProvider>(this, listen: true);
}
