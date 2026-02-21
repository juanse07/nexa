import { Router } from 'express';
import mongoose from 'mongoose';
import { z } from 'zod';
import { requireAuth, AuthenticatedUser } from '../middleware/requireAuth';
import { requireActiveSubscription } from '../middleware/requireActiveSubscription';
import { AvailabilityModel } from '../models/availability';
import { EventModel } from '../models/event';
import { TariffModel } from '../models/tariff';
import { ClientModel } from '../models/client';
import { RoleModel } from '../models/role';
import { ManagerModel } from '../models/manager';
import { TeamModel } from '../models/team';
import { TeamMemberModel } from '../models/teamMember';
import { resolveManagerForRequest } from '../utils/manager';
import { emitToManager, emitToTeams, emitToUser } from '../socket/server';
import { notificationService } from '../services/notificationService';
import { UserModel } from '../models/user';
import { StaffProfileModel } from '../models/staffProfile';
import {
  isWithinGeofence,
  formatDistance,
  isValidCoordinate,
  DEFAULT_GEOFENCE_RADIUS_METERS,
} from '../utils/geolocation';
import { FlaggedAttendanceModel, FlagType, FlagSeverity } from '../models/flaggedAttendance';
import {
  sanitizeTeamIds,
  timeToMinutes,
  sendEventNotifications,
} from '../utils/eventHelpers';
import {
  shareEventPublic,
  shareEventPrivate,
  sendDirectInvitation,
} from '../services/eventShareService';

const router = Router();

/**
 * Check for unusual attendance patterns and create flags for manager review.
 * Flags are created asynchronously and don't block the clock-out response.
 */
async function checkUnusualPatterns(
  event: any,
  userKey: string,
  attendanceRecord: any,
  staffInfo: any
): Promise<void> {
  const flags: Array<{ type: FlagType; severity: FlagSeverity; reason: string }> = [];

  const clockInTime = new Date(attendanceRecord.clockInAt);
  const clockOutTime = new Date(attendanceRecord.clockOutAt);
  const hoursWorked = (clockOutTime.getTime() - clockInTime.getTime()) / (1000 * 60 * 60);
  const clockOutHour = clockOutTime.getHours();

  // Calculate expected duration from event times
  let expectedHours: number | undefined;
  if (event.start_time && event.end_time) {
    const [startH, startM] = event.start_time.split(':').map(Number);
    const [endH, endM] = event.end_time.split(':').map(Number);
    if (!isNaN(startH) && !isNaN(endH)) {
      expectedHours = (endH + endM / 60) - (startH + startM / 60);
      if (expectedHours < 0) expectedHours += 24; // Handle overnight shifts
    }
  }

  // Flag 1: Unusual clock-out hours (11 PM - 5 AM)
  if (clockOutHour >= 23 || clockOutHour < 5) {
    flags.push({
      type: 'unusual_hours',
      severity: clockOutHour >= 2 && clockOutHour < 5 ? 'high' : 'medium',
      reason: `Clock-out at unusual hour: ${clockOutTime.toLocaleTimeString()}`,
    });
  }

  // Flag 2: Excessive duration (more than expected + 3 hours, or > 12 hours)
  if (expectedHours && hoursWorked > expectedHours + 3) {
    flags.push({
      type: 'excessive_duration',
      severity: hoursWorked > expectedHours + 5 ? 'high' : 'medium',
      reason: `Worked ${hoursWorked.toFixed(1)}h vs expected ${expectedHours.toFixed(1)}h`,
    });
  } else if (hoursWorked > 12) {
    flags.push({
      type: 'excessive_duration',
      severity: hoursWorked > 16 ? 'high' : 'medium',
      reason: `Worked ${hoursWorked.toFixed(1)} hours (over 12h limit)`,
    });
  }

  // Flag 3: Very late clock-out (more than 4 hours after expected end time)
  if (event.end_time && event.date) {
    const [endH, endM] = event.end_time.split(':').map(Number);
    if (!isNaN(endH) && !isNaN(endM)) {
      const expectedEnd = new Date(event.date);
      expectedEnd.setHours(endH, endM, 0, 0);
      const hoursLate = (clockOutTime.getTime() - expectedEnd.getTime()) / (1000 * 60 * 60);
      if (hoursLate > 4) {
        flags.push({
          type: 'late_clock_out',
          severity: hoursLate > 8 ? 'high' : 'medium',
          reason: `Clocked out ${hoursLate.toFixed(1)} hours after shift end`,
        });
      }
    }
  }

  // Create flags in database and notify manager
  for (const flag of flags) {
    try {
      await FlaggedAttendanceModel.create({
        eventId: event._id,
        managerId: event.managerId,
        userKey,
        staffName: staffInfo?.name || `${staffInfo?.first_name || ''} ${staffInfo?.last_name || ''}`.trim() || userKey,
        eventName: event.event_name || event.shift_name,
        eventDate: event.date ? new Date(event.date) : undefined,
        flagType: flag.type,
        severity: flag.severity,
        details: {
          clockInAt: clockInTime,
          clockOutAt: clockOutTime,
          expectedDurationHours: expectedHours,
          actualDurationHours: hoursWorked,
          clockInLocation: attendanceRecord.clockInLocation,
          clockOutLocation: attendanceRecord.clockOutLocation,
          venueLocation: event.venue_latitude && event.venue_longitude
            ? { latitude: event.venue_latitude, longitude: event.venue_longitude }
            : undefined,
        },
        status: 'pending',
      });

      // Send notification to manager (using sendToUser with manager's user key)
      if (event.managerId) {
        try {
          const flagManager = await ManagerModel.findById(event.managerId);
          if (flagManager?.subject && flagManager?.provider) {
            const managerUserKey = `${flagManager.provider}:${flagManager.subject}`;
            await notificationService.sendToUser(
              managerUserKey,
              `⚠️ Attendance Flag: ${flag.severity.toUpperCase()}`,
              `${staffInfo?.name || userKey}: ${flag.reason}`,
              {
                type: 'event',  // Use existing notification type
                eventId: String(event._id),
              }
            );
          }
        } catch (notifyErr) {
          console.error('[checkUnusualPatterns] Failed to notify manager:', notifyErr);
        }
      }
    } catch (err) {
      console.error('[checkUnusualPatterns] Failed to create flag:', err);
    }
  }
}

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
  status: z.enum(['draft', 'published', 'confirmed', 'fulfilled', 'in_progress', 'completed', 'cancelled']).nullish(),
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
  audience_team_ids: z.array(z.string()).nullish(),
});

// computeRoleStats is imported from shared utility
import { computeRoleStats } from '../utils/eventCapacity';

function toObjectId(value: unknown): mongoose.Types.ObjectId | undefined {
  if (!value) return undefined;
  if (value instanceof mongoose.Types.ObjectId) return value;
  if (typeof value === 'string' && mongoose.Types.ObjectId.isValid(value)) {
    return new mongoose.Types.ObjectId(value);
  }
  return undefined;
}

type EventGroup = {
  managerId: mongoose.Types.ObjectId | undefined;
  events: any[];
};

// Helper to enrich events with tariff data per role
export async function enrichEventsWithTariffs(events: any[]): Promise<any[]> {
  const grouped = new Map<string, EventGroup>();

  for (const event of events) {
    const managerObjectId = toObjectId(event.managerId);
    const key = managerObjectId ? managerObjectId.toHexString() : '__unscoped__';
    const existing = grouped.get(key);
    if (existing) {
      existing.events.push(event);
    } else {
      grouped.set(key, { managerId: managerObjectId, events: [event] });
    }
  }

  const results: any[] = [];

  for (const { managerId, events: scopedEvents } of grouped.values()) {
    if (scopedEvents.length === 0) continue;

    const clientNames = Array.from(
      new Set(
        scopedEvents
          .map((e) => (e.client_name ? String(e.client_name).toLowerCase().trim() : null))
          .filter((value): value is string => !!value)
      )
    );

    const roleNames = Array.from(
      new Set(
        scopedEvents
          .flatMap((e) => (e.roles || []).map((r: any) => (r.role ? String(r.role).toLowerCase().trim() : null)))
          .filter((value): value is string => !!value)
      )
    );

    let clientNameToId = new Map<string, string>();
    if (clientNames.length > 0) {
      const clientQuery: Record<string, any> = {
        normalizedName: { $in: clientNames },
      };
      if (managerId) {
        clientQuery.managerId = managerId;
      }
      const clients = await ClientModel.find(clientQuery).lean();
      clientNameToId = new Map(clients.map((c) => [c.normalizedName, String(c._id)]));
    }

    let roleNameToId = new Map<string, string>();
    if (roleNames.length > 0) {
      const roleQuery: Record<string, any> = {
        normalizedName: { $in: roleNames },
      };
      if (managerId) {
        roleQuery.managerId = managerId;
      }
      const rolesData = await RoleModel.find(roleQuery).lean();
      roleNameToId = new Map(rolesData.map((r) => [r.normalizedName, String(r._id)]));
    }

    let tariffMap = new Map<string, any>();
    const clientIds = Array.from(clientNameToId.values());
    const roleIds = Array.from(roleNameToId.values());
    if (clientIds.length > 0 && roleIds.length > 0) {
      const tariffFilter: Record<string, any> = {
        clientId: { $in: clientIds.map((id) => new mongoose.Types.ObjectId(id)) },
        roleId: { $in: roleIds.map((id) => new mongoose.Types.ObjectId(id)) },
      };
      if (managerId) {
        tariffFilter.managerId = managerId;
      }
      const tariffs = await TariffModel.find(tariffFilter).lean();
      tariffMap = new Map(tariffs.map((t) => [`${t.clientId}_${t.roleId}`, t]));
    }

    for (const event of scopedEvents) {
      const normalizedClientName = event.client_name ? String(event.client_name).toLowerCase().trim() : undefined;
      const clientId = normalizedClientName ? clientNameToId.get(normalizedClientName) : undefined;

      const enrichedRoles = (event.roles || []).map((role: any) => {
        const normalizedRoleName = role.role ? String(role.role).toLowerCase().trim() : undefined;
        const roleId = normalizedRoleName ? roleNameToId.get(normalizedRoleName) : undefined;

        if (clientId && roleId) {
          const tariff = tariffMap.get(`${clientId}_${roleId}`);
          if (tariff) {
            return {
              ...role,
              tariff: {
                rate: tariff.rate,
                currency: tariff.currency,
                rateDisplay: `${tariff.currency} ${tariff.rate.toFixed(2)}/hr`,
              },
            };
          }
        }

        return role;
      });

      results.push({
        ...event,
        roles: enrichedRoles,
      });
    }
  }

  return results;
}

// sanitizeTeamIds, timeToMinutes, and sendEventNotifications imported from ../utils/eventHelpers

router.post('/events', requireAuth, async (req, res) => {
  try {
    const manager = await resolveManagerForRequest(req as any);
    const managerId = manager._id as mongoose.Types.ObjectId;
    const parsed = eventSchema.safeParse(req.body);
    if (!parsed.success) {
      return res.status(400).json({
        error: 'Validation failed',
        details: parsed.error.format(),
      });
    }

    const raw = parsed.data as any;
    const teamIds = await sanitizeTeamIds(managerId, raw.audience_team_ids);
    raw.audience_team_ids = teamIds;
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
    const role_stats = computeRoleStats(
      normalized.roles as any[],
      (normalized.accepted_staff as any[]) || []
    );

    const created = await EventModel.create({
      ...normalized,
      role_stats,
      managerId,
      // Status defaults to 'draft' from schema, but can be overridden
      status: normalized.status || 'draft',
    });
    const createdObj = created.toObject();
    const responsePayload = {
      ...createdObj,
      id: String(createdObj._id),
      managerId: createdObj.managerId ? String(createdObj.managerId) : undefined,
      audience_user_keys: (createdObj.audience_user_keys || []).map((v: any) => v?.toString()).filter((v: string | undefined) => !!v),
      audience_team_ids: (createdObj.audience_team_ids || [])
        .map((v: any) => v?.toString())
        .filter((v: string | undefined) => !!v),
    };

    // Always notify the manager about their own event creation
    emitToManager(String(managerId), 'event:created', responsePayload);

    // Only notify staff if the event is published (not a draft)
    if (createdObj.status !== 'draft') {
      const audienceTeams = (responsePayload.audience_team_ids || []) as string[];
      if (audienceTeams.length > 0) {
        emitToTeams(audienceTeams, 'event:created', responsePayload);
      }

      const audienceUsers = (responsePayload.audience_user_keys || []) as string[];
      for (const key of audienceUsers) {
        emitToUser(key, 'event:created', responsePayload);
      }
    }

    return res.status(201).json(responsePayload);
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error('Failed to create event', err);
    return res.status(500).json({ error: 'Internal Server Error' });
  }
});

// Batch create multiple events
router.post('/events/batch', requireAuth, async (req, res) => {
  try {
    const manager = await resolveManagerForRequest(req as any);
    const managerId = manager._id as mongoose.Types.ObjectId;

    const { events } = req.body;
    if (!Array.isArray(events) || events.length === 0) {
      return res.status(400).json({ message: 'events array is required and cannot be empty' });
    }

    if (events.length > 30) {
      return res.status(400).json({ message: 'Maximum 30 events can be created at once' });
    }

    // Validate and prepare all events
    const validatedEvents = [];
    for (let i = 0; i < events.length; i++) {
      const parsed = eventSchema.safeParse(events[i]);
      if (!parsed.success) {
        return res.status(400).json({
          error: `Validation failed for event ${i + 1}`,
          details: parsed.error.format(),
        });
      }

      const raw = parsed.data as any;
      const teamIds = await sanitizeTeamIds(managerId, raw.audience_team_ids);
      raw.audience_team_ids = teamIds;

      // Backwards compatibility
      if ((raw as any).client_company_name && !(raw as any).third_party_company_name) {
        (raw as any).third_party_company_name = (raw as any).client_company_name;
        delete (raw as any).client_company_name;
      }

      // Normalize date to Date type if provided
      if (raw.date && typeof raw.date === 'string') {
        raw.date = new Date(raw.date);
      }

      // Prepare event data
      const eventData = {
        ...raw,
        managerId,
        status: raw.status || 'draft',
        role_stats: computeRoleStats(raw.roles || [], raw.accepted_staff || []),
      };

      validatedEvents.push(eventData);
    }

    // Create all events in a transaction
    const session = await mongoose.startSession();
    session.startTransaction();

    try {
      const createdEvents = await EventModel.insertMany(validatedEvents, { session });

      await session.commitTransaction();

      // Convert to response format
      const responseEvents = createdEvents.map(event => {
        const obj = event.toObject();
        return {
          ...obj,
          id: String(obj._id),
        };
      });

      // Notify about created events (only published ones)
      for (const event of responseEvents) {
        // Always notify the manager
        emitToManager(String(managerId), 'event:created', event);

        // Only notify staff if the event is published (not a draft)
        if (event.status !== 'draft') {
          const audienceTeams = ((event.audience_team_ids || []) as unknown as any[]).map(id => String(id));
          if (audienceTeams.length > 0) {
            emitToTeams(audienceTeams, 'event:created', event);
          }

          const audienceUsers = (event.audience_user_keys || []) as string[];
          for (const key of audienceUsers) {
            emitToUser(key, 'event:created', event);
          }
        }
      }

      return res.status(201).json({
        message: `Created ${createdEvents.length} events successfully`,
        events: responseEvents,
      });

    } catch (error) {
      await session.abortTransaction();
      throw error;
    } finally {
      session.endSession();
    }

  } catch (err) {
    console.error('[batch create events] failed', err);
    return res.status(500).json({ error: 'Internal Server Error' });
  }
});

