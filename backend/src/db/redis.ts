import Redis from 'ioredis';
import { ENV } from '../config/env';

let client: Redis | null = null;

/**
 * Returns the singleton Redis client, creating it on first call.
 * Gracefully handles missing REDIS_URL by returning null (no-op mode).
 */
export function getRedisClient(): Redis | null {
  if (client) return client;

  const url = ENV.redisUrl;
  if (!url) {
    console.warn('[Redis] No REDIS_URL configured — running without Redis');
    return null;
  }

  client = new Redis(url, {
    maxRetriesPerRequest: null, // Required for BullMQ / rate-limit-redis compatibility
    retryStrategy(times) {
      if (times > 20) {
        console.error(`[Redis] Exhausted ${times} reconnection attempts — giving up`);
        return null; // Stop retrying
      }
      const delay = Math.min(times * 200, 5000); // Exponential backoff, max 5s
      console.warn(`[Redis] Reconnecting in ${delay}ms (attempt ${times})`);
      return delay;
    },
    lazyConnect: false,
    enableReadyCheck: true,
  });

  client.on('connect', () => {
    console.log('[Redis] Connected');
  });

  client.on('ready', () => {
    console.log('[Redis] Ready to accept commands');
  });

  client.on('error', (err) => {
    console.error('[Redis] Error:', err.message);
  });

  client.on('close', () => {
    console.warn('[Redis] Connection closed');
  });

  return client;
}

/**
 * Checks if Redis is connected and responding.
 */
export async function isRedisHealthy(): Promise<boolean> {
  try {
    if (!client) return false;
    const pong = await client.ping();
    return pong === 'PONG';
  } catch {
    return false;
  }
}

/**
 * Gracefully closes the Redis connection.
 * Called during server shutdown.
 */
export async function closeRedis(): Promise<void> {
  if (!client) return;
  try {
    await client.quit();
    console.log('[Redis] Connection closed gracefully');
  } catch (err) {
    console.error('[Redis] Error during shutdown:', (err as Error).message);
    client.disconnect(); // Force disconnect if quit fails
  } finally {
    client = null;
  }
}
