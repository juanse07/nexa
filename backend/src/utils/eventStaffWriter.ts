import mongoose from 'mongoose';
import { EventStaffModel } from '../models/eventStaff';
import { EventModel } from '../models/event';
import { computeRoleStats } from './eventCapacity';

/**
 * Accept a staff member to an event.
 *
 * Uses a MongoDB transaction to atomically check capacity and insert.
 * Then dual-writes to the embedded accepted_staff array for backward compatibility.
 *
 * @param eventId - Event ObjectId
 * @param managerId - Manager ObjectId (denormalized for queries)
 * @param staffDoc - Staff member data (userKey, name, email, etc.)
 * @param roleCapacity - Max staff allowed for this role (Infinity to skip capacity check)
 * @param roleName - The role being accepted for
 * @returns The upserted EventStaff document
 * @throws Error with code 'CAPACITY_FULL' or 'ALREADY_ACCEPTED' on failure
 */
export async function acceptStaffToEvent(
  eventId: string | mongoose.Types.ObjectId,
  managerId: string | mongoose.Types.ObjectId,
  staffDoc: {
    userKey: string;
    provider?: string;
    subject?: string;
    email?: string;
    name?: string;
    first_name?: string;
    last_name?: string;
    picture?: string;
    role?: string;
    respondedAt?: Date;
  },
  roleCapacity: number,
  roleName: string
) {
  const eid = typeof eventId === 'string' ? new mongoose.Types.ObjectId(eventId) : eventId;
  const mid = typeof managerId === 'string' ? new mongoose.Types.ObjectId(managerId) : managerId;

  const session = await mongoose.startSession();
  try {
    let result: any;

    await session.withTransaction(async () => {
      // 1. Check capacity (skip if Infinity — e.g. private invites)
      if (isFinite(roleCapacity)) {
        const currentCount = await EventStaffModel.countDocuments(
          {
            eventId: eid,
            response: 'accept',
            role: { $regex: new RegExp(`^${roleName}$`, 'i') },
          },
          { session }
        );

        if (currentCount >= roleCapacity) {
          throw Object.assign(new Error(`No spots left for role '${roleName}'`), { code: 'CAPACITY_FULL' });
        }
      }

      // 2. Upsert EventStaff (unique index {eventId, userKey} prevents duplicates)
      result = await EventStaffModel.findOneAndUpdate(
        { eventId: eid, userKey: staffDoc.userKey },
        {
          $set: {
            managerId: mid,
            provider: staffDoc.provider,
            subject: staffDoc.subject,
            email: staffDoc.email,
            name: staffDoc.name,
            first_name: staffDoc.first_name,
            last_name: staffDoc.last_name,
            picture: staffDoc.picture,
            response: 'accept',
            role: staffDoc.role || roleName,
            respondedAt: staffDoc.respondedAt || new Date(),
          },
        },
        { upsert: true, new: true, session }
      );
    });

    // 3. Dual-write: sync embedded array (best-effort, does not roll back EventStaff)
    try {
      const embeddedDoc = {
        ...staffDoc,
        response: 'accept',
        role: staffDoc.role || roleName,
        respondedAt: staffDoc.respondedAt || new Date(),
      };

      await EventModel.updateOne(
        { _id: eid },
        {
          $pull: { declined_staff: { userKey: staffDoc.userKey } } as any,
        }
      );
      // Use $push with $ne to avoid duplicates in embedded array
      await EventModel.updateOne(
        { _id: eid, 'accepted_staff.userKey': { $ne: staffDoc.userKey } },
        {
          $push: { accepted_staff: embeddedDoc } as any,
          $inc: { version: 1 },
          $set: { updatedAt: new Date() },
        }
      );

      // Recompute role_stats from embedded array
      await recomputeEmbeddedRoleStats(eid);
    } catch (embeddedErr) {
      console.error('[eventStaffWriter] Dual-write (accept) embedded sync failed:', embeddedErr);
    }

    return result;
  } finally {
    await session.endSession();
  }
}

/**
 * Decline a staff member from an event.
 *
 * Upserts EventStaff with response='decline'. Then dual-writes: $pull from
 * accepted_staff and $push to declined_staff on the Event document.
 */
export async function declineStaffFromEvent(
  eventId: string | mongoose.Types.ObjectId,
  managerId: string | mongoose.Types.ObjectId,
  staffDoc: {
    userKey: string;
    provider?: string;
    subject?: string;
    email?: string;
    name?: string;
    first_name?: string;
    last_name?: string;
    picture?: string;
    role?: string;
    respondedAt?: Date;
  }
) {
  const eid = typeof eventId === 'string' ? new mongoose.Types.ObjectId(eventId) : eventId;
  const mid = typeof managerId === 'string' ? new mongoose.Types.ObjectId(managerId) : managerId;

  // Upsert EventStaff as declined
  const result = await EventStaffModel.findOneAndUpdate(
    { eventId: eid, userKey: staffDoc.userKey },
    {
      $set: {
        managerId: mid,
        provider: staffDoc.provider,
        subject: staffDoc.subject,
        email: staffDoc.email,
        name: staffDoc.name,
        first_name: staffDoc.first_name,
        last_name: staffDoc.last_name,
        picture: staffDoc.picture,
        response: 'decline',
        role: staffDoc.role,
        respondedAt: staffDoc.respondedAt || new Date(),
      },
    },
    { upsert: true, new: true }
  );

  // Dual-write: sync embedded arrays
  try {
    const embeddedDoc = {
      ...staffDoc,
      response: 'decline',
      respondedAt: staffDoc.respondedAt || new Date(),
    };

    await EventModel.updateOne(
      { _id: eid },
      {
        $pull: { accepted_staff: { userKey: staffDoc.userKey } } as any,
        $push: { declined_staff: embeddedDoc } as any,
        $inc: { version: 1 },
        $set: { updatedAt: new Date() },
      }
    );
    await recomputeEmbeddedRoleStats(eid);
  } catch (embeddedErr) {
    console.error('[eventStaffWriter] Dual-write (decline) embedded sync failed:', embeddedErr);
  }

  return result;
}

