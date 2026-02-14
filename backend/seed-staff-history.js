/**
 * Seed script: Create 200 completed event documents for staff member juan gomez
 * Run via: docker exec nexa-api node /app/seed-staff-history.js
 */

const mongoose = require('mongoose');

const MONGO_URI = process.env.MONGODB_URI || process.env.MONGO_URI;
const MANAGER_ID = '698b6f033eab434a989b4912';

const staff = {
  userKey: 'google:112603799149919213350',
  provider: 'google',
  subject: '112603799149919213350',
  email: 'juan.2007@gmail.com',
  name: 'juan gomez',
  first_name: 'Juan',
  last_name: 'Gomez',
  picture: 'https://lh3.googleusercontent.com/a/ACg8ocIrn0I-vAo2UG-zAnowHwyU5AtyXekkZLaxjNJOm7584Y_xtPv5SQ=s96-c',
  response: 'accepted',
};

const venues = [
  { name: 'Colorado Convention Center', address: '700 14th St, Denver, CO 80202', city: 'Denver', state: 'CO', lat: 39.7427, lng: -104.9942 },
  { name: 'Ball Arena', address: '1000 Chopper Cir, Denver, CO 80204', city: 'Denver', state: 'CO', lat: 39.7487, lng: -105.0077 },
  { name: 'Four Seasons Hotel Denver', address: '1111 14th St, Denver, CO 80202', city: 'Denver', state: 'CO', lat: 39.7480, lng: -104.9963 },
  { name: 'The Ritz-Carlton Denver', address: '1881 Curtis St, Denver, CO 80202', city: 'Denver', state: 'CO', lat: 39.7498, lng: -104.9928 },
  { name: 'Grand Hyatt Denver', address: '1750 Welton St, Denver, CO 80202', city: 'Denver', state: 'CO', lat: 39.7471, lng: -104.9897 },
  { name: 'Bellco Theatre', address: '700 14th St, Denver, CO 80202', city: 'Denver', state: 'CO', lat: 39.7430, lng: -104.9940 },
  { name: 'Denver Botanic Gardens', address: '1007 York St, Denver, CO 80206', city: 'Denver', state: 'CO', lat: 39.7320, lng: -104.9598 },
  { name: 'The Brown Palace Hotel', address: '321 17th St, Denver, CO 80202', city: 'Denver', state: 'CO', lat: 39.7442, lng: -104.9873 },
  { name: 'Wings Over the Rockies', address: '7711 E Academy Blvd, Denver, CO 80230', city: 'Denver', state: 'CO', lat: 39.7214, lng: -104.8965 },
  { name: 'Denver Art Museum', address: '100 W 14th Ave Pkwy, Denver, CO 80204', city: 'Denver', state: 'CO', lat: 39.7372, lng: -104.9893 },
  { name: 'Empower Field at Mile High', address: '1701 Bryant St, Denver, CO 80204', city: 'Denver', state: 'CO', lat: 39.7439, lng: -105.0201 },
  { name: 'Hilton Denver City Center', address: '1701 California St, Denver, CO 80202', city: 'Denver', state: 'CO', lat: 39.7468, lng: -104.9870 },
  { name: 'Sheraton Denver Downtown', address: '1550 Court Pl, Denver, CO 80202', city: 'Denver', state: 'CO', lat: 39.7454, lng: -104.9896 },
  { name: 'The Cable Center', address: '2000 Buchtel Blvd S, Denver, CO 80210', city: 'Denver', state: 'CO', lat: 39.6795, lng: -104.9645 },
  { name: 'Ellie Caulkins Opera House', address: '1385 Curtis St, Denver, CO 80204', city: 'Denver', state: 'CO', lat: 39.7397, lng: -104.9980 },
  { name: 'Wellshire Event Center', address: '3333 S Colorado Blvd, Denver, CO 80222', city: 'Denver', state: 'CO', lat: 39.6625, lng: -104.9407 },
  { name: 'The Manor House', address: '1 Manor House Rd, Littleton, CO 80127', city: 'Littleton', state: 'CO', lat: 39.5906, lng: -105.1168 },
  { name: 'Cielo at Castle Pines', address: '895 W Happy Canyon Rd, Castle Rock, CO 80108', city: 'Castle Rock', state: 'CO', lat: 39.4618, lng: -104.8970 },
  { name: 'Pinehurst Country Club', address: '6255 W Quincy Ave, Denver, CO 80235', city: 'Denver', state: 'CO', lat: 39.6615, lng: -105.0522 },
  { name: 'Seawell Grand Ballroom', address: '1000 14th St, Denver, CO 80202', city: 'Denver', state: 'CO', lat: 39.7412, lng: -104.9958 },
];

