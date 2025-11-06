# Load Testing Guide for Event Acceptance

This guide provides **practical, easy-to-use** tools for testing concurrent event acceptances with limited real user accounts.

---

## 🎯 Testing Options (Choose Based on Your Needs)

### Option 1: Quick Duplicate Test (Easiest - Use Your 2 Real Tokens)
**Best for:** Testing duplicate prevention with real users
**Time:** 10 seconds
**Setup:** Minimal

### Option 2: Simulated Users (Recommended - No extra tokens needed)
**Best for:** Testing high concurrency (10-1000 users)
**Time:** 2 minutes
**Setup:** Simple

### Option 3: Manual Click Test (No coding)
**Best for:** Quick visual testing
**Time:** 1 minute
**Setup:** None

---

## Option 1: Quick Duplicate Test ⚡

**What it does:** Sends 10 duplicate requests from the same user to test duplicate prevention.

### Step 1: Get Your JWT Token

1. Open your app in a browser
2. Open DevTools (F12 or Right-click → Inspect)
3. Go to **Application** tab → **Local Storage** or **Session Storage**
4. Find your JWT token (usually stored as `token` or `authToken`)
5. Copy the entire token value

### Step 2: Run the Test

```bash
cd /Volumes/Data/Users/juansuarez/nexa/backend

# Set your token and event ID
export TOKEN="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."  # Your actual token
export EVENT_ID="674b3f8e9a1c2d3e4f5g6h7i"  # Your test event ID
export ROLE="Server"

# Run the test
node scripts/quick-duplicate-test.js
```

### Expected Output:

```
Quick Duplicate Request Test
─────────────────────────────────────────────────

Sending 10 duplicate requests...

Results:
──────────────────────────────────────────────────
  ✅ Request 1: 200 - OK (45ms)
  🚫 Request 2: 409 - You have already accepted this event (23ms)
  🚫 Request 3: 409 - You have already accepted this event (25ms)
  ...

Summary:
──────────────────────────────────────────────────
  Total Requests:     10
  Successful:         1
  Already Accepted:   9

✅ PERFECT: Exactly 1 success, rest rejected as duplicates!
```

**Troubleshooting:**
- If multiple succeed → Duplicate prevention isn't working
- If none succeed → Check event ID or if user already accepted
- If you get 401 error → Token is expired, get a new one

---

## Option 2: Simulated Concurrent Users (Recommended) 🚀

**What it does:** Creates 50-1000 simulated users and has them all accept simultaneously.

### Step 1: Create Test Users (One-Time Setup)

```bash
cd /Volumes/Data/Users/juansuarez/nexa/backend

# Make sure MongoDB is running
# Make sure your .env has MONGO_URI and JWT_SECRET

# Create 100 test users
npm run create-test-users
# Or: NUM_TEST_USERS=100 node scripts/create-test-users.js
```

**Expected output:**
```
✅ Created 100 test users
Test user credentials:
  google:test-user-1
  google:test-user-2
  ...
  google:test-user-100
```

### Step 2: Create a Test Event

1. Open your manager app
2. Create a new event with:
   - **Role:** Server (or any role name)
   - **Capacity:** 10 spots
   - **Status:** Published
3. Copy the event ID

### Step 3: Start Your Backend

```bash
# Make sure backend is running
npm run dev
```

### Step 4: Run the Simulation

```bash
# Set configuration
export TEST_EVENT_ID="674b3f8e9a1c2d3e4f5g6h7i"  # Your event ID
export TEST_ROLE="Server"
export TEST_CAPACITY=10
export TEST_CONCURRENT_USERS=50  # Start with 50

# Run simulation
node scripts/simulate-concurrent-acceptance.js
```

### Expected Output:

```
╔═══════════════════════════════════════════════════════════════╗
║       Concurrent Event Acceptance Simulation                 ║
╚═══════════════════════════════════════════════════════════════╝

Configuration:
  API URL:           http://localhost:3000
  Event ID:          674b3f8e9a1c2d3e4f5g6h7i
  Role:              Server
  Expected Capacity: 10
  Concurrent Users:  50

✅ Backend is running

🚀 Starting simulation in 2 seconds...

📡 Sending 50 concurrent requests...

═══════════════════════════════════════════════════════════════

📊 Results Summary:
─────────────────────────────────────────────────────────────────
  Total Requests:        50
  ✅ Accepted (200):      10       ← Exactly capacity!
  🚫 Capacity Full (409):  40      ← All others rejected!
  ❌ Server Errors (5xx):  0
  🔌 Network Errors:       0

  ⏱️  Total Duration:       156ms

📈 Latency Statistics:
─────────────────────────────────────────────────────────────────
  Min:       12ms
  Average:   45.23ms
  P50:       42ms
  P95:       89ms         ← Should be <500ms
  P99:       125ms
  Max:       156ms

═══════════════════════════════════════════════════════════════
✓ Validation:
─────────────────────────────────────────────────────────────────
  ✅ PERFECT: Exactly 10/10 accepted
  ✅ PASS: 40 requests properly rejected
  ✅ EXCELLENT: P95 latency 89ms < 500ms
  ✅ PASS: No server errors (5xx)
  ✅ PASS: No network errors
═══════════════════════════════════════════════════════════════

📊 Database Verification:
─────────────────────────────────────────────────────────────────
  Event found in database
  Total accepted_staff:  10
  ✅ No duplicate userKeys
  Role stats for "Server":
    Capacity:  10
    Taken:     10
    Remaining: 0
    Is Full:   true
  ✅ role_stats.taken matches successful requests

  Accepted users (first 10):
    1. google:test-user-3 (Server)
    2. google:test-user-7 (Server)
    3. google:test-user-12 (Server)
    ...

═══════════════════════════════════════════════════════════════
🎉 ALL TESTS PASSED!
   Atomic capacity enforcement is working perfectly!
```

