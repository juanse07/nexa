# User Collection Security Implementation

## Overview
This document describes the security architecture implemented to make the users collection private, where managers can only interact with users who are active members of their teams.

---

## Architecture Changes

### 1. Authorization Middleware
**File:** `src/middleware/requireTeamMemberAccess.ts`

**Purpose:** Provides authorization functions and middleware for verifying manager access to users.

**Key Functions:**

#### `canAccessUser(managerId, provider, subject)`
- Checks if a manager has access to a specific user
- Queries TeamMember collection for active membership
- Returns boolean (true if authorized, false otherwise)

#### `getAccessibleUsers(managerId)`
- Returns a Set of all user identities accessible by a manager
- Format: `"provider:subject"` strings
- Used for bulk authorization checks

#### `requireManagerAuth(req, res, next)`
- Middleware that enforces manager authentication
- Verifies JWT contains `managerId` field
- Resolves manager document from database
- Caches manager ID in `req._authCache` for performance
- Rejects requests without manager credentials (403 Forbidden)

#### `getCachedManagerId(req)`
- Helper to retrieve cached manager ID from request
- Avoids redundant database queries

#### `getOrCacheAccessibleUsers(req)`
- Gets or populates the accessible users cache
- Prevents duplicate authorization queries within a single request

**Request Caching Pattern:**
```typescript
req._authCache = {
  managerId: ObjectId,           // Cached manager ID
  accessibleUsers: Set<string>   // Set of "provider:subject" keys
}
```

---

### 2. Users Routes Updates
**File:** `src/routes/users.ts`

#### GET `/users/me` (Modified)
**Security:** Block manager authentication

**Changes:**
- Added check for `authUser.managerId`
- Rejects manager-authenticated requests with 403
- Error message directs managers to use `/managers/me`

**Use Case:** Regular users accessing their own profile

---

#### GET `/users` (Modified - Major Security Change)
**Security:** Managers only see active team members

**Changes:**
- Added `requireManagerAuth` middleware
- Queries TeamMember collection to get accessible users
- Filters User collection by team membership
- Maintains search functionality (name, email, firstName, lastName)
- Maintains cursor-based pagination
- Returns empty array if manager has no team members

**Query Pattern:**
1. Fetch all active team members for manager
2. Build `$or` filter with (provider, subject) pairs
3. Apply search query if provided
4. Apply cursor pagination
5. Return filtered results

**Performance:** Uses indexed queries on TeamMember collection

**Response Format:**
```json
{
  "items": [
    {
      "id": "user_id",
      "provider": "google",
      "subject": "123...",
      "email": "user@example.com",
      "name": "John Doe",
      "firstName": "John",
      "lastName": "Doe",
      "phoneNumber": "555-1234",
      "picture": "https://...",
      "appId": "123456789"
    }
  ],
  "nextCursor": "base64_cursor"
}
```

---

#### GET `/users/:userId` (New Endpoint)
**Security:** Managers can only lookup team members by ObjectId

**Authorization Flow:**
1. Validate userId is a valid MongoDB ObjectId
2. Verify manager authentication
3. Fetch user document to get OAuth identity
4. Check if user is an active member of manager's teams
5. Return 404 if unauthorized (not 403 to avoid leaking user existence)
6. Return user profile if authorized

**Security Best Practice:** Returns 404 instead of 403 for unauthorized access to prevent user enumeration attacks

**Response:** Same format as GET /users items

---

#### GET `/users/by-identity` (New Endpoint)
**Security:** Managers can only lookup team members by OAuth identity

**Query Parameters:**
- `provider` (required): OAuth provider (google, apple)
- `subject` (required): OAuth subject identifier

**Authorization Flow:**
1. Validate query parameters
2. Verify manager authentication
3. Check if user is an active member using `canAccessUser()`
4. Return 404 if unauthorized
5. Fetch and return user profile if authorized

**Use Case:** Chat/messaging features that need to resolve user profiles from OAuth identities

**Response:** Same format as GET /users/:userId

---

### 3. Teams Routes Enhancement
**File:** `src/routes/teams.ts`

