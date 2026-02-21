import { Router, Request, Response } from 'express';
import crypto from 'crypto';
import { z } from 'zod';
import { requireAuth } from '../middleware/requireAuth';
import { requireOrgMembership } from '../middleware/requireOrgMembership';
import { OrganizationModel, OrganizationDocument, OrgStaffPolicy } from '../models/organization';
import { ManagerModel } from '../models/manager';
import { UserModel } from '../models/user';
import { ENV } from '../config/env';
import {
  createCustomer,
  createCheckoutSession,
  createPortalSession,
  constructWebhookEvent,
} from '../services/stripeService';

const router = Router();

// ─── Helpers ───────────────────────────────────────────────────────

function slugify(name: string): string {
  return name
    .toLowerCase()
    .trim()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-|-$/g, '');
}

function generateInviteToken(): string {
  return crypto.randomBytes(32).toString('hex');
}

// ─── Validation Schemas ────────────────────────────────────────────

const createOrgSchema = z.object({
  name: z.string().min(2).max(100).trim(),
});

const updateOrgSchema = z.object({
  name: z.string().min(2).max(100).trim().optional(),
});

const inviteMemberSchema = z.object({
  email: z.string().email().trim().toLowerCase(),
  role: z.enum(['admin', 'member']).default('member'),
});

const checkoutSchema = z.object({
  successUrl: z.string().url(),
  cancelUrl: z.string().url(),
});

const addStaffSchema = z.object({
  provider: z.string().min(1).trim(),
  subject: z.string().min(1).trim(),
  name: z.string().trim().optional(),
  email: z.string().email().trim().optional(),
});

const updatePolicySchema = z.object({
  staffPolicy: z.enum(['open', 'restricted']),
});

// ─── POST /organizations — Create org, become owner ───────────────

router.post('/organizations', requireAuth, async (req: Request, res: Response) => {
  try {
    const managerId = (req as any).user?.managerId;
    if (!managerId) {
      return res.status(403).json({ message: 'Manager access required' });
    }

    // Check if manager already belongs to an org
    const existingManager = await ManagerModel.findById(managerId).lean();
    if (!existingManager) {
      return res.status(404).json({ message: 'Manager not found' });
    }
    if (existingManager.organizationId) {
      return res.status(409).json({ message: 'You already belong to an organization' });
    }

    const validated = createOrgSchema.parse(req.body);

    // Generate unique slug
    let slug = slugify(validated.name);
    const existing = await OrganizationModel.findOne({ slug }).lean();
    if (existing) {
      slug = `${slug}-${crypto.randomBytes(3).toString('hex')}`;
    }

    // Create Stripe customer
    let stripeCustomerId: string | undefined;
    if (ENV.stripeSecretKey) {
      const customer = await createCustomer(
        validated.name,
        existingManager.email || '',
        managerId,
      );
      stripeCustomerId = customer.id;
    }

    // Create org
    const org = await OrganizationModel.create({
      name: validated.name,
      slug,
      stripeCustomerId,
      members: [{
        managerId,
        role: 'owner',
        joinedAt: new Date(),
      }],
    });

    // Update manager with org reference
    await ManagerModel.findByIdAndUpdate(managerId, {
      organizationId: org._id,
      orgRole: 'owner',
    });

    console.log(`[organizations] Created org "${validated.name}" (${org._id}) by manager ${managerId}`);

    return res.status(201).json({
      id: org._id,
      name: org.name,
      slug: org.slug,
      stripeCustomerId: org.stripeCustomerId,
      subscriptionStatus: org.subscriptionStatus,
      subscriptionTier: org.subscriptionTier,
      members: org.members,
    });
  } catch (err: any) {
    if (err instanceof z.ZodError) {
      return res.status(400).json({ message: 'Invalid data', errors: err.issues });
    }
    console.error('[organizations] Create error:', err);
    return res.status(500).json({ message: 'Failed to create organization' });
  }
});

// ─── GET /organizations/mine — Get current manager's org ──────────

