import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../data/services/chat_service.dart';
import '../domain/entities/conversation.dart';
import 'chat_screen.dart';
import '../../extraction/presentation/ai_chat_screen.dart';
import 'package:nexa/shared/presentation/theme/app_colors.dart';
import 'package:nexa/shared/widgets/initials_avatar.dart';
import 'package:nexa/shared/widgets/tappable_app_title.dart';
import 'package:nexa/shared/widgets/web_content_wrapper.dart';

class ConversationsScreen extends StatefulWidget {
  const ConversationsScreen({super.key});

  @override
  State<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen> {
  final ChatService _chatService = ChatService();
  final TextEditingController _searchController = TextEditingController();
  List<Conversation> _conversations = <Conversation>[];
  List<Conversation> _filteredConversations = <Conversation>[];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadConversations();
    _listenToNewMessages();
    _searchController.addListener(_filterConversations);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterConversations() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      if (query.isEmpty) {
        _filteredConversations = _conversations;
      } else {
        _filteredConversations = _conversations.where((c) {
          return c.displayName.toLowerCase().contains(query) ||
              (c.lastMessagePreview ?? '').toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  void _listenToNewMessages() {
    _chatService.messageStream.listen((message) {
      // Refresh conversations when a new message arrives
      _loadConversations();
    });
  }

  Future<void> _loadConversations() async {
    try {
      setState(() {
        _loading = true;
        _error = null;
      });

      final conversations = await _chatService.fetchConversations();

      setState(() {
        _conversations = conversations;
        _filteredConversations = conversations;
        _loading = false;
      });
      _filterConversations();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: Scaffold(
            backgroundColor: AppColors.surfaceLight,
            appBar: AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              title: TappableAppTitle.text(
                'Chats',
                style: const TextStyle(
                  color: AppColors.charcoal,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
              iconTheme: const IconThemeData(color: AppColors.charcoal),
            ),
            body: WebContentWrapper.list(
              child: Column(
                children: [
                  // Search bar
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search conversations...',
                        hintStyle: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                        ),
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          color: Colors.grey.shade400,
                          size: 22,
                        ),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.close, color: Colors.grey.shade400, size: 20),
                                onPressed: () {
                                  _searchController.clear();
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFF1A1A2E), width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                    ),
                  ),
                  Expanded(child: _buildBody()),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 100,
          right: 16,
          child: FloatingActionButton(
            onPressed: _showContactPicker,
            backgroundColor: const Color(0xFF1A1A2E),
            elevation: 4,
            child: const Icon(Icons.add_comment_rounded, color: Color(0xFFDAA520), size: 24),
          ),
        ),
      ],
    );
  }

  void _showContactPicker() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ContactPickerSheet(
        onContactSelected: (contact) {
          Navigator.pop(context);
          _openNewChat(contact);
        },
      ),
    );
  }

