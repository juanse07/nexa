/**
 * Simulate Concurrent Event Acceptances
 *
 * This script simulates multiple users accepting an event by making
 * direct HTTP requests with generated JWT tokens for test users.
 *
 * Prerequisites:
 * 1. Run create-test-users.js first
 * 2. Create a test event and note its ID
 * 3. Set environment variables (see below)
 *
 * Usage:
 *   node scripts/simulate-concurrent-acceptance.js
 */

require('dotenv').config();
const jwt = require('jsonwebtoken');
const axios = require('axios');

// ============================================================================
// CONFIGURATION
// ============================================================================

const CONFIG = {
  apiUrl: process.env.API_URL || 'http://localhost:4000',
  jwtSecret: process.env.BACKEND_JWT_SECRET || process.env.JWT_SECRET || 'your-secret-key',
  eventId: process.env.TEST_EVENT_ID || '',
  roleName: process.env.TEST_ROLE || 'Server',
  capacity: parseInt(process.env.TEST_CAPACITY) || 10,
  concurrentUsers: parseInt(process.env.TEST_CONCURRENT_USERS) || 50,
};

// ============================================================================
// GENERATE JWT FOR TEST USER
// ============================================================================

function generateTestUserToken(userId) {
  const payload = {
    provider: 'google',
    sub: `test-user-${userId}`,
    email: `testuser${userId}@loadtest.example.com`,
    name: `Test User ${userId}`,
    iat: Math.floor(Date.now() / 1000),
    exp: Math.floor(Date.now() / 1000) + (60 * 60), // 1 hour
  };

  return jwt.sign(payload, CONFIG.jwtSecret, { algorithm: 'HS256' });
}

// ============================================================================
// MAKE ACCEPTANCE REQUEST
// ============================================================================

