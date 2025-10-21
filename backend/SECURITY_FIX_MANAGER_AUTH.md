# Security Fix: Manager Auto-Creation Vulnerability

## Problem Identified

**Critical Security Flaw:** Users authenticated via staff endpoints (`/auth/google`, `/auth/apple`) were being automatically promoted to managers when they accessed manager-only endpoints.

### Root Cause

The `resolveManagerForRequest()` utility function in `src/utils/manager.ts` had auto-creation logic:

```typescript
// OLD CODE - VULNERABLE
if (existing) {
  return existing;
}

const created = await ManagerModel.create({
  provider: req.authUser.provider,
  subject: req.authUser.sub,
  // ... auto-creates manager for ANY authenticated user
});
```

This meant:
1. Staff user signs in via `/auth/google` → Gets JWT **without** `managerId`
2. Staff user calls manager endpoint (e.g., `POST /events`)
3. Endpoint calls `resolveManagerForRequest()`
4. Function creates Manager document → **Staff user becomes manager!** 🚨

---

## Solution Implemented

### 1. Fixed `resolveManagerForRequest()` in `src/utils/manager.ts`

**NEW BEHAVIOR:** Requires `managerId` in JWT token, never auto-creates.

```typescript
// SECURITY: Require managerId in JWT token (only manager auth endpoints provide this)
if (!req.authUser?.managerId) {
  throw new Error('Manager authentication required. Please sign in using the manager app.');
}

// Look up manager by the managerId claim in JWT (more efficient and secure)
const manager = await ManagerModel.findById(req.authUser.managerId);

if (!manager) {
  throw new Error('Manager profile not found. Please sign in again using the manager app.');
}

// Verify the JWT claims match the manager document (prevent token tampering)
if (manager.provider !== req.authUser.provider || manager.subject !== req.authUser.sub) {
  throw new Error('Manager authentication mismatch. Please sign in again.');
}
```

### 2. Enhanced `requireManagerAuth` Middleware in `src/middleware/requireTeamMemberAccess.ts`

**Improvements:**
- Looks up manager by `managerId` from JWT (instead of `provider:subject`)
- Verifies JWT claims match the manager document (prevents token tampering)
- Returns clear error messages for troubleshooting

```typescript
// Resolve manager document by managerId from JWT (more efficient and secure)
const managerObjectId = new mongoose.Types.ObjectId(authUser.managerId);
const manager = await ManagerModel.findById(managerObjectId);

// Verify JWT claims match the manager document (prevent token tampering)
if (manager.provider !== authUser.provider || manager.subject !== authUser.sub) {
  res.status(403).json({
    error: 'Manager authentication mismatch',
    message: 'Please sign in again.'
  });
  return;
}
```

---

## Security Architecture

### Authentication Flow

