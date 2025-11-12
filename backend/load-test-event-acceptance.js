/**
 * Load Testing Script for Event Acceptance Concurrency
 *
 * This script simulates 1000 concurrent users accepting an event simultaneously
 * to validate that the atomic capacity enforcement works correctly.
 *
 * Usage:
 *   node load-test-event-acceptance.js <eventId> <roleName> <capacity> [concurrentUsers]
 *
 * Example:
 *   node load-test-event-acceptance.js 674b3f8e9a1c2d3e4f5g6h7i "Server" 10 1000
 */

const https = require('https');
const http = require('http');

// Configuration
const API_BASE_URL = process.env.API_URL || 'http://localhost:3000';
const EVENT_ID = process.argv[2];
const ROLE_NAME = process.argv[3];
const EXPECTED_CAPACITY = parseInt(process.argv[4]) || 10;
const CONCURRENT_USERS = parseInt(process.argv[5]) || 1000;

if (!EVENT_ID || !ROLE_NAME) {
  console.error('Usage: node load-test-event-acceptance.js <eventId> <roleName> <capacity> [concurrentUsers]');
  console.error('Example: node load-test-event-acceptance.js 674b3f8e9a1c2d3e4f5g6h7i "Server" 10 1000');
  process.exit(1);
}

// Generate mock JWT tokens for test users
function generateMockToken(userId) {
  // In production, these would be real OAuth tokens
  // For testing, we'll use a simple mock format
  const mockUser = {
    provider: 'google',
    sub: `test-user-${userId}`,
    email: `testuser${userId}@example.com`,
    name: `Test User ${userId}`,
  };

  // This is a mock - in real testing you'd generate actual JWT tokens
  // using your JWT_SECRET from environment
  return Buffer.from(JSON.stringify(mockUser)).toString('base64');
}

// Make HTTP request
function makeRequest(userId) {
  return new Promise((resolve) => {
    const url = new URL(`${API_BASE_URL}/api/events/${EVENT_ID}/respond`);
    const isHttps = url.protocol === 'https:';
    const httpModule = isHttps ? https : http;

    const postData = JSON.stringify({
      response: 'accept',
      role: ROLE_NAME,
    });

    const options = {
      hostname: url.hostname,
      port: url.port || (isHttps ? 443 : 80),
      path: url.pathname,
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(postData),
        'Authorization': `Bearer ${generateMockToken(userId)}`,
      },
    };

    const startTime = Date.now();

    const req = httpModule.request(options, (res) => {
      let data = '';

      res.on('data', (chunk) => {
        data += chunk;
      });

      res.on('end', () => {
        const endTime = Date.now();
        const latency = endTime - startTime;

        resolve({
          userId,
          statusCode: res.statusCode,
          latency,
          success: res.statusCode === 200,
          error: res.statusCode !== 200 ? data : null,
        });
      });
    });

    req.on('error', (error) => {
      const endTime = Date.now();
      const latency = endTime - startTime;

      resolve({
        userId,
        statusCode: 0,
        latency,
        success: false,
        error: error.message,
      });
    });

    req.write(postData);
    req.end();
  });
}

