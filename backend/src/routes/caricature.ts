import { Router, Request, Response } from 'express';
import { z } from 'zod';
import path from 'path';
import fs from 'fs';
import { requireAuth } from '../middleware/requireAuth';
import { requireActiveSubscription } from '../middleware/requireActiveSubscription';
import {
  generateCaricature,
  getAllRoles,
  getAllArtStyles,
  generateCacheKey,
  getCachedCaricature,
  CaricatureRole,
  ArtStyle,
  CaricatureModel,
  ALL_ROLE_IDS,
} from '../services/caricatureService';
import { isStorageConfigured, uploadProfilePicture } from '../services/storageService';
import { ManagerModel } from '../models/manager';
import { UserModel } from '../models/user';
import pino from 'pino';

const logger = pino({ level: process.env.LOG_LEVEL || 'info' });
const router = Router();

// In-memory daily usage tracking (resets on server restart — acceptable for MVP)
const dailyUsage = new Map<string, { count: number; date: string }>();

const DAILY_LIMIT = 999; // unlimited for testing

// Image count per model tier (dev=2 cheaper previews, pro=4 full quality)
const IMAGE_COUNT: Record<string, number> = { dev: 2, pro: 4 };

// Bridge generate→accept: store cacheKey so accept can use it without frontend roundtrip
// Key: userId, Value: { cacheKey, overlayText, timestamp }
const pendingCacheKeys = new Map<string, { cacheKey: string; overlayText?: string; ts: number }>();

// Clean stale entries older than 5 minutes
function cleanPendingCache(): void {
  const cutoff = Date.now() - 5 * 60 * 1000;
  for (const [key, val] of pendingCacheKeys) {
    if (val.ts < cutoff) pendingCacheKeys.delete(key);
  }
}

function getTodayKey(): string {
  return new Date().toISOString().slice(0, 10);
}

function checkAndIncrementUsage(userId: string): { allowed: boolean; remaining: number } {
  const today = getTodayKey();
  const entry = dailyUsage.get(userId);

  if (!entry || entry.date !== today) {
    dailyUsage.set(userId, { count: 1, date: today });
    return { allowed: true, remaining: DAILY_LIMIT - 1 };
  }

  if (entry.count >= DAILY_LIMIT) {
    return { allowed: false, remaining: 0 };
  }

  entry.count += 1;
  return { allowed: true, remaining: DAILY_LIMIT - entry.count };
}

/**
 * GET /api/caricature/styles
 * Returns available roles and art styles.
 */
router.get('/styles', requireAuth, async (_req: Request, res: Response) => {
  try {
    const roles = getAllRoles();
    const artStyles = getAllArtStyles();

    return res.json({
      roles,
      artStyles,
    });
  } catch (error) {
    logger.error({ error }, 'Failed to get caricature styles');
    return res.status(500).json({ message: 'Failed to get styles' });
  }
});

/**
 * POST /api/caricature/generate
 * Generate a caricature preview — returns base64 image data only.
 * Checks MongoDB cache first; if a matching accepted caricature exists,
 * returns it instantly (no Together AI cost).
 */
const generateSchema = z.object({
  role: z.enum(ALL_ROLE_IDS as [string, ...string[]]),
  artStyle: z.enum(['cartoon', 'caricature', 'anime', 'comic', 'pixar', 'watercolor']),
  model: z.enum(['dev', 'pro']).optional().default('pro'),
  name: z.string().max(40).optional(),
  tagline: z.string().max(50).optional(),
  forceNew: z.boolean().optional().default(false),
});

