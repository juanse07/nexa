import { Router } from 'express';
import mongoose from 'mongoose';
import { z } from 'zod';
import { requireAuth } from '../middleware/requireAuth';
import { UserModel } from '../models/user';
import { TeamMemberModel } from '../models/teamMember';
import {
  requireManagerAuth,
  getCachedManagerId,
  canAccessUser,
  type AuthenticatedRequest
} from '../middleware/requireTeamMemberAccess';

const router = Router();

const querySchema = z.object({
  q: z.string().optional(),
  cursor: z.string().optional(), // base64 of ObjectId string
  limit: z.coerce.number().min(1).max(100).default(20),
});

const updateSchema = z.object({
  firstName: z.string().trim().min(1).max(100).optional(),
  lastName: z.string().trim().min(1).max(100).optional(),
  phoneNumber: z
    .string()
    .regex(
      /^(\d{3}-\d{3}-\d{4}|\d{10})$/,
      'Phone number must be in US format: XXX-XXX-XXXX or XXXXXXXXXX'
    )
    .optional(),
  appId: z
    .string()
    .regex(/^\d{9}$/)
    .optional(),
  picture: z.string().url().max(2048).optional(),
  isCaricature: z.boolean().optional(), // When true, saves current picture as originalPicture
  eventTerminology: z.enum(['shift', 'job', 'event']).optional(),
});

router.get('/users/me', requireAuth, async (req, res) => {
  try {
    const authUser = (req as any).authUser;
    if (!authUser?.provider || !authUser?.sub) {
      return res.status(401).json({ message: 'Unauthorized' });
    }

    // Block manager-authenticated requests (managers use /managers/me)
    if (authUser.managerId) {
      return res.status(403).json({
        message: 'Manager authentication not allowed',
        details: 'Managers should use /managers/me endpoint for their profile'
      });
    }

    const user = await UserModel.findOne({
      provider: authUser.provider,
      subject: authUser.sub,
    }).lean();

    if (!user) return res.status(404).json({ message: 'User not found' });
    return res.json({
      id: String(user._id),
      email: user.email,
      name: user.name,
      firstName: user.first_name,
      lastName: user.last_name,
      phoneNumber: user.phone_number,
      picture: user.picture,
      originalPicture: user.originalPicture || null,
      caricatureHistory: user.caricatureHistory || [],
      appId: user.app_id,
      eventTerminology: user.eventTerminology || 'shift',
    });
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error('[users] GET /me failed', err);
    return res.status(500).json({ message: 'Failed to fetch user profile', error: (err as Error).message });
  }
});

