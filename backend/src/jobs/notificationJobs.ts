/**
 * Notification Jobs for Clock-In System
 *
 * Handles:
 * 1. Pre-shift reminders (e.g., 30 minutes before shift)
 * 2. Clock-in success notifications
 * 3. Forgot to clock-out reminders
 */

import mongoose from 'mongoose';
import { EventModel } from '../models/event';
import { UserModel } from '../models/user';
import { notificationService } from '../services/notificationService';

// Default reminder time before shift (in minutes)
const DEFAULT_PRE_SHIFT_REMINDER_MINUTES = 30;

/**
 * Parse event start time from date and start_time fields
 */
function parseEventStartTime(event: any): Date | undefined {
  if (!event.date || !event.start_time) return undefined;

  try {
    const eventDate = new Date(event.date);
    const [hours, minutes] = event.start_time.split(':').map(Number);

    if (isNaN(hours) || isNaN(minutes)) return undefined;

    eventDate.setHours(hours, minutes, 0, 0);
    return eventDate;
  } catch {
    return undefined;
  }
}

/**
 * Parse event end time from date and end_time fields
 */
function parseEventEndTime(event: any): Date | undefined {
  if (!event.date || !event.end_time) return undefined;

  try {
    const eventDate = new Date(event.date);
    const [hours, minutes] = event.end_time.split(':').map(Number);

    if (isNaN(hours) || isNaN(minutes)) return undefined;

    eventDate.setHours(hours, minutes, 0, 0);
    return eventDate;
  } catch {
    return undefined;
  }
}

/**
 * Send pre-shift reminder notifications
 *
 * Finds events starting in ~30 minutes (or configured time)
 * and sends reminders to accepted staff who haven't been notified yet.
 */
export async function sendPreShiftReminders(): Promise<{
  notificationsSent: number;
  errors: number;
}> {
  let notificationsSent = 0;
  let errorCount = 0;
  const now = new Date();

  try {
    // Find all upcoming events that haven't sent pre-shift reminders
    const events = await EventModel.find({
      status: { $in: ['published', 'confirmed'] },
      start_time: { $exists: true, $ne: null },
      date: { $gte: new Date(now.toDateString()) }, // Today or future
      'notificationsSent.preShiftReminder': { $ne: true },
    }).lean();

    for (const event of events) {
      const eventStart = parseEventStartTime(event);
      if (!eventStart) continue;

      // Check if event starts soon (within reminder window)
      const acceptedStaff = event.accepted_staff || [];

      for (const staff of acceptedStaff) {
        if (!staff.userKey) continue;

        const [provider, subject] = staff.userKey.split(':');
        if (!provider || !subject) continue;

        // Get user's configured reminder time
        const user = await UserModel.findOne({ provider, subject }).lean();
        if (!user) continue;

        const reminderMinutes =
          user.clockInSettings?.preShiftReminderMinutes ?? DEFAULT_PRE_SHIFT_REMINDER_MINUTES;

        // Calculate reminder time
        const reminderTime = new Date(eventStart.getTime() - reminderMinutes * 60 * 1000);

        // Check if we're in the reminder window (now is after reminder time, but before event start)
        if (now >= reminderTime && now < eventStart) {
          try {
            const eventName = event.event_name || event.shift_name || 'Your shift';
            const minutesUntilStart = Math.round((eventStart.getTime() - now.getTime()) / (60 * 1000));

            await notificationService.sendToUser(
              String(user._id),
              '⏰ Shift Starting Soon',
              `${eventName} starts in ${minutesUntilStart} minutes. Don't forget to clock in!`,
              {
                type: 'event',
                eventId: String(event._id),
                action: 'pre_shift_reminder',
              },
              'user'
            );
            notificationsSent++;
          } catch (err) {
            console.error(`[pre-shift-reminder] Failed to notify ${staff.userKey}:`, err);
            errorCount++;
          }
        }
      }

      // Mark event as notified (only if any staff was in the reminder window)
      if (notificationsSent > 0) {
        await EventModel.updateOne(
          { _id: event._id },
          { $set: { 'notificationsSent.preShiftReminder': true } }
        );
      }
    }

    if (notificationsSent > 0) {
      console.log(`[pre-shift-reminder] Sent ${notificationsSent} reminders`);
    }

    return { notificationsSent, errors: errorCount };
  } catch (err) {
    console.error('[pre-shift-reminder] Job failed:', err);
    throw err;
  }
}

/**
 * Send "forgot to clock out" reminders
 *
 * Finds staff who have been clocked in for longer than expected
 * and haven't been reminded yet.
 */
