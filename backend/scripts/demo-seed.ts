/**
 * DEMO SEED SCRIPT — Apple App Store Review Dataset
 *
 * Seeds `nexa_prod` with a small, curated dataset designed to look
 * professional during an Apple reviewer walkthrough:
 *
 * - 1 Manager (placeholder credentials)
 * - 10 Staff Users
 * - 1 Team with all 10 staff
 * - 2 High-profile Clients
 * - 5 Roles (Server, Bartender, Host, Chef, Event Coordinator)
 * - 3 Venues
 * - Tariffs for all role/client combos
 * - 3 Past completed events (with attendance + approved hours)
 * - 2 Published events (reviewer can test accepting)
 * - 1 Draft event
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
  subject: 'demo-mgr-001',
  name: 'Elena Rivera',
  email: 'elena.rivera@nexademo.com',
  first_name: 'Elena',
  last_name: 'Rivera',
  city: 'Miami',
  teamName: 'Rivera Events Team',
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
  { name: 'The Grand Hyatt Group' },
  { name: 'Stellar Productions Inc' },
];

const ROLE_DEFS = [
  { name: 'Server',            baseRate: 25 },
  { name: 'Bartender',         baseRate: 30 },
  { name: 'Host',              baseRate: 22 },
  { name: 'Chef',              baseRate: 45 },
  { name: 'Event Coordinator', baseRate: 40 },
];

const VENUE_DEFS = [
  { name: 'Faena Hotel Miami Beach', address: '3201 Collins Ave', city: 'Miami Beach', state: 'FL', lat: 25.8119, lng: -80.1225 },
  { name: 'Vizcaya Museum & Gardens', address: '3251 S Miami Ave', city: 'Miami', state: 'FL', lat: 25.7443, lng: -80.2109 },
  { name: 'Perez Art Museum Miami', address: '1103 Biscayne Blvd', city: 'Miami', state: 'FL', lat: 25.7859, lng: -80.1863 },
];

const GROUP_DEFS = [
  { name: 'Top Performers', color: '#FFD700' },
  { name: 'Reliable Staff',  color: '#4CAF50' },
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
    const uri = ENV.mongoUri.trim().replace(/\/$/, '');
    await mongoose.connect(`${uri}/${dbName}`);
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

    this.mgrUser = await UserModel.create({
      provider: 'google', subject: d.subject,
      email: d.email, name: d.name,
      first_name: d.first_name, last_name: d.last_name,
      subscription_tier: 'pro', subscription_status: 'active',
    });

    this.mgr = await ManagerModel.create({
      provider: 'google', subject: d.subject,
      email: d.email, name: d.name,
      first_name: d.first_name, last_name: d.last_name,
      subscription_tier: 'pro', subscription_status: 'active',
      cities: [{ name: `${d.city}, USA`, isTourist: false }],
    });

    console.log(`   + ${d.name} (${d.email}) [${this.mgr._id}]\n`);
  }

  // ── 10 Staff ────────────────────────────────────────────
  private async seedStaff() {
    console.log('   CREATING 10 STAFF USERS...');
    const docs = STAFF_DEFS.map(s => ({
      provider: 'google' as const,
      subject: `demo-staff-${s.id}`,
      email: `${s.first.toLowerCase()}.${s.last.toLowerCase()}@nexademo.com`,
      name: `${s.first} ${s.last}`,
      first_name: s.first,
      last_name: s.last,
      subscription_tier: 'free',
      subscription_status: 'active',
    }));
    this.staff = await UserModel.insertMany(docs);
    console.log(`   + ${this.staff.length} staff created\n`);
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
    const multipliers = [1.0, 1.3]; // standard, premium
    for (let c = 0; c < this.clients.length; c++) {
      const mult = multipliers[c];
      for (let r = 0; r < this.roles.length; r++) {
        tariffs.push({
          managerId: this.mgr._id,
          clientId: this.clients[c]._id,
          roleId: this.roles[r]._id,
          rate: Math.round(ROLE_DEFS[r]!.baseRate * mult!),
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
            approvedBy: `google:${this.mgr.subject}`,
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
        publishedBy: `google:${this.mgr.subject}`,
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
        hoursApprovedBy: `google:${this.mgr.subject}`,
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
        publishedBy: `google:${this.mgr.subject}`,
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

      const conv = await ConversationModel.create({
        managerId: this.mgr._id,
        userKey: uk,
        lastMessageAt: daysAgo(i),
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
        },
        {
          conversationId: conv._id, managerId: this.mgr._id, userKey: uk,
          senderType: 'user', senderName: s.name,
          message: staffMessages[i]!, messageType: 'text',
          readByManager: i !== 0, readByUser: true,
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
        sub: d.subject, provider: 'google',
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
        { sub: s.subject, provider: 'google', email: s.email, name: s.name },
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
    console.log('   Clients:            2 (The Grand Hyatt Group, Stellar Productions Inc)');
    console.log('   Roles:              5 (Server, Bartender, Host, Chef, Event Coordinator)');
    console.log('   Venues:             3 (Miami area)');
    console.log(`   Tariffs:            ${this.clients.length * this.roles.length}`);
    console.log('   Staff Groups:       2 (Top Performers, Reliable Staff)');
    console.log('   Staff Profiles:     10 (4 rated 5-star, 3 rated 4-star, 3 rated 3-star)');
    console.log('   Past Events:        3 (completed, with attendance & approved hours)');
    console.log('   Published Events:   2 (open for staff acceptance)');
    console.log('   Draft Events:       1');
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
    console.log('APPLE REVIEW TESTING GUIDE:');
    console.log('-'.repeat(65));
    console.log('');
    console.log('1. MANAGER FLOW:');
    console.log('   - Login as Elena Rivera (manager token above)');
    console.log('   - View 3 completed events with earnings data');
    console.log('   - View 2 published events awaiting staff');
    console.log('   - Edit/publish the draft Award Ceremony');
    console.log('   - Chat with staff members');
    console.log('');
    console.log('2. STAFF FLOW:');
    console.log('   - Login as any staff member (tokens above)');
    console.log('   - Browse 2 published events and accept/decline');
    console.log('   - View past event history and hours');
    console.log('   - Chat with manager');
    console.log('');
    console.log('3. EARNINGS DATA:');
    console.log('   - 3 completed events with approved hours');
    console.log('   - Tariffs provide pay rates per role/client');
    console.log('   - Staff profiles show ratings & group membership');
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