// Publish a draft event (transition from draft → published)
const publishEventSchema = z.object({
  audience_user_keys: z.array(z.string()).nullish(),
  audience_team_ids: z.array(z.string()).nullish(),
  audience_group_ids: z.array(z.string()).nullish(),
  visibilityType: z.enum(['private', 'public', 'private_public']).optional(),
});

router.post('/events/:id/publish', requireAuth, async (req, res) => {
  try {
    const manager = await resolveManagerForRequest(req as any);
    const managerId = manager._id as mongoose.Types.ObjectId;
    const eventId = req.params.id;

    if (!eventId || !mongoose.Types.ObjectId.isValid(eventId)) {
      return res.status(400).json({ message: 'Invalid event ID' });
    }

    const event = await EventModel.findOne({
      _id: new mongoose.Types.ObjectId(eventId),
      managerId,
    });

    if (!event) {
      return res.status(404).json({ message: 'Event not found or not owned by you' });
    }

    if (event.status !== 'draft') {
      return res.status(400).json({
        message: `Cannot publish event with status '${event.status}'. Only draft events can be published.`,
      });
    }

    // Check if event is already fulfilled (all positions filled via private invitations)
    const { checkIfEventFulfilled } = await import('../utils/eventCapacity');
    if (checkIfEventFulfilled(event)) {
      return res.status(400).json({
        message: 'Cannot publish event - all positions are already filled via private invitations. Event is fulfilled.',
        hint: 'This event was filled through direct invitations and does not need to be published.',
      });
    }

    // Validate and sanitize audience data
    const parsed = publishEventSchema.safeParse(req.body);
    if (!parsed.success) {
      return res.status(400).json({
        error: 'Validation failed',
        details: parsed.error.format(),
      });
    }

    const { audience_user_keys, audience_team_ids, audience_group_ids, visibilityType } = parsed.data;
    const teamIds = await sanitizeTeamIds(managerId, audience_team_ids);

    // Validate group IDs belong to this manager
    let groupIds: mongoose.Types.ObjectId[] = [];
    if (audience_group_ids && audience_group_ids.length > 0) {
      const validIds = audience_group_ids
        .filter((id) => mongoose.Types.ObjectId.isValid(id))
        .map((id) => new mongoose.Types.ObjectId(id));
      if (validIds.length > 0) {
        const { StaffGroupModel } = await import('../models/staffGroup');
        const validGroups = await StaffGroupModel.find({ _id: { $in: validIds }, managerId }).lean();
        groupIds = validGroups.map((g: any) => g._id);
      }
    }

    // Get all user keys we're publishing to (for notifications and availability checks)
    const targetUserKeys: string[] = [];

    console.log('[EVENT PUBLISH DEBUG] audience_user_keys:', audience_user_keys);
    console.log('[EVENT PUBLISH DEBUG] teamIds:', teamIds);

    if (audience_user_keys && audience_user_keys.length > 0) {
      targetUserKeys.push(...audience_user_keys);
      console.log('[EVENT PUBLISH DEBUG] Added audience_user_keys to targetUserKeys:', targetUserKeys);
    }

    // Get user keys from teams
    if (teamIds.length > 0) {
      const teamMembers = await TeamMemberModel.find({
        teamId: { $in: teamIds },
        status: 'active',
      }).lean();

      console.log('[EVENT PUBLISH DEBUG] Found team members:', teamMembers.length);

      for (const member of teamMembers) {
        console.log('[EVENT PUBLISH DEBUG] Team member:', {
          provider: member.provider,
          subject: member.subject,
          status: member.status
        });

        if (member.provider && member.subject) {
          const userKey = `${member.provider}:${member.subject}`;
          if (!targetUserKeys.includes(userKey)) {
            targetUserKeys.push(userKey);
          }
        }
      }
    }

    // Expand group members into targetUserKeys
    if (groupIds.length > 0) {
      const groupMembers = await StaffProfileModel.find({
        managerId,
        groupIds: { $in: groupIds },
      }).lean();
      for (const profile of groupMembers) {
        if (profile.userKey && !targetUserKeys.includes(profile.userKey)) {
          targetUserKeys.push(profile.userKey);
        }
      }
      console.log('[EVENT PUBLISH DEBUG] Added group members, total targetUserKeys:', targetUserKeys.length);
    }

    console.log('[EVENT PUBLISH DEBUG] Final targetUserKeys:', targetUserKeys);

    // Check availability conflicts for staff in the audience
    const availabilityWarnings: any[] = [];

    if (event.date && event.start_time && event.end_time) {
      const eventDate = new Date(event.date);
      const eventDateStr = eventDate.toISOString().split('T')[0]; // YYYY-MM-DD

      // Check availability for each user
      if (targetUserKeys.length > 0) {
        const unavailableStaff = await AvailabilityModel.find({
          userKey: { $in: targetUserKeys },
          date: eventDateStr,
          status: 'unavailable',
        }).lean();

        // Check if event time overlaps with unavailable periods
        for (const avail of unavailableStaff) {
          // Simple overlap check: if unavailable period overlaps with event time
          const eventStartMinutes = timeToMinutes(event.start_time);
          const eventEndMinutes = timeToMinutes(event.end_time);
          const unavailStartMinutes = timeToMinutes(avail.startTime);
          const unavailEndMinutes = timeToMinutes(avail.endTime);

          // Check for overlap: A starts before B ends AND A ends after B starts
          if (eventStartMinutes < unavailEndMinutes && eventEndMinutes > unavailStartMinutes) {
            availabilityWarnings.push({
              userKey: avail.userKey,
              date: avail.date,
              unavailableFrom: avail.startTime,
              unavailableTo: avail.endTime,
            });
          }
        }
      }
    }

    // Update event to published status
    console.log(`[EVENT PUBLISH] Changing status from '${event.status}' to 'published' for event ${eventId}`);
    event.status = 'published';
    event.publishedAt = new Date();
    event.publishedBy = manager.email || manager.name || String(managerId);
    event.audience_user_keys = audience_user_keys || [];
    event.audience_team_ids = teamIds;
    event.audience_group_ids = groupIds;

    // Set visibility type — infer from audience shape when not explicitly provided
    if (visibilityType) {
      // Caller explicitly specified (Flutter sends 'public')
      event.visibilityType = visibilityType;
    } else {
      // Auto-infer from audience shape
      const hasTeams = teamIds.length > 0;
      const hasDirectUsers = !!(audience_user_keys && audience_user_keys.length > 0);
      const hasInvitedStaff = !!((event as any).invited_staff && (event as any).invited_staff.length > 0);

      if (hasTeams && (hasDirectUsers || hasInvitedStaff)) {
        event.visibilityType = 'private_public';
      } else if (hasTeams) {
        event.visibilityType = 'public';
      } else if (hasDirectUsers) {
        event.visibilityType = 'private';
      } else {
        event.visibilityType = 'public'; // Default: publishing = making visible
      }
    }

    await event.save();
    console.log(`[EVENT PUBLISH] ✓ Event ${eventId} saved successfully with status: ${event.status}`);

    const eventObj = event.toObject();
    const responsePayload = {
      ...eventObj,
      id: String(eventObj._id),
      managerId: String(eventObj.managerId),
      audience_user_keys: (eventObj.audience_user_keys || []).map(String),
      audience_team_ids: (eventObj.audience_team_ids || []).map(String),
      audience_group_ids: (eventObj.audience_group_ids || []).map(String),
      availabilityWarnings,
    };

    // Emit socket events to notify staff
    emitToManager(String(managerId), 'event:published', responsePayload);

    const audienceTeams = (responsePayload.audience_team_ids || []) as string[];
    if (audienceTeams.length > 0) {
      emitToTeams(audienceTeams, 'event:created', responsePayload);
    }

    const audienceUsers = (responsePayload.audience_user_keys || []) as string[];
    for (const key of audienceUsers) {
      emitToUser(key, 'event:created', responsePayload);
    }

    // Send push notifications to ALL assigned staff members (including team members)
    if (targetUserKeys.length > 0) {
      const teamIdStrings = (eventObj.audience_team_ids || []).map(String);
      const teamsForNotification = await TeamModel.find({
        _id: { $in: teamIdStrings.map((id: string) => new mongoose.Types.ObjectId(id)) }
      }).lean();
      const teamIdToName = new Map(teamsForNotification.map((t: any) => [String(t._id), t.name]));

      await sendEventNotifications({
        targetUserKeys,
        event: eventObj,
        teamIdToName,
        notificationType: 'new_open',
        managerId: String(managerId),
      });
    }

    return res.json(responsePayload);
  } catch (err) {
    console.error('[publish event] failed', err);
    return res.status(500).json({ message: 'Failed to publish event' });
  }
});

// Unified share endpoint — dispatches to the appropriate service function
const shareEventSchema = z.object({
  shareType: z.enum(['public', 'private', 'direct_invitation']),
  targetTeamIds: z.array(z.string()).nullish(),
  targetStaff: z.array(z.string()).nullish(),
  invitee: z.object({
    staffName: z.string(),
    roleName: z.string(),
  }).nullish(),
  sendChatMessage: z.boolean().default(false),
});

router.post('/events/:id/share', requireAuth, async (req, res) => {
  try {
    const manager = await resolveManagerForRequest(req as any);
    const managerId = manager._id as mongoose.Types.ObjectId;
    const eventId = req.params.id;

    if (!eventId || !mongoose.Types.ObjectId.isValid(eventId)) {
      return res.status(400).json({ message: 'Invalid event ID' });
    }

    const parsed = shareEventSchema.safeParse(req.body);
    if (!parsed.success) {
      return res.status(400).json({ error: 'Validation failed', details: parsed.error.format() });
    }

    const { shareType, targetTeamIds, targetStaff, invitee } = parsed.data;
    const managerName = manager.first_name && manager.last_name
      ? `${manager.first_name} ${manager.last_name}`
      : manager.name || 'Manager';

    switch (shareType) {
      case 'public': {
        const result = await shareEventPublic({
          managerId,
          eventId,
          targetTeamIds: targetTeamIds || null,
          managerName,
          managerEmail: manager.email || '',
        });
        if (!result.success) {
          return res.status(400).json({ message: result.error });
        }
        return res.json({
          message: `Published to ${result.teamCount} team(s). ${result.notifiedCount} staff notified.`,
          ...result,
        });
      }

      case 'private': {
        if (!targetStaff || targetStaff.length === 0) {
          return res.status(400).json({ message: 'targetStaff is required for private share.' });
        }

        // Resolve staff names to userKeys using fuzzy match
        const resolvedUserKeys: string[] = [];
        const notFound: string[] = [];

        for (const name of targetStaff) {
          const nameRegex = new RegExp(name.split(/\s+/).join('.*'), 'i');
          const member = await TeamMemberModel.findOne({
            managerId,
            status: 'active',
            $or: [{ name: nameRegex }, { email: new RegExp(name, 'i') }],
          }).lean();

          if (member && member.provider && member.subject) {
            resolvedUserKeys.push(`${member.provider}:${member.subject}`);
          } else {
            notFound.push(name);
          }
        }

        if (resolvedUserKeys.length === 0) {
          return res.status(400).json({ message: `No matching staff found for: ${notFound.join(', ')}` });
        }

        const result = await shareEventPrivate({
          managerId,
          eventId,
          targetUserKeys: resolvedUserKeys,
          managerName,
          managerEmail: manager.email || '',
        });

        if (!result.success) {
          return res.status(400).json({ message: result.error });
        }

        return res.json({
          message: `Shared privately with ${result.notifiedCount} staff member(s).`,
          notFound: notFound.length > 0 ? notFound : undefined,
          ...result,
        });
      }

      case 'direct_invitation': {
        if (!invitee) {
          return res.status(400).json({ message: 'invitee is required for direct_invitation.' });
        }

        // Resolve invitee name to userKey
        const nameRegex = new RegExp(invitee.staffName.split(/\s+/).join('.*'), 'i');
        const member = await TeamMemberModel.findOne({
          managerId,
          status: 'active',
          $or: [{ name: nameRegex }, { email: new RegExp(invitee.staffName, 'i') }],
        }).lean();

        if (!member || !member.provider || !member.subject) {
          return res.status(404).json({ message: `Staff member "${invitee.staffName}" not found.` });
        }

        const inviteeUserKey = `${member.provider}:${member.subject}`;
        const mgrPicture = (manager as any).picture || null;

        const result = await sendDirectInvitation({
          managerId,
          eventId,
          inviteeUserKey,
          roleName: invitee.roleName,
          managerName,
          managerPicture: mgrPicture,
        });

        if (!result.success) {
          return res.status(400).json({ message: result.error });
        }

        return res.json({
          message: `Invitation sent to ${(member as any).name || invitee.staffName} for the ${result.roleName} role.`,
          ...result,
        });
      }
    }
  } catch (err) {
    console.error('[share event] failed', err);
    return res.status(500).json({ message: 'Failed to share event' });
  }
});

