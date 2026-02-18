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
            notificationTitle = `🔵 New Open ${capitalizedTerm}`;
            notificationBody = `${teamName} posted a new ${terminology} as ${roleName}`;
            break;
          case 'now_open':
            notificationTitle = `🟢 ${capitalizedTerm} Now Open`;
            notificationBody = `${teamName} posted a new ${terminology} as ${roleName}`;
            break;
          case 'cancelled':
            notificationTitle = `⚪ ${capitalizedTerm} Canceled`;
            notificationBody = `${roleName} at ${teamName}`;
            break;
        }

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