router.get('/organizations/mine', requireAuth, async (req: Request, res: Response) => {
  try {
    const managerId = (req as any).user?.managerId;
    if (!managerId) {
      return res.status(403).json({ message: 'Manager access required' });
    }

    const manager = await ManagerModel.findById(managerId).select('organizationId').lean();
    if (!manager?.organizationId) {
      return res.json({ organization: null });
    }

    const org = await OrganizationModel.findById(manager.organizationId).lean();
    if (!org) {
      return res.json({ organization: null });
    }

    // Populate member details
    const memberIds = org.members.map((m) => m.managerId);
    const managers = await ManagerModel.find({ _id: { $in: memberIds } })
      .select('_id email name first_name last_name picture')
      .lean();

    const managerMap = new Map(managers.map((m) => [String(m._id), m]));

    const membersWithDetails = org.members.map((m) => ({
      managerId: String(m.managerId),
      role: m.role,
      joinedAt: m.joinedAt,
      ...managerMap.get(String(m.managerId)),
    }));

    return res.json({
      organization: {
        id: org._id,
        name: org.name,
        slug: org.slug,
        subscriptionStatus: org.subscriptionStatus,
        subscriptionTier: org.subscriptionTier,
        currentPeriodEnd: org.currentPeriodEnd,
        cancelAtPeriodEnd: org.cancelAtPeriodEnd,
        managerSeatsIncluded: org.managerSeatsIncluded,
        staffSeatsIncluded: org.staffSeatsIncluded,
        staffPolicy: org.staffPolicy || 'open',
        approvedStaffCount: (org.approvedStaff || []).length,
        members: membersWithDetails,
        pendingInvites: org.pendingInvites.map((inv) => ({
          email: inv.email,
          role: inv.role,
          expiresAt: inv.expiresAt,
        })),
        createdAt: org.createdAt,
      },
    });
  } catch (err) {
    console.error('[organizations] Get mine error:', err);
    return res.status(500).json({ message: 'Failed to get organization' });
  }
});

// ─── GET /organizations/:id — Get org details ─────────────────────

router.get(
  '/organizations/:id',
  requireAuth,
  requireOrgMembership(),
  async (req: Request, res: Response) => {
    const org = (req as any).org as OrganizationDocument;
    return res.json({ organization: org });
  },
);

// ─── PATCH /organizations/:id — Update org ────────────────────────

router.patch(
  '/organizations/:id',
  requireAuth,
  requireOrgMembership('admin'),
  async (req: Request, res: Response) => {
    try {
      const validated = updateOrgSchema.parse(req.body);
      const update: Record<string, any> = {};

      if (validated.name) {
        update.name = validated.name;
      }

      const org = await OrganizationModel.findByIdAndUpdate(
        req.params.id,
        { $set: update },
        { new: true },
      );

      return res.json({ organization: org });
    } catch (err: any) {
      if (err instanceof z.ZodError) {
        return res.status(400).json({ message: 'Invalid data', errors: err.issues });
      }
      console.error('[organizations] Update error:', err);
      return res.status(500).json({ message: 'Failed to update organization' });
    }
  },
);

// ─── POST /organizations/:id/members — Invite manager by email ───

router.post(
  '/organizations/:id/members',
  requireAuth,
  requireOrgMembership('admin'),
  async (req: Request, res: Response) => {
    try {
      const validated = inviteMemberSchema.parse(req.body);
      const managerId = (req as any).user?.managerId;
      const org = (req as any).org as OrganizationDocument;

      // Check seat limit
      if (org.managerSeatsIncluded > 0 && org.members.length >= org.managerSeatsIncluded) {
        return res.status(403).json({
          message: `Organization has reached its seat limit (${org.managerSeatsIncluded})`,
        });
      }

      // Check if email is already a member
      const existingManager = await ManagerModel.findOne({ email: validated.email }).lean();
      if (existingManager) {
        const alreadyMember = org.members.some(
          (m) => String(m.managerId) === String(existingManager._id),
        );
        if (alreadyMember) {
          return res.status(409).json({ message: 'This manager is already a member' });
        }
      }

      // Check if there's already a pending invite for this email
      const hasPendingInvite = org.pendingInvites.some(
        (inv) => inv.email === validated.email && inv.expiresAt > new Date(),
      );
      if (hasPendingInvite) {
        return res.status(409).json({ message: 'An invite is already pending for this email' });
      }

      const token = generateInviteToken();
      const expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000); // 7 days

      await OrganizationModel.findByIdAndUpdate(org._id, {
        $push: {
          pendingInvites: {
            email: validated.email,
            role: validated.role,
            token,
            expiresAt,
            invitedBy: managerId,
          },
        },
      });

      console.log(`[organizations] Invite sent to ${validated.email} for org ${org._id}`);

      return res.status(201).json({
        message: 'Invite created',
        invite: {
          email: validated.email,
          role: validated.role,
          token,
          expiresAt,
        },
      });
    } catch (err: any) {
      if (err instanceof z.ZodError) {
        return res.status(400).json({ message: 'Invalid data', errors: err.issues });
      }
      console.error('[organizations] Invite error:', err);
      return res.status(500).json({ message: 'Failed to create invite' });
    }
  },
);

