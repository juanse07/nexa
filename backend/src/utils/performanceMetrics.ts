/**
 * Shared performance metrics utilities.
 * Extracted from ai.ts so both AI chat tools and staffMatchingService can reuse them.
 */

export interface PunctualityEventDetail {
  date: string;
  clientName: string;
  role: string;
  status: 'on_time' | 'late' | 'no_show';
  minutesLate: number;
  bulkClockIn: boolean;
}

export interface PunctualityRecord {
  staffKey: string;
  staffName: string;
  onTimeCount: number;
  lateCount: number;
  noShowCount: number;
  totalLateMinutes: number;
  totalEvents: number;
  eventDetails: PunctualityEventDetail[];
}

/**
 * Compute punctuality stats from a set of events.
 *
 * For each accepted staff member on each event, compares their first clockInAt
 * against the expected arrival time (role call_time → event start_time fallback).
 *
 * @param events       - Pre-queried events (must include accepted_staff, date, start_time, roles, client_name, status)
 * @param staffUserKey - If set, only compute for this specific staff member
 * @param staffNamePattern - Fallback regex pattern when userKey is unavailable
 * @param thresholdMinutes - Grace period before marking late (default 5 min)
 */
export function computePunctuality(
  events: any[],
  staffUserKey?: string | null,
  staffNamePattern?: string | null,
  thresholdMinutes: number = 5
): PunctualityRecord[] {
  const recordMap = new Map<string, PunctualityRecord>();

  for (const event of events) {
    if (!event.accepted_staff || !Array.isArray(event.accepted_staff)) continue;

    // Only evaluate completed/fulfilled/in_progress events (future drafts are meaningless)
    const eventStatus = event.status;
    if (!['completed', 'fulfilled', 'in_progress'].includes(eventStatus)) continue;

    const eventDate = event.date ? new Date(event.date) : null;
    if (!eventDate) continue;

    for (const staff of event.accepted_staff) {
      // Filter: only accepted staff
      if (staff.response !== 'accepted' && staff.response !== 'accept') continue;

      // Filter to specific staff if requested
      if (staffUserKey && staff.userKey !== staffUserKey) continue;
      if (!staffUserKey && staffNamePattern && !new RegExp(staffNamePattern, 'i').test(staff.name || '')) continue;

      // Determine expected arrival time
      // Priority: role-specific call_time → event start_time
      let expectedTimeStr: string | null = null;

      if (staff.role && event.roles && Array.isArray(event.roles)) {
        const matchedRole = event.roles.find(
          (r: any) => r.role && r.call_time && r.role.toLowerCase() === staff.role.toLowerCase()
        );
        if (matchedRole?.call_time) {
          expectedTimeStr = matchedRole.call_time;
        }
      }

      if (!expectedTimeStr && event.start_time) {
        expectedTimeStr = event.start_time;
      }

      if (!expectedTimeStr) continue; // Can't compute without an expected time

      // Build full expected datetime
      const timeParts = expectedTimeStr.split(':').map(Number);
      const expH = timeParts[0] ?? 0;
      const expM = timeParts[1] ?? 0;
      const expectedDt = new Date(eventDate);
      expectedDt.setHours(expH, expM, 0, 0);

      // Staff key for grouping
      const key = staff.userKey || staff.name || 'unknown';
      if (!recordMap.has(key)) {
        recordMap.set(key, {
          staffKey: key,
          staffName: staff.name || staff.first_name || 'Unknown',
          onTimeCount: 0,
          lateCount: 0,
          noShowCount: 0,
          totalLateMinutes: 0,
          totalEvents: 0,
          eventDetails: []
        });
      }
      const record = recordMap.get(key)!;
      record.totalEvents++;

      const attendance = staff.attendance;
      const hasClockIn = attendance && Array.isArray(attendance) && attendance.length > 0 && attendance[0].clockInAt;

      if (!hasClockIn) {
        // No attendance → no-show (only meaningful for completed events)
        record.noShowCount++;
        record.eventDetails.push({
          date: eventDate.toISOString().slice(0, 10),
          clientName: event.client_name || 'Unknown',
          role: staff.role || 'N/A',
          status: 'no_show',
          minutesLate: 0,
          bulkClockIn: false
        });
        continue;
      }

      // Use first session's clockInAt
      const clockIn = new Date(attendance[0].clockInAt);
      const diffMinutes = (clockIn.getTime() - expectedDt.getTime()) / (1000 * 60);
      const isBulk = !!attendance[0].overrideBy;

      if (diffMinutes <= thresholdMinutes) {
        record.onTimeCount++;
        record.eventDetails.push({
          date: eventDate.toISOString().slice(0, 10),
          clientName: event.client_name || 'Unknown',
          role: staff.role || 'N/A',
          status: 'on_time',
          minutesLate: 0,
          bulkClockIn: isBulk
        });
      } else {
        const minsLate = Math.round(diffMinutes);
        record.lateCount++;
        record.totalLateMinutes += minsLate;
        record.eventDetails.push({
          date: eventDate.toISOString().slice(0, 10),
          clientName: event.client_name || 'Unknown',
          role: staff.role || 'N/A',
          status: 'late',
          minutesLate: minsLate,
          bulkClockIn: isBulk
        });
      }
    }
  }

  return Array.from(recordMap.values());
}
