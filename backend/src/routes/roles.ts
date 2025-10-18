import { Router } from 'express';
import mongoose from 'mongoose';
import { z } from 'zod';
import { requireAuth } from '../middleware/requireAuth';
import { RoleModel } from '../models/role';
import { resolveManagerForRequest } from '../utils/manager';

const router = Router();

const roleSchema = z.object({ name: z.string().min(1, 'name is required').max(200) });

router.get('/roles', requireAuth, async (req, res) => {
  try {
    const manager = await resolveManagerForRequest(req as any);
    const roles = await RoleModel.find(
      { managerId: manager._id },
      { _id: 1, name: 1 }
    )
      .sort({ normalizedName: 1 })
      .lean();
    const mapped = (roles || []).map((r: any) => ({ id: String(r._id), name: r.name }));
    return res.json(mapped);
  } catch (err) {
    return res.status(500).json({ message: 'Failed to fetch roles' });
  }
});

router.post('/roles', requireAuth, async (req, res) => {
  try {
    const manager = await resolveManagerForRequest(req as any);
    const parsed = roleSchema.safeParse(req.body);
    if (!parsed.success) return res.status(400).json({ message: 'Validation failed', details: parsed.error.format() });
    const name = parsed.data.name.trim();
    const existing = await RoleModel.findOne({
      managerId: manager._id,
      normalizedName: name.toLowerCase(),
    }).lean();
    if (existing) return res.status(409).json({ message: 'Role already exists' });
    const created = await RoleModel.create({ managerId: manager._id, name });
    return res.status(201).json({ id: String(created._id), name: created.name });
  } catch (err) {
    return res.status(500).json({ message: 'Failed to create role' });
  }
});

router.patch('/roles/:id', requireAuth, async (req, res) => {
  try {
    const manager = await resolveManagerForRequest(req as any);
    const id = req.params.id ?? '';
    if (!mongoose.Types.ObjectId.isValid(id)) return res.status(400).json({ message: 'Invalid role id' });
    const parsed = roleSchema.safeParse(req.body);
    if (!parsed.success) return res.status(400).json({ message: 'Validation failed', details: parsed.error.format() });
    const name = parsed.data.name.trim();
    const conflict = await RoleModel.findOne({
      managerId: manager._id,
      normalizedName: name.toLowerCase(),
      _id: { $ne: new mongoose.Types.ObjectId(id) },
    }).lean();
    if (conflict) return res.status(409).json({ message: 'Another role with that name already exists' });
    const result = await RoleModel.updateOne(
      { _id: new mongoose.Types.ObjectId(id), managerId: manager._id },
      { $set: { name, updatedAt: new Date() } }
    );
    if (result.matchedCount === 0) return res.status(404).json({ message: 'Role not found' });
    const updated = await RoleModel.findOne({ _id: new mongoose.Types.ObjectId(id), managerId: manager._id }).lean();
    return res.json({ id, name: updated?.name });
  } catch (err) {
    return res.status(500).json({ message: 'Failed to update role' });
  }
});

router.delete('/roles/:id', requireAuth, async (req, res) => {
  try {
    const manager = await resolveManagerForRequest(req as any);
    const id = req.params.id ?? '';
    if (!mongoose.Types.ObjectId.isValid(id)) return res.status(400).json({ message: 'Invalid role id' });
    const result = await RoleModel.deleteOne({ _id: new mongoose.Types.ObjectId(id), managerId: manager._id });
    if (result.deletedCount === 0) return res.status(404).json({ message: 'Role not found' });
    return res.json({ message: 'Role deleted' });
  } catch (err) {
    return res.status(500).json({ message: 'Failed to delete role' });
  }
});

export default router;

