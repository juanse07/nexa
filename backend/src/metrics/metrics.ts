import client from 'prom-client';

// Single shared registry
export const registry = new client.Registry();
registry.setDefaultLabels({ app: 'flowshift' });

// Collect default Node.js metrics (heap, GC, event loop, etc.)
client.collectDefaultMetrics({ register: registry, prefix: 'flowshift_' });

// ─── HTTP Metrics ──────────────────────────────────────────────────────────────

export const httpRequestDuration = new client.Histogram({
  name: 'flowshift_http_request_duration_seconds',
  help: 'Duration of HTTP requests in seconds',
  labelNames: ['method', 'route', 'status_code'] as const,
  buckets: [0.01, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5, 10],
  registers: [registry],
});

export const httpRequestsTotal = new client.Counter({
  name: 'flowshift_http_requests_total',
  help: 'Total number of HTTP requests',
  labelNames: ['method', 'route', 'status_code'] as const,
  registers: [registry],
});

export const httpRequestsInFlight = new client.Gauge({
  name: 'flowshift_http_requests_in_flight',
  help: 'Number of HTTP requests currently being processed',
  registers: [registry],
});

// ─── Business Metrics ──────────────────────────────────────────────────────────

export const eventsCreatedTotal = new client.Counter({
  name: 'flowshift_events_created_total',
  help: 'Total number of events created',
  registers: [registry],
});

export const usersRegisteredTotal = new client.Counter({
  name: 'flowshift_users_registered_total',
  help: 'Total number of new user registrations',
  labelNames: ['provider'] as const,
  registers: [registry],
});

export const authAttemptsTotal = new client.Counter({
  name: 'flowshift_auth_attempts_total',
  help: 'Total authentication attempts',
  labelNames: ['provider', 'role', 'result'] as const,
  registers: [registry],
});

export const clockInsTotal = new client.Counter({
  name: 'flowshift_clock_ins_total',
  help: 'Total number of clock-ins',
  labelNames: ['type'] as const, // 'self' | 'bulk'
  registers: [registry],
});

export const clockOutsTotal = new client.Counter({
  name: 'flowshift_clock_outs_total',
  help: 'Total number of clock-outs',
  labelNames: ['type'] as const, // 'self' | 'force'
  registers: [registry],
});

// ─── Socket.IO Metrics ─────────────────────────────────────────────────────────

export const socketConnectionsActive = new client.Gauge({
  name: 'flowshift_socket_connections_active',
  help: 'Number of active Socket.IO connections',
  registers: [registry],
});

// ─── MongoDB Metrics ───────────────────────────────────────────────────────────

export const mongoQueryDuration = new client.Histogram({
  name: 'flowshift_mongo_query_duration_seconds',
  help: 'Duration of Mongoose queries in seconds',
  labelNames: ['model', 'operation'] as const,
  buckets: [0.001, 0.005, 0.01, 0.05, 0.1, 0.5, 1, 5],
  registers: [registry],
});

// ─── Gauge Metrics (populated by businessMetricsCollector) ─────────────────────

export const activeManagersGauge = new client.Gauge({
  name: 'flowshift_active_managers',
  help: 'Number of active manager accounts',
  registers: [registry],
});

export const activeEventsGauge = new client.Gauge({
  name: 'flowshift_active_events',
  help: 'Number of events with status published/confirmed/in_progress',
  registers: [registry],
});

export const totalStaffGauge = new client.Gauge({
  name: 'flowshift_total_staff',
  help: 'Total number of staff users',
  registers: [registry],
});
