import * as cron from 'node-cron';
import os from 'os';
import { EventModel } from '../models/event';
import { UserModel } from '../models/user';
import { EventChatMessageModel } from '../models/eventChatMessage';
import { notificationService } from './notificationService';
import { formatNotifDate, formatStartTime12h } from '../utils/eventHelpers';
import { emitToManager } from '../socket/server';
import { AttendanceLogModel } from '../models/attendanceLog';
import { getRedisClient } from '../db/redis';
import { enrichEventsWithStaff } from '../utils/eventStaffHelper';

const instanceId = `${os.hostname()}:${process.pid}`;

/**
 * Acquire a distributed lock using Redis SET NX EX.
 * Returns true if this instance acquired the lock, false otherwise.
 * Lock auto-expires after `ttlSeconds` so a dead instance's lock is reclaimed.
 */
async function acquireCronLock(name: string, ttlSeconds: number): Promise<boolean> {
  const redis = getRedisClient();
  if (!redis) return true; // No Redis = single instance, always run
  try {
    const result = await redis.set(`lock:cron:${name}`, instanceId, 'EX', ttlSeconds, 'NX');
    return result === 'OK';
  } catch {
    return true; // Redis error = degrade to allowing execution
  }
}

class NotificationScheduler {
  private tasks: cron.ScheduledTask[] = [];

  /**
   * Initialize all scheduled notification tasks
   */
  initialize() {
    console.log('[NotificationScheduler] Initializing scheduled tasks...');

    // Run every 5 minutes to check for upcoming shifts
    this.tasks.push(
      cron.schedule('*/5 * * * *', async () => {
        if (!(await acquireCronLock('upcoming_shifts', 4 * 60))) return;
        this.checkUpcomingShifts().catch(err => {
          console.error('[NotificationScheduler] Upcoming shifts check failed:', err);
        });
      })
    );

    // Run every 15 minutes to check for forgotten clock-outs
    this.tasks.push(
      cron.schedule('*/15 * * * *', async () => {
        if (!(await acquireCronLock('forgotten_clockouts', 14 * 60))) return;
        this.checkForgottenClockOuts().catch(err => {
          console.error('[NotificationScheduler] Forgotten clock-outs check failed:', err);
        });
      })
    );

    // Run daily at 9 AM to send timesheet reminders
    this.tasks.push(
      cron.schedule('0 9 * * *', async () => {
        if (!(await acquireCronLock('timesheet_reminders', 23 * 60 * 60))) return;
        this.sendTimesheetReminders().catch(err => {
          console.error('[NotificationScheduler] Timesheet reminders failed:', err);
        });
      })
    );

    // Run every 5 minutes to auto-enable chat 1 hour before events
    this.tasks.push(
      cron.schedule('*/5 * * * *', async () => {
        if (!(await acquireCronLock('auto_enable_chat', 4 * 60))) return;
        this.autoEnableEventChat().catch(err => {
          console.error('[NotificationScheduler] Auto-enable chat failed:', err);
        });
      })
    );

    // Run daily at midnight to auto-complete past events
    this.tasks.push(
      cron.schedule('0 0 * * *', async () => {
        if (!(await acquireCronLock('auto_complete', 23 * 60 * 60))) return;
        this.autoCompleteEvents().catch(err => {
          console.error('[NotificationScheduler] Auto-complete events failed:', err);
        });
      })
    );

    console.log('[NotificationScheduler] ✅ Initialized 5 scheduled tasks');
  }

