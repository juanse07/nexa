import { ManagerDocument } from '../models/manager';
import { OrganizationModel, OrgSubscriptionStatus } from '../models/organization';

export interface EffectiveSubscription {
  tier: 'free' | 'pro';
  source: 'individual' | 'organization';
  orgId?: string;
}

const ACTIVE_ORG_STATUSES: OrgSubscriptionStatus[] = ['active', 'trialing'];

/**
 * Determine the effective subscription tier for a manager.
 * Organization subscription overrides individual subscription.
 *
 * Priority:
 *  1. If manager belongs to an org with active/trialing Stripe subscription → org tier
 *  2. Otherwise → individual tier from manager.subscription_tier (Qonversion IAP)
 */
export async function getEffectiveSubscriptionTier(
  manager: Pick<ManagerDocument, 'organizationId' | 'subscription_tier'>,
): Promise<EffectiveSubscription> {
  // Check org subscription first
  if (manager.organizationId) {
    const org = await OrganizationModel.findById(manager.organizationId)
      .select('subscriptionTier subscriptionStatus')
      .lean();

    if (org && ACTIVE_ORG_STATUSES.includes(org.subscriptionStatus)) {
      return {
        tier: org.subscriptionTier,
        source: 'organization',
        orgId: String(org._id),
      };
    }
  }

  // Fall through to individual tier
  return {
    tier: manager.subscription_tier || 'free',
    source: 'individual',
  };
}
