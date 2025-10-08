import { Router } from 'express';
import mongoose from 'mongoose';
import { z } from 'zod';
import { requireAuth } from '../middleware/requireAuth';
import { AvailabilityModel } from '../models/availability';
import { EventModel } from '../models/event';
import { TariffModel } from '../models/tariff';
import { ClientModel } from '../models/client';
import { RoleModel } from '../models/role';

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
  audience_user_keys: z.array(z.string()).nullish(),
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

// Helper to enrich events with tariff data per role
async function enrichEventsWithTariffs(events: any[]): Promise<any[]> {
  // Build a map of client names to IDs
  const clientNames = Array.from(new Set(events.map(e => e.client_name).filter(Boolean)));
  const clients = await ClientModel.find({
    normalizedName: { $in: clientNames.map(n => n.toLowerCase().trim()) }
  }).lean();
  const clientNameToId = new Map(clients.map(c => [c.normalizedName, c._id.toString()]));

  // Build a map of role names to IDs
  const roleNames = Array.from(new Set(
    events.flatMap(e => (e.roles || []).map((r: any) => r.role)).filter(Boolean)
  ));
  const rolesData = await RoleModel.find({
    normalizedName: { $in: roleNames.map(n => n.toLowerCase().trim()) }
  }).lean();
  const roleNameToId = new Map(rolesData.map(r => [r.normalizedName, r._id.toString()]));

  // Fetch all relevant tariffs in one query
  const clientIds = Array.from(clientNameToId.values());
  const roleIds = Array.from(roleNameToId.values());
  const tariffs = await TariffModel.find({
    clientId: { $in: clientIds.map(id => new mongoose.Types.ObjectId(id)) },
    roleId: { $in: roleIds.map(id => new mongoose.Types.ObjectId(id)) }
  }).lean();

  // Build a map: clientId_roleId -> tariff
  const tariffMap = new Map(
    tariffs.map(t => [`${t.clientId}_${t.roleId}`, t])
  );

  // Enrich each event's roles with tariff data
  return events.map(event => {
    const clientId = clientNameToId.get(event.client_name?.toLowerCase().trim());

    const enrichedRoles = (event.roles || []).map((role: any) => {
      const roleId = roleNameToId.get(role.role?.toLowerCase().trim());

      if (clientId && roleId) {
        const tariff = tariffMap.get(`${clientId}_${roleId}`);
        if (tariff) {
          return {
            ...role,
            tariff: {
              rate: tariff.rate,
              currency: tariff.currency,
              rateDisplay: `${tariff.currency} ${tariff.rate.toFixed(2)}/hr`
            }
          };
        }
      }

      return role;
    });

    return {
      ...event,
      roles: enrichedRoles
    };
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

    const raw = parsed.data as any;
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
        raw.accepted_staff?.map((m: any) => {
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

// Update an event (partial update)
router.patch('/events/:id', async (req, res) => {
  try {
    const eventId = req.params.id ?? '';
    if (!mongoose.Types.ObjectId.isValid(eventId)) {
      return res.status(400).json({ message: 'Invalid event id' });
    }

    const updateData = { ...req.body };
    delete updateData._id;
    delete updateData.id;

    // Normalize date if provided
    if (updateData.date) {
      updateData.date = new Date(updateData.date);
    }

    // Update the event
    const result = await EventModel.updateOne(
      { _id: new mongoose.Types.ObjectId(eventId) },
      { $set: { ...updateData, updatedAt: new Date() } }
    );

    if (result.matchedCount === 0) {
      return res.status(404).json({ message: 'Event not found' });
    }

    const updated = await EventModel.findById(eventId).lean();
    if (!updated) {
      return res.status(404).json({ message: 'Event not found after update' });
    }
    return res.json({ ...updated, id: String(updated._id) });
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error('[update event] failed', err);
    return res.status(500).json({ message: 'Failed to update event' });
  }
});

router.get('/events', async (_req, res) => {
  try {
    const audienceKey = (_req.headers['x-user-key'] as string | undefined) || undefined;
    const lastSyncParam = _req.query.lastSync as string | undefined;

    const filter: any = {};

    // Delta sync: only return documents updated after lastSync timestamp
    if (lastSyncParam) {
      try {
        const lastSyncDate = new Date(lastSyncParam);
        if (!isNaN(lastSyncDate.getTime())) {
          filter.updatedAt = { $gt: lastSyncDate };
        }
      } catch (e) {
        // Invalid date format, ignore and return all
      }
    }

    if (audienceKey) {
      filter.$or = [
        { audience_user_keys: { $size: 0 } },
        { audience_user_keys: { $exists: false } },
        { audience_user_keys: audienceKey },
      ];
    }
    const events = await EventModel.find(filter).sort({ createdAt: -1 }).lean();

    // Map events to include id field as string
    const mappedEvents = events.map((event: any) => ({
      ...event,
      id: String(event._id),
    }));

    // Enrich with tariff data
    const enrichedEvents = await enrichEventsWithTariffs(mappedEvents);

    // Include current server timestamp for next sync
    return res.json({
      events: enrichedEvents,
      serverTimestamp: new Date().toISOString(),
      deltaSync: !!lastSyncParam
    });
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

// Remove accepted staff member from event
router.delete('/events/:id/staff/:userKey', async (req, res) => {
  try {
    const eventId = req.params.id ?? '';
    const userKey = req.params.userKey ?? '';

    if (!mongoose.Types.ObjectId.isValid(eventId)) {
      return res.status(400).json({ message: 'Invalid event id' });
    }

    if (!userKey) {
      return res.status(400).json({ message: 'User key is required' });
    }

    const event = await EventModel.findById(eventId).lean();
    if (!event) return res.status(404).json({ message: 'Event not found' });

    // Remove the staff member from accepted_staff array
    const result = await EventModel.updateOne(
      { _id: new mongoose.Types.ObjectId(eventId) },
      {
        $pull: { accepted_staff: { userKey } } as any,
        $set: { updatedAt: new Date() }
      }
    );

    if (result.matchedCount === 0) {
      return res.status(404).json({ message: 'Event not found' });
    }

    // Recompute and persist role_stats
    const updatedEvent = await EventModel.findById(eventId).lean();
    if (!updatedEvent) return res.status(404).json({ message: 'Event not found' });
    const role_stats = computeRoleStats((updatedEvent.roles as any[]) || [], (updatedEvent.accepted_staff as any[]) || []);
    await EventModel.updateOne(
      { _id: new mongoose.Types.ObjectId(eventId) },
      { $set: { role_stats, updatedAt: new Date() } }
    );

    const finalDoc = await EventModel.findById(eventId).lean();
    return res.json(finalDoc);
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error('[remove staff] failed', err);
    return res.status(500).json({ message: 'Failed to remove staff member' });
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

// Analyze sign-in sheet photo with OpenAI
router.post('/events/:id/analyze-sheet', async (req, res) => {
  try {
    const eventId = req.params.id ?? '';
    if (!mongoose.Types.ObjectId.isValid(eventId)) {
      return res.status(400).json({ message: 'Invalid event id' });
    }

    const { imageBase64, openaiApiKey } = req.body;
    if (!imageBase64 || !openaiApiKey) {
      return res.status(400).json({ message: 'imageBase64 and openaiApiKey required' });
    }

    const event = await EventModel.findById(eventId).lean();
    if (!event) return res.status(404).json({ message: 'Event not found' });

    // Get accepted staff for context
    const staffList = (event.accepted_staff || []).map((s: any) => ({
      name: s.name || `${s.first_name} ${s.last_name}`,
      role: s.role,
    }));

    // Call OpenAI API
    const prompt = `You are a timesheet data extractor. Analyze this sign-in/sign-out sheet photo and extract staff hours.

Event: ${event.event_name}
Expected Staff: ${JSON.stringify(staffList)}

Extract for each person:
- name (string): Staff member name
- role (string): Their role/position
- signInTime (string): Time they signed in (format: HH:MM AM/PM)
- signOutTime (string): Time they signed out (format: HH:MM AM/PM)
- notes (string, optional): Any notes or observations

Return ONLY valid JSON in this exact format:
{
  "staffHours": [
    {
      "name": "John Doe",
      "role": "Bartender",
      "signInTime": "5:00 PM",
      "signOutTime": "11:30 PM",
      "notes": ""
    }
  ]
}`;

    const openaiResponse = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${openaiApiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model: 'gpt-4o-mini',
        messages: [
          {
            role: 'user',
            content: [
              { type: 'text', text: prompt },
              {
                type: 'image_url',
                image_url: { url: `data:image/png;base64,${imageBase64}` },
              },
            ],
          },
        ],
        temperature: 0,
        max_tokens: 1000,
      }),
    });

    if (!openaiResponse.ok) {
      const errorText = await openaiResponse.text();
      return res.status(openaiResponse.status).json({
        message: 'OpenAI API error',
        details: errorText,
      });
    }

    const aiResult = await openaiResponse.json();
    const content = aiResult.choices?.[0]?.message?.content || '{}';

    // Parse JSON from response
    const start = content.indexOf('{');
    const end = content.lastIndexOf('}');
    if (start === -1 || end === -1) {
      return res.status(500).json({ message: 'Failed to parse AI response' });
    }

    const extracted = JSON.parse(content.substring(start, end + 1));
    return res.json(extracted);
  } catch (err) {
    console.error('[analyze-sheet] failed', err);
    return res.status(500).json({ message: 'Failed to analyze sheet' });
  }
});

// Submit hours from sign-in sheet
router.post('/events/:id/submit-hours', async (req, res) => {
  try {
    const eventId = req.params.id ?? '';
    if (!mongoose.Types.ObjectId.isValid(eventId)) {
      return res.status(400).json({ message: 'Invalid event id' });
    }

    const { staffHours, sheetPhotoUrl, submittedBy } = req.body;
    if (!Array.isArray(staffHours)) {
      return res.status(400).json({ message: 'staffHours array required' });
    }

    const event = await EventModel.findById(eventId);
    if (!event) return res.status(404).json({ message: 'Event not found' });

    // Update each staff member's attendance with sheet data
    const acceptedStaff = event.accepted_staff || [];

    console.log(`[submit-hours] Processing ${staffHours.length} staff members`);
    console.log(`[submit-hours] Event has ${acceptedStaff.length} accepted staff`);

    for (const hours of staffHours) {
      console.log(`[submit-hours] Looking for: "${hours.name}" with role: "${hours.role}"`);

      // Try multiple matching strategies
      const nameLower = hours.name?.toLowerCase().trim() || '';
      const roleLower = hours.role?.toLowerCase().trim() || '';

      const staffMember = acceptedStaff.find((s: any) => {
        const staffName = (s.name || `${s.first_name || ''} ${s.last_name || ''}`).toLowerCase().trim();
        const staffRole = (s.role || '').toLowerCase().trim();

        // Match by name (contains or exact)
        const nameMatch = staffName.includes(nameLower) || nameLower.includes(staffName);

        // Match by role if provided
        const roleMatch = !roleLower || !staffRole || staffRole === roleLower;

        console.log(`  Checking: "${staffName}" (${staffRole}) - nameMatch=${nameMatch}, roleMatch=${roleMatch}`);

        return nameMatch && roleMatch;
      });

      if (staffMember) {
        console.log(`  ✓ Found staff member: ${staffMember.name || staffMember.userKey}`);
      } else {
        console.log(`  ✗ No match found for "${hours.name}"`);
        console.log(`  Available staff:`, acceptedStaff.map((s: any) => ({
          name: s.name || `${s.first_name} ${s.last_name}`,
          role: s.role,
          userKey: s.userKey
        })));
        continue; // Skip this person
      }

      if (staffMember) {
        // Initialize attendance array if it doesn't exist
        if (!staffMember.attendance) {
          staffMember.attendance = [];
        }

        // If there's a recent attendance session (clocked in), update it
        // Otherwise, create a new session from sheet data
        let attendanceSession: any;
        if (staffMember.attendance.length > 0) {
          attendanceSession = staffMember.attendance[staffMember.attendance.length - 1];
        } else {
          // Create new attendance session from sheet data
          const newSession = {
            clockInAt: new Date(), // Use current time as placeholder
          };
          staffMember.attendance.push(newSession);
          attendanceSession = newSession;
        }

        // Update with sheet data
        if (hours.signInTime) {
          attendanceSession.sheetSignInTime = new Date(`1970-01-01 ${hours.signInTime}`);
        }
        if (hours.signOutTime) {
          attendanceSession.sheetSignOutTime = new Date(`1970-01-01 ${hours.signOutTime}`);
        }
        if (hours.approvedHours != null) {
          attendanceSession.approvedHours = hours.approvedHours;
          console.log(`[submit-hours] Set approvedHours=${hours.approvedHours} for ${hours.name}`);
        }
        if (hours.notes) {
          attendanceSession.managerNotes = hours.notes;
        }
        attendanceSession.status = 'sheet_submitted';
      }
    }

    event.signInSheetPhotoUrl = sheetPhotoUrl;
    event.hoursStatus = 'sheet_submitted';
    event.hoursSubmittedBy = submittedBy;
    event.hoursSubmittedAt = new Date();

    await event.save();

    // Count how many staff have approved hours set
    const staffWithHours = acceptedStaff.filter((s: any) => {
      return s.attendance && s.attendance.some((a: any) => a.approvedHours != null);
    }).length;

    console.log(`[submit-hours] Successfully set hours for ${staffWithHours}/${staffHours.length} staff members`);

    return res.json({
      message: 'Hours submitted successfully',
      processedCount: staffWithHours,
      totalCount: staffHours.length,
      event
    });
  } catch (err) {
    console.error('[submit-hours] failed', err);
    return res.status(500).json({ message: 'Failed to submit hours' });
  }
});

// Approve hours for individual staff member
router.post('/events/:id/approve-hours/:userKey', async (req, res) => {
  try {
    const eventId = req.params.id ?? '';
    const userKey = req.params.userKey ?? '';

    if (!mongoose.Types.ObjectId.isValid(eventId)) {
      return res.status(400).json({ message: 'Invalid event id' });
    }

    const { approvedHours, approvedBy, notes } = req.body;
    if (approvedHours == null) {
      return res.status(400).json({ message: 'approvedHours required' });
    }

    const event = await EventModel.findById(eventId);
    if (!event) return res.status(404).json({ message: 'Event not found' });

    const staffMember = (event.accepted_staff || []).find(
      (s: any) => s.userKey === userKey
    );

    if (!staffMember) {
      return res.status(404).json({ message: 'Staff member not found' });
    }

    if (staffMember.attendance && staffMember.attendance.length > 0) {
      const lastAttendance = staffMember.attendance[staffMember.attendance.length - 1];
      if (lastAttendance) {
        lastAttendance.approvedHours = approvedHours;
        lastAttendance.approvedBy = approvedBy;
        lastAttendance.approvedAt = new Date();
        lastAttendance.status = 'approved';
        if (notes) lastAttendance.managerNotes = notes;
      }
    }

    await event.save();

    return res.json({ message: 'Hours approved', staffMember });
  } catch (err) {
    console.error('[approve-hours] failed', err);
    return res.status(500).json({ message: 'Failed to approve hours' });
  }
});

// Bulk approve all hours for an event
router.post('/events/:id/bulk-approve-hours', async (req, res) => {
  try {
    const eventId = req.params.id ?? '';
    if (!mongoose.Types.ObjectId.isValid(eventId)) {
      return res.status(400).json({ message: 'Invalid event id' });
    }

    const { approvedBy } = req.body;
    if (!approvedBy) {
      return res.status(400).json({ message: 'approvedBy required' });
    }

    const event = await EventModel.findById(eventId);
    if (!event) return res.status(404).json({ message: 'Event not found' });

    let approvedCount = 0;
    for (const staffMember of event.accepted_staff || []) {
      if (staffMember.attendance && staffMember.attendance.length > 0) {
        const lastAttendance = staffMember.attendance[staffMember.attendance.length - 1];
        if (lastAttendance && lastAttendance.status === 'sheet_submitted' && lastAttendance.approvedHours != null) {
          console.log(`[bulk-approve] Approving ${staffMember.name || staffMember.userKey}: ${lastAttendance.approvedHours} hours`);
          lastAttendance.status = 'approved';
          lastAttendance.approvedBy = approvedBy;
          lastAttendance.approvedAt = new Date();
          approvedCount++;
        } else {
          console.log(`[bulk-approve] Skipping ${staffMember.name || staffMember.userKey}: status=${lastAttendance?.status}, hours=${lastAttendance?.approvedHours}`);
        }
      }
    }

    event.hoursStatus = 'approved';
    event.hoursApprovedBy = approvedBy;
    event.hoursApprovedAt = new Date();

    await event.save();

    return res.json({
      message: `Bulk approved ${approvedCount} staff hours`,
      approvedCount,
    });
  } catch (err) {
    console.error('[bulk-approve-hours] failed', err);
    return res.status(500).json({ message: 'Failed to bulk approve hours' });
  }
});

export default router;