  /**
   * Check for shifts starting in the next 1 hour and send reminders
   */
  async checkUpcomingShifts(): Promise<void> {
    try {
      const now = new Date();
      const oneHourFromNow = new Date(now.getTime() + 60 * 60 * 1000);
      const fiveMinutesFromNow = new Date(now.getTime() + 5 * 60 * 1000);

      console.log(`[NotificationScheduler] Checking for shifts between ${fiveMinutesFromNow.toISOString()} and ${oneHourFromNow.toISOString()}`);

      // Find events starting within the next hour that haven't been notified yet
      const upcomingEvents = await EventModel.find({
        date: {
          $gte: fiveMinutesFromNow,
          $lte: oneHourFromNow
        },
        status: { $in: ['confirmed', 'published'] },
        'notificationsSent.preShiftReminder': { $ne: true }
      }).lean();

      console.log(`[NotificationScheduler] Found ${upcomingEvents.length} upcoming shifts`);

      // Enrich with staff data from EventStaff collection
      await enrichEventsWithStaff(upcomingEvents);

      // Batch-resolve all staff userKeys → user IDs in one query
      const allUserKeys = new Set<string>();
      for (const event of upcomingEvents) {
        for (const staff of event.accepted_staff || []) {
          if (staff.userKey) allUserKeys.add(staff.userKey as string);
        }
      }
      const userIdMap = await this.batchResolveUserIds(Array.from(allUserKeys));

      for (const event of upcomingEvents) {
        const acceptedStaff = event.accepted_staff || [];

        for (const staff of acceptedStaff) {
          const userKey = staff.userKey as string;
          if (!userKey) continue;

          const userId = userIdMap.get(userKey);
          if (!userId) continue;

          // Calculate time until shift
          const eventDate = event.date ? new Date(event.date) : null;
          if (!eventDate) continue;

          const timeUntilShift = Math.round((eventDate.getTime() - now.getTime()) / (60 * 1000));
          const timeText = timeUntilShift > 60
            ? `${Math.round(timeUntilShift / 60)}h ${timeUntilShift % 60}m`
            : `${timeUntilShift}m`;

          // Get staff's role name
          const staffRole = (staff as any).role || '';

          // Format start time in 12h
          const startTime12h = event.start_time ? formatStartTime12h(event.start_time) : '';

          // Build body lines
          const line1 = staffRole
            ? `${staffRole} shift starts in ${timeText}`
            : `Your shift starts in ${timeText}`;
          const line2 = event.venue_name ? `${event.venue_name}` : '';
          const line3 = startTime12h ? `Your shift starts at ${startTime12h}` : '';
          const bodyLines = [line1, line2, line3].filter(Boolean);

          await notificationService.sendToUser(
            userId,
            'Shift Starting Soon',
            bodyLines.join('\n'),
            {
              type: 'event',
              eventId: event._id.toString(),
              action: 'shift_reminder',
              eventName: event.event_name || 'Shift',
              venueName: event.venue_name || '',
              startTime: eventDate.toISOString(),
            },
            'user',
            '6366F1'
          );

          console.log(`[NotificationScheduler] ✅ Sent shift reminder to ${userId} for event ${event._id}`);
        }

        // Mark event as notified
        await EventModel.updateOne(
          { _id: event._id },
          { $set: { 'notificationsSent.preShiftReminder': true } }
        );
      }

    } catch (error) {
      console.error('[NotificationScheduler] checkUpcomingShifts error:', error);
    }
  }

