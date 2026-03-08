import rateLimit from 'express-rate-limit';
import { RedisStore } from 'rate-limit-redis';
import { getRedisClient } from '../db/redis';

/**
 * Creates a rate limiter backed by Redis (shared across all API instances).
 * Falls back to in-memory store if Redis is unavailable.
 *
 * Uses authenticated userKey when available (more accurate than IP),
 * falls back to IP for unauthenticated requests.
 */
function createRedisLimiter(opts: {
  windowMs: number;
  max: number;
  prefix: string;
  message?: string;
}) {
  const client = getRedisClient();

  const storeConfig = client
    ? {
        store: new RedisStore({
          // Use ioredis `call` method for compatibility
          sendCommand: (...args: string[]) => (client as any).call(...args),
          prefix: `rl:${opts.prefix}:`,
        }),
      }
    : {}; // Falls back to default MemoryStore

  return rateLimit({
    windowMs: opts.windowMs,
    max: opts.max,
    standardHeaders: true,
    legacyHeaders: false,
    // Disable IPv6 validation — we prefer authenticated userKey over IP
    validate: { ipAddress: false },
    keyGenerator: (req) => {
      // Prefer authenticated user key over IP
      const authUser = (req as any).user || (req as any).authUser;
      if (authUser?.provider && authUser?.sub) {
        return `${authUser.provider}:${authUser.sub}`;
      }
      return req.ip || 'unknown';
    },
    message: {
      error: 'Too many requests',
      message: opts.message || 'Please slow down',
    },
    ...storeConfig,
  });
}

// ─── Limiter instances ───────────────────────────────────────────────────────

/** Global API limiter: 300 requests/min per user */
export const globalApiLimiter = createRedisLimiter({
  windowMs: 60 * 1000,
  max: 300,
  prefix: 'global',
  message: 'Too many API requests. Please try again shortly.',
});

/** Event respond limiter: 30/min */
export const eventRespondLimiter = createRedisLimiter({
  windowMs: 60 * 1000,
  max: 30,
  prefix: 'respond',
  message: 'Too many event responses. Please slow down.',
});

/** Clock-in limiter: 10/min */
export const clockInLimiter = createRedisLimiter({
  windowMs: 60 * 1000,
  max: 10,
  prefix: 'clockin',
  message: 'Too many clock-in attempts.',
});

/** Clock-out limiter: 10/min */
export const clockOutLimiter = createRedisLimiter({
  windowMs: 60 * 1000,
  max: 10,
  prefix: 'clockout',
  message: 'Too many clock-out attempts.',
});

/** AI chat limiter: 15/min */
export const aiChatLimiter = createRedisLimiter({
  windowMs: 60 * 1000,
  max: 15,
  prefix: 'aichat',
  message: 'Too many AI chat messages. Please wait a moment.',
});
