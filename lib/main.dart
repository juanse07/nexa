import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';

import 'package:nexa/app.dart';
import 'package:nexa/core/config/environment.dart';
import 'package:nexa/core/deep_link/deep_link_service.dart';
import 'package:nexa/core/di/injection.dart';
import 'package:nexa/core/utils/logger.dart';
import 'package:nexa/services/notification_service.dart';

/// Main entry point for the Nexa application.
///
/// Initializes core dependencies and configurations before running the app:
/// - Environment variables
/// - Dependency injection
/// - System UI configuration
/// - Error handling
Future<void> main() async {
  // Ensure Flutter bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Set preferred orientations (portrait only for mobile, all orientations for web)
    if (!kIsWeb) {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);

      // Configure system UI overlays (mobile only)
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
          systemNavigationBarColor: Colors.white,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
      );
    }

    // Initialize environment variables
    await Environment.load();
    if (kIsWeb) {
      print('Environment loaded successfully for web');
    } else {
      AppLogger.instance.i('Environment loaded successfully');
    }

    // Initialize Firebase (for phone auth)
    try {
      await Firebase.initializeApp();
      if (kIsWeb) {
        print('Firebase initialized successfully');
      } else {
        AppLogger.instance.i('Firebase initialized successfully');
      }
    } catch (e) {
      // Firebase may already be initialized or not configured
      if (kIsWeb) {
        print('Firebase initialization skipped: $e');
      } else {
        AppLogger.instance.w('Firebase initialization skipped', error: e);
      }
    }

    // Configure dependency injection
    await configureDependencies();
    if (kIsWeb) {
      print('Dependencies configured successfully for web');
    } else {
      AppLogger.instance.i('Dependencies configured successfully');
    }

    // Initialize push notifications (mobile only)
    if (!kIsWeb) {
      try {
        await NotificationService().initialize();
        AppLogger.instance.i('NotificationService initialized successfully');
      } catch (e) {
        AppLogger.instance.e('Failed to initialize NotificationService', error: e);
      }
    }

    // Initialize deep link service (mobile only)
    if (!kIsWeb) {
      try {
        await DeepLinkService.instance.initialize();
        AppLogger.instance.i('DeepLinkService initialized successfully');
      } catch (e) {
        AppLogger.instance.e('Failed to initialize DeepLinkService', error: e);
      }
    }

    // Set up global error handling
    FlutterError.onError = (FlutterErrorDetails details) {
      if (kIsWeb) {
        print('Flutter error: ${details.exception}');
        print('Stack trace: ${details.stack}');
      } else {
        AppLogger.instance.e(
          'Flutter error caught',
          error: details.exception,
          stackTrace: details.stack,
        );
      }
    };

    // Run the app
    runApp(const NexaApp());
  } catch (e, stackTrace) {
    // Catch any initialization errors
    if (kIsWeb) {
      print('FATAL ERROR during initialization: $e');
      print('Stack trace: $stackTrace');
    }

    // Show error screen
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  const Text(
                    'Failed to initialize app',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    e.toString(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
