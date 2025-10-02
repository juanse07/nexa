import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:nexa/app.dart';
import 'package:nexa/core/config/environment.dart';
import 'package:nexa/core/di/injection.dart';
import 'package:nexa/core/utils/logger.dart';

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

  // Set preferred orientations (portrait only for now)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Configure system UI overlays
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  // Initialize environment variables
  await Environment.load();
  AppLogger.instance.i('Environment loaded successfully');

  // Configure dependency injection
  await configureDependencies();
  AppLogger.instance.i('Dependencies configured successfully');

  // Set up global error handling
  FlutterError.onError = (FlutterErrorDetails details) {
    AppLogger.instance.e(
      'Flutter error caught',
      error: details.exception,
      stackTrace: details.stack,
    );
  };

  // Run the app
  runApp(const NexaApp());
}
