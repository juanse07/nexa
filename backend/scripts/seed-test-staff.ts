/**
 * CLEAN SEED SCRIPT — Elena + 5 Test Staff
 *
 * DESTRUCTIVE: Drops all collections and rebuilds from scratch.
 *
 * Creates:
 * - 1 Manager (Elena Rivera — demo@flowshift.work / FlowShift2024!)
 * - 1 Team: "Rivera Events Team"
 * - 8 Roles, 5 Clients, 10 Venues, 40 Tariffs
 * - 5 Staff users (email auth, pro subscription)
 * - ~250 completed events per staff (Jan 2025 → Feb 2026)
 * - 5 published events (1 per tester accepted) — "My Events"
 * - 5 published events (open, no accepted_staff) — "Available"
 * - 10 draft events — invisible to all staff
 * - JWT tokens for all 6 accounts
 *
 * Usage:
 *   cd backend && npx ts-node --transpile-only scripts/seed-test-staff.ts
 */

import mongoose from 'mongoose';
import jwt from 'jsonwebtoken';
import bcrypt from 'bcryptjs';
import { ENV } from '../src/config/env';
import { UserModel } from '../src/models/user';
import { ManagerModel } from '../src/models/manager';
import { TeamModel } from '../src/models/team';
import { TeamMemberModel } from '../src/models/teamMember';
import { ClientModel } from '../src/models/client';
import { RoleModel } from '../src/models/role';
import { TariffModel } from '../src/models/tariff';
import { VenueModel } from '../src/models/venue';
import { EventModel } from '../src/models/event';
import { StaffProfileModel } from '../src/models/staffProfile';

// ════════════════════════════════════════════════════════════
// STATIC DATA
// ════════════════════════════════════════════════════════════

const MANAGER_DEF = {
  subject: 'demo@flowshift.work',
  name: 'Elena Rivera',
  email: 'demo@flowshift.work',
  password: 'FlowShift2024!',
  first_name: 'Elena',
  last_name: 'Rivera',
  city: 'Denver',
  teamName: 'Rivera Events Team',
};

const STAFF_PASSWORD = 'FlowShift2024!';

interface StaffDef {
  first: string;
  last: string;
  email: string;
  roles: string[];
}

const STAFF_DEFS: StaffDef[] = [
  { first: 'Angie',   last: 'Reyes',   email: 'angie@flowshift.work',   roles: ['Server', 'Host/Hostess', 'Barback'] },
  { first: 'Camilo',  last: 'Ariza',   email: 'camilo@flowshift.work',  roles: ['Bartender', 'Barback', 'Setup Crew'] },
  { first: 'Juanita', last: 'Camacho', email: 'juanita@flowshift.work', roles: ['Event Coordinator', 'Host/Hostess', 'Server'] },
  { first: 'Steven',  last: 'Leon',    email: 'steven@flowshift.work',  roles: ['Security', 'Setup Crew', 'Valet'] },
  { first: 'Laura',   last: 'Acosta',  email: 'laura@flowshift.work',   roles: ['Valet', 'Server', 'Setup Crew'] },
];

const ROLE_DEFS: { name: string; payMin: number; payMax: number; baseRate: number }[] = [
  { name: 'Server',            payMin: 20, payMax: 24, baseRate: 22 },
  { name: 'Bartender',         payMin: 24, payMax: 30, baseRate: 27 },
  { name: 'Host/Hostess',      payMin: 20, payMax: 23, baseRate: 21 },
  { name: 'Event Coordinator', payMin: 26, payMax: 32, baseRate: 29 },
  { name: 'Security',          payMin: 22, payMax: 28, baseRate: 25 },
  { name: 'Barback',           payMin: 20, payMax: 22, baseRate: 21 },
  { name: 'Setup Crew',        payMin: 20, payMax: 25, baseRate: 22 },
  { name: 'Valet',             payMin: 21, payMax: 26, baseRate: 23 },
];

