import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:nexa/features/auth/data/services/auth_service.dart';
import 'package:nexa/features/auth/presentation/pages/login_page.dart';
import 'package:nexa/features/users/presentation/pages/manager_onboarding_page.dart';
import 'package:nexa/shared/presentation/theme/theme.dart';

/// The root widget of the Nexa application.
///
/// Configures the MaterialApp with theme, routing, and localization settings.
class NexaApp extends StatelessWidget {
  const NexaApp({super.key});

  static Future<String?> _validateAndGetToken() async {
    if (kIsWeb) {
      print('[APP] Validating token on web...');
    }

    final token = await AuthService.getJwt();

    if (kIsWeb && token != null) {
      print('[APP] Token found, length: ${token.length}');
      // Double-check for managerId on web
      try {
        final parts = token.split('.');
        if (parts.length == 3) {
          final payload = json.decode(
            utf8.decode(base64Url.decode(base64Url.normalize(parts[1])))
          ) as Map<String, dynamic>;

          if (kIsWeb) {
            print('[APP] Token payload keys: ${payload.keys.toList()}');
            print('[APP] Has managerId: ${payload.containsKey('managerId')}');
          }

          if (!payload.containsKey('managerId')) {
            print('[APP] Token missing managerId - forcing logout');
            await AuthService.signOut();
            return null;
          }
        }
      } catch (e) {
        print('[APP] Error checking token: $e');
      }
    }

    return token;
  }

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
        future: _validateAndGetToken(),
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
          return hasToken ? const ManagerOnboardingGate() : const LoginPage();
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
