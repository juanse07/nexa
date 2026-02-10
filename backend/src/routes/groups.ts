import { Router, Request, Response } from 'express';
import mongoose from 'mongoose';
import { z } from 'zod';
import { requireAuth } from '../middleware/requireAuth';
import { resolveManagerForRequest } from '../utils/manager';
import { StaffGroupModel } from '../models/staffGroup';
import { StaffProfileModel } from '../models/staffProfile';

const router = Router();

// ============================================================================
// GET /groups — List manager's groups with member counts
// ============================================================================

router.get('/groups', requireAuth, async (req: Request, res: Response) => {
  try {
    const manager = await resolveManagerForRequest(req as any);
    if (!manager || !manager._id) {
      return res.status(400).json({ message: 'Manager not found' });
    }
    const managerId = manager._id as mongoose.Types.ObjectId;

    const groups = await StaffGroupModel.find({ managerId }).sort({ name: 1 }).lean();

    // Get member counts per group in one aggregation
    const counts = await StaffProfileModel.aggregate([
      { $match: { managerId, groupIds: { $exists: true, $ne: [] } } },
      { $unwind: '$groupIds' },
      { $group: { _id: '$groupIds', count: { $sum: 1 } } },
    ]);
    const countMap: Record<string, number> = {};
    for (const c of counts) {
      countMap[String(c._id)] = c.count;
    }

    const payload = groups.map((g: any) => ({
      id: String(g._id),
      name: g.name,
      color: g.color || null,
      memberCount: countMap[String(g._id)] || 0,
      createdAt: g.createdAt,
    }));

    return res.json({ items: payload });
  } catch (err: any) {
    console.error('[GET /groups] Error:', err);
    return res.status(500).json({ message: err.message || 'Server error' });
  }
});

// ============================================================================
// POST /groups — Create a new group
// ============================================================================