const clients = [
  'Goldman Sachs Corporate', 'Platinum Weddings Co', 'Google Denver Office', 'Microsoft Events',
  'Tesla Annual Gala', 'Amazon Web Services', 'Oracle Corporate', 'Salesforce Summit',
  'Facebook Meta Events', 'Apple Product Launch', 'JPMorgan Chase Events', 'Deloitte Denver',
  'McKinsey & Company', 'Boeing Corporate', 'Lockheed Martin', 'Raytheon Technologies',
  'United Airlines Events', 'Southwest Airlines Gala', 'Comcast NBCU', 'Charter Communications',
  'First Data Corp', 'Western Union', 'Arrow Electronics', 'Liberty Global',
  'DaVita Healthcare', 'VF Corporation', 'Molson Coors Beverage', 'Ball Corporation',
  'RE/MAX Corporate', 'Denver Broncos Foundation', 'Colorado Avalanche Charity', 'Denver Nuggets Foundation',
  'University of Denver', 'Colorado School of Mines', 'Red Bull Events', 'Nike Denver',
  'Patagonia Corporate', 'KPMG Denver', 'EY Rocky Mountain', 'PwC Colorado',
];

const eventTypes = [
  'Corporate Dinner', 'Wedding Reception', 'Charity Gala', 'Awards Ceremony',
  'Product Launch', 'Holiday Party', 'Cocktail Reception', 'Conference Dinner',
  'Anniversary Celebration', 'Networking Event', 'Fundraiser Gala', 'Company Retreat',
  'Board Meeting Dinner', 'Client Appreciation', 'Team Building Event', 'VIP Cocktail Party',
  'Engagement Party', 'Bridal Shower', 'Retirement Celebration', 'Grand Opening',
];

const roles = [
  { role: 'Server', count: 8 },
  { role: 'Bartender', count: 3 },
  { role: 'Captain', count: 2 },
  { role: 'Busser', count: 4 },
  { role: 'Event Lead', count: 1 },
  { role: 'Setup Crew', count: 5 },
  { role: 'Kitchen Staff', count: 3 },
  { role: 'Coat Check', count: 1 },
  { role: 'Valet', count: 2 },
  { role: 'Host/Hostess', count: 2 },
];

const uniforms = [
  'Black pants, white dress shirt, black tie',
  'All black formal attire',
  'Black pants, black polo with logo',
  'Black slacks, white button-down, black vest',
  'Formal: black suit, white shirt, black bow tie',
  'Business casual: khaki pants, company polo',
  'All black with apron provided on-site',
  'Black pants, black dress shirt, no tie',
];

function randomFrom(arr) {
  return arr[Math.floor(Math.random() * arr.length)];
}

function randomInt(min, max) {
  return Math.floor(Math.random() * (max - min + 1)) + min;
}

function generateStartTime() {
  const hours = [7, 8, 9, 10, 11, 12, 14, 15, 16, 17, 18, 19];
  const h = randomFrom(hours);
  const m = randomFrom([0, 15, 30]);
  return `${String(h).padStart(2, '0')}:${String(m).padStart(2, '0')}`;
}

function generateEndTime(startTime) {
  const [h, m] = startTime.split(':').map(Number);
  const duration = randomInt(4, 10); // 4-10 hour events
  const endH = Math.min(h + duration, 23);
  return `${String(endH).padStart(2, '0')}:${String(m).padStart(2, '0')}`;
}

function generateAttendance(eventDate, startTime, endTime) {
  const [sh, sm] = startTime.split(':').map(Number);
  const [eh, em] = endTime.split(':').map(Number);

  const clockIn = new Date(eventDate);
  clockIn.setHours(sh, sm - randomInt(0, 15), 0); // arrive 0-15 min early

  const clockOut = new Date(eventDate);
  clockOut.setHours(eh, em + randomInt(0, 30), 0); // leave 0-30 min after

  const hoursWorked = (clockOut - clockIn) / (1000 * 60 * 60);

  return [{
    clockInAt: clockIn,
    clockOutAt: clockOut,
    estimatedHours: Math.round(hoursWorked * 10) / 10,
    approvedHours: Math.round(hoursWorked * 10) / 10,
    status: 'approved',
    clockInLocation: {
      latitude: 39.7392 + (Math.random() - 0.5) * 0.05,
      longitude: -104.9903 + (Math.random() - 0.5) * 0.05,
      accuracy: randomInt(5, 25),
      source: 'geofence',
    },
  }];
}