// ─── DELETE /organizations/:id/members/:managerId — Remove member ─

router.delete(
  '/organizations/:id/members/:managerId',
  requireAuth,
  requireOrgMembership('admin'),
  async (req: Request, res: Response) => {
    try {
      const targetManagerId = req.params.managerId;
      const org = (req as any).org as OrganizationDocument;
      const requestingMember = (req as any).orgMember;

      // Cannot remove the owner
      const targetMember = org.members.find(
        (m) => String(m.managerId) === targetManagerId,
      );
      if (!targetMember) {
        return res.status(404).json({ message: 'Member not found in organization' });
      }
      if (targetMember.role === 'owner' && requestingMember.role !== 'owner') {
        return res.status(403).json({ message: 'Cannot remove the organization owner' });
      }

      // Remove from org
      await OrganizationModel.findByIdAndUpdate(org._id, {
        $pull: { members: { managerId: targetManagerId } },
      });

      // Clear org reference on manager
      await ManagerModel.findByIdAndUpdate(targetManagerId, {
        $unset: { organizationId: 1, orgRole: 1 },
      });

      console.log(`[organizations] Removed manager ${targetManagerId} from org ${org._id}`);

      return res.json({ message: 'Member removed' });
    } catch (err) {
      console.error('[organizations] Remove member error:', err);
      return res.status(500).json({ message: 'Failed to remove member' });
    }
  },
);

// ─── POST /organizations/join/:token — Accept invite ──────────────

router.post('/organizations/join/:token', requireAuth, async (req: Request, res: Response) => {
  try {
    const managerId = (req as any).user?.managerId;
    if (!managerId) {
      return res.status(403).json({ message: 'Manager access required' });
    }

    // Check if manager already belongs to an org
    const manager = await ManagerModel.findById(managerId).lean();
    if (manager?.organizationId) {
      return res.status(409).json({ message: 'You already belong to an organization' });
    }

    const token = req.params.token;

    // Find org with this invite token
    const org = await OrganizationModel.findOne({
      'pendingInvites.token': token,
      'pendingInvites.expiresAt': { $gt: new Date() },
    });

    if (!org) {
      return res.status(404).json({ message: 'Invalid or expired invite' });
    }

    const invite = org.pendingInvites.find((inv) => inv.token === token);
    if (!invite) {
      return res.status(404).json({ message: 'Invite not found' });
    }

    // Check seat limit
    if (org.managerSeatsIncluded > 0 && org.members.length >= org.managerSeatsIncluded) {
      return res.status(403).json({ message: 'Organization has reached its seat limit' });
    }

    // Add member and remove invite
    await OrganizationModel.findByIdAndUpdate(org._id, {
      $push: {
        members: {
          managerId,
          role: invite.role,
          joinedAt: new Date(),
        },
      },
      $pull: { pendingInvites: { token } },
    });

    // Update manager
    await ManagerModel.findByIdAndUpdate(managerId, {
      organizationId: org._id,
      orgRole: invite.role,
    });

    console.log(`[organizations] Manager ${managerId} joined org ${org._id} via invite`);

    return res.json({
      message: 'Successfully joined organization',
      organizationId: org._id,
      organizationName: org.name,
      role: invite.role,
    });
  } catch (err) {
    console.error('[organizations] Join error:', err);
    return res.status(500).json({ message: 'Failed to join organization' });
  }
});

