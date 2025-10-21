import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

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
  }) onCreateLink;

  @override
  State<CreateInviteLinkDialog> createState() =>
      _CreateInviteLinkDialogState();
}

class _CreateInviteLinkDialogState extends State<CreateInviteLinkDialog> {
  int _expiresInDays = 7;
  int? _maxUses;
  bool _requireApproval = false;
  bool _loading = false;
  Map<String, dynamic>? _createdLink;
  String? _error;

  Future<void> _createLink() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await widget.onCreateLink(
        expiresInDays: _expiresInDays,
        maxUses: _maxUses,
        requireApproval: _requireApproval,
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
    final message = _createdLink!['shareableMessage'] as String?;
    if (message != null) {
      Share.share(message, subject: 'Join my team on Nexa');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_createdLink != null) {
      return _buildSuccessView();
    }

    return AlertDialog(
      title: const Text('Create Invite Link'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Create a shareable link that anyone can use to join your team.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 16),

            // Expiration
            const Text(
              'Link expires in:',
              style: TextStyle(fontWeight: FontWeight.bold),
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
            const Text(
              'Max uses (optional):',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            TextField(
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                hintText: 'Leave empty for unlimited',
                border: OutlineInputBorder(),
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
              title: const Text('Require approval'),
              subtitle: const Text('You must approve members after they join'),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
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
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _loading ? null : _createLink,
          child: _loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Create Link'),
        ),
      ],
    );
  }

  Widget _buildSuccessView() {
    final shortCode = _createdLink!['shortCode'] as String;
    final deepLink = _createdLink!['deepLink'] as String;
    final shareableMessage = _createdLink!['shareableMessage'] as String;
    final expiresAt = _createdLink!['expiresAt'] as String?;

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.check_circle, color: Colors.green),
          SizedBox(width: 8),
          Text('Invite Link Created!'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Short Code
            const Text(
              'Invite Code:',
              style: TextStyle(fontWeight: FontWeight.bold),
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
                    onPressed: () => _copyToClipboard(shortCode, 'Invite code'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Deep Link
            const Text(
              'Deep Link:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              'Share this link - it will open the app automatically',
              style: TextStyle(fontSize: 12, color: Colors.grey),
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
                    onPressed: () => _copyToClipboard(deepLink, 'Deep link'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Expiration
            if (expiresAt != null) ...[
              Text(
                'Expires: ${_formatDate(expiresAt)}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 8),
            ],

            // Share button
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.share),
                label: const Text('Share via WhatsApp, SMS, etc.'),
                onPressed: _shareMessage,
                style: ElevatedButton.styleFrom(
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
          child: const Text('Done'),
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