router.post('/generate', requireAuth, requireActiveSubscription, async (req: Request, res: Response) => {
  try {
    const parsed = generateSchema.safeParse(req.body);
    if (!parsed.success) {
      return res.status(400).json({
        message: 'Invalid request',
        errors: parsed.error.errors,
      });
    }

    const { role, artStyle, model, name, tagline, forceNew } = parsed.data;
    const { provider, sub, managerId } = (req as any).authUser;
    const userId = managerId || `${provider}:${sub}`;

    // Build overlay text from name + tagline
    const textParts: string[] = [];
    if (name) textParts.push(name);
    if (tagline) textParts.push(tagline);
    const overlayText = textParts.length > 0 ? textParts.join(' — ') : undefined;

    // Look up user/manager to get picture URL
    let pictureUrl: string | undefined;

    if (managerId) {
      const manager = await ManagerModel.findById(managerId).lean();
      if (!manager) {
        return res.status(404).json({ message: 'Manager not found' });
      }
      pictureUrl = manager.picture ?? undefined;
    } else {
      const user = await UserModel.findOne({ provider, subject: sub }).lean();
      if (!user) {
        return res.status(404).json({ message: 'User not found' });
      }
      pictureUrl = user.picture ?? undefined;
    }

    // Verify profile picture exists
    if (!pictureUrl) {
      return res.status(400).json({
        message: 'You need a profile picture before generating a caricature. Upload one first!',
      });
    }

    // ── CACHE CHECK: Generate cache key and look up MongoDB ──
    const cacheKey = generateCacheKey(pictureUrl, role, artStyle, model, overlayText);
    logger.info({ userId, cacheKey, forceNew }, 'Generated cache key');

    // Skip cache when user explicitly requests fresh generation
    if (!forceNew) {
      const cached = await getCachedCaricature(cacheKey, 30);

      if (cached) {
        logger.info({ userId, cacheKey, cachedUrl: cached.url }, 'Cache HIT - returning cached result');

        // Download cached image from R2 and return as base64 (backward compatible with old Flutter)
        let cachedImages: string[] = [];
        try {
          const imgResponse = await fetch(cached.url);
          if (imgResponse.ok) {
            const buf = Buffer.from(await imgResponse.arrayBuffer());
            cachedImages = [buf.toString('base64')];
            logger.info({ userId, cacheKey, imageSize: buf.length }, 'Cache HIT: downloaded image from R2');
          }
        } catch (dlErr) {
          logger.warn({ dlErr, url: cached.url }, 'Cache HIT: failed to download cached image');
        }

        return res.json({
          images: cachedImages, // base64 array for backward compat
          url: cached.url,
          role: cached.role,
          artStyle: cached.artStyle,
          model: cached.model,
          overlayText: cached.overlayText,
          cached: true,
          cacheKey,
          remaining: -1, // don't decrement usage for cache hits
          message: 'Instant delivery from cache!',
        });
      }
    } else {
      logger.info({ userId, cacheKey }, 'Cache BYPASS - forceNew requested');
    }

    // ── CACHE MISS: Generate new caricature ──
    logger.info({ userId, cacheKey }, 'Cache MISS - generating new caricature');

    // Check daily usage limit
    const usage = checkAndIncrementUsage(userId);
    if (!usage.allowed) {
      return res.status(429).json({
        message: `You've reached your daily limit of ${DAILY_LIMIT} caricatures. Try again tomorrow!`,
      });
    }

    // dev=2 images, pro=4 images (cost optimization)
    const count = IMAGE_COUNT[model] ?? 4;

    // Generate caricature previews — returns raw buffers, nothing saved yet
    const imageBuffers = await generateCaricature(pictureUrl, role as CaricatureRole, artStyle as ArtStyle, model as CaricatureModel, count, overlayText);

    logger.info({ userId, role, artStyle, model, count: imageBuffers.length, remaining: usage.remaining, cached: false, cacheKey }, 'Caricature previews generated (new)');

    // Store cacheKey for accept route (in case frontend doesn't send it back)
    pendingCacheKeys.set(userId, { cacheKey, overlayText, ts: Date.now() });
    cleanPendingCache();

    return res.json({
      images: imageBuffers.map((buf) => buf.toString('base64')),
      role,
      artStyle,
      model,
      cached: false,
      remaining: usage.remaining,
      cacheKey, // Pass to frontend so accept can include it
      overlayText, // Pass to frontend so accept can save it
      message: 'Caricatures generated successfully',
    });
  } catch (error) {
    logger.error({ error }, 'Failed to generate caricature');
    const message = (error as Error).message || 'Failed to generate caricature';
    return res.status(500).json({ message });
  }
});

/**
 * POST /api/caricature/accept
 * Accept a generated caricature — uploads to R2 and saves to history WITH cacheKey.
 * Called only when the user clicks "Use This Photo".
 */
const acceptSchema = z.object({
  base64: z.string().min(100), // base64-encoded PNG
  role: z.enum(ALL_ROLE_IDS as [string, ...string[]]),
  artStyle: z.enum(['cartoon', 'caricature', 'anime', 'comic', 'pixar', 'watercolor']),
  model: z.enum(['dev', 'pro']).optional().default('dev'),
  cacheKey: z.string().optional(), // from generate response
  overlayText: z.string().optional(),
});

