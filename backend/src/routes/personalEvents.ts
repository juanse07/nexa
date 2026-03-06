import express from 'express';
import { z } from 'zod';
import { requireAuth } from '../middleware/requireAuth';
import { requireActiveSubscription } from '../middleware/requireActiveSubscription';
import { PersonalEventModel } from '../models/personalEvent';
import { AvailabilityModel } from '../models/availability';
import { UserModel } from '../models/user';

const router = express.Router();

// ── Validation ──────────────────────────────────────────────────────────
const personalEventSchema = z.object({
  title: z.string().min(1).max(200),
  date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'Date must be YYYY-MM-DD'),
  startTime: z.string().regex(/^\d{2}:\d{2}$/, 'Start time must be HH:mm'),
  endTime: z.string().regex(/^\d{2}:\d{2}$/, 'End time must be HH:mm'),
  notes: z.string().max(1000).optional(),
  location: z.string().max(300).optional(),
  role: z.string().max(100).optional(),
  client: z.string().max(200).optional(),
  hourlyRate: z.number().min(0).max(10000).optional(),
  currency: z.string().max(10).optional(),
});

const updateSchema = personalEventSchema.partial();

// ── Helpers ─────────────────────────────────────────────────────────────
const PRO_TIERS = ['pro', 'premium'];

async function getUserTier(provider: string, subject: string): Promise<string> {
  const user = await UserModel.findOne({ provider, subject })
    .select('subscription_tier free_month_end_override createdAt')
    .lean();
  if (!user) return 'free';

  // Check if in free month
  const freeMonthEnd = (user as any).free_month_end_override || new Date((user as any).createdAt?.getTime?.() + 30 * 24 * 60 * 60 * 1000);
  if (new Date() < new Date(freeMonthEnd)) return 'premium'; // free month = premium access

  return (user as any).subscription_tier || 'free';
}

/** Create an unavailability record linked to a personal event */
async function createLinkedAvailability(
  userKey: string,
  date: string,
  startTime: string,
  endTime: string,
  personalEventId: any,
  notes?: string,
) {
  const avail = await AvailabilityModel.create({
    userKey,
    date,
    startTime,
    endTime,
    status: 'unavailable',
    notes: notes || undefined,
    personalEventId,
    source: 'personal_event',
  });
  return avail;
}

// ── POST /personal-events  (Create) ────────────────────────────────────
router.post('/personal-events', requireAuth, requireActiveSubscription, async (req, res) => {
  try {
    const { provider, sub } = (req as any).user;
    if (!provider || !sub) return res.status(401).json({ message: 'Unauthorized' });

    // Tier gate: Pro+ only
    const tier = await getUserTier(provider, sub);
    if (!PRO_TIERS.includes(tier)) {
      const canUpgrade = tier === 'starter';
      return res.status(402).json({
        message: 'Personal events require a Pro subscription.',
        upgradeRequired: canUpgrade,
      });
    }

    const parsed = personalEventSchema.safeParse(req.body);
    if (!parsed.success) {
      return res.status(400).json({ message: 'Invalid request', errors: parsed.error.errors });
    }

    const { title, date, startTime, endTime, notes, location, role, client, hourlyRate, currency } = parsed.data;

    // Reject past dates
    const eventDate = new Date(date + 'T00:00:00');
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    if (eventDate < today) {
      return res.status(400).json({ message: 'Cannot create personal events in the past.' });
    }

    const userKey = `${provider}:${sub}`;

    // Create the personal event
    const personalEvent = await PersonalEventModel.create({
      userKey,
      title,
      date: eventDate,
      startTime,
      endTime,
      notes: notes || undefined,
      location: location || undefined,
      role: role || undefined,
      client: client || undefined,
      hourlyRate: hourlyRate ?? undefined,
      currency: currency || undefined,
    });

    // Auto-create linked availability record
    const avail = await createLinkedAvailability(
      userKey, date, startTime, endTime, personalEvent._id, notes,
    );

    // Back-link the availability ID
    personalEvent.availabilityId = avail._id as any;
    await personalEvent.save();

    return res.status(201).json({
      message: 'Personal event created',
      event: {
        id: String(personalEvent._id),
        title: personalEvent.title,
        date: date,
        startTime: personalEvent.startTime,
        endTime: personalEvent.endTime,
        notes: personalEvent.notes,
        location: personalEvent.location,
        role: personalEvent.role,
        client: personalEvent.client,
        hourlyRate: personalEvent.hourlyRate,
        currency: personalEvent.currency,
        availabilityId: String(avail._id),
        createdAt: personalEvent.createdAt,
      },
    });
  } catch (err: any) {
    console.error('[POST /personal-events] Error:', err);
    return res.status(500).json({ message: 'Internal server error' });
  }
});

// ── GET /personal-events/suggestions  (Autocomplete from own history) ──
// Returns distinct roles and clients from the user's OWN personal events.
// Does NOT read any manager, team, or shared database.
router.get('/personal-events/suggestions', requireAuth, async (req, res) => {
  try {
    const { provider, sub } = (req as any).user;
    if (!provider || !sub) return res.status(401).json({ message: 'Unauthorized' });

    const userKey = `${provider}:${sub}`;

    const [roles, clients] = await Promise.all([
      PersonalEventModel.distinct('role', { userKey, role: { $nin: [null, ''] } }),
      PersonalEventModel.distinct('client', { userKey, client: { $nin: [null, ''] } }),
    ]);

    return res.json({
      roles: roles.filter(Boolean),
      clients: clients.filter(Boolean),
    });
  } catch (err: any) {
    console.error('[GET /personal-events/suggestions] Error:', err);
    return res.status(500).json({ message: 'Internal server error' });
  }
});

