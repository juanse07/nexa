const mongoose = require('mongoose');
require('dotenv').config();

async function checkUserData() {
  try {
    const mongoUri = process.env.MONGO_URI;
    const dbName = 'nexa_prod';
    await mongoose.connect(`${mongoUri}/${dbName}`);
    console.log('✅ Connected to database');

    // Check the user record for juan.2007@gmail.com
    const user = await mongoose.connection.db.collection('users').findOne({
      email: 'juan.2007@gmail.com'
    });

    if (user) {
      console.log('👤 User found:');
      console.log(`  Email: ${user.email}`);
      console.log(`  Name: ${user.name}`);
      console.log(`  Provider: ${user.provider}`);
      console.log(`  Subject: ${user.subject}`);
      console.log(`  _id: ${user._id}`);
    } else {
      console.log('❌ User not found');
    }

    // Check what userKeys are being used in events
    console.log('\n🔍 Checking userKey patterns in events...');
    const eventsWithStaff = await mongoose.connection.db.collection('events').find({
      'accepted_staff': { $exists: true, $ne: [] }
    }).limit(20);

    const userKeyPatterns = {};
    let eventsCount = 0;

    await eventsWithStaff.forEach(event => {
      eventsCount++;
      if (event.accepted_staff && event.accepted_staff.length > 0) {
        event.accepted_staff.forEach(staff => {
          if (staff.userKey) {
            userKeyPatterns[staff.userKey] = (userKeyPatterns[staff.userKey] || 0) + 1;
          }
        });
      }
    });

    console.log(`📊 Analyzed ${eventsCount} events with staff`);
    console.log('🔑 UserKey patterns found:');
    Object.entries(userKeyPatterns).forEach(([userKey, count]) => {
      console.log(`  "${userKey}": ${count} events`);
    });

    // Find recent events to see if any were created recently
    const recentEvents = await mongoose.connection.db.collection('events').find({
      date: { $gte: new Date('2024-01-01') }
    }).sort({ date: -1 }).limit(5);

    console.log('\n📅 Recent events:');
    await recentEvents.forEach(event => {
      console.log(`  Date: ${event.date?.toISOString()?.split('T')[0]}, Status: ${event.status}, Staff: ${event.accepted_staff?.length || 0}`);
      if (event.accepted_staff && event.accepted_staff.length > 0) {
        const staff = event.accepted_staff[0];
        console.log(`    Staff userKey: "${staff.userKey}", email: "${staff.email}"`);
      }
    });

    await mongoose.disconnect();
  } catch (error) {
    console.error('❌ Error:', error);
    process.exit(1);
  }
}

checkUserData();