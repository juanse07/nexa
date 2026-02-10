/**
 * FULFILL EXPIRED EVENTS SCRIPT
 *
 * Finds all expired unfulfilled events (past + published + not fully staffed)
 * and converts them to completed events with:
 * - Full accepted_staff rosters with attendance sessions
 * - Updated role_stats (all roles full)
 * - Status set to 'completed'
 * - Hours approved
 * - Tariffs ensured for all manager/client/role combos
 *
 * Usage:
 *   cd backend && npx ts-node scripts/fulfill-expired-events.ts
 */

import mongoose from 'mongoose';
import { ENV } from '../src/config/env';

// ════════════════════════════════════════════════════════════
// CONNECT (same pattern as bulky-seed.ts)
// ════════════════════════════════════════════════════════════

async function main() {
  if (!ENV.mongoUri) throw new Error('MONGO_URI required in .env');

  const dbName = ENV.nodeEnv === 'production' ? 'nexa_prod' : 'nexa_test';
  let uri = ENV.mongoUri.trim().replace(/\/$/, '');
  // Insert DB name before query string: ...mongodb.net/?opts → ...mongodb.net/dbName?opts
  const qIdx = uri.indexOf('?');
  if (qIdx >= 0) {
    uri = uri.substring(0, qIdx) + '/' + dbName + uri.substring(qIdx);
  } else {
    uri = `${uri}/${dbName}`;
  }

  console.log(`\n  Connecting to MongoDB (${dbName})...\n`);
  await mongoose.connect(uri, { serverSelectionTimeoutMS: 30000 });
  console.log(`  Connected to: ${dbName}\n`);
  const db = mongoose.connection.db!;

  const shifts = db.collection('shifts');
  const users = db.collection('users');
  const roles = db.collection('roles');
  const tariffs = db.collection('tariffs');
  const clients = db.collection('clients');
  const teamMembers = db.collection('teammembers');

  // ── Step 1: Find expired events (past + published/confirmed + not fully staffed)
  const now = new Date();
  now.setHours(0, 0, 0, 0);

  const expiredEvents = await shifts.find({
    status: { $in: ['published', 'confirmed', 'in_progress'] },
    date: { $lt: now },
  }).toArray();

  console.log(`  Found ${expiredEvents.length} expired unfulfilled events\n`);

  if (expiredEvents.length === 0) {
    console.log('  Nothing to do!');
    await mongoose.disconnect();
    return;
  }

  let totalUpdated = 0;
  let tariffsCreated = 0;

  for (const event of expiredEvents) {
    const managerId = event.managerId;
    const eventDate = new Date(event.date);
    const startTime = event.start_time || '10:00';
    const endTime = event.end_time || '18:00';
    const startH = parseInt(startTime.split(':')[0]) || 10;
    const endH = parseInt(endTime.split(':')[0]) || 18;
    const eventRoles: { role: string; count: number }[] = event.roles || [];
    const headcount = eventRoles.reduce((s: number, r: { count: number }) => s + r.count, 0);

    console.log(`  Processing: "${event.shift_name}" (${eventDate.toISOString().split('T')[0]})`);
    console.log(`    Roles: ${eventRoles.map((r: { role: string; count: number }) => `${r.role}×${r.count}`).join(', ')} = ${headcount} total`);

    // ── Step 2: Get staff from manager's team
    const teamStaff = await teamMembers.find({
      managerId: managerId,
      status: 'active',
    }).limit(headcount + 20).toArray();

    if (teamStaff.length === 0) {
      console.log(`    ⚠ No team members found for manager ${managerId}, skipping`);
      continue;
    }

    // Look up full user records for the staff
    const staffUserKeys = teamStaff.map(tm => `${tm.provider}:${tm.subject}`);
    const uniqueKeys = [...new Set(staffUserKeys)];
    const staffUsers = await users.find({
      $or: uniqueKeys.slice(0, headcount).map(uk => {
        const [provider, subject] = uk.split(':');
        return { provider, subject };
      }),
    }).toArray();

    // Build a map for quick lookup
    const userMap = new Map<string, any>();
    for (const u of staffUsers) {
      userMap.set(`${u.provider}:${u.subject}`, u);
    }

    // ── Step 3: Build accepted_staff for each role
    const accepted_staff: any[] = [];
    let staffIdx = 0;
    const availableStaff = uniqueKeys.filter(uk => userMap.has(uk));

    for (const roleReq of eventRoles) {
      for (let i = 0; i < roleReq.count; i++) {
        if (staffIdx >= availableStaff.length) {
          // Wrap around if we don't have enough unique staff
          staffIdx = 0;
        }
        const uk = availableStaff[staffIdx]!;
        const user = userMap.get(uk);
        if (!user || !uk) { staffIdx++; continue; }

        const [provider, subject] = uk.split(':');
        const ciDate = new Date(eventDate);
        const coDate = new Date(eventDate);
        ciDate.setHours(startH, Math.floor(Math.random() * 15), 0);
        coDate.setHours(endH, Math.floor(Math.random() * 30), 0);
        const hrs = Math.round(((coDate.getTime() - ciDate.getTime()) / 3600000) * 10) / 10;

        accepted_staff.push({
          userKey: uk,
          provider,
          subject,
          email: user.email || `${subject}@test.nexa.com`,
          name: user.name || `Staff ${staffIdx}`,
          first_name: user.first_name || 'Staff',
          last_name: user.last_name || `${staffIdx}`,
          role: roleReq.role,
          response: 'accepted',
          respondedAt: new Date(eventDate.getTime() - (1 + Math.floor(Math.random() * 5)) * 86400000),
          attendance: [{
            clockInAt: ciDate,
            clockOutAt: coDate,
            estimatedHours: hrs,
            approvedHours: hrs,
            status: 'approved',
            approvedBy: `system`,
            approvedAt: new Date(eventDate.getTime() + 86400000),
            clockInLocation: {
              latitude: event.venue_latitude || 34.0522,
              longitude: event.venue_longitude || -118.2437,
              accuracy: 10 + Math.floor(Math.random() * 40),
              source: 'geofence',
            },
            clockOutLocation: {
              latitude: (event.venue_latitude || 34.0522) + (Math.random() * 0.001 - 0.0005),
              longitude: (event.venue_longitude || -118.2437) + (Math.random() * 0.001 - 0.0005),
              accuracy: 10 + Math.floor(Math.random() * 40),
            },
          }],
        });

        staffIdx++;
      }
    }

    // ── Step 4: Build role_stats (all full)
    const role_stats = eventRoles.map((r: { role: string; count: number }) => {
      const taken = accepted_staff.filter(s => s.role === r.role).length;
      return {
        role: r.role,
        capacity: r.count,
        taken,
        remaining: 0,
        is_full: true,
      };
    });

    // ── Step 5: Ensure tariffs exist for this event's client/roles
    const clientName = event.client_name;
    const clientDoc = await clients.findOne({ managerId, name: clientName });
    if (clientDoc) {
      const managerRoles = await roles.find({ managerId }).toArray();
      const roleNameToId = new Map<string, any>();
      for (const r of managerRoles) {
        roleNameToId.set(r.name, r._id);
      }

      for (const roleReq of eventRoles) {
        const roleId = roleNameToId.get(roleReq.role);
        if (!roleId) continue;

        const existing = await tariffs.findOne({
          managerId,
          clientId: clientDoc._id,
          roleId,
        });

        if (!existing) {
          // Create a reasonable tariff
          const baseRates: Record<string, number> = {
            'Server': 25, 'Bartender': 30, 'Host': 22,
            'Executive Chef': 45, 'Event Coordinator': 40,
            'Security': 28, 'Busser': 20,
          };
          const rate = baseRates[roleReq.role] || 25;

          await tariffs.insertOne({
            managerId,
            clientId: clientDoc._id,
            roleId,
            rate,
            currency: 'USD',
            createdAt: new Date(),
            updatedAt: new Date(),
          });
          tariffsCreated++;
        }
      }
    }

    // ── Step 6: Update the event
    await shifts.updateOne(
      { _id: event._id },
      {
        $set: {
          status: 'completed',
          accepted_staff,
          role_stats,
          headcount_total: headcount,
          fulfilledAt: new Date(eventDate.getTime() + (endH - startH) * 3600000),
          hoursStatus: 'approved',
          hoursApprovedBy: 'system',
          hoursApprovedAt: new Date(eventDate.getTime() + 2 * 86400000),
        },
      },
    );

    totalUpdated++;
    console.log(`    ✓ Filled with ${accepted_staff.length} staff, status → completed`);
  }

  console.log(`\n  ════════════════════════════════════════`);
  console.log(`  DONE!`);
  console.log(`    Events updated: ${totalUpdated}`);
  console.log(`    Tariffs created: ${tariffsCreated}`);
  console.log(`  ════════════════════════════════════════\n`);

  await mongoose.disconnect();
}

main().catch(err => {
  console.error('Script failed:', err);
  mongoose.disconnect();
  process.exit(1);
});
