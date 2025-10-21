# Professional Chat Architecture

## Overview

Following industry best practices from Slack, WhatsApp, and Microsoft Teams, the chat system provides:
- ✅ Unified contact list with conversation status
- ✅ Server-side search for performance
- ✅ Smart sorting (active conversations first)
- ✅ Graceful empty states
- ✅ Manager/Staff role separation

---

## API Endpoints

### For Managers

#### GET `/chat/contacts`
**Purpose:** Get searchable list of team members for chatting
**Authentication:** Manager JWT required
**Query Parameters:**
- `q` (optional): Search query to filter by name or email

**Response (200):**
```json
{
  "contacts": [
    {
      "userKey": "google:123456789",
      "name": "John Doe",
      "firstName": "John",
      "lastName": "Doe",
      "email": "john@example.com",
      "picture": "https://...",

      // Conversation status
      "hasConversation": true,
      "conversationId": "507f1f77bcf86cd799439011",
      "lastMessageAt": "2024-10-21T13:15:00Z",
      "lastMessagePreview": "Thanks for the update!",
      "unreadCount": 2
    },
    {
      "userKey": "google:987654321",
      "name": "Jane Smith",
      "firstName": "Jane",
      "lastName": "Smith",
      "email": "jane@example.com",
      "picture": "https://...",

      // No conversation yet
      "hasConversation": false,
      "conversationId": null,
      "lastMessageAt": null,
      "lastMessagePreview": null,
      "unreadCount": 0
    }
  ]
}
```

**Empty State (200):**
```json
{
  "contacts": [],
  "message": "You don't have any team members yet. Create an invite link to add members to your team!"
}
```

**Error (403):**
```json
{
  "error": "Manager authentication required",
  "message": "This endpoint is only available for managers"
}
```

**Sorting Logic:**
1. **Existing conversations** - Sorted by `lastMessageAt` (most recent first)
2. **No conversations** - Sorted alphabetically by `name`

**Search Behavior:**
- Server-side filtering (fast, scales well)
- Searches: `name`, `firstName`, `lastName`, `email`
- Case-insensitive
- Substring matching (e.g., "joh" matches "John")

---

#### GET `/chat/conversations`
**Purpose:** Get list of existing conversations
**Authentication:** Manager or User JWT
**Best For:** Main chat list / inbox view

**Response for Manager (200):**
```json
{
  "conversations": [
    {
      "id": "507f1f77bcf86cd799439011",
      "userKey": "google:123456789",
      "userName": "John Doe",
      "userFirstName": "John",
      "userLastName": "Doe",
      "userPicture": "https://...",
      "userEmail": "john@example.com",
      "lastMessageAt": "2024-10-21T13:15:00Z",
      "lastMessagePreview": "Thanks for the update!",
      "unreadCount": 2,
      "updatedAt": "2024-10-21T13:15:00Z"
    }
  ]
}
```

**Note:** Only returns conversations with **active team members** (filtered by team membership).

---

### For Users (Staff)

#### GET `/chat/managers`
**Purpose:** Get list of managers to chat with
**Authentication:** User JWT required (no `managerId` claim)

**Response (200):**
```json
{
  "managers": [
    {
      "id": "507f1f77bcf86cd799439011",
      "name": "Jane Smith",
      "email": "jane@manager.com",
      "picture": "https://..."
    }
  ]
}
```

---

## Frontend Integration Guide

### Manager App - Chat Feature

#### 1. Chat Contact List UI

```typescript
// Fetch contacts with search
const fetchContacts = async (searchQuery: string = '') => {
  try {
    const url = searchQuery
      ? `/api/chat/contacts?q=${encodeURIComponent(searchQuery)}`
      : `/api/chat/contacts`;

    const response = await fetch(url, {
      headers: { Authorization: `Bearer ${managerToken}` }
    });

    if (!response.ok) {
      const error = await response.json();

      if (response.status === 403) {
        // Not a manager - redirect to login
        showError(error.message);
        redirectToManagerLogin();
        return;
      }

      throw new Error(error.message || 'Failed to load contacts');
    }

    const data = await response.json();

    if (data.contacts.length === 0) {
      // Show empty state
      if (data.message) {
        showEmptyState(data.message);
        // "You don't have any team members yet. Create an invite link!"
      } else {
        showEmptyState('No contacts found matching your search.');
      }
      return;
    }

    // Display contacts
    displayContacts(data.contacts);

  } catch (err) {
    showError('Unable to load contacts. Please try again.');
  }
};

// Display contacts in UI
const displayContacts = (contacts: Contact[]) => {
  const contactList = contacts.map(contact => {
    if (contact.hasConversation) {
      return (
        <ContactRow
          key={contact.userKey}
          name={contact.name}
          picture={contact.picture}
          lastMessage={contact.lastMessagePreview}
          lastMessageTime={contact.lastMessageAt}
          unreadCount={contact.unreadCount}
          onClick={() => openConversation(contact.conversationId)}
        />
      );
    } else {
      return (
        <ContactRow
          key={contact.userKey}
          name={contact.name}
          picture={contact.picture}
          subtitle="Start a conversation"
          onClick={() => startNewConversation(contact.userKey)}
        />
      );
    }
  });

  render(contactList);
};
```

