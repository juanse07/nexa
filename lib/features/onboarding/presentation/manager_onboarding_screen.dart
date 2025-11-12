import 'package:flutter/material.dart';

import '../../cities/data/models/city.dart';
import '../data/services/onboarding_service.dart';
import 'widgets/multi_city_picker.dart';

/// Manager onboarding screen with city selection and venue discovery
class ManagerOnboardingScreen extends StatefulWidget {
  final VoidCallback? onComplete;

  const ManagerOnboardingScreen({
    super.key,
    this.onComplete,
  });

  @override
  State<ManagerOnboardingScreen> createState() => _ManagerOnboardingScreenState();
}

class _ManagerOnboardingScreenState extends State<ManagerOnboardingScreen> {
  int _currentStep = 0;
  List<City> _selectedCities = [];
  String? _errorMessage;

  // Legacy fields (keep for potential backward compatibility)
  String? _selectedCity;
  bool _isDetectingLocation = false;
  bool _isDiscoveringVenues = false;
  int? _venueCount;

  final TextEditingController _cityController = TextEditingController();

  @override
  void dispose() {
    _cityController.dispose();
    super.dispose();
  }

  /// Auto-detect user's city from device location
  Future<void> _detectLocation() async {
    setState(() {
      _isDetectingLocation = true;
      _errorMessage = null;
    });

    try {
      final city = await OnboardingService.detectUserCity();

      if (city != null) {
        setState(() {
          _selectedCity = city;
          _cityController.text = city;
          _isDetectingLocation = false;
        });
      } else {
        setState(() {
          _isDetectingLocation = false;
          _errorMessage = 'Could not detect your location. Please enter your city manually.';
        });
      }
    } catch (e) {
      setState(() {
        _isDetectingLocation = false;
        _errorMessage = 'Location detection failed. Please enter your city manually.';
      });
    }
  }

  /// Skip onboarding and continue to app
  void _skipOnboarding() {
    if (widget.onComplete != null) {
      widget.onComplete!();
    } else {
      Navigator.of(context).pop(true); // Return true to indicate completion (skipped)
    }
  }

  /// Complete onboarding with selected cities
  Future<void> _completeOnboarding() async {
    if (_selectedCities.isEmpty) {
      setState(() {
        _errorMessage = 'Please add at least one city';
      });
      return;
    }

    setState(() {
      _isDiscoveringVenues = true;
      _currentStep = 2; // Move to loading screen
      _errorMessage = null;
    });

    try {
      final result = await OnboardingService.completeOnboardingWithCities(_selectedCities);

      if (result.success) {
        setState(() {
          _currentStep = 3; // Move to success screen
          _isDiscoveringVenues = false;
        });
      } else {
        setState(() {
          _isDiscoveringVenues = false;
          _errorMessage = result.message;
          _currentStep = 1; // Go back to city selection
        });
      }
    } catch (e) {
      setState(() {
        _isDiscoveringVenues = false;
        _errorMessage = 'An error occurred. Please try again.';
        _currentStep = 1;
      });
    }
  }

  /// Finish onboarding and return to app
  void _finishOnboarding() {
    if (widget.onComplete != null) {
      widget.onComplete!();
    } else {
      Navigator.of(context).pop(true); // Return true to indicate completion
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          child: _buildStepContent(),
        ),
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildWelcomeStep();
      case 1:
        return _buildCitySelectionStep();
      case 2:
        return _buildLoadingStep();
      case 3:
        return _buildSuccessStep();
      default:
        return _buildWelcomeStep();
    }
  }

  /// Step 0: Welcome message
  Widget _buildWelcomeStep() {
    return Padding(
      key: const ValueKey('welcome'),
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.purple.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.location_city,
              size: 80,
              color: Colors.purple,
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'Welcome to Nexa!',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          const Text(
            'Let\'s personalize your experience by finding popular event venues in your area.',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                setState(() {
                  _currentStep = 1;
                });
                _detectLocation(); // Auto-start location detection
              },
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.purple,
              ),
              child: const Text(
                'Get Started',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _skipOnboarding,
            child: const Text('Skip for now'),
          ),
        ],
      ),
    );
  }

  /// Step 1: City selection
  Widget _buildCitySelectionStep() {
    return SingleChildScrollView(
      key: const ValueKey('city-selection'),
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 40),
          const Text(
            'Where are you located?',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Add one or more cities where you operate. You can discover venues for each city later.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 32),

          // Multi-city picker widget
          MultiCityPicker(
            initialCities: _selectedCities,
            onCitiesChanged: (cities) {
              setState(() {
                _selectedCities = cities;
                _errorMessage = null;
              });
            },
          ),

          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 32),

          // Continue button
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _selectedCities.isNotEmpty
                  ? _completeOnboarding
                  : null,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.purple,
              ),
              child: const Text(
                'Continue',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: _skipOnboarding,
              child: const Text('Skip for now'),
            ),
          ),
        ],
      ),
    );
  }

  /// Step 2: Setting up cities
  Widget _buildLoadingStep() {
    final cityCount = _selectedCities.length;
    final cityNames = _selectedCities.map((c) => c.displayName).join(', ');

    return Center(
      key: const ValueKey('loading'),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.purple),
            ),
            const SizedBox(height: 32),
            Text(
              cityCount == 1
                  ? 'Setting up your city...'
                  : 'Setting up your $cityCount cities...',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            if (cityCount <= 3) ...[
              const SizedBox(height: 12),
              Text(
                cityNames,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 16),
            const Text(
              'This will only take a moment...',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Step 3: Success
  Widget _buildSuccessStep() {
    return Padding(
      key: const ValueKey('success'),
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle,
              size: 80,
              color: Colors.green,
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'All Set!',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            _selectedCities.length == 1
                ? 'Your city has been configured successfully!'
                : 'Your ${_selectedCities.length} cities have been configured successfully!',
            style: const TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'You can now discover venues for each city from Settings > Manage Cities.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _finishOnboarding,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.purple,
              ),
              child: const Text(
                'Start Using Nexa',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
