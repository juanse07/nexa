import { Router } from 'express';
import mongoose from 'mongoose';
import { z } from 'zod';
import { requireAuth } from '../middleware/requireAuth';
import { ManagerModel } from '../models/manager';

const router = Router();

const updateSchema = z.object({
  first_name: z.string().trim().min(1).max(100).optional(),
  last_name: z.string().trim().min(1).max(100).optional(),
  app_id: z
    .string()
    .regex(/^\d{9}$/)
    .optional(),
  picture: z.string().url().max(2048).optional(),
});

router.get('/managers/me', requireAuth, async (req, res) => {
  try {
    if (!req.user?.provider || !req.user?.sub) {
      return res.status(401).json({ message: 'Unauthorized' });
    }
    const doc = await ManagerModel.findOne({ provider: req.user.provider, subject: req.user.sub }).lean();
    if (!doc) return res.status(404).json({ message: 'Manager not found' });
    return res.json({
      id: String(doc._id),
      email: doc.email,
      first_name: doc.first_name,
      last_name: doc.last_name,
      picture: doc.picture,
      app_id: doc.app_id,
    });
  } catch (err) {
    return res.status(500).json({ message: 'Failed to fetch manager profile' });
  }
});

router.patch('/managers/me', requireAuth, async (req, res) => {
  try {
    if (!req.user?.provider || !req.user?.sub) {
      return res.status(401).json({ message: 'Unauthorized' });
    }
    const parsed = updateSchema.safeParse(req.body || {});
    if (!parsed.success) {
      return res.status(400).json({ message: 'Validation failed', details: parsed.error.format() });
    }

    // If app_id provided, ensure not used by another manager
    if (parsed.data.app_id) {
      const conflict = await ManagerModel.findOne({
        app_id: parsed.data.app_id,
        $or: [
          { provider: { $ne: req.user.provider } },
          { subject: { $ne: req.user.sub } },
        ],
      }).lean();
      if (conflict) {
        return res.status(409).json({ message: 'This App ID is already in use' });
      }
    }

    const result = await ManagerModel.updateOne(
      { provider: req.user.provider, subject: req.user.sub },
      { $set: { ...parsed.data, updatedAt: new Date() } }
    );
    if (result.matchedCount === 0) return res.status(404).json({ message: 'Manager not found' });
    const doc = await ManagerModel.findOne({ provider: req.user.provider, subject: req.user.sub }).lean();
    return res.json({
      id: String(doc?._id),
      email: doc?.email,
      first_name: doc?.first_name,
      last_name: doc?.last_name,
      picture: doc?.picture,
      app_id: doc?.app_id,
    });
  } catch (err) {
    return res.status(500).json({ message: 'Failed to update manager profile' });
  }
});

export default router;


