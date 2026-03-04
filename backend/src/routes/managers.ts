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
  isCaricature: z.boolean().optional(), // When true, saves current picture as originalPicture
  preferredCity: z.string().trim().min(1).max(200).optional(),
});

router.get('/managers/me', requireAuth, async (req, res) => {
  try {
    if (!(req as any).authUser?.provider || !(req as any).authUser?.sub) {
      return res.status(401).json({ message: 'Unauthorized' });
    }

    let manager = await ManagerModel.findOne({
      provider: (req as any).authUser.provider,
      subject: (req as any).authUser.sub,
    }).lean();

    // Auto-provision a manager profile if it doesn't exist yet
    if (!manager) {
      const created = await ManagerModel.create({
        provider: ((req as any).authUser as any).provider,
        subject: ((req as any).authUser as any).sub,
        email: ((req as any).authUser as any).email,
        name: ((req as any).authUser as any).name,
        picture: ((req as any).authUser as any).picture,
      });
      manager = (created.toObject() as any);
    }

    return res.json({
      id: String((manager as any)._id),
      email: (manager as any).email,
      name: (manager as any).name,
      first_name: (manager as any).first_name,
      last_name: (manager as any).last_name,
      picture: (manager as any).picture,
      originalPicture: (manager as any).originalPicture || null,
      caricatureHistory: (manager as any).caricatureHistory || [],
      app_id: (manager as any).app_id,
      provider: (manager as any).provider,
      linked_providers: (manager as any).linked_providers || [],
      auth_phone_number: (manager as any).auth_phone_number || null,
      phone_number: (manager as any).phone_number || null,
      preferredCity: (manager as any).preferredCity,
      cities: (manager as any).cities || [],
    });
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error('[managers] GET /me failed', err);
    return res.status(500).json({ message: 'Failed to fetch manager profile', error: (err as Error).message });
  }
});

router.patch('/managers/me', requireAuth, async (req, res) => {
  try {
    if (!(req as any).authUser?.provider || !(req as any).authUser?.sub) {
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
          { provider: { $ne: (req as any).authUser.provider } },
          { subject: { $ne: (req as any).authUser.sub } },
        ],
      }).lean();
      if (conflict) {
        return res.status(409).json({ message: 'This App ID is already in use' });
      }
    }

    // If this is a caricature update, save the current picture as originalPicture
    const { isCaricature, ...updateFields } = parsed.data;
    const setData: Record<string, any> = { ...updateFields, updatedAt: new Date() };

    if (isCaricature && updateFields.picture) {
      const current = await ManagerModel.findOne({
        provider: (req as any).authUser.provider,
        subject: (req as any).authUser.sub,
      }).lean();
      if (current?.picture) {
        setData.originalPicture = current.picture;
      }
    }

    const updated = await ManagerModel.findOneAndUpdate(
      { provider: (req as any).authUser.provider, subject: (req as any).authUser.sub },
      {
        $set: setData,
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
      originalPicture: updated.originalPicture || null,
      app_id: updated.app_id,
      preferredCity: updated.preferredCity,
      cities: updated.cities || [],
    });
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error('[managers] PATCH /me failed', err);
    return res.status(500).json({ message: 'Failed to update manager profile', error: (err as Error).message });
  }
});

// POST /managers/me/revert-picture - Revert to original (pre-caricature) picture
router.post('/managers/me/revert-picture', requireAuth, async (req, res) => {
  try {
    if (!(req as any).authUser?.provider || !(req as any).authUser?.sub) {
      return res.status(401).json({ message: 'Unauthorized' });
    }

    const manager = await ManagerModel.findOne({
      provider: (req as any).authUser.provider,
      subject: (req as any).authUser.sub,
    });
    if (!manager) return res.status(404).json({ message: 'Manager not found' });

    if (!manager.originalPicture) {
      return res.status(400).json({ message: 'No original picture to revert to' });
    }

    manager.picture = manager.originalPicture;
    manager.originalPicture = undefined;
    await manager.save();

    return res.json({
      picture: manager.picture,
      originalPicture: null,
      message: 'Reverted to original picture',
    });
  } catch (err) {
    console.error('[managers] POST /me/revert-picture failed', err);
    return res.status(500).json({ message: 'Failed to revert picture', error: (err as Error).message });
  }
});

// DELETE /managers/me/caricatures/:index - Delete a caricature from history
router.delete('/managers/me/caricatures/:index', requireAuth, async (req, res) => {
  try {
    if (!(req as any).authUser?.provider || !(req as any).authUser?.sub) {
      return res.status(401).json({ message: 'Unauthorized' });
    }

    const index = parseInt(req.params.index || '0', 10);
    if (isNaN(index) || index < 0) {
      return res.status(400).json({ message: 'Invalid index parameter' });
    }

    const manager = await ManagerModel.findOne({
      provider: (req as any).authUser.provider,
      subject: (req as any).authUser.sub,
    });
    if (!manager) return res.status(404).json({ message: 'Manager not found' });

    if (!manager.caricatureHistory || index >= manager.caricatureHistory.length) {
      return res.status(404).json({ message: 'Caricature not found at index' });
    }

    manager.caricatureHistory.splice(index, 1);
    await manager.save();

    return res.json({
      message: 'Caricature deleted',
      caricatureHistory: manager.caricatureHistory,
    });
  } catch (err) {
    console.error('[managers] DELETE /me/caricatures/:index failed', err);
    return res.status(500).json({ message: 'Failed to delete caricature', error: (err as Error).message });
  }
});

export default router;
