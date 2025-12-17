import mongoose from 'mongoose';
import dotenv from 'dotenv';
dotenv.config();

// This script adds 5 marketing-friendly draft shifts to the database
// Run with: npx ts-node scripts/add-marketing-shifts.ts

async function main() {
  const MONGO_URI = process.env.MONGO_URI;
  if (!MONGO_URI) {
    console.error('❌ MONGO_URI environment variable not found');
    console.log('💡 Make sure to run: source .env');
    process.exit(1);
  }

  console.log('🔌 Connecting to MongoDB...');
  await mongoose.connect(MONGO_URI);
  console.log('✅ Connected!\n');

  const db = mongoose.connection.db!;
  const shiftsCollection = db.collection('shifts');
  const managersCollection = db.collection('managers');

  // Get first manager to use as owner
  const manager = await managersCollection.findOne({});
  if (!manager) {
    console.error('❌ No managers found in database.');
    await mongoose.disconnect();
    process.exit(1);
  }

  console.log(`📝 Using manager: ${manager._id}\n`);

  // Premium marketing-friendly event data
  const marketingShifts = [
    {
      shift_name: 'New Year Gala',
      client_name: 'Ritz-Carlton Denver',
      venue_name: 'Ritz-Carlton Denver',
      venue_address: '1881 Curtis Street, Denver, CO 80202',
      city: 'Denver',
      state: 'CO',
      date: new Date('2026-01-07'),
      start_time: '5:00 PM',
      end_time: '11:00 PM',
      roles: [
        { role: 'Bartender', count: 4 },
        { role: 'Server', count: 6 },
      ],
      headcount_total: 10,
      uniform: 'Black tie formal attire',
      notes: 'High-profile corporate event. VIP service standards required.',
      contact_name: 'Sarah Mitchell',
      contact_phone: '(303) 555-0142',
    },
    {
      shift_name: 'Tech Summit Reception',
      client_name: 'Google Boulder',
      venue_name: 'Google Boulder Campus',
      venue_address: '2590 Pearl Street, Boulder, CO 80302',
      city: 'Boulder',
      state: 'CO',
      date: new Date('2026-01-08'),
      start_time: '4:00 PM',
      end_time: '9:00 PM',
      roles: [
        { role: 'Bartender', count: 3 },
        { role: 'Server', count: 5 },
        { role: 'Event Coordinator', count: 1 },
      ],
      headcount_total: 9,
      uniform: 'Smart casual - company polo provided',
      notes: 'Tech industry networking event. Expect 200+ guests.',
      contact_name: 'Michael Chen',
      contact_phone: '(720) 555-0198',
    },
    {
      shift_name: 'Charity Wine Auction',
      client_name: 'Denver Art Museum',
      venue_name: 'Denver Art Museum',
      venue_address: '100 W 14th Ave Pkwy, Denver, CO 80204',
      city: 'Denver',
      state: 'CO',
      date: new Date('2026-01-09'),
      start_time: '6:00 PM',
      end_time: '10:00 PM',
      roles: [
        { role: 'Sommelier', count: 2 },
        { role: 'Server', count: 4 },
        { role: 'Bartender', count: 2 },
      ],
      headcount_total: 8,
      uniform: 'All black formal attire',
      notes: 'Charity gala benefiting local arts programs. Wine knowledge preferred.',
      contact_name: 'Emily Rodriguez',
      contact_phone: '(303) 555-0256',
    },
    {
      shift_name: 'Corporate Awards Dinner',
      client_name: 'Microsoft Denver',
      venue_name: 'Four Seasons Denver',
      venue_address: '1111 14th Street, Denver, CO 80202',
      city: 'Denver',
      state: 'CO',
      date: new Date('2026-01-10'),
      start_time: '5:30 PM',
      end_time: '11:30 PM',
      roles: [
        { role: 'Captain', count: 1 },
        { role: 'Server', count: 8 },
        { role: 'Bartender', count: 3 },
      ],
      headcount_total: 12,
      uniform: 'Black and white formal',
      notes: 'Annual employee recognition dinner. 300 guests expected.',
      contact_name: 'James Wilson',
      contact_phone: '(720) 555-0334',
    },
    {
      shift_name: 'Luxury Brand Launch',
      client_name: 'Louis Vuitton',
      venue_name: 'The Crawford Hotel',
      venue_address: '1701 Wynkoop Street, Denver, CO 80202',
      city: 'Denver',
      state: 'CO',
      date: new Date('2026-01-12'),
      start_time: '7:00 PM',
      end_time: '12:00 AM',
      roles: [
        { role: 'Bartender', count: 4 },
        { role: 'Server', count: 6 },
        { role: 'Host', count: 2 },
      ],
      headcount_total: 12,
      uniform: 'Designer black attire - details TBD',
      notes: 'Exclusive product launch. Celebrity guests expected. NDA required.',
      contact_name: 'Alexandra Dubois',
      contact_phone: '(303) 555-0412',
    },
  ];

  // Build the documents
  const shiftsToInsert = marketingShifts.map(shift => ({
    managerId: manager._id,
    status: 'draft', // So they appear in pending section
    visibilityType: 'public',
    ...shift,
    role_stats: shift.roles.map(r => ({
      role: r.role,
      capacity: r.count,
      taken: 0,
      remaining: r.count,
      is_full: false,
    })),
    accepted_staff: [],
    declined_staff: [],
    audience_user_keys: [],
    audience_team_ids: [],
    createdAt: new Date(),
    updatedAt: new Date(),
  }));

  console.log(`📥 Inserting ${shiftsToInsert.length} marketing shifts...`);

  for (const shift of shiftsToInsert) {
    console.log(`  → ${shift.shift_name} (${shift.client_name}) - ${shift.date.toDateString()}`);
  }

  const result = await shiftsCollection.insertMany(shiftsToInsert);
  console.log(`\n✅ Inserted ${result.insertedCount} draft shifts\n`);

  // Verify
  const draftCount = await shiftsCollection.countDocuments({
    managerId: manager._id,
    status: 'draft'
  });

  console.log('📊 Summary:');
  console.log(`  Draft shifts ready to publish: ${draftCount}`);
  console.log('\n💡 Open the Manager app → Pending section to publish these shifts!');

  await mongoose.disconnect();
  console.log('\n✅ Done!');
}

main().catch(err => {
  console.error('❌ Error:', err);
  process.exit(1);
});
