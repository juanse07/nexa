/**
 * Auto Clock-Out Background Job
 *
 * This job runs periodically to automatically clock out staff members
 * who forgot to clock out after their shift ended.
 *
 * Logic:
 * 1. Find all events with end_time that have passed (+ buffer)
 * 2. Find staff who are still clocked in (have clockInAt but no clockOutAt)
 * 3. Auto clock them out with reason 'shift_end_buffer'
 * 4. Send notification to the staff member
 */

import mongoose from 'mongoose';
import { EventModel } from '../models/event';
import { ManagerModel } from '../models/manager';
import { UserModel } from '../models/user';
import { notificationService } from '../services/notificationService';

// Default buffer after shift end time before auto clock-out (in minutes)
const DEFAULT_AUTO_CLOCK_OUT_BUFFER_MINUTES = 15;

interface AutoClockOutResult {
  eventId: string;
  eventName: string;
  userKey: string;
  staffName: string;
  clockInAt: Date;
  clockOutAt: Date;
  hoursWorked: number;
}

/**
 * Parse event end time from date and end_time fields
 * Returns undefined if end_time is not set or invalid
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
 * Process auto clock-outs for a single event
 */
async function processEventAutoClockOut(
  event: any,
  bufferMinutes: number
): Promise<AutoClockOutResult[]> {
  const results: AutoClockOutResult[] = [];
  const now = new Date();

  // Parse end time and check if buffer has passed
  const eventEndTime = parseEventEndTime(event);
  if (!eventEndTime) return results;

  const autoClockOutTime = new Date(eventEndTime.getTime() + bufferMinutes * 60 * 1000);
  if (now < autoClockOutTime) return results;

  // Find staff who are still clocked in
  const acceptedStaff = event.accepted_staff || [];
  const staffToClockOut: Array<{ idx: number; staff: any; lastAttendance: any }> = [];

  for (let i = 0; i < acceptedStaff.length; i++) {
    const staff = acceptedStaff[i];
    const attendance = staff.attendance || [];
    const lastAttendance = attendance.length > 0 ? attendance[attendance.length - 1] : null;

    // Check if clocked in but not clocked out
    if (lastAttendance && lastAttendance.clockInAt && !lastAttendance.clockOutAt) {
      staffToClockOut.push({ idx: i, staff, lastAttendance });
    }
  }

  if (staffToClockOut.length === 0) return results;

  // Process each staff member
  for (const { idx, staff, lastAttendance } of staffToClockOut) {
    const clockOutTime = now;
    const clockInTime = new Date(lastAttendance.clockInAt);
    const hoursWorked = (clockOutTime.getTime() - clockInTime.getTime()) / (1000 * 60 * 60);

    // Build updated attendance record
    const updatedAttendance = {
      ...lastAttendance,
      clockOutAt: clockOutTime,
      autoClockOut: true,
      autoClockOutReason: 'shift_end_buffer' as const,
      estimatedHours: Math.round(hoursWorked * 100) / 100,
    };

    // Update the attendance array
    const newAttendanceArray = [...(staff.attendance || [])];
    newAttendanceArray[newAttendanceArray.length - 1] = updatedAttendance;

    // Perform atomic update
    await EventModel.updateOne(
      {
        _id: event._id,
        [`accepted_staff.${idx}.attendance`]: { $exists: true },
      },
      {
        $set: {
          [`accepted_staff.${idx}.attendance`]: newAttendanceArray,
          updatedAt: new Date(),
        },
      }
    );

    results.push({
      eventId: String(event._id),
      eventName: event.event_name || event.shift_name || 'Unknown Event',
      userKey: staff.userKey,
      staffName: staff.name || `${staff.first_name || ''} ${staff.last_name || ''}`.trim() || 'Unknown',
      clockInAt: clockInTime,
      clockOutAt: clockOutTime,
      hoursWorked: Math.round(hoursWorked * 100) / 100,
    });
  }

  return results;
}

/**
 * Send notification to staff member about auto clock-out
 */
async function notifyAutoClockOut(result: AutoClockOutResult): Promise<void> {
  const [provider, subject] = result.userKey.split(':');
  if (!provider || !subject) return;

  const user = await UserModel.findOne({ provider, subject }).lean();
  if (!user) return;

  try {
    await notificationService.sendToUser(
      String(user._id),
      '🔴 Auto Clock-Out',
      `You were automatically clocked out from "${result.eventName}" after ${result.hoursWorked.toFixed(1)} hours. The shift ended and you forgot to clock out.`,
      {
        type: 'event',
        eventId: result.eventId,
        action: 'auto_clock_out',
        hoursWorked: result.hoursWorked,
      },
      'user'
    );
  } catch (err) {
    console.error(`[auto-clock-out] Failed to notify ${result.userKey}:`, err);
  }
}

/**
 * Main job function - process all events for auto clock-out
 *
 * This should be called on a schedule (e.g., every 5 minutes)
 */
export async function processAutoClockOuts(): Promise<{
  processed: number;
  errors: number;
  results: AutoClockOutResult[];
}> {
  const allResults: AutoClockOutResult[] = [];
  let errorCount = 0;

  try {
    // Find all events that are in progress or confirmed
    // and have an end_time set
    const events = await EventModel.find({
      status: { $in: ['published', 'confirmed', 'in_progress'] },
      end_time: { $exists: true, $ne: null },
      'accepted_staff.attendance': { $exists: true },
    }).lean();

    console.log(`[auto-clock-out] Checking ${events.length} events for auto clock-out`);

    for (const event of events) {
      try {
        // Get manager's configured buffer time
        const manager = await ManagerModel.findById(event.managerId).lean();
        const bufferMinutes =
          (manager as any)?.clockInConfig?.autoClockOutBufferMinutes ??
          DEFAULT_AUTO_CLOCK_OUT_BUFFER_MINUTES;

        const results = await processEventAutoClockOut(event, bufferMinutes);

        // Send notifications for each auto clock-out
        for (const result of results) {
          await notifyAutoClockOut(result);
          allResults.push(result);
        }
      } catch (err) {
        console.error(`[auto-clock-out] Error processing event ${event._id}:`, err);
        errorCount++;
      }
    }

    if (allResults.length > 0) {
      console.log(`[auto-clock-out] Processed ${allResults.length} auto clock-outs`);
    }

    return {
      processed: allResults.length,
      errors: errorCount,
      results: allResults,
    };
  } catch (err) {
    console.error('[auto-clock-out] Job failed:', err);
    throw err;
  }
}

/**
 * Initialize the auto clock-out job with node-cron
 * Call this from your server.ts or index.ts
 */
export function initAutoClockOutJob(cron: typeof import('node-cron')): void {
  // Run every 5 minutes
  cron.schedule('*/5 * * * *', async () => {
    console.log('[auto-clock-out] Running scheduled job...');
    try {
      const result = await processAutoClockOuts();
      if (result.processed > 0) {
        console.log(`[auto-clock-out] Completed: ${result.processed} staff auto-clocked out`);
      }
    } catch (err) {
      console.error('[auto-clock-out] Scheduled job error:', err);
    }
  });

  console.log('[auto-clock-out] Job scheduled to run every 5 minutes');
}
