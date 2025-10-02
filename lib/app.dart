import 'package:flutter/material.dart';

import 'package:nexa/features/auth/data/services/auth_service.dart';
import 'package:nexa/features/auth/presentation/pages/login_page.dart';
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

      // Initial route - check authentication
      home: FutureBuilder<String?>(
        future: AuthService.getJwt(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );
          }

          // If JWT exists, go to main app, otherwise login
          final hasToken = snapshot.data != null && snapshot.data!.isNotEmpty;
          return hasToken ? const ExtractionScreen() : const LoginPage();
        },
      ),

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
