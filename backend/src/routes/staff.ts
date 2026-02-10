import { Router, Request, Response } from 'express';
import mongoose from 'mongoose';
import { requireAuth } from '../middleware/requireAuth';
import { resolveManagerForRequest } from '../utils/manager';
import { TeamMemberModel } from '../models/teamMember';
import { StaffProfileModel } from '../models/staffProfile';
import { StaffGroupModel } from '../models/staffGroup';
import { EventModel } from '../models/event';

const router = Router();

// ============================================================================
// HELPERS
// ============================================================================

function getDateRange(period: string): { start: Date; end: Date } {
  const now = new Date();
  let start: Date;
  const end = new Date(now);
  end.setHours(23, 59, 59, 999);

  switch (period) {
    case 'week':
      start = new Date(now);
      start.setDate(start.getDate() - 7);
      start.setHours(0, 0, 0, 0);
      break;
    case 'month':
      start = new Date(now.getFullYear(), now.getMonth(), 1);
      start.setHours(0, 0, 0, 0);
      break;
    default: // 'all'
      start = new Date(2020, 0, 1);
  }

  return { start, end };
}

function calculateShiftHours(event: any, userKey: string): number {
  const acceptedStaff = event.accepted_staff || [];
  const userInShift = acceptedStaff.find((s: any) => s.userKey === userKey);
  if (!userInShift || (userInShift.response !== 'accepted' && userInShift.response !== 'accept')) return 0;

  const attendance = (userInShift.attendance || []) as any[];
  if (attendance.length > 0) {
    const record = attendance[attendance.length - 1];
    if (record.approvedHours) return record.approvedHours;
    if (record.clockInAt && record.clockOutAt) {
      const clockIn = new Date(record.clockInAt);
      const clockOut = new Date(record.clockOutAt);
      return (clockOut.getTime() - clockIn.getTime()) / (1000 * 60 * 60);
    }
  }

  // Fall back to scheduled hours
  const startTime = event.start_time;
  const endTime = event.end_time;
  if (startTime && endTime) {
    const startParts = startTime.split(':').map(Number);
    const endParts = endTime.split(':').map(Number);
    let hours = (endParts[0] + endParts[1] / 60) - (startParts[0] + startParts[1] / 60);
    if (hours < 0) hours += 24;
    return hours;
  }

  return 0;
}

// ============================================================================
// GET /staff — List staff with profiles, favorites, roles, shift count
// ============================================================================

