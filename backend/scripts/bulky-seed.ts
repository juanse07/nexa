/**
 * BULKY TEST SEED SCRIPT
 *
 * Nukes the entire database and creates comprehensive test data:
 * - 3 Managers (User + Manager documents, bypassing OAuth)
 * - 300 Staff Users (100 per manager team)
 * - 3 Exclusive Teams + 3 Shared "All Staff" Teams
 * - High-profile Clients with different tiers
 * - Roles, Venues, Tariffs with varied rates
 * - 90 Past completed Events with attendance (earnings/stats)
 * - 15 Published Events with large headcounts (bulk acceptance)
 * - 6 Draft Events
 * - 60 Chat conversations with messages
 * - Staff Profiles with ratings, groups, favorites
 * - JWT tokens printed at end for auth bypass
 *
 * Usage:
 *   cd backend && npx ts-node scripts/bulky-seed.ts
 *
 * Prerequisites:
 *   - .env with MONGO_URI and BACKEND_JWT_SECRET
 */

import mongoose from 'mongoose';
import jwt from 'jsonwebtoken';
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
import { ConversationModel } from '../src/models/conversation';
import { ChatMessageModel } from '../src/models/chatMessage';
import { StaffProfileModel } from '../src/models/staffProfile';
import { StaffGroupModel } from '../src/models/staffGroup';

// ════════════════════════════════════════════════════════════
// CONFIGURATION
// ════════════════════════════════════════════════════════════

const STAFF_PER_TEAM = 100;
const TOTAL_STAFF = 300;
const PAST_EVENTS_PER_MANAGER = 30;
const PUBLISHED_EVENTS_PER_MANAGER = 5;
const DRAFT_EVENTS_PER_MANAGER = 2;
const CHATS_PER_MANAGER = 20;
const MSG_PER_CHAT_MIN = 3;
const MSG_PER_CHAT_MAX = 10;

// ════════════════════════════════════════════════════════════
// NAME POOLS
// ════════════════════════════════════════════════════════════

const FIRST_NAMES = [
  'James', 'Maria', 'David', 'Sofia', 'Michael', 'Emma', 'Robert', 'Isabella',
  'William', 'Olivia', 'Richard', 'Ava', 'Joseph', 'Mia', 'Thomas', 'Charlotte',
  'Christopher', 'Amelia', 'Daniel', 'Harper', 'Matthew', 'Evelyn', 'Andrew',
  'Abigail', 'Joshua', 'Emily', 'Anthony', 'Ella', 'Kevin', 'Scarlett',
  'Brian', 'Grace', 'Steven', 'Chloe', 'Ryan', 'Lily', 'Jason', 'Aria',
  'Brandon', 'Zoe', 'Carlos', 'Luna', 'Derek', 'Nora', 'Luis', 'Layla',
  'Andre', 'Riley', 'Omar', 'Stella',
];

const LAST_NAMES = [
  'Smith', 'Johnson', 'Williams', 'Brown', 'Jones', 'Garcia', 'Miller', 'Davis',
  'Rodriguez', 'Martinez', 'Hernandez', 'Lopez', 'Gonzalez', 'Wilson', 'Anderson',
  'Thomas', 'Taylor', 'Moore', 'Jackson', 'Martin', 'Lee', 'Perez', 'Thompson',
  'White', 'Harris', 'Sanchez', 'Clark', 'Ramirez', 'Lewis', 'Robinson',
  'Walker', 'Young', 'Allen', 'King', 'Wright', 'Scott', 'Torres', 'Nguyen',
  'Hill', 'Flores', 'Green', 'Adams', 'Nelson', 'Baker', 'Hall', 'Rivera',
  'Campbell', 'Mitchell', 'Carter', 'Roberts',
];

// ════════════════════════════════════════════════════════════
// MANAGER DEFINITIONS
// ════════════════════════════════════════════════════════════

const MANAGER_DEFS = [
  {
    subject: 'mgr-alpha-001', name: 'Carlos Mendez',
    email: 'carlos.mendez@eliteevents.com',
    first_name: 'Carlos', last_name: 'Mendez',
    city: 'Los Angeles', teamName: 'Alpha VIP Team',
  },
  {
    subject: 'mgr-beta-001', name: 'Sarah Chen',
    email: 'sarah.chen@premiumcatering.com',
    first_name: 'Sarah', last_name: 'Chen',
    city: 'New York', teamName: 'Beta Premium Team',
  },
  {
    subject: 'mgr-gamma-001', name: 'Marcus Thompson',
    email: 'marcus.thompson@luxhospitality.com',
    first_name: 'Marcus', last_name: 'Thompson',
    city: 'Miami', teamName: 'Gamma Elite Team',
  },
];

// ════════════════════════════════════════════════════════════
// CLIENT NAMES (high-profile, per manager)
// ════════════════════════════════════════════════════════════