router.patch('/users/me', requireAuth, async (req, res) => {
  try {
    const authUser = (req as any).authUser;
    if (!authUser?.provider || !authUser?.sub) {
      return res.status(401).json({ message: 'Unauthorized' });
    }

    // eslint-disable-next-line no-console
    console.log('[users] PATCH /me - Request body:', JSON.stringify(req.body));

    const parsed = updateSchema.safeParse(req.body || {});
    if (!parsed.success) {
      // eslint-disable-next-line no-console
      console.error('[users] PATCH /me - Validation failed:', parsed.error.issues);
      return res.status(400).json({ message: 'Validation failed', details: parsed.error.issues });
    }

    // eslint-disable-next-line no-console
    console.log('[users] PATCH /me - Parsed data:', JSON.stringify(parsed.data));

    // If appId provided, ensure not used by another user
    if (parsed.data.appId) {
      const conflict = await UserModel.findOne({
        app_id: parsed.data.appId,
        $or: [
          { provider: { $ne: authUser.provider } },
          { subject: { $ne: authUser.sub } },
        ],
      }).lean();
      if (conflict) {
        return res.status(409).json({ message: 'This App ID is already in use' });
      }
    }

    // Map camelCase to snake_case for database
    const { isCaricature, ...restData } = parsed.data;
    const dbUpdate: any = { updatedAt: new Date() };
    if (restData.firstName !== undefined) dbUpdate.first_name = restData.firstName;
    if (restData.lastName !== undefined) dbUpdate.last_name = restData.lastName;
    if (restData.phoneNumber !== undefined) dbUpdate.phone_number = restData.phoneNumber;
    if (restData.appId !== undefined) dbUpdate.app_id = restData.appId;
    if (restData.picture !== undefined) dbUpdate.picture = restData.picture;
    if (restData.eventTerminology !== undefined) dbUpdate.eventTerminology = restData.eventTerminology;

    // If this is a caricature update, save the current picture as originalPicture
    if (isCaricature && restData.picture) {
      const current = await UserModel.findOne({
        provider: authUser.provider,
        subject: authUser.sub,
      }).lean();
      if (current?.picture) {
        dbUpdate.originalPicture = current.picture;
      }
    }

    // eslint-disable-next-line no-console
    console.log('[users] PATCH /me - DB update object:', JSON.stringify(dbUpdate));

    const updated = await UserModel.findOneAndUpdate(
      { provider: authUser.provider, subject: authUser.sub },
      {
        $set: dbUpdate,
      },
      { new: true }
    ).lean();
    if (!updated) return res.status(404).json({ message: 'User not found' });

    // eslint-disable-next-line no-console
    console.log('[users] PATCH /me - Updated user:', JSON.stringify({
      id: updated._id,
      first_name: updated.first_name,
      last_name: updated.last_name,
      phone_number: updated.phone_number,
      eventTerminology: updated.eventTerminology,
    }));
    return res.json({
      id: String(updated._id),
      email: updated.email,
      name: updated.name,
      firstName: updated.first_name,
      lastName: updated.last_name,
      phoneNumber: updated.phone_number,
      picture: updated.picture,
      originalPicture: updated.originalPicture || null,
      caricatureHistory: updated.caricatureHistory || [],
      appId: updated.app_id,
      eventTerminology: updated.eventTerminology || 'shift',
    });
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error('[users] PATCH /me failed', err);
    return res.status(500).json({ message: 'Failed to update user profile', error: (err as Error).message });
  }
});

// Get user's gamification stats (points, streaks)
router.get('/users/me/gamification', requireAuth, async (req, res) => {
  try {
    const authUser = (req as any).authUser;
    if (!authUser?.provider || !authUser?.sub) {
      return res.status(401).json({ message: 'Unauthorized' });
    }

    const user = await UserModel.findOne({
      provider: authUser.provider,
      subject: authUser.sub,
    }).lean();

    if (!user) return res.status(404).json({ message: 'User not found' });

    // Return gamification stats with defaults for missing data
    return res.json({
      totalPoints: user.gamification?.totalPoints ?? 0,
      currentStreak: user.gamification?.currentStreak ?? 0,
      longestStreak: user.gamification?.longestStreak ?? 0,
      lastPunctualClockIn: user.gamification?.lastPunctualClockIn ?? null,
      streakStartDate: user.gamification?.streakStartDate ?? null,
      recentHistory: (user.gamification?.pointsHistory ?? []).slice(-20),
    });
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error('[users] GET /me/gamification failed', err);
    return res.status(500).json({ message: 'Failed to fetch gamification stats' });
  }
});

// POST /users/me/revert-picture - Revert to original (pre-caricature) picture
router.post('/users/me/revert-picture', requireAuth, async (req, res) => {
  try {
    const authUser = (req as any).authUser;
    if (!authUser?.provider || !authUser?.sub) {
      return res.status(401).json({ message: 'Unauthorized' });
    }
    if (authUser.managerId) {
      return res.status(403).json({ message: 'Managers should use /managers/me/revert-picture' });
    }

    const user = await UserModel.findOne({
      provider: authUser.provider,
      subject: authUser.sub,
    });
    if (!user) return res.status(404).json({ message: 'User not found' });

    if (!user.originalPicture) {
      return res.status(400).json({ message: 'No original picture to revert to' });
    }

    user.picture = user.originalPicture;
    user.originalPicture = undefined;
    await user.save();

    return res.json({
      picture: user.picture,
      originalPicture: null,
      message: 'Reverted to original picture',
    });
  } catch (err) {
    console.error('[users] POST /me/revert-picture failed', err);
    return res.status(500).json({ message: 'Failed to revert picture', error: (err as Error).message });
  }
});

