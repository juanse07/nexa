# User-Friendly Error Messages

## Problem

The manager app was showing raw error messages like:
- "Failed to load users: Exception: Failed to load users (401): {error: Authentication required}"

This is confusing for users who don't understand technical errors.

---

## Solution

Improved error messages to be helpful and actionable instead of technical.

---

## Changes Made

### 1. Empty Team Members Response

**File:** `src/routes/users.ts` (line 290-297)

**Scenario:** Manager has no team members yet

**Before:**
```json
{
  "items": [],
  "nextCursor": undefined
}
```

**After:**
```json
{
  "items": [],
  "nextCursor": undefined,
  "message": "You don't have any team members yet. Create an invite link to add members to your team!"
}
```

**Frontend Display:** Show friendly empty state with call-to-action

---

### 2. Authentication Required Error

**File:** `src/middleware/requireTeamMemberAccess.ts` (line 102-108)

**Scenario:** User not authenticated (missing JWT token)

**Before:**
```json
{
  "error": "Authentication required"
}
```

**After:**
```json
{
  "error": "Authentication required",
  "message": "Please sign in to continue"
}
```

**HTTP Status:** 401
**Frontend Action:** Redirect to login screen

---

### 3. Manager Access Required Error

**File:** `src/routes/users.ts` (line 373-380)

**Scenario:** Staff user trying to access manager endpoint

**Before:**
```json
{
  "message": "Failed to fetch users"
}
```

**After:**
```json
{
  "message": "Manager access required",
  "hint": "Please sign in using the manager app to view team members"
}
```

**HTTP Status:** 403
**Frontend Action:** Show error message with hint

---

### 4. Generic Server Error

**File:** `src/routes/users.ts` (line 382-385)

**Scenario:** Unexpected server error

**Before:**
```json
{
  "message": "Failed to fetch users"
}
```

**After:**
```json
{
  "message": "Unable to load users at this time",
  "hint": "Please try again or contact support if the problem persists"
}
```

**HTTP Status:** 500
**Frontend Action:** Show retry button or support contact

---

## Frontend Integration Guide

### Handling Empty State

```typescript
// Example: Chat user search in manager app
const response = await fetch('/api/users?q=juan', {
  headers: { Authorization: `Bearer ${token}` }
});

const data = await response.json();

if (data.items.length === 0) {
  if (data.message) {
    // Show friendly empty state
    showEmptyState(data.message);
    // "You don't have any team members yet. Create an invite link to add members to your team!"
  } else {
    showEmptyState('No users found matching your search.');
  }
}
```

### Handling Errors

```typescript
try {
  const response = await fetch('/api/users', {
    headers: { Authorization: `Bearer ${token}` }
  });

  if (!response.ok) {
    const error = await response.json();

    switch (response.status) {
      case 401:
        // Not authenticated
        showError(error.message || 'Please sign in to continue');
        redirectToLogin();
        break;

      case 403:
        // Not authorized (wrong app or not a manager)
        showError(error.message || 'Access denied');
        if (error.hint) showHint(error.hint);
        break;

      case 500:
        // Server error
        showError(error.message || 'Something went wrong');
        if (error.hint) showHint(error.hint);
        showRetryButton();
        break;

      default:
        showError('Unable to load users');
    }
    return;
  }

  const data = await response.json();
  displayUsers(data.items);

} catch (err) {
  // Network error
  showError('Unable to connect. Please check your internet connection.');
  showRetryButton();
}
```

---

## Error Message Guidelines

### Good Error Messages Should:

✅ **Be user-friendly:** Avoid technical jargon
✅ **Be actionable:** Tell users what they can do
✅ **Be specific:** Explain what went wrong
✅ **Be helpful:** Provide hints or next steps
✅ **Be honest:** Don't hide errors, but present them nicely

### Examples:

**Bad:**
- "Exception: Failed to load users (401)"
- "Error: Authentication required"
- "Internal server error"

**Good:**
- "Please sign in to continue"
- "You don't have any team members yet. Create an invite link!"
- "Unable to load users at this time. Please try again."

---

## Testing

### Test Case 1: New Manager with No Team Members

**Request:**
```bash
curl -X GET http://localhost:3000/api/users \
  -H "Authorization: Bearer <manager_jwt>"
```

**Expected Response (200):**
```json
{
  "items": [],
  "nextCursor": undefined,
  "message": "You don't have any team members yet. Create an invite link to add members to your team!"
}
```

**Frontend Should Show:**
```
┌──────────────────────────────────────┐
│  No Team Members Yet                 │
│                                      │
│  You don't have any team members     │
│  yet. Create an invite link to add   │
│  members to your team!               │
│                                      │
│  [Create Invite Link]                │
└──────────────────────────────────────┘
```

---

### Test Case 2: Unauthenticated Request

**Request:**
```bash
curl -X GET http://localhost:3000/api/users
# No Authorization header
```

**Expected Response (401):**
```json
{
  "error": "Authentication required",
  "message": "Please sign in to continue"
}
```

**Frontend Should:**
- Clear local auth token
- Redirect to login screen
- Show: "Please sign in to continue"

---

### Test Case 3: Staff User Trying to Access Manager Endpoint

**Request:**
```bash
curl -X GET http://localhost:3000/api/users \
  -H "Authorization: Bearer <staff_jwt>"
# JWT without managerId claim
```

**Expected Response (403):**
```json
{
  "message": "Manager access required",
  "hint": "Please sign in using the manager app to view team members"
}
```

**Frontend Should Show:**
```
┌──────────────────────────────────────┐
│  ⚠️ Manager Access Required          │
│                                      │
│  Please sign in using the manager    │
│  app to view team members            │
│                                      │
│  [Switch to Manager App]             │
└──────────────────────────────────────┘
```

---

## Benefits

1. **Better UX:** Users understand what's happening
2. **Fewer Support Tickets:** Clear instructions reduce confusion
3. **Higher Engagement:** Helpful hints guide users to next actions
4. **Professional Feel:** Polish and attention to detail
5. **Easier Debugging:** Developers can quickly identify auth vs empty state issues

---

## Related Documentation

- `SECURITY_FIX_MANAGER_AUTH.md` - Manager authentication security fix
- `TEAM_INVITATION_SYSTEM.md` - Team invitation system implementation
