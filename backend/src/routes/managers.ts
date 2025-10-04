import { Router } from 'express';
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

    const manager = await ManagerModel.findOne({
      provider: req.user.provider,
      subject: req.user.sub,
    }).lean();

    if (!manager) return res.status(404).json({ message: 'Manager not found' });
    return res.json({
      id: String(manager._id),
      email: manager.email,
      name: manager.name,
      first_name: manager.first_name,
      last_name: manager.last_name,
      picture: manager.picture,
      app_id: manager.app_id,
    });
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error('[managers] GET /me failed', err);
    return res.status(500).json({ message: 'Failed to fetch manager profile', error: (err as Error).message });
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

    const updated = await ManagerModel.findOneAndUpdate(
      { provider: req.user.provider, subject: req.user.sub },
      {
        $set: { ...parsed.data, updatedAt: new Date() },
      },
      { new: true }
    ).lean();
    if (!updated) return res.status(404).json({ message: 'Manager not found' });
    return res.json({
      id: String(updated._id),
      email: updated.email,
      name: updated.name,
      first_name: updated.first_name,
      last_name: updated.last_name,
      picture: updated.picture,
      app_id: updated.app_id,
    });
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error('[managers] PATCH /me failed', err);
    return res.status(500).json({ message: 'Failed to update manager profile', error: (err as Error).message });
  }
});

export default router;


