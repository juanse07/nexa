import mongoose from 'mongoose';
import { ENV } from '../src/config/env';
import { EventModel } from '../src/models/event';

/**
 * Fix UserKey Format in Historical Events
 * Updates userKey from 'google:112603799149919213350' to '112603799149919213350'
 */

const WRONG_USERKEY = 'google:112603799149919213350';
const CORRECT_USERKEY = '112603799149919213350';
const USER_EMAIL = 'juan.2007@gmail.com';

async function main(): Promise<void> {
  console.log('🔧 Fixing userKey format in historical events...');

  try {
    // Connect to database
    if (!ENV.mongoUri) {
      throw new Error('MONGO_URI environment variable is required');
    }

    const dbName = ENV.nodeEnv === 'production' ? 'nexa_prod' : 'nexa_test';
    let uri = ENV.mongoUri.trim();
    if (uri.endsWith('/')) {
      uri = uri.slice(0, -1);
    }

    await mongoose.connect(`${uri}/${dbName}`);
    console.log(`✅ Connected to database: ${dbName}`);

    // Find events with the wrong userKey format
    const wrongEvents = await EventModel.find({
      'accepted_staff.userKey': WRONG_USERKEY
    });

    console.log(`📊 Found ${wrongEvents.length} events with wrong userKey format`);

    if (wrongEvents.length === 0) {
      console.log('ℹ️ No events need fixing. UserKey format is already correct.');

      // Check if there are any events with the correct format
      const correctEvents = await EventModel.find({
        'accepted_staff.userKey': CORRECT_USERKEY
      });
      console.log(`📊 Found ${correctEvents.length} events with correct userKey format`);

      return;
    }

    let updatedCount = 0;
    const now = new Date();

    for (const event of wrongEvents) {
      let needsUpdate = false;

      // Update userKey format in accepted_staff array
      if (event.accepted_staff && event.accepted_staff.length > 0) {
        for (const staff of event.accepted_staff) {
          if (staff.userKey === WRONG_USERKEY) {
            staff.userKey = CORRECT_USERKEY;
            needsUpdate = true;
          }
        }
      }

      // Ensure status is set correctly based on date
      const eventDate = new Date(event.date);
      if (!event.status) {
        if (eventDate < now) {
          event.status = 'completed';
        } else {
          event.status = 'confirmed';
        }
        needsUpdate = true;
        console.log(`  📅 Set status to '${event.status}' for event on ${eventDate.toISOString().split('T')[0]}`);
      } else if (eventDate < now && event.status !== 'completed' && event.status !== 'cancelled') {
        event.status = 'completed';
        needsUpdate = true;
        console.log(`  📅 Updated status to 'completed' for past event on ${eventDate.toISOString().split('T')[0]}`);
      }

      // Ensure required fields are present
      if (!event.createdAt) {
        event.createdAt = new Date(event.date);
        needsUpdate = true;
      }

      if (!event.fulfilledAt && event.status === 'completed') {
        event.fulfilledAt = new Date(eventDate.getTime() + (6 * 60 * 60 * 1000)); // 6 hours after event start
        needsUpdate = true;
      }

      if (needsUpdate) {
        await event.save();
        updatedCount++;
        console.log(`  ✅ Updated event: ${event.shift_name || 'Untitled'} (${eventDate.toISOString().split('T')[0]})`);
      }
    }

    console.log(`\n✅ Updated ${updatedCount} events with correct userKey format`);

    // Verify the fix
    const verifiedEvents = await EventModel.find({
      'accepted_staff.userKey': CORRECT_USERKEY
    });

    console.log(`📊 Verification: Found ${verifiedEvents.length} events with correct userKey format`);

    // Status summary
    const statusSummary = await EventModel.aggregate([
      { $match: { 'accepted_staff.userKey': CORRECT_USERKEY } },
      { $group: { _id: '$status', count: { $sum: 1 } } },
      { $sort: { count: -1 } }
    ]);

    console.log('\n📈 Status Summary:');
    for (const status of statusSummary) {
      console.log(`  ${status._id || 'undefined'}: ${status.count} events`);
    }

    // Show sample of fixed events
    const sampleEvents = await EventModel.find({
      'accepted_staff.userKey': CORRECT_USERKEY
    })
    .sort({ date: -1 })
    .limit(5)
    .select('date status shift_name approvedHours');

    console.log('\n🔍 Sample of Fixed Events:');
    for (const event of sampleEvents) {
      const eventDate = new Date(event.date);
      const approvedHours = (event as any).approvedHours || 0;
      console.log(`  ${eventDate.toISOString().split('T')[0]}: ${event.status} - ${event.shift_name || 'Untitled'} (${approvedHours}h)`);
    }

    console.log('\n🎉 UserKey format fix completed! The historical events should now appear in the Past Events screen.');

  } catch (error) {
    console.error('❌ Error fixing userKey format:', error);
    throw error;
  } finally {
    await mongoose.disconnect();
    console.log('🔌 Database disconnected');
  }
}

if (require.main === module) {
  main();
}