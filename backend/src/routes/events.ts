import { Router } from 'express';
import { z } from 'zod';
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

export default router;


