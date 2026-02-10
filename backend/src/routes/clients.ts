import { Router } from 'express';
import mongoose from 'mongoose';
import { z } from 'zod';
import { requireAuth, AuthenticatedRequest } from '../middleware/requireAuth';
import { ClientModel } from '../models/client';
import { ManagerModel } from '../models/manager';
import { mergeClients } from '../services/catalogMergeService';

const router = Router();

const clientSchema = z.object({
  name: z.string().min(1, 'name is required').max(200),
});

// List clients (sorted by name)
router.get('/clients', requireAuth, async (req, res) => {
  try {
    const authUser = (req as any).authUser;
    let managerObjectId: mongoose.Types.ObjectId;

    if (authUser.managerId) {
      // Manager ID in token
      managerObjectId = new mongoose.Types.ObjectId(authUser.managerId);
    } else {
      // Look up manager by provider/subject
      const manager = await ManagerModel.findOne({
        provider: authUser.provider,
        subject: authUser.sub
      });
      if (!manager) {
        return res.status(403).json({ message: 'Manager not found' });
      }
      managerObjectId = manager._id as mongoose.Types.ObjectId;
    }

    const clients = await ClientModel.find(
      { managerId: managerObjectId },
      { _id: 1, name: 1 }
    )
      .sort({ normalizedName: 1 })
      .lean();
    const mapped = (clients || []).map((c: any) => ({ id: String(c._id), name: c.name }));
    return res.json(mapped);
  } catch (err) {
    return res.status(500).json({ message: 'Failed to fetch clients' });
  }
});

// Create a client (name unique, case-insensitive)
router.post('/clients', requireAuth, async (req, res) => {
  try {
    const authUser = (req as any).authUser;
    let managerObjectId: mongoose.Types.ObjectId;

    if (authUser.managerId) {
      managerObjectId = new mongoose.Types.ObjectId(authUser.managerId);
    } else {
      const manager = await ManagerModel.findOne({
        provider: authUser.provider,
        subject: authUser.sub
      });
      if (!manager) {
        return res.status(403).json({ message: 'Manager not found' });
      }
      managerObjectId = manager._id as mongoose.Types.ObjectId;
    }

    const parsed = clientSchema.safeParse(req.body);
    if (!parsed.success) {
      return res.status(400).json({ message: 'Validation failed', details: parsed.error.format() });
    }
    const name = parsed.data.name.trim();
    const existing = await ClientModel.findOne({
      managerId: managerObjectId,
      normalizedName: name.toLowerCase(),
    }).lean();
    if (existing) {
      return res.status(409).json({ message: 'Client already exists' });
    }
    const created = await ClientModel.create({ managerId: managerObjectId, name });
    return res.status(201).json({ id: String(created._id), name: created.name });
  } catch (err) {
    return res.status(500).json({ message: 'Failed to create client' });
  }
});

// Update a client name
router.patch('/clients/:id', requireAuth, async (req, res) => {
  try {
    const authUser = (req as any).authUser;
    let managerObjectId: mongoose.Types.ObjectId;

    if (authUser.managerId) {
      managerObjectId = new mongoose.Types.ObjectId(authUser.managerId);
    } else {
      const manager = await ManagerModel.findOne({
        provider: authUser.provider,
        subject: authUser.sub
      });
      if (!manager) {
        return res.status(403).json({ message: 'Manager not found' });
      }
      managerObjectId = manager._id as mongoose.Types.ObjectId;
    }

    const id = req.params.id ?? '';
    if (!mongoose.Types.ObjectId.isValid(id)) {
      return res.status(400).json({ message: 'Invalid client id' });
    }
    const parsed = clientSchema.safeParse(req.body);
    if (!parsed.success) {
      return res.status(400).json({ message: 'Validation failed', details: parsed.error.format() });
    }
    const name = parsed.data.name.trim();
    const conflict = await ClientModel.findOne({
      managerId: managerObjectId,
      normalizedName: name.toLowerCase(),
      _id: { $ne: new mongoose.Types.ObjectId(id) },
    }).lean();
    if (conflict) {
      return res.status(409).json({ message: 'Another client with that name already exists' });
    }
    const result = await ClientModel.updateOne(
      { _id: new mongoose.Types.ObjectId(id), managerId: managerObjectId },
      { $set: { name, updatedAt: new Date() } }
    );
    if (result.matchedCount === 0) return res.status(404).json({ message: 'Client not found' });
    const updated = await ClientModel.findOne({ _id: new mongoose.Types.ObjectId(id), managerId: managerObjectId }).lean();
    return res.json({ id, name: updated?.name });
  } catch (err) {
    return res.status(500).json({ message: 'Failed to update client' });
  }
});

// Delete a client
router.delete('/clients/:id', requireAuth, async (req, res) => {
  try {
    const authUser = (req as any).authUser;
    let managerObjectId: mongoose.Types.ObjectId;

    if (authUser.managerId) {
      managerObjectId = new mongoose.Types.ObjectId(authUser.managerId);
    } else {
      const manager = await ManagerModel.findOne({
        provider: authUser.provider,
        subject: authUser.sub
      });
      if (!manager) {
        return res.status(403).json({ message: 'Manager not found' });
      }
      managerObjectId = manager._id as mongoose.Types.ObjectId;
    }

    const id = req.params.id ?? '';
    if (!mongoose.Types.ObjectId.isValid(id)) {
      return res.status(400).json({ message: 'Invalid client id' });
    }
    const result = await ClientModel.deleteOne({
      _id: new mongoose.Types.ObjectId(id),
      managerId: managerObjectId,
    });
    if (result.deletedCount === 0) return res.status(404).json({ message: 'Client not found' });
    return res.json({ message: 'Client deleted' });
  } catch (err) {
    return res.status(500).json({ message: 'Failed to delete client' });
  }
});

// Merge clients: transfer events/tariffs from sources to target, delete sources
const mergeSchema = z.object({
  sourceIds: z.array(z.string().min(1)).min(1),
  targetId: z.string().min(1),
});

router.post('/clients/merge', requireAuth, async (req, res) => {
  try {
    const authUser = (req as any).authUser;
    let managerObjectId: mongoose.Types.ObjectId;

    if (authUser.managerId) {
      managerObjectId = new mongoose.Types.ObjectId(authUser.managerId);
    } else {
      const manager = await ManagerModel.findOne({
        provider: authUser.provider,
        subject: authUser.sub
      });
      if (!manager) {
        return res.status(403).json({ message: 'Manager not found' });
      }
      managerObjectId = manager._id as mongoose.Types.ObjectId;
    }

    const parsed = mergeSchema.safeParse(req.body);
    if (!parsed.success) {
      return res.status(400).json({ message: 'Validation failed', details: parsed.error.format() });
    }
    const { sourceIds, targetId } = parsed.data;

    // Validate all IDs are valid ObjectIds
    for (const id of [...sourceIds, targetId]) {
      if (!mongoose.Types.ObjectId.isValid(id)) {
        return res.status(400).json({ message: `Invalid id: ${id}` });
      }
    }

    const result = await mergeClients(managerObjectId, sourceIds, targetId);
    return res.json(result);
  } catch (err: any) {
    return res.status(500).json({ message: err.message || 'Failed to merge clients' });
  }
});

export default router;