const CLIENT_NAMES_BY_MANAGER = [
  ['Ritz Carlton Events', 'Goldman Sachs Corporate', 'Met Gala Productions', 'Platinum Weddings Co'],
  ['Tesla Launch Events', 'Apple Keynote Catering', 'Michelin Star Group', 'Olympic Committee'],
  ['Forbes Summit Group', 'UN Conference Services', 'Yacht Club International', 'Film Festival VIP'],
];

// ════════════════════════════════════════════════════════════
// ROLES & BASE RATES
// ════════════════════════════════════════════════════════════

const ROLE_DEFS = [
  { name: 'Server', baseRate: 25 },
  { name: 'Bartender', baseRate: 30 },
  { name: 'Host', baseRate: 22 },
  { name: 'Executive Chef', baseRate: 45 },
  { name: 'Event Coordinator', baseRate: 40 },
  { name: 'Security', baseRate: 28 },
  { name: 'Busser', baseRate: 20 },
];

// Client tier multipliers: Standard, Premium, VIP, Ultra-VIP
const TIER_MULTIPLIERS = [1.0, 1.2, 1.5, 1.8];

// ════════════════════════════════════════════════════════════
// VENUES (per manager region)
// ════════════════════════════════════════════════════════════

const VENUES_BY_MANAGER = [
  // LA
  [
    { name: 'The Grand Ballroom', address: '123 Main St', city: 'Los Angeles', state: 'CA', lat: 34.0522, lng: -118.2437 },
    { name: 'Sunset Terrace', address: '456 Ocean Ave', city: 'Santa Monica', state: 'CA', lat: 34.0195, lng: -118.4912 },
    { name: 'Beverly Hills Hotel', address: '9641 Sunset Blvd', city: 'Beverly Hills', state: 'CA', lat: 34.0825, lng: -118.4133 },
    { name: 'LA Convention Center', address: '1201 S Figueroa St', city: 'Los Angeles', state: 'CA', lat: 34.0407, lng: -118.2697 },
    { name: 'Malibu Beach Club', address: '22878 Pacific Coast Hwy', city: 'Malibu', state: 'CA', lat: 34.0259, lng: -118.7798 },
  ],
  // NYC
  [
    { name: 'The Plaza Hotel', address: '768 5th Ave', city: 'New York', state: 'NY', lat: 40.7645, lng: -73.9746 },
    { name: 'Chelsea Piers Events', address: '62 Chelsea Piers', city: 'New York', state: 'NY', lat: 40.7466, lng: -74.0082 },
    { name: 'Brooklyn Botanic Garden', address: '990 Washington Ave', city: 'Brooklyn', state: 'NY', lat: 40.6694, lng: -73.9624 },
    { name: 'Gotham Hall', address: '1356 Broadway', city: 'New York', state: 'NY', lat: 40.7504, lng: -73.9879 },
    { name: 'Hudson Yards Pavilion', address: '20 Hudson Yards', city: 'New York', state: 'NY', lat: 40.7537, lng: -74.0020 },
  ],
  // Miami
  [
    { name: 'Faena Hotel', address: '3201 Collins Ave', city: 'Miami Beach', state: 'FL', lat: 25.8119, lng: -80.1225 },
    { name: 'Vizcaya Museum', address: '3251 S Miami Ave', city: 'Miami', state: 'FL', lat: 25.7443, lng: -80.2109 },
    { name: 'Perez Art Museum', address: '1103 Biscayne Blvd', city: 'Miami', state: 'FL', lat: 25.7859, lng: -80.1863 },
    { name: 'Fontainebleau Miami', address: '4441 Collins Ave', city: 'Miami Beach', state: 'FL', lat: 25.8207, lng: -80.1228 },
    { name: 'Wynwood Walls Events', address: '2520 NW 2nd Ave', city: 'Miami', state: 'FL', lat: 25.8013, lng: -80.1993 },
  ],
];

// ════════════════════════════════════════════════════════════
// EVENT TYPES
// ════════════════════════════════════════════════════════════

const EVENT_TYPES = [
  { name: 'Corporate Gala', duration: 6, uniform: 'Black tie formal' },
  { name: 'Wedding Reception', duration: 7, uniform: 'White shirt, black vest, black pants' },
  { name: 'Product Launch', duration: 5, uniform: 'All black attire' },
  { name: 'Charity Fundraiser', duration: 6, uniform: 'Black pants, white button-down' },
  { name: 'Private Dinner', duration: 4, uniform: 'Formal service attire' },
  { name: 'Conference Banquet', duration: 8, uniform: 'Business formal' },
  { name: 'VIP Cocktail Party', duration: 5, uniform: 'Black on black' },
  { name: 'Award Ceremony', duration: 6, uniform: 'Full formal uniform' },
];

// ════════════════════════════════════════════════════════════
// CHAT TEMPLATES
// ════════════════════════════════════════════════════════════

