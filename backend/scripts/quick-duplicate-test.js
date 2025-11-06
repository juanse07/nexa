/**
 * Quick Duplicate Acceptance Test
 *
 * This tests duplicate prevention by sending the same user's request
 * multiple times rapidly (simulating double-clicks or network retries).
 *
 * Usage:
 *   1. Get a real JWT token from your app
 *   2. Run: TOKEN=your-jwt-token EVENT_ID=event-id node scripts/quick-duplicate-test.js
 */

require('dotenv').config();
const axios = require('axios');

const CONFIG = {
  apiUrl: process.env.API_URL || 'http://localhost:3000',
  token: process.env.TOKEN || '',
  eventId: process.env.EVENT_ID || '',
  roleName: process.env.ROLE || 'Server',
  duplicateRequests: parseInt(process.env.DUPLICATE_REQUESTS) || 10,
};

async function sendRequest(requestNum) {
  const startTime = Date.now();

  try {
    const response = await axios({
      method: 'POST',
      url: `${CONFIG.apiUrl}/api/events/${CONFIG.eventId}/respond`,
      headers: {
        'Authorization': `Bearer ${CONFIG.token}`,
        'Content-Type': 'application/json',
      },
      data: {
        response: 'accept',
        role: CONFIG.roleName,
      },
      timeout: 5000,
      validateStatus: () => true,
    });

    return {
      requestNum,
      status: response.status,
      latency: Date.now() - startTime,
      message: response.data?.message || 'OK',
      success: response.status === 200,
    };
  } catch (error) {
    return {
      requestNum,
      status: 0,
      latency: Date.now() - startTime,
      message: error.message,
      success: false,
    };
  }
}

async function runTest() {
  console.log('\n╔═══════════════════════════════════════════════════╗');
  console.log('║     Quick Duplicate Request Test                 ║');
  console.log('╚═══════════════════════════════════════════════════╝\n');

  if (!CONFIG.token || !CONFIG.eventId) {
    console.error('❌ Missing TOKEN or EVENT_ID environment variables!\n');
    console.error('Usage:');
    console.error('  TOKEN=your-jwt-token EVENT_ID=event-id node scripts/quick-duplicate-test.js\n');
    console.error('To get your token:');
    console.error('  1. Open your app in browser');
    console.error('  2. Open DevTools (F12)');
    console.error('  3. Go to Application > Local Storage');
    console.error('  4. Find and copy your JWT token\n');
    process.exit(1);
  }

  console.log(`Sending ${CONFIG.duplicateRequests} duplicate requests...\n`);

  const promises = [];
  for (let i = 1; i <= CONFIG.duplicateRequests; i++) {
    promises.push(sendRequest(i));
  }

  const results = await Promise.all(promises);

  console.log('Results:');
  console.log('─'.repeat(50));

  results.forEach(r => {
    const icon = r.success ? '✅' : '🚫';
    console.log(`  ${icon} Request ${r.requestNum}: ${r.status} - ${r.message} (${r.latency}ms)`);
  });

  console.log('\n');

  const successful = results.filter(r => r.success).length;
  const alreadyAccepted = results.filter(r => r.message?.includes('already accepted')).length;

  console.log('Summary:');
  console.log('─'.repeat(50));
  console.log(`  Total Requests:     ${CONFIG.duplicateRequests}`);
  console.log(`  Successful:         ${successful}`);
  console.log(`  Already Accepted:   ${alreadyAccepted}`);
  console.log('');

  if (successful === 1 && alreadyAccepted === CONFIG.duplicateRequests - 1) {
    console.log('✅ PERFECT: Exactly 1 success, rest rejected as duplicates!\n');
  } else if (successful === 1) {
    console.log('✅ PASS: Only 1 request succeeded (duplicate prevention working)\n');
  } else if (successful > 1) {
    console.log('❌ FAIL: Multiple requests succeeded! Duplicate prevention not working!\n');
  } else {
    console.log('⚠️  No requests succeeded - check event ID and role\n');
  }
}

runTest();
