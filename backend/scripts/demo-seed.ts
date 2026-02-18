/**
 * DEMO SEED SCRIPT — Apple App Store Review Dataset
 *
 * Seeds `nexa_prod` with a rich dataset designed for impressive
 * App Store screenshots and Apple reviewer walkthroughs:
 *
 * - 1 Manager (Elena Rivera)
 * - 10 Staff Users (Marcus Johnson = demo staff login)
 * - 1 Team with all 10 staff
 * - 4 Clients with different pay rate multipliers
 * - 5 Roles (Server, Bartender, Host, Chef, Event Coordinator)
 * - 10 Denver-area Venues
 * - 20 Tariffs (4 clients × 5 roles)
 * - 6 Manager-focused events (3 past + 2 published + 1 draft)
 * - ~260 Staff-focused events (Apr 2025 → Apr 2026)
 *   - ~210 completed with approved hours for Marcus
 *   - ~30 future published (Marcus accepted)
 *   - ~20 future published (open/pending)
 * - 3 Chat conversations with messages
 * - Staff profiles with ratings
 * - JWT tokens printed for quick API testing
 *
 * Usage:
 *   cd backend && npm run seed:demo
 *   (or: NODE_ENV=production npx ts-node scripts/demo-seed.ts)
 *
 * Prerequisites:
 *   - .env with MONGO_URI and BACKEND_JWT_SECRET
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
import { ConversationModel } from '../src/models/conversation';
import { ChatMessageModel } from '../src/models/chatMessage';
import { StaffProfileModel } from '../src/models/staffProfile';
import { StaffGroupModel } from '../src/models/staffGroup';

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

const DEMO_STAFF_DEF = {
  email: 'staff@flowshift.work',
  password: 'FlowShift2024!',
};

const STAFF_DEFS = [
  { first: 'Marcus',  last: 'Johnson',  id: '001' },
  { first: 'Sofia',   last: 'Chen',     id: '002' },
  { first: 'James',   last: 'Williams', id: '003' },
  { first: 'Olivia',  last: 'Martinez', id: '004' },
  { first: 'David',   last: 'Thompson', id: '005' },
  { first: 'Emma',    last: 'Garcia',   id: '006' },
  { first: 'Michael', last: 'Brown',    id: '007' },
  { first: 'Ava',     last: 'Davis',    id: '008' },
  { first: 'Daniel',  last: 'Wilson',   id: '009' },
  { first: 'Isabella',last: 'Lee',      id: '010' },
];

const CLIENT_DEFS = [
  { name: 'The Grand Hyatt Group',      multiplier: 1.0 },
  { name: 'Stellar Productions Inc',    multiplier: 1.3 },
  { name: 'Rocky Mountain Event Co',    multiplier: 1.1 },
  { name: 'Mile High Hospitality Group', multiplier: 1.2 },
];

const ROLE_DEFS = [
  { name: 'Server',            baseRate: 25 },
  { name: 'Bartender',         baseRate: 30 },
  { name: 'Host',              baseRate: 22 },
  { name: 'Chef',              baseRate: 45 },
  { name: 'Event Coordinator', baseRate: 40 },
];

const VENUE_DEFS = [
  { name: 'Four Seasons Hotel Denver',      address: '1111 14th St',             city: 'Denver',      state: 'CO', lat: 39.7447, lng: -104.9997 },
  { name: 'The Ritz-Carlton, Denver',       address: '1881 Curtis St',           city: 'Denver',      state: 'CO', lat: 39.7473, lng: -104.9941 },
  { name: 'Denver Art Museum',              address: '100 W 14th Ave Pkwy',      city: 'Denver',      state: 'CO', lat: 39.7373, lng: -104.9896 },
  { name: 'Colorado Convention Center',     address: '700 14th St',              city: 'Denver',      state: 'CO', lat: 39.7392, lng: -104.9973 },
  { name: 'Ellie Caulkins Opera House',     address: '1385 Curtis St',           city: 'Denver',      state: 'CO', lat: 39.7396, lng: -105.0003 },
  { name: 'Mile High Station',              address: '2027 W Colfax Ave',        city: 'Denver',      state: 'CO', lat: 39.7406, lng: -105.0088 },
  { name: 'The Manor House',               address: '1 Manor House Rd',         city: 'Littleton',   state: 'CO', lat: 39.5853, lng: -105.0144 },
  { name: 'Cielo at Castle Pines',          address: '6380 Village Ln',          city: 'Castle Rock', state: 'CO', lat: 39.4733, lng: -104.8861 },
  { name: 'Della Terra Mountain Chateau',   address: '3501 Fall River Rd',       city: 'Estes Park',  state: 'CO', lat: 40.3883, lng: -105.5858 },
  { name: 'Wellshire Event Center',         address: '3333 S Colorado Blvd',     city: 'Denver',      state: 'CO', lat: 39.6578, lng: -104.9408 },
];

const GROUP_DEFS = [
  { name: 'Top Performers', color: '#FFD700' },
  { name: 'Reliable Staff',  color: '#4CAF50' },
];

const STAFF_EVENT_NAMES = [
  'Corporate Gala', 'Annual Fundraiser', 'Wedding Reception', 'VIP Cocktail Party',
  'Holiday Dinner', 'Product Launch', 'Art Exhibition Opening', 'Wine Tasting Soirée',
  'Charity Auction', 'Award Ceremony', 'Rehearsal Dinner', 'Corporate Retreat',
  'Sports Banquet', 'Birthday Celebration', 'Networking Mixer', 'Fashion Show',
  'Grand Opening', 'Film Premiere', 'Tech Summit Reception', 'Music Festival VIP',
  'New Year\'s Eve Gala', 'Bridal Shower', 'Anniversary Party', 'Retirement Celebration',
  'Memorial Dinner', 'Graduation Party', 'Whiskey Tasting', 'Book Launch',
  'Garden Party', 'Harvest Festival',
];

const UNIFORM_POOL = [
  'Black tie formal',
  'All black attire',
  'White shirt, black vest, black pants',
  'Formal service attire',
  'Black pants, white button-down',
  'Business casual',
  'Black cocktail attire',
  'Chef whites',
  'Black suit, no tie',
  'Smart casual — dark colors',
];

// ════════════════════════════════════════════════════════════
// UTILITIES
// ════════════════════════════════════════════════════════════

function daysAgo(n: number): Date {
  const d = new Date();
  d.setDate(d.getDate() - n);
  d.setHours(0, 0, 0, 0);
  return d;
}

function daysAhead(n: number): Date {
  const d = new Date();
  d.setDate(d.getDate() + n);
  d.setHours(0, 0, 0, 0);
  return d;
}

/** Seeded pseudo-random number generator (Mulberry32) for reproducible data */
function mulberry32(seed: number) {
  return function () {
    let t = (seed += 0x6d2b79f5);
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

const rand = mulberry32(42);

function randomPick<T>(arr: T[]): T {
  return arr[Math.floor(rand() * arr.length)]!;
}

function randomInt(min: number, max: number): number {
  return Math.floor(rand() * (max - min + 1)) + min;
}

/** Generate `count` dates spread across [start, end] with slight random jitter */
function generateSpreadDates(start: Date, end: Date, count: number): Date[] {
  const startMs = start.getTime();
  const endMs = end.getTime();
  const span = endMs - startMs;
  const dates: Date[] = [];
  for (let i = 0; i < count; i++) {
    // Evenly spaced base position + random jitter within ±1 day
    const base = startMs + (span * i) / count;
    const jitter = (rand() - 0.5) * 2 * 86400000; // ±1 day
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

class DemoSeed {
  private mgr: any;
  private mgrUser: any;
  private staff: any[] = [];
  private team: any;
  private clients: any[] = [];
  private roles: any[] = [];
  private venues: any[] = [];
  private groups: any[] = [];
  private tokens: { role: string; name: string; email: string; token: string }[] = [];

  async run() {
    try {
      await this.connect();
      await this.dropAll();
      await this.seedManager();
      await this.seedStaff();
      await this.seedTeam();
      await this.seedTeamMembers();
      await this.seedClients();
      await this.seedRoles();
      await this.seedVenues();
      await this.seedTariffs();
      await this.seedGroupsAndProfiles();
      await this.seedPastEvents();
      await this.seedPublishedEvents();
      await this.seedDraftEvent();
      await this.seedStaffEvents();
      await this.seedChat();
      this.genTokens();
      this.report();
      await mongoose.disconnect();
      console.log('\n   Database disconnected. Demo ready!\n');
    } catch (err) {
      console.error('\n   DEMO SEED FAILED:', err);
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

  // ── Manager ─────────────────────────────────────────────
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

  // ── 10 Staff ────────────────────────────────────────────
  private async seedStaff() {
    console.log('   CREATING 10 STAFF USERS...');
    const staffPasswordHash = await bcrypt.hash(DEMO_STAFF_DEF.password, 10);

    const docs = await Promise.all(STAFF_DEFS.map(async (s, i) => {
      const isDemo = i === 0; // Marcus Johnson = demo staff login
      return {
        provider: isDemo ? ('email' as const) : ('google' as const),
        subject: isDemo ? DEMO_STAFF_DEF.email : `demo-staff-${s.id}`,
        email: isDemo ? DEMO_STAFF_DEF.email : `${s.first.toLowerCase()}.${s.last.toLowerCase()}@nexademo.com`,
        name: `${s.first} ${s.last}`,
        first_name: s.first,
        last_name: s.last,
        phone_number: isDemo ? '+15551234567' : undefined,
        passwordHash: isDemo ? staffPasswordHash : undefined,
        subscription_tier: 'free',
        subscription_status: 'active',
      };
    }));
    this.staff = await UserModel.insertMany(docs);
    console.log(`   + ${this.staff.length} staff created (${DEMO_STAFF_DEF.email} = Marcus Johnson)\n`);
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

  // ── Team Members ────────────────────────────────────────
  private async seedTeamMembers() {
    console.log('   CREATING TEAM MEMBERSHIPS...');
    const docs = this.staff.map((s: any) => ({
      teamId: this.team._id,
      managerId: this.mgr._id,
      provider: s.provider,
      subject: s.subject,
      email: s.email,
      name: s.name,
      invitedBy: this.mgr._id,
      joinedAt: daysAgo(30),
      status: 'active',
    }));
    await TeamMemberModel.insertMany(docs);
    console.log(`   + ${docs.length} memberships\n`);
  }

  // ── Clients ─────────────────────────────────────────────
  private async seedClients() {
    console.log('   CREATING CLIENTS...');
    for (const cd of CLIENT_DEFS) {
      const c = await ClientModel.create({ managerId: this.mgr._id, name: cd.name });
      this.clients.push(c);
      console.log(`   + ${cd.name}`);
    }
    console.log('');
  }

  // ── Roles ───────────────────────────────────────────────
  private async seedRoles() {
    console.log('   CREATING ROLES...');
    for (const rd of ROLE_DEFS) {
      const r = await RoleModel.create({ managerId: this.mgr._id, name: rd.name });
      this.roles.push(r);
    }
    console.log(`   + ${ROLE_DEFS.map(r => r.name).join(', ')}\n`);
  }

  // ── Venues ──────────────────────────────────────────────
  private async seedVenues() {
    console.log('   CREATING VENUES...');
    for (const v of VENUE_DEFS) {
      const doc = await VenueModel.create({
        managerId: this.mgr._id, name: v.name, address: v.address,
        city: v.city, state: v.state, country: 'USA',
        latitude: v.lat, longitude: v.lng, source: 'manual',
      });
      this.venues.push(doc);
      console.log(`   + ${v.name}`);
    }
    console.log('');
  }

  // ── Tariffs ─────────────────────────────────────────────
  private async seedTariffs() {
    console.log('   CREATING TARIFFS...');
    const tariffs: any[] = [];
    for (let c = 0; c < this.clients.length; c++) {
      const mult = CLIENT_DEFS[c]!.multiplier;
      for (let r = 0; r < this.roles.length; r++) {
        tariffs.push({
          managerId: this.mgr._id,
          clientId: this.clients[c]._id,
          roleId: this.roles[r]._id,
          rate: Math.round(ROLE_DEFS[r]!.baseRate * mult),
          currency: 'USD',
        });
      }
    }
    await TariffModel.insertMany(tariffs);
    console.log(`   + ${tariffs.length} tariffs\n`);
  }

  // ── Staff Groups & Profiles ─────────────────────────────
  private async seedGroupsAndProfiles() {
    console.log('   CREATING STAFF GROUPS & PROFILES...');
    for (const gd of GROUP_DEFS) {
      const g = await StaffGroupModel.create({
        managerId: this.mgr._id, name: gd.name, color: gd.color,
      });
      this.groups.push(g);
    }

    const profiles = this.staff.map((s: any, i: number) => {
      const uk = `${s.provider}:${s.subject}`;
      const isTop = i < 4; // first 4 are top performers
      return {
        managerId: this.mgr._id,
        userKey: uk,
        notes: isTop ? 'Consistently excellent — top performer.' : '',
        rating: isTop ? 5 : (i < 7 ? 4 : 3),
        isFavorite: isTop,
        groupIds: isTop ? [this.groups[0]._id] : [this.groups[1]._id],
      };
    });
    await StaffProfileModel.insertMany(profiles);
    console.log(`   + ${GROUP_DEFS.length} groups, ${profiles.length} profiles\n`);
  }

  // ── 3 Past Completed Events ─────────────────────────────
  private async seedPastEvents() {
    console.log('   CREATING 3 PAST COMPLETED EVENTS...');
    const eventDefs = [
      { name: 'Corporate Gala',       daysBack: 14, client: 0, venue: 0, startH: 18, dur: 5, uniform: 'Black tie formal' },
      { name: 'Private Dinner',       daysBack: 7,  client: 1, venue: 1, startH: 19, dur: 4, uniform: 'Formal service attire' },
      { name: 'Charity Fundraiser',   daysBack: 3,  client: 0, venue: 2, startH: 17, dur: 6, uniform: 'Black pants, white button-down' },
    ];

    for (const ed of eventDefs) {
      const eventDate = daysAgo(ed.daysBack);
      const client = this.clients[ed.client];
      const venue = this.venues[ed.venue];
      const endH = ed.startH + ed.dur;

      // Use 6 staff per past event
      const selStaff = this.staff.slice(0, 6);
      const rolesArr = [
        { role: 'Server', count: 3 },
        { role: 'Bartender', count: 2 },
        { role: 'Event Coordinator', count: 1 },
      ];
      const headcount = rolesArr.reduce((s, r) => s + r.count, 0);

      const roleAssign = ['Server', 'Server', 'Server', 'Bartender', 'Bartender', 'Event Coordinator'];
      const accepted_staff = selStaff.map((s: any, idx: number) => {
        const role = roleAssign[idx];
        const ciDate = new Date(eventDate); ciDate.setHours(ed.startH, 0, 0);
        const coDate = new Date(eventDate); coDate.setHours(endH, 0, 0);
        const hrs = ed.dur;

        return {
          userKey: `${s.provider}:${s.subject}`,
          provider: s.provider, subject: s.subject,
          email: s.email, name: s.name,
          first_name: s.first_name, last_name: s.last_name,
          role, response: 'accepted',
          respondedAt: new Date(eventDate.getTime() - 2 * 86400000),
          attendance: [{
            clockInAt: ciDate, clockOutAt: coDate,
            estimatedHours: hrs, approvedHours: hrs,
            status: 'approved',
            approvedBy: `${this.mgr.provider}:${this.mgr.subject}`,
            approvedAt: new Date(eventDate.getTime() + 86400000),
            clockInLocation: {
              latitude: venue.latitude, longitude: venue.longitude,
              accuracy: 10, source: 'geofence' as const,
            },
            clockOutLocation: {
              latitude: venue.latitude, longitude: venue.longitude,
              accuracy: 12,
            },
          }],
        };
      });

      const role_stats = rolesArr.map(r => {
        const taken = accepted_staff.filter((s: any) => s.role === r.role).length;
        return { role: r.role, capacity: r.count, taken, remaining: 0, is_full: true };
      });

      await EventModel.create({
        managerId: this.mgr._id,
        status: 'completed',
        publishedAt: new Date(eventDate.getTime() - 5 * 86400000),
        publishedBy: `${this.mgr.provider}:${this.mgr.subject}`,
        fulfilledAt: new Date(eventDate.getTime() + ed.dur * 3600000),
        visibilityType: 'private',
        shift_name: `${ed.name} - ${client.name}`,
        client_name: client.name,
        date: eventDate,
        start_time: `${String(ed.startH).padStart(2, '0')}:00`,
        end_time: `${String(endH).padStart(2, '0')}:00`,
        venue_name: venue.name, venue_address: venue.address,
        venue_latitude: venue.latitude, venue_longitude: venue.longitude,
        city: venue.city, state: venue.state, country: 'USA',
        contact_name: 'Elena Rivera',
        contact_phone: '+15551234567',
        contact_email: `events@${client.name.toLowerCase().replace(/\s+/g, '')}.com`,
        uniform: ed.uniform,
        notes: `${ed.name} for ${client.name}.`,
        headcount_total: headcount, roles: rolesArr,
        accepted_staff, declined_staff: [], role_stats,
        audience_team_ids: [this.team._id],
        hoursStatus: 'approved',
        hoursApprovedBy: `${this.mgr.provider}:${this.mgr.subject}`,
        hoursApprovedAt: new Date(eventDate.getTime() + 2 * 86400000),
        chatEnabled: true,
        chatEnabledAt: new Date(eventDate.getTime() - 86400000),
        version: 0,
      });
      console.log(`   + ${ed.name} (${ed.daysBack} days ago)`);
    }
    console.log('');
  }

  // ── 2 Published Events ──────────────────────────────────
  private async seedPublishedEvents() {
    console.log('   CREATING 2 PUBLISHED EVENTS...');
    const pubDefs = [
      { name: 'VIP Cocktail Party', daysOut: 5,  client: 1, venue: 0, startH: 19, dur: 4, uniform: 'All black attire' },
      { name: 'Wedding Reception',  daysOut: 10, client: 0, venue: 1, startH: 16, dur: 7, uniform: 'White shirt, black vest, black pants' },
    ];

    for (const pd of pubDefs) {
      const eventDate = daysAhead(pd.daysOut);
      const client = this.clients[pd.client];
      const venue = this.venues[pd.venue];
      const endH = Math.min(pd.startH + pd.dur, 23);

      const rolesArr = [
        { role: 'Server', count: 4 },
        { role: 'Bartender', count: 2 },
        { role: 'Host', count: 1 },
        { role: 'Event Coordinator', count: 1 },
      ];
      const headcount = rolesArr.reduce((s, r) => s + r.count, 0);

      const role_stats = rolesArr.map(r => ({
        role: r.role, capacity: r.count, taken: 0,
        remaining: r.count, is_full: false,
      }));

      await EventModel.create({
        managerId: this.mgr._id,
        status: 'published',
        publishedAt: new Date(),
        publishedBy: `${this.mgr.provider}:${this.mgr.subject}`,
        visibilityType: 'public',
        shift_name: `${pd.name} - ${client.name}`,
        client_name: client.name,
        date: eventDate,
        start_time: `${String(pd.startH).padStart(2, '0')}:00`,
        end_time: `${String(endH).padStart(2, '0')}:00`,
        venue_name: venue.name, venue_address: venue.address,
        venue_latitude: venue.latitude, venue_longitude: venue.longitude,
        city: venue.city, state: venue.state, country: 'USA',
        contact_name: 'Elena Rivera',
        contact_phone: '+15551234567',
        contact_email: `events@${client.name.toLowerCase().replace(/\s+/g, '')}.com`,
        uniform: pd.uniform,
        notes: `${pd.name} for ${client.name}. All team members welcome to apply.`,
        headcount_total: headcount, roles: rolesArr,
        accepted_staff: [], declined_staff: [], role_stats,
        audience_team_ids: [this.team._id],
        hoursStatus: 'pending',
        chatEnabled: true, chatEnabledAt: new Date(),
        pay_rate_info: `$${ROLE_DEFS[2]!.baseRate}-${ROLE_DEFS[3]!.baseRate}/hr depending on role`,
        version: 0,
      });
      console.log(`   + ${pd.name} (${pd.daysOut} days out)`);
    }
    console.log('');
  }

  // ── 1 Draft Event ───────────────────────────────────────
  private async seedDraftEvent() {
    console.log('   CREATING 1 DRAFT EVENT...');
    const client = this.clients[0];
    const venue = this.venues[2];

    await EventModel.create({
      managerId: this.mgr._id,
      status: 'draft',
      visibilityType: 'private',
      shift_name: `Upcoming Award Ceremony - ${client.name}`,
      client_name: client.name,
      date: daysAhead(21),
      start_time: '18:00', end_time: '23:00',
      venue_name: venue.name, venue_address: venue.address,
      city: venue.city, state: venue.state, country: 'USA',
      headcount_total: 8,
      roles: [
        { role: 'Server', count: 3 },
        { role: 'Bartender', count: 2 },
        { role: 'Host', count: 1 },
        { role: 'Chef', count: 1 },
        { role: 'Event Coordinator', count: 1 },
      ],
      accepted_staff: [], declined_staff: [], role_stats: [],
      version: 0,
    });
    console.log('   + Award Ceremony (draft)\n');
  }

  // ── 260 Staff-Focused Events ────────────────────────────
  private async seedStaffEvents() {
    console.log('   CREATING 260 STAFF-FOCUSED EVENTS (Apr 2025 → Apr 2026)...');

    const marcus = this.staff[0]; // Marcus Johnson = demo staff login
    const marcusKey = `${marcus.provider}:${marcus.subject}`;
    const mgrKey = `${this.mgr.provider}:${this.mgr.subject}`;

    // Other staff for filling events (2-4 random co-workers per event)
    const otherStaff = this.staff.slice(1);

    const startDate = new Date('2025-04-01');
    const endDate = new Date('2026-04-30');
    // "today" for the seed context is 2026-02-17 per plan
    const today = new Date('2026-02-17');
    today.setHours(23, 59, 59, 999);

    const TOTAL = 260;
    const eventDates = generateSpreadDates(startDate, endDate, TOTAL);

    // Split: dates before today = completed, dates after = future
    const pastDates = eventDates.filter(d => d <= today);
    const futureDates = eventDates.filter(d => d > today);

    // Past events: all completed with approved hours (210 planned)
    const events: any[] = [];
    let completedCount = 0;
    let futureAcceptedCount = 0;
    let futureOpenCount = 0;

    for (const eventDate of pastDates) {
      const venue = randomPick(this.venues);
      const clientIdx = randomInt(0, this.clients.length - 1);
      const client = this.clients[clientIdx]!;
      const eventName = randomPick(STAFF_EVENT_NAMES);
      const marcusRoleDef = ROLE_DEFS[randomInt(0, ROLE_DEFS.length - 1)]!;
      const startHour = randomInt(7, 19);
      const duration = randomInt(6, 11);
      const endHour = Math.min(startHour + duration, 23);
      const actualDuration = endHour - startHour;
      const uniform = randomPick(UNIFORM_POOL);

      // Build roles array — Marcus's role + 1-2 others
      const otherRoles = ROLE_DEFS.filter(r => r.name !== marcusRoleDef.name);
      const extraRole1 = randomPick(otherRoles);
      const rolesArr = [
        { role: marcusRoleDef.name, count: randomInt(2, 4) },
        { role: extraRole1.name, count: randomInt(1, 3) },
      ];
      if (rand() > 0.4) {
        const extraRole2 = randomPick(otherRoles.filter(r => r.name !== extraRole1.name));
        if (extraRole2) rolesArr.push({ role: extraRole2.name, count: randomInt(1, 2) });
      }
      const headcount = rolesArr.reduce((s, r) => s + r.count, 0);

      // Marcus's attendance
      const ciDate = new Date(eventDate);
      ciDate.setHours(startHour, randomInt(0, 15), 0);
      const coDate = new Date(eventDate);
      coDate.setHours(endHour, randomInt(0, 30), 0);

      // Small variation in approved hours (±0.5)
      const approvedHours = Math.max(4, actualDuration + (rand() > 0.5 ? 0.5 : 0));

      const marcusStaffEntry = {
        userKey: marcusKey,
        provider: marcus.provider, subject: marcus.subject,
        email: marcus.email, name: marcus.name,
        first_name: marcus.first_name, last_name: marcus.last_name,
        role: marcusRoleDef.name, response: 'accepted',
        respondedAt: new Date(eventDate.getTime() - randomInt(2, 7) * 86400000),
        attendance: [{
          clockInAt: ciDate, clockOutAt: coDate,
          estimatedHours: actualDuration,
          approvedHours,
          status: 'approved' as const,
          approvedBy: mgrKey,
          approvedAt: new Date(eventDate.getTime() + randomInt(1, 3) * 86400000),
          clockInLocation: {
            latitude: venue.latitude + (rand() - 0.5) * 0.0002,
            longitude: venue.longitude + (rand() - 0.5) * 0.0002,
            accuracy: randomInt(5, 20),
            source: 'geofence' as const,
          },
          clockOutLocation: {
            latitude: venue.latitude + (rand() - 0.5) * 0.0002,
            longitude: venue.longitude + (rand() - 0.5) * 0.0002,
            accuracy: randomInt(8, 25),
          },
        }],
      };

      // 2-4 other staff on the event
      const numOthers = randomInt(2, 4);
      const shuffled = [...otherStaff].sort(() => rand() - 0.5);
      const eventOthers = shuffled.slice(0, numOthers);
      const otherEntries = eventOthers.map((s: any) => {
        const otherRole = randomPick(rolesArr).role;
        const oCiDate = new Date(eventDate);
        oCiDate.setHours(startHour, randomInt(0, 20), 0);
        const oCoDate = new Date(eventDate);
        oCoDate.setHours(endHour, randomInt(0, 30), 0);
        return {
          userKey: `${s.provider}:${s.subject}`,
          provider: s.provider, subject: s.subject,
          email: s.email, name: s.name,
          first_name: s.first_name, last_name: s.last_name,
          role: otherRole, response: 'accepted',
          respondedAt: new Date(eventDate.getTime() - randomInt(1, 5) * 86400000),
          attendance: [{
            clockInAt: oCiDate, clockOutAt: oCoDate,
            estimatedHours: actualDuration,
            approvedHours: actualDuration,
            status: 'approved' as const,
            approvedBy: mgrKey,
            approvedAt: new Date(eventDate.getTime() + randomInt(1, 3) * 86400000),
            clockInLocation: {
              latitude: venue.latitude + (rand() - 0.5) * 0.0003,
              longitude: venue.longitude + (rand() - 0.5) * 0.0003,
              accuracy: randomInt(5, 25),
              source: 'geofence' as const,
            },
            clockOutLocation: {
              latitude: venue.latitude + (rand() - 0.5) * 0.0003,
              longitude: venue.longitude + (rand() - 0.5) * 0.0003,
              accuracy: randomInt(8, 30),
            },
          }],
        };
      });

      const accepted_staff = [marcusStaffEntry, ...otherEntries];

      // Build role_stats
      const role_stats = rolesArr.map(r => {
        const taken = accepted_staff.filter((s: any) => s.role === r.role).length;
        return { role: r.role, capacity: r.count, taken, remaining: Math.max(0, r.count - taken), is_full: taken >= r.count };
      });

      const rate = Math.round(marcusRoleDef.baseRate * CLIENT_DEFS[clientIdx]!.multiplier);

      events.push({
        managerId: this.mgr._id,
        status: 'completed',
        publishedAt: new Date(eventDate.getTime() - randomInt(5, 14) * 86400000),
        publishedBy: mgrKey,
        fulfilledAt: new Date(eventDate.getTime() + actualDuration * 3600000),
        visibilityType: rand() > 0.5 ? 'private' : 'public',
        shift_name: `${eventName} - ${client.name}`,
        client_name: client.name,
        date: eventDate,
        start_time: `${String(startHour).padStart(2, '0')}:00`,
        end_time: `${String(endHour).padStart(2, '0')}:00`,
        venue_name: venue.name, venue_address: venue.address,
        venue_latitude: venue.latitude, venue_longitude: venue.longitude,
        city: venue.city, state: venue.state, country: 'USA',
        contact_name: 'Elena Rivera',
        contact_phone: '+15551234567',
        contact_email: `events@${client.name.toLowerCase().replace(/\s+/g, '')}.com`,
        uniform,
        notes: `${eventName} hosted by ${client.name} at ${venue.name}.`,
        headcount_total: headcount, roles: rolesArr,
        accepted_staff, declined_staff: [], role_stats,
        audience_team_ids: [this.team._id],
        hoursStatus: 'approved',
        hoursApprovedBy: mgrKey,
        hoursApprovedAt: new Date(eventDate.getTime() + randomInt(1, 4) * 86400000),
        chatEnabled: true,
        chatEnabledAt: new Date(eventDate.getTime() - 86400000),
        pay_rate_info: `$${rate}/hr`,
        version: 0,
      });
      completedCount++;
    }

    // Future events: split ~60% accepted by Marcus, ~40% open/pending
    for (let i = 0; i < futureDates.length; i++) {
      const eventDate = futureDates[i]!;
      const venue = randomPick(this.venues);
      const clientIdx = randomInt(0, this.clients.length - 1);
      const client = this.clients[clientIdx]!;
      const eventName = randomPick(STAFF_EVENT_NAMES);
      const marcusRoleDef = ROLE_DEFS[randomInt(0, ROLE_DEFS.length - 1)]!;
      const startHour = randomInt(7, 19);
      const duration = randomInt(6, 11);
      const endHour = Math.min(startHour + duration, 23);
      const uniform = randomPick(UNIFORM_POOL);

      const otherRoles = ROLE_DEFS.filter(r => r.name !== marcusRoleDef.name);
      const extraRole1 = randomPick(otherRoles);
      const rolesArr = [
        { role: marcusRoleDef.name, count: randomInt(2, 5) },
        { role: extraRole1.name, count: randomInt(1, 3) },
      ];
      if (rand() > 0.3) {
        const extraRole2 = randomPick(otherRoles.filter(r => r.name !== extraRole1.name));
        if (extraRole2) rolesArr.push({ role: extraRole2.name, count: randomInt(1, 2) });
      }
      const headcount = rolesArr.reduce((s, r) => s + r.count, 0);

      const isMarcusAccepted = i < Math.ceil(futureDates.length * 0.6); // first 60% = accepted

      let accepted_staff: any[] = [];
      if (isMarcusAccepted) {
        accepted_staff.push({
          userKey: marcusKey,
          provider: marcus.provider, subject: marcus.subject,
          email: marcus.email, name: marcus.name,
          first_name: marcus.first_name, last_name: marcus.last_name,
          role: marcusRoleDef.name, response: 'accepted',
          respondedAt: new Date(today.getTime() - randomInt(0, 5) * 86400000),
          attendance: [],
        });
        futureAcceptedCount++;
      } else {
        futureOpenCount++;
      }

      // A few other staff members already accepted on some events
      if (rand() > 0.4) {
        const numOthers = randomInt(1, 3);
        const shuffled = [...otherStaff].sort(() => rand() - 0.5);
        for (const s of shuffled.slice(0, numOthers)) {
          const otherRole = randomPick(rolesArr).role;
          accepted_staff.push({
            userKey: `${s.provider}:${s.subject}`,
            provider: s.provider, subject: s.subject,
            email: s.email, name: s.name,
            first_name: s.first_name, last_name: s.last_name,
            role: otherRole, response: 'accepted',
            respondedAt: new Date(today.getTime() - randomInt(0, 3) * 86400000),
            attendance: [],
          });
        }
      }

      const role_stats = rolesArr.map(r => {
        const taken = accepted_staff.filter((s: any) => s.role === r.role).length;
        return { role: r.role, capacity: r.count, taken, remaining: Math.max(0, r.count - taken), is_full: taken >= r.count };
      });

      const rate = Math.round(marcusRoleDef.baseRate * CLIENT_DEFS[clientIdx]!.multiplier);

      events.push({
        managerId: this.mgr._id,
        status: 'published',
        publishedAt: new Date(today.getTime() - randomInt(1, 10) * 86400000),
        publishedBy: mgrKey,
        visibilityType: 'public',
        shift_name: `${eventName} - ${client.name}`,
        client_name: client.name,
        date: eventDate,
        start_time: `${String(startHour).padStart(2, '0')}:00`,
        end_time: `${String(endHour).padStart(2, '0')}:00`,
        venue_name: venue.name, venue_address: venue.address,
        venue_latitude: venue.latitude, venue_longitude: venue.longitude,
        city: venue.city, state: venue.state, country: 'USA',
        contact_name: 'Elena Rivera',
        contact_phone: '+15551234567',
        contact_email: `events@${client.name.toLowerCase().replace(/\s+/g, '')}.com`,
        uniform,
        notes: `${eventName} hosted by ${client.name} at ${venue.name}. All team members welcome.`,
        headcount_total: headcount, roles: rolesArr,
        accepted_staff, declined_staff: [], role_stats,
        audience_team_ids: [this.team._id],
        hoursStatus: 'pending',
        chatEnabled: true,
        chatEnabledAt: new Date(today.getTime() - randomInt(0, 5) * 86400000),
        pay_rate_info: `$${rate}/hr`,
        version: 0,
      });
    }

    // Insert in batches of 50
    for (let i = 0; i < events.length; i += 50) {
      const batch = events.slice(i, i + 50);
      await EventModel.insertMany(batch);
    }

    console.log(`   + ${completedCount} completed events (past, with approved hours)`);
    console.log(`   + ${futureAcceptedCount} published events (future, Marcus accepted)`);
    console.log(`   + ${futureOpenCount} published events (future, open/pending)`);
    console.log(`   = ${events.length} total staff-focused events\n`);
  }

  // ── 3 Chat Conversations ────────────────────────────────
  private async seedChat() {
    console.log('   CREATING 3 CHAT CONVERSATIONS...');
    const chatStaff = this.staff.slice(0, 3);

    const mgrMessages = [
      'Hi! Great work at the gala last week. Are you available for the cocktail party this Friday?',
      'Just a reminder — the dress code for the upcoming wedding is white shirt and black vest.',
      'Thanks for confirming! Looking forward to working with you again.',
    ];
    const staffMessages = [
      'Thank you! Yes, I\'m available Friday evening. What time should I arrive?',
      'Got it, I\'ll make sure to have the right attire ready. Thanks!',
      'Sounds great, see you there!',
    ];

    for (let i = 0; i < chatStaff.length; i++) {
      const s = chatStaff[i];
      const uk = `${s.provider}:${s.subject}`;

      // Stagger message times so they sort correctly (manager first, staff reply 5 min later)
      const baseTime = daysAgo(i);
      baseTime.setHours(14, 0, 0, 0); // 2:00 PM
      const replyTime = new Date(baseTime.getTime() + 5 * 60 * 1000); // 2:05 PM

      const conv = await ConversationModel.create({
        managerId: this.mgr._id,
        userKey: uk,
        lastMessageAt: replyTime,
        lastMessagePreview: staffMessages[i]!.slice(0, 200),
        unreadCountManager: i === 0 ? 1 : 0,
        unreadCountUser: 0,
      });

      const msgs = [
        {
          conversationId: conv._id, managerId: this.mgr._id, userKey: uk,
          senderType: 'manager', senderName: MANAGER_DEF.name,
          message: mgrMessages[i]!, messageType: 'text',
          readByManager: true, readByUser: true,
          createdAt: baseTime,
        },
        {
          conversationId: conv._id, managerId: this.mgr._id, userKey: uk,
          senderType: 'user', senderName: s.name,
          message: staffMessages[i]!, messageType: 'text',
          readByManager: i !== 0, readByUser: true,
          createdAt: replyTime,
        },
      ];
      await ChatMessageModel.insertMany(msgs);
      console.log(`   + Conversation with ${s.name} (${msgs.length} messages)`);
    }
    console.log('');
  }

  // ── JWT Tokens ──────────────────────────────────────────
  private genTokens() {
    console.log('   GENERATING JWT TOKENS (30-day expiry)...');

    // Manager token
    const d = MANAGER_DEF;
    const mgrToken = jwt.sign(
      {
        sub: d.subject, provider: 'email',
        email: d.email, name: d.name,
        managerId: this.mgr._id.toString(),
      },
      ENV.jwtSecret,
      { algorithm: 'HS256', expiresIn: '30d' },
    );
    this.tokens.push({ role: 'MANAGER', name: d.name, email: d.email, token: mgrToken });

    // Staff tokens (all 10)
    for (const s of this.staff) {
      const token = jwt.sign(
        { sub: s.subject, provider: s.provider, email: s.email, name: s.name },
        ENV.jwtSecret,
        { algorithm: 'HS256', expiresIn: '30d' },
      );
      this.tokens.push({ role: 'STAFF', name: s.name, email: s.email, token });
    }
  }

  // ── Report ──────────────────────────────────────────────
  private report() {
    console.log('\n');
    console.log('='.repeat(65));
    console.log('        DEMO SEED COMPLETE - APPLE REVIEW DATASET');
    console.log('='.repeat(65));
    console.log('');
    console.log('DATA CREATED:');
    console.log('   Manager:            1 (Elena Rivera)');
    console.log('   Staff Users:        10');
    console.log('   Team:               1 (Rivera Events Team)');
    console.log('   Team Members:       10');
    console.log('   Clients:            4 (Grand Hyatt, Stellar, Rocky Mountain, Mile High)');
    console.log('   Roles:              5 (Server, Bartender, Host, Chef, Event Coordinator)');
    console.log('   Venues:             10 (Denver metro area)');
    console.log(`   Tariffs:            ${this.clients.length * this.roles.length}`);
    console.log('   Staff Groups:       2 (Top Performers, Reliable Staff)');
    console.log('   Staff Profiles:     10 (4 rated 5-star, 3 rated 4-star, 3 rated 3-star)');
    console.log('   Manager Events:     6 (3 past + 2 published + 1 draft)');
    console.log('   Staff Events:       ~260 (Apr 2025 → Apr 2026 for Marcus Johnson)');
    console.log('   Total Events:       ~266');
    console.log('   Chat Conversations: 3 (with message history)');
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
    console.log('DEMO LOGIN CREDENTIALS:');
    console.log('-'.repeat(65));
    console.log('');
    console.log(`   Manager:  ${MANAGER_DEF.email} / ${MANAGER_DEF.password}`);
    console.log(`   Staff:    ${DEMO_STAFF_DEF.email} / ${DEMO_STAFF_DEF.password}`);
    console.log('');
    console.log('-'.repeat(65));
    console.log('APPLE REVIEW TESTING GUIDE:');
    console.log('-'.repeat(65));
    console.log('');
    console.log('1. MANAGER FLOW:');
    console.log('   - Login as Elena Rivera (manager token above)');
    console.log('   - View completed events with earnings data');
    console.log('   - View published events awaiting staff');
    console.log('   - Edit/publish the draft Award Ceremony');
    console.log('   - Chat with staff members');
    console.log('');
    console.log('2. STAFF FLOW (Marcus Johnson — staff@flowshift.work):');
    console.log('   - ~210 completed events with approved hours (Apr 2025 → Feb 2026)');
    console.log('   - ~30 upcoming accepted events (Feb → Apr 2026)');
    console.log('   - ~20 open events available to accept');
    console.log('   - Rich earnings history across 5 roles, 4 clients, 10 Denver venues');
    console.log('');
    console.log('3. EARNINGS DATA:');
    console.log('   - ~210 completed events × avg 8.5 hrs × avg $32/hr ≈ $57,000+');
    console.log('   - Monthly breakdown spanning 13 months');
    console.log('   - Role distribution: Server, Bartender, Host, Chef, Event Coordinator');
    console.log('   - 4 clients with different pay rate multipliers');
    console.log('');
    console.log('='.repeat(65));
  }
}

// ════════════════════════════════════════════════════════════
// ENTRY POINT
// ════════════════════════════════════════════════════════════

if (require.main === module) {
  new DemoSeed().run();
}
