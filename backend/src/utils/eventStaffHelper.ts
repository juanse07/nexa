import mongoose from 'mongoose';
import { EventStaffModel } from '../models/eventStaff';

/**
 * Enriches an event with staff data from the EventStaff collection.
 * Reconstructs `accepted_staff[]` and `declined_staff[]` so the JSON response
 * shape is identical to the legacy embedded format — no Flutter client changes needed.
 *
 * Feature flag: if USE_EVENT_STAFF !== 'true', returns event unchanged (embedded data used).
 */
export async function enrichEventWithStaff<T extends { _id: any; accepted_staff?: any[]; declined_staff?: any[] }>(
  event: T
): Promise<T> {
  if (process.env.USE_EVENT_STAFF !== 'true') return event;

  const staffDocs = await EventStaffModel.find({ eventId: event._id }).lean();
  if (staffDocs.length === 0) {
    event.accepted_staff = [];
    event.declined_staff = [];
    return event;
  }

  // Preserve existing embedded attendance data (keyed by userKey).
  // AttendanceLog collection may be empty — attendance lives only in embedded arrays.
  const attendanceMap = new Map<string, any[]>();
  for (const s of event.accepted_staff || []) {
    if (s.userKey && Array.isArray(s.attendance) && s.attendance.length > 0) {
      attendanceMap.set(s.userKey, s.attendance);
    }
  }

  const accepted: any[] = [];
  const declined: any[] = [];

  for (const doc of staffDocs) {
    const staffObj = {
      userKey: doc.userKey,
      provider: doc.provider,
      subject: doc.subject,
      email: doc.email,
      name: doc.name,
      first_name: doc.first_name,
      last_name: doc.last_name,
      picture: doc.picture,
      response: doc.response,
      role: doc.role,
      respondedAt: doc.respondedAt,
      attendance: attendanceMap.get(doc.userKey) || [],
    };
    if (doc.response === 'accept') {
      accepted.push(staffObj);
    } else {
      declined.push(staffObj);
    }
  }

  event.accepted_staff = accepted;
  event.declined_staff = declined;
  return event;
}

/**
 * Enriches multiple events with staff data (batched query).
 */
export async function enrichEventsWithStaff<T extends { _id: any; accepted_staff?: any[]; declined_staff?: any[] }>(
  events: T[]
): Promise<T[]> {
  if (process.env.USE_EVENT_STAFF !== 'true') return events;
  if (events.length === 0) return events;

  const eventIds = events.map((e) => e._id);
  const staffDocs = await EventStaffModel.find({ eventId: { $in: eventIds } }).lean();

  // Build per-event attendance map from existing embedded data before overwriting.
  // Key: "eventId:userKey" → attendance array
  const attendanceMap = new Map<string, any[]>();
  for (const event of events) {
    const eid = event._id.toString();
    for (const s of event.accepted_staff || []) {
      if (s.userKey && Array.isArray(s.attendance) && s.attendance.length > 0) {
        attendanceMap.set(`${eid}:${s.userKey}`, s.attendance);
      }
    }
  }

  // Group by eventId
  const byEvent = new Map<string, { accepted: any[]; declined: any[] }>();
  for (const doc of staffDocs) {
    const eid = doc.eventId.toString();
    if (!byEvent.has(eid)) byEvent.set(eid, { accepted: [], declined: [] });
    const bucket = byEvent.get(eid)!;
    const staffObj = {
      userKey: doc.userKey,
      provider: doc.provider,
      subject: doc.subject,
      email: doc.email,
      name: doc.name,
      first_name: doc.first_name,
      last_name: doc.last_name,
      picture: doc.picture,
      response: doc.response,
      role: doc.role,
      respondedAt: doc.respondedAt,
      attendance: attendanceMap.get(`${eid}:${doc.userKey}`) || [],
    };
    if (doc.response === 'accept') {
      bucket.accepted.push(staffObj);
    } else {
      bucket.declined.push(staffObj);
    }
  }

  for (const event of events) {
    const data = byEvent.get(event._id.toString());
    event.accepted_staff = data?.accepted || [];
    event.declined_staff = data?.declined || [];
  }

  return events;
}

/**
 * Get all EventStaff documents for an event.
 */
export async function getEventStaffForEvent(eventId: string) {
  return EventStaffModel.find({ eventId: new mongoose.Types.ObjectId(eventId) }).lean();
}

/**
 * Count accepted staff for a specific role at an event.
 * Used for capacity checks — hits the compound index {eventId, response, role}.
 */
export async function getAcceptedCountByRole(
  eventId: string | mongoose.Types.ObjectId,
  role: string
): Promise<number> {
  return EventStaffModel.countDocuments({
    eventId: typeof eventId === 'string' ? new mongoose.Types.ObjectId(eventId) : eventId,
    response: 'accept',
    role: { $regex: new RegExp(`^${role}$`, 'i') },
  });
}
