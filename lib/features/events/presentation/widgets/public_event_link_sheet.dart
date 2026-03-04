import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:nexa/l10n/app_localizations.dart';
import 'package:nexa/shared/presentation/theme/app_colors.dart';
import 'package:nexa/features/extraction/services/event_service.dart';

class PublicEventLinkSheet extends StatefulWidget {
  final String eventId;
  final EventService eventService;

  const PublicEventLinkSheet({
    super.key,
    required this.eventId,
    required this.eventService,
  });

  @override
  State<PublicEventLinkSheet> createState() => _PublicEventLinkSheetState();
}

class _PublicEventLinkSheetState extends State<PublicEventLinkSheet> {
  bool _loading = true;
  bool _linkExists = false;
  String? _url;
  String? _shortCode;

  // Privacy toggles
  bool _showContactName = true;
  bool _showContactPhone = false;
  bool _showContactEmail = false;
  bool _showManagerPhoto = false;

  @override
  void initState() {
    super.initState();
    _checkExistingLink();
  }

  Future<void> _checkExistingLink() async {
    try {
      final result = await widget.eventService.getPublicLink(widget.eventId);
      if (!mounted) return;
      if (result['exists'] == true) {
        setState(() {
          _linkExists = true;
          _url = result['url'] as String?;
          _shortCode = result['shortCode'] as String?;
          _showContactName = result['showContactName'] == true;
          _showContactPhone = result['showContactPhone'] == true;
          _showContactEmail = result['showContactEmail'] == true;
          _showManagerPhoto = result['showManagerPhoto'] == true;
        });
      }
    } catch (_) {
      // No link exists or error — show generate state
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _generateLink() async {
    setState(() => _loading = true);
    try {
      final result = await widget.eventService.createPublicLink(
        widget.eventId,
        showContactName: _showContactName,
        showContactPhone: _showContactPhone,
        showContactEmail: _showContactEmail,
        showManagerPhoto: _showManagerPhoto,
      );
      if (!mounted) return;
      setState(() {
        _linkExists = true;
        _url = result['url'] as String?;
        _shortCode = result['shortCode'] as String?;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _updatePrivacy(String field, bool value) async {
    try {
      await widget.eventService.updatePublicLink(
        widget.eventId,
        showContactName: field == 'showContactName' ? value : null,
        showContactPhone: field == 'showContactPhone' ? value : null,
        showContactEmail: field == 'showContactEmail' ? value : null,
        showManagerPhoto: field == 'showManagerPhoto' ? value : null,
      );
    } catch (_) {
      // Revert on failure
      if (!mounted) return;
      setState(() {
        switch (field) {
          case 'showContactName':
            _showContactName = !value;
          case 'showContactPhone':
            _showContactPhone = !value;
          case 'showContactEmail':
            _showContactEmail = !value;
          case 'showManagerPhoto':
            _showManagerPhoto = !value;
        }
      });
    }
  }

  Future<void> _revokeLink() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.revokeLink),
        content: Text(l10n.revokeLinkConfirmation),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l10n.revokeLink),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _loading = true);
    try {
      await widget.eventService.revokePublicLink(widget.eventId);
      if (!mounted) return;
      setState(() {
        _linkExists = false;
        _url = null;
        _shortCode = null;
        _loading = false;
      });
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(l10n.linkRevoked)));
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  void _copyLink() {
    if (_url == null) return;
    Clipboard.setData(ClipboardData(text: _url!));
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.linkCopied)),
      );
  }

  void _shareLink() {
    if (_url == null) return;
    Share.share(_url!);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      decoration: const BoxDecoration(
        color: AppColors.navySpaceCadet,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Title
          Text(
            l10n.publicEventLink,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.anyoneWithLink,
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.5),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),

          if (_loading)
            const Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(color: AppColors.coralRed),
            )
          else if (_linkExists)
            _buildLinkExistsState(l10n)
          else
            _buildGenerateState(l10n),
        ],
      ),
    );
  }

  Widget _buildGenerateState(AppLocalizations l10n) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildPrivacyToggles(l10n),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _generateLink,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.coralRed,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(
              l10n.generatePublicLink,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLinkExistsState(AppLocalizations l10n) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // URL display
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Text(
            _url ?? '',
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.8),
              fontFamily: 'monospace',
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 16),

        // Action buttons row
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _copyLink,
                icon: const Icon(Icons.copy, size: 18),
                label: Text(l10n.copyLink),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.coralRed,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _shareLink,
                icon: const Icon(Icons.share, size: 18),
                label: Text(l10n.shareLink),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Privacy toggles
        _buildPrivacyToggles(l10n),
        const SizedBox(height: 16),

        // Revoke button
        TextButton(
          onPressed: _revokeLink,
          style: TextButton.styleFrom(foregroundColor: Colors.red.shade300),
          child: Text(l10n.revokeLink),
        ),
      ],
    );
  }

  Widget _buildPrivacyToggles(AppLocalizations l10n) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Text(
              l10n.privacySettings,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.5),
                letterSpacing: 0.5,
              ),
            ),
          ),
          _buildToggle(l10n.showContactName, _showContactName, (v) {
            setState(() => _showContactName = v);
            if (_linkExists) _updatePrivacy('showContactName', v);
          }),
          _buildToggle(l10n.showPhoneNumber, _showContactPhone, (v) {
            setState(() => _showContactPhone = v);
            if (_linkExists) _updatePrivacy('showContactPhone', v);
          }),
          _buildToggle(l10n.showEmail, _showContactEmail, (v) {
            setState(() => _showContactEmail = v);
            if (_linkExists) _updatePrivacy('showContactEmail', v);
          }),
          _buildToggle(l10n.showYourPhoto, _showManagerPhoto, (v) {
            setState(() => _showManagerPhoto = v);
            if (_linkExists) _updatePrivacy('showManagerPhoto', v);
          }),
        ],
      ),
    );
  }

  Widget _buildToggle(String label, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.coralRed,
          ),
        ],
      ),
    );
  }
}
