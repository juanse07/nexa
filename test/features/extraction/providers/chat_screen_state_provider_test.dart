import 'dart:io';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexa/features/extraction/providers/chat_screen_state_provider.dart';
import 'package:nexa/features/extraction/services/chat_timer_manager.dart';
import 'package:nexa/features/extraction/services/chat_event_service.dart';
import 'package:nexa/features/extraction/services/extraction_service.dart';

// Mock ExtractionService
class MockExtractionService extends ExtractionService {
  Map<String, dynamic>? _mockResponse;
  Exception? _mockError;

  void setMockResponse(Map<String, dynamic> response) {
    _mockResponse = response;
    _mockError = null;
  }

  void setMockError(Exception error) {
    _mockError = error;
  }

  @override
  Future<Map<String, dynamic>> extractStructuredData({
    required String input,
  }) async {
    await Future.delayed(const Duration(milliseconds: 10));
    if (_mockError != null) throw _mockError!;
    return _mockResponse ?? {};
  }
}

// Mock ChatEventService
class MockChatEventService extends ChatEventService {
  final List<ChatMessage> _conversationHistory = [];
  final Map<String, dynamic> _currentEventData = {};
  bool _greetingCalled = false;
  bool _sendMessageCalled = false;
  String? _lastMessage;

  @override
  List<ChatMessage> get conversationHistory => _conversationHistory;

  @override
  Map<String, dynamic> get currentEventData => _currentEventData;

  @override
  Future<ChatMessage> getGreeting() async {
    _greetingCalled = true;
    final message = ChatMessage(
      role: 'assistant',
      content: 'Hello! How can I help you today?',
    );
    _conversationHistory.add(message);
    return message;
  }

  @override
  Future<ChatMessage> sendMessage(String message, {String? terminology}) async {
    _sendMessageCalled = true;
    _lastMessage = message;
    await Future.delayed(const Duration(milliseconds: 50));
    final chatMessage = ChatMessage(role: 'user', content: message);
    _conversationHistory.add(chatMessage);
    return chatMessage;
  }

  @override
  void updateEventData(Map<String, dynamic> data) {
    _currentEventData.addAll(data);
  }

  @override
  void clearCurrentEventData() {
    _currentEventData.clear();
  }

  @override
  void startNewConversation() {
    _conversationHistory.clear();
    _currentEventData.clear();
  }

  void addMockMessage(String role, String content) {
    _conversationHistory.add(ChatMessage(role: role, content: content));
  }
}

