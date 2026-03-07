import mongoose from 'mongoose';
import { TeamModel } from '../models/team';
import { TeamMemberModel } from '../models/teamMember';
import { UserModel } from '../models/user';
import { notificationService } from '../services/notificationService';

/**
 * Validate that team IDs belong to a specific manager.
 * Returns only the valid ObjectIds.
 */
export async function sanitizeTeamIds(
  managerId: mongoose.Types.ObjectId,
  input: unknown
): Promise<mongoose.Types.ObjectId[]> {
  if (!Array.isArray(input)) {
    return [];
  }
  const uniqueStrings = Array.from(
    new Set(
      input
        .map((value) => {
          if (value == null) return '';
          return value.toString().trim();
        })
        .filter((value) => value.length > 0)
    )
  );

  const objectIds = uniqueStrings
    .filter((value) => mongoose.Types.ObjectId.isValid(value))
    .map((value) => new mongoose.Types.ObjectId(value));

  if (objectIds.length === 0) {
    return [];
  }

  const teams = await TeamModel.find({
    _id: { $in: objectIds },
    managerId,
  })
    .select('_id')
    .lean();

  return teams.map((team) => team._id as mongoose.Types.ObjectId);
}

/**
 * Convert "HH:mm" time string to minutes since midnight.
 */
export function timeToMinutes(timeStr: string | undefined): number {
  if (!timeStr) return 0;
  const parts = timeStr.split(':');
  if (parts.length !== 2 || !parts[0] || !parts[1]) return 0;
  const hours = parseInt(parts[0], 10);
  const minutes = parseInt(parts[1], 10);
  if (isNaN(hours) || isNaN(minutes)) return 0;
  return hours * 60 + minutes;
}

/**
 * Format 24h "HH:mm" to 12h (e.g., "5 PM", "2:30 PM").
 */
function formatTime12h(timeStr: string): { formatted: string; period: string } {
  const parts = timeStr.split(':');
  if (parts.length < 2) return { formatted: timeStr, period: '' };
  const h = parseInt(parts[0]!, 10);
  const m = parseInt(parts[1]!, 10);
  if (isNaN(h) || isNaN(m)) return { formatted: timeStr, period: '' };
  const period = h >= 12 ? 'PM' : 'AM';
  const hour12 = h === 0 ? 12 : h > 12 ? h - 12 : h;
  const formatted = m === 0 ? `${hour12}` : `${hour12}:${String(m).padStart(2, '0')}`;
  return { formatted, period };
}

/**
 * Format a time range in 12h (e.g., "5\u201311 PM", "9 AM\u20135 PM").
 */
export function formatTimeRange(startTime: string, endTime: string): string {
  const start = formatTime12h(startTime);
  const end = formatTime12h(endTime);
  if (!start.period || !end.period) return `${startTime} - ${endTime}`;
  if (start.period === end.period) {
    return `${start.formatted}\u2013${end.formatted} ${end.period}`;
  }
  return `${start.formatted} ${start.period}\u2013${end.formatted} ${end.period}`;
}

/**
 * Format date as "Mar 9" from a Date or ISO string.
 */
export function formatNotifDate(date: Date | string): string {
  const d = date instanceof Date ? date : new Date(date);
  const day = d.getDate();
  const month = d.toLocaleDateString('en-US', { month: 'short' });
  return `${month} ${day}`;
}

/**
 * Format start time to 12h for display (e.g., "5:00 PM").
 */
export function formatStartTime12h(timeStr: string): string {
  const t = formatTime12h(timeStr);
  if (!t.period) return timeStr;
  return `${t.formatted} ${t.period}`;
}

/**
 * Send event push notifications to a list of staff userKeys.
 * Handles per-user terminology, team name lookup, and one-notification-per-role.
 *
 * @returns number of users successfully notified
 */
export async function sendEventNotifications(params: {
  targetUserKeys: string[];
  event: any;
  teamIdToName: Map<string, string>;
  notificationType: 'new_open' | 'now_open' | 'cancelled';
  managerId: string;
}): Promise<number> {
  const { targetUserKeys, event, teamIdToName, notificationType, managerId } = params;

  if (targetUserKeys.length === 0) return 0;

  const eventDate = event.date;
  const startTime = event.start_time;
  const endTime = event.end_time;
  const roles = event.roles || [];

  // Format date as "Mar 9"
  let formattedDate = '';
  if (eventDate) {
    formattedDate = formatNotifDate(eventDate);
  }

  // Format time range in 12h (e.g., "5–11 PM")
  let timeRange = '';
  if (startTime && endTime) {
    timeRange = formatTimeRange(startTime, endTime);
  }

  const teamIdStrings = Array.from(teamIdToName.keys());
  let notifiedCount = 0;

  for (const userKey of targetUserKeys) {
    try {
      const [provider, subject] = userKey.split(':');
      if (!provider || !subject) continue;

      const user = await UserModel.findOne({ provider, subject }).lean();
      if (!user) continue;

      // Get user's preferred terminology (default: 'shift')
      const terminology = (user as any).eventTerminology || 'shift';
      const capitalizedTerm = terminology.charAt(0).toUpperCase() + terminology.slice(1);

      // Find which team this user belongs to (from the event's audience teams)
      let teamName = 'Your team';
      if (teamIdStrings.length > 0) {
        const userTeamMembership = await TeamMemberModel.findOne({
          provider,
          subject,
          teamId: { $in: teamIdStrings.map((id: string) => new mongoose.Types.ObjectId(id)) },
          status: 'active',
        }).lean();

        if (userTeamMembership) {
          teamName = teamIdToName.get(String(userTeamMembership.teamId)) || 'Your team';
        }
      }

      // Build notification title and body based on type
      for (const role of roles) {
        const roleName = role.role || role.role_name;
        if (!roleName) continue;

        let notificationTitle: string;
        let notificationBody: string;

        switch (notificationType) {
          case 'new_open':
          case 'now_open': {
            notificationTitle = `New Open ${capitalizedTerm}`;
            const parts = [roleName];
            if (formattedDate) parts.push(formattedDate);
            if (timeRange) parts.push(timeRange);
            notificationBody = parts.join(' \u2022 ') + '\n' + teamName;
            break;
          }
          case 'cancelled': {
            notificationTitle = `${capitalizedTerm} Cancelled`;
            let datePart = '';
            if (formattedDate && timeRange) datePart = ` on ${formattedDate} \u2022 ${timeRange}`;
            else if (formattedDate) datePart = ` on ${formattedDate}`;
            notificationBody = `Your ${terminology}${datePart} was cancelled`;
            break;
          }
        }

        await notificationService.sendToUser(
          String(user._id),
          notificationTitle,
          notificationBody,
          {
            type: 'event',
            eventId: String(event._id),
            role: roleName,
          },
          'user'
        );
      }

      notifiedCount++;
    } catch (err) {
      console.error(`[EVENT NOTIF] Failed to send notification to ${userKey}:`, err);
    }
  }

  return notifiedCount;
}