router.post('/accept', requireAuth, async (req: Request, res: Response) => {
  try {
    const parsed = acceptSchema.safeParse(req.body);
    if (!parsed.success) {
      return res.status(400).json({
        message: 'Invalid request',
        errors: parsed.error.errors,
      });
    }

    const { base64, role, artStyle, model, cacheKey: clientCacheKey, overlayText: clientOverlayText } = parsed.data;
    const { provider, sub, managerId } = (req as any).authUser;
    const userId = managerId || `${provider}:${sub}`;

    // Use pending cacheKey from generate route if frontend didn't send it
    let cacheKey = clientCacheKey;
    let overlayText = clientOverlayText;
    if (!cacheKey) {
      const pending = pendingCacheKeys.get(userId);
      if (pending) {
        cacheKey = pending.cacheKey;
        if (!overlayText) overlayText = pending.overlayText;
        pendingCacheKeys.delete(userId);
        logger.info({ userId, cacheKey, overlayText }, 'Caricature accept: using cacheKey from generate (pending bridge)');
      } else {
        logger.warn({ userId }, 'Caricature accept: no cacheKey from frontend or pending bridge');
      }
    }

    const imageBuffer = Buffer.from(base64, 'base64');

    // Upload to R2 or local filesystem
    const timestamp = Date.now();
    const filename = `${timestamp}-${role}-${artStyle}-${model}.png`;
    let url: string;

    if (isStorageConfigured()) {
      url = await uploadProfilePicture(imageBuffer, userId, filename, 'image/png');
    } else {
      const uploadsDir = path.join('/app', 'uploads', 'caricatures', userId.toString());
      fs.mkdirSync(uploadsDir, { recursive: true });
      fs.writeFileSync(path.join(uploadsDir, filename), imageBuffer);
      const proto = req.headers['x-forwarded-proto'] || 'https';
      const host = req.headers['x-forwarded-host'] || req.headers.host || 'localhost:4000';
      url = `${proto}://${host}/uploads/caricatures/${userId}/${filename}`;
    }

    // Save to caricature history WITH cacheKey (push new, cap at 10 entries)
    try {
      const historyEntry = {
        $push: {
          caricatureHistory: {
            $each: [{
              url,
              role,
              artStyle,
              model,
              overlayText,
              cacheKey, // enables future cache lookups
              cached: false, // this was a new generation
              createdAt: new Date(),
            }],
            $slice: -10,
          },
        },
      };
      if (managerId) {
        await ManagerModel.findByIdAndUpdate(managerId, historyEntry);
      } else {
        await UserModel.findOneAndUpdate(
          { provider, subject: sub },
          historyEntry,
        );
      }
    } catch (historyErr) {
      logger.warn({ historyErr }, 'Failed to save caricature history (non-blocking)');
    }

    logger.info({ userId, role, artStyle, model, cacheKey, local: !isStorageConfigured() }, 'Caricature accepted and saved');

    return res.json({
      url,
      role,
      artStyle,
      model,
      message: 'Caricature saved successfully',
    });
  } catch (error) {
    logger.error({ error }, 'Failed to accept caricature');
    const message = (error as Error).message || 'Failed to save caricature';
    return res.status(500).json({ message });
  }
});

/**
 * GET /api/caricature/admin/cache-stats
 * Track cache performance: hit rate, cost savings, generation counts.
 */
router.get('/admin/cache-stats', requireAuth, async (_req: Request, res: Response) => {
  try {
    const currentMonth = new Date().toISOString().slice(0, 7);
    const monthStart = new Date(currentMonth + '-01');

    // Aggregate across managers
    const managerStats = await ManagerModel.aggregate([
      { $unwind: '$caricatureHistory' },
      { $match: { 'caricatureHistory.createdAt': { $gte: monthStart } } },
      { $group: {
        _id: '$caricatureHistory.cached',
        count: { $sum: 1 },
      }},
    ]);

    // Aggregate across users
    const userStats = await UserModel.aggregate([
      { $unwind: '$caricatureHistory' },
      { $match: { 'caricatureHistory.createdAt': { $gte: monthStart } } },
      { $group: {
        _id: '$caricatureHistory.cached',
        count: { $sum: 1 },
      }},
    ]);

    // Combine manager + user stats
    let newGenerations = 0;
    let cachedGenerations = 0;
    for (const stat of [...managerStats, ...userStats]) {
      if (stat._id === true) cachedGenerations += stat.count;
      else newGenerations += stat.count;
    }
    const total = newGenerations + cachedGenerations;
    const cacheHitRate = total > 0 ? (cachedGenerations / total * 100).toFixed(1) : '0.0';

    // Cost estimate (avg $0.10 per generation)
    const avgCostPerGeneration = 0.10;
    const costWithoutCache = total * avgCostPerGeneration;
    const actualCost = newGenerations * avgCostPerGeneration;
    const savings = costWithoutCache - actualCost;

    return res.json({
      month: currentMonth,
      generations: { total, new: newGenerations, cached: cachedGenerations },
      cacheHitRate: `${cacheHitRate}%`,
      costs: {
        withoutCache: `$${costWithoutCache.toFixed(2)}`,
        withCache: `$${actualCost.toFixed(2)}`,
        savings: `$${savings.toFixed(2)}`,
      },
    });
  } catch (error) {
    logger.error({ error }, 'Failed to get cache stats');
    return res.status(500).json({ message: 'Failed to get cache statistics' });
  }
});

export default router;