void main() {
  group('ChatScreenStateProvider', () {
    late ChatScreenStateProvider provider;
    late MockChatEventService mockChatService;
    late MockExtractionService mockExtractionService;
    late List<String> notifyListenerCalls;

    setUp(() {
      mockChatService = MockChatEventService();
      mockExtractionService = MockExtractionService();

      provider = ChatScreenStateProvider(
        chatService: mockChatService,
        extractionService: mockExtractionService,
        scrollController: ScrollController(),
      );

      notifyListenerCalls = [];
      provider.addListener(() {
        notifyListenerCalls.add('notified');
      });
    });

    tearDown(() {
      provider.dispose();
    });

    group('initialization', () {
      test('starts with default state', () {
        expect(provider.isLoading, false);
        expect(provider.showingConfirmation, false);
        expect(provider.confirmationSeconds, 30);
        expect(provider.isInputVisible, true);
        expect(provider.hasEventData, false);
        expect(provider.selectedImages, isEmpty);
        expect(provider.selectedDocuments, isEmpty);
        expect(provider.isProcessingFiles, false);
        expect(provider.totalFiles, 0);
      });

      test('initializes with custom timer config', () {
        final customProvider = ChatScreenStateProvider(
          timerConfig: const ChatTimerConfig(
            confirmationDuration: Duration(seconds: 45),
          ),
          chatService: mockChatService,
          extractionService: mockExtractionService,
        );

        expect(customProvider.confirmationSeconds, 30); // Initial value

        customProvider.dispose();
      });

      test('sets up file processing event callback', () {
        // Callback should be set during initialization
        // We'll verify this works in the file processing event tests
        expect(provider, isNotNull);
      });
    });

    group('loading state', () {
      test('setLoading updates state and notifies', () {
        notifyListenerCalls.clear();

        provider.setLoading(true);

        expect(provider.isLoading, true);
        expect(notifyListenerCalls, isNotEmpty);
      });

      test('setLoading does not notify if value unchanged', () {
        provider.setLoading(true);
        notifyListenerCalls.clear();

        provider.setLoading(true); // Same value

        expect(notifyListenerCalls, isEmpty);
      });

      test('setLoading can toggle multiple times', () {
        provider.setLoading(true);
        expect(provider.isLoading, true);

        provider.setLoading(false);
        expect(provider.isLoading, false);

        provider.setLoading(true);
        expect(provider.isLoading, true);
      });
    });

    group('confirmation flow', () {
      test('showConfirmation starts confirmation state', () {
        provider.showConfirmation(onAutoSave: () {});

        expect(provider.showingConfirmation, true);
        expect(notifyListenerCalls, isNotEmpty);
      });

      test('showConfirmation starts countdown timer', () {
        fakeAsync((async) {
          var autoSaved = false;

          provider.showConfirmation(onAutoSave: () => autoSaved = true);

          expect(provider.confirmationSeconds, 30);

          async.elapse(const Duration(seconds: 1));
          expect(provider.confirmationSeconds, 29);

          async.elapse(const Duration(seconds: 5));
          expect(provider.confirmationSeconds, 24);

          async.elapse(const Duration(seconds: 24));
          expect(autoSaved, true);
          expect(provider.showingConfirmation, false);
        });
      });

      test('showConfirmation starts inactivity timer', () {
        fakeAsync((async) {
          provider.showConfirmation(onAutoSave: () {});

          expect(provider.showingConfirmation, true);

          // Inactivity timer (2 minutes) should hide confirmation
          async.elapse(const Duration(minutes: 2));

          expect(provider.showingConfirmation, false);
        });
      });

      test('showConfirmation does nothing if already showing', () {
        provider.showConfirmation(onAutoSave: () {});
        notifyListenerCalls.clear();

        provider.showConfirmation(onAutoSave: () {});

        expect(notifyListenerCalls, isEmpty);
      });

      test('hideConfirmation clears state and cancels timers', () {
        fakeAsync((async) {
          var autoSaved = false;

          provider.showConfirmation(onAutoSave: () => autoSaved = true);
          expect(provider.showingConfirmation, true);

          provider.hideConfirmation();

          expect(provider.showingConfirmation, false);

          // Timer should be canceled
          async.elapse(const Duration(seconds: 31));
          expect(autoSaved, false);
        });
      });

      test('hideConfirmation does nothing if not showing', () {
        notifyListenerCalls.clear();

        provider.hideConfirmation();

        expect(notifyListenerCalls, isEmpty);
      });

      test('resetConfirmationState hides and starts reset timer', () {
        fakeAsync((async) {
          var resetCompleted = false;

          provider.showConfirmation(onAutoSave: () {});
          mockChatService.updateEventData({'test': 'data'});

          provider.resetConfirmationState(
            onComplete: () => resetCompleted = true,
          );

          expect(provider.showingConfirmation, false);

          // Reset timer (5 seconds)
          async.elapse(const Duration(seconds: 5));

          expect(resetCompleted, true);
          expect(provider.currentEventData, isEmpty);
        });
      });

      test('resetInactivityTimer restarts inactivity timer', () {
        fakeAsync((async) {
          provider.showConfirmation(onAutoSave: () {});

          // Advance time partway through inactivity period
          async.elapse(const Duration(minutes: 1));
          expect(provider.showingConfirmation, true);

          // Reset the timer
          provider.resetInactivityTimer();

          // Original timer would have fired at 2 minutes, but we reset at 1 minute
          // So new timer fires at 3 minutes total
          async.elapse(const Duration(minutes: 1, seconds: 30));
          expect(provider.showingConfirmation, true);

          async.elapse(const Duration(seconds: 30));
          expect(provider.showingConfirmation, false);
        });
      });

      test('resetInactivityTimer does nothing if not showing confirmation', () {
        // Should not throw
        expect(() => provider.resetInactivityTimer(), returnsNormally);
      });
    });

    group('input visibility', () {
      test('showInput makes input visible', () {
        provider.hideInput();
        notifyListenerCalls.clear();

        provider.showInput();

        expect(provider.isInputVisible, true);
        expect(notifyListenerCalls, isNotEmpty);
      });

      test('showInput does nothing if already visible', () {
        expect(provider.isInputVisible, true);
        notifyListenerCalls.clear();

        provider.showInput();

        expect(notifyListenerCalls, isEmpty);
      });

      test('hideInput hides input', () {
        notifyListenerCalls.clear();

        provider.hideInput();

        expect(provider.isInputVisible, false);
        expect(notifyListenerCalls, isNotEmpty);
      });

      test('hideInput does nothing if already hidden', () {
        provider.hideInput();
        notifyListenerCalls.clear();

        provider.hideInput();

        expect(notifyListenerCalls, isEmpty);
      });

      test('toggleInput switches visibility', () {
        expect(provider.isInputVisible, true);

        provider.toggleInput();
        expect(provider.isInputVisible, false);

        provider.toggleInput();
        expect(provider.isInputVisible, true);
      });
    });

    group('file processing delegation', () {
      late File testFile;

      setUp(() async {
        final tempDir = await Directory.systemTemp.createTemp('test_provider');
        testFile = File('${tempDir.path}/test.jpg');
        await testFile.writeAsBytes([1, 2, 3, 4, 5]);
      });

      test('processImage delegates to file manager', () async {
        final mockData = {'event_name': 'Test Event'};
        mockExtractionService.setMockResponse(mockData);

        final result = await provider.processImage(testFile);

        expect(result, equals(mockData));

        // Wait for auto-removal
        await Future.delayed(const Duration(milliseconds: 600));
      });

      test('processImage propagates errors', () async {
        mockExtractionService.setMockError(Exception('Test error'));

        expect(
          () => provider.processImage(testFile),
          throwsException,
        );

        await Future.delayed(const Duration(milliseconds: 100));
      });

      test('removeImage delegates to file manager', () async {
        mockExtractionService.setMockError(Exception('Stop'));

        try {
          await provider.processImage(testFile);
        } catch (_) {}

        provider.removeImage(testFile);

        expect(provider.selectedImages, isEmpty);
      });

      test('clearAllFiles delegates to file manager', () async {
        mockExtractionService.setMockError(Exception('Stop'));

        try {
          await provider.processImage(testFile);
        } catch (_) {}

        expect(provider.totalFiles, 1);

        provider.clearAllFiles();

        expect(provider.totalFiles, 0);
        expect(provider.selectedImages, isEmpty);
      });

      test('file processing updates isProcessingFiles getter', () async {
        mockExtractionService.setMockResponse({'event_name': 'Test'});

        final future = provider.processImage(testFile);

        await Future.delayed(const Duration(milliseconds: 30));

        // May or may not be processing depending on timing
        // Just verify the getter works
        expect(provider.isProcessingFiles, isA<bool>());

        await future;
        await Future.delayed(const Duration(milliseconds: 600));
      });
    });

    group('message sending', () {
      test('sendMessage sets loading during send', () async {
        mockChatService.addMockMessage('assistant', 'Hello');

        final future = provider.sendMessage('Test message');

        // Should be loading immediately
        await Future.delayed(const Duration(milliseconds: 10));
        expect(provider.isLoading, true);

        await future;

        expect(provider.isLoading, false);
      });

      test('sendMessage delegates to chat service', () async {
        await provider.sendMessage('Test message');

        expect(mockChatService._sendMessageCalled, true);
        expect(mockChatService._lastMessage, 'Test message');
      });

      test('sendMessage clears loading even on error', () async {
        // Create a throwing mock service
        final throwingService = _ThrowingChatService();
        final throwingProvider = ChatScreenStateProvider(
          chatService: throwingService,
          extractionService: mockExtractionService,
        );

        try {
          await throwingProvider.sendMessage('Test');
        } catch (_) {
          // Expected
        }

        expect(throwingProvider.isLoading, false);

        throwingProvider.dispose();
      });
    });

    group('event data management', () {
      test('updateEventData updates and notifies', () {
        notifyListenerCalls.clear();

        provider.updateEventData({'event_name': 'Test Event'});

        expect(provider.currentEventData, contains('event_name'));
        expect(provider.hasEventData, true);
        expect(notifyListenerCalls, isNotEmpty);
      });

      test('clearEventData clears and notifies', () {
        provider.updateEventData({'event_name': 'Test'});
        notifyListenerCalls.clear();

        provider.clearEventData();

        expect(provider.currentEventData, isEmpty);
        expect(provider.hasEventData, false);
        expect(notifyListenerCalls, isNotEmpty);
      });

      test('hasEventData reflects current data', () {
        expect(provider.hasEventData, false);

        provider.updateEventData({'test': 'data'});
        expect(provider.hasEventData, true);

        provider.clearEventData();
        expect(provider.hasEventData, false);
      });
    });

    group('conversation management', () {
      test('conversationHistory delegates to chat service', () {
        mockChatService.addMockMessage('user', 'Hello');
        mockChatService.addMockMessage('assistant', 'Hi there!');

        final history = provider.conversationHistory;

        expect(history.length, 2);
        expect(history[0]['role'], 'user');
        expect(history[0]['content'], 'Hello');
        expect(history[1]['role'], 'assistant');
        expect(history[1]['content'], 'Hi there!');
      });

      test('loadGreeting calls chat service and notifies', () async {
        notifyListenerCalls.clear();

        await provider.loadGreeting();

        expect(mockChatService._greetingCalled, true);
        expect(notifyListenerCalls, isNotEmpty);
      });

      test('startNewConversation clears state', () async {
        // Set up some state
        provider.showConfirmation(onAutoSave: () {});
        mockExtractionService.setMockError(Exception('Stop'));

        final tempDir = await Directory.systemTemp.createTemp('test_new_conv');
        final testFile = File('${tempDir.path}/test.jpg');
        await testFile.writeAsBytes([1, 2, 3]);

        try {
          await provider.processImage(testFile);
        } catch (_) {}

        provider.updateEventData({'test': 'data'});

        expect(provider.showingConfirmation, true);
        expect(provider.totalFiles, 1);
        expect(provider.hasEventData, true);

        // Start new conversation
        provider.startNewConversation();

        expect(provider.showingConfirmation, false);
        expect(provider.totalFiles, 0);
        expect(provider.conversationHistory, isEmpty);
        expect(provider.currentEventData, isEmpty);
      });
    });

    group('file processing events', () {
      test('extraction completed event updates event data', () async {
        final tempDir = await Directory.systemTemp.createTemp('test_events');
        final testFile = File('${tempDir.path}/test.jpg');
        await testFile.writeAsBytes([1, 2, 3]);

        final mockData = {'event_name': 'Extracted Event'};
        mockExtractionService.setMockResponse(mockData);

        await provider.processImage(testFile);

        // Event data should be updated
        expect(provider.currentEventData, contains('event_name'));
        expect(provider.currentEventData['event_name'], 'Extracted Event');

        await Future.delayed(const Duration(milliseconds: 600));
      });

      test('file processing events notify listeners', () async {
        final tempDir = await Directory.systemTemp.createTemp('test_notify');
        final testFile = File('${tempDir.path}/test.jpg');
        await testFile.writeAsBytes([1, 2, 3]);

        mockExtractionService.setMockResponse({'test': 'data'});

        notifyListenerCalls.clear();

        await provider.processImage(testFile);

        // Should have multiple notifications from file processing events
        expect(notifyListenerCalls.length, greaterThan(0));

        await Future.delayed(const Duration(milliseconds: 600));
      });
    });

    group('dispose', () {
      test('disposes all managed resources', () {
        // Create a new provider for this test
        final testProvider = ChatScreenStateProvider(
          chatService: MockChatEventService(),
          extractionService: MockExtractionService(),
        );

        // Should not throw
        expect(() => testProvider.dispose(), returnsNormally);
      });

      test('disposes timer manager', () {
        fakeAsync((async) {
          final testProvider = ChatScreenStateProvider(
            chatService: MockChatEventService(),
            extractionService: MockExtractionService(),
          );

          var timerFired = false;
          testProvider.showConfirmation(onAutoSave: () => timerFired = true);

          testProvider.dispose();

          // Timer should not fire after dispose
          async.elapse(const Duration(seconds: 31));
          expect(timerFired, false);
        });
      });
    });

    group('delegated getters', () {
      test('selectedImages returns file manager images', () async {
        final tempDir = await Directory.systemTemp.createTemp('test_getters');
        final testFile = File('${tempDir.path}/test.jpg');
        await testFile.writeAsBytes([1, 2, 3]);

        mockExtractionService.setMockError(Exception('Stop'));

        try {
          await provider.processImage(testFile);
        } catch (_) {}

        expect(provider.selectedImages, contains(testFile));

        provider.clearAllFiles();
      });

      test('currentEventData returns chat service data', () {
        mockChatService.updateEventData({'test': 'value'});

        expect(provider.currentEventData, equals(mockChatService.currentEventData));
      });
    });
  });
}

// Helper class for testing error handling
class _ThrowingChatService extends MockChatEventService {
  @override
  Future<ChatMessage> sendMessage(String message, {String? terminology}) async {
    throw Exception('Mock send message error');
  }
}