#### Staff Users (Mobile App):
1. Sign in via `/auth/google` or `/auth/apple`
2. Receive JWT **without** `managerId` claim
3. Can access:
   - ✅ `GET /users/me` - Own profile
   - ✅ `GET /events` - View available events (filters to manager's events)
   - ✅ `POST /invites/redeem` - Join teams
   - ✅ `GET /chat/conversations` - Chat with managers
4. **BLOCKED** from:
   - ❌ `POST /events` - Creating events (requires managerId)
   - ❌ `POST /teams` - Creating teams (requires managerId)
   - ❌ `GET /users` - Listing users (requires managerId)
   - ❌ Any endpoint using `resolveManagerForRequest()`

#### Managers (Manager App):
1. Sign in via `/auth/manager/google` or `/auth/manager/apple`
2. Receive JWT **with** `managerId` claim
3. Can access:
   - ✅ All manager endpoints (events, teams, users, roles, tariffs)
   - ✅ `GET /managers/me` - Own manager profile
   - ✅ `GET /users` - List team members
   - ✅ `POST /teams/:id/invites/create-link` - Create invite links
4. **BLOCKED** from:
   - ❌ `GET /users/me` - Staff profile endpoint (returns 403)

---

## Token Structure

### Staff JWT (from `/auth/google` or `/auth/apple`):
```json
{
  "sub": "google_123456789",
  "provider": "google",
  "email": "staff@example.com",
  "name": "John Doe",
  "picture": "https://...",
  "exp": 1234567890
}
```
**Note:** No `managerId` claim

### Manager JWT (from `/auth/manager/google` or `/auth/manager/apple`):
```json
{
  "sub": "google_987654321",
  "provider": "google",
  "email": "manager@example.com",
  "name": "Jane Smith",
  "picture": "https://...",
  "managerId": "507f1f77bcf86cd799439011",
  "exp": 1234567890
}
```
**Note:** Includes `managerId` claim

---

## Testing

### Test 1: Staff User Blocked from Manager Endpoints

**Setup:**
```bash
# Get staff JWT
curl -X POST http://localhost:3000/api/auth/google \
  -H "Content-Type: application/json" \
  -d '{"idToken": "staff_google_token"}'
```

**Expected Response:**
```json
{
  "token": "eyJhbGc...",  // JWT without managerId
  "user": {
    "provider": "google",
    "subject": "123456789",
    "email": "staff@example.com"
  }
}
```

**Test Manager Endpoint:**
```bash
curl -X POST http://localhost:3000/api/events \
  -H "Authorization: Bearer <staff_jwt>" \
  -H "Content-Type: application/json" \
  -d '{"event_name": "Test Event"}'
```

**Expected Response:**
```json
{
  "message": "Manager authentication required. Please sign in using the manager app."
}
```
**Status:** 500 (thrown error from resolveManagerForRequest)

### Test 2: Manager Can Access Manager Endpoints

**Setup:**
```bash
# Get manager JWT
curl -X POST http://localhost:3000/api/auth/manager/google \
  -H "Content-Type: application/json" \
  -d '{"idToken": "manager_google_token"}'
```

**Expected Response:**
```json
{
  "token": "eyJhbGc...",  // JWT with managerId
  "user": {
    "provider": "google",
    "subject": "987654321",
    "email": "manager@example.com"
  }
}
```

**Test Manager Endpoint:**
```bash
curl -X POST http://localhost:3000/api/events \
  -H "Authorization: Bearer <manager_jwt>" \
  -H "Content-Type: application/json" \
  -d '{"event_name": "Test Event", ...}'
```

**Expected Response:**
```json
{
  "id": "507f...",
  "event_name": "Test Event",
  ...
}
```
**Status:** 201 Created ✅

---

## Files Modified

### 1. `src/utils/manager.ts`
- ✅ Removed auto-creation logic
- ✅ Requires `managerId` in JWT
- ✅ Validates JWT claims match manager document
- ✅ Clear error messages

### 2. `src/middleware/requireTeamMemberAccess.ts`
- ✅ Uses `managerId` from JWT for lookup (not provider:subject)
- ✅ Validates JWT claims match manager document
- ✅ Better error messages

---

## Impact on Existing Code

### Endpoints Using `resolveManagerForRequest()`:

**All these now require manager JWT:**
- `src/routes/events.ts` - 14 calls
- `src/routes/teams.ts` - 13 calls
- `src/routes/roles.ts` - 4 calls
- `src/routes/tariffs.ts` - 3 calls

**Behavior Change:**
- **Before:** Staff users could accidentally become managers
- **After:** Staff users get clear error message and are blocked

### No Breaking Changes for Proper Usage:

- Manager app users already use `/auth/manager/*` endpoints ✅
- Staff app users already use `/auth/google` or `/auth/apple` endpoints ✅
- Existing tokens continue to work as designed ✅

---

## Security Benefits

1. **Principle of Least Privilege:** Users can only access what they need
2. **No Auto-Promotion:** Managers must be explicitly created via manager auth endpoints
3. **Token Validation:** JWT claims are verified against database documents
4. **Defense in Depth:** Multiple layers check for `managerId` claim
5. **Clear Error Messages:** Helps debugging without leaking security info

---

## Deployment Notes

### Before Deploying:
1. ✅ Ensure all manager users have signed in via `/auth/manager/*` endpoints
2. ✅ Verify manager app is using correct auth endpoints
3. ✅ Test with both staff and manager tokens

### After Deploying:
1. Monitor logs for "Manager authentication required" errors
2. If staff users report errors, verify they're using correct auth endpoint
3. If managers report errors, have them sign in again via manager app

---

## Related Security Fixes

This fix complements the earlier security improvements:
1. **User Privacy:** Managers can only see team members (not all users)
2. **Chat Security:** Conversations filtered by team membership
3. **Manager Auth:** This fix - no auto-promotion to manager

Together, these create a secure multi-tenant architecture where managers and staff are properly isolated.
