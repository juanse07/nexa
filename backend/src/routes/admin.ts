import express from 'express';
import { EventModel } from '../models/event';

const router = express.Router();

/**
 * Admin endpoint to standardize all event dates to Date objects
 * POST /api/admin/standardize-dates
 */
router.post('/admin/standardize-dates', async (req, res) => {
  try {
    console.log('[Admin] Starting date standardization...');

    // Find all events
    const allEvents = await EventModel.find({}).lean();
    console.log(`[Admin] Found ${allEvents.length} total events`);

    let stringDateCount = 0;
    let dateObjectCount = 0;
    let nullDateCount = 0;
    let convertedCount = 0;

    // Analyze current state
    for (const event of allEvents) {
      if (event.date == null) {
        nullDateCount++;
      } else if (typeof event.date === 'string') {
        stringDateCount++;
      } else if (event.date instanceof Date) {
        dateObjectCount++;
      }
    }

    console.log('[Admin] Current State:');
    console.log(`  String dates: ${stringDateCount}`);
    console.log(`  Date objects: ${dateObjectCount}`);
    console.log(`  Null/undefined: ${nullDateCount}`);

    if (stringDateCount === 0) {
      return res.json({
        success: true,
        message: 'All dates are already standardized as Date objects',
        stats: { stringDates: 0, dateObjects: dateObjectCount, null: nullDateCount, converted: 0 }
      });
    }

    // Convert all string dates to Date objects
    for (const event of allEvents) {
      if (event.date != null && typeof event.date === 'string') {
        try {
          // Convert string to Date object
          const dateObj = new Date(event.date as string);

          // Validate the date is valid
          if (isNaN(dateObj.getTime())) {
            console.log(`[Admin] Skipping invalid date for event ${event._id}: ${event.date}`);
            continue;
          }

          // Update the event
          await EventModel.updateOne(
            { _id: event._id },
            { $set: { date: dateObj } }
          );

          convertedCount++;

          if (convertedCount % 10 === 0) {
            console.log(`[Admin] Converted ${convertedCount}/${stringDateCount} dates...`);
          }
        } catch (err: any) {
          console.error(`[Admin] Error converting date for event ${event._id}:`, err.message);
        }
      }
    }

    console.log(`[Admin] Conversion complete!`);
    console.log(`  Successfully converted: ${convertedCount} dates`);
    console.log(`  Failed: ${stringDateCount - convertedCount} dates`);

    // Verify the fix
    const updatedEvents = await EventModel.find({}).lean();
    let finalStringCount = 0;
    let finalDateObjectCount = 0;
    let finalNullCount = 0;

    for (const event of updatedEvents) {
      if (event.date == null) {
        finalNullCount++;
      } else if (typeof event.date === 'string') {
        finalStringCount++;
      } else if (event.date instanceof Date) {
        finalDateObjectCount++;
      }
    }

    return res.json({
      success: true,
      message: `Successfully converted ${convertedCount} dates`,
      before: { stringDates: stringDateCount, dateObjects: dateObjectCount, null: nullDateCount },
      after: { stringDates: finalStringCount, dateObjects: finalDateObjectCount, null: finalNullCount },
      converted: convertedCount
    });

  } catch (error: any) {
    console.error('[Admin] Error:', error);
    return res.status(500).json({
      success: false,
      message: `Failed to standardize dates: ${error.message}`
    });
  }
});

export default router;
