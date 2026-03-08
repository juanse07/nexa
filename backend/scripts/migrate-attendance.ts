/**
 * Migration script: Extract nested attendance data from Event.accepted_staff[].attendance[]
 * into the new AttendanceLog collection.
 *
 * Usage:
 *   NODE_ENV=production ts-node --transpile-only scripts/migrate-attendance.ts
 *
 * Features:
 * - Idempotent: uses upsert with (eventId + userKey + clockInAt) as unique key
 * - Batched: processes in bulkWrite batches of 500 for memory efficiency
 * - Non-destructive: does NOT remove nested attendance data from events
 * - Progress logging: prints progress every 100 events
 */

import mongoose from 'mongoose';
import { config } from 'dotenv';
config();

// Minimal inline connection (avoids importing app code)
const MONGO_URI = process.env.MONGO_URI || '';
const DB_NAME = process.env.NODE_ENV === 'production' ? 'nexa_prod' : 'nexa_test';

async function run() {
  if (!MONGO_URI) {
    console.error('MONGO_URI is required');
    process.exit(1);
  }

  // Build URI with DB name
  let uri = MONGO_URI.trim().replace(/\/$/, '');
  const protoMatch = uri.match(/^mongodb(\+srv)?:\/\//);
  if (!protoMatch) throw new Error('Invalid MONGO_URI');

  const afterProto = uri.substring(protoMatch[0].length);
  const qIdx = afterProto.indexOf('?');
  let base: string, qs = '';
  if (qIdx !== -1) {
    const before = afterProto.substring(0, qIdx);
    qs = afterProto.substring(qIdx);
    const slashIdx = before.lastIndexOf('/');
    base = slashIdx !== -1 ? protoMatch[0] + before.substring(0, slashIdx) : protoMatch[0] + before;
  } else {
    const slashIdx = afterProto.lastIndexOf('/');
    base = slashIdx !== -1 ? protoMatch[0] + afterProto.substring(0, slashIdx) : uri;
  }

  const finalUri = `${base}/${DB_NAME}${qs}`;
  console.log(`[Migration] Connecting to ${DB_NAME}...`);
  await mongoose.connect(finalUri);
  console.log('[Migration] Connected');

  const db = mongoose.connection.db!;
  const eventsCol = db.collection('events');
  const attendanceCol = db.collection('attendancelogs');

  // Create unique index for idempotent upserts
  await attendanceCol.createIndex(
    { eventId: 1, userKey: 1, clockInAt: 1 },
    { unique: true, name: 'migration_upsert_key' }
  );

  // Find events that have attendance data
  const cursor = eventsCol.find(
    { 'accepted_staff.attendance.0': { $exists: true } },
    { projection: { _id: 1, managerId: 1, accepted_staff: 1 } }
  );

  let eventCount = 0;
  let totalSessions = 0;
  let upsertedCount = 0;
  let skippedCount = 0;
  const BATCH_SIZE = 500;
  let batch: any[] = [];

  for await (const event of cursor) {
    eventCount++;
    const managerId = event.managerId;
    const acceptedStaff: any[] = event.accepted_staff || [];

    for (const staff of acceptedStaff) {
      const userKey = staff.userKey;
      if (!userKey) continue;

      const sessions: any[] = staff.attendance || [];
      for (const session of sessions) {
        if (!session.clockInAt) continue;

        totalSessions++;
        batch.push({
          updateOne: {
            filter: {
              eventId: event._id,
              userKey,
              clockInAt: new Date(session.clockInAt),
            },
            update: {
              $setOnInsert: {
                eventId: event._id,
                managerId,
                userKey,
                clockInAt: new Date(session.clockInAt),
              },
              $set: {
                ...(session.clockOutAt && { clockOutAt: new Date(session.clockOutAt) }),
                ...(session.estimatedHours != null && { estimatedHours: session.estimatedHours }),
                ...(session.clockInLocation && { clockInLocation: session.clockInLocation }),
                ...(session.clockOutLocation && { clockOutLocation: session.clockOutLocation }),
                ...(session.autoClockOut != null && { autoClockOut: session.autoClockOut }),
                ...(session.autoClockOutReason && { autoClockOutReason: session.autoClockOutReason }),
                ...(session.overrideBy && { overrideBy: session.overrideBy }),
                ...(session.overrideNote && { overrideNote: session.overrideNote }),
                ...(session.sheetSignInTime && { sheetSignInTime: new Date(session.sheetSignInTime) }),
                ...(session.sheetSignOutTime && { sheetSignOutTime: new Date(session.sheetSignOutTime) }),
                ...(session.approvedHours != null && { approvedHours: session.approvedHours }),
                status: session.status || 'clocked',
                ...(session.approvedBy && { approvedBy: session.approvedBy }),
                ...(session.approvedAt && { approvedAt: new Date(session.approvedAt) }),
                ...(session.managerNotes && { managerNotes: session.managerNotes }),
                ...(session.discrepancyNote && { discrepancyNote: session.discrepancyNote }),
              },
            },
            upsert: true,
          },
        });

        if (batch.length >= BATCH_SIZE) {
          const result = await attendanceCol.bulkWrite(batch, { ordered: false });
          upsertedCount += result.upsertedCount;
          skippedCount += result.matchedCount;
          batch = [];
        }
      }
    }

    if (eventCount % 100 === 0) {
      console.log(`[Migration] Processed ${eventCount} events, ${totalSessions} sessions so far...`);
    }
  }

  // Flush remaining batch
  if (batch.length > 0) {
    const result = await attendanceCol.bulkWrite(batch, { ordered: false });
    upsertedCount += result.upsertedCount;
    skippedCount += result.matchedCount;
  }

  console.log('\n[Migration] Complete!');
  console.log(`  Events processed:    ${eventCount}`);
  console.log(`  Sessions found:      ${totalSessions}`);
  console.log(`  New records created: ${upsertedCount}`);
  console.log(`  Already existed:     ${skippedCount}`);

  await mongoose.disconnect();
  process.exit(0);
}

run().catch((err) => {
  console.error('[Migration] Fatal error:', err);
  process.exit(1);
});