const MGR_MSGS = [
  'Hi! Are you available for this weekend?',
  'Great job at the last event! The client specifically mentioned you.',
  'We have a big gala coming up next Saturday. Interested?',
  'Can you confirm your availability for the corporate event on Friday?',
  'Reminder: Please arrive 30 minutes early for setup.',
  'The dress code has been updated - please check the event details.',
  'You did amazing work last night. Thank you!',
  'We need extra hands for the wedding on Sunday. Can you make it?',
  'Just sent you a new event invitation. Let me know!',
  'Quick update: the venue address has changed for tomorrow.',
];

const STAFF_MSGS = [
  'Yes, I\'m available! What time should I be there?',
  'Thank you! It was a great event to work.',
  'I\'d love to! What role would I be filling?',
  'Confirmed! I\'ll be there.',
  'Will do, thanks for the heads up!',
  'Got it, I\'ll check now.',
  'Thanks for the kind words! Looking forward to the next one.',
  'I can make it! Do I need any special equipment?',
  'Sounds great, I\'m in!',
  'Thanks for letting me know. See you tomorrow!',
];

// ════════════════════════════════════════════════════════════
// STAFF GROUP DEFINITIONS
// ════════════════════════════════════════════════════════════

const GROUP_DEFS = [
  { name: 'A-Team Elite', color: '#FFD700' },
  { name: 'Experienced Veterans', color: '#4CAF50' },
  { name: 'Rising Stars', color: '#2196F3' },
  { name: 'New Recruits', color: '#FF9800' },
];

// ════════════════════════════════════════════════════════════
// UTILITIES
// ════════════════════════════════════════════════════════════

function rand(min: number, max: number): number {
  return Math.floor(Math.random() * (max - min + 1)) + min;
}

function pick<T>(arr: T[]): T {
  return arr[Math.floor(Math.random() * arr.length)];
}

function pickN<T>(arr: T[], n: number): T[] {
  const shuffled = [...arr].sort(() => Math.random() - 0.5);
  return shuffled.slice(0, Math.min(n, arr.length));
}

function staffName(index: number): { first_name: string; last_name: string; name: string } {
  const f = FIRST_NAMES[index % FIRST_NAMES.length];
  const l = LAST_NAMES[Math.floor(index / FIRST_NAMES.length) % LAST_NAMES.length];
  const cycle = Math.floor(index / (FIRST_NAMES.length * LAST_NAMES.length));
  const suffix = cycle > 0 ? ` ${String.fromCharCode(65 + cycle)}` : '';
  return { first_name: f, last_name: `${l}${suffix}`, name: `${f} ${l}${suffix}` };
}

function daysAgo(n: number): Date {
  const d = new Date(); d.setDate(d.getDate() - n); d.setHours(0, 0, 0, 0); return d;
}

function daysAhead(n: number): Date {
  const d = new Date(); d.setDate(d.getDate() + n); d.setHours(0, 0, 0, 0); return d;
}

// ════════════════════════════════════════════════════════════
// MAIN SEED CLASS
// ════════════════════════════════════════════════════════════

class BulkySeed {
  private managers: any[] = [];
  private staff: any[] = [];
  private exTeams: any[] = [];
  private shTeams: any[] = [];
  private clients: any[][] = [];
  private roles: any[][] = [];
  private venues: any[][] = [];
  private groups: any[][] = [];
  private tokens: { role: string; name: string; email: string; token: string }[] = [];

