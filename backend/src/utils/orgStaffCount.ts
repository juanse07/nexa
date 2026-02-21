import { OrganizationModel } from '../models/organization';
import { TeamMemberModel } from '../models/teamMember';
import { updateSubscriptionItemQuantity } from '../services/stripeService';
import { ENV } from '../config/env';

/**
 * Count unique active staff across all teams in an organization.
 * Staff are deduplicated by (provider, subject) — the same person in
 * multiple teams counts as one seat.
 */
export async function countOrgUniqueStaff(orgId: string): Promise<number> {
  const org = await OrganizationModel.findById(orgId).select('members').lean();
  if (!org) return 0;

  const managerIds = org.members.map((m) => m.managerId);
  if (managerIds.length === 0) return 0;

  const result = await TeamMemberModel.aggregate([
    { $match: { managerId: { $in: managerIds }, status: { $ne: 'left' } } },
    { $group: { _id: { provider: '$provider', subject: '$subject' } } },
    { $count: 'total' },
  ]);

  return result[0]?.total || 0;
}

/**
 * Sync the org's Stripe staff seat quantity to match the current
 * unique staff count. Only applies to per_seat billing orgs.
 * Designed to be called fire-and-forget after staff membership changes.
 */
export async function syncStaffSeatsToStripe(orgId: string): Promise<void> {
  const org = await OrganizationModel.findById(orgId)
    .select('billingModel stripeSubscriptionId staffSeatsUsed')
    .lean();

  if (!org || org.billingModel !== 'per_seat' || !org.stripeSubscriptionId) return;
  if (!ENV.stripePriceIdPerSeat) return;

  const currentCount = await countOrgUniqueStaff(orgId);
  if (currentCount === org.staffSeatsUsed) return; // no change

  await updateSubscriptionItemQuantity(
    org.stripeSubscriptionId,
    ENV.stripePriceIdPerSeat,
    Math.max(currentCount, 1),
  );

  await OrganizationModel.findByIdAndUpdate(orgId, { staffSeatsUsed: currentCount });
  console.log(`[seat-sync] Org ${orgId} staff: ${org.staffSeatsUsed} → ${currentCount} seats`);
}

/**
 * Sync the org's Stripe manager seat quantity to match the current
 * member count. Only applies to per_seat billing orgs.
 * Designed to be called fire-and-forget after org member changes.
 */
export async function syncManagerSeatsToStripe(orgId: string): Promise<void> {
  const org = await OrganizationModel.findById(orgId)
    .select('billingModel stripeSubscriptionId members')
    .lean();

  if (!org || org.billingModel !== 'per_seat' || !org.stripeSubscriptionId) return;
  if (!ENV.stripePriceIdPro) return;

  const managerCount = org.members.length;

  await updateSubscriptionItemQuantity(
    org.stripeSubscriptionId,
    ENV.stripePriceIdPro,
    Math.max(managerCount, 1),
  );

  console.log(`[seat-sync] Org ${orgId} managers: ${managerCount} seats`);
}
