import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

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
  static const _lastDismissedKey = 'venue_onboarding_last_dismissed';
  static const _dismissIntervalDays = 30;

  bool _isLoading = true;
  bool _hasCompletedOnboarding = false;

  @override
  void initState() {
    super.initState();
    _checkOnboardingStatus();
  }

  /// Check if manager has completed onboarding by checking venues collection
  Future<void> _checkOnboardingStatus() async {
    try {
      final token = await AuthService.getJwt();
      if (token == null) {
        setState(() {
          _isLoading = false;
          _hasCompletedOnboarding = false;
        });
        return;
      }

      final baseUrl = AppConfig.instance.baseUrl;

      // Check venues from the venues collection
      final venuesResponse = await http.get(
        Uri.parse('$baseUrl/venues'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      bool hasVenues = false;
      if (venuesResponse.statusCode == 200) {
        final venuesData = jsonDecode(venuesResponse.body);
        final venuesList = venuesData['venues'] as List?;
        hasVenues = venuesList != null && venuesList.isNotEmpty;
      }

      // If they have venues, skip onboarding entirely
      if (hasVenues) {
        setState(() {
          _hasCompletedOnboarding = true;
          _isLoading = false;
        });
        if (mounted) _navigateToMainApp();
        return;
      }

      // No venues — check if dismissed recently (within 30 days)
      final prefs = await SharedPreferences.getInstance();
      final lastDismissed = prefs.getInt(_lastDismissedKey);
      if (lastDismissed != null) {
        final dismissedDate = DateTime.fromMillisecondsSinceEpoch(lastDismissed);
        final daysSince = DateTime.now().difference(dismissedDate).inDays;
        if (daysSince < _dismissIntervalDays) {
          // Dismissed recently, skip onboarding
          setState(() {
            _hasCompletedOnboarding = true;
            _isLoading = false;
          });
          if (mounted) _navigateToMainApp();
          return;
        }
      }

      // No venues and not dismissed recently — show onboarding
      setState(() {
        _hasCompletedOnboarding = false;
        _isLoading = false;
      });
    } catch (e) {
      print('[VenueOnboardingGate] Error checking onboarding status: $e');
      // On error, skip onboarding to avoid blocking the user
      setState(() {
        _isLoading = false;
        _hasCompletedOnboarding = true;
      });
      if (mounted) _navigateToMainApp();
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

  /// Handle onboarding completion (both skip and finish)
  Future<void> _onOnboardingComplete() async {
    // Save dismiss timestamp so we don't show again for 30 days
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastDismissedKey, DateTime.now().millisecondsSinceEpoch);
    if (mounted) _navigateToMainApp();
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
