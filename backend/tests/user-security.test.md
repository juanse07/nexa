# User Collection Security Test Plan

## Overview
This document outlines the test scenarios to verify that the users collection is properly secured and managers can only access users who are active members of their teams.

## Prerequisites
1. Two manager accounts (Manager A and Manager B)
2. Multiple user accounts
3. Teams set up with different members
4. Manager authentication tokens

## Test Scenarios

### 1. GET /users/me Endpoint

#### Test 1.1: Regular User Can Access Own Profile
**Setup:**
- User authenticated with regular user JWT (no managerId)
- User has completed profile

**Request:**
```http
GET /users/me
Authorization: Bearer <user_jwt_token>
```

**Expected Result:**
- ✅ Status: 200 OK
- ✅ Returns user's own profile data
- ✅ Response includes: id, email, name, firstName, lastName, phoneNumber, picture, appId

#### Test 1.2: Manager Cannot Use /users/me
**Setup:**
- Manager authenticated with manager JWT (has managerId)

**Request:**
```http
GET /users/me
Authorization: Bearer <manager_jwt_token>
```

**Expected Result:**
- ✅ Status: 403 Forbidden
- ✅ Error message: "Manager authentication not allowed"
- ✅ Details: "Managers should use /managers/me endpoint for their profile"

---

### 2. GET /users Endpoint (List Users)

#### Test 2.1: Manager Sees Only Team Members
**Setup:**
- Manager A has Team Alpha with users: user1@example.com, user2@example.com
- Manager A has Team Beta with users: user2@example.com, user3@example.com
- There exists user4@example.com who is NOT in any of Manager A's teams

**Request:**
```http
GET /users?limit=20
Authorization: Bearer <manager_a_jwt_token>
```

**Expected Result:**
- ✅ Status: 200 OK
- ✅ Returns only: user1, user2, user3 (team members)
- ✅ Does NOT return: user4 (not a team member)
- ✅ Includes phoneNumber field in results

#### Test 2.2: Search Only Returns Team Members
**Setup:**
- Same as Test 2.1
- user4@example.com has firstName="Alice"
- user1@example.com has firstName="Albert"

**Request:**
```http
GET /users?q=Al&limit=20
Authorization: Bearer <manager_a_jwt_token>
```

**Expected Result:**
- ✅ Status: 200 OK
- ✅ Returns only: user1 (Albert - team member matching "Al")
- ✅ Does NOT return: user4 (Alice - matches "Al" but not a team member)

#### Test 2.3: Pagination Works Within Team Members
**Setup:**
- Manager A has 50 team members across all teams

**Request:**
```http
GET /users?limit=20
Authorization: Bearer <manager_a_jwt_token>
```

**Expected Result:**
- ✅ Status: 200 OK
- ✅ Returns 20 items
- ✅ Includes nextCursor for pagination
- ✅ All returned users are team members

**Follow-up Request:**
```http
GET /users?limit=20&cursor=<nextCursor>
Authorization: Bearer <manager_a_jwt_token>
```

**Expected Result:**
- ✅ Returns next batch of team members
- ✅ No duplicates from first batch

#### Test 2.4: Manager Without Teams Returns Empty
**Setup:**
- Manager C has no teams created

**Request:**
```http
GET /users?limit=20
Authorization: Bearer <manager_c_jwt_token>
```

**Expected Result:**
- ✅ Status: 200 OK
- ✅ Returns empty array: `{ "items": [], "nextCursor": undefined }`

#### Test 2.5: Regular User Cannot Access /users
**Setup:**
- Regular user (not manager) attempts to list users

**Request:**
```http
GET /users
Authorization: Bearer <user_jwt_token>
```

**Expected Result:**
- ✅ Status: 403 Forbidden
- ✅ Error: "Manager authentication required"

---

### 3. GET /users/:userId Endpoint

#### Test 3.1: Manager Can Access Team Member Profile
**Setup:**
- user1 is a member of Manager A's Team Alpha
- user1 has ObjectId: `507f1f77bcf86cd799439011`

**Request:**
```http
GET /users/507f1f77bcf86cd799439011
Authorization: Bearer <manager_a_jwt_token>
```

**Expected Result:**
- ✅ Status: 200 OK
- ✅ Returns full user profile including phoneNumber
- ✅ Response includes: id, provider, subject, email, name, firstName, lastName, phoneNumber, picture, appId

#### Test 3.2: Manager Cannot Access Non-Team Member
**Setup:**
- user4 is NOT a member of any of Manager A's teams
- user4 has ObjectId: `507f1f77bcf86cd799439022`

**Request:**
```http
GET /users/507f1f77bcf86cd799439022
Authorization: Bearer <manager_a_jwt_token>
```

**Expected Result:**
- ✅ Status: 404 Not Found (NOT 403 - security through obscurity)
- ✅ Error: "User not found"
- ✅ Does NOT leak information about user existence