async function seed() {
  console.log('Connecting to MongoDB...');
  await mongoose.connect(MONGO_URI);
  console.log('Connected.');

  const db = mongoose.connection.db;
  const collection = db.collection('shifts'); // Events collection name

  const events = [];
  const startDate = new Date('2025-01-05');
  const endDate = new Date('2026-02-13');
  const totalDays = Math.floor((endDate - startDate) / (1000 * 60 * 60 * 24));

  // Generate 200 events spread across the date range
  const eventDates = [];
  for (let i = 0; i < 200; i++) {
    const dayOffset = Math.floor((i / 200) * totalDays) + randomInt(0, 3);
    const d = new Date(startDate);
    d.setDate(d.getDate() + dayOffset);
    eventDates.push(d);
  }
  eventDates.sort((a, b) => a - b);

  for (let i = 0; i < 200; i++) {
    const eventDate = eventDates[i];
    const venue = randomFrom(venues);
    const client = randomFrom(clients);
    const eventType = randomFrom(eventTypes);
    const startTime = generateStartTime();
    const endTime = generateEndTime(startTime);
    const eventRoles = [];
    const numRoles = randomInt(2, 5);
    const usedRoles = new Set();
    for (let r = 0; r < numRoles; r++) {
      let role;
      do { role = randomFrom(roles); } while (usedRoles.has(role.role));
      usedRoles.add(role.role);
      eventRoles.push({ role: role.role, count: randomInt(1, role.count) });
    }

    const headcount = eventRoles.reduce((sum, r) => sum + r.count, 0);
    const staffRole = randomFrom(eventRoles).role;

    const attendance = generateAttendance(eventDate, startTime, endTime);

    const event = {
      managerId: new mongoose.Types.ObjectId(MANAGER_ID),
      status: 'completed',
      visibilityType: randomFrom(['private', 'public', 'private_public']),
      publishedAt: new Date(eventDate.getTime() - randomInt(3, 14) * 24 * 60 * 60 * 1000),
      fulfilledAt: new Date(eventDate.getTime() - randomInt(0, 2) * 24 * 60 * 60 * 1000),
      shift_name: `${eventType} - ${client}`,
      client_name: client,
      date: eventDate,
      start_time: startTime,
      end_time: endTime,
      venue_name: venue.name,
      venue_address: venue.address,
      venue_latitude: venue.lat,
      venue_longitude: venue.lng,
      city: venue.city,
      state: venue.state,
      country: 'US',
      contact_name: `${randomFrom(['Sarah', 'Michael', 'Jennifer', 'David', 'Emily', 'Robert', 'Jessica', 'James'])} ${randomFrom(['Smith', 'Johnson', 'Williams', 'Brown', 'Jones', 'Davis', 'Miller', 'Wilson'])}`,
      contact_phone: `(303) ${randomInt(200, 999)}-${String(randomInt(1000, 9999))}`,
      contact_email: `events@${client.toLowerCase().replace(/[^a-z]/g, '')}.com`,
      setup_time: `${String(Math.max(6, parseInt(startTime) - 2)).padStart(2, '0')}:00`,
      uniform: randomFrom(uniforms),
      notes: randomFrom([
        'Parking in garage B. Enter through service entrance.',
        'All staff must check in at security desk.',
        'Client requires strict dress code compliance.',
        'Meals provided for staff during break.',
        'Load-in through loading dock on east side.',
        'NDA required - corporate event.',
        'VIP guests expected. White glove service.',
        '',
      ]),
      headcount_total: headcount,
      roles: eventRoles,
      pay_rate_info: `$${randomInt(18, 35)}/hr`,
      accepted_staff: [{
        ...staff,
        role: staffRole,
        respondedAt: new Date(eventDate.getTime() - randomInt(1, 10) * 24 * 60 * 60 * 1000),
        attendance,
      }],
      declined_staff: [],
      role_stats: eventRoles.map(r => ({
        role: r.role,
        capacity: r.count,
        taken: r.count,
        remaining: 0,
        is_full: true,
      })),
      hoursStatus: 'approved',
      hoursApprovedAt: new Date(eventDate.getTime() + randomInt(1, 5) * 24 * 60 * 60 * 1000),
      notificationsSent: { preShiftReminder: true, forgotClockOut: false },
      chatEnabled: Math.random() > 0.5,
      version: 0,
      createdAt: new Date(eventDate.getTime() - randomInt(7, 21) * 24 * 60 * 60 * 1000),
      updatedAt: new Date(eventDate.getTime() + randomInt(1, 5) * 24 * 60 * 60 * 1000),
    };

    events.push(event);
  }

  console.log(`Inserting ${events.length} events...`);
  const result = await collection.insertMany(events);
  console.log(`Inserted ${result.insertedCount} events.`);

  // Print date range
  const first = events[0].date;
  const last = events[events.length - 1].date;
  console.log(`Date range: ${first.toISOString().split('T')[0]} to ${last.toISOString().split('T')[0]}`);

  await mongoose.disconnect();
  console.log('Done.');
}

seed().catch(err => {
  console.error('Seed failed:', err);
  process.exit(1);
});
