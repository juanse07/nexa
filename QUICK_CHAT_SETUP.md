# Quick Chat Setup - Copy & Paste Guide

This is the fastest way to add chat navigation to your apps. Just copy and paste these snippets!

---

## 🚀 Manager App - Quick Setup

### Option 1: Add Chat Button to User Profiles

When viewing a team member or user details, add a chat button:

```dart
import 'package:flutter/material.dart';
import 'features/chat/presentation/chat_screen.dart';

// In your user profile/detail screen:
IconButton(
  icon: const Icon(Icons.chat_bubble_outline),
  tooltip: 'Message User',
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          targetId: userKey,        // e.g., "google:123456"
          targetName: userName,      // e.g., "John Doe"
          targetPicture: userPicture, // e.g., "https://..."
        ),
      ),
    );
  },
)
```

### Option 2: Add "Messages" to Main Menu/Drawer

```dart
import 'package:flutter/material.dart';
import 'features/chat/presentation/conversations_screen.dart';

// In your Drawer widget:
ListTile(
  leading: const Icon(Icons.chat_bubble),
  title: const Text('Messages'),
  onTap: () {
    Navigator.pop(context); // Close drawer
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ConversationsScreen(),
      ),
    );
  },
),
```

### Option 3: Add Floating Action Button

```dart
import 'package:flutter/material.dart';
import 'features/chat/presentation/conversations_screen.dart';

// In your Scaffold:
Scaffold(
  // ... other properties
  floatingActionButton: FloatingActionButton(
    onPressed: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const ConversationsScreen(),
        ),
      );
    },
    child: const Icon(Icons.chat),
    tooltip: 'Messages',
  ),
)
```

---

## 📱 Staff App - Quick Setup

### Step 1: Add to Bottom Navigation

Edit your `lib/pages/root_page.dart`:

```dart
import 'package:flutter/material.dart';
import 'conversations_page.dart'; // Add this import

class RootPage extends StatefulWidget {
  const RootPage({super.key});

  @override
  State<RootPage> createState() => _RootPageState();
}

class _RootPageState extends State<RootPage> {
  int _currentIndex = 0;

  // Add ConversationsPage to your pages list
  final List<Widget> _pages = [
    // ... your existing pages (e.g., HomePage, EventsPage, etc.)
    const ConversationsPage(), // ADD THIS
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        items: const [
          // ... your existing items

          // ADD THIS:
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            activeIcon: Icon(Icons.chat_bubble),
            label: 'Messages',
          ),
        ],
      ),
    );
  }
}
```

### Step 2: Enable Real-time Messages

Edit your `lib/services/data_service.dart`:

Find the `_initSocket()` method (around line 200-300) and add this listener with your other `socket.on()` calls:

```dart
import '../services/chat_service.dart'; // Add this import at top

// In _initSocket() method, add this with other socket listeners:
_socket?.on('chat:message', (data) {
  debugPrint('📨 Received chat message');
  try {
    if (data is Map<String, dynamic>) {
      ChatService().handleIncomingMessage(data);
    }
  } catch (e) {
    debugPrint('Error handling chat message: $e');
  }
});
```

**That's it!** Run your app and the Messages tab will appear.

---

## 🎯 Complete Example - Staff Root Page

Here's a complete example with 4 tabs including Messages:

```dart
import 'package:flutter/material.dart';
import 'conversations_page.dart';
import 'event_detail_page.dart';
import 'past_events_page.dart';
import 'user_profile_page.dart';

class RootPage extends StatefulWidget {
  const RootPage({super.key});

  @override
  State<RootPage> createState() => _RootPageState();
}

class _RootPageState extends State<RootPage> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const EventDetailPage(),      // Home/Events
    const PastEventsPage(),        // History
    const ConversationsPage(),     // Messages (NEW!)
    const UserProfilePage(),       // Profile
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Theme.of(context).primaryColor,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.event),
            label: 'Events',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'History',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            activeIcon: Icon(Icons.chat_bubble),
            label: 'Messages',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
```

---

## 💬 Testing the Chat

### Test Flow (Manager → Staff):

1. **Manager App:**
   ```
   1. Find a user in your team
   2. Tap the chat icon next to their name
   3. Type: "Hello, test message"
   4. Press send
   ```

2. **Staff App:**
   ```
   1. Open the Messages tab
   2. You should see the conversation appear
   3. Tap it to open
   4. See manager's message
   5. Reply: "Got it, thanks!"
   ```