#### GET `/teams/:teamId/members` (Enhanced)
**New Feature:** Optional user profile join via MongoDB aggregation

**Query Parameters:**
- `includeUserProfile`: Set to "true" or "1" to include full user profiles

**Default Behavior (includeUserProfile=false):**
- Returns TeamMember data only
- No User collection lookup

**Enhanced Behavior (includeUserProfile=true):**
- Uses MongoDB `$lookup` aggregation
- Joins User collection on (provider, subject)
- Returns TeamMember data + nested userProfile object
- userProfile is null if user hasn't registered yet

**Response Format with Profiles:**
```json
{
  "members": [
    {
      "id": "member_id",
      "teamId": "team_id",
      "provider": "google",
      "subject": "123...",
      "email": "user@example.com",
      "name": "John Doe",
      "status": "active",
      "joinedAt": "2024-01-15T10:00:00Z",
      "createdAt": "2024-01-15T10:00:00Z",
      "userProfile": {
        "id": "user_id",
        "provider": "google",
        "subject": "123...",
        "email": "user@example.com",
        "name": "John Doe",
        "firstName": "John",
        "lastName": "Doe",
        "phoneNumber": "555-1234",
        "picture": "https://...",
        "appId": "123456789"
      }
    }
  ]
}
```

**Aggregation Pipeline:**
```javascript
[
  { $match: { teamId, managerId, status: { $ne: 'left' } } },
  {
    $lookup: {
      from: 'users',
      let: { memberProvider: '$provider', memberSubject: '$subject' },
      pipeline: [
        {
          $match: {
            $expr: {
              $and: [
                { $eq: ['$provider', '$$memberProvider'] },
                { $eq: ['$subject', '$$memberSubject'] }
              ]
            }
          }
        },
        { $project: { /* user fields */ } }
      ],
      as: 'userProfile'
    }
  },
  { $sort: { createdAt: -1 } }
]
```

---

### 4. Database Index Optimization
**File:** `src/models/teamMember.ts`

**New Index Added:**
```javascript
TeamMemberSchema.index({ managerId: 1, status: 1, provider: 1, subject: 1 });
```

**Purpose:**
- Optimizes authorization queries: "which users can this manager access?"
- Enables fast lookups filtering by `managerId` + `status: 'active'`
- Covers queries that only need provider/subject for authorization
- MongoDB can use index prefixes for partial matches

**Existing Indexes:**
1. `{ teamId: 1, provider: 1, subject: 1 }` - unique constraint
2. `{ provider: 1, subject: 1, status: 1 }` - user-centric queries
3. `{ teamId: 1 }` - single field index (from schema)
4. `{ managerId: 1 }` - single field index (from schema)

---

## Security Principles Applied

### 1. Least Privilege
- Managers can ONLY access users who are active members of their teams
- No access to users in other managers' teams (unless user is shared)
- No access to users with status='left' or status='pending'

### 2. Defense in Depth
- Authorization at middleware level (`requireManagerAuth`)
- Authorization at business logic level (`canAccessUser`)
- Authorization at query level (filtering by team membership)

### 3. Fail Secure
- Unauthorized access returns 404 instead of 403
- Prevents user enumeration attacks
- Makes it indistinguishable whether user exists but is unauthorized vs. doesn't exist

### 4. Audit Trail
- All access goes through tracked team membership
- TeamMember records provide audit history
- Authorization checks are logged

### 5. Performance
- Indexed queries prevent slow table scans
- Request-level caching prevents duplicate authorization queries
- Compound indexes optimized for common access patterns

---

## API Endpoint Summary

| Endpoint | Method | Auth Required | Access Control |
|----------|--------|---------------|----------------|
| `/users/me` | GET | User (not manager) | Own profile only |
| `/users/me` | PATCH | User (not manager) | Own profile only |
| `/users` | GET | Manager | Active team members only |
| `/users/:userId` | GET | Manager | Active team members only |
| `/users/by-identity` | GET | Manager | Active team members only |
| `/teams/:teamId/members` | GET | Manager | Own team members only |

