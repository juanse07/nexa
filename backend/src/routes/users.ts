import { Router } from 'express';
import mongoose from 'mongoose';
import { z } from 'zod';
import { requireAuth } from '../middleware/requireAuth';
import { UserModel } from '../models/user';

const router = Router();

const querySchema = z.object({
  q: z.string().optional(),
  cursor: z.string().optional(), // base64 of ObjectId string
  limit: z.coerce.number().min(1).max(100).default(20),
});

const updateSchema = z.object({
  first_name: z.string().trim().min(1).max(100).optional(),
  last_name: z.string().trim().min(1).max(100).optional(),
  app_id: z
    .string()
    .regex(/^\d{9}$/)
    .optional(),
  picture: z.string().url().max(2048).optional(),
});

router.get('/users/me', requireAuth, async (req, res) => {
  try {
    const authUser = (req as any).authUser;
    if (!authUser?.provider || !authUser?.sub) {
      return res.status(401).json({ message: 'Unauthorized' });
    }

    const user = await UserModel.findOne({
      provider: authUser.provider,
      subject: authUser.sub,
    }).lean();

    if (!user) return res.status(404).json({ message: 'User not found' });
    return res.json({
      id: String(user._id),
      email: user.email,
      name: user.name,
      first_name: user.first_name,
      last_name: user.last_name,
      picture: user.picture,
      app_id: user.app_id,
    });
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error('[users] GET /me failed', err);
    return res.status(500).json({ message: 'Failed to fetch user profile', error: (err as Error).message });
  }
});

router.patch('/users/me', requireAuth, async (req, res) => {
  try {
    const authUser = (req as any).authUser;
    if (!authUser?.provider || !authUser?.sub) {
      return res.status(401).json({ message: 'Unauthorized' });
    }
    const parsed = updateSchema.safeParse(req.body || {});
    if (!parsed.success) {
      return res.status(400).json({ message: 'Validation failed', details: parsed.error.format() });
    }

    // If app_id provided, ensure not used by another user
    if (parsed.data.app_id) {
      const conflict = await UserModel.findOne({
        app_id: parsed.data.app_id,
        $or: [
          { provider: { $ne: authUser.provider } },
          { subject: { $ne: authUser.sub } },
        ],
      }).lean();
      if (conflict) {
        return res.status(409).json({ message: 'This App ID is already in use' });
      }
    }

    const updated = await UserModel.findOneAndUpdate(
      { provider: authUser.provider, subject: authUser.sub },
      {
        $set: { ...parsed.data, updatedAt: new Date() },
      },
      { new: true }
    ).lean();
    if (!updated) return res.status(404).json({ message: 'User not found' });
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
    console.error('[users] PATCH /me failed', err);
    return res.status(500).json({ message: 'Failed to update user profile', error: (err as Error).message });
  }
});

// Cursor-paginated, prefix search by name/email
router.get('/users', async (req, res) => {
  try {
    const parsed = querySchema.safeParse(req.query);
    if (!parsed.success) return res.status(400).json({ message: 'Invalid query' });
    const { q, cursor, limit } = parsed.data;

    const filter: any = {};
    if (q && q.trim().length > 0) {
      const rx = new RegExp('^' + q.trim().replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'i');
      filter.$or = [{ name: rx }, { email: rx }];
    }
    if (cursor) {
      try {
        const idStr = Buffer.from(cursor, 'base64').toString('utf8');
        if (mongoose.Types.ObjectId.isValid(idStr)) {
          filter._id = { $gt: new mongoose.Types.ObjectId(idStr) };
        }
      } catch (_) {}
    }

    const docs = await UserModel.find(filter, { provider: 1, subject: 1, email: 1, name: 1, first_name: 1, last_name: 1, picture: 1, app_id: 1 })
      .sort({ _id: 1 })
      .limit(limit + 1)
      .lean();

    let nextCursor: string | undefined;
    let items = docs;
    if (docs.length > limit) {
      items = docs.slice(0, limit);
      const lastDoc = items[items.length - 1];
      if (lastDoc?._id) {
        nextCursor = Buffer.from(String(lastDoc._id)).toString('base64');
      }
    }

    const mapped = items.map((u: any) => ({
      id: String(u._id),
      provider: u.provider,
      subject: u.subject,
      email: u.email,
      name: u.name,
      first_name: u.first_name,
      last_name: u.last_name,
      picture: u.picture,
      app_id: u.app_id,
    }));
    return res.json({ items: mapped, nextCursor });
  } catch (err) {
    return res.status(500).json({ message: 'Failed to fetch users' });
  }
});

export default router;