// Unpublish a published event (transition from published → draft)
router.post('/events/:id/unpublish', requireAuth, async (req, res) => {
  try {
    const manager = await resolveManagerForRequest(req as any);
    const managerId = manager._id as mongoose.Types.ObjectId;
    const eventId = req.params.id;

    if (!eventId || !mongoose.Types.ObjectId.isValid(eventId)) {
      return res.status(400).json({ message: 'Invalid event ID' });
    }

    const event = await EventModel.findOne({
      _id: new mongoose.Types.ObjectId(eventId),
      managerId,
    });

    if (!event) {
      return res.status(404).json({ message: 'Event not found or not owned by you' });
    }

    // Can unpublish published events OR drafts that have been sent to staff
    const hasSentToStaff = event.accepted_staff && event.accepted_staff.length > 0;
    const canUnpublish = event.status === 'published' || (event.status === 'draft' && hasSentToStaff);

    if (!canUnpublish) {
      return res.status(400).json({
        message: `Cannot unpublish event with status '${event.status}'. Only published events or drafts sent to staff can be moved back to drafts.`,
      });
    }

    // Store accepted staff and team IDs for notifications before removing them
    const acceptedStaff = event.accepted_staff || [];
    const originalTeamIds = (event.audience_team_ids || []).map(String);
    const targetUserKeys: string[] = [];

    for (const staff of acceptedStaff) {
      if (staff.userKey) {
        targetUserKeys.push(staff.userKey);
      } else if (staff.provider && staff.subject) {
        targetUserKeys.push(`${staff.provider}:${staff.subject}`);
      }
    }

    // Update event back to draft status
    event.status = 'draft';
    event.publishedAt = undefined;
    event.publishedBy = undefined;
    event.audience_user_keys = [];
    event.audience_team_ids = [];
    event.accepted_staff = [];
    event.visibilityType = undefined;

    await event.save();

    const eventObj = event.toObject();
    const responsePayload = {
      ...eventObj,
      id: String(eventObj._id),
      managerId: String(eventObj.managerId),
    };

    // Emit socket events to notify manager
    emitToManager(String(managerId), 'event:unpublished', responsePayload);

    // Send cancellation notifications to removed staff members
    if (targetUserKeys.length > 0) {
      const teamsForNotification = await TeamModel.find({
        _id: { $in: originalTeamIds.map((id: string) => new mongoose.Types.ObjectId(id)) }
      }).lean();
      const teamIdToName = new Map(teamsForNotification.map((t: any) => [String(t._id), t.name]));

      await sendEventNotifications({
        targetUserKeys,
        event: eventObj,
        teamIdToName,
        notificationType: 'cancelled',
        managerId: String(managerId),
      });

      // Emit cancel socket to each user
      for (const userKey of targetUserKeys) {
        emitToUser(userKey, 'event:canceled', responsePayload);
      }

      console.log(`[EVENT UNPUBLISH] Event ${eventId} unpublished, notified ${targetUserKeys.length} staff members`);
    }

    return res.json(responsePayload);
  } catch (err) {
    console.error('[unpublish event] failed', err);
    return res.status(500).json({ message: 'Failed to unpublish event' });
  }
});

// Change visibility type of a published event
const changeVisibilitySchema = z.object({
  visibilityType: z.enum(['private', 'public', 'private_public']),
  audience_team_ids: z.array(z.string()).nullish(),
  audience_group_ids: z.array(z.string()).nullish(),
});

router.patch('/events/:id/visibility', requireAuth, async (req, res) => {
  try {
    const manager = await resolveManagerForRequest(req as any);
    const managerId = manager._id as mongoose.Types.ObjectId;
    const eventId = req.params.id;

    if (!eventId || !mongoose.Types.ObjectId.isValid(eventId)) {
      return res.status(400).json({ message: 'Invalid event ID' });
    }

    const event = await EventModel.findOne({
      _id: new mongoose.Types.ObjectId(eventId),
      managerId,
    });

    if (!event) {
      return res.status(404).json({ message: 'Event not found or not owned by you' });
    }

    if (event.status !== 'published') {
      return res.status(400).json({
        message: `Cannot change visibility for event with status '${event.status}'. Only published events can have their visibility changed.`,
      });
    }

    // Validate and sanitize data
    const parsed = changeVisibilitySchema.safeParse(req.body);
    if (!parsed.success) {
      return res.status(400).json({
        error: 'Validation failed',
        details: parsed.error.format(),
      });
    }

    const { visibilityType, audience_team_ids } = parsed.data;
    const oldVisibilityType = event.visibilityType;

    // Update visibility type
    event.visibilityType = visibilityType;

    // If changing to public or private_public, update audience teams
    if ((visibilityType === 'public' || visibilityType === 'private_public') && audience_team_ids) {
      const teamIds = await sanitizeTeamIds(managerId, audience_team_ids);
      event.audience_team_ids = teamIds;
    }

    await event.save();

    const eventObj = event.toObject();
    const responsePayload = {
      ...eventObj,
      id: String(eventObj._id),
      managerId: String(eventObj.managerId),
      audience_team_ids: (eventObj.audience_team_ids || []).map(String),
    };

    // Emit socket events to notify manager
    emitToManager(String(managerId), 'event:visibility_changed', responsePayload);

    // If changed to public or private_public, notify teams
    if ((visibilityType === 'public' || visibilityType === 'private_public') && oldVisibilityType === 'private') {
      const audienceTeams = (responsePayload.audience_team_ids || []) as string[];
      if (audienceTeams.length > 0) {
        emitToTeams(audienceTeams, 'event:visibility_changed', responsePayload);

        // Get team members to send notifications
        const teamMembers = await TeamMemberModel.find({
          teamId: { $in: audienceTeams },
          status: 'active',
        }).lean();

        const targetUserKeys: string[] = [];
        for (const member of teamMembers) {
          if (member.provider && member.subject) {
            const userKey = `${member.provider}:${member.subject}`;
            if (!targetUserKeys.includes(userKey)) {
              targetUserKeys.push(userKey);
            }
          }
        }

        // Send push notifications - one per role
        if (targetUserKeys.length > 0) {
          const teamsForNotification = await TeamModel.find({
            _id: { $in: audienceTeams.map((id: string) => new mongoose.Types.ObjectId(id)) }
          }).lean();
          const teamIdToName = new Map(teamsForNotification.map((t: any) => [String(t._id), t.name]));

          const notifiedCount = await sendEventNotifications({
            targetUserKeys,
            event: eventObj,
            teamIdToName,
            notificationType: 'now_open',
            managerId: String(managerId),
          });

          console.log(`[EVENT VISIBILITY] Event ${eventId} visibility changed to ${visibilityType}, notified ${notifiedCount} team members`);
        }
      }
    }

    return res.json(responsePayload);
  } catch (err) {
    console.error('[change visibility] failed', err);
    return res.status(500).json({ message: 'Failed to change event visibility' });
  }
});

// timeToMinutes imported from ../utils/eventHelpers

// Update roles for an event with capacity validation
const updateRolesSchema = z.object({
  roles: z.array(roleSchema).min(1, 'at least one role is required'),
});

router.patch('/events/:id/roles', requireAuth, async (req, res) => {
  try {
    const manager = await resolveManagerForRequest(req as any);
    const managerId = manager._id as mongoose.Types.ObjectId;
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
    for (const [roleKey, taken] of Object.entries(acceptedCounts) as [string, number][]) {
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
      { _id: new mongoose.Types.ObjectId(eventId), managerId },
      { $set: { roles, role_stats, updatedAt: new Date() } }
    );

    if (result.matchedCount === 0) {
      return res.status(404).json({ message: 'Event not found' });
    }

    const updated = await EventModel.findOne({
      _id: new mongoose.Types.ObjectId(eventId),
      managerId,
    }).lean();
    return res.json(updated);
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error('[update roles] failed', err);
    return res.status(500).json({ message: 'Failed to update roles' });
  }
});

// Update an event (partial update)
router.patch('/events/:id', requireAuth, async (req, res) => {
  try {
    const manager = await resolveManagerForRequest(req as any);
    const managerId = manager._id as mongoose.Types.ObjectId;
    const eventId = req.params.id ?? '';
    if (!mongoose.Types.ObjectId.isValid(eventId)) {
      return res.status(400).json({ message: 'Invalid event id' });
    }

    const updateData = { ...req.body };
    delete updateData._id;
    delete updateData.id;

    if (Object.prototype.hasOwnProperty.call(updateData, 'audience_team_ids')) {
      if (Array.isArray(updateData.audience_team_ids)) {
        updateData.audience_team_ids = await sanitizeTeamIds(
          managerId,
          updateData.audience_team_ids
        );
      } else if (
        updateData.audience_team_ids === null ||
        updateData.audience_team_ids === undefined
      ) {
        updateData.audience_team_ids = [];
      } else {
        delete updateData.audience_team_ids;
      }
    }

    // Normalize date if provided
    if (updateData.date) {
      updateData.date = new Date(updateData.date);
    }

    // Get the event before update to detect status changes and audience changes
    const eventBefore = await EventModel.findOne({
      _id: new mongoose.Types.ObjectId(eventId),
      managerId,
    }).lean();

    // Track old audience for comparison
    const oldAudienceUsers = eventBefore?.audience_user_keys
      ? (eventBefore.audience_user_keys as any[]).map((v: any) => v?.toString()).filter(Boolean)
      : [];
    const oldAudienceTeams = eventBefore?.audience_team_ids
      ? (eventBefore.audience_team_ids as any[]).map((v: any) => v?.toString()).filter(Boolean)
      : [];

    // Update the event
    const result = await EventModel.updateOne(
      { _id: new mongoose.Types.ObjectId(eventId), managerId },
      { $set: { ...updateData, updatedAt: new Date() } }
    );

    if (result.matchedCount === 0) {
      return res.status(404).json({ message: 'Event not found' });
    }

    const updated = await EventModel.findOne({
      _id: new mongoose.Types.ObjectId(eventId),
      managerId,
    }).lean();
    if (!updated) {
      return res.status(404).json({ message: 'Event not found after update' });
    }
    const responsePayload = {
      ...updated,
      id: String(updated._id),
      managerId: updated.managerId ? String(updated.managerId) : undefined,
      audience_user_keys: (updated.audience_user_keys || []).map((v: any) => v?.toString()).filter((v: string | undefined) => !!v),
      audience_team_ids: (updated.audience_team_ids || [])
        .map((v: any) => v?.toString())
        .filter((v: string | undefined) => !!v),
    };

    emitToManager(String(managerId), 'event:updated', responsePayload);

    // Determine which users/teams are NEW vs EXISTING
    const updateTeams = (responsePayload.audience_team_ids || []) as string[];
    const updateUsers = (responsePayload.audience_user_keys || []) as string[];

    const newTeams = updateTeams.filter(t => !oldAudienceTeams.includes(t));
    const existingTeams = updateTeams.filter(t => oldAudienceTeams.includes(t));

    const newUsers = updateUsers.filter(u => !oldAudienceUsers.includes(u));
    const existingUsers = updateUsers.filter(u => oldAudienceUsers.includes(u));

    // Emit event:created to NEWLY invited staff (so they see it appear in Available tab)
    if (newTeams.length > 0) {
      emitToTeams(newTeams, 'event:created', responsePayload);
    }
    for (const key of newUsers) {
      emitToUser(key, 'event:created', responsePayload);
    }

    // Emit event:updated to EXISTING staff (who were already in the audience)
    if (existingTeams.length > 0) {
      emitToTeams(existingTeams, 'event:updated', responsePayload);
    }
    for (const key of existingUsers) {
      emitToUser(key, 'event:updated', responsePayload);
    }

    // Send push notifications when event status changes to published/confirmed
    const statusChanged = eventBefore && eventBefore.status !== updated.status;
    const isNowPublished = updated.status === 'published' || updated.status === 'confirmed';

    if (statusChanged && isNowPublished) {
      // Build list of ALL target users (including team members)
      const allTargetUserKeys: string[] = [];

      // Add users from audience_user_keys
      if (updateUsers.length > 0) {
        allTargetUserKeys.push(...updateUsers);
      }

      // Add team members from audience_team_ids
      if (updateTeams.length > 0) {
        const teamMembers = await TeamMemberModel.find({
          teamId: { $in: updateTeams },
          status: 'active',
        }).lean();

        for (const member of teamMembers) {
          if (member.provider && member.subject) {
            const userKey = `${member.provider}:${member.subject}`;
            if (!allTargetUserKeys.includes(userKey)) {
              allTargetUserKeys.push(userKey);
            }
          }
        }
      }

      if (allTargetUserKeys.length > 0) {
        console.log(`[EVENT NOTIF] Event ${eventId} status changed to ${updated.status}, notifying ${allTargetUserKeys.length} staff members (teams + selected users)`);

        // Get event details
        const eventDate = (updated as any).date;
        const startTime = (updated as any).start_time;
        const endTime = (updated as any).end_time;
        const roles = (updated as any).roles || [];

        // Format date as "8 Jan"
        let formattedDate = '';
        if (eventDate) {
          const d = new Date(eventDate);
          const day = d.getDate();
          const month = d.toLocaleDateString('en-US', { month: 'short' });
          formattedDate = `${day} ${month}`;
        }

        // Format time part
        let timePart = '';
        if (startTime && endTime) {
          timePart = `${startTime} - ${endTime}`;
        }

        // Get team names for lookup
        const teamIdStrings = updateTeams.map(String);
        const teamsForNotification = await TeamModel.find({
          _id: { $in: teamIdStrings.map((id: string) => new mongoose.Types.ObjectId(id)) }
        }).lean();
        const teamIdToName = new Map(teamsForNotification.map((t: any) => [String(t._id), t.name]));

        // Notify each assigned staff member - one notification per role
        for (const userKey of allTargetUserKeys) {
          try {
            const [provider, subject] = userKey.split(':');
            if (!provider || !subject) continue;

            const user = await UserModel.findOne({ provider, subject }).lean();
            if (!user) {
              console.log(`[EVENT NOTIF] User not found for key: ${userKey}`);
              continue;
            }

            // Get user's preferred terminology (default: 'shift')
            const terminology = (user as any).eventTerminology || 'shift';
            const capitalizedTerm = terminology.charAt(0).toUpperCase() + terminology.slice(1);

            // Find which team this user belongs to
            let teamName = 'Your team';
            const userTeamMembership = await TeamMemberModel.findOne({
              provider,
              subject,
              teamId: { $in: teamIdStrings.map((id: string) => new mongoose.Types.ObjectId(id)) },
              status: 'active'
            }).lean();

            if (userTeamMembership) {
              teamName = teamIdToName.get(String(userTeamMembership.teamId)) || 'Your team';
            }

            // Send one notification per role
            for (const role of roles) {
              const roleName = role.role || role.role_name;
              if (!roleName) continue;

              // Title: "🔵 New Open Shift"
              const notificationTitle = `🔵 New Open ${capitalizedTerm}`;

              // Body: "Tie Events posted a new shift as Bartender • 8 Jan, 4:00 PM - 9:00 PM"
              let notificationBody = `${teamName} posted a new ${terminology} as ${roleName}`;
              if (formattedDate && timePart) {
                notificationBody += ` • ${formattedDate}, ${timePart}`;
              } else if (formattedDate) {
                notificationBody += ` • ${formattedDate}`;
              }

              await notificationService.sendToUser(
                String(user._id),
                notificationTitle,
                notificationBody,
                {
                  type: 'event',
                  eventId: String(updated._id),
                  role: roleName,
                },
                'user'
              );
            }
          } catch (err) {
            console.error(`[EVENT NOTIF] Failed to send notification to ${userKey}:`, err);
          }
        }
      }
    }

    return res.json(responsePayload);
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error('[update event] failed', err);
    return res.status(500).json({ message: 'Failed to update event' });
  }
});