---

## Migration Notes

### For Existing API Consumers

1. **GET /users endpoint now requires manager authentication**
   - Regular users will receive 403 Forbidden
   - Managers will only see their team members

2. **New endpoints available:**
   - `GET /users/:userId` - Lookup user by MongoDB ObjectId
   - `GET /users/by-identity` - Lookup user by OAuth identity

3. **Enhanced team members endpoint:**
   - Add `?includeUserProfile=true` to get full user profiles

### Database Migration
No data migration required. The new index will be created automatically:
- On first server start, MongoDB will build the new compound index
- Existing data remains unchanged
- No downtime required

### Deployment Steps
1. Deploy updated code
2. Restart backend service
3. Verify new index creation: `db.teammembers.getIndexes()`
4. Run security tests (see `tests/user-security.test.md`)

---

## Testing

See `tests/user-security.test.md` for comprehensive test scenarios covering:
- Manager access restrictions
- Cross-manager isolation
- Team member status filtering
- Search and pagination
- Performance verification
- Security boundary testing

---

## Performance Considerations

### Query Optimization
- All authorization queries use indexed lookups
- Compound index `{ managerId, status, provider, subject }` covers common patterns
- Request-level caching prevents redundant database queries

### Expected Performance
- Authorization check: < 10ms (indexed query)
- GET /users (20 items): < 50ms
- GET /users/:userId: < 30ms
- GET /users/by-identity: < 30ms

### Monitoring Recommendations
1. Monitor slow query log for any COLLSCAN operations
2. Track authorization check latency
3. Monitor index hit rate
4. Alert on queries > 100ms

---

## Security Checklist

✅ Managers can only see users in their teams
✅ Managers cannot see users from other managers' teams (unless shared)
✅ Regular users cannot list all users
✅ Unauthorized access returns 404 (not 403)
✅ Left members are inaccessible
✅ Pending members are inaccessible
✅ Manager authentication is enforced
✅ All queries are indexed
✅ Authorization happens before data retrieval
✅ Request-level caching prevents performance issues

---

## Future Enhancements

### Possible Additions
1. **Role-based access control (RBAC)**
   - Use existing Role model to implement fine-grained permissions
   - Define permissions like: view_user, edit_user, delete_user

2. **Audit logging**
   - Log all user profile access attempts
   - Track which manager accessed which user and when

3. **Rate limiting**
   - Prevent abuse of user lookup endpoints
   - Implement per-manager rate limits

4. **Bulk operations**
   - `POST /users/batch` - Lookup multiple users in single request
   - More efficient than multiple individual requests

5. **Field-level permissions**
   - Control which fields managers can see (e.g., hide phoneNumber for certain roles)

---

## Troubleshooting

### Issue: Manager cannot see any users
**Possible Causes:**
1. Manager has no teams created
2. Teams have no active members
3. All members have status='left' or status='pending'

**Resolution:**
- Check `GET /teams` to verify manager has teams
- Check `GET /teams/:teamId/members` to verify active members
- Verify TeamMember status field

### Issue: 404 when accessing valid user
**Possible Causes:**
1. User is not an active member of any of the manager's teams
2. User has status='left' or status='pending'
3. User is a member of a different manager's team

**Resolution:**
- Verify team membership: query TeamMember collection
- Check member status
- Confirm managerId matches

### Issue: Slow query performance
**Possible Causes:**
1. New compound index not created
2. Large number of team members
3. Missing index on User collection

**Resolution:**
- Verify indexes: `db.teammembers.getIndexes()`
- Check query explain plan
- Consider adding pagination limits

---

## Related Files

- `src/middleware/requireTeamMemberAccess.ts` - Authorization middleware
- `src/routes/users.ts` - User endpoints with security
- `src/routes/teams.ts` - Enhanced team members endpoint
- `src/models/teamMember.ts` - Updated with new index
- `tests/user-security.test.md` - Test scenarios

---

## Contact

For questions or issues related to this implementation, refer to:
- Architecture documentation
- Security team
- Backend development team