// ── GET /personal-events  (List) ───────────────────────────────────────
router.get('/personal-events', requireAuth, async (req, res) => {
  try {
    const { provider, sub } = (req as any).user;
    if (!provider || !sub) return res.status(401).json({ message: 'Unauthorized' });

    const userKey = `${provider}:${sub}`;
    const filter: any = { userKey };

    // Optional period filter
    const period = req.query.period as string | undefined;
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    if (period === 'future') {
      filter.date = { $gte: today };
    } else if (period === 'past') {
      filter.date = { $lt: today };
    }

    const events = await PersonalEventModel.find(filter).sort({ date: -1 }).lean();

    return res.json({
      events: events.map((e) => ({
        id: String(e._id),
        title: e.title,
        date: e.date instanceof Date ? e.date.toISOString().split('T')[0] : String(e.date),
        startTime: e.startTime,
        endTime: e.endTime,
        notes: e.notes,
        location: e.location,
        role: e.role,
        client: e.client,
        hourlyRate: e.hourlyRate,
        currency: e.currency,
        availabilityId: e.availabilityId ? String(e.availabilityId) : undefined,
        createdAt: e.createdAt,
        updatedAt: e.updatedAt,
      })),
    });
  } catch (err: any) {
    console.error('[GET /personal-events] Error:', err);
    return res.status(500).json({ message: 'Internal server error' });
  }
});

// ── PUT /personal-events/:id  (Update) ─────────────────────────────────
router.put('/personal-events/:id', requireAuth, async (req, res) => {
  try {
    const { provider, sub } = (req as any).user;
    if (!provider || !sub) return res.status(401).json({ message: 'Unauthorized' });

    const userKey = `${provider}:${sub}`;
    const eventId = req.params.id;

    const existing = await PersonalEventModel.findOne({ _id: eventId, userKey });
    if (!existing) return res.status(404).json({ message: 'Personal event not found' });

    const parsed = updateSchema.safeParse(req.body);
    if (!parsed.success) {
      return res.status(400).json({ message: 'Invalid request', errors: parsed.error.errors });
    }

    const updates = parsed.data;

    // If date changed, reject past dates
    if (updates.date) {
      const newDate = new Date(updates.date + 'T00:00:00');
      const today = new Date();
      today.setHours(0, 0, 0, 0);
      if (newDate < today) {
        return res.status(400).json({ message: 'Cannot move personal event to a past date.' });
      }
    }

    // Update the personal event
    if (updates.date) (existing as any).date = new Date(updates.date + 'T00:00:00');
    if (updates.title !== undefined) existing.title = updates.title;
    if (updates.startTime !== undefined) existing.startTime = updates.startTime;
    if (updates.endTime !== undefined) existing.endTime = updates.endTime;
    if (updates.notes !== undefined) existing.notes = updates.notes;
    if (updates.location !== undefined) existing.location = updates.location;
    if (updates.role !== undefined) (existing as any).role = updates.role || undefined;
    if (updates.client !== undefined) (existing as any).client = updates.client || undefined;
    if (updates.hourlyRate !== undefined) (existing as any).hourlyRate = updates.hourlyRate ?? undefined;
    if (updates.currency !== undefined) (existing as any).currency = updates.currency || undefined;
    await existing.save();

    // Update linked availability record
    if (existing.availabilityId) {
      const availUpdates: any = { status: 'unavailable', source: 'personal_event' };
      if (updates.date) availUpdates.date = updates.date;
      if (updates.startTime) availUpdates.startTime = updates.startTime;
      if (updates.endTime) availUpdates.endTime = updates.endTime;
      if (updates.notes !== undefined) availUpdates.notes = updates.notes;
      await AvailabilityModel.findByIdAndUpdate(existing.availabilityId, availUpdates);
    }

    const dateStr = existing.date instanceof Date
      ? existing.date.toISOString().split('T')[0]
      : String(existing.date);

    return res.json({
      message: 'Personal event updated',
      event: {
        id: String(existing._id),
        title: existing.title,
        date: dateStr,
        startTime: existing.startTime,
        endTime: existing.endTime,
        notes: existing.notes,
        location: existing.location,
        role: (existing as any).role,
        client: (existing as any).client,
        hourlyRate: (existing as any).hourlyRate,
        currency: (existing as any).currency,
        availabilityId: existing.availabilityId ? String(existing.availabilityId) : undefined,
        updatedAt: existing.updatedAt,
      },
    });
  } catch (err: any) {
    console.error('[PUT /personal-events/:id] Error:', err);
    return res.status(500).json({ message: 'Internal server error' });
  }
});

// ── DELETE /personal-events/:id  (Delete) ──────────────────────────────
router.delete('/personal-events/:id', requireAuth, async (req, res) => {
  try {
    const { provider, sub } = (req as any).user;
    if (!provider || !sub) return res.status(401).json({ message: 'Unauthorized' });

    const userKey = `${provider}:${sub}`;
    const eventId = req.params.id;

    const existing = await PersonalEventModel.findOne({ _id: eventId, userKey });
    if (!existing) return res.status(404).json({ message: 'Personal event not found' });

    // Delete linked availability record first
    if (existing.availabilityId) {
      await AvailabilityModel.findByIdAndDelete(existing.availabilityId);
    }

    await PersonalEventModel.deleteOne({ _id: eventId });

    return res.json({ message: 'Personal event deleted' });
  } catch (err: any) {
    console.error('[DELETE /personal-events/:id] Error:', err);
    return res.status(500).json({ message: 'Internal server error' });
  }
});

export default router;
