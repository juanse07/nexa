import http from 'k6/http';
import { check, sleep } from 'k6';
import { Counter, Trend } from 'k6/metrics';

/**
 * Auth Stress Test
 *
 * Simulates 500 concurrent login/auth requests.
 * Tests JWT generation performance and rate limiter behavior.
 *
 * Note: Since Google/Apple OAuth requires real tokens, this test
 * focuses on the auth middleware validation path by sending requests
 * with JWTs to authenticated endpoints. This validates:
 *   - JWT verification throughput
 *   - Rate limiter under load
 *   - Auth middleware performance
 *
 * Prerequisites:
 *   - A running backend
 *   - Set env vars: BASE_URL, MANAGER_TOKEN
 *
 * Usage:
 *   k6 run --env BASE_URL=http://localhost:3000 \
 *          --env MANAGER_TOKEN=<jwt> \
 *          load-tests/auth-stress.k6.js
 */

const BASE_URL = __ENV.BASE_URL || 'http://localhost:3000';
const MANAGER_TOKEN = __ENV.MANAGER_TOKEN || '';

// Custom metrics
const authSuccess = new Counter('auth_success');
const authFailed = new Counter('auth_failed');
const rateLimited = new Counter('rate_limited');
const authLatency = new Trend('auth_latency', true);

export const options = {
  scenarios: {
    auth_burst: {
      // Burst: 500 concurrent auth requests
      executor: 'constant-vus',
      vus: 500,
      duration: '30s',
    },
  },
  thresholds: {
    http_req_duration: ['p(95)<1500'],   // Auth should be fast
    http_req_failed: ['rate<0.05'],       // Allow up to 5% failures (rate limiting)
  },
};

const authHeaders = {
  'Content-Type': 'application/json',
  Authorization: `Bearer ${MANAGER_TOKEN}`,
};

const noAuthHeaders = {
  'Content-Type': 'application/json',
};

export default function () {
  const scenario = Math.random();

  if (scenario < 0.4) {
    // 40%: Authenticated request (JWT verification)
    testAuthenticatedRequest();
  } else if (scenario < 0.7) {
    // 30%: Invalid token request (auth rejection path)
    testInvalidTokenRequest();
  } else if (scenario < 0.9) {
    // 20%: Missing auth header
    testMissingAuthRequest();
  } else {
    // 10%: Expired-style token (malformed)
    testMalformedTokenRequest();
  }

  sleep(0.05); // Minimal delay to simulate realistic burst
}

function testAuthenticatedRequest() {
  const start = Date.now();
  const res = http.get(`${BASE_URL}/api/events`, { headers: authHeaders });
  authLatency.add(Date.now() - start);

  if (res.status === 200) {
    authSuccess.add(1);
  } else if (res.status === 429) {
    rateLimited.add(1);
  } else {
    authFailed.add(1);
  }

  check(res, {
    'auth request ok or rate limited': (r) =>
      r.status === 200 || r.status === 429,
  });
}

function testInvalidTokenRequest() {
  const start = Date.now();
  const res = http.get(`${BASE_URL}/api/events`, {
    headers: {
      'Content-Type': 'application/json',
      Authorization: 'Bearer invalid-token-' + __VU,
    },
  });
  authLatency.add(Date.now() - start);

  if (res.status === 401) {
    authSuccess.add(1); // Expected rejection
  } else if (res.status === 429) {
    rateLimited.add(1);
  } else {
    authFailed.add(1);
  }

  check(res, {
    'invalid token returns 401 or 429': (r) =>
      r.status === 401 || r.status === 429,
  });
}

function testMissingAuthRequest() {
  const start = Date.now();
  const res = http.get(`${BASE_URL}/api/events`, {
    headers: noAuthHeaders,
  });
  authLatency.add(Date.now() - start);

  if (res.status === 401) {
    authSuccess.add(1);
  } else if (res.status === 429) {
    rateLimited.add(1);
  } else {
    authFailed.add(1);
  }

  check(res, {
    'missing auth returns 401 or 429': (r) =>
      r.status === 401 || r.status === 429,
  });
}

function testMalformedTokenRequest() {
  const start = Date.now();
  const res = http.get(`${BASE_URL}/api/events`, {
    headers: {
      'Content-Type': 'application/json',
      Authorization: 'Bearer eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIn0.INVALID',
    },
  });
  authLatency.add(Date.now() - start);

  if (res.status === 401) {
    authSuccess.add(1);
  } else if (res.status === 429) {
    rateLimited.add(1);
  } else {
    authFailed.add(1);
  }

  check(res, {
    'malformed token returns 401 or 429': (r) =>
      r.status === 401 || r.status === 429,
  });
}

export function teardown() {
  console.log('\n=== Auth Stress Test Results ===');
  console.log('Check auth_success, auth_failed, and rate_limited counters above.');
  console.log('If rate_limited is high, the rate limiter is working as expected.');
}