### Step 5: Increase the Load

Once you confirm it works with 50 users, ramp up:

```bash
# Test with 100 users
export TEST_CONCURRENT_USERS=100
node scripts/simulate-concurrent-acceptance.js

# Test with 500 users
export TEST_CONCURRENT_USERS=500
node scripts/simulate-concurrent-acceptance.js

# Test with 1000 users (stress test)
export TEST_CONCURRENT_USERS=1000
node scripts/simulate-concurrent-acceptance.js
```

---

## Option 3: Manual Click Test (No Code) 🖱️

**What it does:** Use your browser to rapidly click the accept button.

### Instructions:

1. Open your staff app in browser (not mobile app)
2. Navigate to an event detail page
3. Open browser console (F12)
4. Paste this code:

```javascript
// Rapid fire 20 acceptance clicks
for (let i = 0; i < 20; i++) {
  document.querySelector('button:contains("ACCEPT")').click();
}
```

Or manually:
1. Click the ACCEPT button rapidly 10-20 times
2. Only ONE request should succeed
3. The button should be disabled after first click (loading spinner)

**Expected behavior:**
- ✅ Button shows loading spinner immediately
- ✅ Only 1 acceptance goes through
- ✅ All other clicks are ignored
- ✅ Snackbar shows "Event accept" once

**If multiple acceptances go through:**
- Frontend loading state isn't working
- Check that `_isResponding` state is implemented

---

## Common Issues & Solutions

### Issue: "Backend not reachable"
**Solution:**
```bash
# Make sure backend is running
cd /Volumes/Data/Users/juansuarez/nexa/backend
npm run dev
```

### Issue: "TEST_EVENT_ID not set"
**Solution:**
```bash
# Set the environment variable
export TEST_EVENT_ID="your-event-id-here"

# Or create .env file:
echo "TEST_EVENT_ID=your-event-id-here" >> .env
```

### Issue: "All requests failed with 401"
**Solution:**
- For Option 1: Get a fresh JWT token (they expire)
- For Option 2: Check JWT_SECRET in .env matches your backend

### Issue: "More than capacity accepted"
**Solution:**
- ❌ Atomic operations not deployed correctly
- Check backend code has `findOneAndUpdate` with `$expr`
- Verify transaction wrapper is active
- Run: `git log --oneline -5` to see recent commits

### Issue: "Duplicate userKeys in database"
**Solution:**
- ❌ Duplicate prevention not working
- Check query has `'accepted_staff.userKey': { $ne: userKey }`
- Verify unique index on accepted_staff.userKey

---

## Interpreting Results

### ✅ Perfect Result
```
Successful:        10  (= capacity)
Capacity Full:     40  (= total - capacity)
Server Errors:     0
Duplicates:        0
P95 Latency:       <500ms
```

### ⚠️ Acceptable (with warnings)
```
Successful:        8   (< capacity, but no overflow)
Capacity Full:     42
Server Errors:     0
P95 Latency:       750ms  (acceptable but could optimize)
```

### ❌ Failed Test
```
Successful:        25  (!> capacity) ← CAPACITY OVERFLOW!
Capacity Full:     15
Server Errors:     10  ← BACKEND ERRORS!
Duplicates:        5   ← DUPLICATE PREVENTION FAILED!
```

---

## Quick Reference: Environment Variables

```bash
# Simulation script
export TEST_EVENT_ID="your-event-id"
export TEST_ROLE="Server"
export TEST_CAPACITY=10
export TEST_CONCURRENT_USERS=50
export API_URL="http://localhost:3000"

# Quick duplicate test
export TOKEN="your-jwt-token"
export EVENT_ID="your-event-id"
export ROLE="Server"
export DUPLICATE_REQUESTS=10

# Create test users
export NUM_TEST_USERS=100
export MONGO_URI="mongodb://localhost:27017/nexa"
```

---

## Advanced: Test Different Scenarios

### Scenario 1: Multiple Roles Simultaneously
```bash
# Create event with 10 Servers + 5 Cooks
# Run two tests in parallel

# Terminal 1
export TEST_ROLE="Server"
export TEST_CAPACITY=10
export TEST_CONCURRENT_USERS=50
node scripts/simulate-concurrent-acceptance.js

# Terminal 2 (at same time)
export TEST_ROLE="Cook"
export TEST_CAPACITY=5
export TEST_CONCURRENT_USERS=30
node scripts/simulate-concurrent-acceptance.js
```

### Scenario 2: Stress Test (1000 users)
```bash
export TEST_CONCURRENT_USERS=1000
export TEST_CAPACITY=10

# Expect: Exactly 10 accepted, 990 rejected
node scripts/simulate-concurrent-acceptance.js
```

### Scenario 3: Same User, Different Events
```bash
# Use Option 1 with different EVENT_IDs
export EVENT_ID="event-1-id"
node scripts/quick-duplicate-test.js

export EVENT_ID="event-2-id"
node scripts/quick-duplicate-test.js
```

---

## Next Steps After Testing

### If Tests Pass ✅
1. Deploy to production
2. Monitor real-world usage
3. Set up alerts for capacity overflows
4. Celebrate! 🎉

### If Tests Fail ❌
1. Review backend implementation
2. Check database indexes
3. Verify transaction wrapper
4. Check backend logs for errors
5. Review CONCURRENCY_FIX_SUMMARY.md for troubleshooting

---

## Support

**Need help?**
- Check `CONCURRENCY_FIX_SUMMARY.md` for detailed technical docs
- Review backend logs: `docker compose logs --tail=100 api`
- Query database: `db.events.findOne({_id: ObjectId("event-id")})`