// Delete an event
router.delete('/events/:id', requireAuth, async (req, res) => {
  try {
    const manager = await resolveManagerForRequest(req as any);
    const managerId = manager._id as mongoose.Types.ObjectId;
    const eventId = req.params.id ?? '';

    if (!mongoose.Types.ObjectId.isValid(eventId)) {
      return res.status(400).json({ message: 'Invalid event id' });
    }

    // Check if event exists and belongs to manager
    const event = await EventModel.findOne({
      _id: new mongoose.Types.ObjectId(eventId),
      managerId,
    }).lean();

    if (!event) {
      return res.status(404).json({ message: 'Event not found' });
    }

    // Delete the event
    const result = await EventModel.deleteOne({
      _id: new mongoose.Types.ObjectId(eventId),
      managerId,
    });

    if (result.deletedCount === 0) {
      return res.status(404).json({ message: 'Event not found' });
    }

    // Emit socket events to notify clients
    emitToManager(String(managerId), 'event:deleted', { id: eventId });

    const audienceTeamIds = (event.audience_team_ids || []).map((v: any) => v?.toString()).filter((v: string | undefined) => !!v);
    if (audienceTeamIds.length > 0) {
      emitToTeams(audienceTeamIds, 'event:deleted', { id: eventId });
    }

    const audienceUserKeys = (event.audience_user_keys || []) as string[];
    for (const key of audienceUserKeys) {
      emitToUser(key, 'event:deleted', { id: eventId });
    }

    return res.json({ message: 'Event deleted successfully', id: eventId });
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error('[DELETE /events/:id] Error:', err);
    return res.status(500).json({ message: 'Failed to delete event' });
  }
});

// ============================================================================
// ATTENDANCE DASHBOARD ENDPOINTS (Must be defined BEFORE /events/:id)
// These routes have literal paths that would otherwise be caught by :id param
// ============================================================================

// Get attendance report for manager dashboard
router.get('/events/attendance-report', requireAuth, async (req, res) => {
  try {
    const manager = await resolveManagerForRequest(req as any);
    if (!manager) {
      return res.status(403).json({ message: 'Manager access required' });
    }

    const { startDate, endDate, eventId } = req.query;

    // Build filter for events
    const eventFilter: any = { managerId: manager._id };

    if (startDate && typeof startDate === 'string') {
      eventFilter.date = { ...eventFilter.date, $gte: new Date(startDate) };
    }
    if (endDate && typeof endDate === 'string') {
      eventFilter.date = { ...eventFilter.date, $lte: new Date(endDate) };
    }
    if (eventId && typeof eventId === 'string' && mongoose.Types.ObjectId.isValid(eventId)) {
      eventFilter._id = new mongoose.Types.ObjectId(eventId);
    }

    // Fetch events with attendance data
    const events = await EventModel.find(eventFilter, {
      _id: 1,
      event_name: 1,
      date: 1,
      accepted_staff: 1,
    }).lean();

    // Extract all attendance records with staff info
    const report: any[] = [];
    for (const event of events) {
      const acceptedStaff = (event.accepted_staff || []) as any[];
      for (const staff of acceptedStaff) {
        const attendance = (staff.attendance || []) as any[];
        for (const record of attendance) {
          if (record.clockInAt) {
            const clockInAt = new Date(record.clockInAt);
            const clockOutAt = record.clockOutAt ? new Date(record.clockOutAt) : null;
            const hoursWorked = clockOutAt
              ? (clockOutAt.getTime() - clockInAt.getTime()) / (1000 * 60 * 60)
              : null;

            report.push({
              eventId: String(event._id),
              eventName: event.event_name,
              eventDate: event.date,
              userKey: staff.userKey,
              staffName: staff.name || `${staff.first_name || ''} ${staff.last_name || ''}`.trim() || 'Unknown',
              role: staff.role,
              picture: staff.picture,
              email: staff.email,
              clockInAt: record.clockInAt,
              clockOutAt: record.clockOutAt,
              hoursWorked: hoursWorked !== null ? Math.round(hoursWorked * 100) / 100 : null,
              autoClockOut: record.autoClockOut || false,
              clockInLocation: record.clockInLocation,
              clockOutLocation: record.clockOutLocation,
            });
          }
        }
      }
    }

    // Sort by clock-in time (most recent first)
    report.sort((a, b) => new Date(b.clockInAt).getTime() - new Date(a.clockInAt).getTime());

    return res.json({ report });
  } catch (err) {
    console.error('[attendance-report] GET failed:', err);
    return res.status(500).json({ message: 'Failed to generate attendance report' });
  }
});

// Helper function to format elapsed time
function formatElapsedTime(ms: number): string {
  const hours = Math.floor(ms / (1000 * 60 * 60));
  const minutes = Math.floor((ms % (1000 * 60 * 60)) / (1000 * 60));
  if (hours > 0) {
    return `${hours}h ${minutes}m`;
  }
  return `${minutes}m`;
}

// Get all staff currently clocked in across manager's events
router.get('/events/currently-clocked-in', requireAuth, async (req, res) => {
  try {
    const manager = await resolveManagerForRequest(req as any);
    if (!manager) {
      return res.status(403).json({ message: 'Manager access required' });
    }

    // Get all events for this manager from the last 48 hours
    const cutoffDate = new Date();
    cutoffDate.setHours(cutoffDate.getHours() - 48);

    const events = await EventModel.find(
      {
        managerId: manager._id,
        date: { $gte: cutoffDate },
      },
      {
        _id: 1,
        event_name: 1,
        date: 1,
        accepted_staff: 1,
        venue_address: 1,
      }
    ).lean();

    const clockedInStaff: any[] = [];

    for (const event of events) {
      const acceptedStaff = (event.accepted_staff || []) as any[];

      for (const staff of acceptedStaff) {
        const attendance = (staff.attendance || []) as any[];

        // Find active clock-in (has clockInAt but no clockOutAt)
        const activeSession = attendance.find(
          (a: any) => a.clockInAt && !a.clockOutAt
        );

        if (activeSession) {
          const clockInTime = new Date(activeSession.clockInAt);
          const elapsed = Date.now() - clockInTime.getTime();
          const MAX_SESSION_MS = 16 * 60 * 60 * 1000; // 16 hours
          const isStale = elapsed > MAX_SESSION_MS;

          clockedInStaff.push({
            userKey: staff.userKey,
            name: staff.name || `${staff.first_name || ''} ${staff.last_name || ''}`.trim() || 'Unknown',
            picture: staff.picture,
            role: staff.role,
            email: staff.email,
            eventId: String(event._id),
            eventName: event.event_name,
            venueAddress: event.venue_address,
            clockInTime: activeSession.clockInAt,
            elapsedMs: elapsed,
            elapsedFormatted: formatElapsedTime(elapsed),
            clockInLocation: activeSession.clockInLocation,
            stale: isStale,
          });
        }
      }
    }

    // Sort by clock-in time (most recent first)
    clockedInStaff.sort(
      (a, b) => new Date(b.clockInTime).getTime() - new Date(a.clockInTime).getTime()
    );

    const staleCount = clockedInStaff.filter((s) => s.stale).length;

    return res.json({
      count: clockedInStaff.length,
      staleCount,
      staff: clockedInStaff,
    });
  } catch (err) {
    console.error('[currently-clocked-in] GET failed:', err);
    return res.status(500).json({ message: 'Failed to fetch currently clocked-in staff' });
  }
});

// Get attendance analytics for dashboard hero header
router.get('/events/attendance-analytics', requireAuth, async (req, res) => {
  try {
    const manager = await resolveManagerForRequest(req as any);
    if (!manager) {
      return res.status(403).json({ message: 'Manager access required' });
    }

    const { startDate, endDate } = req.query;

    // Default to last 7 days
    const end = endDate ? new Date(endDate as string) : new Date();
    const start = startDate
      ? new Date(startDate as string)
      : new Date(end.getTime() - 7 * 24 * 60 * 60 * 1000);

    // Get all events in date range
    const events = await EventModel.find(
      {
        managerId: manager._id,
        date: { $gte: start, $lte: end },
      },
      {
        _id: 1,
        event_name: 1,
        date: 1,
        accepted_staff: 1,
      }
    ).lean();

    // Separate query for currentlyWorking: use 48-hour window (matches currently-clocked-in endpoint)
    const cutoff48h = new Date();
    cutoff48h.setHours(cutoff48h.getHours() - 48);
    const recentEvents = await EventModel.find(
      { managerId: manager._id, date: { $gte: cutoff48h } },
      { 'accepted_staff.userKey': 1, 'accepted_staff.attendance': 1, 'accepted_staff.response': 1 }
    ).lean();

    let currentlyWorking = 0;
    for (const ev of recentEvents) {
      for (const s of (ev.accepted_staff || []) as any[]) {
        if (s.response !== 'accepted' && s.response !== 'accept') continue;
        for (const a of (s.attendance || []) as any[]) {
          if (a.clockInAt && !a.clockOutAt) currentlyWorking++;
        }
      }
    }

    let totalHoursPeriod = 0;
    let todayTotalHours = 0;
    const todayDateKey = new Date().toISOString().split('T')[0] as string;
    const dailyHours: { [date: string]: number } = {};

    // Initialize daily hours for all days in range
    const currentDate = new Date(start);
    while (currentDate <= end) {
      const dateKey = currentDate.toISOString().split('T')[0] as string;
      dailyHours[dateKey] = 0;
      currentDate.setDate(currentDate.getDate() + 1);
    }

    for (const event of events) {
      const acceptedStaff = (event.accepted_staff || []) as any[];
      const eventDate = event.date ? new Date(event.date).toISOString().split('T')[0] : null;

      for (const staff of acceptedStaff) {
        if (staff.response !== 'accepted' && staff.response !== 'accept') continue;

        const attendance = (staff.attendance || []) as any[];

        if (attendance.length > 0) {
          for (const record of attendance) {
            if (!record.clockInAt) continue;

            const clockIn = new Date(record.clockInAt);
            const clockInDate = clockIn.toISOString().split('T')[0] as string;
            const clockOut = record.clockOutAt ? new Date(record.clockOutAt) : null;

            // Calculate hours worked
            const endTime = clockOut || new Date();
            const hoursWorked = (endTime.getTime() - clockIn.getTime()) / (1000 * 60 * 60);

            // Add to daily totals
            if (clockInDate in dailyHours) {
              dailyHours[clockInDate]! += hoursWorked;
            }

            totalHoursPeriod += hoursWorked;
            if (clockInDate === todayDateKey) {
              todayTotalHours += hoursWorked;
            }
          }
        } else if (eventDate) {
          // No attendance records — fall back to scheduled event hours
          const startTime = (event as any).start_time;
          const endTime = (event as any).end_time;
          if (startTime && endTime) {
            const startParts = startTime.split(':').map(Number);
            const endParts = endTime.split(':').map(Number);
            let hours = (endParts[0] + endParts[1] / 60) - (startParts[0] + startParts[1] / 60);
            if (hours < 0) hours += 24;
            if (eventDate in dailyHours) {
              dailyHours[eventDate]! += hours;
            }
            totalHoursPeriod += hours;
            if (eventDate === todayDateKey) {
              todayTotalHours += hours;
            }
          }
        }
      }
    }

    // Get pending flags count
    const pendingFlagsCount = await FlaggedAttendanceModel.countDocuments({
      managerId: manager._id,
      status: 'pending',
    });

    // Format daily hours as array
    const weeklyHours = Object.entries(dailyHours)
      .map(([date, hours]) => ({
        date,
        hours: Math.round(hours * 10) / 10,
        dayOfWeek: new Date(date).toLocaleDateString('en-US', { weekday: 'short' }),
      }))
      .sort((a, b) => a.date.localeCompare(b.date));

    return res.json({
      currentlyWorking,
      todayTotalHours: Math.round(todayTotalHours * 10) / 10,
      periodTotalHours: Math.round(totalHoursPeriod * 10) / 10,
      pendingFlags: pendingFlagsCount,
      weeklyHours,
      dateRange: {
        start: start.toISOString(),
        end: end.toISOString(),
      },
    });
  } catch (err) {
    console.error('[attendance-analytics] GET failed:', err);
    return res.status(500).json({ message: 'Failed to fetch attendance analytics' });
  }
});

// ============================================================================
// END ATTENDANCE DASHBOARD ENDPOINTS
// ============================================================================

// ============================================================================
// AVAILABILITY ROUTES (must be before /events/:id to avoid route shadowing)
// ============================================================================

function getUserKey(req: any): string | undefined {
  const provider = req?.user?.provider;
  const sub = req?.user?.sub;
  if (!provider || !sub) return undefined;
  return `${provider}:${sub}`;
}

const availabilitySchema = z.object({
  date: z.string().min(1, 'date is required'),
  startTime: z.string().min(1, 'startTime is required'),
  endTime: z.string().min(1, 'endTime is required'),
  status: z.enum(['available', 'unavailable']),
});

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

