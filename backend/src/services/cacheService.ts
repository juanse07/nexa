import { getRedisClient } from '../db/redis';

/**
 * Generic Redis cache service with graceful degradation.
 * All methods are no-ops when Redis is unavailable — the app falls through to MongoDB.
 */
export const cache = {
  /**
   * Get a cached value by key. Returns null on miss or Redis failure.
   */
  async get<T = any>(key: string): Promise<T | null> {
    try {
      const client = getRedisClient();
      if (!client) return null;
      const raw = await client.get(key);
      if (!raw) return null;
      return JSON.parse(raw) as T;
    } catch {
      return null;
    }
  },

  /**
   * Set a cached value with TTL (in seconds).
   */
  async set(key: string, value: any, ttlSeconds: number): Promise<void> {
    try {
      const client = getRedisClient();
      if (!client) return;
      await client.set(key, JSON.stringify(value), 'EX', ttlSeconds);
    } catch {
      // Silently fail — cache is best-effort
    }
  },

  /**
   * Delete a specific cache key.
   */
  async del(key: string): Promise<void> {
    try {
      const client = getRedisClient();
      if (!client) return;
      await client.del(key);
    } catch {
      // Silently fail
    }
  },

  /**
   * Delete all keys matching a pattern (e.g., "tm:*" to clear all team member caches).
   * Uses SCAN to avoid blocking Redis with KEYS command.
   */
  async delPattern(pattern: string): Promise<void> {
    try {
      const client = getRedisClient();
      if (!client) return;
      let cursor = '0';
      do {
        const [nextCursor, keys] = await client.scan(cursor, 'MATCH', pattern, 'COUNT', 100);
        cursor = nextCursor;
        if (keys.length > 0) {
          await client.del(...keys);
        }
      } while (cursor !== '0');
    } catch {
      // Silently fail
    }
  },
};

// ─── Cache key constants ─────────────────────────────────────────────────────
// Centralized key patterns prevent typos and make invalidation easy to trace.

export const CacheKeys = {
  teamMembers: (managerId: string) => `tm:${managerId}`,
  managerProfile: (managerId: string) => `mgr:${managerId}`,
  eventSummary: (eventId: string) => `evt:${eventId}:summary`,
  roles: (managerId: string) => `roles:${managerId}`,
  clients: (managerId: string) => `clients:${managerId}`,
  aiContext: (managerId: string) => `ai_ctx:${managerId}`,
  subscriptionTier: (userKey: string) => `sub:${userKey}`,
} as const;

// ─── Cache TTLs (seconds) ────────────────────────────────────────────────────

export const CacheTTL = {
  TEAM_MEMBERS: 5 * 60,      // 5 min
  MANAGER_PROFILE: 10 * 60,  // 10 min
  EVENT_SUMMARY: 2 * 60,     // 2 min
  ROLES: 10 * 60,            // 10 min
  CLIENTS: 10 * 60,          // 10 min
  AI_CONTEXT: 5 * 60,        // 5 min
  SUBSCRIPTION: 5 * 60,      // 5 min
} as const;
