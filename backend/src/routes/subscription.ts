import { Router } from 'express';
import crypto from 'crypto';
import { z } from 'zod';
import { requireAuth } from '../middleware/requireAuth';
import { UserModel } from '../models/user';
import { ManagerModel } from '../models/manager';
import { TeamMemberModel } from '../models/teamMember';
import { EventModel } from '../models/event';

const router = Router();

/**
 * Helper function to determine which model to use based on JWT token
 * Returns { Model, isManager }
 */
function getUserModel(req: any): { Model: typeof UserModel | typeof ManagerModel; isManager: boolean } {
  const managerId = req.user?.managerId;
  return managerId
    ? { Model: ManagerModel, isManager: true }
    : { Model: UserModel, isManager: false };
}

/**
 * GET /api/subscription/status
 * Get current user's subscription status and details
 * Supports both staff users and managers
 */
router.get('/subscription/status', requireAuth, async (req, res) => {
  try {
    const provider = (req as any).user?.provider;
    const subject = (req as any).user?.sub;

    if (!provider || !subject) {
      return res.status(401).json({ message: 'Unauthorized' });
    }

    const { Model, isManager } = getUserModel(req);

    const user = await (Model as any).findOne({ provider, subject })
      .select('subscription_tier subscription_status subscription_platform subscription_started_at subscription_expires_at')
      .lean();

    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }

    return res.json({
      tier: user.subscription_tier || 'free',
      status: user.subscription_status || 'active',
      platform: user.subscription_platform || null,
      startedAt: user.subscription_started_at || null,
      expiresAt: user.subscription_expires_at || null,
      isActive: user.subscription_tier === 'pro' && user.subscription_status === 'active',
      userType: isManager ? 'manager' : 'staff', // Indicate which type of user
    });
  } catch (err: any) {
    console.error('[subscription/status] Error:', err);
    return res.status(500).json({ message: 'Failed to get subscription status' });
  }
});

/**
 * GET /api/subscription/usage
 * Get AI message usage statistics for current user
 */
router.get('/subscription/usage', requireAuth, async (req, res) => {
  try {
    const provider = (req as any).user?.provider;
    const subject = (req as any).user?.sub;

    if (!provider || !subject) {
      return res.status(401).json({ message: 'Unauthorized' });
    }

    const user = await UserModel.findOne({ provider, subject })
      .select('subscription_tier ai_messages_used_this_month ai_messages_reset_date')
      .lean();

    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }

    const isFree = user.subscription_tier === 'free';
    const FREE_TIER_LIMIT = 20; // Changed from 50 to 20 to reduce costs
    const limit = isFree ? FREE_TIER_LIMIT : null; // Pro has unlimited

    return res.json({
      used: user.ai_messages_used_this_month || 0,
      limit: limit,
      resetDate: user.ai_messages_reset_date,
      tier: user.subscription_tier || 'free',
      percentUsed: isFree ? Math.round(((user.ai_messages_used_this_month || 0) / FREE_TIER_LIMIT) * 100) : 0,
    });
  } catch (err: any) {
    console.error('[subscription/usage] Error:', err);
    return res.status(500).json({ message: 'Failed to get usage statistics' });
  }
});

/**
 * GET /api/subscription/manager/usage
 * Get manager-specific usage statistics (team size, event count, analytics access)
 * Used to enforce free tier limits: 25 team members, 10 events/month
 */
router.get('/subscription/manager/usage', requireAuth, async (req, res) => {
  try {
    const provider = (req as any).user?.provider;
    const subject = (req as any).user?.sub;
    const managerId = (req as any).user?.managerId || (req as any).user?._id;

    if (!provider || !subject || !managerId) {
      return res.status(401).json({ message: 'Unauthorized' });
    }

    const manager = await ManagerModel.findOne({ provider, subject })
      .select('subscription_tier')
      .lean();

    if (!manager) {
      return res.status(404).json({ message: 'Manager not found' });
    }

    const isFree = manager.subscription_tier === 'free' || !manager.subscription_tier;

    // Count team members
    const teamMemberCount = await TeamMemberModel.countDocuments({ managerId });

    // Count events created this month
    const now = new Date();
    const firstDayOfMonth = new Date(now.getFullYear(), now.getMonth(), 1);
    const eventsThisMonth = await EventModel.countDocuments({
      managerId,
      createdAt: { $gte: firstDayOfMonth }
    });

    // Free tier limits
    const FREE_TEAM_LIMIT = 25;
    const FREE_EVENT_LIMIT = 10; // events per month

    return res.json({
      teamMembers: {
        current: teamMemberCount,
        limit: isFree ? FREE_TEAM_LIMIT : null, // Pro has unlimited
        percentUsed: isFree ? Math.round((teamMemberCount / FREE_TEAM_LIMIT) * 100) : 0,
        canAddMore: isFree ? teamMemberCount < FREE_TEAM_LIMIT : true,
      },
      events: {
        thisMonth: eventsThisMonth,
        limit: isFree ? FREE_EVENT_LIMIT : null, // Pro has unlimited
        percentUsed: isFree ? Math.round((eventsThisMonth / FREE_EVENT_LIMIT) * 100) : 0,
        canCreateMore: isFree ? eventsThisMonth < FREE_EVENT_LIMIT : true,
      },
      analytics: {
        hasAccess: !isFree, // Analytics only for Pro users
      },
      tier: manager.subscription_tier || 'free',
      isPro: !isFree,
    });
  } catch (err: any) {
    console.error('[subscription/manager/usage] Error:', err);
    return res.status(500).json({ message: 'Failed to get manager usage statistics' });
  }
});

