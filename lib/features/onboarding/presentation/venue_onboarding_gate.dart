import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../../core/config/app_config.dart';
import '../../auth/data/services/auth_service.dart';
import '../../main/presentation/main_screen.dart';
import 'manager_onboarding_screen.dart';

/// Gate widget that checks if manager has completed venue onboarding
/// Shows venue discovery screen if not, otherwise navigates to main app
class VenueOnboardingGate extends StatefulWidget {
  const VenueOnboardingGate({super.key});

  @override
  State<VenueOnboardingGate> createState() => _VenueOnboardingGateState();
}

class _VenueOnboardingGateState extends State<VenueOnboardingGate> {
  bool _isLoading = true;
  bool _hasCompletedOnboarding = false;

  @override
  void initState() {
    super.initState();
    _checkOnboardingStatus();
  }

  /// Check if manager has completed onboarding by checking if they have a venue list
  Future<void> _checkOnboardingStatus() async {
    try {
      final token = await AuthService.getJwt();
      if (token == null) {
        // Not authenticated, shouldn't happen but handle gracefully
        setState(() {
          _isLoading = false;
          _hasCompletedOnboarding = false;
        });
        return;
      }

      final baseUrl = AppConfig.instance.baseUrl;
      final url = Uri.parse('$baseUrl/managers/me');

      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final venueList = data['venueList'] as List?;

        // Consider onboarding complete if they have at least one venue
        // OR if they explicitly skipped (we can check a flag later)
        final hasVenues = venueList != null && venueList.isNotEmpty;

        setState(() {
          _hasCompletedOnboarding = hasVenues;
          _isLoading = false;
        });

        // Navigate to appropriate screen
        if (mounted) {
          if (hasVenues) {
            _navigateToMainApp();
          }
          // If no venues, stay on this screen and show onboarding
        }
      } else {
        // Error fetching profile, assume onboarding needed
        setState(() {
          _isLoading = false;
          _hasCompletedOnboarding = false;
        });
      }
    } catch (e) {
      print('[VenueOnboardingGate] Error checking onboarding status: $e');
      setState(() {
        _isLoading = false;
        _hasCompletedOnboarding = false;
      });
    }
  }

  /// Navigate to main application
  void _navigateToMainApp() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => const MainScreen(),
      ),
    );
  }

  /// Handle onboarding completion
  void _onOnboardingComplete() {
    // Navigate to main app
    _navigateToMainApp();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_hasCompletedOnboarding) {
      // This shouldn't render because we navigate away, but just in case
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Show onboarding screen
    return WillPopScope(
      onWillPop: () async => false, // Prevent back navigation
      child: ManagerOnboardingScreen(
        onComplete: _onOnboardingComplete,
      ),
    );
  }
}