  void _openNewChat(Map<String, dynamic> contact) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ChatScreen(
          targetId: contact['userKey'] as String,
          targetName: contact['name'] as String? ?? 'Unknown',
          targetPicture: contact['picture'] as String?,
        ),
      ),
    ).then((_) => _loadConversations());
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(Icons.error_outline, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Failed to load conversations',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _loadConversations,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final isSearching = _searchController.text.trim().isNotEmpty;

    if (_filteredConversations.isEmpty && !isSearching) {
      // Still show Valerio Assistant even when empty
      return RefreshIndicator(
        onRefresh: _loadConversations,
        child: ListView(
          children: <Widget>[
            _AIChatTile(
              onTap: () => _openAIChat(),
            ),
            const Divider(height: 1),
            const SizedBox(height: 40),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                children: <Widget>[
                  Image.asset(
                    'assets/chat_placeholder.png',
                    height: 260,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'No conversations yet',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.charcoal,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Start chatting with your team to see your messages here',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 14,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadConversations,
      child: ListView.separated(
        itemCount: _filteredConversations.length + (isSearching ? 0 : 1), // +1 for Valerio Assistant (hidden when searching)
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          if (!isSearching) {
            // First item is always the pinned Valerio Assistant
            if (index == 0) {
              return _AIChatTile(
                onTap: () => _openAIChat(),
              );
            }
            final conversation = _filteredConversations[index - 1];
            return _ConversationTile(
              conversation: conversation,
              onTap: () => _openChat(conversation),
            );
          }

          final conversation = _filteredConversations[index];
          return _ConversationTile(
            conversation: conversation,
            onTap: () => _openChat(conversation),
          );
        },
      ),
    );
  }

  void _openChat(Conversation conversation) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ChatScreen(
          targetId: conversation.userKey ?? conversation.managerId!,
          targetName: conversation.displayName,
          targetPicture: conversation.displayPicture,
          conversationId: conversation.id,
        ),
      ),
    ).then((_) => _loadConversations());
  }

  void _openAIChat() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const AIChatScreen(startNewConversation: true),
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({
    required this.conversation,
    required this.onTap,
  });

  final Conversation conversation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasUnread = conversation.unreadCount > 0;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: <Widget>[
            // Avatar
            Stack(
              children: <Widget>[
                UserAvatar(
                  imageUrl: conversation.displayPicture,
                  fullName: conversation.displayName,
                  radius: 28,
                ),
                if (hasUnread)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: theme.primaryColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: Center(
                        child: Text(
                          conversation.unreadCount > 9
                              ? '9+'
                              : '${conversation.unreadCount}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Expanded(
                        child: Row(
                          children: <Widget>[
                            Flexible(
                              child: Text(
                                conversation.displayName,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight:
                                      hasUnread ? FontWeight.w700 : FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (conversation.isManagerPeer) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF6366F1).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'Manager',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFF6366F1),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (conversation.lastMessageAt != null)
                        Text(
                          timeago.format(conversation.lastMessageAt!),
                          style: TextStyle(
                            fontSize: 12,
                            color: hasUnread
                                ? theme.primaryColor
                                : Colors.grey[600],
                            fontWeight:
                                hasUnread ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    conversation.lastMessagePreview ?? 'No messages yet',
                    style: TextStyle(
                      fontSize: 14,
                      color: hasUnread ? Colors.black87 : Colors.grey[600],
                      fontWeight:
                          hasUnread ? FontWeight.w500 : FontWeight.normal,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

}

/// Pinned Valerio Assistant chat tile
class _AIChatTile extends StatelessWidget {
  const _AIChatTile({
    required this.onTap,
  });

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.tealInfo.withOpacity(0.08),
              AppColors.oceanBlue.withOpacity(0.08),
            ],
          ),
        ),
        child: Row(
          children: <Widget>[
            // Valerio Avatar - AI mascot logo
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/ai_assistant_logo.png',
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Text content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      const Text(
                        'Valerio Assistant',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.charcoal,
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Pin icon
                      Icon(
                        Icons.push_pin,
                        size: 16,
                        color: AppColors.tealInfo.withOpacity(0.7),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Create events, manage jobs, and get instant help',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet for selecting a contact to start a new chat
class _ContactPickerSheet extends StatefulWidget {
  const _ContactPickerSheet({
    required this.onContactSelected,
  });

  final void Function(Map<String, dynamic> contact) onContactSelected;

  @override
  State<_ContactPickerSheet> createState() => _ContactPickerSheetState();
}

class _ContactPickerSheetState extends State<_ContactPickerSheet> {
  final ChatService _chatService = ChatService();
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _contacts = [];
  List<Map<String, dynamic>> _filteredContacts = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadContacts();
    _searchController.addListener(_filterContacts);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadContacts() async {
    try {
      setState(() {
        _loading = true;
        _error = null;
      });

      // Fetch team members and peer managers in parallel
      final results = await Future.wait([
        _chatService.fetchContacts(),
        _chatService.fetchPeerManagers().catchError((_) => <Map<String, dynamic>>[]),
      ]);

      final teamMembers = results[0];
      final peerManagers = results[1];

      // Deduplicate by userKey and merge
      final seen = <String>{};
      final allContacts = <Map<String, dynamic>>[];

      for (final contact in teamMembers) {
        final key = contact['userKey'] as String? ?? '';
        if (key.isNotEmpty && seen.add(key)) {
          allContacts.add(contact);
        }
      }
      for (final manager in peerManagers) {
        final key = manager['userKey'] as String? ?? '';
        if (key.isNotEmpty && seen.add(key)) {
          allContacts.add(manager);
        }
      }

      setState(() {
        _contacts = allContacts;
        _filteredContacts = allContacts;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _filterContacts() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredContacts = _contacts;
      } else {
        _filteredContacts = _contacts.where((contact) {
          final name = (contact['name'] as String? ?? '').toLowerCase();
          final email = (contact['email'] as String? ?? '').toLowerCase();
          return name.contains(query) || email.contains(query);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Text(
                  'New Chat',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.charcoal,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          // Search field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search contacts...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Content
          Expanded(
            child: _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Failed to load contacts',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _loadContacts,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_filteredContacts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              _searchController.text.isNotEmpty
                  ? 'No contacts match your search'
                  : 'No team members yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
            if (_searchController.text.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Add members to your team to start chatting',
                  style: TextStyle(color: Colors.grey[500]),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      );
    }

    return ListView.separated(
      itemCount: _filteredContacts.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final contact = _filteredContacts[index];
        return _ContactTile(
          contact: contact,
          onTap: () => widget.onContactSelected(contact),
        );
      },
    );
  }
}

/// Individual contact tile in the picker
class _ContactTile extends StatelessWidget {
  const _ContactTile({
    required this.contact,
    required this.onTap,
  });

  final Map<String, dynamic> contact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = contact['name'] as String? ?? 'Unknown';
    final email = contact['email'] as String? ?? '';
    final picture = contact['picture'] as String?;
    final hasConversation = contact['hasConversation'] as bool? ?? false;
    final role = contact['role'] as String?;
    final isManager = role == 'Manager';

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            UserAvatar(
              imageUrl: picture,
              fullName: name,
              radius: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isManager) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6366F1).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Manager',
                            style: TextStyle(
                              fontSize: 10,
                              color: Color(0xFF6366F1),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (email.isNotEmpty)
                    Text(
                      email,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                ],
              ),
            ),
            if (hasConversation)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.tealInfo.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Active',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.tealInfo,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            const SizedBox(width: 8),
            Icon(
              Icons.chat_bubble_outline,
              color: AppColors.tealInfo,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
