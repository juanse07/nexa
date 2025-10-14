import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform;

import 'package:nexa/core/config/environment.dart';
import 'package:nexa/features/auth/data/services/auth_service.dart';
import 'package:nexa/features/auth/data/services/apple_web_auth.dart';
import 'package:nexa/features/extraction/presentation/extraction_screen.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _loadingGoogle = false;
  bool _loadingApple = false;
  String? _error;
  bool _appleScriptReady = AppleWebAuth.isSupported;

  @override
  void initState() {
    super.initState();
    if (kIsWeb && !_appleScriptReady) {
      _waitForAppleScript();
    }
  }

  Future<void> _handleGoogle() async {
    setState(() {
      _loadingGoogle = true;
      _error = null;
    });
    String? err;
    final ok = await AuthService.signInWithGoogle(onError: (m) => err = m);
    setState(() {
      _loadingGoogle = false;
      if (!ok) _error = err ?? 'Google sign-in failed';
    });
    if (ok && mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const ExtractionScreen()),
      );
    }
  }

  void _waitForAppleScript([int attempt = 0]) {
    if (!mounted || _appleScriptReady || attempt > 40) return;
    Future<void>.delayed(const Duration(milliseconds: 150), () {
      if (!mounted) return;
      final supported = AppleWebAuth.isSupported;
      if (supported != _appleScriptReady) {
        setState(() {
          _appleScriptReady = supported;
        });
      }
      if (!supported) {
        _waitForAppleScript(attempt + 1);
      }
    });
  }

  Future<void> _handleApple() async {
    setState(() {
      _loadingApple = true;
      _error = null;
    });
    String? err;
    final ok = await AuthService.signInWithApple(onError: (message) => err = message);
    setState(() {
      _loadingApple = false;
      if (!ok) _error = err ?? 'Apple sign-in failed';
    });
    if (ok && mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const ExtractionScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final env = Environment.instance;
    final bool appleWebAvailable = kIsWeb &&
        _appleScriptReady &&
        env.contains('APPLE_SERVICE_ID') &&
        env.contains('APPLE_REDIRECT_URI');
    final bool isiOS = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
    final bool showApple = isiOS || appleWebAvailable;

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                theme.colorScheme.primaryContainer.withOpacity(0.3),
                theme.colorScheme.surfaceContainerLowest,
                theme.colorScheme.secondaryContainer.withOpacity(0.2),
              ],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Logo Section
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: theme.colorScheme.primary.withOpacity(0.1),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Image.asset(
                          'assets/appbar_logo.png',
                          height: 80,
                          width: 80,
                        ),
                      ),
                      const SizedBox(height: 48),

                      // Welcome Text
                      Text(
                        'Welcome Back',
                        style: theme.textTheme.headlineLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Sign in to continue to your account',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 48),

                      // Auth Card
                      Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 30,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            if (_error != null) ...[
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.errorContainer,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.error_outline,
                                      color: theme.colorScheme.error,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _error!,
                                        style: TextStyle(
                                          color: theme.colorScheme.error,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 24),
                            ],

                            // Google Sign In Button
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: FilledButton(
                                onPressed: _loadingGoogle ? null : _handleGoogle,
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF4285F4), // Google Blue
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  elevation: 2,
                                ),
                                child: _loadingGoogle
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Icon(
                                            Icons.login,
                                            size: 22,
                                            color: Colors.white,
                                          ),
                                          const SizedBox(width: 12),
                                          Text(
                                            'Continue with Google',
                                            style: theme.textTheme.titleMedium?.copyWith(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            if (showApple) ...[
                              // Divider
                              Row(
                                children: [
                                  Expanded(
                                    child: Divider(
                                      color: theme.colorScheme.outlineVariant,
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    child: Text(
                                      'OR',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.onSurface.withOpacity(0.5),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Divider(
                                      color: theme.colorScheme.outlineVariant,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                            ],

                            if (showApple)
                              SizedBox(
                                width: double.infinity,
                                height: 56,
                                child: OutlinedButton(
                                  onPressed: _loadingApple ? null : _handleApple,
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: theme.colorScheme.onSurface,
                                    side: BorderSide(
                                      color: theme.colorScheme.outline.withOpacity(0.5),
                                      width: 1.5,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  child: _loadingApple
                                      ? SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            color: theme.colorScheme.primary,
                                          ),
                                        )
                                      : Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            const Icon(
                                              Icons.apple,
                                              size: 22,
                                            ),
                                            const SizedBox(width: 12),
                                            Text(
                                              'Continue with Apple',
                                              style: theme.textTheme.titleMedium?.copyWith(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Footer Text
                      Text(
                        'By continuing, you agree to our Terms of Service\nand Privacy Policy',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.5),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