/**
 * POST /api/subscription/link-user
 * Link Qonversion user ID to backend user
 * Supports both staff users and managers
 */
const linkUserSchema = z.object({
  qonversionUserId: z.string().min(1),
});

router.post('/subscription/link-user', requireAuth, async (req, res) => {
  try {
    const provider = (req as any).user?.provider;
    const subject = (req as any).user?.sub;

    if (!provider || !subject) {
      return res.status(401).json({ message: 'Unauthorized' });
    }

    const validated = linkUserSchema.parse(req.body);
    const { Model, isManager } = getUserModel(req);

    const user = await (Model as any).findOneAndUpdate(
      { provider, subject },
      { qonversion_user_id: validated.qonversionUserId },
      { new: true }
    );

    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }

    console.log(`[subscription/link-user] Linked Qonversion user ${validated.qonversionUserId} to ${isManager ? 'manager' : 'staff'} ${provider}:${subject}`);

    return res.json({ success: true, qonversionUserId: validated.qonversionUserId });
  } catch (err: any) {
    console.error('[subscription/link-user] Error:', err);
    if (err instanceof z.ZodError) {
      return res.status(400).json({ message: 'Invalid request data', errors: err.issues });
    }
    return res.status(500).json({ message: 'Failed to link user' });
  }
});

/**
 * POST /api/subscription/sync
 * Manually sync subscription status from Qonversion
 * (In production, this would call Qonversion API to fetch latest status)
 * Supports both staff users and managers
 */
router.post('/subscription/sync', requireAuth, async (req, res) => {
  try {
    const provider = (req as any).user?.provider;
    const subject = (req as any).user?.sub;

    if (!provider || !subject) {
      return res.status(401).json({ message: 'Unauthorized' });
    }

    const { Model, isManager } = getUserModel(req);

    // TODO: In production, call Qonversion API to fetch subscription status
    // For now, just return current status
    const user = await (Model as any).findOne({ provider, subject })
      .select('subscription_tier subscription_status qonversion_user_id')
      .lean();

    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }

    console.log(`[subscription/sync] Sync requested for ${isManager ? 'manager' : 'staff'} ${provider}:${subject}`);

    return res.json({
      success: true,
      tier: user.subscription_tier || 'free',
      status: user.subscription_status || 'active',
    });
  } catch (err: any) {
    console.error('[subscription/sync] Error:', err);
    return res.status(500).json({ message: 'Failed to sync subscription' });
  }
});

/**
 * POST /api/subscription/webhook
 * Qonversion webhook endpoint for subscription events
 */
router.post('/subscription/webhook', async (req, res) => {
  try {
    // Verify webhook signature
    const signature = req.headers['x-qonversion-signature'] as string;
    const secret = process.env.QONVERSION_WEBHOOK_SECRET;

    if (!secret) {
      console.error('[subscription/webhook] QONVERSION_WEBHOOK_SECRET not configured');
      return res.status(500).json({ message: 'Webhook secret not configured' });
    }

    if (!verifyWebhookSignature(req.body, signature, secret)) {
      console.warn('[subscription/webhook] Invalid signature');
      return res.status(401).json({ message: 'Invalid signature' });
    }

    const event = req.body;

    console.log('[subscription/webhook] Event received:', event.type, 'for user:', event.uid);

    // Handle different event types
    switch (event.type) {
      case 'subscription_renewed':
      case 'subscription_started':
      case 'trial_started':
      case 'trial_converted':
        await handleSubscriptionActivation(event);
        break;

      case 'subscription_expired':
      case 'subscription_cancelled':
      case 'trial_expired':
      case 'trial_cancelled':
        await handleSubscriptionDeactivation(event);
        break;

      case 'subscription_refunded':
        await handleRefund(event);
        break;

      case 'subscription_product_changed':
        await handleProductChange(event);
        break;

      default:
        console.log('[subscription/webhook] Unhandled event type:', event.type);
    }

    return res.json({ received: true });
  } catch (err: any) {
    console.error('[subscription/webhook] Error:', err);
    return res.status(500).json({ message: 'Webhook processing failed' });
  }
});

/**
 * Verify Qonversion webhook signature using HMAC SHA256
 */
function verifyWebhookSignature(payload: any, signature: string, secret: string): boolean {
  try {
    if (!signature) {
      return false;
    }

    const hash = crypto
      .createHmac('sha256', secret)
      .update(JSON.stringify(payload))
      .digest('hex');

    return hash === signature;
  } catch (err) {
    console.error('[verifyWebhookSignature] Error:', err);
    return false;
  }
}

