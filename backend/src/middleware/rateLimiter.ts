import rateLimit from 'express-rate-limit';
import { RedisStore } from 'rate-limit-redis';
import { getRedisClient } from '../db/redis';

/**
 * Creates a Redis-backed store config, or empty object for in-memory fallback.
 */
function redisStoreConfig(prefix: string) {
  const client = getRedisClient();
  if (!client) return {};
  return {
    store: new RedisStore({
      sendCommand: (...args: string[]) => (client as any).call(...args),
      prefix: `rl:${prefix}:`,
    }),
  };
}

/**
 * Rate limiter for invite redemption endpoint.
 * Prevents abuse by limiting redemption attempts.
 */
export const inviteRedeemLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 10, // 10 redemption attempts per 15 minutes per IP
  message: {
    error: 'Too many invite redemption attempts',
    message: 'Please try again later',
    retryAfter: '15 minutes',
  },
  standardHeaders: true,
  legacyHeaders: false,
  ...redisStoreConfig('invite_redeem'),
});

/**
 * Rate limiter for invite validation endpoint (unauthenticated).
 * More lenient since it's just for previewing invites.
 */
export const inviteValidateLimiter = rateLimit({
  windowMs: 1 * 60 * 1000, // 1 minute
  max: 60, // 60 validation requests per minute per IP
  message: {
    error: 'Too many validation requests',
    message: 'Please slow down',
  },
  standardHeaders: true,
  legacyHeaders: false,
  ...redisStoreConfig('invite_validate'),
});

/**
 * Rate limiter for creating invite links.
 * Prevents managers from creating too many invites rapidly.
 */
export const inviteCreateLimiter = rateLimit({
  windowMs: 5 * 60 * 1000, // 5 minutes
  max: 20, // 20 invite links per 5 minutes per IP
  message: {
    error: 'Too many invites created',
    message: 'Please wait a few minutes before creating more invites',
  },
  standardHeaders: true,
  legacyHeaders: false,
  ...redisStoreConfig('invite_create'),
});
