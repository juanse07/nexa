import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:nexa/l10n/app_localizations.dart';

class CreateInviteLinkDialog extends StatefulWidget {
  const CreateInviteLinkDialog({
    super.key,
    required this.teamName,
    required this.onCreateLink,
  });

  final String teamName;
  final Future<Map<String, dynamic>> Function({
    int? expiresInDays,
    int? maxUses,
    bool requireApproval,
    String? password,
  }) onCreateLink;

  @override
  State<CreateInviteLinkDialog> createState() =>
      _CreateInviteLinkDialogState();
}

class _CreateInviteLinkDialogState extends State<CreateInviteLinkDialog> {
  int _expiresInDays = 7;
  int? _maxUses;
  bool _requireApproval = false;
  final _passwordCtrl = TextEditingController();
  bool _loading = false;
  Map<String, dynamic>? _createdLink;
  String? _error;

  @override
  void dispose() {
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _createLink() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final password = _passwordCtrl.text.trim();
      final result = await widget.onCreateLink(
        expiresInDays: _expiresInDays,
        maxUses: _maxUses,
        requireApproval: _requireApproval,
        password: password.isNotEmpty ? password : null,
      );

      setState(() {
        _createdLink = result;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label copied to clipboard!')),
    );
  }

  void _shareMessage() {
    if (_createdLink == null) return;
    final l10n = AppLocalizations.of(context)!;
    final message = _createdLink!['shareableMessage'] as String?;
    if (message != null) {
      Share.share(message, subject: l10n.joinTeamSubject);
    }
  }

  void _showQrCode(BuildContext context, String deepLink, String shortCode) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Scan to join ${widget.teamName}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              QrImageView(
                data: deepLink,
                version: QrVersions.auto,
                size: 250,
                gapless: true,
              ),
              const SizedBox(height: 12),
              Text(
                l10n.codePrefix(shortCode),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l10n.close),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_createdLink != null) {
      return _buildSuccessView();
    }

    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.createInviteLinkTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.shareableLinkDescription,
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 16),

            // Expiration
            Text(
              l10n.linkExpiresIn,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            DropdownButton<int>(
              value: _expiresInDays,
              isExpanded: true,
              items: const [
                DropdownMenuItem(value: 1, child: Text('1 day')),
                DropdownMenuItem(value: 7, child: Text('7 days')),
                DropdownMenuItem(value: 30, child: Text('30 days')),
                DropdownMenuItem(value: 90, child: Text('90 days')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _expiresInDays = value);
                }
              },
            ),
            const SizedBox(height: 16),

            // Max uses
            Text(
              l10n.maxUsesOptional,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            TextField(
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: l10n.leaveEmptyUnlimited,
                border: const OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  _maxUses = int.tryParse(value);
                });
              },
            ),
            const SizedBox(height: 16),

            // Require approval
            CheckboxListTile(
              value: _requireApproval,
              onChanged: (value) {
                setState(() => _requireApproval = value ?? false);
              },
              title: Text(l10n.requireApprovalTitle),
              subtitle: Text(l10n.requireApprovalSubtitle),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
            ),
            const SizedBox(height: 8),

            // Password protection
            Text(
              l10n.passwordOptionalLabel,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            TextField(
              controller: _passwordCtrl,
              obscureText: true,
              decoration: InputDecoration(
                hintText: l10n.leaveEmptyNoPassword,
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.lock_outline),
              ),
            ),

            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        ElevatedButton(
          onPressed: _loading ? null : _createLink,
          child: _loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.createLinkButton),
        ),
      ],
    );
  }

  Widget _buildSuccessView() {
    final l10n = AppLocalizations.of(context)!;
    final shortCode = _createdLink!['shortCode'] as String;
    final deepLink = _createdLink!['deepLink'] as String;
    final shareableMessage = _createdLink!['shareableMessage'] as String;
    final expiresAt = _createdLink!['expiresAt'] as String?;

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.green),
          const SizedBox(width: 8),
          Text(l10n.inviteLinkCreatedTitle),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Short Code
            Text(
              l10n.inviteCodeLabel,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    shortCode,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy),
                    onPressed: () => _copyToClipboard(shortCode, l10n.inviteCodeLabel),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Deep Link
            Text(
              l10n.deepLinkLabel,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.shareDeepLinkHint,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      deepLink,
                      style: const TextStyle(fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy),
                    onPressed: () => _copyToClipboard(deepLink, l10n.deepLinkLabel),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Expiration
            if (expiresAt != null) ...[
              Text(
                l10n.expiresDate(_formatDate(expiresAt)),
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 8),
            ],

            // Share & QR buttons
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.share),
                label: Text(l10n.shareViaApps),
                onPressed: _shareMessage,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.qr_code),
                label: Text(l10n.showQrCode),
                onPressed: () => _showQrCode(context, deepLink, shortCode),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(l10n.done),
        ),
      ],
    );
  }

  String _formatDate(String isoDate) {
    try {
      final date = DateTime.parse(isoDate);
      final month = date.month.toString().padLeft(2, '0');
      final day = date.day.toString().padLeft(2, '0');
      final hour = date.hour.toString().padLeft(2, '0');
      final minute = date.minute.toString().padLeft(2, '0');
      return '$month/$day/${date.year} at $hour:$minute';
    } catch (_) {
      return isoDate;
    }
  }
}
