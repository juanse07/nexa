# Chat System - User Guide

Complete guide on how to use the chat interface for both managers and staff.

---

## 🎯 Quick Access

Before you can use chat, you need to add navigation to access it in your app.

### For Manager App

Add a chat button/tab to your manager dashboard. Here are the best locations:

#### Option 1: Add to Main Navigation/Drawer

Find your main navigation file (likely `lib/main.dart` or where you have your dashboard) and add:

```dart
import 'package:nexa/features/chat/presentation/conversations_screen.dart';

// In your drawer or menu:
ListTile(
  leading: const Icon(Icons.chat_bubble),
  title: const Text('Messages'),
  trailing: _unreadCount > 0
    ? CircleAvatar(
        radius: 10,
        child: Text('$_unreadCount', style: TextStyle(fontSize: 10)),
      )
    : null,
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ConversationsScreen()),
    );
  },
),
```

#### Option 2: Add Floating Action Button

```dart
import 'package:nexa/features/chat/presentation/conversations_screen.dart';

// In your Scaffold:
floatingActionButton: FloatingActionButton(
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ConversationsScreen()),
    );
  },
  child: const Icon(Icons.chat),
  tooltip: 'Messages',
),
```

### For Staff App

Add to your `root_page.dart`:

```dart
import 'pages/conversations_page.dart';

// If you have bottom navigation, add this item:
BottomNavigationBarItem(
  icon: Icon(Icons.chat_bubble_outline),
  activeIcon: Icon(Icons.chat_bubble),
  label: 'Messages',
),

// In your page/screen builder:
case 3: // Or whatever index you want
  return const ConversationsPage();
```

---

## 📱 How to Use Chat - Manager Side

### Starting a Conversation

1. **Open the Chat Screen:**
   - Tap the "Messages" button/icon you added to your navigation
   - You'll see the **Conversations List**

2. **Choose a User to Message:**

   **Method A - From Conversations List:**
   - If you've chatted with a user before, tap their conversation
   - You'll see your message history

   **Method B - Start a New Chat:**
   - Since managers can message any user in their teams, you need to start from a user context
   - Best practice: Add a "Message" button when viewing user/team details

   Example implementation:
   ```dart
   import 'package:nexa/features/chat/presentation/chat_screen.dart';

   // When viewing a user's profile or in a user list:
   IconButton(
     icon: const Icon(Icons.chat_bubble_outline),
     onPressed: () {
       Navigator.push(
         context,
         MaterialPageRoute(
           builder: (_) => ChatScreen(
             targetId: user['userKey'], // e.g., "google:123456"
             targetName: user['name'],
             targetPicture: user['picture'],
           ),
         ),
       );
     },
   )
   ```

### Sending Messages

1. **Type Your Message:**
   - Tap the text input field at the bottom
   - Type your message (up to 5000 characters)
   - The text field expands for multi-line messages

2. **Send:**
   - Press the blue send button (➤) on the right
   - Or press Enter/Return on your keyboard
   - Your message appears immediately in a blue bubble on the right

3. **Wait for Reply:**
   - User's messages appear in gray bubbles on the left
   - Messages arrive in real-time (no refresh needed!)
   - You'll see "typing..." when they're composing a reply

### Reading Messages

- **Blue bubbles (right side)** = Your messages
- **Gray bubbles (left side)** = User's messages
- Each message shows:
  - Sender name (for user messages)
  - Message content
  - Time sent (e.g., "2:30 PM")
- Date dividers show "Today", "Yesterday", or specific dates

### Managing Conversations

- **Pull down** to refresh the conversations list
- **Unread badges** show how many unread messages you have
- **Last message preview** shows in the conversation list
- **Auto-mark as read** when you open a conversation

---

## 📱 How to Use Chat - Staff Side

### Accessing Messages

1. **Open the Messages Tab:**
   - Tap the "Messages" icon in your bottom navigation
   - Or wherever you added the chat navigation

2. **View Your Conversations:**
   - You'll see conversations with your manager(s)
   - Each shows:
     - Manager's name and photo
     - Last message preview
     - Time of last message
     - Unread count badge (if any)

### Replying to Your Manager

1. **Open a Conversation:**
   - Tap on a conversation from the list
   - You'll see the full message history

2. **Type and Send:**
   - Tap the text input at the bottom
   - Type your reply
   - Press the send button (➤)
   - Your message appears in a blue bubble

3. **Real-time Updates:**
   - Manager's messages arrive instantly
   - No need to refresh!
   - See "typing..." when manager is typing

### Starting a New Conversation

If you need to message your manager first:

```dart
import 'pages/chat_page.dart';
import 'services/chat_service.dart';

// Add this button somewhere (e.g., in settings or help):
ElevatedButton(
  onPressed: () async {
    // Fetch your managers
    final managers = await ChatService().fetchManagers();

    if (managers.isEmpty) {
      // Show error: No managers found
      return;
    }

    final manager = managers.first; // Or let user pick if multiple

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatPage(
          managerId: manager['id'],
          managerName: manager['name'],
          managerPicture: manager['picture'],
        ),
      ),
    );
  },
  child: const Text('Contact Manager'),
)
```

---

## 🎨 Understanding the Interface

### Conversations List Screen

```
┌─────────────────────────────────┐
│  ← Messages              [?]    │  ← Header
├─────────────────────────────────┤
│  👤 John Manager         2h ago │  ← Conversation tile
│     Hello, are you available... │     with preview
│                             [3] │  ← Unread badge
├─────────────────────────────────┤
│  👤 Sarah Manager        1d ago │
│     Great work today!           │
├─────────────────────────────────┤
│  👤 Mike Manager         3d ago │
│     Can you work tomorrow?      │
└─────────────────────────────────┘
```