const VENUE_DEFS = [
  { name: 'Four Seasons Hotel Denver',    address: '1111 14th St',         city: 'Denver',      state: 'CO', lat: 39.7447, lng: -104.9997 },
  { name: 'The Ritz-Carlton, Denver',     address: '1881 Curtis St',       city: 'Denver',      state: 'CO', lat: 39.7473, lng: -104.9941 },
  { name: 'Denver Art Museum',            address: '100 W 14th Ave Pkwy',  city: 'Denver',      state: 'CO', lat: 39.7373, lng: -104.9896 },
  { name: 'Colorado Convention Center',   address: '700 14th St',          city: 'Denver',      state: 'CO', lat: 39.7392, lng: -104.9973 },
  { name: 'Ellie Caulkins Opera House',   address: '1385 Curtis St',       city: 'Denver',      state: 'CO', lat: 39.7396, lng: -105.0003 },
  { name: 'Mile High Station',            address: '2027 W Colfax Ave',    city: 'Denver',      state: 'CO', lat: 39.7406, lng: -105.0088 },
  { name: 'The Manor House',             address: '1 Manor House Rd',     city: 'Littleton',   state: 'CO', lat: 39.5853, lng: -105.0144 },
  { name: 'Cielo at Castle Pines',        address: '6380 Village Ln',      city: 'Castle Rock', state: 'CO', lat: 39.4733, lng: -104.8861 },
  { name: 'Della Terra Mountain Chateau', address: '3501 Fall River Rd',   city: 'Estes Park',  state: 'CO', lat: 40.3883, lng: -105.5858 },
  { name: 'Wellshire Event Center',       address: '3333 S Colorado Blvd', city: 'Denver',      state: 'CO', lat: 39.6578, lng: -104.9408 },
];

const CLIENT_DEFS = [
  { name: 'The Grand Hyatt Group',       multiplier: 1.0 },
  { name: 'Stellar Productions Inc',     multiplier: 1.3 },
  { name: 'Rocky Mountain Event Co',     multiplier: 1.1 },
  { name: 'Mile High Hospitality Group', multiplier: 1.2 },
  { name: 'Denver Elite Catering',       multiplier: 1.15 },
];

const EVENT_NAMES = [
  'Corporate Gala', 'Annual Fundraiser', 'Wedding Reception', 'VIP Cocktail Party',
  'Holiday Dinner', 'Product Launch', 'Art Exhibition Opening', 'Wine Tasting Soiree',
  'Charity Auction', 'Award Ceremony', 'Rehearsal Dinner', 'Corporate Retreat',
  'Sports Banquet', 'Birthday Celebration', 'Networking Mixer', 'Fashion Show',
  'Grand Opening', 'Film Premiere', 'Tech Summit Reception', 'Music Festival VIP',
  'New Year\'s Eve Gala', 'Bridal Shower', 'Anniversary Party', 'Retirement Celebration',
  'Memorial Dinner', 'Graduation Party', 'Whiskey Tasting', 'Book Launch',
  'Garden Party', 'Harvest Festival',
];

const UNIFORM_POOL = [
  'Black tie formal', 'All black attire', 'White shirt, black vest, black pants',
  'Formal service attire', 'Black pants, white button-down', 'Business casual',
  'Black cocktail attire', 'Black suit, no tie', 'Smart casual - dark colors',
];

// ════════════════════════════════════════════════════════════
// UTILITIES (seeded PRNG)
// ════════════════════════════════════════════════════════════