// Run load test
async function runLoadTest() {
  console.log('═══════════════════════════════════════════════════════════════');
  console.log('  Event Acceptance Concurrency Load Test');
  console.log('═══════════════════════════════════════════════════════════════');
  console.log(`API URL:            ${API_BASE_URL}`);
  console.log(`Event ID:           ${EVENT_ID}`);
  console.log(`Role:               ${ROLE_NAME}`);
  console.log(`Expected Capacity:  ${EXPECTED_CAPACITY}`);
  console.log(`Concurrent Users:   ${CONCURRENT_USERS}`);
  console.log('═══════════════════════════════════════════════════════════════\n');

  console.log('Starting load test...\n');

  const startTime = Date.now();

  // Launch all requests concurrently
  const promises = [];
  for (let i = 1; i <= CONCURRENT_USERS; i++) {
    promises.push(makeRequest(i));
  }

  // Wait for all requests to complete
  const results = await Promise.all(promises);

  const endTime = Date.now();
  const totalDuration = endTime - startTime;

  // Analyze results
  const successful = results.filter(r => r.success);
  const failed = results.filter(r => !r.success);
  const capacityFull = results.filter(r => r.statusCode === 409);
  const alreadyAccepted = results.filter(r => r.statusCode === 409 && r.error?.includes('already accepted'));
  const networkErrors = results.filter(r => r.statusCode === 0);

  const latencies = results.map(r => r.latency).sort((a, b) => a - b);
  const p50 = latencies[Math.floor(latencies.length * 0.5)];
  const p95 = latencies[Math.floor(latencies.length * 0.95)];
  const p99 = latencies[Math.floor(latencies.length * 0.99)];
  const avgLatency = latencies.reduce((a, b) => a + b, 0) / latencies.length;

  // Print results
  console.log('\n═══════════════════════════════════════════════════════════════');
  console.log('  Test Results');
  console.log('═══════════════════════════════════════════════════════════════');
  console.log(`Total Requests:        ${CONCURRENT_USERS}`);
  console.log(`Successful (200):      ${successful.length}`);
  console.log(`Capacity Full (409):   ${capacityFull.length}`);
  console.log(`Already Accepted:      ${alreadyAccepted.length}`);
  console.log(`Network Errors:        ${networkErrors.length}`);
  console.log(`Other Failures:        ${failed.length - capacityFull.length - networkErrors.length}`);
  console.log('');
  console.log(`Total Duration:        ${totalDuration}ms`);
  console.log(`Avg Latency:           ${avgLatency.toFixed(2)}ms`);
  console.log(`P50 Latency:           ${p50}ms`);
  console.log(`P95 Latency:           ${p95}ms`);
  console.log(`P99 Latency:           ${p99}ms`);
  console.log('═══════════════════════════════════════════════════════════════\n');

  // Validation
  console.log('═══════════════════════════════════════════════════════════════');
  console.log('  Validation');
  console.log('═══════════════════════════════════════════════════════════════');

  const validationResults = [];

  // Check 1: Exactly EXPECTED_CAPACITY acceptances (no more, no less if enough users)
  if (successful.length === EXPECTED_CAPACITY) {
    console.log(`✅ PASS: Exactly ${EXPECTED_CAPACITY} users accepted (expected)`);
    validationResults.push(true);
  } else if (successful.length < EXPECTED_CAPACITY && CONCURRENT_USERS < EXPECTED_CAPACITY) {
    console.log(`✅ PASS: ${successful.length} users accepted (fewer users than capacity)`);
    validationResults.push(true);
  } else {
    console.log(`❌ FAIL: ${successful.length} users accepted (expected ${EXPECTED_CAPACITY})`);
    validationResults.push(false);
  }

  // Check 2: All other requests should be rejected with 409 (capacity full)
  const expectedRejections = CONCURRENT_USERS - EXPECTED_CAPACITY;
  if (capacityFull.length === expectedRejections) {
    console.log(`✅ PASS: ${capacityFull.length} requests rejected (capacity full)`);
    validationResults.push(true);
  } else {
    console.log(`❌ FAIL: ${capacityFull.length} requests rejected (expected ${expectedRejections})`);
    validationResults.push(false);
  }

  // Check 3: No duplicate acceptances (would require querying the database)
  console.log(`ℹ️  INFO: Verify no duplicate userKeys in accepted_staff (requires DB query)`);

  // Check 4: Reasonable latency under load
  if (p95 < 500) {
    console.log(`✅ PASS: P95 latency ${p95}ms < 500ms (acceptable under load)`);
    validationResults.push(true);
  } else if (p95 < 1000) {
    console.log(`⚠️  WARN: P95 latency ${p95}ms < 1000ms (acceptable but could be optimized)`);
    validationResults.push(true);
  } else {
    console.log(`❌ FAIL: P95 latency ${p95}ms > 1000ms (too slow under load)`);
    validationResults.push(false);
  }

  // Check 5: No network errors
  if (networkErrors.length === 0) {
    console.log(`✅ PASS: No network errors`);
    validationResults.push(true);
  } else {
    console.log(`❌ FAIL: ${networkErrors.length} network errors occurred`);
    validationResults.push(false);
  }

  console.log('═══════════════════════════════════════════════════════════════\n');

  // Overall result
  const allPassed = validationResults.every(r => r === true);
  if (allPassed) {
    console.log('🎉 ALL TESTS PASSED! Atomic capacity enforcement is working correctly.\n');
    process.exit(0);
  } else {
    console.log('❌ SOME TESTS FAILED! Review the results above.\n');

    // Show sample failures for debugging
    console.log('Sample failure details:');
    failed.slice(0, 5).forEach((result) => {
      console.log(`  User ${result.userId}: ${result.statusCode} - ${result.error?.substring(0, 100)}`);
    });

    process.exit(1);
  }
}

// Run the test
runLoadTest().catch((error) => {
  console.error('Load test failed with error:', error);
  process.exit(1);
});
