import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate } from 'k6/metrics';

/**
 * API Soak Test
 *
 * Ramps from 0 → 100 → 500 → 0 virtual users over ~20 minutes.
 * Tests core API endpoints for memory leaks and performance degradation.
 *
 * Prerequisites:
 *   - A running backend
 *   - Set env vars: BASE_URL, MANAGER_TOKEN
 *
 * Usage:
 *   k6 run --env BASE_URL=http://localhost:3000 \
 *          --env MANAGER_TOKEN=<jwt> \
 *          load-tests/api-soak.k6.js
 */

const BASE_URL = __ENV.BASE_URL || 'http://localhost:3000';
const MANAGER_TOKEN = __ENV.MANAGER_TOKEN || '';

const errorRate = new Rate('errors');

export const options = {
  stages: [
    { duration: '2m', target: 100 },   // Ramp up to 100 users
    { duration: '5m', target: 100 },   // Hold at 100
    { duration: '3m', target: 500 },   // Ramp up to 500
    { duration: '5m', target: 500 },   // Hold at 500
    { duration: '3m', target: 100 },   // Ramp down to 100
    { duration: '2m', target: 0 },     // Ramp down to 0
  ],
  thresholds: {
    http_req_duration: ['p(95)<3000', 'p(99)<5000'],
    http_req_failed: ['rate<0.05'],
    errors: ['rate<0.1'],
  },
};

const headers = {
  'Content-Type': 'application/json',
  Authorization: `Bearer ${MANAGER_TOKEN}`,
};

// Weighted endpoint selection — more common endpoints hit more often
const endpoints = [
  { weight: 30, fn: getEvents },
  { weight: 20, fn: getClients },
  { weight: 15, fn: getRoles },
  { weight: 10, fn: getTeams },
  { weight: 10, fn: getStatistics },
  { weight: 10, fn: createEvent },
  { weight: 5, fn: getTariffs },
];

const totalWeight = endpoints.reduce((sum, e) => sum + e.weight, 0);

function selectEndpoint() {
  let rand = Math.random() * totalWeight;
  for (const ep of endpoints) {
    rand -= ep.weight;
    if (rand <= 0) return ep.fn;
  }
  return endpoints[0].fn;
}

// --- Endpoint functions ---

function getEvents() {
  const res = http.get(`${BASE_URL}/api/events`, { headers });
  check(res, { 'GET /events 200': (r) => r.status === 200 });
  errorRate.add(res.status !== 200);
  return res;
}

function getClients() {
  const res = http.get(`${BASE_URL}/api/clients`, { headers });
  check(res, { 'GET /clients 200': (r) => r.status === 200 });
  errorRate.add(res.status !== 200);
  return res;
}

function getRoles() {
  const res = http.get(`${BASE_URL}/api/roles`, { headers });
  check(res, { 'GET /roles 200': (r) => r.status === 200 });
  errorRate.add(res.status !== 200);
  return res;
}

function getTeams() {
  const res = http.get(`${BASE_URL}/api/teams`, { headers });
  check(res, { 'GET /teams 200': (r) => r.status === 200 });
  errorRate.add(res.status !== 200);
  return res;
}

function getStatistics() {
  const res = http.get(`${BASE_URL}/api/statistics`, { headers });
  // Statistics may return 200 or 404 depending on setup
  check(res, { 'GET /statistics ok': (r) => r.status === 200 || r.status === 404 });
  errorRate.add(res.status >= 500);
  return res;
}

function createEvent() {
  const payload = JSON.stringify({
    client_name: `Soak Test Client ${__VU}`,
    event_name: `Soak Event ${Date.now()}`,
    shift_name: `Shift ${__ITER}`,
    date: '2026-06-15',
    start_time: '09:00',
    end_time: '17:00',
    venue_name: 'Test Venue',
    venue_address: '123 Load Test St',
    city: 'Denver',
    state: 'CO',
    roles: [{ role: 'Staff', count: 5 }],
    status: 'draft',
  });

  const res = http.post(`${BASE_URL}/api/events`, payload, { headers });
  check(res, { 'POST /events 201 or 200': (r) => r.status === 201 || r.status === 200 });
  errorRate.add(res.status >= 400);
  return res;
}

function getTariffs() {
  const res = http.get(`${BASE_URL}/api/tariffs`, { headers });
  check(res, { 'GET /tariffs ok': (r) => r.status === 200 || r.status === 404 });
  errorRate.add(res.status >= 500);
  return res;
}

// --- Main test function ---

export default function () {
  const endpointFn = selectEndpoint();
  endpointFn();
  sleep(Math.random() * 2 + 0.5); // 0.5-2.5s think time
}
