const mongoose = require('mongoose');
const { ENV } = require('./dist/src/config/env');

async function checkEvents() {
  try {
    await mongoose.connect(`${ENV.mongoUri}/nexa_prod`);
    console.log('✅ Connected to database');

    // Check total events count
    const totalEvents = await mongoose.connection.db.collection('events').countDocuments();
    console.log('📊 Total events in database:', totalEvents);

    // Check events with our userKey
    const userEvents = await mongoose.connection.db.collection('events').find({
      'accepted_staff.userKey': 'google:112603799149919213350'
    }).countDocuments();
    console.log('👤 Events with our userKey:', userEvents);

    // Check events with juan.2007@gmail.com in email field
    const emailEvents = await mongoose.connection.db.collection('events').find({
      'accepted_staff.email': 'juan.2007@gmail.com'
    }).countDocuments();
    console.log('📧 Events with juan.2007@gmail.com email:', emailEvents);

    // Check events from 2024
    const events2024 = await mongoose.connection.db.collection('events').find({
      date: {
        $gte: new Date('2024-01-01'),
        $lt: new Date('2025-01-01')
      }
    }).countDocuments();
    console.log('📅 Events from 2024:', events2024);

    // Get a sample of events to see their structure
    const sampleEvents = await mongoose.connection.db.collection('events').find({}).limit(3).toArray();
    console.log('\n🔍 Sample events structure:');
    sampleEvents.forEach((event, i) => {
      console.log(`Event ${i + 1}:`);
      console.log(`  Date: ${event.date}`);
      console.log(`  Status: ${event.status}`);
      console.log(`  Accepted Staff: ${event.accepted_staff?.length || 0} people`);
      if (event.accepted_staff && event.accepted_staff.length > 0) {
        console.log(`  First staff: ${JSON.stringify(event.accepted_staff[0], null, 2)}`);
      }
      console.log('---');
    });

    await mongoose.disconnect();
  } catch (error) {
    console.error('❌ Error:', error);
    process.exit(1);
  }
}

checkEvents();