  /**
   * Check for staff who forgot to clock out after event ended
   */
  async checkForgottenClockOuts(): Promise<void> {
    try {
      const now = new Date();
      const twoHoursAgo = new Date(now.getTime() - 2 * 60 * 60 * 1000);

      console.log(`[NotificationScheduler] Checking for forgotten clock-outs (events ended before ${twoHoursAgo.toISOString()})`);

      // Find events with dates in the past that haven't been checked yet
      // We'll check end_time manually since it's a string field
      const endedEvents = await EventModel.find({
        date: { $lt: now },
        status: { $in: ['confirmed', 'published'] },
        'notificationsSent.forgotClockOut': { $ne: true }
      }).lean();

      console.log(`[NotificationScheduler] Found ${endedEvents.length} ended events to check`);

      for (const event of endedEvents) {
        // Calculate event end time from date + end_time
        const eventDate = event.date ? new Date(event.date) : null;
        if (!eventDate) continue;

        // Parse end_time (HH:MM format) and calculate actual end datetime
        const endTimeParts = (event.end_time || '').split(':');
        if (endTimeParts.length !== 2 || !endTimeParts[0] || !endTimeParts[1]) continue;

        const endDateTime = new Date(eventDate);
        endDateTime.setHours(parseInt(endTimeParts[0], 10), parseInt(endTimeParts[1], 10), 0, 0);

        // Skip if event hasn't ended yet or ended less than 2 hours ago
        if (endDateTime > twoHoursAgo) continue;

        let sentNotificationCount = 0;

        // Primary: query AttendanceLog for active sessions (no clockOutAt) on this event
        try {
          const activeSessions = await AttendanceLogModel.find({
            eventId: event._id,
            clockOutAt: null,
          }).lean();

          // Batch-resolve userKeys for this event's active sessions
          const sessionKeys = activeSessions.map(s => s.userKey).filter(Boolean) as string[];
          const sessionUserIdMap = await this.batchResolveUserIds(sessionKeys);

          for (const session of activeSessions) {
            const userKey = session.userKey;
            if (!userKey) continue;

            const userId = sessionUserIdMap.get(userKey);
            if (!userId) continue;

            const hoursSinceEnd = Math.round((now.getTime() - endDateTime.getTime()) / (60 * 60 * 1000));

            await notificationService.sendToUser(
              userId,
              'Clock Out Reminder',
              `Your shift at ${event.venue_name || 'venue'} ended ${hoursSinceEnd}h ago`,
              {
                type: 'event',
                eventId: event._id.toString(),
                action: 'forgot_clock_out',
                eventName: event.event_name || 'Shift',
                venueName: event.venue_name || '',
                endTime: endDateTime.toISOString(),
              },
              'user',
              'F59E0B'
            );

            sentNotificationCount++;
            console.log(`[NotificationScheduler] ✅ Sent forgot-clock-out reminder to ${userId} for event ${event._id}`);
          }
        } catch (err) {
          // Fallback: scan nested accepted_staff[].attendance[] if AttendanceLog query fails
          console.warn('[NotificationScheduler] AttendanceLog query failed, falling back to nested data:', err);

          const acceptedStaff = event.accepted_staff || [];

          // Collect userKeys of staff who forgot to clock out, then batch-resolve
          const forgotKeys: string[] = [];
          for (const staff of acceptedStaff) {
            const userKey = staff.userKey as string;
            if (!userKey) continue;
            const attendance = staff.attendance as any[] || [];
            const lastAttendance = attendance.length > 0 ? attendance[attendance.length - 1] : null;
            if (lastAttendance && lastAttendance.clockInAt && !lastAttendance.clockOutAt) {
              forgotKeys.push(userKey);
            }
          }

          const fallbackUserIdMap = await this.batchResolveUserIds(forgotKeys);

          for (const userKey of forgotKeys) {
            const userId = fallbackUserIdMap.get(userKey);
            if (!userId) continue;

            const hoursSinceEnd = Math.round((now.getTime() - endDateTime.getTime()) / (60 * 60 * 1000));

            await notificationService.sendToUser(
              userId,
              'Clock Out Reminder',
              `Your shift at ${event.venue_name || 'venue'} ended ${hoursSinceEnd}h ago`,
              {
                type: 'event',
                eventId: event._id.toString(),
                action: 'forgot_clock_out',
                eventName: event.event_name || 'Shift',
                venueName: event.venue_name || '',
                endTime: endDateTime.toISOString(),
              },
              'user',
              'F59E0B'
            );

            sentNotificationCount++;
            console.log(`[NotificationScheduler] ✅ Sent forgot-clock-out reminder to ${userId} for event ${event._id}`);
          }
        }

        // Mark event as notified
        await EventModel.updateOne(
          { _id: event._id },
          { $set: { 'notificationsSent.forgotClockOut': true } }
        );

        if (sentNotificationCount > 0) {
          console.log(`[NotificationScheduler] Sent ${sentNotificationCount} forgot-clock-out notifications for event ${event._id}`);
        }
      }

    } catch (error) {
      console.error('[NotificationScheduler] checkForgottenClockOuts error:', error);
    }
  }

