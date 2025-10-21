# Frontend Implementation: Shareable Invite Links

## Overview

You need to add UI in your **manager app** to create and share invite links. The backend is ready - you just need to build the Flutter screens.

---

## Current State vs What You Need

### What You Have (OLD System):
- ❌ Email-based invites (lines 78-100 in `team_detail_page.dart`)
- ❌ Calls `/teams/:teamId/invites` (targeted invites)
- ❌ Requires knowing user's email upfront

### What You Need (NEW System):
- ✅ Shareable link invites
- ✅ Calls `/teams/:teamId/invites/create-link` (shareable links)
- ✅ Works for anyone - no email needed
- ✅ Deep links that open the app

---

## Step 1: Add New Methods to TeamsService

**File:** `lib/features/teams/data/services/teams_service.dart`

Add these methods after line 201:

```dart
/// Create a shareable invite link for a team
Future<Map<String, dynamic>> createInviteLink({
  required String teamId,
  int? expiresInDays,
  int? maxUses,
  bool requireApproval = false,
}) async {
  try {
    final response = await _apiClient.post(
      '/teams/$teamId/invites/create-link',
      data: {
        if (expiresInDays != null) 'expiresInDays': expiresInDays,
        if (maxUses != null) 'maxUses': maxUses,
        'requireApproval': requireApproval,
      },
    );
    if (_isSuccess(response.statusCode)) {
      return Map<String, dynamic>.from(response.data as Map);
    }
    throw Exception('Failed to create invite link (${response.statusCode})');
  } on DioException catch (e) {
    throw Exception('Failed to create invite link: ${e.message}');
  }
}

/// Fetch all shareable invite links for a team
Future<List<Map<String, dynamic>>> fetchInviteLinks(String teamId) async {
  try {
    final response = await _apiClient.get('/teams/$teamId/invites/links');
    if (_isSuccess(response.statusCode)) {
      final dynamic data = response.data;
      if (data is Map<String, dynamic>) {
        final dynamic invites = data['invites'];
        if (invites is List) {
          return invites.whereType<Map<String, dynamic>>().toList(
            growable: false,
          );
        }
      }
      return const <Map<String, dynamic>>[];
    }
    throw Exception('Failed to fetch invite links (${response.statusCode})');
  } on DioException catch (e) {
    throw Exception('Failed to fetch invite links: ${e.message}');
  }
}
```

---

## Step 2: Create Invite Link Dialog UI

**File:** `lib/features/teams/presentation/widgets/create_invite_link_dialog.dart`

Create this new file:

```dart
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
  State<CreateInviteLinkDialog> createState() => _CreateInviteLinkDialogState();
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
            const Text('Link expires in:', style: TextStyle(fontWeight: FontWeight.bold)),
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
            const Text('Max uses:', style: TextStyle(fontWeight: FontWeight.bold)),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      hintText: 'Unlimited',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _maxUses = int.tryParse(value);
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                const Text('(leave empty for unlimited)', style: TextStyle(fontSize: 12, color: Colors.grey)),
              ],
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
      title: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.green),
          const SizedBox(width: 8),
          const Text('Invite Link Created!'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Short Code
            const Text('Invite Code:', style: TextStyle(fontWeight: FontWeight.bold)),
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
            const Text('Deep Link:', style: TextStyle(fontWeight: FontWeight.bold)),
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
                border: Border.all(color: Colors.blue[200]!),
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
      return '${date.month}/${date.day}/${date.year} at ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return isoDate;
    }
  }
}
```

---

## Step 3: Update Team Detail Page

**File:** `lib/features/teams/presentation/pages/team_detail_page.dart`

### 3a. Add to imports (top of file):
```dart
import 'package:nexa/features/teams/presentation/widgets/create_invite_link_dialog.dart';
```

### 3b. Add new method after `_sendInvite()` (around line 150):

```dart
Future<void> _createInviteLink() async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => CreateInviteLinkDialog(
      teamName: widget.teamName,
      onCreateLink: ({
        int? expiresInDays,
        int? maxUses,
        bool requireApproval = false,
      }) async {
        return await _teamsService.createInviteLink(
          teamId: widget.teamId,
          expiresInDays: expiresInDays,
          maxUses: maxUses,
          requireApproval: requireApproval,
        );
      },
    ),
  );

  if (result == true && mounted) {
    // Refresh data to show new invite in the list
    await _loadData();
  }
}
```

### 3c. Replace the "+ Add member" button with "+ Create Invite Link"

Find the button around line 170-180 and replace with:

```dart
// Replace the old button with this:
ElevatedButton.icon(
  icon: const Icon(Icons.add_link),
  label: const Text('Create Invite Link'),
  onPressed: _createInviteLink,
  style: ElevatedButton.styleFrom(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  ),
),
```

---

## Step 4: Add share_plus Package

**File:** `pubspec.yaml`

Add to dependencies:

```yaml
dependencies:
  flutter:
    sdk: flutter
  # ... your existing dependencies
  share_plus: ^7.2.2  # Add this line
```

Then run:
```bash
flutter pub get
```

---

## Step 5: Display Active Invite Links

In `team_detail_page.dart`, update the `_loadData()` method to fetch both old invites AND new invite links:

```dart
Future<void> _loadData() async {
  setState(() {
    _loading = true;
    _error = null;
  });
  try {
    final results = await Future.wait([
      _teamsService.fetchMembers(widget.teamId),
      _teamsService.fetchInvites(widget.teamId),  // Old email invites
      _teamsService.fetchInviteLinks(widget.teamId),  // New shareable links
    ]);
    setState(() {
      _members = results[0];
      _invites = results[1];
      _inviteLinks = results[2];  // Add this field to state
      _loading = false;
    });
  } catch (e) {
    setState(() {
      _error = e.toString();
      _loading = false;
    });
  }
}
```

