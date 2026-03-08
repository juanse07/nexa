import { AttendanceLogModel } from '../models/attendanceLog';
import type { AttendanceSession } from '../models/event';

/**
 * Enriches an event (or array of events) with attendance data from the AttendanceLog collection.
 * Merges attendance sessions back into accepted_staff[].attendance[] so the JSON response
 * shape is identical to the legacy nested format — no Flutter client changes needed.
 *
 * Feature flag: if USE_ATTENDANCE_LOG env is 'false', skips enrichment (data still in nested arrays).
 */
export async function enrichEventWithAttendance<T extends { _id: any; accepted_staff?: any[] }>(
  event: T
): Promise<T> {
  if (process.env.USE_ATTENDANCE_LOG === 'false') return event;
  if (!event.accepted_staff || event.accepted_staff.length === 0) return event;

  const logs = await AttendanceLogModel.find({ eventId: event._id }).lean();
  if (logs.length === 0) return event;

  // Group logs by userKey
  const byUser = new Map<string, AttendanceSession[]>();
  for (const log of logs) {
    const sessions = byUser.get(log.userKey) || [];
    sessions.push({
      clockInAt: log.clockInAt,
      clockOutAt: log.clockOutAt,
      estimatedHours: log.estimatedHours,
      clockInLocation: log.clockInLocation as any,
      clockOutLocation: log.clockOutLocation,
      autoClockOut: log.autoClockOut,
      autoClockOutReason: log.autoClockOutReason,
      overrideBy: log.overrideBy,
      overrideNote: log.overrideNote,
      sheetSignInTime: log.sheetSignInTime,
      sheetSignOutTime: log.sheetSignOutTime,
      approvedHours: log.approvedHours,
      status: log.status,
      approvedBy: log.approvedBy,
      approvedAt: log.approvedAt,
      managerNotes: log.managerNotes,
      discrepancyNote: log.discrepancyNote,
    });
    byUser.set(log.userKey, sessions);
  }

  // Merge into accepted_staff
  for (const staff of event.accepted_staff) {
    const userKey = staff.userKey;
    if (userKey && byUser.has(userKey)) {
      staff.attendance = byUser.get(userKey);
    }
  }

  return event;
}

/**
 * Enriches multiple events with attendance data (batched query).
 */
export async function enrichEventsWithAttendance<T extends { _id: any; accepted_staff?: any[] }>(
  events: T[]
): Promise<T[]> {
  if (process.env.USE_ATTENDANCE_LOG === 'false') return events;
  if (events.length === 0) return events;

  const eventIds = events.map((e) => e._id);
  const logs = await AttendanceLogModel.find({ eventId: { $in: eventIds } }).lean();
  if (logs.length === 0) return events;

  // Group by eventId → userKey → sessions
  const byEvent = new Map<string, Map<string, AttendanceSession[]>>();
  for (const log of logs) {
    const eid = log.eventId.toString();
    if (!byEvent.has(eid)) byEvent.set(eid, new Map());
    const userMap = byEvent.get(eid)!;
    const sessions = userMap.get(log.userKey) || [];
    sessions.push({
      clockInAt: log.clockInAt,
      clockOutAt: log.clockOutAt,
      estimatedHours: log.estimatedHours,
      clockInLocation: log.clockInLocation as any,
      clockOutLocation: log.clockOutLocation,
      autoClockOut: log.autoClockOut,
      autoClockOutReason: log.autoClockOutReason,
      overrideBy: log.overrideBy,
      overrideNote: log.overrideNote,
      sheetSignInTime: log.sheetSignInTime,
      sheetSignOutTime: log.sheetSignOutTime,
      approvedHours: log.approvedHours,
      status: log.status,
      approvedBy: log.approvedBy,
      approvedAt: log.approvedAt,
      managerNotes: log.managerNotes,
      discrepancyNote: log.discrepancyNote,
    });
    userMap.set(log.userKey, sessions);
  }

  // Merge into events
  for (const event of events) {
    const userMap = byEvent.get(event._id.toString());
    if (!userMap || !event.accepted_staff) continue;
    for (const staff of event.accepted_staff) {
      if (staff.userKey && userMap.has(staff.userKey)) {
        staff.attendance = userMap.get(staff.userKey);
      }
    }
  }

  return events;
}

/**
 * Get attendance sessions for a single staff member at a specific event.
 */
export async function getAttendanceForStaff(
  eventId: string,
  userKey: string
) {
  return AttendanceLogModel.find({ eventId, userKey }).sort({ clockInAt: -1 }).lean();
}

/**
 * Get the currently active (not clocked out) session for a staff member at an event.
 */
export async function getActiveSession(eventId: string, userKey: string) {
  return AttendanceLogModel.findOne({
    eventId,
    userKey,
    clockOutAt: null,
  }).lean();
}
