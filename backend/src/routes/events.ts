import { Router } from 'express';
import mongoose from 'mongoose';
import { z } from 'zod';
import { requireAuth } from '../middleware/requireAuth';
import { EventModel } from '../models/event';

const router = Router();

const roleSchema = z.object({
  role: z.string().nullish(),
  count: z.number().int().nullish(),
  call_time: z.string().nullish(),
});

const acceptedStaffSchema = z.object({
  userKey: z.string().nullish(),
  provider: z.string().nullish(),
  subject: z.string().nullish(),
  email: z.string().email().nullish(),
  name: z.string().nullish(),
  first_name: z.string().nullish(),
  last_name: z.string().nullish(),
  picture: z.string().url().nullish(),
  response: z.string().nullish(),
  respondedAt: z.union([z.string(), z.date()]).nullish(),
});

const eventSchema = z.object({
  event_name: z.string().nullish(),
  client_name: z.string().nullish(),
  date: z.union([z.string(), z.date()]).nullish(),
  start_time: z.string().nullish(),
  end_time: z.string().nullish(),
  venue_name: z.string().nullish(),
  venue_address: z.string().nullish(),
  city: z.string().nullish(),
  state: z.string().nullish(),
  country: z.string().nullish(),
  contact_name: z.string().nullish(),
  contact_phone: z.string().nullish(),
  contact_email: z.string().email().nullish(),
  setup_time: z.string().nullish(),
  uniform: z.string().nullish(),
  notes: z.string().nullish(),
  headcount_total: z.number().int().nullish(),
  roles: z.array(roleSchema).nullish(),
  pay_rate_info: z.string().nullish(),
  accepted_staff: z.array(acceptedStaffSchema).nullish(),
});

router.post('/events', async (req, res) => {
  try {
    const parsed = eventSchema.safeParse(req.body);
    if (!parsed.success) {
      return res.status(400).json({
        error: 'Validation failed',
        details: parsed.error.format(),
      });
    }

    const raw = parsed.data;
    // Normalize date to Date type if provided
    const normalized = {
      ...raw,
      date:
        raw.date != null
          ? new Date(typeof raw.date === 'string' ? raw.date : raw.date)
          : undefined,
      accepted_staff:
        raw.accepted_staff?.map((m) => ({
          ...m,
          respondedAt:
            m?.respondedAt != null
              ? new Date(
                  typeof m.respondedAt === 'string'
                    ? m.respondedAt
                    : (m.respondedAt as Date)
                )
              : undefined,
        })) ?? undefined,
    } as typeof raw;

    const created = await EventModel.create(normalized);
    return res.status(201).json(created);
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error('Failed to create event', err);
    return res.status(500).json({ error: 'Internal Server Error' });
  }
});

router.get('/events', async (_req, res) => {
  try {
    const events = await EventModel.find().sort({ createdAt: -1 }).lean();
    return res.json(events);
  } catch (err) {
    return res.status(500).json({ error: 'Internal Server Error' });
  }
});

router.post('/events/:id/respond', requireAuth, async (req, res) => {
  try {
    const eventId = req.params.id ?? '';
    const responseVal = (req.body?.response ?? '') as string;
    if (!mongoose.Types.ObjectId.isValid(eventId)) {
      // eslint-disable-next-line no-console
      console.warn('[respond] invalid event id', { eventId });
      return res.status(400).json({ message: 'Invalid event id' });
    }
    if (responseVal !== 'accept' && responseVal !== 'decline') {
      // eslint-disable-next-line no-console
      console.warn('[respond] invalid response value', { responseVal });
      return res.status(400).json({ message: "response must be 'accept' or 'decline'" });
    }
    if (!req.user?.provider || !req.user?.sub) {
      // eslint-disable-next-line no-console
      console.warn('[respond] unauthorized: missing user claims');
      return res.status(401).json({ message: 'Unauthorized' });
    }

    const userKey = `${req.user.provider}:${req.user.sub}`;

    const firstName = req.user.name
      ? req.user.name.trim().split(/\s+/).slice(0, -1).join(' ') || undefined
      : undefined;
    const lastName = req.user.name
      ? req.user.name.trim().split(/\s+/).slice(-1)[0] || undefined
      : undefined;

    const staffDoc = {
      userKey,
      provider: req.user.provider,
      subject: req.user.sub,
      email: req.user.email,
      name: req.user.name,
      first_name: firstName,
      last_name: lastName,
      picture: req.user.picture,
      response: responseVal,
      respondedAt: new Date(),
    };

    // Clear prior responses
    await EventModel.updateOne(
      { _id: new mongoose.Types.ObjectId(eventId) },
      { $pull: { accepted_staff: userKey, declined_staff: userKey } as any }
    );
    await EventModel.updateOne(
      { _id: new mongoose.Types.ObjectId(eventId) },
      { $pull: { accepted_staff: { userKey }, declined_staff: { userKey } } as any }
    );

    const targetField = responseVal === 'accept' ? 'accepted_staff' : 'declined_staff';
    const result = await EventModel.updateOne(
      { _id: new mongoose.Types.ObjectId(eventId) },
      { $push: { [targetField]: staffDoc } as any, $set: { updatedAt: new Date() } }
    );

    if (result.matchedCount === 0) {
      // eslint-disable-next-line no-console
      console.warn('[respond] event not found', { eventId });
      return res.status(404).json({ message: 'Event not found' });
    }

    const updated = await EventModel.findById(eventId).lean();
    if (!updated) return res.status(404).json({ message: 'Event not found' });
    const mapped = { id: String(updated._id), ...updated } as any;
    delete mapped._id;
    return res.json(mapped);
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error('[respond] failed', err);
    return res.status(500).json({ message: 'Failed to update response' });
  }
});
export default router;


