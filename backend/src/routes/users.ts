import { Router } from 'express';
import mongoose from 'mongoose';
import { z } from 'zod';
import { UserModel } from '../models/user';

const router = Router();

const querySchema = z.object({
  q: z.string().optional(),
  cursor: z.string().optional(), // base64 of ObjectId string
  limit: z.coerce.number().min(1).max(100).default(20),
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

    const docs = await UserModel.find(filter, { provider: 1, subject: 1, email: 1, name: 1, picture: 1 })
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
      picture: u.picture,
    }));
    return res.json({ items: mapped, nextCursor });
  } catch (err) {
    return res.status(500).json({ message: 'Failed to fetch users' });
  }
});

export default router;


