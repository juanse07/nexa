import { Router } from 'express';
import mongoose from 'mongoose';
import { z } from 'zod';
import { requireAuth } from '../middleware/requireAuth';
import { AvailabilityModel } from '../models/availability';
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
  third_party_company_name: z.string().nullish(),
  date: z.union([z.string(), z.date()]).nullish(),
  start_time: z.string().nullish(),
  end_time: z.string().nullish(),
  venue_name: z.string().nullish(),
  venue_address: z.string().nullish(),
  venue_latitude: z.number().nullish(),
  venue_longitude: z.number().nullish(),
  google_maps_url: z.string().url().nullish(),
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

function computeRoleStats(roles: any[], accepted: any[]) {
  const acceptedCounts = (accepted || []).reduce((acc: Record<string, number>, m: any) => {
    const key = (m?.role || '').toLowerCase();
    if (!key) return acc;
    acc[key] = (acc[key] || 0) + 1;
    return acc;
  }, {} as Record<string, number>);
  return (roles || []).map((r: any) => {
    const key = (r?.role || '').toLowerCase();
    const capacity = r?.count || 0;
    const taken = acceptedCounts[key] || 0;
    const remaining = Math.max(capacity - taken, 0);
    return { role: r.role, capacity, taken, remaining, is_full: remaining === 0 && capacity > 0 };
  });
}

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
    // Backwards compatibility: accept client_company_name and map to new field
    if ((raw as any).client_company_name && !(raw as any).third_party_company_name) {
      (raw as any).third_party_company_name = (raw as any).client_company_name;
      delete (raw as any).client_company_name;
    }
    // Normalize date to Date type if provided
    const normalized = {
      ...raw,
      date:
        raw.date != null
          ? new Date(typeof raw.date === 'string' ? raw.date : raw.date)
          : undefined,
      accepted_staff:
        raw.accepted_staff?.map((m) => {
          const roleFromPayload = (m?.role || (m as any)?.position || '').trim();
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

    // Persist initial role_stats
    const role_stats = computeRoleStats(normalized.roles as any[], (normalized.accepted_staff as any[]) || []);

    const created = await EventModel.create({ ...normalized, role_stats });
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

    const role_stats = computeRoleStats(roles as any[], accepted as any[]);

    const result = await EventModel.updateOne(
      { _id: new mongoose.Types.ObjectId(eventId) },
      { $set: { roles, role_stats, updatedAt: new Date() } }
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

    const roleVal = roleValRaw;

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
      role: roleVal || undefined,
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

      const roleReq = (event.roles || []).find((r: any) => (r?.role || '').toLowerCase() === roleVal.toLowerCase());
      if (!roleReq) {
        return res.status(400).json({ message: `role '${roleVal}' not found for this event` });
      }

      const acceptedForRole = (event.accepted_staff || []).filter((m: any) => (m?.role || '').toLowerCase() === roleVal.toLowerCase());
      if (acceptedForRole.length >= (roleReq.count || 0)) {
        return res.status(409).json({ message: `No spots left for role '${roleVal}'` });
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

    // Recompute and persist role_stats
    const updatedAfter = await EventModel.findById(eventId).lean();
    if (!updatedAfter) return res.status(404).json({ message: 'Event not found' });
    const role_stats = computeRoleStats((updatedAfter.roles as any[]) || [], (updatedAfter.accepted_staff as any[]) || []);
    await EventModel.updateOne(
      { _id: new mongoose.Types.ObjectId(eventId) },
      { $set: { role_stats, updatedAt: new Date() } }
    );

    const finalDoc = await EventModel.findById(eventId).lean();
    if (!finalDoc) return res.status(404).json({ message: 'Event not found' });
    const mapped = { id: String(finalDoc._id), ...finalDoc } as any;
    delete mapped._id;
    return res.json(mapped);
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error('[respond] failed', err);
    return res.status(500).json({ message: 'Failed to update response' });
  }
});

// Availability APIs
function getUserKey(req: any): string | undefined {
  const provider = req?.user?.provider;
  const sub = req?.user?.sub;
  if (!provider || !sub) return undefined;
  return `${provider}:${sub}`;
}

// Get user's availability blocks
router.get(['/availability', '/events/availability'], requireAuth, async (req, res) => {
  try {
    const userKey = getUserKey(req);
    if (!userKey) return res.status(401).json({ message: 'User not authenticated' });

    const docs = await AvailabilityModel.find({ userKey }).sort({ date: 1, startTime: 1 }).lean();
    const mapped = (docs || []).map((d: any) => {
      const { _id, ...rest } = d;
      return { id: String(_id), ...rest };
    });
    return res.json(mapped);
  } catch (err) {
    return res.status(500).json({ message: 'Failed to fetch availability' });
  }
});

const availabilitySchema = z.object({
  date: z.string().min(1, 'date is required'),
  startTime: z.string().min(1, 'startTime is required'),
  endTime: z.string().min(1, 'endTime is required'),
  status: z.enum(['available', 'unavailable']),
});

// Create or update an availability block
router.post(['/availability', '/events/availability'], requireAuth, async (req, res) => {
  try {
    const userKey = getUserKey(req);
    if (!userKey) return res.status(401).json({ message: 'User not authenticated' });

    const parsed = availabilitySchema.safeParse(req.body);
    if (!parsed.success) {
      return res.status(400).json({ message: 'Validation failed', details: parsed.error.format() });
    }
    const { date, startTime, endTime, status } = parsed.data;

    const result = await AvailabilityModel.updateOne(
      { userKey, date, startTime, endTime },
      { $set: { status, updatedAt: new Date() }, $setOnInsert: { createdAt: new Date(), userKey, date, startTime, endTime } },
      { upsert: true }
    );

    if (result.upsertedId) {
      return res.json({ message: 'Availability created', id: String(result.upsertedId._id) });
    }
    // If not upserted, fetch the existing doc to return id
    const existing = await AvailabilityModel.findOne({ userKey, date, startTime, endTime }, { _id: 1 }).lean();
    return res.json({ message: 'Availability updated', id: existing ? String(existing._id) : undefined });
  } catch (err: any) {
    // Unique index conflict fallback
    if (err?.code === 11000) {
      try {
        const { date, startTime, endTime, status } = req.body || {};
        await AvailabilityModel.updateOne(
          { userKey: getUserKey(req), date, startTime, endTime },
          { $set: { status, updatedAt: new Date() } }
        );
        const existing = await AvailabilityModel.findOne({ userKey: getUserKey(req), date, startTime, endTime }, { _id: 1 }).lean();
        return res.json({ message: 'Availability updated', id: existing ? String(existing._id) : undefined });
      } catch (_) {
        return res.status(500).json({ message: 'Failed to set availability' });
      }
    }
    return res.status(500).json({ message: 'Failed to set availability' });
  }
});

// Delete availability block by id
router.delete(['/availability/:id', '/events/availability/:id'], requireAuth, async (req, res) => {
  try {
    const userKey = getUserKey(req);
    if (!userKey) return res.status(401).json({ message: 'User not authenticated' });

    const availabilityId = req.params.id ?? '';
    if (!mongoose.Types.ObjectId.isValid(availabilityId)) {
      return res.status(400).json({ message: 'Invalid availability id' });
    }

    const result = await AvailabilityModel.deleteOne({ _id: new mongoose.Types.ObjectId(availabilityId), userKey });
    if (result.deletedCount === 0) return res.status(404).json({ message: 'Availability not found' });
    return res.json({ message: 'Availability deleted' });
  } catch (err) {
    return res.status(500).json({ message: 'Failed to delete availability' });
  }
});

// Get current user's attendance record for an event
router.get('/events/:id/attendance/me', requireAuth, async (req, res) => {
  try {
    const eventId = req.params.id ?? '';
    if (!mongoose.Types.ObjectId.isValid(eventId)) {
      return res.status(400).json({ message: 'Invalid event id' });
    }
    if (!req.user?.provider || !req.user?.sub) {
      return res.status(401).json({ message: 'Unauthorized' });
    }
    const userKey = `${req.user.provider}:${req.user.sub}`;
    const event = await EventModel.findById(eventId).lean();
    if (!event) return res.status(404).json({ message: 'Event not found' });
    const member = (event.accepted_staff || []).find((m: any) => (m?.userKey || '') === userKey);
    if (!member) return res.status(404).json({ message: 'Attendance record not found' });
    const attendance = (member.attendance || []) as any[];
    const last = attendance.length > 0 ? attendance[attendance.length - 1] : undefined;
    const isClockedIn = !!(last && !last.clockOutAt);
    return res.json({
      eventId,
      userKey,
      isClockedIn,
      lastClockInAt: last?.clockInAt || null,
      lastClockOutAt: last?.clockOutAt || null,
      attendance,
    });
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error('[attendance/me] failed', err);
    return res.status(500).json({ message: 'Failed to get attendance' });
  }
});

// Clock in to an event
router.post('/events/:id/clock-in', requireAuth, async (req, res) => {
  try {
    const eventId = req.params.id ?? '';
    if (!mongoose.Types.ObjectId.isValid(eventId)) {
      return res.status(400).json({ message: 'Invalid event id' });
    }
    if (!req.user?.provider || !req.user?.sub) {
      return res.status(401).json({ message: 'Unauthorized' });
    }
    const userKey = `${req.user.provider}:${req.user.sub}`;

    const event = await EventModel.findById(eventId).lean();
    if (!event) return res.status(404).json({ message: 'Event not found' });
    const accepted = (event.accepted_staff || []) as any[];
    const idx = accepted.findIndex((m: any) => (m?.userKey || '') === userKey);
    if (idx === -1) {
      return res.status(403).json({ message: 'You are not accepted for this event' });
    }

    const attendance = (accepted[idx].attendance || []) as any[];
    const last = attendance.length > 0 ? attendance[attendance.length - 1] : undefined;
    if (last && !last.clockOutAt) {
      return res.status(409).json({ message: 'Already clocked in' });
    }

    const newAttendance = [...attendance, { clockInAt: new Date() }];
    const result = await EventModel.updateOne(
      { _id: new mongoose.Types.ObjectId(eventId), 'accepted_staff.userKey': userKey },
      { $set: { 'accepted_staff.$.attendance': newAttendance, updatedAt: new Date() } }
    );
    if (result.matchedCount === 0) {
      return res.status(404).json({ message: 'Event not found' });
    }

    return res.status(200).json({ message: 'Clocked in', attendance: newAttendance });
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error('[clock-in] failed', err);
    return res.status(500).json({ message: 'Failed to clock in' });
  }
});

// Clock out from an event
router.post('/events/:id/clock-out', requireAuth, async (req, res) => {
  try {
    const eventId = req.params.id ?? '';
    if (!mongoose.Types.ObjectId.isValid(eventId)) {
      return res.status(400).json({ message: 'Invalid event id' });
    }
    if (!req.user?.provider || !req.user?.sub) {
      return res.status(401).json({ message: 'Unauthorized' });
    }
    const userKey = `${req.user.provider}:${req.user.sub}`;

    const event = await EventModel.findById(eventId).lean();
    if (!event) return res.status(404).json({ message: 'Event not found' });
    const accepted = (event.accepted_staff || []) as any[];
    const idx = accepted.findIndex((m: any) => (m?.userKey || '') === userKey);
    if (idx === -1) {
      return res.status(403).json({ message: 'You are not accepted for this event' });
    }

    const attendance = (accepted[idx].attendance || []) as any[];
    const last = attendance.length > 0 ? attendance[attendance.length - 1] : undefined;
    if (!last || last.clockOutAt) {
      return res.status(409).json({ message: 'Not clocked in' });
    }

    const newAttendance = attendance.slice(0, -1).concat({ ...last, clockOutAt: new Date() });
    const result = await EventModel.updateOne(
      { _id: new mongoose.Types.ObjectId(eventId), 'accepted_staff.userKey': userKey },
      { $set: { 'accepted_staff.$.attendance': newAttendance, updatedAt: new Date() } }
    );
    if (result.matchedCount === 0) {
      return res.status(404).json({ message: 'Event not found' });
    }

    return res.status(200).json({ message: 'Clocked out', attendance: newAttendance });
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error('[clock-out] failed', err);
    return res.status(500).json({ message: 'Failed to clock out' });
  }
});
export default router;