#### 2. Search Implementation

```typescript
// Debounced search for better UX
import { debounce } from 'lodash';

const handleSearch = debounce(async (query: string) => {
  setLoading(true);
  await fetchContacts(query);
  setLoading(false);
}, 300); // Wait 300ms after user stops typing

// In search input
<SearchInput
  placeholder="Search team members..."
  onChange={(e) => handleSearch(e.target.value)}
/>
```

#### 3. Start New Conversation

```typescript
const startNewConversation = async (userKey: string) => {
  try {
    // Send first message to create conversation
    const response = await fetch(`/api/chat/conversations/${userKey}/messages`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${managerToken}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        message: 'Hi! 👋',
        messageType: 'text'
      })
    });

    if (!response.ok) {
      const error = await response.json();

      if (response.status === 403 && error.error.includes('not members of your teams')) {
        showError('You can only message team members. This person may have left your team.');
        return;
      }

      throw new Error(error.error || 'Failed to send message');
    }

    const data = await response.json();

    // Navigate to conversation
    navigateToConversation(data.message.conversationId);

  } catch (err) {
    showError('Unable to start conversation. Please try again.');
  }
};
```

---

## UI/UX Recommendations

### Chat Contact List Layout

```
┌──────────────────────────────────────────────┐
│  Chat                              [+ New]   │
├──────────────────────────────────────────────┤
│  🔍 Search team members...                   │
├──────────────────────────────────────────────┤
│                                              │
│  RECENT CONVERSATIONS                        │
│  ┌────────────────────────────────────────┐ │
│  │ 📷 John Doe                    2m      │ │
│  │    Thanks for the update!        🔵 2 │ │
│  └────────────────────────────────────────┘ │
│  ┌────────────────────────────────────────┐ │
│  │ 📷 Alice Johnson               10m     │ │
│  │    See you tomorrow!                  │ │
│  └────────────────────────────────────────┘ │
│                                              │
│  TEAM MEMBERS                                │
│  ┌────────────────────────────────────────┐ │
│  │ 📷 Bob Smith                           │ │
│  │    Start a conversation                │ │
│  └────────────────────────────────────────┘ │
│  ┌────────────────────────────────────────┐ │
│  │ 📷 Carol White                         │ │
│  │    Start a conversation                │ │
│  └────────────────────────────────────────┘ │
└──────────────────────────────────────────────┘
```

### Empty State

```
┌──────────────────────────────────────────────┐
│  Chat                                        │
├──────────────────────────────────────────────┤
│                                              │
│              👥                              │
│                                              │
│       No Team Members Yet                    │
│                                              │
│  You don't have any team members yet.        │
│  Create an invite link to add members        │
│  to your team!                               │
│                                              │
│       [Create Invite Link]                   │
│                                              │
└──────────────────────────────────────────────┘
```

### Search Results

```
┌──────────────────────────────────────────────┐
│  Chat                                        │
├──────────────────────────────────────────────┤
│  🔍 john                            [×]      │
├──────────────────────────────────────────────┤
│                                              │
│  2 results for "john"                        │
│                                              │
│  ┌────────────────────────────────────────┐ │
│  │ 📷 John Doe                    2m      │ │
│  │    Thanks for the update!        🔵 2 │ │
│  └────────────────────────────────────────┘ │
│  ┌────────────────────────────────────────┐ │
│  │ 📷 John Smith                          │ │
│  │    Start a conversation                │ │
│  └────────────────────────────────────────┘ │
└──────────────────────────────────────────────┘
```

---

## Performance Considerations

### Why Server-Side Search?

✅ **Scalability:** Works with thousands of team members
✅ **Bandwidth:** Only sends matching results
✅ **Consistency:** Search logic centralized on backend
✅ **Security:** Filters by team membership on server

### Response Times (Expected)

- `/chat/contacts` - <100ms for up to 1000 team members
- `/chat/contacts?q=john` - <50ms (indexed search)
- `/chat/conversations` - <50ms (indexed by managerId)

### Caching Strategy (Frontend)

```typescript
// Cache contacts for 30 seconds
const CACHE_TTL = 30000;
let contactsCache = { data: null, timestamp: 0 };

const fetchContacts = async (query: string = '') => {
  const now = Date.now();

  // Return cached data if fresh and no search query
  if (!query && contactsCache.data && (now - contactsCache.timestamp < CACHE_TTL)) {
    return contactsCache.data;
  }

  const data = await fetchFromAPI(`/chat/contacts?q=${query}`);

  // Cache only non-search results
  if (!query) {
    contactsCache = { data, timestamp: now };
  }

  return data;
};
```