  /**
   * Send weekly timesheet reminders
   */
  async sendTimesheetReminders(): Promise<void> {
    try {
      console.log('[NotificationScheduler] Sending timesheet reminders...');

      // Find all active staff users
      const users = await UserModel.find({
        role: 'staff',
        // Optionally filter by last active date
      }).select('_id').lean();

      console.log(`[NotificationScheduler] Sending timesheet reminders to ${users.length} staff members`);

      for (const user of users) {
        await notificationService.sendToUser(
          user._id.toString(),
          'Timesheet Reminder',
          'You have hours pending approval this week',
          {
            type: 'hours',
            action: 'timesheet_reminder',
          },
          'user',
          '10B981' // Green accent color
        );
      }

      console.log(`[NotificationScheduler] ✅ Sent ${users.length} timesheet reminders`);

    } catch (error) {
      console.error('[NotificationScheduler] sendTimesheetReminders error:', error);
    }
  }

  /**
   * Auto-enable team chat when event is FULL and within 1 hour of start
   */
  async autoEnableEventChat(): Promise<void> {
    try {
      const now = new Date();
      const oneHourFromNow = new Date(now.getTime() + 60 * 60 * 1000);
      const fiveMinutesFromNow = new Date(now.getTime() + 5 * 60 * 1000);

      console.log(`[NotificationScheduler] Checking for events to enable chat (${fiveMinutesFromNow.toISOString()} - ${oneHourFromNow.toISOString()})`);

      // Find events starting within the next hour that don't have chat enabled yet
      const events = await EventModel.find({
        date: {
          $gte: fiveMinutesFromNow,
          $lte: oneHourFromNow
        },
        status: { $in: ['confirmed', 'published'] },
        chatEnabled: { $ne: true }
      }).lean();

      console.log(`[NotificationScheduler] Found ${events.length} candidate events for chat`);

      // Enrich with staff data from EventStaff collection
      await enrichEventsWithStaff(events);

      for (const event of events) {
        try {
          // Check if event is full (all roles have enough accepted staff)
          const roles = event.roles || [];
          let isFull = true;
          let totalNeeded = 0;
          let totalAccepted = 0;

          for (const role of roles) {
            const needed = role.count || 0;
            totalNeeded += needed;

            // Count accepted staff for this role
            const acceptedStaff = event.accepted_staff || [];
            const acceptedForRole = acceptedStaff.filter((staff: any) => {
              // Staff can be a string (userKey) or object with role
              const staffRole = typeof staff === 'string' ? null : staff.role;
              // Match by role name
              return staffRole === role.role;
            }).length;

            totalAccepted += acceptedForRole;

            if (acceptedForRole < needed) {
              isFull = false;
            }
          }

          console.log(`[NotificationScheduler] Event ${event._id} (${event.event_name}): ${totalAccepted}/${totalNeeded} filled, isFull=${isFull}`);

          // Only enable chat if event is FULL and within 1 hour
          if (!isFull) {
            console.log(`[NotificationScheduler] ⏭️  Skipping ${event._id} - not full yet`);
            continue;
          }

          // Enable chat
          await EventModel.updateOne(
            { _id: event._id },
            {
              $set: {
                chatEnabled: true,
                chatEnabledAt: new Date()
              }
            }
          );

          // Post system message
          await EventChatMessageModel.create({
            eventId: event._id,
            senderId: event.managerId,
            senderType: 'manager',
            senderName: 'System',
            message: 'Team chat is now open. Your event is fully staffed and starting soon. Use this to coordinate with your team.',
            messageType: 'system',
          });

          console.log(`[NotificationScheduler] ✅ Enabled chat for FULL event ${event._id} (${event.event_name})`);
        } catch (err) {
          console.error(`[NotificationScheduler] Failed to enable chat for event ${event._id}:`, err);
        }
      }

    } catch (error) {
      console.error('[NotificationScheduler] autoEnableEventChat error:', error);
    }
  }

