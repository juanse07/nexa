/**
 * Script to migrate existing events to the new status-based architecture
 *
 * LOCAL USAGE:
 *   npx ts-node src/scripts/migrate-event-status.ts
 *
 * PRODUCTION USAGE (on server):
 *   1. SSH into your server
 *   2. Navigate to your backend directory
 *   3. Run: npx ts-node src/scripts/migrate-event-status.ts
 *
 * This script will:
 * - Find all events without a status field
 * - Set their status to 'published' (assuming they were already visible to staff)
 * - Mark events in the past as 'completed' based on their date
 * - Report how many events were migrated
 */

import mongoose from 'mongoose';
import { config } from 'dotenv';
import { EventModel } from '../models/event';

config();

async function migrateEventStatus() {
  try {
    // Connect to MongoDB
    const mongoUri = process.env.MONGODB_URI || 'mongodb://127.0.0.1:27017/nexa';
    await mongoose.connect(mongoUri);
    console.log('Connected to MongoDB');

    // Find all events without a status field
    const events = await EventModel.find({
      $or: [
        { status: { $exists: false } },
        { status: null }
      ]
    }).lean();

    console.log(`Found ${events.length} events without status`);

    let publishedCount = 0;
    let completedCount = 0;
    let errorCount = 0;

    const now = new Date();

    for (const event of events) {
      try {
        console.log(`\nEvent ${event._id}:`);
        console.log(`  Name: ${event.event_name || '(unnamed)'}`);
        console.log(`  Date: ${event.date ? new Date(event.date).toISOString() : '(no date)'}`);

        let newStatus: 'published' | 'completed' = 'published';

        // If the event is in the past, mark it as completed
        if (event.date) {
          const eventDate = new Date(event.date);
          if (eventDate < now) {
            newStatus = 'completed';
            completedCount++;
            console.log(`  → Setting status to: completed (past event)`);
          } else {
            publishedCount++;
            console.log(`  → Setting status to: published (future event)`);
          }
        } else {
          // No date, assume published
          publishedCount++;
          console.log(`  → Setting status to: published (no date)`);
        }

        await EventModel.updateOne(
          { _id: event._id },
          {
            $set: {
              status: newStatus,
              // Set publishedAt to createdAt if available, otherwise now
              publishedAt: event.createdAt || now
            }
          }
        );

        console.log(`  ✓ Migrated!`);
      } catch (error) {
        console.error(`  ✗ Error migrating event ${event._id}:`, error);
        errorCount++;
      }
    }

    console.log(`\n=== Summary ===`);
    console.log(`Total events migrated: ${events.length}`);
    console.log(`Set to 'published': ${publishedCount}`);
    console.log(`Set to 'completed': ${completedCount}`);
    console.log(`Errors: ${errorCount}`);

    await mongoose.disconnect();
    console.log('\nDisconnected from MongoDB');
  } catch (error) {
    console.error('Error:', error);
    process.exit(1);
  }
}

migrateEventStatus();