#### Test 3.3: Invalid User ID Format
**Request:**
```http
GET /users/invalid-id-format
Authorization: Bearer <manager_a_jwt_token>
```

**Expected Result:**
- ✅ Status: 400 Bad Request
- ✅ Error: "Invalid user ID format"

#### Test 3.4: Non-existent User ID
**Request:**
```http
GET /users/507f1f77bcf86cd799439099
Authorization: Bearer <manager_a_jwt_token>
```

**Expected Result:**
- ✅ Status: 404 Not Found
- ✅ Error: "User not found"

---

### 4. GET /users/by-identity Endpoint

#### Test 4.1: Manager Can Lookup Team Member by OAuth Identity
**Setup:**
- user1 has provider='google', subject='12345678901234567890'
- user1 is a member of Manager A's Team Alpha

**Request:**
```http
GET /users/by-identity?provider=google&subject=12345678901234567890
Authorization: Bearer <manager_a_jwt_token>
```

**Expected Result:**
- ✅ Status: 200 OK
- ✅ Returns full user profile
- ✅ Includes all fields: id, provider, subject, email, name, firstName, lastName, phoneNumber, picture, appId

#### Test 4.2: Manager Cannot Lookup Non-Team Member
**Setup:**
- user4 has provider='google', subject='99999999999999999999'
- user4 is NOT a member of any of Manager A's teams

**Request:**
```http
GET /users/by-identity?provider=google&subject=99999999999999999999
Authorization: Bearer <manager_a_jwt_token>
```

**Expected Result:**
- ✅ Status: 404 Not Found (NOT 403)
- ✅ Error: "User not found"
- ✅ Does NOT leak information about user existence

#### Test 4.3: Missing Query Parameters
**Request:**
```http
GET /users/by-identity?provider=google
Authorization: Bearer <manager_a_jwt_token>
```

**Expected Result:**
- ✅ Status: 400 Bad Request
- ✅ Error: "Missing or invalid query parameters"
- ✅ Details: "Both provider and subject are required as strings"

#### Test 4.4: Non-existent User Identity
**Request:**
```http
GET /users/by-identity?provider=google&subject=00000000000000000000
Authorization: Bearer <manager_a_jwt_token>
```

**Expected Result:**
- ✅ Status: 404 Not Found
- ✅ Error: "User not found"

---

### 5. GET /teams/:teamId/members Endpoint Enhancement

#### Test 5.1: Get Team Members Without User Profiles (Default)
**Setup:**
- Manager A's Team Alpha has 3 members

**Request:**
```http
GET /teams/<team_alpha_id>/members
Authorization: Bearer <manager_a_jwt_token>
```

**Expected Result:**
- ✅ Status: 200 OK
- ✅ Returns members array with TeamMember data only
- ✅ Each member includes: id, teamId, provider, subject, email, name, status, joinedAt, createdAt
- ✅ Does NOT include userProfile field

#### Test 5.2: Get Team Members With User Profiles
**Setup:**
- Manager A's Team Alpha has 3 members
- All members have completed user profiles with phoneNumber

**Request:**
```http
GET /teams/<team_alpha_id>/members?includeUserProfile=true
Authorization: Bearer <manager_a_jwt_token>
```

**Expected Result:**
- ✅ Status: 200 OK
- ✅ Returns members array with TeamMember data
- ✅ Each member includes userProfile object with:
  - id, provider, subject, email, name, firstName, lastName, phoneNumber, picture, appId
- ✅ userProfile is null for members who haven't registered as users yet

#### Test 5.3: User Profile Join for Pending Members
**Setup:**
- Team Beta has a pending invite for user5@example.com
- user5 has NOT yet accepted the invite (no User document exists)

**Request:**
```http
GET /teams/<team_beta_id>/members?includeUserProfile=true
Authorization: Bearer <manager_a_jwt_token>
```

**Expected Result:**
- ✅ Status: 200 OK
- ✅ Returns pending member with userProfile: null

---

### 6. Cross-Manager Isolation Tests

#### Test 6.1: Manager B Cannot See Manager A's Team Members
**Setup:**
- Manager A has user1, user2, user3 in their teams
- Manager B has user5, user6 in their teams
- user1 is NOT in any of Manager B's teams

**Request (Manager B trying to access user1):**
```http
GET /users/by-identity?provider=google&subject=<user1_subject>
Authorization: Bearer <manager_b_jwt_token>
```

**Expected Result:**
- ✅ Status: 404 Not Found
- ✅ Error: "User not found"
- ✅ Manager B CANNOT see user1's data

#### Test 6.2: Shared User Across Managers
**Setup:**
- user7 is a member of BOTH Manager A's Team Alpha AND Manager B's Team Gamma

