import * as cron from 'node-cron';
import { EventModel } from '../models/event';
import { UserModel } from '../models/user';
import { notificationService } from './notificationService';

class NotificationScheduler {
  private tasks: cron.ScheduledTask[] = [];

  /**
   * Initialize all scheduled notification tasks
   */
  initialize() {
    console.log('[NotificationScheduler] Initializing scheduled tasks...');

    // Run every 5 minutes to check for upcoming shifts
    this.tasks.push(
      cron.schedule('*/5 * * * *', () => {
        this.checkUpcomingShifts().catch(err => {
          console.error('[NotificationScheduler] Upcoming shifts check failed:', err);
        });
      })
    );

    // Run every 15 minutes to check for forgotten clock-outs
    this.tasks.push(
      cron.schedule('*/15 * * * *', () => {
        this.checkForgottenClockOuts().catch(err => {
          console.error('[NotificationScheduler] Forgotten clock-outs check failed:', err);
        });
      })
    );

    // Run daily at 9 AM to send timesheet reminders
    this.tasks.push(
      cron.schedule('0 9 * * *', () => {
        this.sendTimesheetReminders().catch(err => {
          console.error('[NotificationScheduler] Timesheet reminders failed:', err);
        });
      })
    );

    console.log('[NotificationScheduler] ✅ Initialized 3 scheduled tasks');
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

      for (const event of upcomingEvents) {
        const acceptedStaff = event.accepted_staff || [];

        for (const staff of acceptedStaff) {
          const userKey = staff.userKey as string;
          if (!userKey) continue;

          // Extract user ID from userKey (format: "provider:sub")
          const userId = await this.getUserIdFromKey(userKey);
          if (!userId) continue;

          // Calculate time until shift
          const eventDate = event.date ? new Date(event.date) : null;
          if (!eventDate) continue;

          const timeUntilShift = Math.round((eventDate.getTime() - now.getTime()) / (60 * 1000));
          const timeText = timeUntilShift > 60
            ? `${Math.round(timeUntilShift / 60)}h ${timeUntilShift % 60}m`
            : `${timeUntilShift}m`;

          // Send notification
          await notificationService.sendToUser(
            userId,
            '🔔 Shift Starting Soon!',
            `Your shift at ${event.venue_name || 'venue'} starts in ${timeText}`,
            {
              type: 'event',
              eventId: event._id.toString(),
              action: 'shift_reminder',
              eventName: event.event_name || 'Shift',
              venueName: event.venue_name || '',
              startTime: eventDate.toISOString(),
            },
            'user',
            '6366F1' // Indigo accent color
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

        const acceptedStaff = event.accepted_staff || [];
        let sentNotificationCount = 0;

        for (const staff of acceptedStaff) {
          const userKey = staff.userKey as string;
          if (!userKey) continue;

          // Check if staff clocked in but never clocked out
          const attendance = staff.attendance as any[] || [];
          const lastAttendance = attendance.length > 0 ? attendance[attendance.length - 1] : null;

          if (lastAttendance && lastAttendance.clockInAt && !lastAttendance.clockOutAt) {
            // Staff forgot to clock out!
            const userId = await this.getUserIdFromKey(userKey);
            if (!userId) continue;

            const hoursSinceEnd = Math.round((now.getTime() - endDateTime.getTime()) / (60 * 60 * 1000));

            await notificationService.sendToUser(
              userId,
              '⏰ Forgot to Clock Out?',
              `Your shift at ${event.venue_name || 'venue'} ended ${hoursSinceEnd}h ago. Don't forget to clock out!`,
              {
                type: 'event',
                eventId: event._id.toString(),
                action: 'forgot_clock_out',
                eventName: event.event_name || 'Shift',
                venueName: event.venue_name || '',
                endTime: endDateTime.toISOString(),
              },
              'user',
              'F59E0B' // Amber/warning color
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
          '📋 Weekly Timesheet Reminder',
          'Don\'t forget to review and approve your timesheet for this week!',
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
