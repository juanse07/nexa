import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nexa/features/auth/data/services/phone_auth_service.dart';
import 'package:nexa/l10n/app_localizations.dart';

/// Widget for phone number authentication
/// Provides a two-step flow: phone number input → OTP verification
class PhoneLoginWidget extends StatefulWidget {
  final VoidCallback onSuccess;
  final VoidCallback? onCancel;

  const PhoneLoginWidget({
    super.key,
    required this.onSuccess,
    this.onCancel,
  });

  @override
  State<PhoneLoginWidget> createState() => _PhoneLoginWidgetState();
}

class _PhoneLoginWidgetState extends State<PhoneLoginWidget> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _phoneAuthService = PhoneAuthService();
  final _phoneFocusNode = FocusNode();
  final _otpFocusNode = FocusNode();

  PhoneAuthState _state = PhoneAuthState.idle;
  String? _error;
  String _selectedCountryCode = '+1';

  // Common country codes
  static const _countryCodes = [
    ('+1', 'US'),
    ('+44', 'UK'),
    ('+52', 'MX'),
    ('+34', 'ES'),
    ('+33', 'FR'),
    ('+49', 'DE'),
    ('+39', 'IT'),
    ('+81', 'JP'),
    ('+86', 'CN'),
    ('+91', 'IN'),
    ('+55', 'BR'),
    ('+61', 'AU'),
  ];

  @override
  void initState() {
    super.initState();
    _phoneAuthService.onStateChanged = (state, error) {
      if (!mounted) return;
      setState(() {
        _state = state;
        _error = error;
      });

      if (state == PhoneAuthState.success) {
        widget.onSuccess();
      } else if (state == PhoneAuthState.codeSent) {
        // Focus OTP field when code is sent
        _otpFocusNode.requestFocus();
      }
    };
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    _phoneFocusNode.dispose();
    _otpFocusNode.dispose();
    super.dispose();
  }

  String get _fullPhoneNumber {
    final phone = _phoneController.text.trim().replaceAll(RegExp(r'[^\d]'), '');
    return '$_selectedCountryCode$phone';
  }

  Future<void> _sendOtp() async {
    final l10n = AppLocalizations.of(context)!;
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      setState(() => _error = l10n.pleaseEnterPhoneNumber);
      return;
    }

    // Basic validation: at least 6 digits
    final digitsOnly = phone.replaceAll(RegExp(r'[^\d]'), '');
    if (digitsOnly.length < 6) {
      setState(() => _error = l10n.pleaseEnterValidPhoneNumber);
      return;
    }

    setState(() => _error = null);
    await _phoneAuthService.sendOtp(_fullPhoneNumber);
  }

  Future<void> _verifyOtp() async {
    final l10n = AppLocalizations.of(context)!;
    final code = _otpController.text.trim();
    if (code.isEmpty) {
      setState(() => _error = l10n.pleaseEnterVerificationCode);
      return;
    }

    if (code.length != 6) {
      setState(() => _error = l10n.verificationCodeMustBe6Digits);
      return;
    }

    setState(() => _error = null);
    await _phoneAuthService.verifyOtp(code);
  }

  void _resetFlow() {
    _otpController.clear();
    _phoneAuthService.reset();
    _phoneFocusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.phone_android,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.phoneSignIn,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      _state == PhoneAuthState.codeSent || _state == PhoneAuthState.verifying
                          ? l10n.enterVerificationCode
                          : l10n.weWillSendVerificationCode,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.onCancel != null)
                IconButton(
                  onPressed: widget.onCancel,
                  icon: const Icon(Icons.close),
                ),
            ],
          ),

          const SizedBox(height: 24),

          // Error message
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
            const SizedBox(height: 16),
          ],

          // Phone input or OTP input based on state
          if (_state == PhoneAuthState.idle ||
              _state == PhoneAuthState.sendingCode ||
              (_state == PhoneAuthState.error && !_phoneAuthService.hasActiveVerification)) ...[
            _buildPhoneInput(theme),
          ] else if (_state == PhoneAuthState.codeSent ||
              _state == PhoneAuthState.verifying ||
              (_state == PhoneAuthState.error && _phoneAuthService.hasActiveVerification)) ...[
            _buildOtpInput(theme),
          ],

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildPhoneInput(ThemeData theme) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Country code + Phone number input
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Country code dropdown
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: theme.colorScheme.outline.withOpacity(0.5)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedCountryCode,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  borderRadius: BorderRadius.circular(12),
                  items: _countryCodes.map((c) {
                    return DropdownMenuItem(
                      value: c.$1,
                      child: Text('${c.$1} ${c.$2}'),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedCountryCode = value);
                    }
                  },
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Phone number field
            Expanded(
              child: TextField(
                controller: _phoneController,
                focusNode: _phoneFocusNode,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _sendOtp(),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d\s\-()]')),
                  LengthLimitingTextInputFormatter(15),
                ],
                decoration: InputDecoration(
                  hintText: l10n.phoneNumber,
                  prefixIcon: const Icon(Icons.phone),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Send code button
        SizedBox(
          height: 52,
          child: FilledButton(
            onPressed: _state == PhoneAuthState.sendingCode ? null : _sendOtp,
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _state == PhoneAuthState.sendingCode
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(l10n.sendVerificationCode),
          ),
        ),
      ],
    );
  }

  Widget _buildOtpInput(ThemeData theme) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Show the phone number being verified
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                Icons.phone,
                size: 18,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _fullPhoneNumber,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              TextButton(
                onPressed: _resetFlow,
                child: Text(l10n.change),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // OTP input
        TextField(
          controller: _otpController,
          focusNode: _otpFocusNode,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          textAlign: TextAlign.center,
          onSubmitted: (_) => _verifyOtp(),
          style: const TextStyle(
            fontSize: 24,
            letterSpacing: 12,
            fontWeight: FontWeight.bold,
          ),
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
          decoration: InputDecoration(
            hintText: '------',
            hintStyle: TextStyle(
              letterSpacing: 12,
              color: theme.colorScheme.outline,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Verify button
        SizedBox(
          height: 52,
          child: FilledButton(
            onPressed: _state == PhoneAuthState.verifying ? null : _verifyOtp,
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _state == PhoneAuthState.verifying
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(l10n.verifyCode),
          ),
        ),

        const SizedBox(height: 12),

        // Resend code button
        TextButton(
          onPressed: _state == PhoneAuthState.sendingCode ? null : () {
            _phoneAuthService.resendOtp();
          },
          child: Text(l10n.didntReceiveCodeResend),
        ),
      ],
    );
  }
}
