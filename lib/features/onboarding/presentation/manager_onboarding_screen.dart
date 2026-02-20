import 'package:flutter/material.dart';
import 'package:nexa/l10n/app_localizations.dart';
import 'package:nexa/shared/presentation/theme/app_colors.dart';

import '../../cities/data/models/city.dart';
import '../data/services/onboarding_service.dart';
import 'widgets/animated_checkmark.dart';
import 'widgets/glassmorphism_card.dart';
import 'widgets/multi_city_picker.dart';
import 'widgets/onboarding_background.dart';
import 'widgets/step_progress_indicator.dart';

/// Manager onboarding screen with city selection and venue discovery.
///
/// Premium redesign: navy gradient background with floating orbs,
/// glassmorphism cards, staggered entrance animations, custom loading
/// rings, and animated checkmark on success.
class ManagerOnboardingScreen extends StatefulWidget {
  final VoidCallback? onComplete;

  const ManagerOnboardingScreen({
    super.key,
    this.onComplete,
  });

  @override
  State<ManagerOnboardingScreen> createState() => _ManagerOnboardingScreenState();
}

class _ManagerOnboardingScreenState extends State<ManagerOnboardingScreen>
    with TickerProviderStateMixin {
  int _currentStep = 0;
  List<City> _selectedCities = [];
  String? _errorMessage;

  final TextEditingController _cityController = TextEditingController();

  // Staggered entrance animations
  late final AnimationController _entranceController;
  late final Animation<double> _logoFade;
  late final Animation<double> _titleFade;
  late final Animation<Offset> _titleSlide;
  late final Animation<double> _subtitleFade;
  late final Animation<double> _ctaFade;
  late final Animation<Offset> _ctaSlide;

  // Step transition
  late final AnimationController _transitionController;
  late final Animation<double> _fadeOut;
  late final Animation<double> _fadeIn;
  late final Animation<Offset> _slideOut;
  late final Animation<Offset> _slideIn;

  int _displayedStep = 0; // What's currently visible during transitions

  @override
  void initState() {
    super.initState();
    _setupEntranceAnimations();
    _setupTransitionAnimations();
    _entranceController.forward();
  }

  void _setupEntranceAnimations() {
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _logoFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
      ),
    );

    _titleFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.2, 0.6, curve: Curves.easeOut),
      ),
    );
    _titleSlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.2, 0.6, curve: Curves.easeOut),
      ),
    );

    _subtitleFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.35, 0.7, curve: Curves.easeOut),
      ),
    );

    _ctaFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.5, 0.85, curve: Curves.easeOut),
      ),
    );
    _ctaSlide = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.5, 0.85, curve: Curves.easeOut),
      ),
    );
  }

  void _setupTransitionAnimations() {
    _transitionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _fadeOut = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(
        parent: _transitionController,
        curve: const Interval(0.0, 0.4, curve: Curves.easeIn),
      ),
    );
    _slideOut = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(-0.3, 0),
    ).animate(
      CurvedAnimation(
        parent: _transitionController,
        curve: const Interval(0.0, 0.4, curve: Curves.easeIn),
      ),
    );

    _fadeIn = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _transitionController,
        curve: const Interval(0.5, 1.0, curve: Curves.easeOut),
      ),
    );
    _slideIn = Tween<Offset>(
      begin: const Offset(0.3, 0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _transitionController,
        curve: const Interval(0.5, 1.0, curve: Curves.easeOut),
      ),
    );

    _transitionController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _displayedStep = _currentStep;
        });
        _transitionController.reset();
      }
    });
  }

  @override
  void dispose() {
    _cityController.dispose();
    _entranceController.dispose();
    _transitionController.dispose();
    super.dispose();
  }

  void _goToStep(int step) {
    if (_transitionController.isAnimating) return;
    setState(() {
      _currentStep = step;
    });
    _transitionController.forward();
  }

  /// Auto-detect user's city from device location
  Future<void> _detectLocation() async {
    setState(() {
      _errorMessage = null;
    });

    try {
      final city = await OnboardingService.detectUserCity();

      if (city != null) {
        setState(() {
          _cityController.text = city;
        });
      } else {
        if (!mounted) return;
        final l10n = AppLocalizations.of(context)!;
        setState(() {
          _errorMessage = l10n.couldNotDetectLocationEnterManually;
        });
      }
    } catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      setState(() {
        _errorMessage = l10n.locationDetectionFailed;
      });
    }
  }

  /// Skip onboarding and continue to app
  void _skipOnboarding() {
    if (widget.onComplete != null) {
      widget.onComplete!();
    } else {
      Navigator.of(context).pop(true);
    }
  }

  /// Complete onboarding with selected cities
  Future<void> _completeOnboarding() async {
    final l10n = AppLocalizations.of(context)!;
    if (_selectedCities.isEmpty) {
      setState(() {
        _errorMessage = l10n.pleaseAddAtLeastOneCity;
      });
      return;
    }

    setState(() {
      _errorMessage = null;
    });
    _goToStep(2);

    try {
      final result = await OnboardingService.completeOnboardingWithCities(_selectedCities);

      if (result.success) {
        _goToStep(3);
      } else {
        setState(() {
          _errorMessage = result.message;
        });
        _goToStep(1);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = l10n.anErrorOccurredTryAgain;
      });
      _goToStep(1);
    }
  }

  /// Finish onboarding and return to app
  void _finishOnboarding() {
    if (widget.onComplete != null) {
      widget.onComplete!();
    } else {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: OnboardingBackground(
        child: SafeArea(
          child: _buildAnimatedContent(),
        ),
      ),
    );
  }

  Widget _buildAnimatedContent() {
    // During transition, show the outgoing step fading out or incoming step fading in
    if (_transitionController.isAnimating) {
      return AnimatedBuilder(
        animation: _transitionController,
        builder: (context, _) {
          if (_transitionController.value < 0.5) {
            // Fading out old step
            return FadeTransition(
              opacity: _fadeOut,
              child: SlideTransition(
                position: _slideOut,
                child: _buildStepContent(_displayedStep),
              ),
            );
          } else {
            // Fading in new step
            return FadeTransition(
              opacity: _fadeIn,
              child: SlideTransition(
                position: _slideIn,
                child: _buildStepContent(_currentStep),
              ),
            );
          }
        },
      );
    }

    return _buildStepContent(_displayedStep);
  }

  Widget _buildStepContent(int step) {
    return Stack(
      children: [
        switch (step) {
          0 => _buildWelcomeStep(),
          1 => _buildCitySelectionStep(),
          2 => _buildLoadingStep(),
          3 => _buildSuccessStep(),
          _ => _buildWelcomeStep(),
        },
        // Step dots at the bottom
        Positioned(
          left: 0,
          right: 0,
          bottom: 24,
          child: StepProgressIndicator(
            currentStep: step,
            totalSteps: 4,
            variant: StepIndicatorVariant.dot,
          ),
        ),
      ],
    );
  }

  /// Step 0: Welcome — logo, staggered text, glassmorphism CTA
  Widget _buildWelcomeStep() {
    final l10n = AppLocalizations.of(context)!;
    return AnimatedBuilder(
      animation: _entranceController,
      builder: (context, _) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo
              FadeTransition(
                opacity: _logoFade,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                  child: Image.asset(
                    'assets/logo_icon_square_transparent.png',
                    height: 80,
                    width: 80,
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Title
              FadeTransition(
                opacity: _titleFade,
                child: SlideTransition(
                  position: _titleSlide,
                  child: Text(
                    l10n.welcomeToFlowShift,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Subtitle
              FadeTransition(
                opacity: _subtitleFade,
                child: Text(
                  l10n.personalizeExperienceWithVenues,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withValues(alpha: 0.7),
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 48),

              // CTA area with glassmorphism
              FadeTransition(
                opacity: _ctaFade,
                child: SlideTransition(
                  position: _ctaSlide,
                  child: GlassmorphismCard(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: ElevatedButton(
                            onPressed: () {
                              _goToStep(1);
                              _detectLocation();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryIndigo,
                              foregroundColor: AppColors.primaryPurple,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: Text(
                              l10n.getStarted,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: _skipOnboarding,
                          child: Text(
                            l10n.skipForNow,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 60), // room for step dots
            ],
          ),
        );
      },
    );
  }

  /// Step 1: City selection — glassmorphism card wrapping city picker
  Widget _buildCitySelectionStep() {
    final l10n = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 40),
          Text(
            l10n.whereAreYouLocated,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            l10n.addCitiesWhereYouOperate,
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.7),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),

          // City picker inside glassmorphism card
          GlassmorphismCard(
            padding: const EdgeInsets.all(16),
            child: Theme(
              data: Theme.of(context).copyWith(
                // Make text fields readable on dark background
                inputDecorationTheme: InputDecorationTheme(
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.15),
                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                  labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.primaryIndigo, width: 1.5),
                  ),
                ),
                textTheme: Theme.of(context).textTheme.apply(
                  bodyColor: Colors.white,
                  displayColor: Colors.white,
                ),
                iconTheme: IconThemeData(color: Colors.white.withValues(alpha: 0.7)),
                chipTheme: ChipThemeData(
                  backgroundColor: AppColors.primaryIndigo.withValues(alpha: 0.2),
                  labelStyle: const TextStyle(color: Colors.white),
                  deleteIconColor: Colors.white.withValues(alpha: 0.7),
                  side: BorderSide(color: AppColors.primaryIndigo.withValues(alpha: 0.4)),
                ),
              ),
              child: MultiCityPicker(
                initialCities: _selectedCities,
                onCitiesChanged: (cities) {
                  setState(() {
                    _selectedCities = cities;
                    _errorMessage = null;
                  });
                },
              ),
            ),
          ),

          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
            GlassmorphismCard(
              padding: const EdgeInsets.all(12),
              accentColor: AppColors.error,
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: AppColors.error, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: AppColors.error, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),

          // Continue button
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _selectedCities.isNotEmpty ? _completeOnboarding : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryIndigo,
                foregroundColor: AppColors.primaryPurple,
                disabledBackgroundColor: Colors.white.withValues(alpha: 0.1),
                disabledForegroundColor: Colors.white.withValues(alpha: 0.3),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Continue',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: _skipOnboarding,
              child: Text(
                l10n.skipForNow,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(height: 80), // room for step dots + bottom safe area
        ],
      ),
    );
  }

  /// Step 2: Loading — pulsing concentric rings + animated city names
  Widget _buildLoadingStep() {
    final l10n = AppLocalizations.of(context)!;
    final cityCount = _selectedCities.length;
    final cityNames = _selectedCities.map((c) => c.displayName).toList();

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _PulsingRings(color: AppColors.primaryIndigo),
            const SizedBox(height: 40),
            Text(
              cityCount == 1
                  ? l10n.settingUpYourCity
                  : l10n.settingUpYourCities(cityCount),
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            // Animated city names appearing one by one
            if (cityCount <= 5) _AnimatedCityNames(names: cityNames),
            const SizedBox(height: 12),
            Text(
              l10n.thisWillOnlyTakeAMoment,
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Step 3: Success — animated checkmark with gold particles
  Widget _buildSuccessStep() {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.all(28.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedCheckmark(
            size: 120,
            color: AppColors.primaryIndigo,
            particleColor: AppColors.primaryIndigo,
            showParticles: true,
          ),
          const SizedBox(height: 32),
          Text(
            l10n.allSet,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            _selectedCities.length == 1
                ? l10n.yourCityConfiguredSuccessfully
                : l10n.yourCitiesConfiguredSuccessfully(_selectedCities.length),
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withValues(alpha: 0.7),
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.discoverVenuesFromSettings,
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.5),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
          GlassmorphismCard(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _finishOnboarding,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryIndigo,
                  foregroundColor: AppColors.primaryPurple,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  l10n.startUsingFlowShift,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
          const SizedBox(height: 60),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Pulsing concentric rings loading indicator
// ---------------------------------------------------------------------------

class _PulsingRings extends StatefulWidget {
  final Color color;

  const _PulsingRings({required this.color});

  @override
  State<_PulsingRings> createState() => _PulsingRingsState();
}

class _PulsingRingsState extends State<_PulsingRings>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      height: 120,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            painter: _PulsingRingsPainter(
              progress: _controller.value,
              color: widget.color,
            ),
          );
        },
      ),
    );
  }
}

class _PulsingRingsPainter extends CustomPainter {
  final double progress;
  final Color color;

  _PulsingRingsPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // 3 concentric rings with staggered phases
    for (int i = 0; i < 3; i++) {
      final phase = (progress + i * 0.33) % 1.0;
      final radius = 15.0 + phase * 40.0;
      final opacity = (1.0 - phase).clamp(0.0, 0.5);

      final paint = Paint()
        ..color = color.withValues(alpha: opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5;

      canvas.drawCircle(center, radius, paint);
    }

    // Center dot
    canvas.drawCircle(
      center,
      6,
      Paint()..color = color.withValues(alpha: 0.8),
    );
  }

  @override
  bool shouldRepaint(_PulsingRingsPainter old) => old.progress != progress;
}

// ---------------------------------------------------------------------------
// Animated city names that fade in one by one
// ---------------------------------------------------------------------------

class _AnimatedCityNames extends StatefulWidget {
  final List<String> names;

  const _AnimatedCityNames({required this.names});

  @override
  State<_AnimatedCityNames> createState() => _AnimatedCityNamesState();
}

class _AnimatedCityNamesState extends State<_AnimatedCityNames>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 600 * widget.names.length),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Column(
          children: List.generate(widget.names.length, (i) {
            final start = i / widget.names.length;
            final end = (i + 1) / widget.names.length;
            final opacity = Interval(start, end, curve: Curves.easeOut)
                .transform(_controller.value);
            return Opacity(
              opacity: opacity,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  widget.names[i],
                  style: TextStyle(
                    fontSize: 15,
                    color: AppColors.primaryIndigo.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