---

## Error Handling

### Common Errors

| Status | Error | Meaning | Action |
|--------|-------|---------|--------|
| 401 | Authentication required | No JWT token | Redirect to login |
| 403 | Manager authentication required | Staff user trying to access | Show error, redirect |
| 403 | Cannot message users who are not members of your teams | User left team | Show error, hide contact |
| 500 | Unable to load contacts | Server error | Show retry button |

### Example Error Handler

```typescript
const handleChatError = (status: number, error: any) => {
  switch (status) {
    case 401:
      showToast('Session expired. Please sign in again.', 'error');
      clearAuthToken();
      redirectToLogin();
      break;

    case 403:
      if (error.message?.includes('Manager authentication')) {
        showToast('Please sign in using the manager app.', 'error');
        redirectToManagerLogin();
      } else {
        showToast(error.message || 'Access denied', 'error');
      }
      break;

    case 500:
      showToast('Something went wrong. Please try again.', 'error');
      showRetryButton();
      break;

    default:
      showToast('Unable to load chat. Please try again.', 'error');
  }
};
```

---

## Migration Guide

### Old Approach (INCORRECT)
```typescript
// ❌ Don't call /users from Chat UI
const contacts = await fetch('/api/users?q=john');
```

### New Approach (CORRECT)
```typescript
// ✅ Use dedicated chat endpoint
const contacts = await fetch('/api/chat/contacts?q=john');
```

### Benefits of New Approach

| Feature | Old `/users` | New `/chat/contacts` |
|---------|-------------|---------------------|
| Shows conversation status | ❌ No | ✅ Yes |
| Sorted by recent messages | ❌ No | ✅ Yes |
| Unread count | ❌ No | ✅ Yes |
| Last message preview | ❌ No | ✅ Yes |
| Search optimized for chat | ❌ No | ✅ Yes |
| Friendly empty state | ❌ No | ✅ Yes |
| Manager-only access | ✅ Yes | ✅ Yes |

---

## Testing

### Test Case 1: Manager with Team Members and Conversations

**Request:**
```bash
curl -X GET "http://localhost:3000/api/chat/contacts" \
  -H "Authorization: Bearer <manager_jwt>"
```

**Expected Response (200):**
```json
{
  "contacts": [
    {
      "userKey": "google:123",
      "name": "John Doe",
      "hasConversation": true,
      "conversationId": "507f...",
      "lastMessageAt": "2024-10-21T13:15:00Z",
      "lastMessagePreview": "Thanks!",
      "unreadCount": 2
    },
    {
      "userKey": "google:456",
      "name": "Alice Smith",
      "hasConversation": false,
      "conversationId": null
    }
  ]
}
```

### Test Case 2: Manager with No Team Members

**Request:**
```bash
curl -X GET "http://localhost:3000/api/chat/contacts" \
  -H "Authorization: Bearer <manager_jwt>"
```

**Expected Response (200):**
```json
{
  "contacts": [],
  "message": "You don't have any team members yet. Create an invite link to add members to your team!"
}
```

### Test Case 3: Search Query

**Request:**
```bash
curl -X GET "http://localhost:3000/api/chat/contacts?q=john" \
  -H "Authorization: Bearer <manager_jwt>"
```

**Expected Response (200):**
```json
{
  "contacts": [
    {
      "userKey": "google:123",
      "name": "John Doe",
      // ...
    },
    {
      "userKey": "google:789",
      "name": "John Smith",
      // ...
    }
  ]
}
```

### Test Case 4: Staff User (Should Fail)

**Request:**
```bash
curl -X GET "http://localhost:3000/api/chat/contacts" \
  -H "Authorization: Bearer <staff_jwt>"
```

**Expected Response (403):**
```json
{
  "error": "Manager authentication required",
  "message": "This endpoint is only available for managers"
}
```

---

## Summary

### For Backend Developers
- ✅ Created `/chat/contacts` endpoint following pro chat app patterns
- ✅ Server-side search with performance optimization
- ✅ Smart sorting (conversations first, then alphabetical)
- ✅ Graceful error handling and empty states
- ✅ Security: filtered by team membership

### For Frontend Developers
- 🔄 **Change:** Use `/chat/contacts` instead of `/users` for Chat UI
- ✅ **Benefit:** Get conversation status, sorting, and better UX
- ✅ **Search:** Pass `?q=query` parameter for server-side filtering
- ✅ **Errors:** Handle gracefully with user-friendly messages
- ✅ **Empty State:** Show helpful message with call-to-action

### For Product/Design
- ✅ Matches professional chat apps (Slack, Teams, WhatsApp)
- ✅ Clean separation: recent conversations vs new contacts
- ✅ Search is fast and intuitive
- ✅ Empty states guide users to next action
