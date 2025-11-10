import 'package:flutter/material.dart';

import '../data/services/onboarding_service.dart';
import 'venue_list_screen.dart';
import 'widgets/enhanced_city_picker.dart';

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
  String? _selectedCity;
  bool _isDetectingLocation = false;
  bool _isDiscoveringVenues = false;
  String? _errorMessage;
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

  /// Complete onboarding with selected city
  Future<void> _completeOnboarding() async {
    if (_selectedCity == null || _selectedCity!.isEmpty) {
      setState(() {
        _errorMessage = 'Please select a city';
      });
      return;
    }

    setState(() {
      _isDiscoveringVenues = true;
      _currentStep = 2; // Move to loading screen
      _errorMessage = null;
    });

    try {
      final result = await OnboardingService.completeOnboarding(_selectedCity!);

      if (result.success) {
        setState(() {
          _venueCount = result.venueCount;
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
            'We\'ll find popular event venues in your area to help you create events faster.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 32),

          // Location detection button
          if (_isDetectingLocation)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Detecting your location...'),
                  ],
                ),
              ),
            )
          else if (_selectedCity == null)
            OutlinedButton.icon(
              onPressed: _detectLocation,
              icon: const Icon(Icons.my_location),
              label: const Text('Detect My Location'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
              ),
            ),

          const SizedBox(height: 24),

          // City input with picker dialog
          TextField(
            controller: _cityController,
            readOnly: true,
            decoration: InputDecoration(
              labelText: 'City *',
              hintText: 'Select your city',
              prefixIcon: const Icon(Icons.location_city),
              suffixIcon: const Icon(Icons.arrow_drop_down),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
            ),
            onTap: () async {
              final result = await showDialog<String>(
                context: context,
                builder: (context) => EnhancedCityPicker(
                  initialCity: _selectedCity,
                ),
              );
              if (result != null) {
                setState(() {
                  _selectedCity = result;
                  _cityController.text = result;
                  _errorMessage = null;
                });
              }
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
              onPressed: _selectedCity != null && _selectedCity!.isNotEmpty
                  ? _completeOnboarding
                  : null,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.purple,
              ),
              child: const Text(
                'Discover Venues',
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

  /// Step 2: Loading venues
  Widget _buildLoadingStep() {
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
              'Discovering venues in\n$_selectedCity',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              'This may take a moment...',
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
            'We discovered ${_venueCount ?? 0} popular venues in $_selectedCity.',
            style: const TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'These venues will help you create events faster with AI assistance.',
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
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const VenueListScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.location_on),
              label: Text('View All ${_venueCount ?? 0} Venues'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