const createGroupSchema = z.object({
  name: z.string().min(1).max(100),
  color: z.string().regex(/^#[0-9A-Fa-f]{6}$/).optional(),
});

router.post('/groups', requireAuth, async (req: Request, res: Response) => {
  try {
    const manager = await resolveManagerForRequest(req as any);
    if (!manager || !manager._id) {
      return res.status(400).json({ message: 'Manager not found' });
    }
    const managerId = manager._id as mongoose.Types.ObjectId;

    const parsed = createGroupSchema.safeParse(req.body);
    if (!parsed.success) {
      return res.status(400).json({ error: 'Validation failed', details: parsed.error.format() });
    }

    const { name, color } = parsed.data;

    const group = new StaffGroupModel({ managerId, name, color });
    await group.save();

    return res.status(201).json({
      id: String(group._id),
      name: group.name,
      color: group.color || null,
      memberCount: 0,
    });
  } catch (err: any) {
    if (err.code === 11000) {
      return res.status(409).json({ message: 'A group with that name already exists' });
    }
    console.error('[POST /groups] Error:', err);
    return res.status(500).json({ message: err.message || 'Server error' });
  }
});

// ============================================================================
// PATCH /groups/:groupId — Update group name/color
// ============================================================================

const updateGroupSchema = z.object({
  name: z.string().min(1).max(100).optional(),
  color: z.string().regex(/^#[0-9A-Fa-f]{6}$/).nullish(),
});

router.patch('/groups/:groupId', requireAuth, async (req: Request, res: Response) => {
  try {
    const manager = await resolveManagerForRequest(req as any);
    if (!manager || !manager._id) {
      return res.status(400).json({ message: 'Manager not found' });
    }
    const managerId = manager._id as mongoose.Types.ObjectId;
    const groupId = req.params.groupId as string;

    if (!mongoose.Types.ObjectId.isValid(groupId)) {
      return res.status(400).json({ message: 'Invalid group ID' });
    }

    const parsed = updateGroupSchema.safeParse(req.body);
    if (!parsed.success) {
      return res.status(400).json({ error: 'Validation failed', details: parsed.error.format() });
    }

    const update: any = {};
    if (parsed.data.name !== undefined) update.name = parsed.data.name;
    if (parsed.data.color !== undefined) update.color = parsed.data.color;

    if (Object.keys(update).length === 0) {
      return res.status(400).json({ message: 'No fields to update' });
    }

    const group = await StaffGroupModel.findOneAndUpdate(
      { _id: new mongoose.Types.ObjectId(groupId), managerId },
      { $set: update },
      { new: true }
    ).lean();

    if (!group) {
      return res.status(404).json({ message: 'Group not found' });
    }

    return res.json({
      id: String(group._id),
      name: group.name,
      color: group.color || null,
    });
  } catch (err: any) {
    if (err.code === 11000) {
      return res.status(409).json({ message: 'A group with that name already exists' });
    }
    console.error('[PATCH /groups/:groupId] Error:', err);
    return res.status(500).json({ message: err.message || 'Server error' });
  }
});

// ============================================================================
// DELETE /groups/:groupId — Delete group and pull from all StaffProfiles
// ============================================================================

router.delete('/groups/:groupId', requireAuth, async (req: Request, res: Response) => {
  try {
    const manager = await resolveManagerForRequest(req as any);
    if (!manager || !manager._id) {
      return res.status(400).json({ message: 'Manager not found' });
    }
    const managerId = manager._id as mongoose.Types.ObjectId;
    const groupId = req.params.groupId as string;

    if (!mongoose.Types.ObjectId.isValid(groupId)) {
      return res.status(400).json({ message: 'Invalid group ID' });
    }

    const oid = new mongoose.Types.ObjectId(groupId);
    const group = await StaffGroupModel.findOneAndDelete({ _id: oid, managerId });

    if (!group) {
      return res.status(404).json({ message: 'Group not found' });
    }

    // Remove groupId from all StaffProfiles
    await StaffProfileModel.updateMany(
      { managerId, groupIds: oid },
      { $pull: { groupIds: oid } }
    );

    return res.json({ message: 'Group deleted' });
  } catch (err: any) {
    console.error('[DELETE /groups/:groupId] Error:', err);
    return res.status(500).json({ message: err.message || 'Server error' });
  }
});

// ============================================================================
// POST /groups/:groupId/members — Add userKeys to group
// ============================================================================

const addMembersSchema = z.object({
  userKeys: z.array(z.string().min(1)).min(1),
});

router.post('/groups/:groupId/members', requireAuth, async (req: Request, res: Response) => {
  try {
    const manager = await resolveManagerForRequest(req as any);
    if (!manager || !manager._id) {
      return res.status(400).json({ message: 'Manager not found' });
    }
    const managerId = manager._id as mongoose.Types.ObjectId;
    const groupId = req.params.groupId as string;

    if (!mongoose.Types.ObjectId.isValid(groupId)) {
      return res.status(400).json({ message: 'Invalid group ID' });
    }

    const parsed = addMembersSchema.safeParse(req.body);
    if (!parsed.success) {
      return res.status(400).json({ error: 'Validation failed', details: parsed.error.format() });
    }

    // Verify group belongs to manager
    const group = await StaffGroupModel.findOne({
      _id: new mongoose.Types.ObjectId(groupId),
      managerId,
    });
    if (!group) {
      return res.status(404).json({ message: 'Group not found' });
    }

    const oid = new mongoose.Types.ObjectId(groupId);

    // Upsert StaffProfiles and $addToSet groupId
    const ops = parsed.data.userKeys.map((userKey) => ({
      updateOne: {
        filter: { managerId, userKey },
        update: { $addToSet: { groupIds: oid } },
        upsert: true,
      },
    }));

    await StaffProfileModel.bulkWrite(ops);

    return res.json({ message: 'Members added', count: parsed.data.userKeys.length });
  } catch (err: any) {
    console.error('[POST /groups/:groupId/members] Error:', err);
    return res.status(500).json({ message: err.message || 'Server error' });
  }
});

// ============================================================================
// DELETE /groups/:groupId/members/:userKey — Remove a member from group
// ============================================================================

router.delete('/groups/:groupId/members/:userKey', requireAuth, async (req: Request, res: Response) => {
  try {
    const manager = await resolveManagerForRequest(req as any);
    if (!manager || !manager._id) {
      return res.status(400).json({ message: 'Manager not found' });
    }
    const managerId = manager._id as mongoose.Types.ObjectId;
    const groupId = req.params.groupId as string;
    const userKey = decodeURIComponent(req.params.userKey as string);

    if (!mongoose.Types.ObjectId.isValid(groupId)) {
      return res.status(400).json({ message: 'Invalid group ID' });
    }

    const oid = new mongoose.Types.ObjectId(groupId);

    const result = await StaffProfileModel.findOneAndUpdate(
      { managerId, userKey, groupIds: oid },
      { $pull: { groupIds: oid } },
      { new: true }
    );

    if (!result) {
      return res.status(404).json({ message: 'Member not found in group' });
    }

    return res.json({ message: 'Member removed' });
  } catch (err: any) {
    console.error('[DELETE /groups/:groupId/members/:userKey] Error:', err);
    return res.status(500).json({ message: err.message || 'Server error' });
  }
});

export default router;