3. **Manager App:**
   ```
   1. See the reply appear in real-time!
   2. No refresh needed ✨
   ```

### Test Checklist:

- [ ] Manager can see conversations list
- [ ] Manager can send message to user
- [ ] Staff receives message in real-time
- [ ] Staff can reply
- [ ] Manager receives reply in real-time
- [ ] Unread count shows correctly
- [ ] Messages marked as read when opened
- [ ] Pull-to-refresh works
- [ ] Typing indicators work (if enabled)

---

## 🎨 Customization

### Change Chat Bubble Color

Both apps use your theme's primary color. To customize:

```dart
// In your main.dart or app.dart:
MaterialApp(
  theme: ThemeData(
    primaryColor: Colors.blue, // Change this!
    colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
  ),
  // ...
)
```

### Add Unread Badge to Navigation

For staff app, add badge to Messages tab:

```dart
import 'package:flutter/material.dart';
import '../services/chat_service.dart';

class RootPage extends StatefulWidget {
  // ...
}

class _RootPageState extends State<RootPage> {
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _loadUnreadCount();

    // Listen for new messages
    ChatService().messageStream.listen((_) {
      _loadUnreadCount();
    });
  }

  Future<void> _loadUnreadCount() async {
    try {
      final conversations = await ChatService().fetchConversations();
      final total = conversations.fold<int>(
        0,
        (sum, conv) => sum + conv.unreadCount,
      );
      if (mounted) setState(() => _unreadCount = total);
    } catch (e) {
      // Ignore errors
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: BottomNavigationBar(
        items: [
          // ... other items
          BottomNavigationBarItem(
            icon: Badge(
              label: Text('$_unreadCount'),
              isLabelVisible: _unreadCount > 0,
              child: const Icon(Icons.chat_bubble_outline),
            ),
            label: 'Messages',
          ),
        ],
        // ...
      ),
    );
  }
}
```

---

## 🔍 Where to Add Chat Icon in Manager App

### 1. In Team Members List

```dart
// In your team members ListView:
ListView.builder(
  itemBuilder: (context, index) {
    final member = teamMembers[index];
    return ListTile(
      leading: CircleAvatar(/* ... */),
      title: Text(member['name']),
      trailing: IconButton(
        icon: const Icon(Icons.chat_bubble_outline),
        onPressed: () => _openChat(member),
      ),
    );
  },
);

void _openChat(Map<String, dynamic> member) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => ChatScreen(
        targetId: member['userKey'],
        targetName: member['name'],
        targetPicture: member['picture'],
      ),
    ),
  );
}
```

### 2. In User Profile Screen

```dart
// At the top of user profile:
AppBar(
  title: Text(userName),
  actions: [
    IconButton(
      icon: const Icon(Icons.chat),
      onPressed: () => _openChat(),
    ),
  ],
)
```

### 3. In Dashboard

```dart
// As a card/tile in your dashboard:
Card(
  child: ListTile(
    leading: const Icon(Icons.chat_bubble, size: 32),
    title: const Text('Messages'),
    subtitle: Text('$unreadCount unread'),
    trailing: const Icon(Icons.arrow_forward_ios),
    onTap: () => Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ConversationsScreen(),
      ),
    ),
  ),
)
```

---

## 📱 Final Checklist

### Manager App:
- [ ] Import chat screens
- [ ] Add navigation (choose one method above)
- [ ] Test by finding a user
- [ ] Send first message
- [ ] Verify it sends

### Staff App:
- [ ] Add `ConversationsPage` to navigation
- [ ] Add socket listener in `data_service.dart`
- [ ] Run the app
- [ ] Check Messages tab appears
- [ ] Wait for/request manager to send message
- [ ] Verify real-time delivery

---

## 🆘 Quick Troubleshooting

### "Page not found" error
- Check your imports are correct
- Verify file paths match your project structure

### Messages don't appear
- Check backend is running
- Verify API_BASE_URL in .env
- Check socket is connected (logs in data_service.dart)

### Can't send messages
- Verify you're logged in
- Check JWT token is valid
- Ensure user/manager exists

### App crashes
- Run `flutter pub get` to ensure dependencies
- Check for typos in code
- Verify all imports are correct

---

**That's it!** With these snippets, you should have a working chat system in minutes.

For detailed explanations, see:
- `CHAT_IMPLEMENTATION.md` - Technical details
- `CHAT_USER_GUIDE.md` - How to use the interface
- `CHAT_INTEGRATION_GUIDE.md` (Staff app) - Full integration guide