### Chat Screen

```
┌─────────────────────────────────┐
│  ← 👤 John Manager              │  ← Header with avatar
│     typing...                   │  ← Typing indicator
├─────────────────────────────────┤
│         ─── Today ───           │  ← Date divider
│                                 │
│  👤  Hello, are you          │  ← Manager's message
│      available tomorrow?     │     (gray, left)
│      2:30 PM                 │
│                                 │
│              Yes, I can work  👤│  ← Your message
│              What time?        │     (blue, right)
│              2:35 PM           │
│                                 │
├─────────────────────────────────┤
│  [  Type a message...      ] [➤]│  ← Input + send button
└─────────────────────────────────┘
```

---

## 💡 Tips & Tricks

### For Managers

1. **Quick Message from User List:**
   Add a chat icon next to each user's name in your team list for quick access

2. **Message Multiple Users:**
   You can have separate conversations with each team member

3. **Track Unread:**
   Red badges show how many unread messages you have per conversation

4. **Search Conversations:**
   Pull down to refresh and see latest messages at the top

### For Staff

1. **Notification Badge:**
   Look for the red badge on the Messages tab to see unread count

2. **Quick Reply:**
   Messages are auto-marked as read when you open them

3. **Multiple Managers:**
   If you're on multiple teams, you'll have separate chats with each manager

4. **Pull to Refresh:**
   Swipe down on conversations list to check for updates

---

## 🔧 Practical Examples

### Example 1: Manager Checking Availability

**Manager (sends):**
```
"Hi Maria, can you work this Saturday?"
```

**Staff (receives notification, replies):**
```
"Yes, what time do you need me?"
```

**Manager:**
```
"9 AM to 5 PM at the downtown location"
```

**Staff:**
```
"Perfect, I'll be there!"
```

### Example 2: Staff Asking for Schedule

**Staff (starts chat):**
```
"Hi, could you send me next week's schedule?"
```

**Manager (gets notification, replies):**
```
"Sure! I'll send it by end of day"
```

### Example 3: Quick Update

**Manager (sends to entire team individually):**
```
"Reminder: Team meeting tomorrow at 10 AM"
```

**Staff (acknowledges):**
```
"Got it, thanks!"
```

---

## 📊 Features Overview

| Feature | Manager | Staff |
|---------|---------|-------|
| Send messages | ✅ | ✅ |
| Receive real-time | ✅ | ✅ |
| See typing indicator | ✅ | ✅ |
| Unread count | ✅ | ✅ |
| Message history | ✅ | ✅ |
| Profile pictures | ✅ | ✅ |
| Time stamps | ✅ | ✅ |
| Date dividers | ✅ | ✅ |
| Pull to refresh | ✅ | ✅ |
| Auto mark as read | ✅ | ✅ |

---

## 🚨 Common Questions

### Q: How do I know if someone read my message?
**A:** Currently, messages are marked as read when the conversation is opened. We don't show "read receipts" yet, but this can be added.

### Q: Can I send images or files?
**A:** Not yet! Currently only text messages (up to 5000 characters). File sharing can be added in the future.

### Q: How far back can I see messages?
**A:** All message history is saved. The app loads the most recent 50 messages, with pagination for older messages (scroll up to load more).

### Q: What if I'm offline?
**A:** Messages sent while offline will fail. You need an internet connection to send/receive. Consider adding offline queuing in the future.

### Q: Can I delete messages?
**A:** Not currently. Once sent, messages cannot be edited or deleted. This is a safety feature for record-keeping.

### Q: Can I message multiple people at once?
**A:** No, conversations are one-on-one between manager and staff. For team announcements, use the events system.

### Q: Are messages encrypted?
**A:** Messages are sent over HTTPS and stored securely in the database. They are not end-to-end encrypted currently.

---

## 🎯 Best Practices

### For Managers:
- ✅ Keep messages professional
- ✅ Respond within 24 hours
- ✅ Use for quick coordination
- ✅ For important scheduling, also use events system
- ❌ Don't use for sensitive/confidential info
- ❌ Don't spam messages

### For Staff:
- ✅ Check messages regularly
- ✅ Respond promptly
- ✅ Be respectful and professional
- ✅ Ask questions if unclear
- ❌ Don't use for emergencies (call instead)
- ❌ Don't message multiple times without waiting for reply

---

## 📱 Screenshot Examples (To Be Added)

When testing, you can take screenshots of:
1. Conversations list with unread badges
2. Chat screen showing message exchange
3. Typing indicator in action
4. Empty state screens

---

## 🎓 Quick Start Checklist

### First Time Setup (Manager):
- [ ] Add chat navigation to your app
- [ ] Test by finding a user
- [ ] Add "Message" button to user profiles
- [ ] Send your first message
- [ ] Verify real-time delivery

### First Time Setup (Staff):
- [ ] Add chat tab to bottom navigation
- [ ] Enable socket listener in data_service.dart
- [ ] Wait for manager to message you
- [ ] Or add "Contact Manager" button
- [ ] Reply to test real-time

---

**Need Help?**
Check the technical documentation:
- Managers: See `CHAT_IMPLEMENTATION.md`
- Staff: See `CHAT_INTEGRATION_GUIDE.md`

**Version:** 1.0.0
**Last Updated:** January 17, 2025