  async run() {
    try {
      await this.connect();
      await this.dropAll();
      await this.seedManagers();
      await this.seedStaff();
      await this.seedTeams();
      await this.seedTeamMembers();
      await this.seedClients();
      await this.seedRoles();
      await this.seedVenues();
      await this.seedTariffs();
      await this.seedGroupsAndProfiles();
      await this.seedPastEvents();
      await this.seedPublishedEvents();
      await this.seedDraftEvents();
      await this.seedChat();
      this.genTokens();
      this.report();
      await mongoose.disconnect();
      console.log('\n   Database disconnected. Happy testing!\n');
    } catch (err) {
      console.error('\n   SEED FAILED:', err);
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
    let uri = ENV.mongoUri.trim().replace(/\/$/, '');
    // Insert DB name before query string: ...mongodb.net/?opts → ...mongodb.net/dbName?opts
    const qIdx = uri.indexOf('?');
    if (qIdx !== -1) {
      const base = uri.substring(0, qIdx).replace(/\/$/, '');
      const query = uri.substring(qIdx);
      uri = `${base}/${dbName}${query}`;
    } else {
      uri = `${uri}/${dbName}`;
    }
    await mongoose.connect(uri);
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

  // ── Phase 1: Managers ───────────────────────────────────
  private async seedManagers() {
    console.log('   CREATING 3 MANAGERS...');
    for (const def of MANAGER_DEFS) {
      await UserModel.create({
        provider: 'google', subject: def.subject,
        email: def.email, name: def.name,
        first_name: def.first_name, last_name: def.last_name,
        subscription_tier: 'pro', subscription_status: 'active',
      });

      const mgr = await ManagerModel.create({
        provider: 'google', subject: def.subject,
        email: def.email, name: def.name,
        first_name: def.first_name, last_name: def.last_name,
        subscription_tier: 'pro', subscription_status: 'active',
        cities: [{ name: `${def.city}, USA`, isTourist: false }],
      });
      this.managers.push(mgr);
      console.log(`   + ${def.name} (${def.email}) [${mgr._id}]`);
    }
    console.log('');
  }

  // ── Phase 2: 300 Staff ──────────────────────────────────
  private async seedStaff() {
    console.log(`   CREATING ${TOTAL_STAFF} STAFF USERS...`);
    const docs: any[] = [];
    for (let i = 1; i <= TOTAL_STAFF; i++) {
      const { first_name, last_name, name } = staffName(i - 1);
      const id = String(i).padStart(3, '0');
      docs.push({
        provider: 'google', subject: `staff-${id}`,
        email: `staff${id}@test.nexa.com`, name, first_name, last_name,
        subscription_tier: i <= 30 ? 'pro' : 'free',
        subscription_status: 'active',
      });
    }
    this.staff = await UserModel.insertMany(docs);
    console.log(`   + ${this.staff.length} staff created\n`);
  }

  // ── Phase 3: Teams ──────────────────────────────────────
  private async seedTeams() {
    console.log('   CREATING TEAMS...');
    for (let m = 0; m < 3; m++) {
      const mgr = this.managers[m];
      const def = MANAGER_DEFS[m];

      const ex = await TeamModel.create({
        managerId: mgr._id, name: def.teamName,
        description: `Exclusive ${def.city} team`,
        welcomeMessage: `Welcome to ${def.teamName}!`,
      });
      this.exTeams.push(ex);
      console.log(`   + Exclusive: ${def.teamName}`);

      const sh = await TeamModel.create({
        managerId: mgr._id, name: 'All Staff Pool',
        description: 'Cross-manager talent pool with all 300 staff',
        welcomeMessage: 'Welcome to the All Staff Pool!',
      });
      this.shTeams.push(sh);
      console.log(`   + Shared: All Staff Pool (under ${def.name})`);
    }
    console.log('');
  }

  // ── Phase 4: Team Members ──────────────────────────────
  private async seedTeamMembers() {
    console.log('   CREATING TEAM MEMBERSHIPS...');
    const all: any[] = [];

    for (let m = 0; m < 3; m++) {
      const mgr = this.managers[m];
      const exTeam = this.exTeams[m];
      const shTeam = this.shTeams[m];

      // 100 exclusive members
      const start = m * STAFF_PER_TEAM;
      for (let i = start; i < start + STAFF_PER_TEAM; i++) {
        const s = this.staff[i];
        all.push({
          teamId: exTeam._id, managerId: mgr._id,
          provider: s.provider, subject: s.subject,
          email: s.email, name: s.name,
          invitedBy: mgr._id, joinedAt: daysAgo(rand(30, 90)), status: 'active',
        });
      }

      // ALL 300 in shared team
      for (let i = 0; i < TOTAL_STAFF; i++) {
        const s = this.staff[i];
        all.push({
          teamId: shTeam._id, managerId: mgr._id,
          provider: s.provider, subject: s.subject,
          email: s.email, name: s.name,
          invitedBy: mgr._id, joinedAt: daysAgo(rand(10, 60)), status: 'active',
        });
      }
    }

    // Bulk insert in batches
    for (let i = 0; i < all.length; i += 500) {
      await TeamMemberModel.insertMany(all.slice(i, i + 500));
    }
    console.log(`   + ${all.length} memberships (300 exclusive + 900 shared)\n`);
  }

  // ── Phase 5: Clients ────────────────────────────────────
  private async seedClients() {
    console.log('   CREATING HIGH-PROFILE CLIENTS...');
    for (let m = 0; m < 3; m++) {
      const mgr = this.managers[m];
      const mgrClients: any[] = [];
      for (const cname of CLIENT_NAMES_BY_MANAGER[m]) {
        const c = await ClientModel.create({ managerId: mgr._id, name: cname });
        mgrClients.push(c);
        console.log(`   + ${MANAGER_DEFS[m].name} -> ${cname}`);
      }
      this.clients.push(mgrClients);
    }
    console.log('');
  }

  // ── Phase 6: Roles ──────────────────────────────────────
  private async seedRoles() {
    console.log('   CREATING ROLES...');
    for (let m = 0; m < 3; m++) {
      const mgr = this.managers[m];
      const mgrRoles: any[] = [];
      for (const rd of ROLE_DEFS) {
        const r = await RoleModel.create({ managerId: mgr._id, name: rd.name });
        mgrRoles.push(r);
      }
      this.roles.push(mgrRoles);
      console.log(`   + ${MANAGER_DEFS[m].name}: ${ROLE_DEFS.map(r => r.name).join(', ')}`);
    }
    console.log('');
  }

  // ── Phase 7: Venues ─────────────────────────────────────
  private async seedVenues() {
    console.log('   CREATING VENUES...');
    for (let m = 0; m < 3; m++) {
      const mgr = this.managers[m];
      const mgrVenues: any[] = [];
      for (const v of VENUES_BY_MANAGER[m]) {
        const doc = await VenueModel.create({
          managerId: mgr._id, name: v.name, address: v.address,
          city: v.city, state: v.state, country: 'USA',
          latitude: v.lat, longitude: v.lng, source: 'manual',
        });
        mgrVenues.push(doc);
      }
      this.venues.push(mgrVenues);
      console.log(`   + ${MANAGER_DEFS[m].name}: ${VENUES_BY_MANAGER[m].length} venues`);
    }
    console.log('');
  }

  // ── Phase 8: Tariffs ────────────────────────────────────
  private async seedTariffs() {
    console.log('   CREATING TARIFFS...');
    const tariffs: any[] = [];
    for (let m = 0; m < 3; m++) {
      const mgr = this.managers[m];
      for (let c = 0; c < this.clients[m].length; c++) {
        const mult = TIER_MULTIPLIERS[c];
        for (let r = 0; r < this.roles[m].length; r++) {
          tariffs.push({
            managerId: mgr._id,
            clientId: this.clients[m][c]._id,
            roleId: this.roles[m][r]._id,
            rate: Math.round(ROLE_DEFS[r].baseRate * mult),
            currency: 'USD',
          });
        }
      }
    }
    await TariffModel.insertMany(tariffs);
    console.log(`   + ${tariffs.length} tariffs ($20/hr Busser Standard -> $81/hr Chef Ultra-VIP)\n`);
  }

  // ── Phase 9: Staff Groups & Profiles ────────────────────
  private async seedGroupsAndProfiles() {
    console.log('   CREATING STAFF GROUPS & PROFILES...');
    for (let m = 0; m < 3; m++) {
      const mgr = this.managers[m];
      const start = m * STAFF_PER_TEAM;
      const mgrGroups: any[] = [];

      for (const gd of GROUP_DEFS) {
        const g = await StaffGroupModel.create({
          managerId: mgr._id, name: gd.name, color: gd.color,
        });
        mgrGroups.push(g);
      }
      this.groups.push(mgrGroups);

      const profiles: any[] = [];
      for (let i = 0; i < STAFF_PER_TEAM; i++) {
        const s = this.staff[start + i];
        const uk = `${s.provider}:${s.subject}`;
        let rating = 0, isFavorite = false, groupIds: any[] = [];

        if (i < 10) { rating = 5; isFavorite = true; groupIds = [mgrGroups[0]._id]; }
        else if (i < 40) { rating = 4; groupIds = [mgrGroups[1]._id]; }
        else if (i < 70) { rating = 3; groupIds = [mgrGroups[2]._id]; }
        else { rating = 0; groupIds = [mgrGroups[3]._id]; }

        profiles.push({
          managerId: mgr._id, userKey: uk,
          notes: isFavorite ? 'Top performer - always reliable.' : '',
          rating, isFavorite, groupIds,
        });
      }
      await StaffProfileModel.insertMany(profiles);
      console.log(`   + ${MANAGER_DEFS[m].name}: 4 groups, ${profiles.length} profiles`);
    }
    console.log('');
  }

  // ── Phase 10: Past Completed Events ─────────────────────
  private async seedPastEvents() {
    console.log(`   CREATING ${PAST_EVENTS_PER_MANAGER * 3} PAST COMPLETED EVENTS...`);

    for (let m = 0; m < 3; m++) {
      const mgr = this.managers[m];
      const mClients = this.clients[m];
      const mVenues = this.venues[m];
      const staffStart = m * STAFF_PER_TEAM;
      const mStaff = this.staff.slice(staffStart, staffStart + STAFF_PER_TEAM);
      const events: any[] = [];

      for (let e = 0; e < PAST_EVENTS_PER_MANAGER; e++) {
        const da = rand(3, 90);
        const eventDate = daysAgo(da);
        const et = pick(EVENT_TYPES);
        const client = pick(mClients);
        const venue = pick(mVenues);

        // 2-3 roles per event
        const selRoles = pickN(ROLE_DEFS, rand(2, 3));
        const rolesArr = selRoles.map(r => ({ role: r.name, count: rand(3, 8) }));
        const headcount = rolesArr.reduce((s, r) => s + r.count, 0);

        // Staff for this event
        const staffCount = Math.min(headcount, rand(5, 15));
        const selStaff = pickN(mStaff, staffCount);

        const startH = rand(8, 18);
        const endH = Math.min(startH + et.duration, 23);

        const accepted_staff = selStaff.map((s: any, idx: number) => {
          const role = selRoles[idx % selRoles.length].name;
          const ciDate = new Date(eventDate);
          const coDate = new Date(eventDate);
          ciDate.setHours(startH, rand(0, 15), 0);
          coDate.setHours(endH, rand(0, 30), 0);
          const hrs = Math.round(((coDate.getTime() - ciDate.getTime()) / 3600000) * 10) / 10;

          return {
            userKey: `${s.provider}:${s.subject}`,
            provider: s.provider, subject: s.subject,
            email: s.email, name: s.name,
            first_name: s.first_name, last_name: s.last_name,
            role, response: 'accepted',
            respondedAt: new Date(eventDate.getTime() - rand(1, 5) * 86400000),
            attendance: [{
              clockInAt: ciDate, clockOutAt: coDate,
              estimatedHours: hrs, approvedHours: hrs,
              status: 'approved',
              approvedBy: `google:${mgr.subject}`,
              approvedAt: new Date(eventDate.getTime() + 86400000),
              clockInLocation: {
                latitude: venue.latitude, longitude: venue.longitude,
                accuracy: rand(5, 50), source: 'geofence' as const,
              },
              clockOutLocation: {
                latitude: venue.latitude + (Math.random() * 0.001 - 0.0005),
                longitude: venue.longitude + (Math.random() * 0.001 - 0.0005),
                accuracy: rand(5, 50),
              },
            }],
          };
        });

        const role_stats = rolesArr.map(r => {
          const taken = accepted_staff.filter((s: any) => s.role === r.role).length;
          return {
            role: r.role, capacity: r.count, taken,
            remaining: Math.max(0, r.count - taken),
            is_full: taken >= r.count,
          };
        });

        events.push({
          managerId: mgr._id,
          status: 'completed',
          publishedAt: new Date(eventDate.getTime() - rand(3, 7) * 86400000),
          publishedBy: `google:${mgr.subject}`,
          fulfilledAt: new Date(eventDate.getTime() + et.duration * 3600000),
          visibilityType: pick(['private', 'public'] as const),
          shift_name: `${et.name} - ${client.name}`,
          client_name: client.name,
          date: eventDate,
          start_time: `${String(startH).padStart(2, '0')}:00`,
          end_time: `${String(endH).padStart(2, '0')}:00`,
          venue_name: venue.name, venue_address: venue.address,
          venue_latitude: venue.latitude, venue_longitude: venue.longitude,
          city: venue.city, state: venue.state, country: 'USA',
          contact_name: `${pick(FIRST_NAMES)} ${pick(LAST_NAMES)}`,
          contact_phone: `+1555${rand(1000000, 9999999)}`,
          contact_email: `events@${client.name.toLowerCase().replace(/\s+/g, '')}.com`,
          uniform: et.uniform,
          notes: `${et.name} for ${client.name}. Staff: ${staffCount}.`,
          headcount_total: headcount, roles: rolesArr,
          accepted_staff, declined_staff: [], role_stats,
          audience_team_ids: [this.exTeams[m]._id],
          hoursStatus: 'approved',
          hoursApprovedBy: `google:${mgr.subject}`,
          hoursApprovedAt: new Date(eventDate.getTime() + 2 * 86400000),
          chatEnabled: true,
          chatEnabledAt: new Date(eventDate.getTime() - 86400000),
          version: 0,
        });
      }

      await EventModel.insertMany(events);
      console.log(`   + ${MANAGER_DEFS[m].name}: ${events.length} completed events`);
    }
    console.log('');
  }

  // ── Phase 11: Published Events (bulk acceptance) ────────
  private async seedPublishedEvents() {
    console.log(`   CREATING ${PUBLISHED_EVENTS_PER_MANAGER * 3} PUBLISHED EVENTS...`);

    for (let m = 0; m < 3; m++) {
      const mgr = this.managers[m];
      const mClients = this.clients[m];
      const mVenues = this.venues[m];
      const events: any[] = [];

      for (let e = 0; e < PUBLISHED_EVENTS_PER_MANAGER; e++) {
        const eventDate = daysAhead(rand(3, 14));
        const et = pick(EVENT_TYPES);
        const client = mClients[e % mClients.length];
        const venue = mVenues[e % mVenues.length];

        const rolesArr = [
          { role: 'Server', count: rand(20, 40) },
          { role: 'Bartender', count: rand(10, 20) },
          { role: 'Host', count: rand(5, 10) },
          { role: 'Event Coordinator', count: rand(3, 5) },
          { role: 'Security', count: rand(5, 10) },
        ];
        const headcount = rolesArr.reduce((s, r) => s + r.count, 0);
        const startH = rand(10, 18);
        const endH = Math.min(startH + et.duration, 23);

        const role_stats = rolesArr.map(r => ({
          role: r.role, capacity: r.count, taken: 0,
          remaining: r.count, is_full: false,
        }));

        events.push({
          managerId: mgr._id,
          status: 'published',
          publishedAt: new Date(),
          publishedBy: `google:${mgr.subject}`,
          visibilityType: 'public',
          shift_name: `${et.name} - ${client.name}`,
          client_name: client.name,
          date: eventDate,
          start_time: `${String(startH).padStart(2, '0')}:00`,
          end_time: `${String(endH).padStart(2, '0')}:00`,
          venue_name: venue.name, venue_address: venue.address,
          venue_latitude: venue.latitude, venue_longitude: venue.longitude,
          city: venue.city, state: venue.state, country: 'USA',
          contact_name: `${pick(FIRST_NAMES)} ${pick(LAST_NAMES)}`,
          contact_phone: `+1555${rand(1000000, 9999999)}`,
          contact_email: `events@${client.name.toLowerCase().replace(/\s+/g, '')}.com`,
          uniform: et.uniform,
          notes: `BULK TEST: ${et.name}. Headcount: ${headcount}. All 300 staff eligible.`,
          headcount_total: headcount, roles: rolesArr,
          accepted_staff: [], declined_staff: [], role_stats,
          audience_team_ids: [this.shTeams[m]._id],
          hoursStatus: 'pending',
          chatEnabled: true, chatEnabledAt: new Date(),
          pay_rate_info: `$${ROLE_DEFS[5].baseRate}-${ROLE_DEFS[3].baseRate}/hr depending on role`,
          version: 0,
        });
      }

      await EventModel.insertMany(events);
      console.log(`   + ${MANAGER_DEFS[m].name}: ${events.length} published (headcount ${events.map((e: any) => e.headcount_total).join(', ')})`);
    }
    console.log('');
  }

  // ── Phase 12: Draft Events ──────────────────────────────
  private async seedDraftEvents() {
    console.log(`   CREATING ${DRAFT_EVENTS_PER_MANAGER * 3} DRAFT EVENTS...`);
    for (let m = 0; m < 3; m++) {
      const mgr = this.managers[m];
      const client = this.clients[m][0];
      const venue = this.venues[m][0];
      const events: any[] = [];

      for (let e = 0; e < DRAFT_EVENTS_PER_MANAGER; e++) {
        events.push({
          managerId: mgr._id, status: 'draft', visibilityType: 'private',
          shift_name: `Upcoming ${pick(EVENT_TYPES).name}`,
          client_name: client.name,
          date: daysAhead(rand(14, 30)),
          start_time: '18:00', end_time: '23:00',
          venue_name: venue.name, venue_address: venue.address,
          city: venue.city, state: venue.state, country: 'USA',
          headcount_total: rand(10, 30),
          roles: [
            { role: 'Server', count: rand(5, 15) },
            { role: 'Bartender', count: rand(3, 8) },
          ],
          accepted_staff: [], declined_staff: [], role_stats: [],
          version: 0,
        });
      }
      await EventModel.insertMany(events);
      console.log(`   + ${MANAGER_DEFS[m].name}: ${events.length} drafts`);
    }
    console.log('');
  }

  // ── Phase 13: Chat ──────────────────────────────────────
  private async seedChat() {
    console.log('   CREATING CHAT DATA...');
    for (let m = 0; m < 3; m++) {
      const mgr = this.managers[m];
      const staffStart = m * STAFF_PER_TEAM;
      const chatStaff = pickN(
        this.staff.slice(staffStart, staffStart + STAFF_PER_TEAM),
        CHATS_PER_MANAGER,
      );

      let totalMsgs = 0;
      for (const s of chatStaff) {
        const uk = `${s.provider}:${s.subject}`;
        const msgCount = rand(MSG_PER_CHAT_MIN, MSG_PER_CHAT_MAX);

        const conv = await ConversationModel.create({
          managerId: mgr._id, userKey: uk,
          lastMessageAt: daysAgo(rand(0, 14)),
          lastMessagePreview: pick(STAFF_MSGS).slice(0, 200),
          unreadCountManager: rand(0, 3),
          unreadCountUser: rand(0, 2),
        });

        const msgs: any[] = [];
        for (let i = 0; i < msgCount; i++) {
          const isMgr = i % 2 === 0;
          const msgDate = daysAgo(rand(0, 14));
          msgDate.setHours(rand(8, 22), rand(0, 59), 0, 0);
          msgs.push({
            conversationId: conv._id, managerId: mgr._id, userKey: uk,
            senderType: isMgr ? 'manager' : 'user',
            senderName: isMgr ? mgr.name : s.name,
            message: isMgr ? pick(MGR_MSGS) : pick(STAFF_MSGS),
            messageType: 'text',
            readByManager: !isMgr || Math.random() > 0.3,
            readByUser: isMgr || Math.random() > 0.3,
          });
        }
        await ChatMessageModel.insertMany(msgs);
        totalMsgs += msgs.length;
      }
      console.log(`   + ${MANAGER_DEFS[m].name}: ${CHATS_PER_MANAGER} convos, ${totalMsgs} messages`);
    }
    console.log('');
  }

  // ── Phase 14: JWT Tokens ────────────────────────────────
  private genTokens() {
    console.log('   GENERATING JWT TOKENS (30-day expiry)...');

    // Manager tokens
    for (let m = 0; m < 3; m++) {
      const mgr = this.managers[m];
      const def = MANAGER_DEFS[m];
      const token = jwt.sign(
        {
          sub: def.subject, provider: 'google',
          email: def.email, name: def.name,
          managerId: mgr._id.toString(),
        },
        ENV.jwtSecret,
        { algorithm: 'HS256', expiresIn: '30d' },
      );
      this.tokens.push({ role: 'MANAGER', name: def.name, email: def.email, token });
    }

    // Sample staff tokens (first, middle, last of each team + extras)
    const indices = [0, 49, 99, 100, 149, 199, 200, 249, 299];
    for (const idx of indices) {
      const s = this.staff[idx];
      const token = jwt.sign(
        { sub: s.subject, provider: 'google', email: s.email, name: s.name },
        ENV.jwtSecret,
        { algorithm: 'HS256', expiresIn: '30d' },
      );
      this.tokens.push({ role: 'STAFF', name: s.name, email: s.email, token });
    }
  }

  // ── Phase 15: Report ────────────────────────────────────
  private report() {
    console.log('\n');
    console.log('='.repeat(65));
    console.log('          BULKY SEED COMPLETE - SUMMARY REPORT');
    console.log('='.repeat(65));
    console.log('');
    console.log('DATA CREATED:');
    console.log(`   Managers:           3`);
    console.log(`   Staff Users:        ${TOTAL_STAFF}`);
    console.log(`   Teams:              3 exclusive + 3 shared = 6`);
    console.log(`   Team Members:       1200 (300 exclusive + 900 shared)`);
    console.log(`   Clients:            12 (4 per manager, tiered)`);
    console.log(`   Roles:              21 (7 per manager)`);
    console.log(`   Venues:             15 (5 per manager)`);
    console.log(`   Tariffs:            84 (manager x client x role)`);
    console.log(`   Staff Groups:       12 (4 per manager)`);
    console.log(`   Staff Profiles:     300`);
    console.log(`   Past Events:        ${PAST_EVENTS_PER_MANAGER * 3} (completed, with attendance)`);
    console.log(`   Published Events:   ${PUBLISHED_EVENTS_PER_MANAGER * 3} (for bulk acceptance)`);
    console.log(`   Draft Events:       ${DRAFT_EVENTS_PER_MANAGER * 3}`);
    console.log(`   Chat Conversations: ${CHATS_PER_MANAGER * 3}`);
    console.log('');
    console.log('-'.repeat(65));
    console.log('JWT TOKENS (Authorization: Bearer <token>):');
    console.log('-'.repeat(65));
    for (const t of this.tokens) {
      console.log(`\n   [${t.role}] ${t.name} (${t.email})`);
      console.log(`   ${t.token}`);
    }
    console.log('');
    console.log('-'.repeat(65));
    console.log('TESTING GUIDE:');
    console.log('-'.repeat(65));
    console.log('');
    console.log('1. BULK ACCEPTANCE:');
    console.log('   - 15 published events with 43-85 headcount each');
    console.log('   - All 300 staff can see & accept via shared teams');
    console.log('   - POST /api/events/:id/respond {response:"accepted", role:"Server"}');
    console.log('');
    console.log('2. EARNINGS / STATS:');
    console.log('   - 90 completed events with approved hours & attendance');
    console.log('   - Tariffs link pay rates to (manager, client, role)');
    console.log('   - Each staff member appears in ~4-5 past events');
    console.log('');
    console.log('3. CHAT MESSAGING:');
    console.log('   - 60 conversations with 3-10 messages each');
    console.log('   - Mix of manager/staff messages, some unread');
    console.log('');
    console.log('4. AUTH BYPASS:');
    console.log('   - Use JWT tokens above with any HTTP client (Postman, curl)');
    console.log('   - Header: Authorization: Bearer <token>');
    console.log('   - Manager tokens include managerId for manager routes');
    console.log('   - Staff tokens work for all staff-side routes');
    console.log('');
    console.log('5. STAFF GROUPS & RATINGS:');
    console.log('   - A-Team Elite (10 staff, rating 5, favorites)');
    console.log('   - Experienced Veterans (30 staff, rating 4)');
    console.log('   - Rising Stars (30 staff, rating 3)');
    console.log('   - New Recruits (30 staff, unrated)');
    console.log('');
    console.log('='.repeat(65));
  }
}

// ════════════════════════════════════════════════════════════
// ENTRY POINT
// ════════════════════════════════════════════════════════════

if (require.main === module) {
  new BulkySeed().run();
}