router.get('/staff', requireAuth, async (req: Request, res: Response) => {
  try {
    const manager = await resolveManagerForRequest(req as any);
    if (!manager || !manager._id) {
      return res.status(400).json({ message: 'Manager not found' });
    }
    const managerId = manager._id as mongoose.Types.ObjectId;

    const q = (req.query.q ?? '').toString().trim();
    const favorite = req.query.favorite;
    const groupId = (req.query.groupId ?? '').toString().trim();
    const cursor = (req.query.cursor ?? '').toString();
    const limit = Math.min(parseInt((req.query.limit ?? '50').toString(), 10) || 50, 100);

    // Build aggregation pipeline
    const pipeline: any[] = [
      { $match: { managerId, status: 'active' } },
    ];

    if (q) {
      pipeline.push({
        $match: {
          $or: [
            { name: { $regex: q, $options: 'i' } },
            { email: { $regex: q, $options: 'i' } },
          ],
        },
      });
    }

    if (cursor) {
      try {
        const cursorId = new mongoose.Types.ObjectId(cursor);
        pipeline.push({ $match: { _id: { $gt: cursorId } } });
      } catch (_e) { /* invalid cursor, skip */ }
    }

    // Lookup user profile
    pipeline.push({
      $lookup: {
        from: 'users',
        let: { memberProvider: '$provider', memberSubject: '$subject' },
        pipeline: [
          {
            $match: {
              $expr: {
                $and: [
                  { $eq: ['$provider', '$$memberProvider'] },
                  { $eq: ['$subject', '$$memberSubject'] },
                ],
              },
            },
          },
          {
            $project: {
              _id: 1, provider: 1, subject: 1, email: 1, name: 1,
              first_name: 1, last_name: 1, phone_number: 1, picture: 1,
            },
          },
        ],
        as: 'userProfile',
      },
    });

    // Add computed userKey field
    pipeline.push({
      $addFields: {
        userKey: { $concat: ['$provider', ':', '$subject'] },
      },
    });

    // Lookup staff profile (manager annotations)
    pipeline.push({
      $lookup: {
        from: 'staffprofiles',
        let: { uk: '$userKey' },
        pipeline: [
          {
            $match: {
              $expr: {
                $and: [
                  { $eq: ['$managerId', managerId] },
                  { $eq: ['$userKey', '$$uk'] },
                ],
              },
            },
          },
        ],
        as: 'staffProfile',
      },
    });

    // Lookup groups from staffProfile's groupIds
    pipeline.push({
      $lookup: {
        from: 'staffgroups',
        let: { gids: { $ifNull: [{ $arrayElemAt: ['$staffProfile.groupIds', 0] }, []] } },
        pipeline: [
          { $match: { $expr: { $in: ['$_id', '$$gids'] } } },
          { $project: { _id: 1, name: 1, color: 1 } },
        ],
        as: 'groups',
      },
    });

    // Filter by groupId if requested
    if (groupId && mongoose.Types.ObjectId.isValid(groupId)) {
      const gid = new mongoose.Types.ObjectId(groupId);
      pipeline.push({
        $match: {
          'staffProfile.0.groupIds': gid,
        },
      });
    }

    pipeline.push({ $sort: { _id: 1 } });
    pipeline.push({ $limit: limit + 1 });

    let members = await TeamMemberModel.aggregate(pipeline);

    // Filter by favorite if requested (post-lookup since StaffProfile is joined)
    if (favorite === 'true') {
      members = members.filter((m: any) => m.staffProfile?.[0]?.isFavorite === true);
    }

    // Collect all userKeys for batch event query
    const userKeys = members.map((m: any) => m.userKey);

    // Batch query: get distinct roles + shift count per user from events
    const eventStats = await EventModel.aggregate([
      {
        $match: {
          managerId,
          'accepted_staff.userKey': { $in: userKeys },
          status: { $ne: 'cancelled' },
        },
      },
      { $unwind: '$accepted_staff' },
      {
        $match: {
          'accepted_staff.userKey': { $in: userKeys },
          'accepted_staff.response': { $in: ['accepted', 'accept'] },
        },
      },
      {
        $group: {
          _id: '$accepted_staff.userKey',
          roles: { $addToSet: '$accepted_staff.role' },
          shiftCount: { $sum: 1 },
        },
      },
    ]);

    const statsMap: Record<string, { roles: string[]; shiftCount: number }> = {};
    for (const stat of eventStats) {
      statsMap[stat._id] = {
        roles: (stat.roles || []).filter(Boolean),
        shiftCount: stat.shiftCount || 0,
      };
    }

    // Determine pagination
    const hasMore = members.length > limit;
    const items = hasMore ? members.slice(0, limit) : members;
    const nextCursor = hasMore ? String(items[items.length - 1]._id) : null;

    const payload = items.map((member: any) => {
      const userProfile = member.userProfile?.[0];
      const profile = member.staffProfile?.[0];
      const stats = statsMap[member.userKey] || { roles: [], shiftCount: 0 };

      const groups = (member.groups || []).map((g: any) => ({
        _id: String(g._id),
        name: g.name,
        color: g.color || null,
      }));

      return {
        id: String(member._id),
        userKey: member.userKey,
        provider: member.provider,
        subject: member.subject,
        email: userProfile?.email || member.email,
        name: userProfile?.name || member.name,
        first_name: userProfile?.first_name,
        last_name: userProfile?.last_name,
        phone_number: userProfile?.phone_number,
        picture: userProfile?.picture,
        notes: profile?.notes || '',
        rating: profile?.rating || 0,
        isFavorite: profile?.isFavorite || false,
        roles: stats.roles,
        shiftCount: stats.shiftCount,
        groups,
      };
    });

    return res.json({ items: payload, nextCursor });
  } catch (err: any) {
    console.error('[GET /staff] Error:', err);
    return res.status(500).json({ message: err.message || 'Server error' });
  }
});

// ============================================================================
// GET /staff/:userKey — Single staff detail + recent shifts
// ============================================================================