// ─── POST /organizations/:id/transfer — Transfer ownership ────────

const transferOwnershipSchema = z.object({
  newOwnerId: z.string().min(1),
});

router.post(
  '/organizations/:id/transfer',
  requireAuth,
  requireOrgMembership('owner'),
  async (req: Request, res: Response) => {
    try {
      const validated = transferOwnershipSchema.parse(req.body);
      const requestingMember = (req as any).orgMember;
      const org = (req as any).org as OrganizationDocument;
      const currentOwnerId = String(requestingMember.managerId);

      // Cannot transfer to self
      if (validated.newOwnerId === currentOwnerId) {
        return res.status(400).json({ message: 'Cannot transfer ownership to yourself' });
      }

      // Validate new owner is a current member
      const targetMember = org.members.find(
        (m) => String(m.managerId) === validated.newOwnerId,
      );
      if (!targetMember) {
        return res.status(404).json({ message: 'Target manager is not a member of this organization' });
      }

      // Atomic update: swap roles in the members array
      await OrganizationModel.bulkWrite([
        {
          updateOne: {
            filter: { _id: org._id, 'members.managerId': currentOwnerId },
            update: { $set: { 'members.$.role': 'admin' } },
          },
        },
        {
          updateOne: {
            filter: { _id: org._id, 'members.managerId': validated.newOwnerId },
            update: { $set: { 'members.$.role': 'owner' } },
          },
        },
      ]);

      // Update both managers' orgRole field
      await Promise.all([
        ManagerModel.findByIdAndUpdate(currentOwnerId, { orgRole: 'admin' }),
        ManagerModel.findByIdAndUpdate(validated.newOwnerId, { orgRole: 'owner' }),
      ]);

      const updatedOrg = await OrganizationModel.findById(org._id).lean();

      console.log(
        `[organizations] Ownership transferred from ${currentOwnerId} to ${validated.newOwnerId} in org ${org._id}`,
      );

      return res.json({ organization: updatedOrg });
    } catch (err: any) {
      if (err instanceof z.ZodError) {
        return res.status(400).json({ message: 'Invalid data', errors: err.issues });
      }
      console.error('[organizations] Transfer ownership error:', err);
      return res.status(500).json({ message: 'Failed to transfer ownership' });
    }
  },
);

// ─── Staff Pool Management ────────────────────────────────────────

// GET /organizations/:id/staff — List approved staff pool
router.get(
  '/organizations/:id/staff',
  requireAuth,
  requireOrgMembership(),
  async (req: Request, res: Response) => {
    try {
      const org = (req as any).org as OrganizationDocument;
      const approvedStaff = org.approvedStaff || [];

      // Enrich with user profile data where available
      const enriched = await Promise.all(
        approvedStaff.map(async (entry) => {
          const user = await UserModel.findOne({
            provider: entry.provider,
            subject: entry.subject,
          })
            .select('name email picture phone')
            .lean();

          return {
            provider: entry.provider,
            subject: entry.subject,
            name: entry.name || user?.name,
            email: entry.email || user?.email,
            picture: user?.picture,
            addedAt: entry.addedAt,
          };
        }),
      );

      return res.json({ staff: enriched });
    } catch (err) {
      console.error('[organizations] Get staff pool error:', err);
      return res.status(500).json({ message: 'Failed to get staff pool' });
    }
  },
);

// POST /organizations/:id/staff — Add staff to approved pool
router.post(
  '/organizations/:id/staff',
  requireAuth,
  requireOrgMembership('admin'),
  async (req: Request, res: Response) => {
    try {
      const validated = addStaffSchema.parse(req.body);
      const managerId = (req as any).user?.managerId;
      const org = (req as any).org as OrganizationDocument;

      // Check for duplicate
      const alreadyExists = (org.approvedStaff || []).some(
        (s) => s.provider === validated.provider && s.subject === validated.subject,
      );
      if (alreadyExists) {
        return res.status(409).json({ message: 'Staff member already in approved pool' });
      }

      const entry = {
        provider: validated.provider,
        subject: validated.subject,
        name: validated.name,
        email: validated.email,
        addedBy: managerId,
        addedAt: new Date(),
      };

      await OrganizationModel.findByIdAndUpdate(org._id, {
        $push: { approvedStaff: entry },
      });

      console.log(`[organizations] Added staff ${validated.provider}:${validated.subject} to org ${org._id}`);

      return res.status(201).json({ entry });
    } catch (err: any) {
      if (err instanceof z.ZodError) {
        return res.status(400).json({ message: 'Invalid data', errors: err.issues });
      }
      console.error('[organizations] Add staff error:', err);
      return res.status(500).json({ message: 'Failed to add staff to pool' });
    }
  },
);