// Create or update an availability block
router.post(['/availability', '/events/availability'], requireAuth, requireActiveSubscription, async (req, res) => {
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
    const existing = await AvailabilityModel.findOne({ userKey, date, startTime, endTime }, { _id: 1 }).lean();
    return res.json({ message: 'Availability updated', id: existing ? String(existing._id) : undefined });
  } catch (err: any) {
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

// ============================================================================
// END AVAILABILITY ROUTES
// ============================================================================

// Get a single event by ID
router.get('/events/:id', requireAuth, async (req, res) => {
  try {
    const eventId = req.params.id;

    if (!eventId || !mongoose.Types.ObjectId.isValid(eventId)) {
      return res.status(400).json({ message: 'Invalid event ID' });
    }

    // Verify the requester is a manager
    const manager = await resolveManagerForRequest(req as any);
    if (!manager) {
      return res.status(403).json({ message: 'Unauthorized: Manager access required' });
    }

    const event = await EventModel.findOne({
      _id: eventId,
      managerId: manager._id,
    }).lean();

    if (!event) {
      return res.status(404).json({ message: 'Event not found' });
    }

    // Return with string IDs
    const teamIds = Array.isArray(event.audience_team_ids)
      ? event.audience_team_ids
          .map((value: any) => {
            if (!value) return null;
            if (value instanceof mongoose.Types.ObjectId) {
              return value.toHexString();
            }
            const str = value.toString();
            return mongoose.Types.ObjectId.isValid(str) ? str : null;
          })
          .filter((value: string | null): value is string => !!value)
      : [];

    return res.json({
      ...event,
      id: String(event._id),
      managerId: event.managerId ? String(event.managerId) : undefined,
      audience_team_ids: teamIds,
    });
  } catch (err) {
    console.error('[GET /events/:id] Error:', err);
    return res.status(500).json({ message: 'Failed to get event' });
  }
});

router.get('/events', requireAuth, async (req, res) => {
  try {
    const authUser = (req as any).user as AuthenticatedUser | undefined;
    const audienceHeader =
      typeof req.headers['x-user-key'] === 'string'
        ? (req.headers['x-user-key'] as string).trim()
        : undefined;
    const explicitAudienceKey =
      audienceHeader && audienceHeader.length > 0 ? audienceHeader : undefined;
    const derivedAudienceKey =
      authUser?.provider && authUser.sub
        ? `${authUser.provider}:${authUser.sub}`
        : undefined;
    const audienceKey = explicitAudienceKey ?? derivedAudienceKey;

    let managerScope = false;
    let manager: any = null;
    let managerId: mongoose.Types.ObjectId | undefined;

    if (authUser?.provider && authUser.sub) {
      console.log('[GET /events] Looking for manager with provider:', authUser.provider, 'subject:', authUser.sub);
      manager = await ManagerModel.findOne({
        provider: authUser.provider,
        subject: authUser.sub,
      });
      console.log('[GET /events] Manager found (direct lookup):', manager ? `Yes (ID: ${manager._id})` : 'No');

      if (!manager && !explicitAudienceKey) {
        // Try fallback only if user has managerId in JWT (manager app user)
        // Staff users won't have managerId, so this will safely return null
        try {
          console.log('[GET /events] Trying resolveManagerForRequest fallback');
          manager = await resolveManagerForRequest(req as any);
          console.log('[GET /events] Manager found (fallback):', manager ? `Yes (ID: ${manager._id})` : 'No');
        } catch (err) {
          // Expected for staff users - they don't have managerId in JWT
          console.log('[GET /events] Not a manager, continuing as staff user');
          manager = null;
        }
      }

      if (manager && !explicitAudienceKey) {
        managerScope = true;
        managerId = manager._id as mongoose.Types.ObjectId;
        console.log('[GET /events] Using MANAGER scope with ID:', managerId);
      } else {
        console.log('[GET /events] Using STAFF scope for userKey:', audienceKey);
      }
    }

    const lastSyncParam = req.query.lastSync as string | undefined;

    const filter: any = {};

    if (managerScope && managerId) {
      filter.managerId = managerId;
      // Managers see all their events (including drafts)

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

      if (explicitAudienceKey) {
        filter.$or = [
          { audience_user_keys: { $size: 0 } },
          { audience_user_keys: { $exists: false } },
          { audience_user_keys: explicitAudienceKey },
        ];
      }
    } else {
      if (!audienceKey) {
        return res.status(403).json({ message: 'Audience access requires a valid user key' });
      }

      if (lastSyncParam) {
        try {
          const lastSyncDate = new Date(lastSyncParam);
          if (!isNaN(lastSyncDate.getTime())) {
            filter.updatedAt = { $gt: lastSyncDate };
          }
        } catch (e) {
          // Ignore invalid date formats for staff scope
        }
      }

      const membershipTeamIdsRaw = authUser?.provider && authUser.sub
        ? await TeamMemberModel.distinct('teamId', {
            provider: authUser.provider,
            subject: authUser.sub,
            status: 'active',
          })
        : [];

      console.log('[EVENTS DEBUG] Staff access - userKey:', audienceKey);
      console.log('[EVENTS DEBUG] Raw team memberships:', membershipTeamIdsRaw);

      const membershipTeamIds = (membershipTeamIdsRaw as unknown[])
        .map((value) => {
          if (!value) return null;
          if (value instanceof mongoose.Types.ObjectId) {
            return value as mongoose.Types.ObjectId;
          }
          const str = value.toString();
          if (!mongoose.Types.ObjectId.isValid(str)) {
            return null;
          }
          return new mongoose.Types.ObjectId(str);
        })
        .filter((value): value is mongoose.Types.ObjectId => value !== null);

      console.log('[EVENTS DEBUG] Processed team IDs:', membershipTeamIds);

      const visibilityFilters: any[] = [
        // Public/Private+Public events visible to all (no targeting required)
        {
          $and: [
            {
              $or: [
                { audience_team_ids: { $exists: false } },
                { audience_team_ids: { $eq: [] } },
              ],
            },
            {
              $or: [
                { audience_user_keys: { $exists: false } },
                { audience_user_keys: { $eq: [] } },
              ],
            },
            // Only if visibilityType is public or private_public (not private-only)
            {
              $or: [
                { visibilityType: 'public' },
                { visibilityType: 'private_public' },
              ]
            },
          ],
        },
        // Directly invited staff (any visibilityType)
        { audience_user_keys: audienceKey },
        // Staff who already accepted (any visibilityType)
        { 'accepted_staff.userKey': audienceKey },
      ];

      if (membershipTeamIds.length > 0) {
        visibilityFilters.push({ audience_team_ids: { $in: membershipTeamIds } });
      }

      filter.$or = visibilityFilters;

      // Staff can only see published events (not drafts)
      // The visibility filters above already ensure they only see events they're invited to
      filter.$and = [
        {
          $or: [
            { status: { $ne: 'draft' } },  // Non-draft events
            { accepted_staff: { $exists: true, $ne: [], $not: { $size: 0 } } }  // Events with accepted staff
          ]
        }
      ];

      console.log('[EVENTS DEBUG] Staff filter:', JSON.stringify(filter, null, 2));
    }

    // Log database name to debug discrepancy
    console.log('[EVENTS DEBUG] Database name:', mongoose.connection.db?.databaseName || 'unknown');
    console.log('[EVENTS DEBUG] EventModel collection:', EventModel.collection.name);

    const events = await EventModel.find(filter).sort({ createdAt: -1 }).lean();

    if (!managerScope) {
      console.log('[EVENTS DEBUG] Staff events found:', events.length);
      if (events.length > 0 && events[0]) {
        console.log('[EVENTS DEBUG] First event audience_team_ids:', events[0].audience_team_ids);
        console.log('[EVENTS DEBUG] First 3 events summary:');
        events.slice(0, 3).forEach((evt: any, i: number) => {
          console.log(`  ${i+1}. ${evt.event_name} - date: ${evt.date}, status: ${evt.status}, accepted_staff: ${(evt.accepted_staff || []).length}`);
        });
      }
    }

    // Enrich with tariff data
    const enrichedEvents = await enrichEventsWithTariffs(events);

    // For staff users, filter roles to only show their assigned role for private events
    let processedEvents = enrichedEvents;
    if (!managerScope && audienceKey) {
      processedEvents = enrichedEvents.map((event: any) => {
        const invitedStaff = event.invited_staff || [];
        const userInvitation = invitedStaff.find((s: any) => s.userKey === audienceKey);

        if (userInvitation && event.visibilityType === 'private') {
          // Filter roles to only the assigned role
          const assignedRoleName = userInvitation.roleName;
          const originalRoles = event.roles || [];
          const filteredRoles = originalRoles.filter((r: any) => {
            const roleNameLower = (r.role || '').toLowerCase();
            const assignedLower = (assignedRoleName || '').toLowerCase();
            const roleIdLower = (userInvitation.roleId || '').toLowerCase();
            return roleNameLower === assignedLower || roleNameLower === roleIdLower;
          });

          // Also filter role_stats to match filtered roles
          const originalRoleStats = event.role_stats || [];
          const filteredRoleStats = originalRoleStats.filter((rs: any) => {
            const roleNameLower = (rs.role || '').toLowerCase();
            const assignedLower = (assignedRoleName || '').toLowerCase();
            const roleIdLower = (userInvitation.roleId || '').toLowerCase();
            return roleNameLower === assignedLower || roleNameLower === roleIdLower;
          });

          console.log(`[EVENTS DEBUG] Event ${event.client_name}: Original roles: ${JSON.stringify(originalRoles.map((r: any) => r.role))}`);
          console.log(`[EVENTS DEBUG] Filtering for: assignedRoleName="${assignedRoleName}", roleId="${userInvitation.roleId}"`);
          console.log(`[EVENTS DEBUG] Filtered roles: ${JSON.stringify(filteredRoles.map((r: any) => r.role))}`);
          console.log(`[EVENTS DEBUG] Filtered role_stats: ${JSON.stringify(filteredRoleStats.map((rs: any) => rs.role))}`);

          return {
            ...event,
            roles: filteredRoles.length > 0 ? filteredRoles : event.roles, // Fallback to all if no match
            role_stats: filteredRoleStats.length > 0 ? filteredRoleStats : event.role_stats, // Fallback to all if no match
            assigned_role: assignedRoleName, // Tell staff app which role they were assigned
          };
        }

        return event;
      });
    }

    // Map events to include string ids
    const mappedEvents = processedEvents.map((event: any) => {
      const teamIds = Array.isArray(event.audience_team_ids)
        ? event.audience_team_ids
            .map((value: any) => {
              if (!value) return null;
              if (value instanceof mongoose.Types.ObjectId) {
                return value.toHexString();
              }
              const str = value.toString();
              return mongoose.Types.ObjectId.isValid(str) ? str : null;
            })
            .filter((value: string | null): value is string => !!value)
        : [];

      return {
        ...event,
        id: String(event._id),
        managerId: event.managerId ? String(event.managerId) : undefined,
        audience_team_ids: teamIds,
      };
    });

    // Include current server timestamp for next sync
    if (!managerScope) {
      console.log('[EVENTS DEBUG] Returning to staff app:', mappedEvents.length, 'events');
      if (mappedEvents.length > 0) {
        console.log('[EVENTS DEBUG] Sample event dates:', mappedEvents.slice(0, 3).map((e: any) => e.date));
      }
    }
    return res.json({
      events: mappedEvents,
      serverTimestamp: new Date().toISOString(),
      deltaSync: !!lastSyncParam
    });
  } catch (err) {
    return res.status(500).json({ error: 'Internal Server Error' });
  }
});

// Positions view: flatten roles to position cards with remaining spots
router.get('/positions', requireAuth, async (req, res) => {
  try {
    const manager = await resolveManagerForRequest(req as any);
    const managerId = manager._id as mongoose.Types.ObjectId;
    const events = await EventModel.find({ managerId })
      .sort({ createdAt: -1 })
      .lean();
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
router.delete('/events/:id/staff/:userKey', requireAuth, async (req, res) => {
  try {
    const manager = await resolveManagerForRequest(req as any);
    const managerId = manager._id as mongoose.Types.ObjectId;
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
      { _id: new mongoose.Types.ObjectId(eventId), managerId },
      {
        $pull: { accepted_staff: { userKey } } as any,
        $set: { updatedAt: new Date() }
      }
    );

    if (result.matchedCount === 0) {
      return res.status(404).json({ message: 'Event not found' });
    }

    // Recompute and persist role_stats
    const updatedEvent = await EventModel.findOne({
      _id: new mongoose.Types.ObjectId(eventId),
      managerId,
    }).lean();
    if (!updatedEvent) return res.status(404).json({ message: 'Event not found' });
    const role_stats = computeRoleStats((updatedEvent.roles as any[]) || [], (updatedEvent.accepted_staff as any[]) || []);
    await EventModel.updateOne(
      { _id: new mongoose.Types.ObjectId(eventId), managerId },
      { $set: { role_stats, updatedAt: new Date() } }
    );

    const finalDoc = await EventModel.findOne({
      _id: new mongoose.Types.ObjectId(eventId),
      managerId,
    }).lean();
    return res.json(finalDoc);
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error('[remove staff] failed', err);
    return res.status(500).json({ message: 'Failed to remove staff member' });
  }
});

router.post('/events/:id/respond', requireAuth, requireActiveSubscription, async (req, res) => {
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
    if (!(req as any).authUser?.provider || !(req as any).authUser?.sub) {
      // eslint-disable-next-line no-console
      console.warn('[respond] unauthorized: missing user claims');
      return res.status(401).json({ message: 'Unauthorized' });
    }

    const userKey = `${(req as any).authUser.provider}:${(req as any).authUser.sub}`;

    const firstName = (req as any).authUser.name
      ? (req as any).authUser.name.trim().split(/\s+/).slice(0, -1).join(' ') || undefined
      : undefined;
    const lastName = (req as any).authUser.name
      ? (req as any).authUser.name.trim().split(/\s+/).slice(-1)[0] || undefined
      : undefined;

    const roleVal = roleValRaw;

    const staffDoc = {
      userKey,
      provider: (req as any).authUser.provider,
      subject: (req as any).authUser.sub,
      email: (req as any).authUser.email,
      name: (req as any).authUser.name,
      first_name: firstName,
      last_name: lastName,
      picture: (req as any).authUser.picture,
      response: responseVal,
      role: roleVal || undefined,
      respondedAt: new Date(),
    };

    // Atomic operations (no transaction wrapper needed)
    let updatedEvent: any = null;

    try {
      if (responseVal === 'decline') {
        // DECLINE: Simple atomic operation (no capacity check needed)
        updatedEvent = await EventModel.findOneAndUpdate(
          { _id: new mongoose.Types.ObjectId(eventId) },
          {
            // Remove from accepted_staff (in case user previously accepted)
            $pull: {
              accepted_staff: { userKey }
            } as any,
            // Add to declined_staff
            $push: { declined_staff: staffDoc } as any,
            $inc: { version: 1 },
            $set: { updatedAt: new Date() }
          },
          { new: true }
        );

        if (!updatedEvent) {
          throw new Error('EVENT_NOT_FOUND');
        }

      } else {
        // ACCEPT: Atomic operation with embedded capacity check

        // First, validate that the role exists on this event
        const event = await EventModel.findById(eventId, { roles: 1 }).lean();
        if (!event) {
          throw new Error('EVENT_NOT_FOUND');
        }

        const roleReq = (event.roles || []).find((r: any) =>
          (r?.role || '').toLowerCase() === roleVal.toLowerCase()
        );

        if (!roleReq) {
          throw new Error(`ROLE_NOT_FOUND:${roleVal}`);
        }

        const roleCapacity = roleReq.count || 0;

        // ATOMIC OPERATION: Update only if capacity available AND user not already accepted
        // This query ensures:
        // 1. User isn't already in accepted_staff (prevents duplicates)
        // 2. Current accepted count for role < capacity (prevents overflow)
        // 3. All in a single atomic database operation (no race conditions)
        updatedEvent = await EventModel.findOneAndUpdate(
          {
            _id: new mongoose.Types.ObjectId(eventId),
            // Ensure user not already accepted for this event
            'accepted_staff.userKey': { $ne: userKey },
            // Embedded capacity check using MongoDB aggregation expressions
            $expr: {
              $lt: [
                // Count accepted staff with matching role (case-insensitive)
                {
                  $size: {
                    $filter: {
                      input: { $ifNull: ['$accepted_staff', []] },
                      as: 'staff',
                      cond: {
                        $eq: [
                          { $toLower: { $ifNull: ['$$staff.role', ''] } },
                          roleVal.toLowerCase()
                        ]
                      }
                    }
                  }
                },
                roleCapacity
              ]
            }
          },
          {
            // Remove from declined_staff (in case user previously declined)
            // NOTE: We don't pull from accepted_staff because the query filter already ensures userKey not in it
            $pull: {
              declined_staff: { userKey }
            } as any,
            // Add to accepted_staff
            $push: { accepted_staff: staffDoc } as any,
            $inc: { version: 1 },
            $set: { updatedAt: new Date() }
          },
          { new: true }
        );

        if (!updatedEvent) {
          // Query didn't match - either event not found, user already accepted, or capacity full
          // Check which scenario to provide better error message
          const checkEvent = await EventModel.findById(eventId).lean();

          if (!checkEvent) {
            throw new Error('EVENT_NOT_FOUND');
          }

          // Check if user already accepted
          const alreadyAccepted = (checkEvent.accepted_staff || []).some(
            (s: any) => s.userKey === userKey
          );
          if (alreadyAccepted) {
            throw new Error('ALREADY_ACCEPTED');
          }

          // Must be capacity full
          throw new Error(`CAPACITY_FULL:${roleVal}`);
        }
      }

      // Recompute role_stats (separate operation, not critical for atomicity)
      const role_stats = computeRoleStats(
        (updatedEvent.roles as any[]) || [],
        (updatedEvent.accepted_staff as any[]) || []
      );

      // Auto-publish draft events when first staff accepts (especially for private invitations)
      const updateFields: any = { role_stats, updatedAt: new Date() };

      if (responseVal === 'accept' && updatedEvent.status === 'draft') {
        updateFields.status = 'published';
        updateFields.publishedAt = new Date();
        console.log(`[respond] Auto-publishing event ${eventId} from draft to published (first staff acceptance)`);
      }

      // Check if event should auto-transition to 'fulfilled' status (all positions filled)
      if (responseVal === 'accept' && (updatedEvent.status === 'published' || updatedEvent.status === 'draft')) {
        const { checkIfEventFulfilled } = await import('../utils/eventCapacity');
        const isFulfilled = checkIfEventFulfilled(updatedEvent);

        if (isFulfilled) {
          console.log(`[respond] Event ${eventId} is now fulfilled - all positions filled`);
          updateFields.status = 'fulfilled';
          updateFields.fulfilledAt = new Date();

          // Emit socket event to manager for fulfilled status
          if (updatedEvent.managerId) {
            emitToManager(String(updatedEvent.managerId), 'event:fulfilled', {
              eventId: String(updatedEvent._id),
              eventName: updatedEvent.event_name,
              date: updatedEvent.date,
              timestamp: new Date().toISOString(),
            });
          }
        }
      }

      await EventModel.updateOne(
        { _id: updatedEvent._id },
        { $set: updateFields, $inc: { version: 1 } }
      );

      updatedEvent.role_stats = role_stats as any;
      if (updateFields.status) {
        updatedEvent.status = updateFields.status;
        updatedEvent.publishedAt = updateFields.publishedAt;
      }

      // Success - return updated event
      if (!updatedEvent) {
        throw new Error('Update completed but event not found');
      }

      const mapped = { id: String(updatedEvent._id), ...updatedEvent.toObject() } as any;
      delete mapped._id;

      // eslint-disable-next-line no-console
      console.log('[respond] success', { eventId, userKey, response: responseVal, role: roleVal });

      // Broadcast real-time update to all connected clients viewing this event
      try {
        const eventUpdate = {
          eventId,
          userId: userKey,
          response: responseVal,
          role: roleVal,
          acceptedStaff: mapped.accepted_staff || [],
          declinedStaff: mapped.declined_staff || [],
          roleStats: mapped.role_stats || [],
          timestamp: new Date().toISOString(),
        };

        // Emit to manager
        if (updatedEvent.managerId) {
          emitToManager(String(updatedEvent.managerId), 'event:response', eventUpdate);
        }

        // Emit to team members if event is associated with teams
        const audienceTeamIds = updatedEvent.audience_team_ids || [];
        if (audienceTeamIds.length > 0) {
          emitToTeams(
            audienceTeamIds.map((id: any) => String(id)),
            'event:response',
            eventUpdate
          );
        }

        // Emit to all staff who have already accepted (for real-time capacity updates)
        const acceptedStaff = updatedEvent.accepted_staff || [];
        acceptedStaff.forEach((staff: any) => {
          if (staff.userKey && staff.userKey !== userKey) {
            emitToUser(staff.userKey, 'event:response', eventUpdate);
          }
        });

        // eslint-disable-next-line no-console
        console.log('[respond] broadcasted real-time update', { eventId, response: responseVal });
      } catch (socketError) {
        // Don't fail the request if socket broadcast fails
        // eslint-disable-next-line no-console
        console.error('[respond] socket broadcast failed', socketError);
      }

      return res.json(mapped);

    } catch (transactionError: any) {
      // Handle specific error cases
      const errorMsg = transactionError.message || String(transactionError);

      if (errorMsg === 'EVENT_NOT_FOUND') {
        // eslint-disable-next-line no-console
        console.warn('[respond] event not found', { eventId });
        return res.status(404).json({ message: 'Event not found' });
      }

      if (errorMsg === 'ALREADY_ACCEPTED') {
        // eslint-disable-next-line no-console
        console.warn('[respond] user already accepted', { eventId, userKey });
        return res.status(409).json({ message: 'You have already accepted this event' });
      }

      if (errorMsg.startsWith('ROLE_NOT_FOUND:')) {
        const role = errorMsg.split(':')[1];
        // eslint-disable-next-line no-console
        console.warn('[respond] role not found', { eventId, role });
        return res.status(400).json({ message: `Role '${role}' not found for this event` });
      }

      if (errorMsg.startsWith('CAPACITY_FULL:')) {
        const role = errorMsg.split(':')[1];
        // eslint-disable-next-line no-console
        console.warn('[respond] capacity full', { eventId, role, userKey });
        return res.status(409).json({ message: `No spots left for role '${role}'` });
      }

      // Unknown error
      // eslint-disable-next-line no-console
      console.error('[respond] operation failed', { eventId, error: transactionError });
      throw transactionError;
    }
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error('[respond] failed', err);
    return res.status(500).json({ message: 'Failed to update response' });
  }
});

// Get current user's attendance record for an event
router.get('/events/:id/attendance/me', requireAuth, async (req, res) => {
  try {
    const eventId = req.params.id ?? '';
    if (!mongoose.Types.ObjectId.isValid(eventId)) {
      return res.status(400).json({ message: 'Invalid event id' });
    }
    if (!(req as any).authUser?.provider || !(req as any).authUser?.sub) {
      return res.status(401).json({ message: 'Unauthorized' });
    }
    const userKey = `${(req as any).authUser.provider}:${(req as any).authUser.sub}`;
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

// Zod schema for clock-in request with location
const clockInSchema = z.object({
  latitude: z.number().min(-90).max(90).optional(),
  longitude: z.number().min(-180).max(180).optional(),
  accuracy: z.number().positive().optional(),
  source: z.enum(['manual', 'geofence', 'voice_assistant', 'bulk_manager']).optional(),
});

// Clock in to an event (with optional server-side geofence validation)
router.post('/events/:id/clock-in', requireAuth, requireActiveSubscription, async (req, res) => {
  try {
    const eventId = req.params.id ?? '';
    if (!mongoose.Types.ObjectId.isValid(eventId)) {
      return res.status(400).json({ message: 'Invalid event id' });
    }
    if (!(req as any).authUser?.provider || !(req as any).authUser?.sub) {
      return res.status(401).json({ message: 'Unauthorized' });
    }
    const userKey = `${(req as any).authUser.provider}:${(req as any).authUser.sub}`;

    // Parse location from request body
    const parseResult = clockInSchema.safeParse(req.body);
    const { latitude, longitude, accuracy, source } = parseResult.success
      ? parseResult.data
      : { latitude: undefined, longitude: undefined, accuracy: undefined, source: undefined };

    const event = await EventModel.findById(eventId).lean();
    if (!event) return res.status(404).json({ message: 'Event not found' });

    // Server-side geofence validation (if venue and user location are available)
    if (
      event.venue_latitude &&
      event.venue_longitude &&
      latitude !== undefined &&
      longitude !== undefined &&
      isValidCoordinate(latitude, longitude) &&
      isValidCoordinate(event.venue_latitude, event.venue_longitude)
    ) {
      // Get manager's configured geofence radius (or use default)
      const manager = await ManagerModel.findById(event.managerId).lean();
      const geofenceRadius =
        (manager as any)?.clockInConfig?.geofenceRadiusMeters ?? DEFAULT_GEOFENCE_RADIUS_METERS;

      const { isInside, distanceMeters } = isWithinGeofence(
        latitude,
        longitude,
        event.venue_latitude,
        event.venue_longitude,
        geofenceRadius
      );

      if (!isInside) {
        return res.status(403).json({
          message: `You are ${formatDistance(distanceMeters)} from the venue. Please be within ${formatDistance(geofenceRadius)} to clock in.`,
          code: 'GEOFENCE_VIOLATION',
          distanceMeters,
          requiredRadiusMeters: geofenceRadius,
          venueLocation: {
            latitude: event.venue_latitude,
            longitude: event.venue_longitude,
          },
        });
      }
    }

    const accepted = (event.accepted_staff || []) as any[];
    const staffEntry = accepted.find((m: any) => (m?.userKey || '') === userKey);
    if (!staffEntry) {
      return res.status(403).json({ message: 'You are not accepted for this event' });
    }

    const clockInTime = new Date();

    // Build attendance record with optional location
    const newAttendanceRecord: any = { clockInAt: clockInTime };
    if (latitude !== undefined && longitude !== undefined && isValidCoordinate(latitude, longitude)) {
      newAttendanceRecord.clockInLocation = {
        latitude,
        longitude,
        accuracy: accuracy ?? undefined,
        source: source ?? 'manual',
      };
    }

    // Atomic clock-in: $push only if no active session (no record without clockOutAt)
    const result = await EventModel.updateOne(
      {
        _id: new mongoose.Types.ObjectId(eventId),
        'accepted_staff': {
          $elemMatch: {
            userKey,
            $or: [
              { attendance: { $exists: false } },
              { attendance: { $size: 0 } },
              { attendance: { $not: { $elemMatch: { clockOutAt: { $exists: false } } } } },
            ],
          },
        },
      },
      {
        $push: { 'accepted_staff.$.attendance': newAttendanceRecord },
        $set: { updatedAt: new Date() },
      }
    );

    if (result.matchedCount === 0) {
      // Disambiguate: user is in accepted_staff (checked above), so must be already clocked in
      const activeSession = ((staffEntry.attendance || []) as any[]).find(
        (a: any) => a.clockInAt && !a.clockOutAt
      );
      return res.status(409).json({
        message: 'Already clocked in',
        status: 'clocked_in',
        clockInAt: activeSession?.clockInAt,
      });
    }

    // Gamification points (future feature - disabled for now)
    const gamification: any = null;

    const existingAttendance = (staffEntry.attendance || []) as any[];
    return res.status(200).json({
      message: 'Clocked in',
      status: 'clocked_in',
      clockInAt: clockInTime,
      attendance: [...existingAttendance, newAttendanceRecord],
      // Include geofence status for client feedback
      geofenceValidated: !!(event.venue_latitude && event.venue_longitude && latitude && longitude),
      // Include gamification data if points were awarded
      gamification,
    });
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error('[clock-in] failed', err);
    return res.status(500).json({ message: 'Failed to clock in' });
  }
});

// Zod schema for clock-out request with location and auto-clock-out fields
const clockOutSchema = z.object({
  latitude: z.number().min(-90).max(90).optional(),
  longitude: z.number().min(-180).max(180).optional(),
  accuracy: z.number().positive().optional(),
  autoClockOut: z.boolean().optional(),
  autoClockOutReason: z.enum(['shift_end_buffer', 'forgot_clock_out', 'manager_override']).optional(),
});

// Clock out from an event (with optional location storage)
router.post('/events/:id/clock-out', requireAuth, requireActiveSubscription, async (req, res) => {
  try {
    const eventId = req.params.id ?? '';
    if (!mongoose.Types.ObjectId.isValid(eventId)) {
      return res.status(400).json({ message: 'Invalid event id' });
    }
    if (!(req as any).authUser?.provider || !(req as any).authUser?.sub) {
      return res.status(401).json({ message: 'Unauthorized' });
    }
    const userKey = `${(req as any).authUser.provider}:${(req as any).authUser.sub}`;

    // Parse location and auto-clock-out fields from request body
    const parseResult = clockOutSchema.safeParse(req.body);
    const { latitude, longitude, accuracy, autoClockOut, autoClockOutReason } = parseResult.success
      ? parseResult.data
      : { latitude: undefined, longitude: undefined, accuracy: undefined, autoClockOut: undefined, autoClockOutReason: undefined };

    const event = await EventModel.findById(eventId).lean();
    if (!event) return res.status(404).json({ message: 'Event not found' });
    const accepted = (event.accepted_staff || []) as any[];
    const staffEntry = accepted.find((m: any) => (m?.userKey || '') === userKey);
    if (!staffEntry) {
      return res.status(403).json({ message: 'You are not accepted for this event' });
    }

    const attendance = (staffEntry.attendance || []) as any[];
    const activeSession = attendance.find((a: any) => a.clockInAt && !a.clockOutAt);
    if (!activeSession) {
      return res.status(409).json({ message: 'Not clocked in' });
    }

    const clockOutTime = new Date();

    // Calculate estimated hours worked from the active session's clockInAt
    const clockInTime = new Date(activeSession.clockInAt);
    const hoursWorked = (clockOutTime.getTime() - clockInTime.getTime()) / (1000 * 60 * 60);
    const estimatedHours = Math.round(hoursWorked * 100) / 100;

    // Build the atomic $set fields for the matching session
    const updateFields: any = {
      'accepted_staff.$[staff].attendance.$[session].clockOutAt': clockOutTime,
      'accepted_staff.$[staff].attendance.$[session].estimatedHours': estimatedHours,
      'updatedAt': new Date(),
    };

    // Add clock-out location if provided
    if (latitude !== undefined && longitude !== undefined && isValidCoordinate(latitude, longitude)) {
      updateFields['accepted_staff.$[staff].attendance.$[session].clockOutLocation'] = {
        latitude,
        longitude,
        accuracy: accuracy ?? undefined,
      };
    }

    // Mark as auto clock-out if specified
    if (autoClockOut) {
      updateFields['accepted_staff.$[staff].attendance.$[session].autoClockOut'] = true;
      updateFields['accepted_staff.$[staff].attendance.$[session].autoClockOutReason'] =
        autoClockOutReason ?? 'shift_end_buffer';
    }

    // Atomic clock-out: only update sessions without clockOutAt
    const result = await EventModel.updateOne(
      { _id: new mongoose.Types.ObjectId(eventId), 'accepted_staff.userKey': userKey },
      { $set: updateFields },
      {
        arrayFilters: [
          { 'staff.userKey': userKey },
          { 'session.clockOutAt': { $exists: false } },
        ],
      }
    );

    if (result.matchedCount === 0) {
      return res.status(404).json({ message: 'Event not found' });
    }
    if (result.modifiedCount === 0) {
      // Document matched but no session was updated — already clocked out (race condition)
      return res.status(409).json({ message: 'Not clocked in' });
    }

    // Build the updated record for pattern checking and response
    const updatedLast: any = {
      ...activeSession,
      clockOutAt: clockOutTime,
      estimatedHours,
    };
    if (latitude !== undefined && longitude !== undefined && isValidCoordinate(latitude, longitude)) {
      updatedLast.clockOutLocation = { latitude, longitude, accuracy: accuracy ?? undefined };
    }
    if (autoClockOut) {
      updatedLast.autoClockOut = true;
      updatedLast.autoClockOutReason = autoClockOutReason ?? 'shift_end_buffer';
    }

    // Check for unusual patterns asynchronously (don't block the response)
    checkUnusualPatterns(event, userKey, updatedLast, staffEntry).catch((err) => {
      console.error('[clock-out] pattern check failed:', err);
    });

    // Build updated attendance for the response
    const updatedAttendance = attendance.map((a: any) =>
      a.clockInAt && !a.clockOutAt ? updatedLast : a
    );

    return res.status(200).json({
      message: autoClockOut ? 'Auto clocked out' : 'Clocked out',
      attendance: updatedAttendance,
      hoursWorked: estimatedHours,
      autoClockOut: autoClockOut ?? false,
    });
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error('[clock-out] failed', err);
    return res.status(500).json({ message: 'Failed to clock out' });
  }
});

// Zod schema for bulk clock-in request
const bulkClockInSchema = z.object({
  userKeys: z.array(z.string().min(1)).min(1, 'At least one user key is required'),
  note: z.string().max(500).optional(),
  timestamp: z.string().datetime().optional(),
});

// Bulk clock-in for managers (clock in multiple staff at once)
router.post('/events/:id/bulk-clock-in', requireAuth, async (req, res) => {
  try {
    const manager = await resolveManagerForRequest(req as any);
    if (!manager) {
      return res.status(403).json({ message: 'Manager access required' });
    }

    const eventId = req.params.id ?? '';
    if (!mongoose.Types.ObjectId.isValid(eventId)) {
      return res.status(400).json({ message: 'Invalid event id' });
    }

    // Validate request body
    const parseResult = bulkClockInSchema.safeParse(req.body);
    if (!parseResult.success) {
      return res.status(400).json({
        message: 'Invalid request',
        errors: parseResult.error.errors,
      });
    }

    const { userKeys, note, timestamp } = parseResult.data;
    const clockInTime = timestamp ? new Date(timestamp) : new Date();

    // Verify manager owns this event
    const event = await EventModel.findOne({
      _id: new mongoose.Types.ObjectId(eventId),
      managerId: manager._id,
    }).lean();

    if (!event) {
      return res.status(404).json({ message: 'Event not found or access denied' });
    }

    const managerKey = `${manager.provider}:${manager.subject}`;
    const acceptedStaff = (event.accepted_staff || []) as any[];
    const results: Array<{
      userKey: string;
      status: 'success' | 'error' | 'already_clocked_in' | 'not_accepted';
      message?: string;
      staffName?: string;
    }> = [];

    // Process each staff member
    for (const userKey of userKeys) {
      const staffIdx = acceptedStaff.findIndex((s: any) => s?.userKey === userKey);

      if (staffIdx === -1) {
        results.push({
          userKey,
          status: 'not_accepted',
          message: 'Staff member not accepted for this event',
        });
        continue;
      }

      const staff = acceptedStaff[staffIdx];

      // Check response status before allowing clock-in
      if (staff.response !== 'accepted' && staff.response !== 'accept') {
        results.push({
          userKey,
          status: 'not_accepted',
          message: 'Staff has not accepted this event',
          staffName: staff.name || `${staff.first_name || ''} ${staff.last_name || ''}`.trim(),
        });
        continue;
      }

      const attendance = (staff.attendance || []) as any[];
      const lastAttendance = attendance.length > 0 ? attendance[attendance.length - 1] : null;

      // Check if already clocked in
      if (lastAttendance && !lastAttendance.clockOutAt) {
        results.push({
          userKey,
          status: 'already_clocked_in',
          message: 'Already clocked in',
          staffName: staff.name || `${staff.first_name || ''} ${staff.last_name || ''}`.trim(),
        });
        continue;
      }

      // Create new attendance record with manager override
      const newAttendanceRecord = {
        clockInAt: clockInTime,
        clockInLocation: {
          latitude: event.venue_latitude || 0,
          longitude: event.venue_longitude || 0,
          source: 'bulk_manager' as const,
        },
        overrideBy: managerKey,
        overrideNote: note || 'Bulk clock-in by manager',
      };

      // Atomic $push: only if no active session (prevents race with concurrent bulk clock-ins)
      const updateResult = await EventModel.updateOne(
        {
          _id: new mongoose.Types.ObjectId(eventId),
          'accepted_staff': {
            $elemMatch: {
              userKey,
              $or: [
                { attendance: { $exists: false } },
                { attendance: { $size: 0 } },
                { attendance: { $not: { $elemMatch: { clockOutAt: { $exists: false } } } } },
              ],
            },
          },
        },
        {
          $push: { 'accepted_staff.$.attendance': newAttendanceRecord },
          $set: { updatedAt: new Date() },
        }
      );

      if (updateResult.matchedCount === 0) {
        // Race condition: someone else clocked them in between our read and this write
        results.push({
          userKey,
          status: 'already_clocked_in',
          message: 'Already clocked in',
          staffName: staff.name || `${staff.first_name || ''} ${staff.last_name || ''}`.trim(),
        });
        continue;
      }

      results.push({
        userKey,
        status: 'success',
        staffName: staff.name || `${staff.first_name || ''} ${staff.last_name || ''}`.trim(),
      });

      // Send notification to staff member
      try {
        const [provider, subject] = userKey.split(':');
        const user = await UserModel.findOne({ provider, subject }).lean();
        if (user) {
          const eventName = event.event_name || event.shift_name || 'your shift';
          await notificationService.sendToUser(
            String(user._id),
            '✅ Clocked In by Manager',
            `Your manager has clocked you in to "${eventName}".${note ? ` Note: ${note}` : ''}`,
            {
              type: 'event',
              eventId: String(event._id),
              action: 'bulk_clock_in',
            },
            'user'
          );
        }
      } catch (notifyErr) {
        console.error(`[bulk-clock-in] Failed to notify ${userKey}:`, notifyErr);
      }
    }

    const successCount = results.filter((r) => r.status === 'success').length;

    return res.status(200).json({
      message: `Successfully clocked in ${successCount} of ${userKeys.length} staff members`,
      results,
      total: userKeys.length,
      successful: successCount,
      clockInTime,
    });
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error('[bulk-clock-in] failed', err);
    return res.status(500).json({ message: 'Failed to perform bulk clock-in' });
  }
});

// Analyze sign-in sheet photo with OpenAI
router.post('/events/:id/analyze-sheet', requireAuth, async (req, res) => {
  try {
    const manager = await resolveManagerForRequest(req as any);
    const eventId = req.params.id ?? '';
    if (!mongoose.Types.ObjectId.isValid(eventId)) {
      return res.status(400).json({ message: 'Invalid event id' });
    }

    const { imageBase64 } = req.body;
    if (!imageBase64) {
      return res.status(400).json({ message: 'imageBase64 required' });
    }

    const openaiApiKey = process.env.OPENAI_API_KEY;
    if (!openaiApiKey) {
      console.error('[analyze-sheet] OPENAI_API_KEY not configured');
      return res.status(500).json({ message: 'OpenAI API key not configured on server' });
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

// Helper function to calculate string similarity (simple Levenshtein-based)
function stringSimilarity(str1: string, str2: string): number {
  const longer = str1.length > str2.length ? str1 : str2;
  const shorter = str1.length > str2.length ? str2 : str1;

  if (longer.length === 0) return 1.0;

  const editDistance = levenshteinDistance(longer, shorter);
  return (longer.length - editDistance) / longer.length;
}

function levenshteinDistance(str1: string, str2: string): number {
  const matrix: number[][] = [];

  for (let i = 0; i <= str2.length; i++) {
    matrix[i] = [i];
  }

  for (let j = 0; j <= str1.length; j++) {
    if (matrix[0]) matrix[0][j] = j;
  }

  for (let i = 1; i <= str2.length; i++) {
    for (let j = 1; j <= str1.length; j++) {
      const row = matrix[i];
      const prevRow = matrix[i - 1];
      if (!row || !prevRow) continue;

      if (str2.charAt(i - 1) === str1.charAt(j - 1)) {
        row[j] = prevRow[j - 1] ?? 0;
      } else {
        row[j] = Math.min(
          (prevRow[j - 1] ?? 0) + 1,
          (row[j - 1] ?? 0) + 1,
          (prevRow[j] ?? 0) + 1
        );
      }
    }
  }

  return matrix[str2.length]?.[str1.length] ?? 0;
}

// Submit hours from sign-in sheet
router.post('/events/:id/submit-hours', requireAuth, async (req, res) => {
  try {
    const manager = await resolveManagerForRequest(req as any);
    const managerId = manager._id as mongoose.Types.ObjectId;
    const eventId = req.params.id ?? '';
    if (!mongoose.Types.ObjectId.isValid(eventId)) {
      return res.status(400).json({ message: 'Invalid event id' });
    }

    const { staffHours, sheetPhotoUrl, submittedBy } = req.body;
    if (!Array.isArray(staffHours)) {
      return res.status(400).json({ message: 'staffHours array required' });
    }

    const event = await EventModel.findOne({
      _id: new mongoose.Types.ObjectId(eventId),
      managerId,
    });
    if (!event) return res.status(404).json({ message: 'Event not found' });

    // Update each staff member's attendance with sheet data
    const acceptedStaff = event.accepted_staff || [];

    console.log(`[submit-hours] Processing ${staffHours.length} staff members`);
    console.log(`[submit-hours] Event has ${acceptedStaff.length} accepted staff`);

    const matchResults: Array<{
      extractedName: string;
      extractedRole: string;
      matched: boolean;
      matchedName?: string;
      matchedUserKey?: string;
      similarity?: number;
      reason?: string;
    }> = [];

    for (const hours of staffHours) {
      console.log(`[submit-hours] Looking for: "${hours.name}" with role: "${hours.role}"`);

      // Try multiple matching strategies
      const nameLower = hours.name?.toLowerCase().trim() || '';
      const roleLower = hours.role?.toLowerCase().trim() || '';

      // First attempt: exact or contains match
      let staffMember = acceptedStaff.find((s: any) => {
        const staffName = (s.name || `${s.first_name || ''} ${s.last_name || ''}`).toLowerCase().trim();
        const staffRole = (s.role || '').toLowerCase().trim();

        const nameMatch = staffName.includes(nameLower) || nameLower.includes(staffName);
        const roleMatch = !roleLower || !staffRole || staffRole === roleLower;

        return nameMatch && roleMatch && staffName.length > 0 && nameLower.length > 0;
      });

      let matchMethod = 'exact';
      let similarity = 1.0;

      // Second attempt: fuzzy matching with similarity threshold
      if (!staffMember && nameLower.length > 0) {
        console.log(`[submit-hours] Trying fuzzy match for "${hours.name}"`);

        const candidates = acceptedStaff.map((s: any) => {
          const staffName = (s.name || `${s.first_name || ''} ${s.last_name || ''}`).toLowerCase().trim();
          const staffRole = (s.role || '').toLowerCase().trim();

          if (staffName.length === 0) return { staff: s, similarity: 0 };

          const nameSimilarity = stringSimilarity(nameLower, staffName);
          const roleMatch = !roleLower || !staffRole || staffRole === roleLower;

          // Boost similarity if role matches
          const finalSimilarity = roleMatch ? nameSimilarity : nameSimilarity * 0.8;

          console.log(`  Fuzzy: "${staffName}" (${staffRole}) - similarity=${finalSimilarity.toFixed(2)}`);

          return { staff: s, similarity: finalSimilarity, staffName };
        }).filter(c => c.similarity > 0.6); // Threshold: 60% similarity

        candidates.sort((a, b) => b.similarity - a.similarity);

        if (candidates.length > 0 && candidates[0]) {
          staffMember = candidates[0].staff;
          similarity = candidates[0].similarity ?? 1.0;
          matchMethod = 'fuzzy';
          console.log(`  ✓ Fuzzy matched to: "${candidates[0].staffName ?? ''}" (${(similarity * 100).toFixed(0)}% match)`);
        }
      }

      if (staffMember) {
        const staffName = staffMember.name || `${staffMember.first_name || ''} ${staffMember.last_name || ''}`;
        console.log(`  ✓ Found staff member: ${staffName} (${matchMethod})`);

        const matchResult: any = {
          extractedName: hours.name,
          extractedRole: hours.role,
          matched: true,
          matchedName: staffName.trim(),
          similarity: Math.round(similarity * 100),
        };
        if (staffMember.userKey) {
          matchResult.matchedUserKey = staffMember.userKey;
        }
        matchResults.push(matchResult);

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
      } else {
        console.log(`  ✗ No match found for "${hours.name}"`);
        const availableStaff = acceptedStaff.map((s: any) => {
          const staffName = s.name || `${s.first_name} ${s.last_name}`;
          return `${staffName} (${s.role || 'no role'})`;
        }).join(', ');
        console.log(`  Available staff: ${availableStaff}`);

        matchResults.push({
          extractedName: hours.name,
          extractedRole: hours.role,
          matched: false,
          reason: `No match found in accepted staff. Available: ${availableStaff}`,
        });
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

    const unmatchedCount = matchResults.filter(r => !r.matched).length;

    console.log(`[submit-hours] Successfully set hours for ${staffWithHours}/${staffHours.length} staff members`);
    if (unmatchedCount > 0) {
      console.log(`[submit-hours] WARNING: ${unmatchedCount} names could not be matched`);
    }

    return res.json({
      message: staffWithHours > 0
        ? `Hours submitted for ${staffWithHours}/${staffHours.length} staff members`
        : 'No hours were matched - check name matching results',
      processedCount: staffWithHours,
      totalCount: staffHours.length,
      unmatchedCount,
      matchResults,
      event
    });
  } catch (err) {
    console.error('[submit-hours] failed', err);
    return res.status(500).json({ message: 'Failed to submit hours' });
  }
});

// Approve hours for individual staff member
router.post('/events/:id/approve-hours/:userKey', requireAuth, async (req, res) => {
  try {
    const manager = await resolveManagerForRequest(req as any);
    const managerId = manager._id as mongoose.Types.ObjectId;
    const eventId = req.params.id ?? '';
    const userKey = req.params.userKey ?? '';

    if (!mongoose.Types.ObjectId.isValid(eventId)) {
      return res.status(400).json({ message: 'Invalid event id' });
    }

    const { approvedHours, approvedBy, notes } = req.body;
    if (approvedHours == null) {
      return res.status(400).json({ message: 'approvedHours required' });
    }

    const event = await EventModel.findOne({
      _id: new mongoose.Types.ObjectId(eventId),
      managerId,
    });
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

// Debug endpoint: inspect event attendance data
router.get('/events/:id/debug-attendance', requireAuth, async (req, res) => {
  try {
    const manager = await resolveManagerForRequest(req as any);
    const managerId = manager._id as mongoose.Types.ObjectId;
    const eventId = req.params.id ?? '';
    if (!mongoose.Types.ObjectId.isValid(eventId)) {
      return res.status(400).json({ message: 'Invalid event id' });
    }

    const event = await EventModel.findOne({
      _id: new mongoose.Types.ObjectId(eventId),
      managerId,
    }).lean();
    if (!event) return res.status(404).json({ message: 'Event not found' });

    const staffDebug = (event.accepted_staff || []).map((s: any) => ({
      name: s.name || `${s.first_name} ${s.last_name}`,
      role: s.role,
      userKey: s.userKey,
      attendanceCount: s.attendance?.length || 0,
      attendance: s.attendance?.map((a: any) => ({
        clockInAt: a.clockInAt,
        clockOutAt: a.clockOutAt,
        sheetSignInTime: a.sheetSignInTime,
        sheetSignOutTime: a.sheetSignOutTime,
        approvedHours: a.approvedHours,
        status: a.status,
        managerNotes: a.managerNotes,
      })) || [],
    }));

    return res.json({
      eventName: event.event_name,
      hoursStatus: event.hoursStatus,
      signInSheetPhotoUrl: event.signInSheetPhotoUrl,
      acceptedStaffCount: (event.accepted_staff || []).length,
      staff: staffDebug,
    });
  } catch (err) {
    console.error('[debug-attendance] failed', err);
    return res.status(500).json({ message: 'Failed to debug attendance' });
  }
});

// Bulk approve all hours for an event
router.post('/events/:id/bulk-approve-hours', requireAuth, async (req, res) => {
  try {
    const manager = await resolveManagerForRequest(req as any);
    const managerId = manager._id as mongoose.Types.ObjectId;
    const eventId = req.params.id ?? '';
    if (!mongoose.Types.ObjectId.isValid(eventId)) {
      return res.status(400).json({ message: 'Invalid event id' });
    }

    const { approvedBy } = req.body;
    if (!approvedBy) {
      return res.status(400).json({ message: 'approvedBy required' });
    }

    const event = await EventModel.findOne({
      _id: new mongoose.Types.ObjectId(eventId),
      managerId,
    });
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

// Get events for a specific user by userKey
router.get('/events/user/:userKey', requireAuth, async (req, res) => {
  try {
    const authUser = (req as any).user as AuthenticatedUser | undefined;
    if (!authUser) {
      return res.status(401).json({ message: 'Not authenticated' });
    }

    const userKey = req.params.userKey ?? '';
    if (!userKey) {
      return res.status(400).json({ message: 'userKey is required' });
    }

    // Build scoped query based on caller type
    const query: Record<string, any> = { 'accepted_staff.userKey': userKey };

    if (authUser.managerId) {
      // Manager: only see events they own
      query.managerId = new mongoose.Types.ObjectId(authUser.managerId);
    } else {
      // Staff: can only query their own events
      const callerKey = `${authUser.provider}:${authUser.sub}`;
      if (callerKey !== userKey) {
        return res.status(403).json({ message: 'Cannot view another staff member\'s events' });
      }
    }

    // Find all events where the user is in accepted_staff
    const events = await EventModel.find(query).sort({ date: -1 }).lean();

    // Map events and include user's specific role and status
    const mappedEvents = events.map((event: any) => {
      const staffMember = (event.accepted_staff || []).find(
        (s: any) => s.userKey === userKey
      );

      return {
        ...event,
        id: String(event._id),
        userRole: staffMember?.role || null,
        userResponse: staffMember?.response || null,
        userRespondedAt: staffMember?.respondedAt || null,
      };
    });

    return res.json({ events: mappedEvents });
  } catch (err) {
    console.error('[events/user] failed', err);
    return res.status(500).json({ message: 'Failed to fetch user events' });
  }
});

// Debug endpoint to check user's past events
router.get('/events/debug/my-past-events', requireAuth, async (req, res) => {
  try {
    const authUser = (req as any).user as AuthenticatedUser | undefined;
    const userKey = authUser?.provider && authUser.sub
      ? `${authUser.provider}:${authUser.sub}`
      : undefined;

    if (!userKey) {
      return res.status(401).json({ message: 'User not authenticated' });
    }

    const now = new Date();
    const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());

    // Find all events where user is in accepted_staff
    const allUserEvents = await EventModel.find({
      'accepted_staff.userKey': userKey
    }).lean();

    console.log(`[DEBUG] User: ${userKey}`);
    console.log(`[DEBUG] Total user events: ${allUserEvents.length}`);

    // Filter past events
    const pastEvents = allUserEvents.filter(event => {
      if (!event.date) return false;
      const eventDate = new Date(event.date);
      return eventDate < today;
    });

    console.log(`[DEBUG] Past events: ${pastEvents.length}`);

    return res.json({
      userKey,
      today: today.toISOString(),
      totalEvents: allUserEvents.length,
      pastEventsCount: pastEvents.length,
      pastEvents: pastEvents.map(event => ({
        id: String(event._id),
        event_name: event.event_name,
        date: event.date,
        client_name: event.client_name,
        status: event.status
      }))
    });

  } catch (err) {
    console.error('[DEBUG] Error:', err);
    return res.status(500).json({ message: 'Failed to debug events' });
  }
});

// ============================================================================
// FLAGGED ATTENDANCE MANAGEMENT ENDPOINTS
// ============================================================================

// Get flagged attendance entries for manager review
router.get('/events/flagged-attendance', requireAuth, async (req, res) => {
  try {
    const manager = await resolveManagerForRequest(req as any);
    if (!manager) {
      return res.status(403).json({ message: 'Manager access required' });
    }

    const { status, severity, limit = '50' } = req.query;

    const filter: any = { managerId: manager._id };
    if (status && typeof status === 'string') {
      filter.status = status;
    }
    if (severity && typeof severity === 'string') {
      filter.severity = severity;
    }

    const flagged = await FlaggedAttendanceModel.find(filter)
      .sort({ createdAt: -1 })
      .limit(parseInt(limit as string, 10))
      .lean();

    return res.json({ flagged });
  } catch (err) {
    console.error('[flagged-attendance] GET failed:', err);
    return res.status(500).json({ message: 'Failed to fetch flagged attendance' });
  }
});

// Review a flagged attendance entry (approve/dismiss)
const reviewFlagSchema = z.object({
  status: z.enum(['approved', 'dismissed', 'investigating']),
  reviewNotes: z.string().max(500).optional(),
});

router.patch('/events/flagged-attendance/:flagId', requireAuth, async (req, res) => {
  try {
    const manager = await resolveManagerForRequest(req as any);
    if (!manager) {
      return res.status(403).json({ message: 'Manager access required' });
    }

    const { flagId } = req.params;
    if (!flagId || !mongoose.Types.ObjectId.isValid(flagId)) {
      return res.status(400).json({ message: 'Invalid flag ID' });
    }

    const parseResult = reviewFlagSchema.safeParse(req.body);
    if (!parseResult.success) {
      return res.status(400).json({ message: 'Invalid request', details: parseResult.error.issues });
    }

    const { status, reviewNotes } = parseResult.data;
    const managerKey = `${manager.provider}:${manager.subject}`;

    const result = await FlaggedAttendanceModel.findOneAndUpdate(
      {
        _id: new mongoose.Types.ObjectId(flagId),
        managerId: manager._id,
      },
      {
        $set: {
          status,
          reviewedBy: managerKey,
          reviewedAt: new Date(),
          reviewNotes: reviewNotes || undefined,
        },
      },
      { new: true }
    );

    if (!result) {
      return res.status(404).json({ message: 'Flagged attendance not found' });
    }

    return res.json({ message: 'Review submitted', flag: result });
  } catch (err) {
    console.error('[flagged-attendance] PATCH failed:', err);
    return res.status(500).json({ message: 'Failed to review flagged attendance' });
  }
});

// Force clock-out a staff member (manager override)
router.post('/events/:id/force-clock-out/:userKey', requireAuth, async (req, res) => {
  try {
    const manager = await resolveManagerForRequest(req as any);
    if (!manager) {
      return res.status(403).json({ message: 'Manager access required' });
    }

    const { id, userKey } = req.params;
    const { note } = req.body;

    if (!id || !mongoose.Types.ObjectId.isValid(id)) {
      return res.status(400).json({ message: 'Invalid event ID' });
    }

    if (!userKey) {
      return res.status(400).json({ message: 'User key is required' });
    }

    const event = await EventModel.findOne({
      _id: new mongoose.Types.ObjectId(id),
      managerId: manager._id,
    });

    if (!event) {
      return res.status(404).json({ message: 'Event not found' });
    }

    // Find the staff member
    const staffIndex = event.accepted_staff?.findIndex(
      (s: any) => s.userKey === userKey
    );

    if (staffIndex === undefined || staffIndex === -1) {
      return res.status(404).json({ message: 'Staff member not found in this event' });
    }

    const staff = event.accepted_staff![staffIndex] as any;
    const attendance = staff.attendance || [];

    // Find active session
    const activeSessionIndex = attendance.findIndex(
      (a: any) => a.clockInAt && !a.clockOutAt
    );

    if (activeSessionIndex === -1) {
      return res.status(400).json({ message: 'Staff is not currently clocked in' });
    }

    // Update the attendance session
    const now = new Date();
    const updatePath = `accepted_staff.${staffIndex}.attendance.${activeSessionIndex}`;

    const result = await EventModel.updateOne(
      { _id: event._id },
      {
        $set: {
          [`${updatePath}.clockOutAt`]: now,
          [`${updatePath}.autoClockOut`]: true,
          [`${updatePath}.autoClockOutReason`]: 'manager_override',
          [`${updatePath}.overrideBy`]: String(manager._id),
          [`${updatePath}.overrideNote`]: note || 'Force clock-out by manager',
        },
      }
    );

    if (result.modifiedCount === 0) {
      return res.status(500).json({ message: 'Failed to update attendance' });
    }

    // Notify the staff member
    try {
      await notificationService.sendToUser(
        userKey,
        'You have been clocked out',
        `A manager has clocked you out from ${event.event_name}.${note ? ` Note: ${note}` : ''}`,
        { type: 'event', eventId: String(event._id) }  // Use existing notification type
      );
    } catch (notifyErr) {
      console.warn('[force-clock-out] Failed to send notification:', notifyErr);
    }

    return res.json({
      message: 'Staff clocked out successfully',
      clockOutAt: now,
      staffName: staff.name || `${staff.first_name || ''} ${staff.last_name || ''}`.trim(),
    });
  } catch (err) {
    console.error('[force-clock-out] POST failed:', err);
    return res.status(500).json({ message: 'Failed to force clock-out' });
  }
});

export default router;