  /**
   * Auto-complete events that have passed (runs daily at midnight)
   */
  async autoCompleteEvents(): Promise<void> {
    try {
      const now = new Date();
      const startOfToday = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 0, 0, 0);

      console.log(`[NotificationScheduler] Checking for events to auto-complete (before ${startOfToday.toISOString()})`);

      // Find events from previous days that should be auto-completed
      const eventsToComplete = await EventModel.find({
        date: { $lt: startOfToday },
        status: { $in: ['published', 'confirmed', 'fulfilled', 'in_progress'] },
        keepOpen: { $ne: true },
      }).lean();

      console.log(`[NotificationScheduler] Found ${eventsToComplete.length} events to auto-complete`);

      for (const event of eventsToComplete) {
        try {
          // Update event status to completed
          await EventModel.updateOne(
            { _id: event._id },
            {
              $set: {
                status: 'completed',
                updatedAt: new Date(),
              }
            }
          );

          console.log(`[NotificationScheduler] ✅ Auto-completed event ${event._id} (${event.event_name || event.shift_name})`);

          // Send immediate notification to manager
          if (event.managerId) {
            try {
              emitToManager(String(event.managerId), 'event:auto-completed', {
                eventId: String(event._id),
                eventName: event.event_name || event.shift_name || 'Event',
                clientName: event.client_name || '',
                date: event.date,
                venueName: event.venue_name || '',
                timestamp: new Date().toISOString(),
              });
              console.log(`[NotificationScheduler] 📨 Sent auto-completion notification to manager ${event.managerId}`);
            } catch (notifErr) {
              console.error(`[NotificationScheduler] Failed to notify manager for event ${event._id}:`, notifErr);
            }
          }

        } catch (err) {
          console.error(`[NotificationScheduler] Failed to auto-complete event ${event._id}:`, err);
        }
      }

      console.log(`[NotificationScheduler] ✅ Auto-completed ${eventsToComplete.length} past events`);

    } catch (error) {
      console.error('[NotificationScheduler] autoCompleteEvents error:', error);
    }
  }

  /**
   * Helper: Get user ID from userKey (provider:sub format)
   */
  private async getUserIdFromKey(userKey: string): Promise<string | null> {
    try {
      const [provider, sub] = userKey.split(':');
      if (!provider || !sub) return null;

      const user = await UserModel.findOne({ provider, sub }).select('_id').lean();
      return user?._id.toString() || null;
    } catch (error) {
      console.error('[NotificationScheduler] getUserIdFromKey error:', error);
      return null;
    }
  }

  /**
   * Batch-resolve an array of userKeys to a Map<userKey, userId>.
   * Single DB query instead of N sequential findOne calls.
   */
  private async batchResolveUserIds(userKeys: string[]): Promise<Map<string, string>> {
    const result = new Map<string, string>();
    if (userKeys.length === 0) return result;

    const orClauses: { provider: string; sub: string }[] = [];
    for (const uk of userKeys) {
      const sepIdx = uk.indexOf(':');
      if (sepIdx < 1) continue;
      orClauses.push({ provider: uk.substring(0, sepIdx), sub: uk.substring(sepIdx + 1) });
    }

    if (orClauses.length === 0) return result;

    try {
      const users = await UserModel.find(
        { $or: orClauses },
        { _id: 1, provider: 1, sub: 1 }
      ).lean();
      for (const u of users) {
        result.set(`${(u as any).provider}:${(u as any).sub}`, u._id.toString());
      }
    } catch (error) {
      console.error('[NotificationScheduler] batchResolveUserIds error:', error);
    }
    return result;
  }

  /**
   * Stop all scheduled tasks (for graceful shutdown)
   */
  shutdown() {
    console.log('[NotificationScheduler] Stopping scheduled tasks...');
    this.tasks.forEach(task => task.stop());
    this.tasks = [];
    console.log('[NotificationScheduler] ✅ All tasks stopped');
  }
}

// Export singleton instance
export const notificationScheduler = new NotificationScheduler();