// DELETE /organizations/:id/staff/:provider/:subject — Remove staff from pool
router.delete(
  '/organizations/:id/staff/:provider/:subject',
  requireAuth,
  requireOrgMembership('admin'),
  async (req: Request, res: Response) => {
    try {
      const org = (req as any).org as OrganizationDocument;
      const { provider, subject } = req.params;

      const result = await OrganizationModel.findByIdAndUpdate(
        org._id,
        {
          $pull: {
            approvedStaff: { provider, subject },
          },
        },
        { new: true },
      );

      if (!result) {
        return res.status(404).json({ message: 'Organization not found' });
      }

      console.log(`[organizations] Removed staff ${provider}:${subject} from org ${org._id}`);

      return res.json({ message: 'Staff removed from approved pool' });
    } catch (err) {
      console.error('[organizations] Remove staff error:', err);
      return res.status(500).json({ message: 'Failed to remove staff from pool' });
    }
  },
);

// PATCH /organizations/:id/policy — Update staff policy
router.patch(
  '/organizations/:id/policy',
  requireAuth,
  requireOrgMembership('admin'),
  async (req: Request, res: Response) => {
    try {
      const validated = updatePolicySchema.parse(req.body);
      const org = (req as any).org as OrganizationDocument;

      await OrganizationModel.findByIdAndUpdate(org._id, {
        $set: { staffPolicy: validated.staffPolicy },
      });

      console.log(`[organizations] Updated staff policy to '${validated.staffPolicy}' for org ${org._id}`);

      return res.json({ staffPolicy: validated.staffPolicy });
    } catch (err: any) {
      if (err instanceof z.ZodError) {
        return res.status(400).json({ message: 'Invalid data', errors: err.issues });
      }
      console.error('[organizations] Update policy error:', err);
      return res.status(500).json({ message: 'Failed to update staff policy' });
    }
  },
);

// ─── POST /organizations/:id/checkout — Create Stripe Checkout ────

router.post(
  '/organizations/:id/checkout',
  requireAuth,
  requireOrgMembership('admin'),
  async (req: Request, res: Response) => {
    try {
      const org = (req as any).org as OrganizationDocument;
      const validated = checkoutSchema.parse(req.body);

      if (!ENV.stripePriceIdPro) {
        return res.status(500).json({ message: 'Stripe price not configured' });
      }

      // Lazily create Stripe customer for orgs created before Stripe was configured
      let customerId = org.stripeCustomerId;
      if (!customerId) {
        const managerId = (req as any).user?.managerId;
        const manager = await ManagerModel.findById(managerId).select('email').lean();
        const customer = await createCustomer(
          org.name,
          manager?.email || '',
          managerId || '',
        );
        customerId = customer.id;
        await OrganizationModel.findByIdAndUpdate(org._id, { stripeCustomerId: customerId });
        console.log(`[organizations] Lazily created Stripe customer ${customerId} for org ${org._id}`);
      }

      const session = await createCheckoutSession(
        customerId,
        ENV.stripePriceIdPro,
        String(org._id),
        validated.successUrl,
        validated.cancelUrl,
      );

      return res.json({ url: session.url });
    } catch (err) {
      console.error('[organizations] Checkout error:', err);
      return res.status(500).json({ message: 'Failed to create checkout session' });
    }
  },
);

// ─── POST /organizations/:id/portal — Create Stripe Portal ───────

