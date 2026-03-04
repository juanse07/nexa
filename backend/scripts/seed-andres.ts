/**
 * ADDITIVE SEED SCRIPT — Andres Palacios (252 completed events)
 *
 * ⚠️  NON-DESTRUCTIVE: Does NOT drop any collections.
 *     Queries existing manager/team/venues/clients/roles, then INSERTS only.
 *
 * Creates:
 * - 1 Staff user: Andres Palacios (andresP@flowshift.com / FlowShift2024!)
 * - 1 TeamMember + 1 StaffProfile (linked to existing demo manager)
 * - 252 completed events (Jan 1, 2025 → Feb 25, 2026) with approved attendance
 * - Each event has 2–4 ghost co-workers for realistic headcount
 * - JWT token for API testing
 *
 * Idempotency:
 * - User/TeamMember/StaffProfile: check-then-create (safe to re-run)
 * - Events: NOT idempotent — re-running adds more events
 *
 * Usage:
 *   cd backend && npx ts-node --transpile-only scripts/seed-andres.ts
 *
 * Or on production server (inside Docker):
 *   docker exec nexa-api npx ts-node --transpile-only /app/src/scripts/seed-andres.ts
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
import { VenueModel } from '../src/models/venue';
import { EventModel } from '../src/models/event';
import { StaffProfileModel } from '../src/models/staffProfile';

// ════════════════════════════════════════════════════════════
// ANDRES CONFIG
// ════════════════════════════════════════════════════════════

const ANDRES = {
  first_name: 'Andres',
  last_name: 'Palacios',
  name: 'Andres Palacios',
  email: 'andresp@flowshift.com',
  provider: 'email' as const,
  subject: 'andresp@flowshift.com',
  password: 'FlowShift2024!',
};

const TARGET_EVENT_COUNT = 252;

// Ghost co-workers — fake names that appear alongside Andres in accepted_staff
const GHOST_STAFF = [
  { first: 'Maria',   last: 'Gonzalez', email: 'maria.g@ghost.local' },
  { first: 'Carlos',  last: 'Mendez',   email: 'carlos.m@ghost.local' },
  { first: 'Sofia',   last: 'Ramirez',  email: 'sofia.r@ghost.local' },
  { first: 'Diego',   last: 'Torres',   email: 'diego.t@ghost.local' },
  { first: 'Valentina', last: 'Cruz',   email: 'valentina.c@ghost.local' },
  { first: 'Miguel',  last: 'Herrera',  email: 'miguel.h@ghost.local' },
  { first: 'Isabella', last: 'Vargas',  email: 'isabella.v@ghost.local' },
  { first: 'Sebastian', last: 'Rojas',  email: 'sebastian.r@ghost.local' },
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

// Fallback data if DB has no venues/clients/roles
const FALLBACK_VENUES = [
  { name: 'Four Seasons Hotel Denver',    address: '1111 14th St',         city: 'Denver',      state: 'CO', lat: 39.7447, lng: -104.9997 },
  { name: 'The Ritz-Carlton, Denver',     address: '1881 Curtis St',       city: 'Denver',      state: 'CO', lat: 39.7473, lng: -104.9941 },
  { name: 'Denver Art Museum',            address: '100 W 14th Ave Pkwy',  city: 'Denver',      state: 'CO', lat: 39.7373, lng: -104.9896 },
  { name: 'Colorado Convention Center',   address: '700 14th St',          city: 'Denver',      state: 'CO', lat: 39.7392, lng: -104.9973 },
  { name: 'Ellie Caulkins Opera House',   address: '1385 Curtis St',       city: 'Denver',      state: 'CO', lat: 39.7396, lng: -105.0003 },
];

const FALLBACK_CLIENTS = [
  'The Grand Hyatt Group', 'Stellar Productions Inc', 'Rocky Mountain Event Co',
  'Mile High Hospitality Group', 'Denver Elite Catering',
];

const FALLBACK_ROLES = [
  'Server', 'Bartender', 'Host/Hostess', 'Event Coordinator',
  'Security', 'Barback', 'Setup Crew', 'Valet',
];

// ════════════════════════════════════════════════════════════
// UTILITIES (seeded PRNG — seed 9191)
// ════════════════════════════════════════════════════════════

function mulberry32(seed: number) {
  return function () {
    let t = (seed += 0x6d2b79f5);
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

const rand = mulberry32(9191);

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

class AndresSeed {
  private mgr: any;
  private team: any;
  private venues: { name: string; address: string; city: string; state: string; lat: number; lng: number }[] = [];
  private clientNames: string[] = [];
  private roleNames: string[] = [];
  private andresUser: any;
  private token = '';

  async run() {
    try {
      await this.connect();
      await this.loadManager();
      await this.loadTeam();
      await this.loadVenuesClientsRoles();
      await this.ensureAndresUser();
      await this.seedEvents();
      this.generateToken();
      this.report();
      await mongoose.disconnect();
      console.log('\n   Database disconnected. Andres seed complete!\n');
    } catch (err) {
      console.error('\n   ANDRES SEED FAILED:', err);
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

  // ── Load Existing Manager ──────────────────────────────
  private async loadManager() {
    console.log('   LOADING EXISTING MANAGER (demo@flowshift.work)...');
    this.mgr = await ManagerModel.findOne({ email: 'demo@flowshift.work' });
    if (!this.mgr) throw new Error('Manager demo@flowshift.work not found! Run seed:test-staff first.');
    console.log(`   Found: ${this.mgr.name} [${this.mgr._id}]\n`);
  }

  // ── Load Existing Team ─────────────────────────────────
  private async loadTeam() {
    console.log('   LOADING EXISTING TEAM...');
    this.team = await TeamModel.findOne({ managerId: this.mgr._id });
    if (!this.team) throw new Error('No team found for this manager! Run seed:test-staff first.');
    console.log(`   Found: ${this.team.name} [${this.team._id}]\n`);
  }

  // ── Load Venues/Clients/Roles (or use fallbacks) ──────
  private async loadVenuesClientsRoles() {
    console.log('   LOADING VENUES / CLIENTS / ROLES...');

    // Venues
    const dbVenues = await VenueModel.find({ managerId: this.mgr._id }).lean();
    if (dbVenues.length > 0) {
      this.venues = dbVenues.map((v: any) => ({
        name: v.name, address: v.address || '', city: v.city || 'Denver',
        state: v.state || 'CO', lat: v.latitude || 39.74, lng: v.longitude || -104.99,
      }));
      console.log(`   Venues: ${this.venues.length} from DB`);
    } else {
      this.venues = FALLBACK_VENUES;
      console.log(`   Venues: ${this.venues.length} (fallback)`);
    }

    // Clients
    const dbClients = await ClientModel.find({ managerId: this.mgr._id }).lean();
    if (dbClients.length > 0) {
      this.clientNames = dbClients.map((c: any) => c.name);
      console.log(`   Clients: ${this.clientNames.length} from DB`);
    } else {
      this.clientNames = FALLBACK_CLIENTS;
      console.log(`   Clients: ${this.clientNames.length} (fallback)`);
    }

    // Roles
    const dbRoles = await RoleModel.find({ managerId: this.mgr._id }).lean();
    if (dbRoles.length > 0) {
      this.roleNames = dbRoles.map((r: any) => r.name);
      console.log(`   Roles: ${this.roleNames.length} from DB`);
    } else {
      this.roleNames = FALLBACK_ROLES;
      console.log(`   Roles: ${this.roleNames.length} (fallback)`);
    }
    console.log('');
  }

  // ── Ensure Andres User (idempotent) ───────────────────
  private async ensureAndresUser() {
    console.log('   ENSURING ANDRES USER EXISTS...');
    const { provider, subject, email, name, first_name, last_name, password } = ANDRES;
    const userKey = `${provider}:${subject}`;

    // 1. UserModel
    let user = await UserModel.findOne({ provider, subject });
    if (user) {
      console.log(`   User already exists: ${user.name} [${user._id}]`);
    } else {
      const passwordHash = await bcrypt.hash(password, 10);
      user = await UserModel.create({
        provider, subject, email, name, first_name, last_name,
        passwordHash,
        subscription_tier: 'pro',
        subscription_status: 'active',
      });
      console.log(`   + Created User: ${name} [${user._id}]`);
    }
    this.andresUser = user;

    // 2. TeamMember
    const existingTM = await TeamMemberModel.findOne({
      teamId: this.team._id, provider, subject,
    });
    if (existingTM) {
      console.log(`   TeamMember already exists [${existingTM._id}]`);
    } else {
      const tm = await TeamMemberModel.create({
        teamId: this.team._id,
        managerId: this.mgr._id,
        provider, subject, email, name,
        invitedBy: this.mgr._id,
        joinedAt: new Date('2025-01-01'),
        status: 'active',
      });
      console.log(`   + Created TeamMember [${tm._id}]`);
    }

    // 3. StaffProfile
    const existingSP = await StaffProfileModel.findOne({
      managerId: this.mgr._id, userKey,
    });
    if (existingSP) {
      console.log(`   StaffProfile already exists [${existingSP._id}]`);
    } else {
      const sp = await StaffProfileModel.create({
        managerId: this.mgr._id,
        userKey,
        notes: 'Seeded test staff account',
        rating: 4,
        isFavorite: true,
        groupIds: [],
      });
      console.log(`   + Created StaffProfile [${sp._id}]`);
    }
    console.log('');
  }

  // ── Generate 252 Completed Events ─────────────────────
  private async seedEvents() {
    console.log(`   GENERATING ${TARGET_EVENT_COUNT} COMPLETED EVENTS...`);

    const mgrKey = `${this.mgr.provider}:${this.mgr.subject}`;
    const staffKey = `${ANDRES.provider}:${ANDRES.subject}`;
    const startDate = new Date('2025-01-01');
    const endDate = new Date('2026-02-25');

    // Generate spread dates and deduplicate by calendar day
    const rawDates = generateSpreadDates(startDate, endDate, TARGET_EVENT_COUNT);
    const seenDays = new Set<string>();
    const uniqueDates = rawDates.filter(d => {
      const key = d.toISOString().slice(0, 10);
      if (seenDays.has(key)) return false;
      seenDays.add(key);
      return true;
    });

    console.log(`   Unique dates generated: ${uniqueDates.length}`);

    const events: any[] = [];

    for (let ei = 0; ei < uniqueDates.length; ei++) {
      const eventDate = uniqueDates[ei]!;
      const venue = randomPick(this.venues);
      const clientName = randomPick(this.clientNames);
      const eventName = randomPick(EVENT_NAMES);
      const uniform = randomPick(UNIFORM_POOL);
      const andresRole = this.roleNames[ei % this.roleNames.length]!;
      const payRate = randomInt(20, 31);

      const startHour = randomInt(7, 17);
      const duration = randomInt(7, 10);
      const endHour = Math.min(startHour + duration, 23);
      const actualDuration = endHour - startHour;

      // Clock-in/out times
      const ciDate = new Date(eventDate);
      ciDate.setHours(startHour, randomInt(0, 10), 0);
      const coDate = new Date(eventDate);
      coDate.setHours(endHour, randomInt(0, 20), 0);
      const approvedHours = actualDuration + (rand() > 0.7 ? 0.5 : 0);

      // Build accepted_staff — Andres + 2-4 ghost co-workers
      const ghostCount = randomInt(2, 4);
      const accepted_staff: any[] = [];

      // Andres entry
      accepted_staff.push({
        userKey: staffKey,
        provider: ANDRES.provider,
        subject: ANDRES.subject,
        email: ANDRES.email,
        name: ANDRES.name,
        first_name: ANDRES.first_name,
        last_name: ANDRES.last_name,
        role: andresRole,
        response: 'accept',
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
      });

      // Ghost co-workers
      for (let gi = 0; gi < ghostCount; gi++) {
        const ghost = GHOST_STAFF[(ei * 3 + gi) % GHOST_STAFF.length]!;
        const ghostRole = this.roleNames[randomInt(0, this.roleNames.length - 1)]!;
        const gCi = new Date(eventDate);
        gCi.setHours(startHour, randomInt(0, 15), 0);
        const gCo = new Date(eventDate);
        gCo.setHours(endHour, randomInt(0, 20), 0);

        accepted_staff.push({
          userKey: `email:${ghost.email}`,
          provider: 'email',
          subject: ghost.email,
          email: ghost.email,
          name: `${ghost.first} ${ghost.last}`,
          first_name: ghost.first,
          last_name: ghost.last,
          role: ghostRole,
          response: 'accept',
          respondedAt: new Date(eventDate.getTime() - randomInt(1, 5) * 86400000),
          attendance: [{
            clockInAt: gCi,
            clockOutAt: gCo,
            estimatedHours: actualDuration,
            approvedHours: actualDuration,
            status: 'approved' as const,
            approvedBy: mgrKey,
            approvedAt: new Date(eventDate.getTime() + randomInt(1, 3) * 86400000),
            clockInLocation: {
              latitude: venue.lat + (rand() - 0.5) * 0.001,
              longitude: venue.lng + (rand() - 0.5) * 0.001,
              accuracy: randomInt(5, 30),
              source: 'geofence' as const,
            },
            clockOutLocation: {
              latitude: venue.lat + (rand() - 0.5) * 0.001,
              longitude: venue.lng + (rand() - 0.5) * 0.001,
              accuracy: randomInt(8, 30),
            },
          }],
        });
      }

      // Roles array for the event
      const uniqueRolesInStaff = [...new Set(accepted_staff.map((s: any) => s.role))];
      const rolesArr = uniqueRolesInStaff.map(role => {
        const staffInRole = accepted_staff.filter((s: any) => s.role === role).length;
        return { role, count: staffInRole + randomInt(0, 1) }; // capacity ≥ taken
      });
      const headcount = rolesArr.reduce((s, r) => s + r.count, 0);

      const role_stats = rolesArr.map(r => {
        const taken = accepted_staff.filter((s: any) => s.role === r.role).length;
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
        shift_name: `${eventName} - ${clientName}`,
        client_name: clientName,
        event_name: `${eventName} - ${clientName}`,
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
        contact_email: `events@${clientName.toLowerCase().replace(/\s+/g, '')}.com`,
        uniform,
        notes: `${eventName} hosted by ${clientName} at ${venue.name}.`,
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
    let inserted = 0;
    for (let i = 0; i < events.length; i += 50) {
      const batch = events.slice(i, i + 50);
      await EventModel.insertMany(batch);
      inserted += batch.length;
      console.log(`   Inserted batch ${Math.floor(i / 50) + 1}: ${inserted}/${events.length}`);
    }
    console.log(`\n   Total events inserted: ${events.length}\n`);
  }

  // ── Generate JWT Token ────────────────────────────────
  private generateToken() {
    console.log('   GENERATING JWT TOKEN (30-day expiry)...');
    this.token = jwt.sign(
      {
        sub: ANDRES.subject,
        provider: ANDRES.provider,
        email: ANDRES.email,
        name: ANDRES.name,
      },
      ENV.jwtSecret,
      { algorithm: 'HS256', expiresIn: '30d' },
    );
  }

  // ── Report ────────────────────────────────────────────
  private report() {
    console.log('\n');
    console.log('='.repeat(65));
    console.log('        ANDRES PALACIOS SEED COMPLETE');
    console.log('='.repeat(65));
    console.log('');
    console.log('STAFF USER:');
    console.log(`   Name:          ${ANDRES.name}`);
    console.log(`   Email:         ${ANDRES.email}`);
    console.log(`   Password:      ${ANDRES.password}`);
    console.log(`   Provider:      ${ANDRES.provider}`);
    console.log(`   Subscription:  pro / active`);
    console.log('');
    console.log('EVENTS:');
    console.log(`   Completed:     ${TARGET_EVENT_COUNT}+ (Jan 2025 → Feb 2026)`);
    console.log(`   Pay range:     $20–$31/hr`);
    console.log(`   Shift hours:   7–10 hours each`);
    console.log(`   Co-workers:    2–4 ghost staff per event`);
    console.log('');
    console.log('-'.repeat(65));
    console.log('JWT TOKEN (Authorization: Bearer <token>):');
    console.log('-'.repeat(65));
    console.log(`\n   [STAFF] ${ANDRES.name} (${ANDRES.email})`);
    console.log(`   ${this.token}`);
    console.log('');
    console.log('='.repeat(65));
  }
}

// ════════════════════════════════════════════════════════════
// ENTRY POINT
// ════════════════════════════════════════════════════════════

if (require.main === module) {
  new AndresSeed().run();
}
