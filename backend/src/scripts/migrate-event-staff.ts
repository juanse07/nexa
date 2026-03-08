/**
 * Migration script: Backfill EventStaff collection from embedded accepted_staff/declined_staff arrays.
 *
 * This script reads all events and creates corresponding EventStaff documents.
 * It uses bulkWrite with upsert so it is safe to re-run (idempotent).
 *
 * LOCAL USAGE:
 *   npx ts-node src/scripts/migrate-event-staff.ts
 *
 * PRODUCTION USAGE:
 *   ssh app@198.58.111.243
 *   cd /srv/app && docker exec -it nexa-api node dist/scripts/migrate-event-staff.js
 *
 * This script does NOT modify Event documents — it only populates the EventStaff collection.
 */

import mongoose from 'mongoose';
import { config } from 'dotenv';
import { EventModel } from '../models/event';
import { EventStaffModel } from '../models/eventStaff';
import { connectToDatabase } from '../db/mongoose';

config();

const BATCH_SIZE = 100;

async function migrateEventStaff() {
  try {
    await connectToDatabase();

    // Count events with staff data
    const totalEvents = await EventModel.countDocuments({
      $or: [
        { 'accepted_staff.0': { $exists: true } },
        { 'declined_staff.0': { $exists: true } },
      ],
    });
    console.log(`Found ${totalEvents} events with staff data to migrate`);

    let processed = 0;
    let totalStaffDocs = 0;
    let cursor = EventModel.find(
      {
        $or: [
          { 'accepted_staff.0': { $exists: true } },
          { 'declined_staff.0': { $exists: true } },
        ],
      },
      { _id: 1, managerId: 1, accepted_staff: 1, declined_staff: 1 }
    )
      .lean()
      .batchSize(BATCH_SIZE)
      .cursor();

    let batch: any[] = [];

    for await (const event of cursor) {
      batch.push(event);

      if (batch.length >= BATCH_SIZE) {
        const count = await processBatch(batch);
        totalStaffDocs += count;
        processed += batch.length;
        console.log(`Processed ${processed}/${totalEvents} events (${totalStaffDocs} staff docs upserted)`);
        batch = [];
      }
    }

    // Process remaining batch
    if (batch.length > 0) {
      const count = await processBatch(batch);
      totalStaffDocs += count;
      processed += batch.length;
      console.log(`Processed ${processed}/${totalEvents} events (${totalStaffDocs} staff docs upserted)`);
    }

    // Verify counts
    const eventStaffCount = await EventStaffModel.countDocuments({});
    const embeddedCount = await EventModel.aggregate([
      {
        $project: {
          count: {
            $add: [
              { $size: { $ifNull: ['$accepted_staff', []] } },
              { $size: { $ifNull: ['$declined_staff', []] } },
            ],
          },
        },
      },
      { $group: { _id: null, total: { $sum: '$count' } } },
    ]);
    const embeddedTotal = embeddedCount[0]?.total || 0;

    console.log('\n=== Migration Complete ===');
    console.log(`Events processed: ${processed}`);
    console.log(`EventStaff documents: ${eventStaffCount}`);
    console.log(`Embedded staff total: ${embeddedTotal}`);
    if (eventStaffCount === embeddedTotal) {
      console.log('MATCH: Counts are equal');
    } else {
      console.log(`MISMATCH: Difference of ${Math.abs(eventStaffCount - embeddedTotal)} (may be due to duplicate userKeys in same event)`);
    }
  } catch (err) {
    console.error('Migration failed:', err);
    process.exit(1);
  } finally {
    await mongoose.disconnect();
    console.log('Disconnected from MongoDB');
  }
}

async function processBatch(events: any[]): Promise<number> {
  const ops: any[] = [];

  for (const event of events) {
    const eventId = event._id;
    const managerId = event.managerId;

    // Process accepted_staff
    for (const staff of event.accepted_staff || []) {
      if (!staff.userKey) continue;
      ops.push({
        updateOne: {
          filter: { eventId, userKey: staff.userKey },
          update: {
            $set: {
              managerId,
              provider: staff.provider,
              subject: staff.subject,
              email: staff.email,
              name: staff.name,
              first_name: staff.first_name,
              last_name: staff.last_name,
              picture: staff.picture,
              response: 'accept',
              role: staff.role,
              respondedAt: staff.respondedAt || null,
            },
          },
          upsert: true,
        },
      });
    }

    // Process declined_staff
    for (const staff of event.declined_staff || []) {
      if (!staff.userKey) continue;
      ops.push({
        updateOne: {
          filter: { eventId, userKey: staff.userKey },
          update: {
            $set: {
              managerId,
              provider: staff.provider,
              subject: staff.subject,
              email: staff.email,
              name: staff.name,
              first_name: staff.first_name,
              last_name: staff.last_name,
              picture: staff.picture,
              response: 'decline',
              role: staff.role,
              respondedAt: staff.respondedAt || null,
            },
          },
          upsert: true,
        },
      });
    }
  }

  if (ops.length === 0) return 0;

  const result = await EventStaffModel.bulkWrite(ops, { ordered: false });
  return result.upsertedCount + result.modifiedCount;
}

migrateEventStaff();
