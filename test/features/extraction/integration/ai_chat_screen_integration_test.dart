import 'dart:io';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexa/features/extraction/providers/chat_screen_state_provider.dart';
import 'package:nexa/features/extraction/services/chat_timer_manager.dart';
import 'package:nexa/features/extraction/services/extraction_service.dart';
import 'package:nexa/features/extraction/services/chat_event_service.dart';
import 'package:provider/provider.dart';

// Mock ExtractionService for integration tests
class MockExtractionService extends ExtractionService {
  final Map<String, Map<String, dynamic>> _mockResponses = {};
  Exception? _mockError;
  int callCount = 0;

  void setResponseForInput(String inputPrefix, Map<String, dynamic> response) {
    _mockResponses[inputPrefix] = response;
  }

  void setError(Exception error) {
    _mockError = error;
  }

  void reset() {
    _mockResponses.clear();
    _mockError = null;
    callCount = 0;
  }

  @override
  Future<Map<String, dynamic>> extractStructuredData({
    required String input,
  }) async {
    callCount++;
    await Future.delayed(const Duration(milliseconds: 50));

    if (_mockError != null) throw _mockError!;

    // Find matching mock response
    for (var entry in _mockResponses.entries) {
      if (input.startsWith(entry.key)) {
        return entry.value;
      }
    }

    return {'event_name': 'Default Test Event'};
  }
}

// Mock ChatEventService for integration tests
class MockChatEventService extends ChatEventService {
  final List<ChatMessage> _messages = [];
  final Map<String, dynamic> _eventData = {};
  bool greetingLoaded = false;

  @override
  List<ChatMessage> get conversationHistory => _messages;

  @override
  Map<String, dynamic> get currentEventData => _eventData;

  @override
  Future<ChatMessage> getGreeting() async {
    greetingLoaded = true;
    final msg = ChatMessage(
      role: 'assistant',
      content: 'Hello! I can help you create events. Upload an image or describe the event.',
    );
    _messages.add(msg);
    return msg;
  }

  @override
  Future<ChatMessage> sendMessage(String message, {String? terminology}) async {
    await Future.delayed(const Duration(milliseconds: 30));

    final userMsg = ChatMessage(role: 'user', content: message);
    _messages.add(userMsg);

    final response = ChatMessage(
      role: 'assistant',
      content: 'I received: $message',
    );
    _messages.add(response);

    return response;
  }

  @override
  void updateEventData(Map<String, dynamic> data) {
    _eventData.addAll(data);
  }

  @override
  void clearCurrentEventData() {
    _eventData.clear();
  }

  @override
  void startNewConversation() {
    _messages.clear();
    _eventData.clear();
  }
}

