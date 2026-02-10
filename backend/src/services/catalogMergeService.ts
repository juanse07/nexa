import mongoose from 'mongoose';
import { ClientModel } from '../models/client';
import { RoleModel } from '../models/role';
import { TariffModel } from '../models/tariff';
import { EventModel } from '../models/event';

interface MergeResult {
  merged: number;
  eventsTransferred: number;
  tariffsTransferred: number;
}

/**
 * Merge multiple source clients into a single target client.
 * Transfers events and tariffs from sources to target, then deletes sources.
 */
export async function mergeClients(
  managerId: mongoose.Types.ObjectId,
  sourceIds: string[],
  targetId: string
): Promise<MergeResult> {
  const targetOid = new mongoose.Types.ObjectId(targetId);
  const targetClient = await ClientModel.findOne({ _id: targetOid, managerId }).lean();
  if (!targetClient) throw new Error('Target client not found');

  let totalEventsTransferred = 0;
  let totalTariffsTransferred = 0;

  for (const srcId of sourceIds) {
    const sourceOid = new mongoose.Types.ObjectId(srcId);
    if (sourceOid.equals(targetOid)) continue;

    const sourceClient = await ClientModel.findOne({ _id: sourceOid, managerId }).lean();
    if (!sourceClient) continue;

    // Transfer events from source to target (text-based client_name field)
    const eventsUpdated = await EventModel.updateMany(
      { managerId, client_name: new RegExp(`^${sourceClient.name}$`, 'i') },
      { $set: { client_name: targetClient.name } }
    );
    totalEventsTransferred += eventsUpdated.modifiedCount;

    // Transfer tariffs from source to target (skip if target already has one for that role)
    const sourceTariffs = await TariffModel.find({ managerId, clientId: sourceOid }).lean();
    for (const tariff of sourceTariffs) {
      const existing = await TariffModel.findOne({
        managerId,
        clientId: targetOid,
        roleId: tariff.roleId,
      }).lean();
      if (!existing) {
        await TariffModel.create({
          managerId,
          clientId: targetOid,
          roleId: tariff.roleId,
          rate: tariff.rate,
          currency: tariff.currency,
        });
        totalTariffsTransferred++;
      }
    }

    // Delete source client's tariffs and the client itself
    await TariffModel.deleteMany({ managerId, clientId: sourceOid });
    await ClientModel.deleteOne({ _id: sourceOid });
  }

  return {
    merged: sourceIds.filter((id) => id !== targetId).length,
    eventsTransferred: totalEventsTransferred,
    tariffsTransferred: totalTariffsTransferred,
  };
}

/**
 * Merge multiple source roles into a single target role.
 * Transfers events (array filter on roles) and tariffs, then deletes sources.
 */
export async function mergeRoles(
  managerId: mongoose.Types.ObjectId,
  sourceIds: string[],
  targetId: string
): Promise<MergeResult> {
  const targetOid = new mongoose.Types.ObjectId(targetId);
  const targetRole = await RoleModel.findOne({ _id: targetOid, managerId }).lean();
  if (!targetRole) throw new Error('Target role not found');

  let totalEventsTransferred = 0;
  let totalTariffsTransferred = 0;

  for (const srcId of sourceIds) {
    const sourceOid = new mongoose.Types.ObjectId(srcId);
    if (sourceOid.equals(targetOid)) continue;

    const sourceRole = await RoleModel.findOne({ _id: sourceOid, managerId }).lean();
    if (!sourceRole) continue;

    // Update events to use target role name instead of source (nested roles array)
    const eventsUpdated = await EventModel.updateMany(
      { managerId, 'roles.role': new RegExp(`^${sourceRole.name}$`, 'i') },
      { $set: { 'roles.$[elem].role': targetRole.name } },
      { arrayFilters: [{ 'elem.role': new RegExp(`^${sourceRole.name}$`, 'i') }] }
    );
    totalEventsTransferred += eventsUpdated.modifiedCount;

    // Transfer tariffs from source to target (skip if target already has one for that client)
    const sourceTariffs = await TariffModel.find({ managerId, roleId: sourceOid }).lean();
    for (const tariff of sourceTariffs) {
      const existing = await TariffModel.findOne({
        managerId,
        clientId: tariff.clientId,
        roleId: targetOid,
      }).lean();
      if (!existing) {
        await TariffModel.create({
          managerId,
          clientId: tariff.clientId,
          roleId: targetOid,
          rate: tariff.rate,
          currency: tariff.currency,
        });
        totalTariffsTransferred++;
      }
    }

    // Delete source role's tariffs and the role itself
    await TariffModel.deleteMany({ managerId, roleId: sourceOid });
    await RoleModel.deleteOne({ _id: sourceOid });
  }

  return {
    merged: sourceIds.filter((id) => id !== targetId).length,
    eventsTransferred: totalEventsTransferred,
    tariffsTransferred: totalTariffsTransferred,
  };
}

/**
 * Merge multiple source tariffs into a single target tariff.
 * Simple dedup: deletes source tariffs, keeps target.
 */
export async function mergeTariffs(
  managerId: mongoose.Types.ObjectId,
  sourceIds: string[],
  targetId: string
): Promise<MergeResult> {
  const targetOid = new mongoose.Types.ObjectId(targetId);
  const targetTariff = await TariffModel.findOne({ _id: targetOid, managerId }).lean();
  if (!targetTariff) throw new Error('Target tariff not found');

  let deleted = 0;
  for (const srcId of sourceIds) {
    const sourceOid = new mongoose.Types.ObjectId(srcId);
    if (sourceOid.equals(targetOid)) continue;

    const result = await TariffModel.deleteOne({ _id: sourceOid, managerId });
    if (result.deletedCount > 0) deleted++;
  }

  return {
    merged: deleted,
    eventsTransferred: 0,
    tariffsTransferred: 0,
  };
}