/**
 * Remove a staff member from an event entirely (not accept nor decline).
 * Deletes the EventStaff doc, then $pull from embedded accepted_staff.
 */
export async function removeStaffFromEvent(
  eventId: string | mongoose.Types.ObjectId,
  managerId: string | mongoose.Types.ObjectId,
  userKey: string
) {
  const eid = typeof eventId === 'string' ? new mongoose.Types.ObjectId(eventId) : eventId;

  const result = await EventStaffModel.deleteOne({ eventId: eid, userKey });

  // Dual-write: remove from embedded arrays
  try {
    await EventModel.updateOne(
      { _id: eid },
      {
        $pull: {
          accepted_staff: { userKey },
          declined_staff: { userKey },
        } as any,
        $set: { updatedAt: new Date() },
      }
    );
    await recomputeEmbeddedRoleStats(eid);
  } catch (embeddedErr) {
    console.error('[eventStaffWriter] Dual-write (remove) embedded sync failed:', embeddedErr);
  }

  return result;
}

/**
 * Bulk insert initial staff for a newly created event.
 * Used during event creation when accepted_staff is provided in the payload.
 */
export async function addInitialStaff(
  eventId: string | mongoose.Types.ObjectId,
  managerId: string | mongoose.Types.ObjectId,
  staffArray: any[]
) {
  if (!staffArray || staffArray.length === 0) return;

  const eid = typeof eventId === 'string' ? new mongoose.Types.ObjectId(eventId) : eventId;
  const mid = typeof managerId === 'string' ? new mongoose.Types.ObjectId(managerId) : managerId;

  const ops = staffArray.map((s: any) => ({
    updateOne: {
      filter: { eventId: eid, userKey: s.userKey },
      update: {
        $set: {
          managerId: mid,
          provider: s.provider,
          subject: s.subject,
          email: s.email,
          name: s.name,
          first_name: s.first_name,
          last_name: s.last_name,
          picture: s.picture,
          response: s.response || 'accept',
          role: s.role,
          respondedAt: s.respondedAt || new Date(),
        },
      },
      upsert: true,
    },
  }));

  await EventStaffModel.bulkWrite(ops, { ordered: false });
  // Embedded array is already set during EventModel.create — no dual-write needed here
}

/**
 * Clear all staff from an event.
 * Used during unpublish to reset the event.
 */
export async function clearEventStaff(
  eventId: string | mongoose.Types.ObjectId
) {
  const eid = typeof eventId === 'string' ? new mongoose.Types.ObjectId(eventId) : eventId;

  const result = await EventStaffModel.deleteMany({ eventId: eid });

  // Dual-write: clear embedded arrays
  try {
    await EventModel.updateOne(
      { _id: eid },
      {
        $set: {
          accepted_staff: [],
          declined_staff: [],
          role_stats: [],
          updatedAt: new Date(),
        },
      }
    );
  } catch (embeddedErr) {
    console.error('[eventStaffWriter] Dual-write (clear) embedded sync failed:', embeddedErr);
  }

  return result;
}

/**
 * Recompute and persist role_stats on the Event document from the embedded accepted_staff.
 * Called after dual-write operations to keep role_stats in sync.
 */
async function recomputeEmbeddedRoleStats(eventId: mongoose.Types.ObjectId) {
  const event = await EventModel.findById(eventId, { roles: 1, accepted_staff: 1 }).lean();
  if (!event) return;
  const roleStats = computeRoleStats(
    (event.roles as any[]) || [],
    (event.accepted_staff as any[]) || []
  );
  await EventModel.updateOne({ _id: eventId }, { $set: { role_stats: roleStats } });
}

/**
 * Compute role_stats directly from the EventStaff collection (for Phase 4 reads).
 * Feature-flagged: only used when USE_EVENT_STAFF=true.
 */
export async function computeRoleStatsFromCollection(
  eventId: string | mongoose.Types.ObjectId,
  roles: any[]
) {
  const eid = typeof eventId === 'string' ? new mongoose.Types.ObjectId(eventId) : eventId;

  const counts = await EventStaffModel.aggregate([
    { $match: { eventId: eid, response: 'accept' } },
    { $group: { _id: { $toLower: '$role' }, count: { $sum: 1 } } },
  ]);

  const countMap: Record<string, number> = {};
  for (const c of counts) {
    countMap[c._id || ''] = c.count;
  }

  return (roles || []).map((r: any) => {
    const key = (r?.role || '').toLowerCase();
    const capacity = r?.count || 0;
    const taken = countMap[key] || 0;
    const remaining = Math.max(capacity - taken, 0);
    return { role: r.role, capacity, taken, remaining, is_full: remaining === 0 && capacity > 0 };
  });
}