void main() {
  group('AI Chat Screen Integration Tests', () {
    late MockExtractionService mockExtractionService;
    late MockChatEventService mockChatService;

    setUp(() {
      mockExtractionService = MockExtractionService();
      mockChatService = MockChatEventService();
    });

    group('Complete Extraction Flow', () {
      testWidgets('file upload → extraction → confirmation → save flow',
          (tester) async {
        final provider = ChatScreenStateProvider(
          extractionService: mockExtractionService,
          chatService: mockChatService,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: ChangeNotifierProvider.value(
              value: provider,
              child: Scaffold(
                body: Builder(
                  builder: (context) {
                    return Column(
                      children: [
                        // Simulate file upload button
                        ElevatedButton(
                          onPressed: () async {
                            final tempDir = await Directory.systemTemp
                                .createTemp('integration_test');
                            final testFile =
                                File('${tempDir.path}/test.jpg');
                            await testFile.writeAsBytes([1, 2, 3, 4, 5]);

                            mockExtractionService.setResponseForInput(
                              '[[IMAGE_BASE64]]',
                              {
                                'event_name': 'Tech Conference 2025',
                                'client_name': 'Acme Corp',
                                'date': '2025-03-15',
                              },
                            );

                            await provider.processImage(testFile);
                          },
                          child: const Text('Upload Image'),
                        ),
                        // Display confirmation state
                        if (context
                            .watch<ChatScreenStateProvider>()
                            .showingConfirmation)
                          Text('Confirmation showing'),
                        // Display event data
                        if (context
                            .watch<ChatScreenStateProvider>()
                            .hasEventData)
                          Text('Has event data'),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        );

        // Step 1: Upload image
        await tester.tap(find.text('Upload Image'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Step 2: Verify extraction completed and event data exists
        expect(find.text('Has event data'), findsOneWidget);
        expect(provider.currentEventData['event_name'], 'Tech Conference 2025');

        // Wait for auto-removal
        await tester.pump(const Duration(milliseconds: 600));

        provider.dispose();
      });

      testWidgets('confirmation timer auto-saves after 30 seconds',
          (tester) async {
        await tester.runAsync(() async {
          return fakeAsync((async) {
            final provider = ChatScreenStateProvider(
              extractionService: mockExtractionService,
              chatService: mockChatService,
            );

            var autoSaveCalled = false;

            provider.updateEventData({'test': 'data'});
            provider.showConfirmation(onAutoSave: () {
              autoSaveCalled = true;
            });

            expect(provider.showingConfirmation, true);
            expect(provider.confirmationSeconds, 30);

            // Advance time
            async.elapse(const Duration(seconds: 15));
            expect(provider.confirmationSeconds, 15);
            expect(autoSaveCalled, false);

            async.elapse(const Duration(seconds: 15));
            expect(autoSaveCalled, true);
            expect(provider.showingConfirmation, false);

            provider.dispose();
          });
        });
      });

      testWidgets('inactivity hides confirmation after 2 minutes',
          (tester) async {
        await tester.runAsync(() async {
          return fakeAsync((async) {
            final provider = ChatScreenStateProvider(
              extractionService: mockExtractionService,
              chatService: mockChatService,
            );

            provider.showConfirmation(onAutoSave: () {});

            expect(provider.showingConfirmation, true);

            // Simulate inactivity
            async.elapse(const Duration(minutes: 2));

            expect(provider.showingConfirmation, false);

            provider.dispose();
          });
        });
      });

      testWidgets('reset timer clears event data after save', (tester) async {
        await tester.runAsync(() async {
          return fakeAsync((async) {
            final provider = ChatScreenStateProvider(
              extractionService: mockExtractionService,
              chatService: mockChatService,
            );

            var resetCompleted = false;

            provider.updateEventData({'event_name': 'Test Event'});
            provider.showConfirmation(onAutoSave: () {});

            expect(provider.hasEventData, true);

            // User clicks save
            provider.resetConfirmationState(onComplete: () {
              resetCompleted = true;
            });

            expect(provider.showingConfirmation, false);

            // Wait for reset timer (5 seconds)
            async.elapse(const Duration(seconds: 5));

            expect(resetCompleted, true);
            expect(provider.hasEventData, false);

            provider.dispose();
          });
        });
      });
    });

    group('Multiple File Processing', () {
      testWidgets('processes multiple files sequentially', (tester) async {
        final provider = ChatScreenStateProvider(
          extractionService: mockExtractionService,
          chatService: mockChatService,
        );

        final tempDir = await Directory.systemTemp.createTemp('multi_test');
        final file1 = File('${tempDir.path}/test1.jpg');
        final file2 = File('${tempDir.path}/test2.jpg');
        await file1.writeAsBytes([1, 2, 3]);
        await file2.writeAsBytes([4, 5, 6]);

        mockExtractionService.setResponseForInput(
          '[[IMAGE_BASE64]]',
          {'event_name': 'Event 1'},
        );

        // Process first file
        final result1 = await provider.processImage(file1);
        expect(result1?['event_name'], 'Event 1');

        // Wait for auto-removal
        await tester.pump(const Duration(milliseconds: 600));

        // Process second file
        mockExtractionService.setResponseForInput(
          '[[IMAGE_BASE64]]',
          {'event_name': 'Event 2'},
        );

        final result2 = await provider.processImage(file2);
        expect(result2?['event_name'], 'Event 2');

        await tester.pump(const Duration(milliseconds: 600));

        expect(mockExtractionService.callCount, 2);

        provider.dispose();
      });

      testWidgets('tracks processing state correctly', (tester) async {
        final provider = ChatScreenStateProvider(
          extractionService: mockExtractionService,
          chatService: mockChatService,
        );

        final tempDir = await Directory.systemTemp.createTemp('tracking_test');
        final testFile = File('${tempDir.path}/test.jpg');
        await testFile.writeAsBytes([1, 2, 3]);

        mockExtractionService.setResponseForInput(
          '[[IMAGE_BASE64]]',
          {'event_name': 'Test'},
        );

        expect(provider.isProcessingFiles, false);
        expect(provider.totalFiles, 0);

        final future = provider.processImage(testFile);

        await tester.pump(const Duration(milliseconds: 30));

        // Should be processing
        final wasProcessing = provider.isProcessingFiles ||
            provider.totalFiles > 0; // Might complete quickly
        expect(wasProcessing, true);

        await future;
        await tester.pump(const Duration(milliseconds: 600));

        provider.dispose();
      });
    });

    group('Error Recovery', () {
      testWidgets('handles extraction errors gracefully', (tester) async {
        final provider = ChatScreenStateProvider(
          extractionService: mockExtractionService,
          chatService: mockChatService,
        );

        final tempDir = await Directory.systemTemp.createTemp('error_test');
        final testFile = File('${tempDir.path}/test.jpg');
        await testFile.writeAsBytes([1, 2, 3]);

        mockExtractionService.setError(Exception('Network error'));

        expect(
          () => provider.processImage(testFile),
          throwsException,
        );

        await tester.pump(const Duration(milliseconds: 100));

        // File should still be tracked with error state
        expect(provider.totalFiles, 1);

        // Clean up
        provider.clearAllFiles();
        provider.dispose();
      });

      testWidgets('message sending handles errors', (tester) async {
        final throwingService = _ThrowingChatService();
        final provider = ChatScreenStateProvider(
          extractionService: mockExtractionService,
          chatService: throwingService,
        );

        try {
          await provider.sendMessage('Test message');
        } catch (_) {
          // Expected
        }

        // Loading should be cleared even on error
        expect(provider.isLoading, false);

        provider.dispose();
      });

      testWidgets('can recover from error and process another file',
          (tester) async {
        final provider = ChatScreenStateProvider(
          extractionService: mockExtractionService,
          chatService: mockChatService,
        );

        final tempDir = await Directory.systemTemp.createTemp('recovery_test');
        final errorFile = File('${tempDir.path}/error.jpg');
        final successFile = File('${tempDir.path}/success.jpg');
        await errorFile.writeAsBytes([1, 2, 3]);
        await successFile.writeAsBytes([4, 5, 6]);

        // First file fails
        mockExtractionService.setError(Exception('Error'));

        try {
          await provider.processImage(errorFile);
        } catch (_) {}

        await tester.pump(const Duration(milliseconds: 100));

        // Clear error and try again
        mockExtractionService.reset();
        mockExtractionService.setResponseForInput(
          '[[IMAGE_BASE64]]',
          {'event_name': 'Success Event'},
        );

        final result = await provider.processImage(successFile);

        expect(result?['event_name'], 'Success Event');

        await tester.pump(const Duration(milliseconds: 600));

        provider.dispose();
      });
    });

    group('Conversation Flow', () {
      testWidgets('loads greeting on startup', (tester) async {
        final provider = ChatScreenStateProvider(
          extractionService: mockExtractionService,
          chatService: mockChatService,
        );

        expect(mockChatService.greetingLoaded, false);

        await provider.loadGreeting();

        expect(mockChatService.greetingLoaded, true);
        expect(provider.conversationHistory.length, 1);
        expect(provider.conversationHistory[0]['role'], 'assistant');

        provider.dispose();
      });

      testWidgets('sends messages and updates history', (tester) async {
        final provider = ChatScreenStateProvider(
          extractionService: mockExtractionService,
          chatService: mockChatService,
        );

        expect(provider.conversationHistory, isEmpty);

        await provider.sendMessage('Hello AI');

        expect(provider.conversationHistory.length, 2); // User + Assistant
        expect(provider.conversationHistory[0]['content'], 'Hello AI');

        provider.dispose();
      });

      testWidgets('starts new conversation clears everything', (tester) async {
        final provider = ChatScreenStateProvider(
          extractionService: mockExtractionService,
          chatService: mockChatService,
        );

        final tempDir = await Directory.systemTemp.createTemp('new_conv_test');
        final testFile = File('${tempDir.path}/test.jpg');
        await testFile.writeAsBytes([1, 2, 3]);

        // Set up state
        await provider.loadGreeting();
        await provider.sendMessage('Test');
        provider.updateEventData({'test': 'data'});
        provider.showConfirmation(onAutoSave: () {});

        mockExtractionService.setError(Exception('Stop'));
        try {
          await provider.processImage(testFile);
        } catch (_) {}

        await tester.pump(const Duration(milliseconds: 100));

        expect(provider.conversationHistory.isNotEmpty, true);
        expect(provider.hasEventData, true);
        expect(provider.showingConfirmation, true);
        expect(provider.totalFiles, 1);

        // Start new conversation
        provider.startNewConversation();

        expect(provider.conversationHistory, isEmpty);
        expect(provider.hasEventData, false);
        expect(provider.showingConfirmation, false);
        expect(provider.totalFiles, 0);

        provider.dispose();
      });
    });

    group('State Synchronization', () {
      testWidgets('event data updates trigger UI updates', (tester) async {
        final provider = ChatScreenStateProvider(
          extractionService: mockExtractionService,
          chatService: mockChatService,
        );

        var listenerCalled = false;
        provider.addListener(() {
          listenerCalled = true;
        });

        provider.updateEventData({'event_name': 'New Event'});

        expect(listenerCalled, true);
        expect(provider.currentEventData['event_name'], 'New Event');

        provider.dispose();
      });

      testWidgets('file processing events update UI', (tester) async {
        final provider = ChatScreenStateProvider(
          extractionService: mockExtractionService,
          chatService: mockChatService,
        );

        var notifyCount = 0;
        provider.addListener(() {
          notifyCount++;
        });

        final tempDir = await Directory.systemTemp.createTemp('sync_test');
        final testFile = File('${tempDir.path}/test.jpg');
        await testFile.writeAsBytes([1, 2, 3]);

        mockExtractionService.setResponseForInput(
          '[[IMAGE_BASE64]]',
          {'event_name': 'Test Event'},
        );

        await provider.processImage(testFile);

        // Should have multiple notifications during processing
        expect(notifyCount, greaterThan(0));
        expect(provider.currentEventData['event_name'], 'Test Event');

        await tester.pump(const Duration(milliseconds: 600));

        provider.dispose();
      });

      testWidgets('loading state toggles during operations', (tester) async {
        final provider = ChatScreenStateProvider(
          extractionService: mockExtractionService,
          chatService: mockChatService,
        );

        expect(provider.isLoading, false);

        final future = provider.sendMessage('Test');

        await tester.pump(const Duration(milliseconds: 10));

        // Should be loading
        expect(provider.isLoading, true);

        await future;

        expect(provider.isLoading, false);

        provider.dispose();
      });
    });

    group('Input Visibility Management', () {
      testWidgets('input visibility can be toggled', (tester) async {
        final provider = ChatScreenStateProvider(
          extractionService: mockExtractionService,
          chatService: mockChatService,
        );

        expect(provider.isInputVisible, true);

        provider.hideInput();
        expect(provider.isInputVisible, false);

        provider.showInput();
        expect(provider.isInputVisible, true);

        provider.toggleInput();
        expect(provider.isInputVisible, false);

        provider.dispose();
      });
    });

    group('Timer Coordination', () {
      testWidgets('resetting inactivity timer extends timeout',
          (tester) async {
        await tester.runAsync(() async {
          return fakeAsync((async) {
            final provider = ChatScreenStateProvider(
              extractionService: mockExtractionService,
              chatService: mockChatService,
            );

            provider.showConfirmation(onAutoSave: () {});

            // Wait 1 minute
            async.elapse(const Duration(minutes: 1));
            expect(provider.showingConfirmation, true);

            // User interacts - reset timer
            provider.resetInactivityTimer();

            // Wait another 1.5 minutes (should still be showing)
            async.elapse(const Duration(minutes: 1, seconds: 30));
            expect(provider.showingConfirmation, true);

            // Wait final 30 seconds (total 2 min from reset)
            async.elapse(const Duration(seconds: 30));
            expect(provider.showingConfirmation, false);

            provider.dispose();
          });
        });
      });
    });

    group('Resource Cleanup', () {
      testWidgets('dispose cleans up all resources', (tester) async {
        final provider = ChatScreenStateProvider(
          extractionService: mockExtractionService,
          chatService: mockChatService,
        );

        provider.showConfirmation(onAutoSave: () {});

        // Should not throw
        expect(() => provider.dispose(), returnsNormally);
      });
    });
  });
}

// Helper class for error testing
class _ThrowingChatService extends MockChatEventService {
  @override
  Future<ChatMessage> sendMessage(String message, {String? terminology}) async {
    throw Exception('Mock send message error');
  }
}