// DELETE /users/me/caricatures/:index - Delete a caricature from history
router.delete('/users/me/caricatures/:index', requireAuth, async (req, res) => {
  try {
    const authUser = (req as any).authUser;
    if (!authUser?.provider || !authUser?.sub) {
      return res.status(401).json({ message: 'Unauthorized' });
    }
    if (authUser.managerId) {
      return res.status(403).json({ message: 'Managers should use /managers/me/caricatures/:index' });
    }

    const index = parseInt(req.params.index || '0', 10);
    if (isNaN(index) || index < 0) {
      return res.status(400).json({ message: 'Invalid index parameter' });
    }

    const user = await UserModel.findOne({
      provider: authUser.provider,
      subject: authUser.sub,
    });
    if (!user) return res.status(404).json({ message: 'User not found' });

    if (!user.caricatureHistory || index >= user.caricatureHistory.length) {
      return res.status(404).json({ message: 'Caricature not found at index' });
    }

    user.caricatureHistory.splice(index, 1);
    await user.save();

    return res.json({
      message: 'Caricature deleted',
      caricatureHistory: user.caricatureHistory,
    });
  } catch (err) {
    console.error('[users] DELETE /me/caricatures/:index failed', err);
    return res.status(500).json({ message: 'Failed to delete caricature', error: (err as Error).message });
  }
});

// Get user by provider and subject (OAuth identity)
// SECURITY: Managers can only lookup users who are active members of their teams
router.get('/users/by-identity', requireManagerAuth, async (req: AuthenticatedRequest, res) => {
  try {
    const { provider, subject } = req.query;

    if (!provider || !subject || typeof provider !== 'string' || typeof subject !== 'string') {
      return res.status(400).json({
        message: 'Missing or invalid query parameters',
        details: 'Both provider and subject are required as strings'
      });
    }

    const managerId = getCachedManagerId(req);
    if (!managerId) {
      return res.status(403).json({ message: 'Manager authentication required' });
    }

    // Check authorization: user must be an active member of at least one of manager's teams
    const hasAccess = await canAccessUser(managerId, provider, subject);

    if (!hasAccess) {
      // Return 404 instead of 403 to avoid leaking user existence
      return res.status(404).json({ message: 'User not found' });
    }

    // Fetch user profile
    const user = await UserModel.findOne({
      provider: provider,
      subject: subject
    }).lean();

    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }

    return res.json({
      id: String(user._id),
      provider: user.provider,
      subject: user.subject,
      email: user.email,
      name: user.name,
      firstName: user.first_name,
      lastName: user.last_name,
      phoneNumber: user.phone_number,
      picture: user.picture,
      appId: user.app_id,
    });
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error('[users] GET /users/by-identity failed', err);
    return res.status(500).json({ message: 'Failed to fetch user' });
  }
});

// Get user by MongoDB ObjectId
// SECURITY: Managers can only lookup users who are active members of their teams
router.get('/users/:userId', requireManagerAuth, async (req: AuthenticatedRequest, res) => {
  try {
    const { userId } = req.params;

    if (!userId || !mongoose.Types.ObjectId.isValid(userId)) {
      return res.status(400).json({ message: 'Invalid user ID format' });
    }

    const managerId = getCachedManagerId(req);
    if (!managerId) {
      return res.status(403).json({ message: 'Manager authentication required' });
    }

    // Fetch user to get their identity
    const userObjectId = new mongoose.Types.ObjectId(userId);
    const user = await UserModel.findById(userObjectId).lean();

    if (!user) {
      // Return 404 for non-existent users
      return res.status(404).json({ message: 'User not found' });
    }

    // Check authorization: user must be an active member of at least one of manager's teams
    const hasAccess = await canAccessUser(managerId, user.provider, user.subject);

    if (!hasAccess) {
      // Return 404 instead of 403 to avoid leaking user existence
      return res.status(404).json({ message: 'User not found' });
    }

    return res.json({
      id: String(user._id),
      provider: user.provider,
      subject: user.subject,
      email: user.email,
      name: user.name,
      firstName: user.first_name,
      lastName: user.last_name,
      phoneNumber: user.phone_number,
      picture: user.picture,
      appId: user.app_id,
    });
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error('[users] GET /users/:userId failed', err);
    return res.status(500).json({ message: 'Failed to fetch user' });
  }
});