function mulberry32(seed: number) {
  return function () {
    let t = (seed += 0x6d2b79f5);
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

const rand = mulberry32(7777);

function randomPick<T>(arr: T[]): T {
  return arr[Math.floor(rand() * arr.length)]!;
}

function randomInt(min: number, max: number): number {
  return Math.floor(rand() * (max - min + 1)) + min;
}

function generateSpreadDates(start: Date, end: Date, count: number): Date[] {
  const startMs = start.getTime();
  const endMs = end.getTime();
  const span = endMs - startMs;
  const dates: Date[] = [];
  for (let i = 0; i < count; i++) {
    const base = startMs + (span * i) / count;
    const jitter = (rand() - 0.5) * 2 * 86400000;
    const ms = Math.max(startMs, Math.min(endMs, base + jitter));
    const d = new Date(ms);
    d.setHours(0, 0, 0, 0);
    dates.push(d);
  }
  return dates.sort((a, b) => a.getTime() - b.getTime());
}

// ════════════════════════════════════════════════════════════
// MAIN SEED CLASS
// ════════════════════════════════════════════════════════════

class CleanSeed {
  private mgr: any;
  private mgrUser: any;
  private team: any;
  private clients: any[] = [];
  private roles: any[] = [];
  private venues: any[] = [];
  private staffUsers: any[] = [];
  private tokens: { role: string; name: string; email: string; token: string }[] = [];
  private eventCounts: { name: string; completed: number; accepted: number; open: number; draft: number }[] = [];

  async run() {
    try {
      await this.connect();
      await this.dropAll();
      await this.seedManager();
      await this.seedTeam();
      await this.seedRoles();
      await this.seedClients();
      await this.seedVenues();
      await this.seedTariffs();
      await this.seedStaffUsers();
      await this.seedCompletedEvents();
      await this.seedAcceptedEvents();
      await this.seedOpenEvents();
      await this.seedDraftEvents();
      this.genTokens();
      this.report();
      await mongoose.disconnect();
      console.log('\n   Database disconnected. Clean seed complete!\n');
    } catch (err) {
      console.error('\n   CLEAN SEED FAILED:', err);
      await mongoose.disconnect();
      process.exit(1);
    }
  }

  // ── Connect ─────────────────────────────────────────────
  private async connect() {
    console.log('\n   CONNECTING TO DATABASE...');
    if (!ENV.mongoUri) throw new Error('MONGO_URI required in .env');
    if (!ENV.jwtSecret) throw new Error('BACKEND_JWT_SECRET required in .env');

    const dbName = ENV.nodeEnv === 'production' ? 'nexa_prod' : 'nexa_test';
    await mongoose.connect(ENV.mongoUri.trim(), { dbName });
    console.log(`   Connected to: ${dbName}\n`);
  }

  // ── Drop Everything ─────────────────────────────────────
  private async dropAll() {
    console.log('   DROPPING ALL COLLECTIONS...');
    const names = [
      'users', 'managers', 'teams', 'teammembers', 'clients', 'roles',
      'tariffs', 'venues', 'shifts', 'conversations', 'chatmessages',
      'staffprofiles', 'staffgroups', 'teaminvites', 'notifications',
      'availabilities', 'flaggedattendances', 'aichatsummaries',
      'eventchatmessages', 'teammessages',
    ];
    const db = mongoose.connection.db;
    if (!db) throw new Error('No db connection');
    for (const n of names) {
      try { await db.dropCollection(n); } catch { /* doesn't exist */ }
    }
    console.log(`   Dropped ${names.length} collections\n`);
  }

  // ── Manager (Elena Rivera) ──────────────────────────────
  private async seedManager() {
    console.log('   CREATING MANAGER...');
    const d = MANAGER_DEF;
    const passwordHash = await bcrypt.hash(d.password, 10);

    this.mgrUser = await UserModel.create({
      provider: 'email', subject: d.subject,
      email: d.email, name: d.name,
      first_name: d.first_name, last_name: d.last_name,
      passwordHash,
      subscription_tier: 'pro', subscription_status: 'active',
    });

    this.mgr = await ManagerModel.create({
      provider: 'email', subject: d.subject,
      email: d.email, name: d.name,
      first_name: d.first_name, last_name: d.last_name,
      passwordHash,
      subscription_tier: 'pro', subscription_status: 'active',
      cities: [{ name: `${d.city}, USA`, isTourist: false }],
    });

    console.log(`   + ${d.name} (${d.email}) [${this.mgr._id}]\n`);
  }

  // ── Team ────────────────────────────────────────────────
  private async seedTeam() {
    console.log('   CREATING TEAM...');
    this.team = await TeamModel.create({
      managerId: this.mgr._id,
      name: MANAGER_DEF.teamName,
      description: 'Core event staff for Rivera Events',
      welcomeMessage: 'Welcome to the Rivera Events team!',
    });
    console.log(`   + ${MANAGER_DEF.teamName}\n`);
  }

  // ── 8 Roles ─────────────────────────────────────────────
  private async seedRoles() {
    console.log('   CREATING ROLES...');
    for (const rd of ROLE_DEFS) {
      const r = await RoleModel.create({
        managerId: this.mgr._id,
        name: rd.name,
        normalizedName: rd.name.trim().toLowerCase(),
      });
      this.roles.push(r);
    }
    console.log(`   + ${ROLE_DEFS.map(r => r.name).join(', ')}\n`);
  }

  // ── 5 Clients ───────────────────────────────────────────
  private async seedClients() {
    console.log('   CREATING CLIENTS...');
    for (const cd of CLIENT_DEFS) {
      const c = await ClientModel.create({ managerId: this.mgr._id, name: cd.name });
      this.clients.push(c);
      console.log(`   + ${cd.name}`);
    }
    console.log('');
  }

  // ── 10 Venues ───────────────────────────────────────────
  private async seedVenues() {
    console.log('   CREATING VENUES...');
    for (const v of VENUE_DEFS) {
      const doc = await VenueModel.create({
        managerId: this.mgr._id, name: v.name, address: v.address,
        city: v.city, state: v.state, country: 'USA',
        latitude: v.lat, longitude: v.lng, source: 'manual',
      });
      this.venues.push(doc);
    }
    console.log(`   + ${VENUE_DEFS.length} venues\n`);
  }

  // ── 40 Tariffs (5 clients × 8 roles) ───────────────────
  private async seedTariffs() {
    console.log('   CREATING TARIFFS...');
    const tariffs: any[] = [];
    for (let c = 0; c < this.clients.length; c++) {
      const mult = CLIENT_DEFS[c]!.multiplier;
      for (let r = 0; r < this.roles.length; r++) {
        const rd = ROLE_DEFS[r]!;
        tariffs.push({
          managerId: this.mgr._id,
          clientId: this.clients[c]._id,
          roleId: this.roles[r]._id,
          rate: Math.round(rd.baseRate * mult * 100) / 100,
          currency: 'USD',
          unit: 'hour',
        });
      }
    }
    await TariffModel.insertMany(tariffs);
    console.log(`   + ${tariffs.length} tariffs\n`);
  }

  // ── 5 Staff Users ───────────────────────────────────────
  private async seedStaffUsers() {
    console.log('   CREATING 5 STAFF USERS...');
    const passwordHash = await bcrypt.hash(STAFF_PASSWORD, 10);

    for (const sd of STAFF_DEFS) {
      const user = await UserModel.create({
        provider: 'email',
        subject: sd.email,
        email: sd.email,
        name: `${sd.first} ${sd.last}`,
        first_name: sd.first,
        last_name: sd.last,
        passwordHash,
        subscription_tier: 'pro',
        subscription_status: 'active',
      });
      this.staffUsers.push(user);

      // TeamMember
      await TeamMemberModel.create({
        teamId: this.team._id,
        managerId: this.mgr._id,
        provider: 'email',
        subject: sd.email,
        email: sd.email,
        name: `${sd.first} ${sd.last}`,
        invitedBy: this.mgr._id,
        joinedAt: new Date('2025-01-01'),
        status: 'active',
      });

      // StaffProfile
      const userKey = `email:${sd.email}`;
      await StaffProfileModel.create({
        managerId: this.mgr._id,
        userKey,
        notes: 'Test staff account',
        rating: randomInt(3, 5),
        isFavorite: rand() > 0.5,
        groupIds: [],
      });

      console.log(`   + ${sd.first} ${sd.last} (${sd.email})`);
    }
    console.log('');
  }

  // ── ~250 Completed Events Per Staff ─────────────────────
  private async seedCompletedEvents() {
    console.log('   GENERATING COMPLETED EVENTS (250 per staff, ~1250 total)...');

    const mgrKey = `${this.mgr.provider}:${this.mgr.subject}`;
    const startDate = new Date('2025-01-01');
    const endDate = new Date('2026-02-21');

    for (let si = 0; si < STAFF_DEFS.length; si++) {
      const sd = STAFF_DEFS[si]!;
      const staffKey = `email:${sd.email}`;

      const rawDates = generateSpreadDates(startDate, endDate, 250);
      const seenDays = new Set<string>();
      const uniqueDates = rawDates.filter(d => {
        const key = d.toISOString().slice(0, 10);
        if (seenDays.has(key)) return false;
        seenDays.add(key);
        return true;
      });

      const events: any[] = [];

      for (let ei = 0; ei < uniqueDates.length; ei++) {
        const eventDate = uniqueDates[ei]!;
        const venue = randomPick(VENUE_DEFS);
        const client = randomPick(CLIENT_DEFS);
        const eventName = randomPick(EVENT_NAMES);
        const uniform = randomPick(UNIFORM_POOL);

        const staffRole = sd.roles[ei % sd.roles.length]!;
        const roleDef = ROLE_DEFS.find(r => r.name === staffRole)!;
        const payRate = randomInt(roleDef.payMin, roleDef.payMax);

        const startHour = randomInt(7, 17);
        const duration = randomInt(7, 9);
        const endHour = Math.min(startHour + duration, 23);
        const actualDuration = endHour - startHour;

        const ciDate = new Date(eventDate);
        ciDate.setHours(startHour, randomInt(0, 10), 0);
        const coDate = new Date(eventDate);
        coDate.setHours(endHour, randomInt(0, 20), 0);
        const approvedHours = actualDuration + (rand() > 0.7 ? 0.5 : 0);

        const accepted_staff = [{
          userKey: staffKey,
          provider: 'email',
          subject: sd.email,
          email: sd.email,
          name: `${sd.first} ${sd.last}`,
          first_name: sd.first,
          last_name: sd.last,
          role: staffRole,
          response: 'accepted',
          respondedAt: new Date(eventDate.getTime() - randomInt(2, 7) * 86400000),
          attendance: [{
            clockInAt: ciDate,
            clockOutAt: coDate,
            estimatedHours: actualDuration,
            approvedHours,
            status: 'approved' as const,
            approvedBy: mgrKey,
            approvedAt: new Date(eventDate.getTime() + randomInt(1, 3) * 86400000),
            clockInLocation: {
              latitude: venue.lat + (rand() - 0.5) * 0.0002,
              longitude: venue.lng + (rand() - 0.5) * 0.0002,
              accuracy: randomInt(5, 20),
              source: 'geofence' as const,
            },
            clockOutLocation: {
              latitude: venue.lat + (rand() - 0.5) * 0.0002,
              longitude: venue.lng + (rand() - 0.5) * 0.0002,
              accuracy: randomInt(8, 25),
            },
          }],
        }];

        // Extra role slot for variety (the event had more positions than just this one person)
        const extraRole = randomPick(ROLE_DEFS.filter(r => r.name !== staffRole));
        const rolesArr = [
          { role: staffRole, count: randomInt(2, 4) },
          { role: extraRole.name, count: randomInt(1, 3) },
        ];
        const headcount = rolesArr.reduce((s, r) => s + r.count, 0);

        const role_stats = rolesArr.map(r => {
          const taken = accepted_staff.filter(s => s.role === r.role).length;
          return {
            role: r.role, capacity: r.count, taken,
            remaining: Math.max(0, r.count - taken),
            is_full: taken >= r.count,
          };
        });

        events.push({
          managerId: this.mgr._id,
          status: 'completed',
          publishedAt: new Date(eventDate.getTime() - randomInt(5, 14) * 86400000),
          publishedBy: mgrKey,
          fulfilledAt: new Date(eventDate.getTime() + actualDuration * 3600000),
          visibilityType: rand() > 0.5 ? 'private' : 'public',
          shift_name: `${eventName} - ${client.name}`,
          client_name: client.name,
          event_name: `${eventName} - ${client.name}`,
          date: eventDate,
          start_time: `${String(startHour).padStart(2, '0')}:00`,
          end_time: `${String(endHour).padStart(2, '0')}:00`,
          venue_name: venue.name,
          venue_address: venue.address,
          venue_latitude: venue.lat,
          venue_longitude: venue.lng,
          city: venue.city,
          state: venue.state,
          country: 'USA',
          contact_name: this.mgr.name || 'Manager',
          contact_phone: '+15551234567',
          contact_email: `events@${client.name.toLowerCase().replace(/\s+/g, '')}.com`,
          uniform,
          notes: `${eventName} hosted by ${client.name} at ${venue.name}.`,
          headcount_total: headcount,
          roles: rolesArr,
          accepted_staff,
          declined_staff: [],
          role_stats,
          audience_team_ids: [this.team._id],
          hoursStatus: 'approved',
          hoursApprovedBy: mgrKey,
          hoursApprovedAt: new Date(eventDate.getTime() + randomInt(1, 4) * 86400000),
          chatEnabled: true,
          chatEnabledAt: new Date(eventDate.getTime() - 86400000),
          pay_rate_info: `$${payRate}/hr`,
          version: 0,
        });
      }

      // Insert in batches of 50
      for (let i = 0; i < events.length; i += 50) {
        const batch = events.slice(i, i + 50);
        await EventModel.insertMany(batch);
      }
      console.log(`   + ${sd.first} ${sd.last}: ${events.length} completed events`);
      this.eventCounts.push({ name: `${sd.first} ${sd.last}`, completed: events.length, accepted: 0, open: 0, draft: 0 });
    }
    console.log('');
  }

  // ── 5 Published Events (1 per tester accepted) — "My Events" ──
  private async seedAcceptedEvents() {
    console.log('   GENERATING 5 ACCEPTED EVENTS (1 per tester)...');

    const mgrKey = `${this.mgr.provider}:${this.mgr.subject}`;
    const now = new Date();

    for (let si = 0; si < STAFF_DEFS.length; si++) {
      const sd = STAFF_DEFS[si]!;
      const staffKey = `email:${sd.email}`;

      const eventDate = new Date();
      eventDate.setDate(eventDate.getDate() + 7 + si * 3); // stagger: +7, +10, +13, +16, +19
      eventDate.setHours(0, 0, 0, 0);

      const venue = VENUE_DEFS[si % VENUE_DEFS.length]!;
      const client = CLIENT_DEFS[si % CLIENT_DEFS.length]!;
      const eventName = EVENT_NAMES[si]!;
      const uniform = UNIFORM_POOL[si % UNIFORM_POOL.length]!;
      const staffRole = sd.roles[0]!;
      const roleDef = ROLE_DEFS.find(r => r.name === staffRole)!;
      const payRate = randomInt(roleDef.payMin, roleDef.payMax);
      const startHour = 10 + si; // stagger start times
      const endHour = Math.min(startHour + 8, 23);

      const accepted_staff = [{
        userKey: staffKey,
        provider: 'email',
        subject: sd.email,
        email: sd.email,
        name: `${sd.first} ${sd.last}`,
        first_name: sd.first,
        last_name: sd.last,
        role: staffRole,
        response: 'accepted',
        respondedAt: new Date(now.getTime() - randomInt(1, 3) * 86400000),
        attendance: [],
      }];

      const extraRole = randomPick(ROLE_DEFS.filter(r => r.name !== staffRole));
      const rolesArr = [
        { role: staffRole, count: 3 },
        { role: extraRole.name, count: 2 },
      ];
      const headcount = rolesArr.reduce((s, r) => s + r.count, 0);
      const role_stats = rolesArr.map(r => {
        const taken = accepted_staff.filter(s => s.role === r.role).length;
        return {
          role: r.role, capacity: r.count, taken,
          remaining: Math.max(0, r.count - taken),
          is_full: taken >= r.count,
        };
      });

      await EventModel.create({
        managerId: this.mgr._id,
        status: 'published',
        publishedAt: new Date(now.getTime() - randomInt(1, 5) * 86400000),
        publishedBy: mgrKey,
        visibilityType: 'public',
        shift_name: `${eventName} - ${client.name}`,
        client_name: client.name,
        event_name: `${eventName} - ${client.name}`,
        date: eventDate,
        start_time: `${String(startHour).padStart(2, '0')}:00`,
        end_time: `${String(endHour).padStart(2, '0')}:00`,
        venue_name: venue.name,
        venue_address: venue.address,
        venue_latitude: venue.lat,
        venue_longitude: venue.lng,
        city: venue.city,
        state: venue.state,
        country: 'USA',
        contact_name: this.mgr.name || 'Manager',
        contact_phone: '+15551234567',
        contact_email: `events@${client.name.toLowerCase().replace(/\s+/g, '')}.com`,
        uniform,
        notes: `${eventName} hosted by ${client.name} at ${venue.name}. Staff confirmed.`,
        headcount_total: headcount,
        roles: rolesArr,
        accepted_staff,
        declined_staff: [],
        role_stats,
        audience_team_ids: [this.team._id],
        hoursStatus: 'pending',
        chatEnabled: true,
        chatEnabledAt: new Date(now.getTime() - 86400000),
        pay_rate_info: `$${payRate}/hr`,
        version: 0,
      });

      console.log(`   + ${sd.first}: "${eventName}" on ${eventDate.toISOString().slice(0, 10)}`);
      const ec = this.eventCounts.find(e => e.name === `${sd.first} ${sd.last}`);
      if (ec) ec.accepted = 1;
    }
    console.log('');
  }

  // ── 5 Published Events (open, no accepted_staff) — "Available" ──
  private async seedOpenEvents() {
    console.log('   GENERATING 5 OPEN EVENTS (available to all staff)...');

    const mgrKey = `${this.mgr.provider}:${this.mgr.subject}`;
    const now = new Date();

    for (let i = 0; i < 5; i++) {
      const eventDate = new Date();
      eventDate.setDate(eventDate.getDate() + 5 + i * 4); // +5, +9, +13, +17, +21
      eventDate.setHours(0, 0, 0, 0);

      const venue = VENUE_DEFS[(i + 5) % VENUE_DEFS.length]!;
      const client = CLIENT_DEFS[i % CLIENT_DEFS.length]!;
      const eventName = EVENT_NAMES[10 + i]!;
      const uniform = UNIFORM_POOL[i % UNIFORM_POOL.length]!;
      const primaryRole = ROLE_DEFS[i % ROLE_DEFS.length]!;
      const secondaryRole = ROLE_DEFS[(i + 3) % ROLE_DEFS.length]!;
      const payRate = randomInt(primaryRole.payMin, primaryRole.payMax);
      const startHour = 9 + i;
      const endHour = Math.min(startHour + 8, 23);

      const rolesArr = [
        { role: primaryRole.name, count: randomInt(3, 5) },
        { role: secondaryRole.name, count: randomInt(2, 3) },
      ];
      const headcount = rolesArr.reduce((s, r) => s + r.count, 0);
      const role_stats = rolesArr.map(r => ({
        role: r.role, capacity: r.count, taken: 0,
        remaining: r.count, is_full: false,
      }));

      await EventModel.create({
        managerId: this.mgr._id,
        status: 'published',
        publishedAt: new Date(now.getTime() - randomInt(1, 3) * 86400000),
        publishedBy: mgrKey,
        visibilityType: 'public',
        shift_name: `${eventName} - ${client.name}`,
        client_name: client.name,
        event_name: `${eventName} - ${client.name}`,
        date: eventDate,
        start_time: `${String(startHour).padStart(2, '0')}:00`,
        end_time: `${String(endHour).padStart(2, '0')}:00`,
        venue_name: venue.name,
        venue_address: venue.address,
        venue_latitude: venue.lat,
        venue_longitude: venue.lng,
        city: venue.city,
        state: venue.state,
        country: 'USA',
        contact_name: this.mgr.name || 'Manager',
        contact_phone: '+15551234567',
        contact_email: `events@${client.name.toLowerCase().replace(/\s+/g, '')}.com`,
        uniform,
        notes: `${eventName} hosted by ${client.name} at ${venue.name}. Open to all team members.`,
        headcount_total: headcount,
        roles: rolesArr,
        accepted_staff: [],
        declined_staff: [],
        role_stats,
        audience_team_ids: [this.team._id],
        hoursStatus: 'pending',
        chatEnabled: false,
        pay_rate_info: `$${payRate}/hr`,
        version: 0,
      });

      console.log(`   + Open: "${eventName}" on ${eventDate.toISOString().slice(0, 10)}`);
    }
    console.log('');
  }

  // ── 10 Draft Events — invisible to all staff ────────────
  private async seedDraftEvents() {
    console.log('   GENERATING 10 DRAFT EVENTS (invisible to staff)...');

    const mgrKey = `${this.mgr.provider}:${this.mgr.subject}`;

    for (let i = 0; i < 10; i++) {
      const eventDate = new Date();
      eventDate.setDate(eventDate.getDate() + 10 + i * 2);
      eventDate.setHours(0, 0, 0, 0);

      const venue = VENUE_DEFS[i % VENUE_DEFS.length]!;
      const client = CLIENT_DEFS[i % CLIENT_DEFS.length]!;
      const eventName = EVENT_NAMES[20 + (i % EVENT_NAMES.length)]!;
      const primaryRole = ROLE_DEFS[i % ROLE_DEFS.length]!;
      const startHour = 10 + (i % 6);
      const endHour = Math.min(startHour + 8, 23);

      const rolesArr = [
        { role: primaryRole.name, count: randomInt(2, 4) },
      ];
      const headcount = rolesArr.reduce((s, r) => s + r.count, 0);
      const role_stats = rolesArr.map(r => ({
        role: r.role, capacity: r.count, taken: 0,
        remaining: r.count, is_full: false,
      }));

      await EventModel.create({
        managerId: this.mgr._id,
        status: 'draft',
        visibilityType: 'public',
        shift_name: `[DRAFT] ${eventName} - ${client.name}`,
        client_name: client.name,
        event_name: `[DRAFT] ${eventName} - ${client.name}`,
        date: eventDate,
        start_time: `${String(startHour).padStart(2, '0')}:00`,
        end_time: `${String(endHour).padStart(2, '0')}:00`,
        venue_name: venue.name,
        venue_address: venue.address,
        venue_latitude: venue.lat,
        venue_longitude: venue.lng,
        city: venue.city,
        state: venue.state,
        country: 'USA',
        contact_name: this.mgr.name || 'Manager',
        contact_phone: '+15551234567',
        uniform: randomPick(UNIFORM_POOL),
        notes: `Draft event — not yet published.`,
        headcount_total: headcount,
        roles: rolesArr,
        accepted_staff: [],
        declined_staff: [],
        role_stats,
        audience_team_ids: [this.team._id],
        hoursStatus: 'pending',
        chatEnabled: false,
        pay_rate_info: `$${randomInt(20, 30)}/hr`,
        version: 0,
      });
    }
    console.log(`   + 10 draft events created\n`);
  }

  // ── JWT Tokens ──────────────────────────────────────────
  private genTokens() {
    console.log('   GENERATING JWT TOKENS (30-day expiry)...');

    // Manager token
    const mgrToken = jwt.sign(
      { sub: this.mgr.subject, provider: this.mgr.provider, email: this.mgr.email, name: this.mgr.name, managerId: this.mgr._id.toString() },
      ENV.jwtSecret,
      { algorithm: 'HS256', expiresIn: '30d' },
    );
    this.tokens.push({ role: 'MANAGER', name: this.mgr.name, email: this.mgr.email, token: mgrToken });

    // Staff tokens
    for (const s of this.staffUsers) {
      const token = jwt.sign(
        { sub: s.subject, provider: s.provider, email: s.email, name: s.name },
        ENV.jwtSecret,
        { algorithm: 'HS256', expiresIn: '30d' },
      );
      this.tokens.push({ role: 'STAFF', name: s.name, email: s.email, token });
    }
  }

  // ── Report ─────────────────────────────────────────────
  private report() {
    console.log('\n');
    console.log('='.repeat(65));
    console.log('        CLEAN SEED COMPLETE');
    console.log('='.repeat(65));
    console.log('');
    console.log('EVENT COUNTS PER STAFF:');
    console.log('-'.repeat(65));
    for (const ec of this.eventCounts) {
      console.log(`   ${ec.name.padEnd(25)} ${String(ec.completed).padStart(4)} completed | ${ec.accepted} accepted | ${ec.open} open | ${ec.draft} draft`);
    }
    console.log('');
    console.log('GLOBAL EVENTS:');
    console.log(`   Open (available):  5`);
    console.log(`   Draft (hidden):    10`);
    console.log('');
    console.log('DATA SUMMARY:');
    console.log(`   Manager:          ${MANAGER_DEF.email} (${MANAGER_DEF.name})`);
    console.log(`   Staff Users:      5 (pro subscription)`);
    console.log(`   Roles:            8`);
    console.log(`   Clients:          ${CLIENT_DEFS.length}`);
    console.log(`   Venues:           ${VENUE_DEFS.length}`);
    console.log(`   Tariffs:          ${CLIENT_DEFS.length * ROLE_DEFS.length}`);
    const totalCompleted = this.eventCounts.reduce((s, e) => s + e.completed, 0);
    console.log(`   Total Completed:  ${totalCompleted}`);
    console.log(`   Total Events:     ${totalCompleted + 5 + 5 + 10}`);
    console.log('');
    console.log('-'.repeat(65));
    console.log('LOGIN CREDENTIALS:');
    console.log('-'.repeat(65));
    console.log('');
    console.log(`   [MANAGER] ${MANAGER_DEF.email.padEnd(30)} ${MANAGER_DEF.password}`);
    for (const sd of STAFF_DEFS) {
      console.log(`   [STAFF]   ${sd.email.padEnd(30)} ${STAFF_PASSWORD}`);
    }
    console.log('');
    console.log('-'.repeat(65));
    console.log('JWT TOKENS (Authorization: Bearer <token>):');
    console.log('-'.repeat(65));
    for (const t of this.tokens) {
      console.log(`\n   [${t.role}] ${t.name} (${t.email})`);
      console.log(`   ${t.token}`);
    }
    console.log('');
    console.log('='.repeat(65));
  }
}

// ════════════════════════════════════════════════════════════
// ENTRY POINT
// ════════════════════════════════════════════════════════════

if (require.main === module) {
  new CleanSeed().run();
}
