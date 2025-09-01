import { Router } from 'express';
import mongoose from 'mongoose';
import { z } from 'zod';
import { ClientModel } from '../models/client';
import { RoleModel } from '../models/role';
import { TariffModel } from '../models/tariff';

const router = Router();

const upsertSchema = z.object({
  clientId: z.string().min(1),
  roleId: z.string().min(1),
  rate: z.number().min(0),
  currency: z.string().min(1).default('USD'),
});

// List tariffs, optionally filtered by clientId or roleId
router.get('/tariffs', async (req, res) => {
  try {
    const clientId = (req.query.clientId as string | undefined) || undefined;
    const roleId = (req.query.roleId as string | undefined) || undefined;
    const filter: any = {};
    if (clientId && mongoose.Types.ObjectId.isValid(clientId)) filter.clientId = new mongoose.Types.ObjectId(clientId);
    if (roleId && mongoose.Types.ObjectId.isValid(roleId)) filter.roleId = new mongoose.Types.ObjectId(roleId);
    const docs = await TariffModel.find(filter).lean();
    const mapped = (docs || []).map((d: any) => ({
      id: String(d._id),
      clientId: String(d.clientId),
      roleId: String(d.roleId),
      rate: d.rate,
      currency: d.currency,
    }));
    return res.json(mapped);
  } catch (err) {
    return res.status(500).json({ message: 'Failed to fetch tariffs' });
  }
});

// Create or update a tariff for (clientId, roleId)
router.post('/tariffs', async (req, res) => {
  try {
    const parsed = upsertSchema.safeParse(req.body);
    if (!parsed.success) return res.status(400).json({ message: 'Validation failed', details: parsed.error.format() });
    const { clientId, roleId, rate, currency } = parsed.data;
    if (!mongoose.Types.ObjectId.isValid(clientId) || !mongoose.Types.ObjectId.isValid(roleId)) {
      return res.status(400).json({ message: 'Invalid clientId or roleId' });
    }
    // Validate refs existence (best-effort)
    const [client, role] = await Promise.all([
      ClientModel.findById(clientId).lean(),
      RoleModel.findById(roleId).lean(),
    ]);
    if (!client) return res.status(404).json({ message: 'Client not found' });
    if (!role) return res.status(404).json({ message: 'Role not found' });

    const result = await TariffModel.updateOne(
      { clientId: new mongoose.Types.ObjectId(clientId), roleId: new mongoose.Types.ObjectId(roleId) },
      { $set: { rate, currency, updatedAt: new Date() }, $setOnInsert: { createdAt: new Date() } },
      { upsert: true }
    );
    if (result.upsertedId) {
      const created = await TariffModel.findOne({ clientId, roleId }).lean();
      return res.status(201).json({ id: created ? String(created._id) : undefined, clientId, roleId, rate, currency });
    }
    const updated = await TariffModel.findOne({ clientId, roleId }).lean();
    return res.json({ id: updated ? String(updated._id) : undefined, clientId, roleId, rate, currency });
  } catch (err) {
    return res.status(500).json({ message: 'Failed to upsert tariff' });
  }
});

// Delete a tariff by id
router.delete('/tariffs/:id', async (req, res) => {
  try {
    const id = req.params.id ?? '';
    if (!mongoose.Types.ObjectId.isValid(id)) return res.status(400).json({ message: 'Invalid tariff id' });
    const result = await TariffModel.deleteOne({ _id: new mongoose.Types.ObjectId(id) });
    if (result.deletedCount === 0) return res.status(404).json({ message: 'Tariff not found' });
    return res.json({ message: 'Tariff deleted' });
  } catch (err) {
    return res.status(500).json({ message: 'Failed to delete tariff' });
  }
});

export default router;