**Request from Manager A:**
```http
GET /users/by-identity?provider=google&subject=<user7_subject>
Authorization: Bearer <manager_a_jwt_token>
```

**Expected Result:**
- ✅ Status: 200 OK
- ✅ Returns user7's profile

**Request from Manager B:**
```http
GET /users/by-identity?provider=google&subject=<user7_subject>
Authorization: Bearer <manager_b_jwt_token>
```

**Expected Result:**
- ✅ Status: 200 OK
- ✅ Returns user7's profile
- ✅ Both managers can access because user7 is in their respective teams

---

### 7. Team Member Status Tests

#### Test 7.1: Left Members Are Not Accessible
**Setup:**
- user8 was previously a member of Manager A's Team Alpha
- user8's status changed to 'left'

**Request:**
```http
GET /users/by-identity?provider=google&subject=<user8_subject>
Authorization: Bearer <manager_a_jwt_token>
```

**Expected Result:**
- ✅ Status: 404 Not Found
- ✅ Error: "User not found"
- ✅ Left members are NOT accessible (only 'active' members)

#### Test 7.2: Pending Members Are Not Accessible
**Setup:**
- user9 has a pending invitation to Manager A's Team Alpha
- user9's status is 'pending'

**Request:**
```http
GET /users/by-identity?provider=google&subject=<user9_subject>
Authorization: Bearer <manager_a_jwt_token>
```

**Expected Result:**
- ✅ Status: 404 Not Found
- ✅ Error: "User not found"
- ✅ Only 'active' members are accessible

---

### 8. Performance Tests

#### Test 8.1: Index Usage Verification
**Setup:**
- Manager A has 1000 active team members across 10 teams

**Test:**
1. Run query: `GET /users?limit=20`
2. Check MongoDB explain plan

**Expected Result:**
- ✅ Query uses index: `{ managerId: 1, status: 1, provider: 1, subject: 1 }`
- ✅ Query execution time < 100ms
- ✅ Index covers the query (IXSCAN, not COLLSCAN)

#### Test 8.2: Authorization Check Performance
**Setup:**
- Manager A has 1000 active team members

**Test:**
1. Run query: `GET /users/by-identity?provider=google&subject=<subject>`
2. Measure authorization check time

**Expected Result:**
- ✅ Authorization check (canAccessUser) uses indexed query
- ✅ Response time < 50ms

---

## Database Index Verification

### Check Indexes on TeamMember Collection
```javascript
db.teammembers.getIndexes()
```

**Expected Indexes:**
1. `{ teamId: 1, provider: 1, subject: 1 }` - unique
2. `{ provider: 1, subject: 1, status: 1 }`
3. `{ managerId: 1, status: 1, provider: 1, subject: 1 }` - NEW for authorization
4. `{ teamId: 1 }`
5. `{ managerId: 1 }`

---

## Security Verification Checklist

- ✅ Managers can ONLY see users who are active members of their teams
- ✅ Managers CANNOT see users from other managers' teams (unless shared)
- ✅ Regular users CANNOT access the /users listing endpoint
- ✅ Unauthorized access returns 404 (not 403) to avoid information leakage
- ✅ Left members are treated as inaccessible
- ✅ Pending members are treated as inaccessible
- ✅ Manager authentication is required for all user lookup endpoints
- ✅ Regular user authentication is blocked from manager-only endpoints
- ✅ All queries are indexed for performance
- ✅ Authorization checks happen before data retrieval where possible

---

## Automated Test Script Location
`backend/tests/user-security.test.ts` (if using Jest/Mocha)

## Manual Testing Checklist
Copy this checklist for manual testing sessions:

- [ ] Test 1.1 - Regular user profile access
- [ ] Test 1.2 - Manager blocked from /users/me
- [ ] Test 2.1 - Manager sees only team members
- [ ] Test 2.2 - Search filtered by team membership
- [ ] Test 2.3 - Pagination works correctly
- [ ] Test 2.4 - Manager without teams gets empty result
- [ ] Test 2.5 - Regular user blocked from /users
- [ ] Test 3.1 - Manager accesses team member by ID
- [ ] Test 3.2 - Manager blocked from non-team member
- [ ] Test 3.3 - Invalid ID format rejected
- [ ] Test 4.1 - Manager looks up team member by identity
- [ ] Test 4.2 - Manager blocked from non-team member lookup
- [ ] Test 4.3 - Missing parameters rejected
- [ ] Test 5.1 - Team members without profiles
- [ ] Test 5.2 - Team members with profiles
- [ ] Test 6.1 - Cross-manager isolation verified
- [ ] Test 6.2 - Shared user accessible to both managers
- [ ] Test 7.1 - Left members inaccessible
- [ ] Test 7.2 - Pending members inaccessible
- [ ] Test 8.1 - Index usage verified
- [ ] Test 8.2 - Authorization performance acceptable