Add to state variables (around line 26):
```dart
List<Map<String, dynamic>> _inviteLinks = const [];
```

Then display them in the UI:

```dart
// Add after the existing invites section
if (_inviteLinks.isNotEmpty) ...[
  const SizedBox(height: 16),
  const Text('Active Invite Links', style: TextStyle(fontWeight: FontWeight.bold)),
  const SizedBox(height: 8),
  ..._inviteLinks.map((link) {
    final shortCode = link['shortCode'] as String;
    final usedCount = link['usedCount'] as int? ?? 0;
    final maxUses = link['maxUses'] as int?;
    final status = link['status'] as String;

    return Card(
      child: ListTile(
        leading: const Icon(Icons.link),
        title: Text('Code: $shortCode'),
        subtitle: Text(
          maxUses != null
              ? 'Used: $usedCount / $maxUses • Status: $status'
              : 'Used: $usedCount (unlimited) • Status: $status',
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete),
          onPressed: () => _cancelInviteLink(link['id'] as String),
        ),
      ),
    );
  }).toList(),
],
```

---

## How It Works (User Flow)

### Manager Creates Invite Link:

1. Manager opens Team Detail screen
2. Taps **"Create Invite Link"** button
3. Dialog appears with options:
   - **Expires in:** 1, 7, 30, or 90 days
   - **Max uses:** Optional limit
   - **Require approval:** Checkbox
4. Taps **"Create Link"**
5. Success screen shows:
   - **Invite Code:** `ABC123` (copy button)
   - **Deep Link:** `nexaapp://invite/ABC123` (copy button)
   - **Share button:** Opens WhatsApp/SMS/Email
6. Manager shares via:
   - WhatsApp: Tap share → Select WhatsApp
   - SMS: Tap share → Select Messages
   - Copy link manually

### Staff Member Joins:

#### If App Installed:
1. Receives link via WhatsApp/SMS
2. Taps `nexaapp://invite/ABC123`
3. App opens automatically
4. Shows invite preview with team details
5. Taps "Accept"
6. Joins team instantly!

#### If App NOT Installed:
1. Receives message: "Download Nexa and enter code: ABC123"
2. Downloads app from App Store
3. Opens app and signs in
4. Sees "Have an invite code?" prompt
5. Enters `ABC123`
6. Joins team!

---

## UI Screenshots (What You'll See)

### Create Invite Dialog:
```
┌──────────────────────────────────────┐
│  Create Invite Link          [×]     │
├──────────────────────────────────────┤
│                                      │
│  Create a shareable link that        │
│  anyone can use to join your team.   │
│                                      │
│  Link expires in:                    │
│  [7 days                  ▼]         │
│                                      │
│  Max uses:                           │
│  [___________] (leave empty)         │
│                                      │
│  ☐ Require approval                  │
│    You must approve members          │
│    after they join                   │
│                                      │
│              [Cancel] [Create Link]  │
└──────────────────────────────────────┘
```

### Success Screen:
```
┌──────────────────────────────────────┐
│  ✅ Invite Link Created!      [×]    │
├──────────────────────────────────────┤
│                                      │
│  Invite Code:                        │
│  ┌────────────────────────────────┐ │
│  │  ABC123              📋       │ │
│  └────────────────────────────────┘ │
│                                      │
│  Deep Link:                          │
│  Share this link - it will open     │
│  the app automatically               │
│  ┌────────────────────────────────┐ │
│  │  nexaapp://invite/ABC123  📋  │ │
│  └────────────────────────────────┘ │
│                                      │
│  Expires: 10/28/2024 at 13:15       │
│                                      │
│  [🔗 Share via WhatsApp, SMS, etc.] │
│                                      │
│                           [Done]     │
└──────────────────────────────────────┘
```

---

## Testing

### Test Step 1: Create Link
```bash
# In your Flutter app:
1. Navigate to Teams screen
2. Select a team
3. Tap "Create Invite Link"
4. Set expiration to 7 days
5. Tap "Create Link"
6. Should see success screen with code
```

### Test Step 2: Share
```bash
1. Tap "Share via WhatsApp..."
2. Select WhatsApp contact
3. Message should contain:
   - Deep link
   - Invite code
   - Instructions
```

### Test Step 3: Join (Different Device)
```bash
1. On another device, tap the deep link
2. Should open app (if installed)
3. Shows team preview
4. Tap "Accept"
5. Check original device - member should appear
```

---

## Summary

### Files to Create:
1. ✅ `lib/features/teams/presentation/widgets/create_invite_link_dialog.dart` - Dialog UI
2. ✅ Update `lib/features/teams/data/services/teams_service.dart` - Add API methods
3. ✅ Update `lib/features/teams/presentation/pages/team_detail_page.dart` - Add button & logic
4. ✅ Update `pubspec.yaml` - Add `share_plus` package

### What You Get:
- ✅ "Create Invite Link" button in Teams screen
- ✅ Professional dialog with options
- ✅ Success screen with copyable code & link
- ✅ Share button for WhatsApp/SMS
- ✅ List of active invite links
- ✅ Works with your existing backend

### Next Steps:
1. Copy the code above into your Flutter project
2. Run `flutter pub get`
3. Test creating an invite link
4. Share it via WhatsApp to yourself
5. Test joining from staff app (you'll need to implement the redeem screen next)

Let me know when you're ready and I can help with the staff app side (redeeming invites)!
