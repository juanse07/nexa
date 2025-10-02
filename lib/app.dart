import 'package:flutter/material.dart';

import 'package:nexa/features/extraction/presentation/extraction_screen.dart';
import 'package:nexa/shared/presentation/theme/theme.dart';

/// The root widget of the Nexa application.
///
/// Configures the MaterialApp with theme, routing, and localization settings.
class NexaApp extends StatelessWidget {
  const NexaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nexa',
      debugShowCheckedModeBanner: false,

      // Theme configuration
      theme: AppTheme.lightTheme(),
      darkTheme: AppTheme.darkTheme(),
      themeMode: ThemeMode.light,

      // Initial route
      home: const ExtractionScreen(),

      // Performance optimizations
      builder: (BuildContext context, Widget? child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.noScaling,
          ),
          child: child!,
        );
      },
    );
  }
}
