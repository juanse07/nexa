import http from 'k6/http';
import { check, sleep } from 'k6';
import { Counter, Trend } from 'k6/metrics';

/**
 * Event Acceptance Spike Test
 *
 * Simulates 1000 staff users simultaneously accepting the same event.
 * Validates that atomic capacity enforcement prevents overbooking.
 *
 * Prerequisites:
 *   - A running backend with a published event
 *   - Set env vars: BASE_URL, MANAGER_TOKEN, EVENT_ID
 *
 * Usage:
 *   k6 run --env BASE_URL=http://localhost:3000 \
 *          --env MANAGER_TOKEN=<jwt> \
 *          --env EVENT_ID=<event_id> \
 *          load-tests/event-acceptance.k6.js
 */

const BASE_URL = __ENV.BASE_URL || 'http://localhost:3000';
const MANAGER_TOKEN = __ENV.MANAGER_TOKEN || '';
const EVENT_ID = __ENV.EVENT_ID || '';

// Custom metrics
const acceptedCount = new Counter('accepted_responses');
const rejectedCount = new Counter('rejected_responses');
const acceptLatency = new Trend('accept_latency', true);

export const options = {
  scenarios: {
    spike_acceptance: {
      executor: 'shared-iterations',
      vus: 1000,
      iterations: 1000,
      maxDuration: '60s',
    },
  },
  thresholds: {
    http_req_duration: ['p(95)<2000'],   // 95% of requests < 2s
    http_req_failed: ['rate<0.01'],       // < 1% HTTP errors (non-4xx)
  },
};

export function setup() {
  // Verify event exists and is published
  if (!EVENT_ID) {
    console.warn('EVENT_ID not set — using placeholder. Set it to test a real event.');
    return { eventId: 'placeholder', roles: ['Staff'] };
  }

  const res = http.get(`${BASE_URL}/api/events/${EVENT_ID}`, {
    headers: { Authorization: `Bearer ${MANAGER_TOKEN}` },
  });

  check(res, { 'setup: event exists': (r) => r.status === 200 });

  if (res.status === 200) {
    const event = res.json();
    const roles = (event.roles || []).map((r) => r.role || 'Staff');
    return { eventId: EVENT_ID, roles };
  }

  return { eventId: EVENT_ID, roles: ['Staff'] };
}

export default function (data) {
  const vuId = __VU;
  const role = data.roles[vuId % data.roles.length];

  // Each VU acts as a unique staff user accepting the event
  const payload = JSON.stringify({
    response: 'accepted',
    role: role,
    userKey: `loadtest:user-${vuId}`,
    userName: `Load Test User ${vuId}`,
  });

  const start = Date.now();
  const res = http.post(
    `${BASE_URL}/api/events/${data.eventId}/respond`,
    payload,
    {
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${MANAGER_TOKEN}`,
      },
    }
  );
  const elapsed = Date.now() - start;
  acceptLatency.add(elapsed);

  if (res.status === 200) {
    acceptedCount.add(1);
  } else if (res.status === 400 || res.status === 409) {
    // Role full or duplicate — expected under contention
    rejectedCount.add(1);
  }

  check(res, {
    'response is 200, 400, or 409': (r) =>
      r.status === 200 || r.status === 400 || r.status === 409,
  });

  sleep(0.1);
}

export function teardown(data) {
  console.log(`\n=== Event Acceptance Spike Test Results ===`);
  console.log(`Event ID: ${data.eventId}`);
  console.log(`Roles tested: ${data.roles.join(', ')}`);
  console.log(`Check 'accepted_responses' and 'rejected_responses' metrics above.`);
  console.log(`Total accepted should NOT exceed role capacity (no overbooking).`);
}