async function acceptEvent(userId) {
  const token = generateTestUserToken(userId);
  const startTime = Date.now();

  try {
    const response = await axios({
      method: 'POST',
      url: `${CONFIG.apiUrl}/api/events/${CONFIG.eventId}/respond`,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${token}`,
      },
      data: {
        response: 'accept',
        role: CONFIG.roleName,
      },
      timeout: 10000,
      validateStatus: () => true, // Don't throw on any status
    });

    const latency = Date.now() - startTime;

    return {
      userId,
      success: response.status === 200,
      statusCode: response.status,
      latency,
      message: response.data?.message || 'OK',
      userKey: `google:test-user-${userId}`,
    };

  } catch (error) {
    const latency = Date.now() - startTime;
    return {
      userId,
      success: false,
      statusCode: 0,
      latency,
      message: error.message,
      userKey: `google:test-user-${userId}`,
    };
  }
}

// ============================================================================
// QUERY EVENT FROM DATABASE
// ============================================================================

async function queryEventFromDB() {
  const mongoose = require('mongoose');

  try {
    await mongoose.connect(process.env.MONGO_URI || 'mongodb://localhost:27017/nexa');

    const EventSchema = new mongoose.Schema({}, { strict: false });
    const Event = mongoose.models.Event || mongoose.model('Event', EventSchema);

    const event = await Event.findById(CONFIG.eventId).lean();

    await mongoose.disconnect();

    return event;

  } catch (error) {
    console.error('Error querying database:', error.message);
    return null;
  }
}

// ============================================================================
// MAIN TEST FUNCTION
// ============================================================================

async function runSimulation() {
  console.log('\n╔═══════════════════════════════════════════════════════════════╗');
  console.log('║       Concurrent Event Acceptance Simulation                 ║');
  console.log('╚═══════════════════════════════════════════════════════════════╝\n');

  // Validation
  if (!CONFIG.eventId) {
    console.error('❌ ERROR: TEST_EVENT_ID not set!\n');
    console.error('Setup:');
    console.error('  1. Create a test event in your app');
    console.error('  2. Copy the event ID');
    console.error('  3. Run: export TEST_EVENT_ID=your-event-id\n');
    process.exit(1);
  }

  console.log('Configuration:');
  console.log(`  API URL:           ${CONFIG.apiUrl}`);
  console.log(`  Event ID:          ${CONFIG.eventId}`);
  console.log(`  Role:              ${CONFIG.roleName}`);
  console.log(`  Expected Capacity: ${CONFIG.capacity}`);
  console.log(`  Concurrent Users:  ${CONFIG.concurrentUsers}`);
  console.log('');

  // Check if backend is running (skip health check, just proceed)
  console.log('Assuming backend is running at', CONFIG.apiUrl);
  console.log('');

  console.log('🚀 Starting simulation in 2 seconds...\n');
  await sleep(2000);

  const startTime = Date.now();

  // Launch all requests concurrently
  console.log(`📡 Sending ${CONFIG.concurrentUsers} concurrent requests...\n`);

  const promises = [];
  for (let i = 1; i <= CONFIG.concurrentUsers; i++) {
    promises.push(acceptEvent(i));
  }

  const results = await Promise.all(promises);

  const endTime = Date.now();
  const totalDuration = endTime - startTime;

  // ============================================================================
  // ANALYZE RESULTS
  // ============================================================================

  console.log('═'.repeat(65) + '\n');

  const successful = results.filter(r => r.success);
  const capacityFull = results.filter(r => r.statusCode === 409);
  const alreadyAccepted = results.filter(r => r.message?.includes('already accepted'));
  const errors = results.filter(r => r.statusCode >= 500);
  const networkErrors = results.filter(r => r.statusCode === 0);
  const otherFailures = results.filter(r =>
    !r.success && r.statusCode !== 409 && r.statusCode < 500 && r.statusCode !== 0
  );

  console.log('📊 Results Summary:');
  console.log('─'.repeat(65));
  console.log(`  Total Requests:        ${CONFIG.concurrentUsers}`);
  console.log(`  ✅ Accepted (200):      ${successful.length}`);
  console.log(`  🚫 Capacity Full (409):  ${capacityFull.length}`);
  console.log(`  ⚠️  Already Accepted:    ${alreadyAccepted.length}`);
  console.log(`  ❌ Server Errors (5xx):  ${errors.length}`);
  console.log(`  🔌 Network Errors:       ${networkErrors.length}`);
  console.log(`  ⚡ Other Failures:       ${otherFailures.length}`);
  console.log('');
  console.log(`  ⏱️  Total Duration:       ${totalDuration}ms`);

  // Latency statistics
  const latencies = results.map(r => r.latency).sort((a, b) => a - b);
  const avgLatency = latencies.reduce((a, b) => a + b, 0) / latencies.length;
  const minLatency = latencies[0];
  const maxLatency = latencies[latencies.length - 1];
  const p50 = latencies[Math.floor(latencies.length * 0.5)];
  const p95 = latencies[Math.floor(latencies.length * 0.95)];
  const p99 = latencies[Math.floor(latencies.length * 0.99)];

  console.log('');
  console.log('📈 Latency Statistics:');
  console.log('─'.repeat(65));
  console.log(`  Min:       ${minLatency}ms`);
  console.log(`  Average:   ${avgLatency.toFixed(2)}ms`);
  console.log(`  P50:       ${p50}ms`);
  console.log(`  P95:       ${p95}ms`);
  console.log(`  P99:       ${p99}ms`);
  console.log(`  Max:       ${maxLatency}ms`);

  // ============================================================================
  // VALIDATION
  // ============================================================================

  console.log('\n' + '═'.repeat(65));
  console.log('✓ Validation:');
  console.log('─'.repeat(65));

  let allPassed = true;
  const warnings = [];

  // Check 1: Capacity enforcement
  if (successful.length === CONFIG.capacity) {
    console.log(`  ✅ PERFECT: Exactly ${successful.length}/${CONFIG.capacity} accepted`);
  } else if (successful.length < CONFIG.capacity) {
    console.log(`  ✅ PASS: ${successful.length}/${CONFIG.capacity} accepted (under capacity)`);
    warnings.push(`Only ${successful.length} out of ${CONFIG.capacity} spots filled`);
  } else {
    console.log(`  ❌ FAIL: CAPACITY OVERFLOW! ${successful.length}/${CONFIG.capacity} accepted`);
    allPassed = false;
  }

  // Check 2: Proper rejections
  const expectedRejections = Math.max(0, CONFIG.concurrentUsers - CONFIG.capacity);
  const actualRejections = capacityFull.length;
  const rejectionMatch = actualRejections >= expectedRejections * 0.95; // 95% match

  if (rejectionMatch) {
    console.log(`  ✅ PASS: ${actualRejections} requests properly rejected`);
  } else {
    console.log(`  ⚠️  WARNING: Expected ~${expectedRejections} rejections, got ${actualRejections}`);
    warnings.push(`Rejection count mismatch`);
  }

  // Check 3: Performance
  if (p95 < 500) {
    console.log(`  ✅ EXCELLENT: P95 latency ${p95}ms < 500ms`);
  } else if (p95 < 1000) {
    console.log(`  ⚠️  ACCEPTABLE: P95 latency ${p95}ms < 1000ms`);
    warnings.push(`Performance could be optimized`);
  } else {
    console.log(`  ❌ SLOW: P95 latency ${p95}ms > 1000ms`);
    allPassed = false;
  }

  // Check 4: No server errors
  if (errors.length === 0) {
    console.log(`  ✅ PASS: No server errors (5xx)`);
  } else {
    console.log(`  ❌ FAIL: ${errors.length} server errors occurred`);
    allPassed = false;
  }

  // Check 5: No network errors
  if (networkErrors.length === 0) {
    console.log(`  ✅ PASS: No network errors`);
  } else {
    console.log(`  ❌ FAIL: ${networkErrors.length} network errors`);
    allPassed = false;
  }

  console.log('═'.repeat(65));

  // ============================================================================
  // DATABASE VERIFICATION
  // ============================================================================

  console.log('\n📊 Database Verification:');
  console.log('─'.repeat(65));

  const event = await queryEventFromDB();

  if (event) {
    const acceptedStaff = event.accepted_staff || [];
    const roleStats = event.role_stats || [];

    console.log(`  Event found in database`);
    console.log(`  Total accepted_staff:  ${acceptedStaff.length}`);

    // Check for duplicates
    const userKeys = acceptedStaff.map(s => s.userKey);
    const uniqueUserKeys = new Set(userKeys);

    if (userKeys.length === uniqueUserKeys.size) {
      console.log(`  ✅ No duplicate userKeys`);
    } else {
      console.log(`  ❌ DUPLICATES FOUND: ${userKeys.length} entries, ${uniqueUserKeys.size} unique`);
      allPassed = false;
    }

    // Check role stats
    const targetRoleStat = roleStats.find(s => s.role === CONFIG.roleName);
    if (targetRoleStat) {
      console.log(`  Role stats for "${CONFIG.roleName}":`);
      console.log(`    Capacity:  ${targetRoleStat.capacity}`);
      console.log(`    Taken:     ${targetRoleStat.taken}`);
      console.log(`    Remaining: ${targetRoleStat.remaining}`);
      console.log(`    Is Full:   ${targetRoleStat.is_full}`);

      if (targetRoleStat.taken === successful.length) {
        console.log(`  ✅ role_stats.taken matches successful requests`);
      } else {
        console.log(`  ⚠️  role_stats.taken (${targetRoleStat.taken}) != successful (${successful.length})`);
        warnings.push('role_stats mismatch');
      }
    }

    // List accepted users
    console.log('\n  Accepted users (first 10):');
    acceptedStaff.slice(0, 10).forEach((staff, i) => {
      console.log(`    ${i + 1}. ${staff.userKey} (${staff.role})`);
    });
    if (acceptedStaff.length > 10) {
      console.log(`    ... and ${acceptedStaff.length - 10} more`);
    }

  } else {
    console.log('  ⚠️  Could not query event from database');
    warnings.push('Database query failed');
  }

  // ============================================================================
  // FINAL RESULT
  // ============================================================================

  console.log('\n' + '═'.repeat(65));

  if (allPassed && warnings.length === 0) {
    console.log('🎉 ALL TESTS PASSED!');
    console.log('   Atomic capacity enforcement is working perfectly!\n');
  } else if (allPassed) {
    console.log('✅ TEST PASSED (with warnings)');
    warnings.forEach(w => console.log(`   ⚠️  ${w}`));
    console.log('');
  } else {
    console.log('❌ TEST FAILED!');
    console.log('   Review the results above for details.\n');

    // Show sample failures
    if (errors.length > 0) {
      console.log('Sample server errors:');
      errors.slice(0, 3).forEach(r => {
        console.log(`  User ${r.userId}: ${r.statusCode} - ${r.message}`);
      });
      console.log('');
    }

    if (otherFailures.length > 0) {
      console.log('Sample other failures:');
      otherFailures.slice(0, 3).forEach(r => {
        console.log(`  User ${r.userId}: ${r.statusCode} - ${r.message}`);
      });
      console.log('');
    }
  }

  // ============================================================================
  // RECOMMENDATIONS
  // ============================================================================

  console.log('💡 Next Steps:');
  console.log('─'.repeat(65));

  if (allPassed) {
    console.log('  ✅ System is working correctly!');
    console.log('');
    console.log('  Try increasing load:');
    console.log('    → export TEST_CONCURRENT_USERS=100');
    console.log('    → export TEST_CONCURRENT_USERS=500');
    console.log('    → export TEST_CONCURRENT_USERS=1000');
    console.log('');
    console.log('  Test different scenarios:');
    console.log('    → Create event with multiple roles');
    console.log('    → Test with different capacities');
  } else {
    console.log('  ❌ Issues detected! Debug steps:');
    console.log('');
    console.log('  1. Check backend logs:');
    console.log('     → Look for "[respond]" log entries');
    console.log('     → Check for transaction errors');
    console.log('');
    console.log('  2. Verify database state:');
    console.log('     → mongo');
    console.log('     → use nexa');
    console.log('     → db.events.findOne({_id: ObjectId("' + CONFIG.eventId + '")})');
    console.log('');
    console.log('  3. Check atomic operations:');
    console.log('     → Verify findOneAndUpdate with $expr is deployed');
    console.log('     → Check transaction wrapper is active');
  }

  console.log('═'.repeat(65) + '\n');

  process.exit(allPassed ? 0 : 1);
}

// ============================================================================
// UTILITY
// ============================================================================

function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

// ============================================================================
// RUN
// ============================================================================

runSimulation().catch(error => {
  console.error('\n❌ Simulation failed:', error.message);
  console.error(error.stack);
  process.exit(1);
});
