import { Router } from 'express';
import mongoose from 'mongoose';
import { z } from 'zod';
import { requireAuth } from '../middleware/requireAuth';
import { EventModel } from '../models/event';

const router = Router();

const roleSchema = z.object({
  role: z.string().min(1, 'role is required'),
  count: z.number().int().min(1, 'count must be at least 1'),
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
  role: z.string().nullish(),
  // Accept 'position' as alias; we'll normalize it
  position: z.string().nullish(),
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
  roles: z.array(roleSchema).min(1, 'at least one role is required'),
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
        raw.accepted_staff?.map((m) => {
          const roleFromPayload = (m?.role || m?.position || '').trim();
          return {
            ...m,
            role: roleFromPayload || undefined,
            position: undefined,
            respondedAt:
              m?.respondedAt != null
                ? new Date(
                    typeof m.respondedAt === 'string'
                      ? m.respondedAt
                      : (m.respondedAt as Date)
                )
                : undefined,
          };
        }) ?? undefined,
    } as typeof raw;

    // If accepted_staff provided, validate capacity per role
    if (Array.isArray(normalized.accepted_staff) && Array.isArray(normalized.roles)) {
      const roleCap: Record<string, number> = {};
      for (const r of normalized.roles) {
        const key = (r?.role || '').toLowerCase();
        if (!key) continue;
        roleCap[key] = (r?.count as number) || 0;
      }
      const taken: Record<string, number> = {};
      for (const m of normalized.accepted_staff) {
        const key = ((m as any)?.role || '').toLowerCase();
        if (!key) continue;
        taken[key] = (taken[key] || 0) + 1;
      }
      for (const [k, count] of Object.entries(taken)) {
        if ((roleCap[k] || 0) < count) {
          return res.status(409).json({
            message: `Accepted staff exceeds capacity for role '${k}' (${count}/${roleCap[k] || 0})`,
          });
        }
      }
    }

    const created = await EventModel.create(normalized);
    return res.status(201).json(created);
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error('Failed to create event', err);
    return res.status(500).json({ error: 'Internal Server Error' });
  }
});

// Update roles for an event with capacity validation
const updateRolesSchema = z.object({
  roles: z.array(roleSchema).min(1, 'at least one role is required'),
});

router.patch('/events/:id/roles', async (req, res) => {
  try {
    const eventId = req.params.id ?? '';
    if (!mongoose.Types.ObjectId.isValid(eventId)) {
      return res.status(400).json({ message: 'Invalid event id' });
    }

    const parsed = updateRolesSchema.safeParse(req.body);
    if (!parsed.success) {
      return res.status(400).json({
        error: 'Validation failed',
        details: parsed.error.format(),
      });
    }

    const { roles } = parsed.data;
    // Ensure unique role names (case-insensitive)
    const lowerSeen = new Set<string>();
    for (const r of roles) {
      const key = r.role.trim().toLowerCase();
      if (lowerSeen.has(key)) {
        return res.status(400).json({ message: `Duplicate role '${r.role}'` });
      }
      lowerSeen.add(key);
    }

    const event = await EventModel.findById(eventId).lean();
    if (!event) return res.status(404).json({ message: 'Event not found' });

    const accepted = (event.accepted_staff || []) as any[];
    const acceptedCounts = accepted.reduce((acc: Record<string, number>, m) => {
      const key = ((m?.role as string) || '').trim().toLowerCase();
      if (!key) return acc;
      acc[key] = (acc[key] || 0) + 1;
      return acc;
    }, {} as Record<string, number>);

    // Validate that new counts are not below accepted counts
    for (const [roleKey, taken] of Object.entries(acceptedCounts)) {
      const newDef = roles.find((r) => r.role.trim().toLowerCase() === roleKey);
      if (!newDef) {
        return res.status(409).json({
          message: `Cannot remove role; '${roleKey}' has ${taken} accepted staff`,
        });
      }
      if ((newDef.count || 0) < taken) {
        return res.status(409).json({
          message: `Cannot reduce '${newDef.role}' below ${taken} (already accepted)`,
        });
      }
    }

    const result = await EventModel.updateOne(
      { _id: new mongoose.Types.ObjectId(eventId) },
      { $set: { roles, updatedAt: new Date() } }
    );

    if (result.matchedCount === 0) {
      return res.status(404).json({ message: 'Event not found' });
    }

    const updated = await EventModel.findById(eventId).lean();
    return res.json(updated);
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error('[update roles] failed', err);
    return res.status(500).json({ message: 'Failed to update roles' });
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

// Positions view: flatten roles to position cards with remaining spots
router.get('/positions', async (_req, res) => {
  try {
    const events = await EventModel.find().sort({ createdAt: -1 }).lean();
    const positions = (events || []).flatMap((ev: any) => {
      const accepted = ev.accepted_staff || [];
      const roleToAcceptedCount = accepted.reduce((acc: Record<string, number>, m: any) => {
        const key = (m?.role || '').toLowerCase();
        if (!key) return acc;
        acc[key] = (acc[key] || 0) + 1;
        return acc;
      }, {} as Record<string, number>);

      return (ev.roles || []).map((r: any) => {
        const key = (r?.role || '').toLowerCase();
        const capacity = r?.count || 0;
        const taken = roleToAcceptedCount[key] || 0;
        const remaining = Math.max(capacity - taken, 0);
        return {
          eventId: String(ev._id),
          event_name: ev.event_name,
          date: ev.date,
          venue_name: ev.venue_name,
          role: r.role,
          capacity,
          taken,
          remaining,
        };
      });
    });
    return res.json(positions);
  } catch (err) {
    return res.status(500).json({ error: 'Internal Server Error' });
  }
});

router.post('/events/:id/respond', requireAuth, async (req, res) => {
  try {
    const eventId = req.params.id ?? '';
    const responseVal = (req.body?.response ?? '') as string;
    const roleValRaw = (req.body?.role ?? req.body?.position ?? '').trim();
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
    if (responseVal === 'accept' && !roleValRaw) {
      // eslint-disable-next-line no-console
      console.warn('[respond] missing role/position on accept');
      return res.status(400).json({ message: 'role or position is required to accept a position' });
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
      role: roleValRaw || undefined,
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

    // Enforce capacity per role on accept
    if (responseVal === 'accept') {
      const event = await EventModel.findById(eventId).lean();
      if (!event) return res.status(404).json({ message: 'Event not found' });

      const roleReq = (event.roles || []).find((r: any) => (r?.role || '').toLowerCase() === roleValRaw.toLowerCase());
      if (!roleReq) {
        return res.status(400).json({ message: `role '${roleValRaw}' not found for this event` });
      }

      const acceptedForRole = (event.accepted_staff || []).filter((m: any) => (m?.role || '').toLowerCase() === roleValRaw.toLowerCase());
      if (acceptedForRole.length >= (roleReq.count || 0)) {
        return res.status(409).json({ message: `No spots left for role '${roleValRaw}'` });
      }
    }

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


