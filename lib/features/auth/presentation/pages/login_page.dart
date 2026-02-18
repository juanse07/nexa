import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform;

import 'package:nexa/core/config/environment.dart';
import 'package:nexa/core/utils/responsive_layout.dart';
import 'package:nexa/features/auth/data/services/auth_service.dart';
import 'package:nexa/features/auth/data/services/apple_web_auth.dart';
import 'package:nexa/features/auth/presentation/widgets/phone_login_widget.dart';
import 'package:nexa/features/users/presentation/pages/manager_onboarding_page.dart';
import 'package:nexa/shared/presentation/theme/app_colors.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _loadingGoogle = false;
  bool _loadingApple = false;
  bool _loadingPhone = false;
  bool _loadingEmail = false;
  String? _error;
  bool _appleScriptReady = AppleWebAuth.isSupported;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

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
        MaterialPageRoute(builder: (_) => const ManagerOnboardingGate()),
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
        MaterialPageRoute(builder: (_) => const ManagerOnboardingGate()),
      );
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleEmail() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Please enter email and password');
      return;
    }
    setState(() {
      _loadingEmail = true;
      _error = null;
    });
    String? err;
    final ok = await AuthService.signInWithEmail(
      email: email,
      password: password,
      onError: (m) => err = m,
    );
    if (!mounted) return;
    setState(() {
      _loadingEmail = false;
      if (!ok) _error = err ?? 'Email sign-in failed';
    });
    if (ok && mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const ManagerOnboardingGate()),
      );
    }
  }

  void _handlePhone() {
    setState(() => _error = null);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 24,
          right: 24,
          top: 24,
        ),
        child: PhoneLoginWidget(
          onSuccess: () {
            Navigator.pop(context); // Close bottom sheet
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const ManagerOnboardingGate()),
            );
          },
          onCancel: () => Navigator.pop(context),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.primaryPurple,    // #2C3E50 navy
                Color(0xFF1A252F),          // darker navy
              ],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 40),

                      // Logo
                      Container(
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
                      const SizedBox(height: 24),

                      // Brand name
                      const Text(
                        'FlowShift',
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Manager',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                          color: Colors.white.withValues(alpha: 0.6),
                          letterSpacing: 4,
                        ),
                      ),
                      const SizedBox(height: 48),

                      // Sign-in card
                      Container(
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 40,
                              offset: const Offset(0, 16),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Text(
                              'Sign in to continue',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primaryPurple,
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Error banner
                            if (_error != null) ...[
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.error.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.errorBorder),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.error_outline, color: AppColors.error, size: 18),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _error!,
                                        style: const TextStyle(color: AppColors.error, fontSize: 13),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),
                            ],

                            // Google button
                            _buildSignInButton(
                              onPressed: _loadingGoogle ? null : _handleGoogle,
                              loading: _loadingGoogle,
                              icon: Icons.g_mobiledata_rounded,
                              label: 'Continue with Google',
                              backgroundColor: AppColors.secondaryPurple,
                              foregroundColor: Colors.white,
                              iconSize: 28,
                            ),

                            if (showApple) ...[
                              const SizedBox(height: 12),
                              _buildSignInButton(
                                onPressed: _loadingApple ? null : _handleApple,
                                loading: _loadingApple,
                                icon: Icons.apple_rounded,
                                label: 'Continue with Apple',
                                backgroundColor: AppColors.primaryPurple,
                                foregroundColor: Colors.white,
                              ),
                            ],

                            const SizedBox(height: 16),
                            // Divider
                            Row(
                              children: [
                                Expanded(child: Divider(color: AppColors.border)),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 14),
                                  child: Text(
                                    'or',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textMuted,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                Expanded(child: Divider(color: AppColors.border)),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Phone button
                            _buildSignInButton(
                              onPressed: _handlePhone,
                              loading: false,
                              icon: Icons.phone_iphone_rounded,
                              label: 'Continue with Phone',
                              backgroundColor: Colors.white,
                              foregroundColor: AppColors.primaryPurple,
                              outlined: true,
                            ),

                            const SizedBox(height: 16),
                            // Email divider
                            Row(
                              children: [
                                Expanded(child: Divider(color: AppColors.border)),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 14),
                                  child: Text(
                                    'or',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textMuted,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                Expanded(child: Divider(color: AppColors.border)),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Email field
                            TextField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              autocorrect: false,
                              textInputAction: TextInputAction.next,
                              decoration: InputDecoration(
                                prefixIcon: Icon(Icons.email_outlined, color: AppColors.textMuted),
                                hintText: 'Email',
                                filled: true,
                                fillColor: Colors.grey.shade50,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(color: AppColors.border),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(color: AppColors.border),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(color: AppColors.secondaryPurple, width: 1.5),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Password field
                            TextField(
                              controller: _passwordController,
                              obscureText: true,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => _handleEmail(),
                              decoration: InputDecoration(
                                prefixIcon: Icon(Icons.lock_outlined, color: AppColors.textMuted),
                                hintText: 'Password',
                                filled: true,
                                fillColor: Colors.grey.shade50,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(color: AppColors.border),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(color: AppColors.border),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(color: AppColors.secondaryPurple, width: 1.5),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Email sign-in button
                            _buildSignInButton(
                              onPressed: _loadingEmail ? null : _handleEmail,
                              loading: _loadingEmail,
                              icon: Icons.login_rounded,
                              label: 'Sign In',
                              backgroundColor: AppColors.secondaryPurple,
                              foregroundColor: Colors.white,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 28),

                      // Footer
                      Text(
                        'By continuing, you agree to our\nTerms of Service and Privacy Policy',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.4),
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
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

  Widget _buildSignInButton({
    required VoidCallback? onPressed,
    required bool loading,
    required IconData icon,
    required String label,
    required Color backgroundColor,
    required Color foregroundColor,
    bool outlined = false,
    double iconSize = 22,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: outlined
          ? OutlinedButton(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                foregroundColor: foregroundColor,
                side: BorderSide(color: AppColors.borderMedium, width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _buildButtonContent(loading, icon, label, foregroundColor, iconSize),
            )
          : ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: backgroundColor,
                foregroundColor: foregroundColor,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _buildButtonContent(loading, icon, label, foregroundColor, iconSize),
            ),
    );
  }

  Widget _buildButtonContent(bool loading, IconData icon, String label, Color color, double iconSize) {
    if (loading) {
      return SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(strokeWidth: 2.5, color: color),
      );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: iconSize),
        const SizedBox(width: 10),
        Text(label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