router.post(
  '/organizations/:id/portal',
  requireAuth,
  requireOrgMembership(),
  async (req: Request, res: Response) => {
    try {
      const org = (req as any).org as OrganizationDocument;

      if (!org.stripeCustomerId) {
        return res.status(400).json({ message: 'Organization has no Stripe customer' });
      }

      const returnUrl = req.body?.returnUrl || ENV.stripePortalReturnUrl;

      const session = await createPortalSession(org.stripeCustomerId, returnUrl);

      return res.json({ url: session.url });
    } catch (err) {
      console.error('[organizations] Portal error:', err);
      return res.status(500).json({ message: 'Failed to create portal session' });
    }
  },
);

// ─── Stripe Webhook Handler ────────────────────────────────────────
// CRITICAL: This must receive raw body (not JSON-parsed).
// It is registered separately in index.ts with express.raw().

export async function stripeWebhookHandler(req: Request, res: Response) {
  try {
    const sig = req.headers['stripe-signature'] as string;
    if (!sig) {
      return res.status(400).json({ message: 'Missing stripe-signature header' });
    }

    const event = constructWebhookEvent(req.body as Buffer, sig);

    console.log(`[stripe-webhook] Received event: ${event.type}`);

    switch (event.type) {
      case 'checkout.session.completed': {
        const session = event.data.object as any;
        const orgId = session.metadata?.orgId;
        if (orgId) {
          const subscriptionId = session.subscription as string;
          await OrganizationModel.findByIdAndUpdate(orgId, {
            stripeSubscriptionId: subscriptionId,
            subscriptionStatus: 'active',
            subscriptionTier: 'pro',
          });

          // Update all org members' subscription
          await syncOrgMemberTiers(orgId, 'pro');
          console.log(`[stripe-webhook] Activated subscription for org ${orgId}`);
        }
        break;
      }

      case 'customer.subscription.updated': {
        const subscription = event.data.object as any;
        const orgId = subscription.metadata?.orgId;
        if (orgId) {
          const status = subscription.status; // active, past_due, canceled, etc.
          const tier = (status === 'active' || status === 'trialing') ? 'pro' : 'free';

          await OrganizationModel.findByIdAndUpdate(orgId, {
            subscriptionStatus: status,
            subscriptionTier: tier,
            currentPeriodEnd: subscription.current_period_end
              ? new Date(subscription.current_period_end * 1000)
              : undefined,
            cancelAtPeriodEnd: subscription.cancel_at_period_end || false,
          });

          await syncOrgMemberTiers(orgId, tier);
          console.log(`[stripe-webhook] Updated subscription for org ${orgId}: ${status}`);
        }
        break;
      }

      case 'customer.subscription.deleted': {
        const subscription = event.data.object as any;
        const orgId = subscription.metadata?.orgId;
        if (orgId) {
          await OrganizationModel.findByIdAndUpdate(orgId, {
            subscriptionStatus: 'canceled',
            subscriptionTier: 'free',
            cancelAtPeriodEnd: false,
          });

          await syncOrgMemberTiers(orgId, 'free');
          console.log(`[stripe-webhook] Canceled subscription for org ${orgId}`);
        }
        break;
      }

      default:
        console.log(`[stripe-webhook] Unhandled event type: ${event.type}`);
    }

    return res.json({ received: true });
  } catch (err: any) {
    console.error('[stripe-webhook] Error:', err.message);
    return res.status(400).json({ message: `Webhook error: ${err.message}` });
  }
}

/**
 * Sync all managers in an org to the org's subscription tier.
 * This is a denormalization for fast reads — the org tier is authoritative.
 */
async function syncOrgMemberTiers(orgId: string, tier: 'free' | 'pro') {
  const org = await OrganizationModel.findById(orgId).select('members').lean();
  if (!org) return;

  const managerIds = org.members.map((m) => m.managerId);

  if (tier === 'pro') {
    await ManagerModel.updateMany(
      { _id: { $in: managerIds } },
      { subscription_tier: 'pro', subscription_status: 'active' },
    );
  }
  // When downgrading, only reset managers who don't have their own individual subscription
  // The getEffectiveSubscriptionTier function handles the priority, so we don't
  // need to touch individual subscription fields — the org tier just stops overriding
}

export default router;
