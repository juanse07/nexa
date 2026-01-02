import 'package:flutter/material.dart';

/// FlowShift Premium Splash Screen
///
/// A premium splash screen featuring:
/// - Black gradient background (deep black → graphite)
/// - Centered "FlowShift" text with elegant fade-in animation
/// - "by PyMESoft" subtle branding at bottom
/// - Smooth transition to the main application
class FlowShiftSplashScreen extends StatefulWidget {
  const FlowShiftSplashScreen({
    super.key,
    required this.onComplete,
    this.variant,
  });

  /// Callback invoked when splash animation completes
  final VoidCallback onComplete;

  /// Optional app variant name to display (e.g., "Manager" or "Staff")
  final String? variant;

  @override
  State<FlowShiftSplashScreen> createState() => _FlowShiftSplashScreenState();
}

class _FlowShiftSplashScreenState extends State<FlowShiftSplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _backgroundController;
  late AnimationController _logoController;
  late AnimationController _subtitleController;
  late AnimationController _fadeOutController;

  late Animation<double> _backgroundOpacity;
  late Animation<double> _logoOpacity;
  late Animation<double> _subtitleOpacity;
  late Animation<double> _fadeOutOpacity;

  // FlowShift splash color palette
  static const Color _deepBlack = Color(0xFF0D0D0D);
  static const Color _darkGraphite = Color(0xFF1A1A1A);
  static const Color _graphite = Color(0xFF262626);
  static const Color _subtleGray = Color(0xFF808080);

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _startAnimationSequence();
  }

  void _setupAnimations() {
    // Background fade in: 0.0s - 0.8s
    _backgroundController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _backgroundOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _backgroundController, curve: Curves.easeOut),
    );

    // Logo fade in: 0.4s - 1.2s (staggered)
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _logoOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeOut),
    );

    // Subtitle fade in: 0.8s - 1.4s
    _subtitleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _subtitleOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _subtitleController, curve: Curves.easeOut),
    );

    // Fade out: 1.8s - 2.2s
    _fadeOutController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeOutOpacity = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(parent: _fadeOutController, curve: Curves.easeIn),
    );

    _fadeOutController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onComplete();
      }
    });
  }

  Future<void> _startAnimationSequence() async {
    // Start background fade in immediately
    _backgroundController.forward();

    // Wait 400ms, then start logo
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    _logoController.forward();

    // Wait another 400ms, then start subtitle
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    _subtitleController.forward();

    // Wait 1000ms (hold for visual impact), then fade out
    await Future<void>.delayed(const Duration(milliseconds: 1000));
    if (!mounted) return;
    _fadeOutController.forward();
  }

  @override
  void dispose() {
    _backgroundController.dispose();
    _logoController.dispose();
    _subtitleController.dispose();
    _fadeOutController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _backgroundOpacity,
        _logoOpacity,
        _subtitleOpacity,
        _fadeOutOpacity,
      ]),
      builder: (context, child) {
        final bgAlpha = (_backgroundOpacity.value * 255).round();
        return Opacity(
          opacity: _fadeOutOpacity.value,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  _deepBlack.withAlpha(bgAlpha),
                  _darkGraphite.withAlpha(bgAlpha),
                  _graphite.withAlpha(bgAlpha),
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
            child: SafeArea(
              child: Stack(
                children: [
                  // Centered FlowShift logo text
                  Center(
                    child: Opacity(
                      opacity: _logoOpacity.value,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'FlowShift',
                            style: TextStyle(
                              fontFamily: 'SF Pro Display',
                              fontSize: 42,
                              fontWeight: FontWeight.w300,
                              color: Colors.white,
                              letterSpacing: 2,
                            ),
                          ),
                          if (widget.variant != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              widget.variant!,
                              style: TextStyle(
                                fontFamily: 'SF Pro Display',
                                fontSize: 16,
                                fontWeight: FontWeight.w400,
                                color: Colors.white.withAlpha(179), // 70% opacity
                                letterSpacing: 4,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  // Bottom "by PyMESoft" branding
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 48,
                    child: Opacity(
                      opacity: _subtitleOpacity.value,
                      child: const Text(
                        'by PyMESoft',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'SF Pro Display',
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: _subtleGray,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
