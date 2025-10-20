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
  firstName: z.string().trim().min(1).max(100).optional(),
  lastName: z.string().trim().min(1).max(100).optional(),
  phoneNumber: z
    .string()
    .regex(
      /^(\d{3}-\d{3}-\d{4}|\d{10})$/,
      'Phone number must be in US format: XXX-XXX-XXXX or XXXXXXXXXX'
    )
    .optional(),
  appId: z
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
      firstName: user.first_name,
      lastName: user.last_name,
      phoneNumber: user.phone_number,
      picture: user.picture,
      appId: user.app_id,
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

    // eslint-disable-next-line no-console
    console.log('[users] PATCH /me - Request body:', JSON.stringify(req.body));

    const parsed = updateSchema.safeParse(req.body || {});
    if (!parsed.success) {
      // eslint-disable-next-line no-console
      console.error('[users] PATCH /me - Validation failed:', parsed.error.issues);
      return res.status(400).json({ message: 'Validation failed', details: parsed.error.issues });
    }

    // eslint-disable-next-line no-console
    console.log('[users] PATCH /me - Parsed data:', JSON.stringify(parsed.data));

    // If appId provided, ensure not used by another user
    if (parsed.data.appId) {
      const conflict = await UserModel.findOne({
        app_id: parsed.data.appId,
        $or: [
          { provider: { $ne: authUser.provider } },
          { subject: { $ne: authUser.sub } },
        ],
      }).lean();
      if (conflict) {
        return res.status(409).json({ message: 'This App ID is already in use' });
      }
    }

    // Map camelCase to snake_case for database
    const dbUpdate: any = { updatedAt: new Date() };
    if (parsed.data.firstName !== undefined) dbUpdate.first_name = parsed.data.firstName;
    if (parsed.data.lastName !== undefined) dbUpdate.last_name = parsed.data.lastName;
    if (parsed.data.phoneNumber !== undefined) dbUpdate.phone_number = parsed.data.phoneNumber;
    if (parsed.data.appId !== undefined) dbUpdate.app_id = parsed.data.appId;
    if (parsed.data.picture !== undefined) dbUpdate.picture = parsed.data.picture;

    // eslint-disable-next-line no-console
    console.log('[users] PATCH /me - DB update object:', JSON.stringify(dbUpdate));

    const updated = await UserModel.findOneAndUpdate(
      { provider: authUser.provider, subject: authUser.sub },
      {
        $set: dbUpdate,
      },
      { new: true }
    ).lean();
    if (!updated) return res.status(404).json({ message: 'User not found' });

    // eslint-disable-next-line no-console
    console.log('[users] PATCH /me - Updated user:', JSON.stringify({
      id: updated._id,
      first_name: updated.first_name,
      last_name: updated.last_name,
      phone_number: updated.phone_number,
    }));
    return res.json({
      id: String(updated._id),
      email: updated.email,
      name: updated.name,
      firstName: updated.first_name,
      lastName: updated.last_name,
      phoneNumber: updated.phone_number,
      picture: updated.picture,
      appId: updated.app_id,
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
