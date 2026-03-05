/**
 * DEMO SEED SCRIPT — App Store / Google Play Review Accounts
 *
 * ADDITIVE/IDEMPOTENT — does NOT drop all collections.
 * Only deletes data owned by demo accounts, then re-creates it.
 *
 * Accounts:
 *   Manager: demo@flowshift.work / FlowShift2024!  (Alex Morgan, pro+active)
 *   Staff:   staff@flowshift.work / FlowShift2024!  (Jordan Bell, free+free_month)
 *            + 4 non-loginable staff to fill events
 *
 * Usage:
 *   cd backend && npm run seed:review
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
import { EventModel } from '../src/models/event';
import { ConversationModel } from '../src/models/conversation';
import { ChatMessageModel } from '../src/models/chatMessage';
import { StaffProfileModel } from '../src/models/staffProfile';
import { StaffGroupModel } from '../src/models/staffGroup';

// ════════════════════════════════════════════════════════════
// STATIC DATA
// ════════════════════════════════════════════════════════════

const MANAGER_EMAIL = 'demo@flowshift.work';
const STAFF_EMAIL = 'staff@flowshift.work';
const PASSWORD = 'FlowShift2024!';

const STAFF_DEFS = [
  { first: 'Jordan', last: 'Bell',   id: 'staff@flowshift.work', provider: 'email' as const, isDemo: true },
  { first: 'Riley',  last: 'Torres', id: 'demo-staff-002', provider: 'google' as const, isDemo: false },
  { first: 'Casey',  last: 'Park',   id: 'demo-staff-003', provider: 'google' as const, isDemo: false },
  { first: 'Morgan', last: 'Lee',    id: 'demo-staff-004', provider: 'google' as const, isDemo: false },
  { first: 'Taylor', last: 'Kim',    id: 'demo-staff-005', provider: 'google' as const, isDemo: false },
];

const CLIENT_DEFS = [
  { name: 'Grand Hyatt Group',   multiplier: 1.0 },
  { name: 'Stellar Productions', multiplier: 1.3 },
];

const ROLE_DEFS = [
  { name: 'Server',            baseRate: 25 },
  { name: 'Bartender',         baseRate: 30 },
  { name: 'Event Coordinator', baseRate: 40 },
];

const VENUE_POOL = [
  { name: 'Four Seasons Hotel Denver',    address: '1111 14th St, Denver, CO',       lat: 39.7447, lng: -104.9997 },
  { name: 'The Ritz-Carlton, Denver',     address: '1881 Curtis St, Denver, CO',     lat: 39.7473, lng: -104.9941 },
  { name: 'Denver Art Museum',            address: '100 W 14th Ave Pkwy, Denver, CO', lat: 39.7373, lng: -104.9896 },
  { name: 'Colorado Convention Center',   address: '700 14th St, Denver, CO',        lat: 39.7392, lng: -104.9973 },
  { name: 'Wellshire Event Center',       address: '3333 S Colorado Blvd, Denver, CO', lat: 39.6578, lng: -104.9408 },
];

const EVENT_NAMES = [
  'Corporate Gala', 'Annual Fundraiser', 'Wedding Reception', 'VIP Cocktail Party',
  'Holiday Dinner', 'Product Launch', 'Art Exhibition Opening', 'Wine Tasting Soirée',
  'Charity Auction', 'Award Ceremony', 'Rehearsal Dinner', 'Corporate Retreat',
  'Sports Banquet', 'Birthday Celebration', 'Networking Mixer', 'Grand Opening',
  'Film Premiere', 'Tech Summit Reception', 'New Year\'s Eve Gala', 'Garden Party',
  'Graduation Banquet',
];

const UNIFORM_POOL = [
  'Black tie formal', 'All black attire', 'White shirt, black vest, black pants',
  'Formal service attire', 'Black pants, white button-down', 'Business casual',
];

const GROUP_DEFS = [
  { name: 'Bartender', color: '#E91E63' },
  { name: 'Server',    color: '#2196F3' },
];

// ════════════════════════════════════════════════════════════
// UTILITIES
// ════════════════════════════════════════════════════════════

function daysAgo(n: number): Date {
  const d = new Date(); d.setDate(d.getDate() - n); d.setHours(0, 0, 0, 0); return d;
}
function daysAhead(n: number): Date {
  const d = new Date(); d.setDate(d.getDate() + n); d.setHours(0, 0, 0, 0); return d;
}

/** Seeded PRNG for reproducible data */
function mulberry32(seed: number) {
  return function () {
    let t = (seed += 0x6d2b79f5);
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}
const rand = mulberry32(99);
function pick<T>(arr: T[]): T { return arr[Math.floor(rand() * arr.length)]!; }
function randInt(min: number, max: number): number { return Math.floor(rand() * (max - min + 1)) + min; }

// ════════════════════════════════════════════════════════════
// MAIN SEED CLASS
// ════════════════════════════════════════════════════════════

class ReviewSeed {
  private mgr: any;
  private staff: any[] = [];
  private team: any;
  private clients: any[] = [];
  private roles: any[] = [];
  private groups: any[] = [];
  private tokens: { role: string; name: string; email: string; token: string }[] = [];

  async run() {
    try {
      await this.connect();
      await this.cleanup();
      await this.seedManager();
      await this.seedStaff();
      await this.seedTeam();
      await this.seedTeamMembers();
      await this.seedClients();
      await this.seedRoles();
      await this.seedTariffs();
      await this.seedGroupsAndProfiles();
      await this.seedPastEvents();
      await this.seedFutureEvents();
      await this.seedDraftEvent();
      await this.seedChat();
      this.genTokens();
      this.report();
      await mongoose.disconnect();
      console.log('\n   Database disconnected. Demo review data ready!\n');
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

    // Only append dbName if the URI doesn't already include it
    const alreadyHasDb = uri.includes(`/${dbName}?`) || uri.endsWith(`/${dbName}`);
    if (!alreadyHasDb) {
      const qIdx = uri.indexOf('?');
      if (qIdx !== -1) {
        const base = uri.substring(0, qIdx).replace(/\/$/, '');
        const query = uri.substring(qIdx);
        uri = `${base}/${dbName}${query}`;
      } else {
        uri = `${uri}/${dbName}`;
      }
    }
    await mongoose.connect(uri);
    console.log(`   Connected to: ${dbName}\n`);
  }

  // ── Cleanup (additive — only deletes demo data) ────────
  private async cleanup() {
    console.log('   CLEANING UP DEMO DATA...');

    // Find demo manager
    const mgr = await ManagerModel.findOne({ email: MANAGER_EMAIL });
    if (mgr) {
      const mgrId = mgr._id;
      const delResults = await Promise.all([
        EventModel.deleteMany({ managerId: mgrId }),
        ConversationModel.deleteMany({ managerId: mgrId }),
        ChatMessageModel.deleteMany({ managerId: mgrId }),
        TeamMemberModel.deleteMany({ managerId: mgrId }),
        TeamModel.deleteMany({ managerId: mgrId }),
        ClientModel.deleteMany({ managerId: mgrId }),
        RoleModel.deleteMany({ managerId: mgrId }),
        TariffModel.deleteMany({ managerId: mgrId }),
        StaffProfileModel.deleteMany({ managerId: mgrId }),
        StaffGroupModel.deleteMany({ managerId: mgrId }),
        ManagerModel.deleteOne({ _id: mgrId }),
      ]);
      const totalDeleted = delResults.reduce((sum, r) => sum + (r.deletedCount || 0), 0);
      console.log(`   Deleted ${totalDeleted} docs for manager ${MANAGER_EMAIL}`);
    }

    // Delete demo staff users
    const staffDel = await UserModel.deleteMany({
      $or: [
        { email: MANAGER_EMAIL },
        { email: STAFF_EMAIL },
        { subject: { $regex: /^demo-staff-/ } },
      ],
    });
    console.log(`   Deleted ${staffDel.deletedCount} demo user docs\n`);
  }

  // ── Manager ─────────────────────────────────────────────
  private async seedManager() {
    console.log('   CREATING MANAGER (Alex Morgan)...');
    const passwordHash = await bcrypt.hash(PASSWORD, 10);

    // Manager user record (for cross-app login)
    await UserModel.create({
      provider: 'email', subject: MANAGER_EMAIL,
      email: MANAGER_EMAIL, name: 'Alex Morgan',
      first_name: 'Alex', last_name: 'Morgan',
      passwordHash,
      subscription_tier: 'pro', subscription_status: 'active',
    });

    this.mgr = await ManagerModel.create({
      provider: 'email', subject: MANAGER_EMAIL,
      email: MANAGER_EMAIL, name: 'Alex Morgan',
      first_name: 'Alex', last_name: 'Morgan',
      passwordHash,
      subscription_tier: 'pro', subscription_status: 'active',
      cities: [{ name: 'Denver, CO, USA', isTourist: false }],
    });

    console.log(`   + Alex Morgan (${MANAGER_EMAIL}) [${this.mgr._id}]\n`);
  }

  // ── Staff ───────────────────────────────────────────────
  private async seedStaff() {
    console.log('   CREATING 5 STAFF USERS...');
    const passwordHash = await bcrypt.hash(PASSWORD, 10);

    // Free trial ends 5 days from now (matches 7-day trial window)
    const freeMonthEnd = new Date();
    freeMonthEnd.setDate(freeMonthEnd.getDate() + 5);
    freeMonthEnd.setHours(23, 59, 59, 999);

    for (const s of STAFF_DEFS) {
      const doc = await UserModel.create({
        provider: s.provider,
        subject: s.id,
        email: s.isDemo ? STAFF_EMAIL : `${s.first.toLowerCase()}.${s.last.toLowerCase()}@flowshiftdemo.com`,
        name: `${s.first} ${s.last}`,
        first_name: s.first,
        last_name: s.last,
        passwordHash: s.isDemo ? passwordHash : undefined,
        subscription_tier: 'free',
        subscription_status: 'free_month',
        free_month_end_override: freeMonthEnd,
        ai_messages_used_this_month: 0,
        caricatures_used_this_month: 0,
      });
      this.staff.push(doc);
      console.log(`   + ${s.first} ${s.last} (${s.provider}:${s.id})${s.isDemo ? ' [DEMO LOGIN]' : ''}`);
    }
    console.log('');
  }

  // ── Team ────────────────────────────────────────────────
  private async seedTeam() {
    console.log('   CREATING TEAM...');
    this.team = await TeamModel.create({
      managerId: this.mgr._id,
      name: 'Morgan Events Team',
      normalizedName: 'morgan events team',
      description: 'Demo team for App Store review',
    });
    console.log(`   + Morgan Events Team [${this.team._id}]\n`);
  }

  // ── Team Members ────────────────────────────────────────
  private async seedTeamMembers() {
    console.log('   ADDING TEAM MEMBERS...');
    for (const s of this.staff) {
      await TeamMemberModel.create({
        teamId: this.team._id,
        managerId: this.mgr._id,
        provider: s.provider,
        subject: s.subject,
        email: s.email,
        name: s.name,
        invitedBy: this.mgr._id,
        joinedAt: new Date(),
        status: 'active',
      });
    }
    console.log(`   + ${this.staff.length} members added\n`);
  }

  // ── Clients ─────────────────────────────────────────────
  private async seedClients() {
    console.log('   CREATING CLIENTS...');
    for (const c of CLIENT_DEFS) {
      const doc = await ClientModel.create({
        managerId: this.mgr._id,
        name: c.name,
        normalizedName: c.name.toLowerCase(),
      });
      this.clients.push({ ...c, _id: doc._id });
      console.log(`   + ${c.name}`);
    }
    console.log('');
  }

  // ── Roles ───────────────────────────────────────────────
  private async seedRoles() {
    console.log('   CREATING ROLES...');
    for (const r of ROLE_DEFS) {
      const doc = await RoleModel.create({
        managerId: this.mgr._id,
        name: r.name,
        normalizedName: r.name.toLowerCase(),
      });
      this.roles.push({ ...r, _id: doc._id });
      console.log(`   + ${r.name} ($${r.baseRate}/hr)`);
    }
    console.log('');
  }

  // ── Tariffs ─────────────────────────────────────────────
  private async seedTariffs() {
    console.log('   CREATING TARIFFS...');
    let count = 0;
    for (const c of this.clients) {
      for (const r of this.roles) {
        const rate = Math.round(r.baseRate * c.multiplier * 100) / 100;
        await TariffModel.create({
          managerId: this.mgr._id,
          clientId: c._id,
          roleId: r._id,
          rate,
          currency: 'USD',
        });
        count++;
      }
    }
    console.log(`   + ${count} tariffs (${this.clients.length} clients × ${this.roles.length} roles)\n`);
  }

  // ── Groups & Profiles ──────────────────────────────────
  private async seedGroupsAndProfiles() {
    console.log('   CREATING GROUPS & PROFILES...');

    // Create groups
    for (const g of GROUP_DEFS) {
      const doc = await StaffGroupModel.create({
        managerId: this.mgr._id,
        name: g.name,
        normalizedName: g.name.toLowerCase(),
        color: g.color,
      });
      this.groups.push(doc);
    }

    // Create profiles — Jordan is 5-star favorite
    const jordan = this.staff[0]!;
    const jordanKey = `${jordan.provider}:${jordan.subject}`;
    await StaffProfileModel.create({
      managerId: this.mgr._id,
      userKey: jordanKey,
      notes: 'Excellent team player. Very reliable.',
      rating: 5,
      isFavorite: true,
      groupIds: [this.groups[1]._id], // Server group
    });

    // Other staff profiles
    for (let i = 1; i < this.staff.length; i++) {
      const s = this.staff[i]!;
      const key = `${s.provider}:${s.subject}`;
      const groupIdx = i <= 2 ? 0 : 1; // First two → Bartender, rest → Server
      await StaffProfileModel.create({
        managerId: this.mgr._id,
        userKey: key,
        notes: '',
        rating: randInt(3, 5),
        isFavorite: false,
        groupIds: [this.groups[groupIdx]._id],
      });
    }

    console.log(`   + ${GROUP_DEFS.length} groups, ${this.staff.length} profiles\n`);
  }

  // ── Past Events (15 completed) ─────────────────────────
  private async seedPastEvents() {
    console.log('   CREATING 15 PAST EVENTS (completed, approved hours)...');
    const jordan = this.staff[0]!;
    const jordanKey = `${jordan.provider}:${jordan.subject}`;

    for (let i = 0; i < 15; i++) {
      // Spread over last 90 days
      const daysBack = Math.floor((90 / 15) * i) + randInt(1, 4);
      const eventDate = daysAgo(daysBack);

      const venue = VENUE_POOL[i % VENUE_POOL.length]!;
      const client = this.clients[i % this.clients.length]!;
      const role = this.roles[i % this.roles.length]!;
      const eventName = EVENT_NAMES[i % EVENT_NAMES.length]!;
      const hours = randInt(4, 8);

      // Build accepted_staff: Jordan + 1-2 other staff
      const otherStaff = this.staff.slice(1, 1 + randInt(1, 2));
      const accepted_staff = [
        this.buildAcceptedStaff(jordan, role.name, eventDate, hours),
        ...otherStaff.map((s: any) => this.buildAcceptedStaff(s, role.name, eventDate, hours)),
      ];

      const totalCount = accepted_staff.length;

      await EventModel.create({
        managerId: this.mgr._id,
        status: 'completed',
        visibilityType: 'public',
        shift_name: eventName,
        client_name: client.name,
        date: eventDate,
        start_time: `${randInt(8, 14)}:00`,
        end_time: `${randInt(18, 23)}:00`,
        venue_name: venue.name,
        venue_address: venue.address,
        venue_latitude: venue.lat,
        venue_longitude: venue.lng,
        city: 'Denver',
        state: 'CO',
        country: 'US',
        uniform: pick(UNIFORM_POOL),
        headcount_total: totalCount,
        roles: [{ role: role.name, count: totalCount }],
        accepted_staff,
        role_stats: [{ role: role.name, capacity: totalCount, taken: totalCount, remaining: 0, is_full: true }],
        audience_team_ids: [this.team._id],
        hoursStatus: 'approved',
        hoursApprovedBy: `email:${MANAGER_EMAIL}`,
        hoursApprovedAt: new Date(eventDate.getTime() + 24 * 60 * 60 * 1000),
        publishedAt: new Date(eventDate.getTime() - 7 * 24 * 60 * 60 * 1000),
      });
    }
    console.log('   + 15 completed events with approved hours\n');
  }

  // ── Future Events (5 published) ────────────────────────
  private async seedFutureEvents() {
    console.log('   CREATING 5 FUTURE PUBLISHED EVENTS...');
    const jordan = this.staff[0]!;

    for (let i = 0; i < 5; i++) {
      const daysOut = randInt(3 + i * 5, 7 + i * 5);
      const eventDate = daysAhead(daysOut);

      const venue = VENUE_POOL[i % VENUE_POOL.length]!;
      const client = this.clients[i % this.clients.length]!;
      const role = this.roles[i % this.roles.length]!;
      const eventName = EVENT_NAMES[(15 + i) % EVENT_NAMES.length]!;
      const neededCount = randInt(2, 4);

      // First 3: Jordan accepted. Last 2: open/pending
      const jordanAccepted = i < 3;
      const accepted_staff: any[] = [];
      const taken = jordanAccepted ? 1 : 0;

      if (jordanAccepted) {
        accepted_staff.push({
          userKey: `${jordan.provider}:${jordan.subject}`,
          provider: jordan.provider,
          subject: jordan.subject,
          email: jordan.email,
          name: jordan.name,
          first_name: jordan.first_name,
          last_name: jordan.last_name,
          role: role.name,
          response: 'accept',
          respondedAt: new Date(),
          attendance: [],
        });
      }

      await EventModel.create({
        managerId: this.mgr._id,
        status: 'published',
        visibilityType: 'public',
        shift_name: eventName,
        client_name: client.name,
        date: eventDate,
        start_time: `${randInt(9, 15)}:00`,
        end_time: `${randInt(19, 23)}:00`,
        venue_name: venue.name,
        venue_address: venue.address,
        venue_latitude: venue.lat,
        venue_longitude: venue.lng,
        city: 'Denver',
        state: 'CO',
        country: 'US',
        uniform: pick(UNIFORM_POOL),
        headcount_total: neededCount,
        roles: [{ role: role.name, count: neededCount }],
        accepted_staff,
        role_stats: [{
          role: role.name,
          capacity: neededCount,
          taken,
          remaining: neededCount - taken,
          is_full: taken >= neededCount,
        }],
        audience_team_ids: [this.team._id],
        publishedAt: new Date(),
      });
    }
    console.log('   + 3 accepted by Jordan, 2 open/pending\n');
  }

  // ── Draft Event ────────────────────────────────────────
  private async seedDraftEvent() {
    console.log('   CREATING 1 DRAFT EVENT...');
    const venue = VENUE_POOL[0]!;
    const role = this.roles[0]!;

    await EventModel.create({
      managerId: this.mgr._id,
      status: 'draft',
      visibilityType: 'public',
      shift_name: 'Spring Charity Gala',
      client_name: this.clients[0]!.name,
      date: daysAhead(21),
      start_time: '17:00',
      end_time: '23:00',
      venue_name: venue.name,
      venue_address: venue.address,
      venue_latitude: venue.lat,
      venue_longitude: venue.lng,
      city: 'Denver',
      state: 'CO',
      country: 'US',
      uniform: 'Black tie formal',
      headcount_total: 5,
      roles: [{ role: role.name, count: 3 }, { role: this.roles[1]!.name, count: 2 }],
      accepted_staff: [],
      role_stats: [
        { role: role.name, capacity: 3, taken: 0, remaining: 3, is_full: false },
        { role: this.roles[1]!.name, capacity: 2, taken: 0, remaining: 2, is_full: false },
      ],
    });
    console.log('   + Spring Charity Gala (draft)\n');
  }

  // ── Chat Conversations ─────────────────────────────────
  private async seedChat() {
    console.log('   CREATING CONVERSATIONS...');
    const jordan = this.staff[0]!;
    const riley = this.staff[1]!;
    const mgrId = this.mgr._id;

    // Conversation 1: Manager ↔ Jordan
    const conv1 = await ConversationModel.create({
      managerId: mgrId,
      userKey: `${jordan.provider}:${jordan.subject}`,
      lastMessageAt: new Date(),
      lastMessagePreview: 'Looking forward to working with you!',
      unreadCountManager: 0,
      unreadCountUser: 1,
    });

    const conv1Messages = [
      { sender: 'manager', msg: 'Hi Jordan! Welcome to the team. Let me know if you have any questions.' },
      { sender: 'user', msg: 'Thanks Alex! Excited to get started. I have some bartending experience too.' },
      { sender: 'manager', msg: 'That\'s great! I\'ll keep that in mind for upcoming events.' },
      { sender: 'manager', msg: 'Looking forward to working with you!' },
    ];

    for (const m of conv1Messages) {
      await ChatMessageModel.create({
        conversationId: conv1._id,
        managerId: mgrId,
        userKey: `${jordan.provider}:${jordan.subject}`,
        senderType: m.sender as any,
        senderName: m.sender === 'manager' ? 'Alex Morgan' : 'Jordan Bell',
        message: m.msg,
        readByManager: true,
        readByUser: m.sender === 'manager' && m.msg.includes('Looking forward') ? false : true,
      });
    }

    // Conversation 2: Manager ↔ Riley
    const conv2 = await ConversationModel.create({
      managerId: mgrId,
      userKey: `${riley.provider}:${riley.subject}`,
      lastMessageAt: daysAgo(2),
      lastMessagePreview: 'See you there!',
      unreadCountManager: 0,
      unreadCountUser: 0,
    });

    const conv2Messages = [
      { sender: 'manager', msg: 'Hey Riley, are you available for the Corporate Gala next week?' },
      { sender: 'user', msg: 'Yes, I can make it! What time should I arrive?' },
      { sender: 'manager', msg: 'Great! Setup starts at 4pm. See you there!' },
      { sender: 'user', msg: 'See you there!' },
    ];

    for (const m of conv2Messages) {
      await ChatMessageModel.create({
        conversationId: conv2._id,
        managerId: mgrId,
        userKey: `${riley.provider}:${riley.subject}`,
        senderType: m.sender as any,
        senderName: m.sender === 'manager' ? 'Alex Morgan' : 'Riley Torres',
        message: m.msg,
        readByManager: true,
        readByUser: true,
      });
    }

    console.log('   + 2 conversations (Manager ↔ Jordan, Manager ↔ Riley)\n');
  }

  // ── JWT Tokens ──────────────────────────────────────────
  private genTokens() {
    // Manager token
    const mgrPayload = {
      provider: 'email',
      sub: MANAGER_EMAIL,
      managerId: String(this.mgr._id),
      email: MANAGER_EMAIL,
      iat: Math.floor(Date.now() / 1000),
    };
    const mgrToken = jwt.sign(mgrPayload, ENV.jwtSecret, { expiresIn: '30d' });
    this.tokens.push({ role: 'Manager', name: 'Alex Morgan', email: MANAGER_EMAIL, token: mgrToken });

    // Staff token (Jordan)
    const jordan = this.staff[0]!;
    const staffPayload = {
      provider: jordan.provider,
      sub: jordan.subject,
      _id: String(jordan._id),
      email: STAFF_EMAIL,
      iat: Math.floor(Date.now() / 1000),
    };
    const staffToken = jwt.sign(staffPayload, ENV.jwtSecret, { expiresIn: '30d' });
    this.tokens.push({ role: 'Staff', name: 'Jordan Bell', email: STAFF_EMAIL, token: staffToken });
  }

  // ── Report ──────────────────────────────────────────────
  private report() {
    console.log('   ════════════════════════════════════════════════');
    console.log('   DEMO REVIEW SEED COMPLETE');
    console.log('   ════════════════════════════════════════════════');
    console.log('');
    console.log('   Accounts:');
    console.log(`     Manager: ${MANAGER_EMAIL} / ${PASSWORD}  (pro + active)`);
    console.log(`     Staff:   ${STAFF_EMAIL} / ${PASSWORD}  (free + free_month, 5 days)`);
    console.log('');
    console.log('   Data created:');
    console.log('     1 Manager (Alex Morgan)');
    console.log('     5 Staff (Jordan Bell = demo login + 4 fill)');
    console.log('     1 Team (Morgan Events Team)');
    console.log(`     ${this.clients.length} Clients`);
    console.log(`     ${this.roles.length} Roles`);
    console.log(`     ${this.clients.length * this.roles.length} Tariffs`);
    console.log(`     ${this.groups.length} Staff Groups`);
    console.log(`     ${this.staff.length} Staff Profiles`);
    console.log('     15 Past events (completed, approved hours)');
    console.log('     5 Future events (3 accepted, 2 open)');
    console.log('     1 Draft event');
    console.log('     2 Conversations with messages');
    console.log('');
    console.log('   Paywall limits (staff):');
    console.log('     AI messages: 4/month (then 402 upgradeRequired)');
    console.log('     Caricatures: 1/month (then 402 upgradeRequired)');
    console.log('');
    console.log('   JWT Tokens (30-day, for API testing):');
    for (const t of this.tokens) {
      console.log(`\n   [${t.role}] ${t.name} (${t.email})`);
      console.log(`   ${t.token}`);
    }
    console.log('');
  }

  // ── Helpers ─────────────────────────────────────────────
  private buildAcceptedStaff(user: any, roleName: string, eventDate: Date, hours: number) {
    const clockIn = new Date(eventDate);
    clockIn.setHours(randInt(8, 14), 0, 0, 0);
    const clockOut = new Date(clockIn.getTime() + hours * 60 * 60 * 1000);

    return {
      userKey: `${user.provider}:${user.subject}`,
      provider: user.provider,
      subject: user.subject,
      email: user.email,
      name: user.name,
      first_name: user.first_name,
      last_name: user.last_name,
      role: roleName,
      response: 'accept',
      respondedAt: new Date(eventDate.getTime() - 5 * 24 * 60 * 60 * 1000),
      attendance: [{
        clockInAt: clockIn,
        clockOutAt: clockOut,
        estimatedHours: hours,
        approvedHours: hours,
        status: 'approved' as const,
        approvedBy: `email:${MANAGER_EMAIL}`,
        approvedAt: new Date(eventDate.getTime() + 24 * 60 * 60 * 1000),
        clockInLocation: { latitude: 39.7392, longitude: -104.9903, accuracy: 10, source: 'manual' as const },
        clockOutLocation: { latitude: 39.7392, longitude: -104.9903, accuracy: 10 },
      }],
    };
  }
}

// ════════════════════════════════════════════════════════════
// RUN
// ════════════════════════════════════════════════════════════
new ReviewSeed().run();