export async function sendForgotClockOutReminders(): Promise<{
  notificationsSent: number;
  errors: number;
}> {
  let notificationsSent = 0;
  let errorCount = 0;
  const now = new Date();

  try {
    // Find events that have ended
    const events = await EventModel.find({
      status: { $in: ['published', 'confirmed', 'in_progress'] },
      end_time: { $exists: true, $ne: null },
      'notificationsSent.forgotClockOut': { $ne: true },
      'accepted_staff.attendance': { $exists: true },
    }).lean();

    for (const event of events) {
      const eventEnd = parseEventEndTime(event);
      if (!eventEnd) continue;

      // Check if event has ended
      if (now <= eventEnd) continue;

      const acceptedStaff = event.accepted_staff || [];
      let sentForThisEvent = false;

      for (const staff of acceptedStaff) {
        if (!staff.userKey) continue;

        const attendance = staff.attendance || [];
        const lastAttendance = attendance.length > 0 ? attendance[attendance.length - 1] : null;

        // Check if still clocked in
        if (!lastAttendance || !lastAttendance.clockInAt || lastAttendance.clockOutAt) {
          continue;
        }

        const [provider, subject] = staff.userKey.split(':');
        if (!provider || !subject) continue;

        const user = await UserModel.findOne({ provider, subject }).lean();
        if (!user) continue;

        // Only remind once, 30 minutes after event end
        const reminderTime = new Date(eventEnd.getTime() + 30 * 60 * 1000);
        if (now < reminderTime) continue;

        try {
          const eventName = event.event_name || event.shift_name || 'Your shift';

          await notificationService.sendToUser(
            String(user._id),
            '⚠️ Forgot to Clock Out?',
            `It looks like you're still clocked in to "${eventName}". Did you forget to clock out?`,
            {
              type: 'event',
              eventId: String(event._id),
              action: 'forgot_clock_out_reminder',
            },
            'user'
          );
          notificationsSent++;
          sentForThisEvent = true;
        } catch (err) {
          console.error(`[forgot-clock-out] Failed to notify ${staff.userKey}:`, err);
          errorCount++;
        }
      }

      // Mark event as notified
      if (sentForThisEvent) {
        await EventModel.updateOne(
          { _id: event._id },
          { $set: { 'notificationsSent.forgotClockOut': true } }
        );
      }
    }

    if (notificationsSent > 0) {
      console.log(`[forgot-clock-out] Sent ${notificationsSent} reminders`);
    }

    return { notificationsSent, errors: errorCount };
  } catch (err) {
    console.error('[forgot-clock-out] Job failed:', err);
    throw err;
  }
}

/**
 * Send clock-in success notification
 *
 * Called directly from the clock-in endpoint, not as a scheduled job.
 */
export async function notifyClockInSuccess(
  userKey: string,
  event: any,
  pointsEarned?: number,
  newStreak?: number
): Promise<void> {
  const [provider, subject] = userKey.split(':');
  if (!provider || !subject) return;

  const user = await UserModel.findOne({ provider, subject }).lean();
  if (!user) return;

  try {
    const eventName = event.event_name || event.shift_name || 'your shift';
    let message = `You've clocked in to "${eventName}".`;

    if (pointsEarned && pointsEarned > 0) {
      message += ` +${pointsEarned} points!`;
    }
    if (newStreak && newStreak > 1) {
      message += ` 🔥 ${newStreak} day streak!`;
    }

    await notificationService.sendToUser(
      String(user._id),
      '✅ Clocked In',
      message,
      {
        type: 'event',
        eventId: String(event._id),
        action: 'clock_in_success',
        pointsEarned,
        newStreak,
      },
      'user'
    );
  } catch (err) {
    console.error(`[clock-in-notification] Failed to notify ${userKey}:`, err);
  }
}

/**
 * Initialize notification jobs with node-cron
 */
export function initNotificationJobs(cron: typeof import('node-cron')): void {
  // Pre-shift reminders: Run every 5 minutes
  cron.schedule('*/5 * * * *', async () => {
    try {
      await sendPreShiftReminders();
    } catch (err) {
      console.error('[notification-jobs] Pre-shift reminder job error:', err);
    }
  });

  // Forgot clock-out reminders: Run every 15 minutes
  cron.schedule('*/15 * * * *', async () => {
    try {
      await sendForgotClockOutReminders();
    } catch (err) {
      console.error('[notification-jobs] Forgot clock-out job error:', err);
    }
  });

  console.log('[notification-jobs] Jobs scheduled (pre-shift: 5min, forgot-clock-out: 15min)');
}