router.get('/staff/:userKey', requireAuth, async (req: Request, res: Response) => {
  try {
    const manager = await resolveManagerForRequest(req as any);
    if (!manager || !manager._id) {
      return res.status(400).json({ message: 'Manager not found' });
    }
    const managerId = manager._id as mongoose.Types.ObjectId;
    const userKey = decodeURIComponent(req.params.userKey as string);

    const [provider, subject] = userKey.split(':');
    if (!provider || !subject) {
      return res.status(400).json({ message: 'Invalid userKey format' });
    }

    // Get team member
    const member = await TeamMemberModel.findOne({
      managerId, provider, subject, status: 'active',
    }).lean();

    if (!member) {
      return res.status(404).json({ message: 'Staff member not found' });
    }

    // Get user profile
    const { UserModel } = await import('../models/user');
    const user = await UserModel.findOne({ provider, subject }).lean();

    // Get staff profile (annotations)
    const profile = await StaffProfileModel.findOne({ managerId, userKey }).lean();

    // Get recent shifts (last 10)
    const recentEvents = await EventModel.find({
      managerId,
      'accepted_staff.userKey': userKey,
      'accepted_staff.response': { $in: ['accepted', 'accept'] },
      status: { $ne: 'cancelled' },
    })
      .sort({ date: -1 })
      .limit(10)
      .lean();

    const recentShifts = recentEvents.map((event: any) => {
      const staffEntry = (event.accepted_staff || []).find((s: any) => s.userKey === userKey);
      return {
        eventId: String(event._id),
        eventName: event.event_name || event.name || 'Untitled',
        date: event.date,
        startTime: event.start_time,
        endTime: event.end_time,
        role: staffEntry?.role || 'Staff',
        hours: Math.round(calculateShiftHours(event, userKey) * 10) / 10,
        venueName: event.venue_name,
      };
    });

    // Get distinct roles
    const roleAgg = await EventModel.aggregate([
      {
        $match: {
          managerId,
          'accepted_staff.userKey': userKey,
          status: { $ne: 'cancelled' },
        },
      },
      { $unwind: '$accepted_staff' },
      { $match: { 'accepted_staff.userKey': userKey, 'accepted_staff.response': { $in: ['accepted', 'accept'] } } },
      { $group: { _id: null, roles: { $addToSet: '$accepted_staff.role' } } },
    ]);

    const roles = (roleAgg[0]?.roles || []).filter(Boolean);

    // Get groups for this staff member
    const groupIds = (profile as any)?.groupIds || [];
    let groups: any[] = [];
    if (groupIds.length > 0) {
      const groupDocs = await StaffGroupModel.find({ _id: { $in: groupIds }, managerId }).lean();
      groups = groupDocs.map((g: any) => ({
        _id: String(g._id),
        name: g.name,
        color: g.color || null,
      }));
    }

    return res.json({
      id: String(member._id),
      userKey,
      provider: member.provider,
      subject: member.subject,
      email: (user as any)?.email || member.email,
      name: (user as any)?.name || member.name,
      first_name: (user as any)?.first_name,
      last_name: (user as any)?.last_name,
      phone_number: (user as any)?.phone_number,
      picture: (user as any)?.picture,
      notes: (profile as any)?.notes || '',
      rating: (profile as any)?.rating || 0,
      isFavorite: (profile as any)?.isFavorite || false,
      roles,
      groups,
      recentShifts,
    });
  } catch (err: any) {
    console.error('[GET /staff/:userKey] Error:', err);
    return res.status(500).json({ message: err.message || 'Server error' });
  }
});

// ============================================================================
// GET /staff/:userKey/hours — Work hours by period (week/month/all)
// ============================================================================

router.get('/staff/:userKey/hours', requireAuth, async (req: Request, res: Response) => {
  try {
    const manager = await resolveManagerForRequest(req as any);
    if (!manager || !manager._id) {
      return res.status(400).json({ message: 'Manager not found' });
    }
    const managerId = manager._id as mongoose.Types.ObjectId;
    const userKey = decodeURIComponent(req.params.userKey as string);

    const computeHours = async (period: string) => {
      const { start, end } = getDateRange(period);
      const events = await EventModel.find({
        managerId,
        'accepted_staff.userKey': userKey,
        status: { $ne: 'cancelled' },
        date: { $gte: start, $lte: end },
      }).lean();

      let totalHours = 0;
      let shiftCount = 0;
      for (const event of events) {
        const hours = calculateShiftHours(event, userKey);
        if (hours > 0) {
          totalHours += hours;
          shiftCount++;
        }
      }
      return { hours: Math.round(totalHours * 10) / 10, shifts: shiftCount };
    };

    const [weekly, monthly, allTime] = await Promise.all([
      computeHours('week'),
      computeHours('month'),
      computeHours('all'),
    ]);

    return res.json({ weekly, monthly, allTime });
  } catch (err: any) {
    console.error('[GET /staff/:userKey/hours] Error:', err);
    return res.status(500).json({ message: err.message || 'Server error' });
  }
});

// ============================================================================
// PATCH /staff/:userKey — Update notes, rating, isFavorite (upsert)
// ============================================================================

router.patch('/staff/:userKey', requireAuth, async (req: Request, res: Response) => {
  try {
    const manager = await resolveManagerForRequest(req as any);
    if (!manager || !manager._id) {
      return res.status(400).json({ message: 'Manager not found' });
    }
    const managerId = manager._id as mongoose.Types.ObjectId;
    const userKey = decodeURIComponent(req.params.userKey as string);

    const update: any = {};
    if (req.body.notes !== undefined) update.notes = String(req.body.notes);
    if (req.body.rating !== undefined) {
      const rating = Number(req.body.rating);
      if (rating < 0 || rating > 5) {
        return res.status(400).json({ message: 'Rating must be between 0 and 5' });
      }
      update.rating = rating;
    }
    if (req.body.isFavorite !== undefined) update.isFavorite = Boolean(req.body.isFavorite);

    if (Object.keys(update).length === 0) {
      return res.status(400).json({ message: 'No fields to update' });
    }

    const profile = await StaffProfileModel.findOneAndUpdate(
      { managerId, userKey },
      { $set: update },
      { upsert: true, new: true }
    ).lean();

    return res.json(profile);
  } catch (err: any) {
    console.error('[PATCH /staff/:userKey] Error:', err);
    return res.status(500).json({ message: err.message || 'Server error' });
  }
});

export default router;
