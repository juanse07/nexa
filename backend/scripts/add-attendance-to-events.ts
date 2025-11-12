import mongoose from 'mongoose';

// Script to add attendance data to existing test events so they show in earnings
// Run with: docker exec nexa-api node dist/scripts/add-attendance-to-events.js

async function main() {
  const MONGO_URI = process.env.MONGO_URI;
  if (!MONGO_URI) {
    console.error('❌ MONGO_URI environment variable not found');
    process.exit(1);
  }

  console.log('🔌 Connecting to MongoDB...');
  await mongoose.connect(MONGO_URI);
  console.log('✅ Connected!\n');

  const db = mongoose.connection.db!;
  const shiftsCollection = db.collection('shifts');

  const userKey = 'google:112603799149919213350';
  console.log(`📝 Adding attendance data for user: ${userKey}\n`);

  // Find all events where user is in accepted_staff but has no attendance
  const eventsNeedingAttendance = await shiftsCollection.find({
    'accepted_staff.userKey': userKey,
  }).toArray();

  console.log(`Found ${eventsNeedingAttendance.length} events for this user`);

  let updatedCount = 0;
  let skippedCount = 0;

  for (const event of eventsNeedingAttendance) {
    // Find user's entry in accepted_staff
    const userStaffEntry = event.accepted_staff?.find(
      (s: any) => s.userKey === userKey
    );

    if (!userStaffEntry) continue;

    // Skip if already has attendance
    if (userStaffEntry.attendance && userStaffEntry.attendance.length > 0) {
      skippedCount++;
      continue;
    }

    // Parse event date and times
    const eventDate = new Date(event.date);
    const [startHour, startMin] = (event.start_time || '17:00').split(':').map(Number);
    const [endHour, endMin] = (event.end_time || '22:00').split(':').map(Number);

    // Create clock in/out times
    const clockInAt = new Date(eventDate);
    clockInAt.setHours(startHour, startMin, 0, 0);

    const clockOutAt = new Date(eventDate);
    clockOutAt.setHours(endHour, endMin, 0, 0);

    // Handle overnight events (end time before start time)
    if (clockOutAt <= clockInAt) {
      clockOutAt.setDate(clockOutAt.getDate() + 1);
    }

    // Calculate hours
    const millisDiff = clockOutAt.getTime() - clockInAt.getTime();
    const approvedHours = Math.round((millisDiff / (1000 * 60 * 60)) * 10) / 10; // Round to 1 decimal

    // Create approval timestamp (1 day after event)
    const approvedAt = new Date(clockOutAt);
    approvedAt.setDate(approvedAt.getDate() + 1);

    // Create attendance session
    const attendanceSession = {
      clockInAt: clockInAt,
      clockOutAt: clockOutAt,
      estimatedHours: approvedHours,
      sheetSignInTime: clockInAt,
      sheetSignOutTime: clockOutAt,
      approvedHours: approvedHours,
      status: 'approved',
      approvedBy: 'system',
      approvedAt: approvedAt,
      managerNotes: 'Auto-generated for historical data',
    };

    // Update the event
    await shiftsCollection.updateOne(
      {
        _id: event._id,
        'accepted_staff.userKey': userKey,
      },
      {
        $set: {
          'accepted_staff.$.attendance': [attendanceSession],
        },
      }
    );

    updatedCount++;
  }

  console.log(`\n✅ Updated ${updatedCount} events with attendance data`);
  console.log(`⏭️  Skipped ${skippedCount} events (already had attendance)`);

  // Verify
  const eventsWithAttendance = await shiftsCollection.countDocuments({
    'accepted_staff': {
      $elemMatch: {
        userKey: userKey,
        'attendance.0': { $exists: true },
        'attendance.status': 'approved',
      },
    },
  });

  console.log(`\n📊 Verification:`);
  console.log(`  Events with approved attendance: ${eventsWithAttendance}`);

  await mongoose.disconnect();
  console.log('\n✅ Done! Events should now appear in earnings screen.');
}

main().catch((err) => {
  console.error('❌ Error:', err);
  process.exit(1);
});
