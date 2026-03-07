/**
 * DEMO SEED SCRIPT — Approval Workflow Testing
 *
 * Seeds `nexa_prod` with focused data for testing the payroll
 * hours-approval workflow:
 *
 * - 1 Manager (Elena Rivera — demo@flowshift.work)
 * - 1 Staff User (Juan Suarez — juansegz07s@gmail.com via Google)
 * - 3 Additional staff (co-workers on events)
 * - 1 Team with all staff
 * - 2 Clients with tariffs
 * - 3 Roles (Server, Bartender, Host)
 * - 3 Denver-area Venues
 * - 6 Tariffs (2 clients × 3 roles)
 * - 8 Past events with approved hours (earnings history)
 * - 5 Events needing approval (various states for workflow testing)
 * - 3 Future published events
 *
 * Usage:
 *   cd backend && npm run seed:demo
 *   (or: NODE_ENV=production npx ts-node scripts/demo-seed.ts)
 *
 * Prerequisites:
 *   - .env with MONGO_URI and BACKEND_JWT_SECRET
 *
 * NOTE: Google login for juansegz07s@gmail.com will auto-link via
 * email matching in upsertUser (auth.ts step 3).
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
import { StaffProfileModel } from '../src/models/staffProfile';

// Venue data — stored inline on events (no separate Venue collection)
interface VenueData { name: string; address: string; city: string; state: string; lat: number; lng: number; }

// ════════════════════════════════════════════════════════════
// DETERMINISTIC IDs — survive re-seeding so JWTs stay valid
// ════════════════════════════════════════════════════════════

const FIXED_IDS = {
  managerUser: new mongoose.Types.ObjectId('aaa000000000000000000001'),
  manager:     new mongoose.Types.ObjectId('aaa000000000000000000002'),
  staffJuan:   new mongoose.Types.ObjectId('aaa000000000000000000010'),
  staffSofia:  new mongoose.Types.ObjectId('aaa000000000000000000011'),
  staffJames:  new mongoose.Types.ObjectId('aaa000000000000000000012'),
  staffOlivia: new mongoose.Types.ObjectId('aaa000000000000000000013'),
  team:        new mongoose.Types.ObjectId('aaa000000000000000000020'),
  clientHyatt: new mongoose.Types.ObjectId('aaa000000000000000000030'),
  clientStellar: new mongoose.Types.ObjectId('aaa000000000000000000031'),
  roleServer:  new mongoose.Types.ObjectId('aaa000000000000000000040'),
  roleBartender: new mongoose.Types.ObjectId('aaa000000000000000000041'),
  roleHost:    new mongoose.Types.ObjectId('aaa000000000000000000042'),
};

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

const STAFF_DEF = {
  email: 'juansegz07s@gmail.com',
  first_name: 'Juan',
  last_name: 'Suarez',
  name: 'Juan Suarez',
};

const COWORKERS = [
  { first: 'Sofia', last: 'Chen', id: '002' },
  { first: 'James', last: 'Williams', id: '003' },
  { first: 'Olivia', last: 'Martinez', id: '004' },
];

const CLIENT_DEFS = [
  { name: 'The Grand Hyatt Group', multiplier: 1.0 },
  { name: 'Stellar Productions Inc', multiplier: 1.3 },
];

const ROLE_DEFS = [
  { name: 'Server', baseRate: 25 },
  { name: 'Bartender', baseRate: 30 },
  { name: 'Host', baseRate: 22 },
];

const VENUE_DEFS = [
  { name: 'Four Seasons Hotel Denver', address: '1111 14th St', city: 'Denver', state: 'CO', lat: 39.7447, lng: -104.9997 },
  { name: 'The Ritz-Carlton, Denver', address: '1881 Curtis St', city: 'Denver', state: 'CO', lat: 39.7473, lng: -104.9941 },
  { name: 'Denver Art Museum', address: '100 W 14th Ave Pkwy', city: 'Denver', state: 'CO', lat: 39.7373, lng: -104.9896 },
];

// ════════════════════════════════════════════════════════════
// HELPERS
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
  private juan: any;
  private coworkers: any[] = [];
  private team: any;
  private clients: any[] = [];
  private roles: any[] = [];
  private venues: VenueData[] = VENUE_DEFS;
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
      await this.seedTariffs();
      await this.seedProfiles();
      await this.seedApprovedEvents();
      await this.seedApprovalWorkflowEvents();
      await this.seedFutureEvents();
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
      _id: FIXED_IDS.managerUser,
      provider: 'email', subject: d.subject,
      email: d.email, name: d.name,
      first_name: d.first_name, last_name: d.last_name,
      passwordHash,
      subscription_tier: 'pro', subscription_status: 'active',
    });

    this.mgr = await ManagerModel.create({
      _id: FIXED_IDS.manager,
      provider: 'email', subject: d.subject,
      email: d.email, name: d.name,
      first_name: d.first_name, last_name: d.last_name,
      passwordHash,
      subscription_tier: 'pro', subscription_status: 'active',
      cities: [{ name: `${d.city}, USA`, isTourist: false }],
    });

    console.log(`   + ${d.name} (${d.email}) [${this.mgr._id}]\n`);
  }

  // ── Staff ───────────────────────────────────────────────
  private async seedStaff() {
    console.log('   CREATING STAFF USERS...');

    // Juan — primary test user (provider: 'email', Google auto-links via email match)
    this.juan = await UserModel.create({
      _id: FIXED_IDS.staffJuan,
      provider: 'email',
      subject: STAFF_DEF.email,
      email: STAFF_DEF.email,
      name: STAFF_DEF.name,
      first_name: STAFF_DEF.first_name,
      last_name: STAFF_DEF.last_name,
      subscription_tier: 'pro',
      subscription_status: 'active',
    });
    console.log(`   + ${STAFF_DEF.name} (${STAFF_DEF.email}) — primary test user`);

    // Co-workers
    const coworkerIds = [FIXED_IDS.staffSofia, FIXED_IDS.staffJames, FIXED_IDS.staffOlivia];
    for (let i = 0; i < COWORKERS.length; i++) {
      const cw = COWORKERS[i]!;
      const user = await UserModel.create({
        _id: coworkerIds[i],
        provider: 'google',
        subject: `demo-staff-${cw.id}`,
        email: `${cw.first.toLowerCase()}.${cw.last.toLowerCase()}@nexademo.com`,
        name: `${cw.first} ${cw.last}`,
        first_name: cw.first,
        last_name: cw.last,
        subscription_tier: 'free',
        subscription_status: 'active',
      });
      this.coworkers.push(user);
      console.log(`   + ${cw.first} ${cw.last} (co-worker)`);
    }
    console.log('');
  }

  // ── Team ────────────────────────────────────────────────
  private async seedTeam() {
    console.log('   CREATING TEAM...');
    this.team = await TeamModel.create({
      _id: FIXED_IDS.team,
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
    const allStaff = [this.juan, ...this.coworkers];
    const docs = allStaff.map((s: any) => ({
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
    const clientIds = [FIXED_IDS.clientHyatt, FIXED_IDS.clientStellar];
    for (let i = 0; i < CLIENT_DEFS.length; i++) {
      const cd = CLIENT_DEFS[i]!;
      const c = await ClientModel.create({ _id: clientIds[i], managerId: this.mgr._id, name: cd.name });
      this.clients.push(c);
      console.log(`   + ${cd.name}`);
    }
    console.log('');
  }

  // ── Roles ───────────────────────────────────────────────
  private async seedRoles() {
    console.log('   CREATING ROLES...');
    const roleIds = [FIXED_IDS.roleServer, FIXED_IDS.roleBartender, FIXED_IDS.roleHost];
    for (let i = 0; i < ROLE_DEFS.length; i++) {
      const rd = ROLE_DEFS[i]!;
      const r = await RoleModel.create({ _id: roleIds[i], managerId: this.mgr._id, name: rd.name });
      this.roles.push(r);
    }
    console.log(`   + ${ROLE_DEFS.map(r => r.name).join(', ')}\n`);
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

  // ── Staff Profiles ──────────────────────────────────────
  private async seedProfiles() {
    console.log('   CREATING STAFF PROFILES...');
    const allStaff = [this.juan, ...this.coworkers];
    const docs = allStaff.map((s: any, i: number) => ({
      managerId: this.mgr._id,
      userKey: `${s.provider}:${s.subject}`,
      name: s.name,
      email: s.email,
      rating: i === 0 ? 5 : 4, // Juan gets 5-star
      status: 'active',
    }));
    await StaffProfileModel.insertMany(docs);
    console.log(`   + ${docs.length} profiles\n`);
  }

  // ── Helper: build staff entry for event ─────────────────
  private staffEntry(user: any, role: string, attendance: any[]) {
    return {
      userKey: `${user.provider}:${user.subject}`,
      provider: user.provider,
      subject: user.subject,
      email: user.email,
      name: user.name,
      first_name: user.first_name,
      last_name: user.last_name,
      role,
      response: 'accept',
      respondedAt: daysAgo(3),
      attendance,
    };
  }

  // ── Helper: build clock attendance session ──────────────
  private clockSession(
    date: Date,
    startH: number,
    endH: number,
    status: string,
    opts: { approvedHours?: number; managerNotes?: string } = {},
  ) {
    const mgrKey = `${this.mgr.provider}:${this.mgr.subject}`;
    const ci = new Date(date); ci.setHours(startH, 0, 0);
    const co = new Date(date); co.setHours(endH, 0, 0);
    return {
      clockInAt: ci,
      clockOutAt: co,
      estimatedHours: endH - startH,
      ...(opts.approvedHours != null ? { approvedHours: opts.approvedHours } : {}),
      status,
      ...(status === 'approved' ? { approvedBy: mgrKey, approvedAt: new Date() } : {}),
      ...(opts.managerNotes ? { managerNotes: opts.managerNotes } : {}),
      clockInLocation: {
        latitude: 39.7447 + (Math.random() - 0.5) * 0.0002,
        longitude: -104.9997 + (Math.random() - 0.5) * 0.0002,
        accuracy: 10,
        source: 'geofence',
      },
      clockOutLocation: {
        latitude: 39.7447 + (Math.random() - 0.5) * 0.0002,
        longitude: -104.9997 + (Math.random() - 0.5) * 0.0002,
        accuracy: 15,
      },
    };
  }

  // ── 8 Past Events with Approved Hours (earnings history) ─
  private async seedApprovedEvents() {
    console.log('   CREATING 8 APPROVED EVENTS (earnings history)...');
    const mgrKey = `${this.mgr.provider}:${this.mgr.subject}`;
    const juan = this.juan;
    const cw = this.coworkers;

    const events = [
      // Event 1 — 14 days ago, Server, Grand Hyatt, 6h
      {
        date: daysAgo(14), startH: 10, endH: 16, role: 'Server',
        name: 'Corporate Luncheon', client: 0, venue: 0, hours: 6,
      },
      // Event 2 — 12 days ago, Bartender, Stellar, 5h
      {
        date: daysAgo(12), startH: 17, endH: 22, role: 'Bartender',
        name: 'Cocktail Reception', client: 1, venue: 1, hours: 5,
      },
      // Event 3 — 10 days ago, Host, Grand Hyatt, 7h
      {
        date: daysAgo(10), startH: 11, endH: 18, role: 'Host',
        name: 'Wedding Reception', client: 0, venue: 2, hours: 7,
      },
      // Event 4 — 21 days ago, Server, Stellar, 8h
      {
        date: daysAgo(21), startH: 9, endH: 17, role: 'Server',
        name: 'Tech Conference Dinner', client: 1, venue: 0, hours: 8,
      },
      // Event 5 — 28 days ago, Bartender, Grand Hyatt, 6h
      {
        date: daysAgo(28), startH: 18, endH: 24, role: 'Bartender',
        name: 'Charity Gala', client: 0, venue: 1, hours: 6,
      },
      // Event 6 — 35 days ago, Host, Stellar, 5h
      {
        date: daysAgo(35), startH: 12, endH: 17, role: 'Host',
        name: 'Product Launch Party', client: 1, venue: 2, hours: 5,
      },
      // Event 7 — 42 days ago, Server, Grand Hyatt, 7h
      {
        date: daysAgo(42), startH: 10, endH: 17, role: 'Server',
        name: 'Annual Awards Banquet', client: 0, venue: 0, hours: 7,
      },
      // Event 8 — 49 days ago, Bartender, Stellar, 6h
      {
        date: daysAgo(49), startH: 16, endH: 22, role: 'Bartender',
        name: 'VIP Networking Mixer', client: 1, venue: 1, hours: 6,
      },
    ];

    for (const ev of events) {
      const client = this.clients[ev.client]!;
      const venue = this.venues[ev.venue]!;
      const coworker = cw[ev.venue % cw.length]!;

      await EventModel.create({
        managerId: this.mgr._id,
        status: 'completed',
        publishedAt: new Date(ev.date.getTime() - 7 * 86400000),
        publishedBy: mgrKey,
        fulfilledAt: new Date(ev.date.getTime() + ev.endH * 3600000),
        visibilityType: 'public',
        shift_name: `${ev.name} - ${client.name}`,
        client_name: client.name,
        date: ev.date,
        start_time: `${String(ev.startH).padStart(2, '0')}:00`,
        end_time: `${String(ev.endH % 24).padStart(2, '0')}:00`,
        venue_name: venue.name,
        venue_address: venue.address,
        venue_latitude: venue.lat,
        venue_longitude: venue.lng,
        city: venue.city, state: venue.state, country: 'USA',
        contact_name: 'Elena Rivera',
        contact_phone: '+15551234567',
        headcount_total: 3,
        roles: [{ role: ev.role, count: 2 }, { role: 'Host', count: 1 }],
        accepted_staff: [
          this.staffEntry(juan, ev.role, [
            this.clockSession(ev.date, ev.startH, ev.endH, 'approved', { approvedHours: ev.hours }),
          ]),
          this.staffEntry(coworker, ev.role, [
            this.clockSession(ev.date, ev.startH, ev.endH, 'approved', { approvedHours: ev.hours }),
          ]),
        ],
        declined_staff: [],
        role_stats: [],
        audience_team_ids: [this.team._id],
        hoursStatus: 'approved',
        hoursApprovedBy: mgrKey,
        hoursApprovedAt: new Date(ev.date.getTime() + 2 * 86400000),
        chatEnabled: true,
        pay_rate_info: `$${ROLE_DEFS.find(r => r.name === ev.role)!.baseRate * CLIENT_DEFS[ev.client]!.multiplier}/hr`,
        version: 0,
      });
      console.log(`   + ${ev.name} (${ev.hours}h, approved)`);
    }
    console.log('');
  }

  // ── 5 Events Needing Approval (workflow testing) ────────
  private async seedApprovalWorkflowEvents() {
    console.log('   CREATING 5 EVENTS NEEDING APPROVAL...');
    const mgrKey = `${this.mgr.provider}:${this.mgr.subject}`;
    const juan = this.juan;
    const cw = this.coworkers;
    const client = this.clients[0]!; // Grand Hyatt for all

    // ────────────────────────────────────────────────────────
    // Event A: Clocked out but UNAPPROVED — 2 days ago
    // Status: 'clocked' — manager needs to review and approve
    // ────────────────────────────────────────────────────────
    await EventModel.create({
      managerId: this.mgr._id,
      status: 'completed',
      publishedAt: daysAgo(9), publishedBy: mgrKey,
      fulfilledAt: daysAgo(2),
      visibilityType: 'public',
      shift_name: `Weekend Brunch Service - ${client.name}`,
      client_name: client.name,
      date: daysAgo(2),
      start_time: '08:00', end_time: '14:00',
      venue_name: this.venues[0]!.name, venue_address: this.venues[0]!.address,
      venue_latitude: this.venues[0]!.lat, venue_longitude: this.venues[0]!.lng,
      city: 'Denver', state: 'CO', country: 'USA',
      contact_name: 'Elena Rivera', contact_phone: '+15551234567',
      headcount_total: 3,
      roles: [{ role: 'Server', count: 2 }, { role: 'Bartender', count: 1 }],
      accepted_staff: [
        this.staffEntry(juan, 'Server', [this.clockSession(daysAgo(2), 8, 14, 'clocked')]),
        this.staffEntry(cw[0]!, 'Server', [this.clockSession(daysAgo(2), 8, 14, 'clocked')]),
        this.staffEntry(cw[1]!, 'Bartender', [this.clockSession(daysAgo(2), 8, 14, 'clocked')]),
      ],
      declined_staff: [], role_stats: [],
      audience_team_ids: [this.team._id],
      hoursStatus: 'pending',
      chatEnabled: true,
      pay_rate_info: '$25/hr', version: 0,
    });
    console.log('   + Weekend Brunch Service (CLOCKED — needs approval)');

    // ────────────────────────────────────────────────────────
    // Event B: Clocked out but UNAPPROVED — 3 days ago
    // Status: 'clocked' — another event waiting for review
    // ────────────────────────────────────────────────────────
    await EventModel.create({
      managerId: this.mgr._id,
      status: 'completed',
      publishedAt: daysAgo(10), publishedBy: mgrKey,
      fulfilledAt: daysAgo(3),
      visibilityType: 'public',
      shift_name: `Rooftop Happy Hour - ${client.name}`,
      client_name: client.name,
      date: daysAgo(3),
      start_time: '16:00', end_time: '21:00',
      venue_name: this.venues[1]!.name, venue_address: this.venues[1]!.address,
      venue_latitude: this.venues[1]!.lat, venue_longitude: this.venues[1]!.lng,
      city: 'Denver', state: 'CO', country: 'USA',
      contact_name: 'Elena Rivera', contact_phone: '+15551234567',
      headcount_total: 2,
      roles: [{ role: 'Bartender', count: 2 }],
      accepted_staff: [
        this.staffEntry(juan, 'Bartender', [this.clockSession(daysAgo(3), 16, 21, 'clocked')]),
        this.staffEntry(cw[2]!, 'Bartender', [this.clockSession(daysAgo(3), 16, 21, 'clocked')]),
      ],
      declined_staff: [], role_stats: [],
      audience_team_ids: [this.team._id],
      hoursStatus: 'pending',
      chatEnabled: true,
      pay_rate_info: '$30/hr', version: 0,
    });
    console.log('   + Rooftop Happy Hour (CLOCKED — needs approval)');

    // ────────────────────────────────────────────────────────
    // Event C: Sheet submitted but NOT approved — 4 days ago
    // Status: 'sheet_submitted' — sign-in sheet uploaded
    // ────────────────────────────────────────────────────────
    await EventModel.create({
      managerId: this.mgr._id,
      status: 'completed',
      publishedAt: daysAgo(11), publishedBy: mgrKey,
      fulfilledAt: daysAgo(4),
      visibilityType: 'public',
      shift_name: `Art Gallery Opening - ${client.name}`,
      client_name: client.name,
      date: daysAgo(4),
      start_time: '18:00', end_time: '23:00',
      venue_name: this.venues[2]!.name, venue_address: this.venues[2]!.address,
      venue_latitude: this.venues[2]!.lat, venue_longitude: this.venues[2]!.lng,
      city: 'Denver', state: 'CO', country: 'USA',
      contact_name: 'Elena Rivera', contact_phone: '+15551234567',
      headcount_total: 3,
      roles: [{ role: 'Server', count: 2 }, { role: 'Host', count: 1 }],
      accepted_staff: (() => {
        // Sheet-submitted attendance: needs clockInAt (required) + sheet times as Dates
        const sheetDate = daysAgo(4);
        const sheetIn = new Date(sheetDate); sheetIn.setHours(18, 0, 0);
        const sheetOut = new Date(sheetDate); sheetOut.setHours(23, 0, 0);
        const sheetAttendance = {
          clockInAt: sheetIn, clockOutAt: sheetOut,
          sheetSignInTime: sheetIn, sheetSignOutTime: sheetOut,
          estimatedHours: 5, approvedHours: 5,
          status: 'sheet_submitted',
        };
        return [
          this.staffEntry(juan, 'Server', [sheetAttendance]),
          this.staffEntry(cw[0]!, 'Server', [sheetAttendance]),
          this.staffEntry(cw[1]!, 'Host', [sheetAttendance]),
        ];
      })(),
      declined_staff: [], role_stats: [],
      audience_team_ids: [this.team._id],
      hoursStatus: 'sheet_submitted',
      chatEnabled: true,
      pay_rate_info: '$25/hr', version: 0,
    });
    console.log('   + Art Gallery Opening (SHEET SUBMITTED — needs approval)');

    // ────────────────────────────────────────────────────────
    // Event D: Partial approval — 5 days ago
    // Juan + Sofia approved, James + Olivia still clocked
    // ────────────────────────────────────────────────────────
    await EventModel.create({
      managerId: this.mgr._id,
      status: 'completed',
      publishedAt: daysAgo(12), publishedBy: mgrKey,
      fulfilledAt: daysAgo(5),
      visibilityType: 'public',
      shift_name: `Awards Dinner - ${client.name}`,
      client_name: client.name,
      date: daysAgo(5),
      start_time: '16:00', end_time: '23:00',
      venue_name: this.venues[0]!.name, venue_address: this.venues[0]!.address,
      venue_latitude: this.venues[0]!.lat, venue_longitude: this.venues[0]!.lng,
      city: 'Denver', state: 'CO', country: 'USA',
      contact_name: 'Elena Rivera', contact_phone: '+15551234567',
      headcount_total: 4,
      roles: [{ role: 'Server', count: 2 }, { role: 'Bartender', count: 1 }, { role: 'Host', count: 1 }],
      accepted_staff: [
        // Juan — APPROVED (7h)
        this.staffEntry(juan, 'Server', [
          this.clockSession(daysAgo(5), 16, 23, 'approved', { approvedHours: 7 }),
        ]),
        // Sofia — APPROVED (7h)
        this.staffEntry(cw[0]!, 'Bartender', [
          this.clockSession(daysAgo(5), 16, 23, 'approved', { approvedHours: 7 }),
        ]),
        // James — still CLOCKED (needs approval)
        this.staffEntry(cw[1]!, 'Server', [
          this.clockSession(daysAgo(5), 16, 23, 'clocked'),
        ]),
        // Olivia — still CLOCKED (needs approval)
        this.staffEntry(cw[2]!, 'Host', [
          this.clockSession(daysAgo(5), 16, 23, 'clocked'),
        ]),
      ],
      declined_staff: [], role_stats: [],
      audience_team_ids: [this.team._id],
      hoursStatus: 'sheet_submitted', // partially approved
      hoursApprovedBy: mgrKey,
      chatEnabled: true,
      pay_rate_info: '$25/hr', version: 0,
    });
    console.log('   + Awards Dinner (PARTIAL — 2/4 approved, 2 clocked)');

    // ────────────────────────────────────────────────────────
    // Event E: Disputed hours — 6 days ago
    // Juan says 5h but clock shows 4h
    // ────────────────────────────────────────────────────────
    await EventModel.create({
      managerId: this.mgr._id,
      status: 'completed',
      publishedAt: daysAgo(13), publishedBy: mgrKey,
      fulfilledAt: daysAgo(6),
      visibilityType: 'public',
      shift_name: `VIP Reception - ${client.name}`,
      client_name: client.name,
      date: daysAgo(6),
      start_time: '19:00', end_time: '23:00',
      venue_name: this.venues[1]!.name, venue_address: this.venues[1]!.address,
      venue_latitude: this.venues[1]!.lat, venue_longitude: this.venues[1]!.lng,
      city: 'Denver', state: 'CO', country: 'USA',
      contact_name: 'Elena Rivera', contact_phone: '+15551234567',
      headcount_total: 2,
      roles: [{ role: 'Bartender', count: 1 }, { role: 'Server', count: 1 }],
      accepted_staff: [
        this.staffEntry(juan, 'Bartender', [
          this.clockSession(daysAgo(6), 19, 23, 'disputed', {
            managerNotes: 'Staff claims 5h but clock shows 4h — needs discussion',
          }),
        ]),
        this.staffEntry(cw[0]!, 'Server', [
          this.clockSession(daysAgo(6), 19, 23, 'disputed'),
        ]),
      ],
      declined_staff: [], role_stats: [],
      audience_team_ids: [this.team._id],
      hoursStatus: 'pending',
      chatEnabled: true,
      pay_rate_info: '$30/hr', version: 0,
    });
    console.log('   + VIP Reception (DISPUTED — needs resolution)');
    console.log('');
  }

  // ── 3 Future Published Events ───────────────────────────
  private async seedFutureEvents() {
    console.log('   CREATING 3 FUTURE EVENTS...');
    const mgrKey = `${this.mgr.provider}:${this.mgr.subject}`;
    const juan = this.juan;

    const futureEvents = [
      { name: 'Spring Fundraiser Gala', days: 3, startH: 17, endH: 23, role: 'Bartender', client: 0, venue: 0 },
      { name: 'Corporate Team Building', days: 7, startH: 9, endH: 16, role: 'Server', client: 1, venue: 1 },
      { name: 'Summer Rooftop Social', days: 14, startH: 18, endH: 23, role: 'Host', client: 1, venue: 2 },
    ];

    for (const ev of futureEvents) {
      const evDate = daysAhead(ev.days);
      const client = this.clients[ev.client]!;
      const venue = this.venues[ev.venue]!;

      await EventModel.create({
        managerId: this.mgr._id,
        status: 'published',
        publishedAt: daysAgo(1), publishedBy: mgrKey,
        visibilityType: 'public',
        shift_name: `${ev.name} - ${client.name}`,
        client_name: client.name,
        date: evDate,
        start_time: `${String(ev.startH).padStart(2, '0')}:00`,
        end_time: `${String(ev.endH).padStart(2, '0')}:00`,
        venue_name: venue.name, venue_address: venue.address,
        venue_latitude: venue.latitude, venue_longitude: venue.lng,
        city: venue.city, state: venue.state, country: 'USA',
        contact_name: 'Elena Rivera', contact_phone: '+15551234567',
        headcount_total: 4,
        roles: [{ role: ev.role, count: 3 }, { role: 'Server', count: 1 }],
        accepted_staff: [
          this.staffEntry(juan, ev.role, []),
        ],
        declined_staff: [], role_stats: [],
        audience_team_ids: [this.team._id],
        hoursStatus: 'pending',
        chatEnabled: true,
        pay_rate_info: `$${ROLE_DEFS.find(r => r.name === ev.role)!.baseRate}/hr`,
        version: 0,
      });
      console.log(`   + ${ev.name} (${ev.days} days from now)`);
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

    // Juan staff token
    const juanToken = jwt.sign(
      {
        sub: STAFF_DEF.email, provider: 'email',
        email: STAFF_DEF.email, name: STAFF_DEF.name,
      },
      ENV.jwtSecret,
      { algorithm: 'HS256', expiresIn: '30d' },
    );
    this.tokens.push({ role: 'STAFF', name: STAFF_DEF.name, email: STAFF_DEF.email, token: juanToken });

    // Co-worker tokens
    for (const s of this.coworkers) {
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
    console.log('     DEMO SEED COMPLETE — APPROVAL WORKFLOW TESTING');
    console.log('='.repeat(65));
    console.log('');
    console.log('DATA CREATED:');
    console.log('   Manager:         1 (Elena Rivera — demo@flowshift.work)');
    console.log(`   Staff Users:     ${1 + this.coworkers.length} (Juan Suarez + ${this.coworkers.length} co-workers)`);
    console.log('   Team:            1 (Rivera Events Team)');
    console.log(`   Clients:         ${this.clients.length}`);
    console.log(`   Roles:           ${this.roles.length} (${ROLE_DEFS.map(r => r.name).join(', ')})`);
    console.log(`   Venues:          ${this.venues.length}`);
    console.log(`   Tariffs:         ${this.clients.length * this.roles.length}`);
    console.log('');
    console.log('EVENTS:');
    console.log('   8 completed + approved (earnings history)');
    console.log('   5 needing approval:');
    console.log('     - 2× clocked out, unapproved (CLOCKED)');
    console.log('     - 1× sign-in sheet uploaded (SHEET_SUBMITTED)');
    console.log('     - 1× partially approved (2/4 approved)');
    console.log('     - 1× disputed hours');
    console.log('   3 future published (Juan accepted)');
    console.log('');

    console.log('-'.repeat(65));
    console.log('APPROVAL TESTING GUIDE:');
    console.log('-'.repeat(65));
    console.log('');
    console.log('1. LOG IN AS MANAGER (demo@flowshift.work / FlowShift2024!)');
    console.log('2. Go to Payroll Export → select current month');
    console.log('   → Should see WARNING: "X staff across Y events have');
    console.log('     unapproved hours" (the 5 workflow events)');
    console.log('   → Only the 8 approved events should count toward earnings');
    console.log('3. Open an event with CLOCKED status → Approve hours');
    console.log('   → Refresh payroll → warning count decreases');
    console.log('4. Try Bulk Approve on partial event → should only approve');
    console.log('   eligible staff, not stamp all');
    console.log('5. Try individual approve with negative hours → should get 400');
    console.log('');

    console.log('-'.repeat(65));
    console.log('STAFF AI TEST:');
    console.log('-'.repeat(65));
    console.log('');
    console.log('1. LOG IN AS STAFF (juansegz07s@gmail.com via Google)');
    console.log('2. Ask AI: "How much did I earn this month?"');
    console.log('   → Should only count the approved events (NOT clocked/disputed)');
    console.log('   → Should match the Earnings page exactly');
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
    console.log('LOGIN CREDENTIALS:');
    console.log('-'.repeat(65));
    console.log('');
    console.log(`   Manager:  ${MANAGER_DEF.email} / ${MANAGER_DEF.password}`);
    console.log(`   Staff:    ${STAFF_DEF.email} (Google Sign-In — auto-links by email)`);
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