// Cursor-paginated, prefix search by name/email
// SECURITY: Managers can only see users who are active members of their teams
router.get('/users', requireManagerAuth, async (req: AuthenticatedRequest, res) => {
  try {
    const parsed = querySchema.safeParse(req.query);
    if (!parsed.success) return res.status(400).json({ message: 'Invalid query' });
    const { q, cursor, limit } = parsed.data;

    const managerId = getCachedManagerId(req);
    if (!managerId) {
      return res.status(403).json({ message: 'Manager authentication required' });
    }

    // Build aggregation pipeline to join Users with TeamMembers
    // Only return users who are active members of this manager's teams
    const pipeline: any[] = [];

    // Stage 1: Match active team members for this manager
    const teamMemberMatch: any = {
      managerId: managerId,
      status: 'active'
    };

    // Get team members first, then lookup user details
    const teamMembers = await TeamMemberModel.find(teamMemberMatch, {
      provider: 1,
      subject: 1
    }).lean();

    if (teamMembers.length === 0) {
      // No team members yet - return empty result with helpful message
      return res.json({
        items: [],
        nextCursor: undefined,
        message: 'You don\'t have any team members yet. Create an invite link to add members to your team!'
      });
    }

    // Build filter for users based on team member identities
    const userFilter: any = {
      $or: teamMembers.map((tm: any) => ({
        provider: tm.provider,
        subject: tm.subject
      }))
    };

    // Apply search filter if provided
    if (q && q.trim().length > 0) {
      const rx = new RegExp('^' + q.trim().replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'i');
      userFilter.$and = [
        { $or: [{ name: rx }, { email: rx }, { first_name: rx }, { last_name: rx }] }
      ];
    }

    // Apply cursor pagination
    if (cursor) {
      try {
        const idStr = Buffer.from(cursor, 'base64').toString('utf8');
        if (mongoose.Types.ObjectId.isValid(idStr)) {
          userFilter._id = { $gt: new mongoose.Types.ObjectId(idStr) };
        }
      } catch (_) {
        // Invalid cursor, ignore
      }
    }

    // Query users with filter
    const docs = await UserModel.find(userFilter, {
      provider: 1,
      subject: 1,
      email: 1,
      name: 1,
      first_name: 1,
      last_name: 1,
      phone_number: 1,
      picture: 1,
      app_id: 1
    })
      .sort({ _id: 1 })
      .limit(limit + 1)
      .lean();

    // Handle pagination
    let nextCursor: string | undefined;
    let items = docs;
    if (docs.length > limit) {
      items = docs.slice(0, limit);
      const lastDoc = items[items.length - 1];
      if (lastDoc?._id) {
        nextCursor = Buffer.from(String(lastDoc._id)).toString('base64');
      }
    }

    // Map to response format
    const mapped = items.map((u: any) => ({
      id: String(u._id),
      provider: u.provider,
      subject: u.subject,
      email: u.email,
      name: u.name,
      firstName: u.first_name,
      lastName: u.last_name,
      phoneNumber: u.phone_number,
      picture: u.picture,
      appId: u.app_id,
    }));

    return res.json({ items: mapped, nextCursor });
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error('[users] GET /users failed', err);

    // Check if it's an authentication error
    const errorMessage = (err as Error).message || '';
    if (errorMessage.includes('Manager authentication required')) {
      return res.status(403).json({
        message: 'Manager access required',
        hint: 'Please sign in using the manager app to view team members'
      });
    }

    return res.status(500).json({
      message: 'Unable to load users at this time',
      hint: 'Please try again or contact support if the problem persists'
    });
  }
});

export default router;
