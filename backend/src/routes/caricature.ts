import { Router, Request, Response } from 'express';
import { z } from 'zod';
import path from 'path';
import fs from 'fs';
import { requireAuth } from '../middleware/requireAuth';
import {
  generateCaricature,
  getAllRoles,
  getAllArtStyles,
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
 * Nothing is saved to storage or history until the user accepts.
 */
const generateSchema = z.object({
  role: z.enum(ALL_ROLE_IDS as [string, ...string[]]),
  artStyle: z.enum(['cartoon', 'caricature', 'anime', 'comic', 'pixar', 'watercolor']),
  model: z.enum(['dev', 'pro']).optional().default('dev'),
});

router.post('/generate', requireAuth, async (req: Request, res: Response) => {
  try {
    const parsed = generateSchema.safeParse(req.body);
    if (!parsed.success) {
      return res.status(400).json({
        message: 'Invalid request',
        errors: parsed.error.errors,
      });
    }

    const { role, artStyle, model } = parsed.data;
    const { provider, sub, managerId } = (req as any).authUser;
    const userId = managerId || `${provider}:${sub}`;

    // Look up user/manager to get picture URL
    let pictureUrl: string | undefined;

    if (managerId) {
      const manager = await ManagerModel.findById(managerId).lean();
      if (!manager) {
        return res.status(404).json({ message: 'Manager not found' });
      }
      pictureUrl = manager.picture;
    } else {
      const user = await UserModel.findOne({ provider, subject: sub }).lean();
      if (!user) {
        return res.status(404).json({ message: 'User not found' });
      }
      pictureUrl = user.picture;
    }

    // Verify profile picture exists
    if (!pictureUrl) {
      return res.status(400).json({
        message: 'You need a profile picture before generating a caricature. Upload one first!',
      });
    }

    // Check daily usage limit
    const usage = checkAndIncrementUsage(userId);
    if (!usage.allowed) {
      return res.status(429).json({
        message: `You've reached your daily limit of ${DAILY_LIMIT} caricatures. Try again tomorrow!`,
      });
    }

    // Generate the caricature — returns raw buffer, nothing saved yet
    const imageBuffer = await generateCaricature(pictureUrl, role as CaricatureRole, artStyle as ArtStyle, model as CaricatureModel);

    logger.info({ userId, role, artStyle, model, remaining: usage.remaining }, 'Caricature preview generated');

    return res.json({
      base64: imageBuffer.toString('base64'),
      role,
      artStyle,
      model,
      remaining: usage.remaining,
      message: 'Caricature generated successfully',
    });
  } catch (error) {
    logger.error({ error }, 'Failed to generate caricature');
    const message = (error as Error).message || 'Failed to generate caricature';
    return res.status(500).json({ message });
  }
});

/**
 * POST /api/caricature/accept
 * Accept a generated caricature — uploads to R2 and saves to history.
 * Called only when the user clicks "Use This Photo".
 */
const acceptSchema = z.object({
  base64: z.string().min(100), // base64-encoded PNG
  role: z.enum(ALL_ROLE_IDS as [string, ...string[]]),
  artStyle: z.enum(['cartoon', 'caricature', 'anime', 'comic', 'pixar', 'watercolor']),
  model: z.enum(['dev', 'pro']).optional().default('dev'),
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

    const { base64, role, artStyle, model } = parsed.data;
    const { provider, sub, managerId } = (req as any).authUser;
    const userId = managerId || `${provider}:${sub}`;

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

    // Save to caricature history (push new, cap at 10 entries)
    try {
      const historyEntry = {
        $push: {
          caricatureHistory: {
            $each: [{ url, role, artStyle, model, createdAt: new Date() }],
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

    logger.info({ userId, role, artStyle, model, local: !isStorageConfigured() }, 'Caricature accepted and saved');

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

export default router;