/**
 * Handle subscription activation (started, renewed, trial started/converted)
 * Tries both UserModel and ManagerModel
 */
async function handleSubscriptionActivation(event: any) {
  try {
    const qonversionUserId = event.uid;
    const expirationDate = event.expiration_date
      ? new Date(event.expiration_date * 1000)
      : null;

    const subscriptionStatus = event.type.includes('trial') ? 'trial' : 'active';
    const updateData = {
      subscription_tier: 'pro' as const,
      subscription_status: subscriptionStatus as 'trial' | 'active',
      subscription_started_at: new Date(),
      subscription_expires_at: expirationDate,
      subscription_platform: event.environment?.toLowerCase() || null,
    };

    // Try staff user first
    let updateResult = await UserModel.findOneAndUpdate(
      { qonversion_user_id: qonversionUserId },
      updateData,
      { new: true }
    );

    // If not found, try manager
    if (!updateResult) {
      updateResult = await ManagerModel.findOneAndUpdate(
        { qonversion_user_id: qonversionUserId },
        updateData,
        { new: true }
      );
    }

    if (updateResult) {
      console.log('[handleSubscriptionActivation] Activated pro subscription for Qonversion user:', qonversionUserId);
    } else {
      console.warn('[handleSubscriptionActivation] User not found for Qonversion ID:', qonversionUserId);
    }
  } catch (err) {
    console.error('[handleSubscriptionActivation] Error:', err);
    throw err;
  }
}

/**
 * Handle subscription deactivation (expired, cancelled)
 * Tries both UserModel and ManagerModel
 */
async function handleSubscriptionDeactivation(event: any) {
  try {
    const qonversionUserId = event.uid;

    const subscriptionStatus = event.type.includes('cancelled') ? 'cancelled' : 'expired';
    const updateData = {
      subscription_tier: 'free' as const,
      subscription_status: subscriptionStatus as 'cancelled' | 'expired',
      subscription_expires_at: new Date(),
    };

    // Try staff user first
    let updateResult = await UserModel.findOneAndUpdate(
      { qonversion_user_id: qonversionUserId },
      updateData,
      { new: true }
    );

    // If not found, try manager
    if (!updateResult) {
      updateResult = await ManagerModel.findOneAndUpdate(
        { qonversion_user_id: qonversionUserId },
        updateData,
        { new: true }
      );
    }

    if (updateResult) {
      console.log('[handleSubscriptionDeactivation] Deactivated subscription for Qonversion user:', qonversionUserId);
    } else {
      console.warn('[handleSubscriptionDeactivation] User not found for Qonversion ID:', qonversionUserId);
    }
  } catch (err) {
    console.error('[handleSubscriptionDeactivation] Error:', err);
    throw err;
  }
}

/**
 * Handle subscription refund
 * Tries both UserModel and ManagerModel
 */
async function handleRefund(event: any) {
  try {
    const qonversionUserId = event.uid;

    const updateData = {
      subscription_tier: 'free' as const,
      subscription_status: 'cancelled' as const,
      subscription_expires_at: new Date(),
    };

    // Try staff user first
    let updateResult = await UserModel.findOneAndUpdate(
      { qonversion_user_id: qonversionUserId },
      updateData,
      { new: true }
    );

    // If not found, try manager
    if (!updateResult) {
      updateResult = await ManagerModel.findOneAndUpdate(
        { qonversion_user_id: qonversionUserId },
        updateData,
        { new: true }
      );
    }

    if (updateResult) {
      console.log('[handleRefund] Processed refund for Qonversion user:', qonversionUserId);
    } else {
      console.warn('[handleRefund] User not found for Qonversion ID:', qonversionUserId);
    }
  } catch (err) {
    console.error('[handleRefund] Error:', err);
    throw err;
  }
}

/**
 * Handle subscription product change (upgrade/downgrade)
 * Tries both UserModel and ManagerModel
 */
async function handleProductChange(event: any) {
  try {
    const qonversionUserId = event.uid;
    const expirationDate = event.expiration_date
      ? new Date(event.expiration_date * 1000)
      : null;

    const updateData = {
      subscription_expires_at: expirationDate,
    };

    // Try staff user first
    let updateResult = await UserModel.findOneAndUpdate(
      { qonversion_user_id: qonversionUserId },
      updateData,
      { new: true }
    );

    // If not found, try manager
    if (!updateResult) {
      updateResult = await ManagerModel.findOneAndUpdate(
        { qonversion_user_id: qonversionUserId },
        updateData,
        { new: true }
      );
    }

    if (updateResult) {
      console.log('[handleProductChange] Updated subscription for Qonversion user:', qonversionUserId);
    } else {
      console.warn('[handleProductChange] User not found for Qonversion ID:', qonversionUserId);
    }
  } catch (err) {
    console.error('[handleProductChange] Error:', err);
    throw err;
  }
}

export default router;
