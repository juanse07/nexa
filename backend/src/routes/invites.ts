import crypto from 'crypto';
import { Router } from 'express';
import { z } from 'zod';

import { requireAuth, AuthenticatedUser } from '../middleware/requireAuth';
import { TeamModel } from '../models/team';
import { TeamMemberModel } from '../models/teamMember';
import { TeamInviteModel } from '../models/teamInvite';
import { UserModel } from '../models/user';
import { TeamApplicantModel } from '../models/teamApplicant';
import { isValidShortCodeFormat } from '../utils/inviteCodeGenerator';
import { inviteValidateLimiter, inviteRedeemLimiter } from '../middleware/rateLimiter';
import { emitToManager } from '../socket/server';

const router = Router();

const redeemInviteSchema = z.object({
  shortCode: z.string().min(6).max(6),
  password: z.string().optional(),
});

async function verifyPassword(password: string, hash: string): Promise<boolean> {
  const [salt = '', key] = hash.split(':');
  return new Promise((resolve, reject) => {
    crypto.scrypt(password, salt, 64, (err, derivedKey) => {
      if (err) reject(err);
      else resolve(derivedKey.toString('hex') === key);
    });
  });
}

// Validate invite code (unauthenticated - for preview)
router.get('/invites/validate/:shortCode', inviteValidateLimiter, async (req, res) => {
  try {
    const { shortCode } = req.params;

    if (!shortCode || !isValidShortCodeFormat(shortCode)) {
      return res.status(400).json({
        valid: false,
        reason: 'invalid_format',
      });
    }

    // Find invite by short code
    const invite = await TeamInviteModel.findOne({
      shortCode: shortCode.toUpperCase(),
      inviteType: 'public',
    }).lean();

    if (!invite) {
      return res.status(404).json({
        valid: false,
        reason: 'not_found',
      });
    }

    // Check if expired
    if (invite.expiresAt && invite.expiresAt.getTime() < Date.now()) {
      // Auto-expire
      await TeamInviteModel.updateOne(
        { _id: invite._id },
        { $set: { status: 'expired' } }
      );

      return res.json({
        valid: false,
        reason: 'expired',
      });
    }

    // Check if revoked or cancelled
    if (invite.status === 'cancelled' || invite.status === 'expired') {
      return res.json({
        valid: false,
        reason: invite.status,
      });
    }

    // Check if max uses reached
    if (invite.maxUses && invite.usedCount >= invite.maxUses) {
      return res.json({
        valid: false,
        reason: 'max_uses_reached',
      });
    }

    // Get team details
    const team = await TeamModel.findById(invite.teamId)
      .select('name description')
      .lean();

    if (!team) {
      return res.json({
        valid: false,
        reason: 'team_not_found',
      });
    }

    // Count team members
    const memberCount = await TeamMemberModel.countDocuments({
      teamId: invite.teamId,
      status: { $ne: 'left' },
    });

    return res.json({
      valid: true,
      teamId: String(invite.teamId),
      teamName: team.name,
      teamDescription: team.description,
      memberCount,
      expiresAt: invite.expiresAt,
      requiresApproval: invite.requireApproval,
      hasPassword: !!invite.passwordHash,
      isPublicLink: invite.inviteType === 'public',
      usesRemaining:
        invite.maxUses ? invite.maxUses - invite.usedCount : null,
    });
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error('[invites] GET /invites/validate/:shortCode failed', err);
    return res.status(500).json({
      valid: false,
      reason: 'server_error',
    });
  }
});

// Redeem invite code (authenticated)
router.post('/invites/redeem', inviteRedeemLimiter, requireAuth, async (req, res) => {
  try {
    const authUser = (req as any).authUser as AuthenticatedUser;

    if (!authUser?.provider || !authUser.sub) {
      return res.status(401).json({ message: 'Authentication required' });
    }

    // Validate request body
    const parsed = redeemInviteSchema.safeParse(req.body ?? {});
    if (!parsed.success) {
      return res.status(400).json({
        message: 'Validation failed',
        details: parsed.error.format(),
      });
    }

    const { shortCode, password } = parsed.data;

    if (!isValidShortCodeFormat(shortCode)) {
      return res.status(400).json({ message: 'Invalid invite code format' });
    }

    // Find public invite
    const invite = await TeamInviteModel.findOne({
      shortCode: shortCode.toUpperCase(),
      inviteType: 'public',
    });

    if (!invite) {
      return res.status(404).json({ message: 'Invite not found' });
    }

    // Check if expired
    if (invite.expiresAt && invite.expiresAt.getTime() < Date.now()) {
      await TeamInviteModel.updateOne(
        { _id: invite._id },
        { $set: { status: 'expired' } }
      );
      return res.status(410).json({ message: 'Invite has expired' });
    }

    // Check status
    if (invite.status !== 'pending') {
      return res.status(409).json({
        message: `Invite is ${invite.status}`,
      });
    }

    // Check max uses
    if (invite.maxUses && invite.usedCount >= invite.maxUses) {
      return res.status(410).json({
        message: 'Invite has reached maximum number of uses',
      });
    }

    // Verify password if required
    if (invite.passwordHash) {
      if (!password) {
        return res.status(403).json({
          message: 'This invite requires a password',
          requiresPassword: true,
        });
      }
      const passwordValid = await verifyPassword(password, invite.passwordHash);
      if (!passwordValid) {
        return res.status(403).json({ message: 'Incorrect password' });
      }
    }

    // Get team
    const team = await TeamModel.findById(invite.teamId).lean();
    if (!team) {
      return res.status(404).json({ message: 'Team not found' });
    }

    // Check if user is already a member
    const existingMember = await TeamMemberModel.findOne({
      teamId: invite.teamId,
      provider: authUser.provider,
      subject: authUser.sub,
      status: { $ne: 'left' },
    }).lean();

    if (existingMember) {
      return res.status(409).json({
        message: 'You are already a member of this team',
        team: {
          id: String(team._id),
          name: team.name,
          description: team.description,
        },
      });
    }

    // Create or update user record (required for chat functionality)
    await UserModel.findOneAndUpdate(
      {
        provider: authUser.provider,
        subject: authUser.sub,
      },
      {
        $setOnInsert: {
          provider: authUser.provider,
          subject: authUser.sub,
          createdAt: new Date(),
        },
        $set: {
          email: authUser.email,
          name: authUser.name,
          updatedAt: new Date(),
        },
      },
      { upsert: true, setDefaultsOnInsert: true }
    );

    const userKey = `${authUser.provider}:${authUser.sub}`;

    // Check if already applied
    const existingApplicant = await TeamApplicantModel.findOne({
      teamId: invite.teamId,
      provider: authUser.provider,
      subject: authUser.sub,
    }).lean();

    if (existingApplicant) {
      return res.status(409).json({
        message: existingApplicant.status === 'pending'
          ? 'You have already applied to this team. Please wait for manager approval.'
          : `Your application was previously ${existingApplicant.status}.`,
        applicationSubmitted: existingApplicant.status === 'pending',
        applicationStatus: existingApplicant.status,
      });
    }

    // Create applicant
    const applicant = await TeamApplicantModel.create({
      teamId: invite.teamId,
      managerId: invite.managerId,
      inviteId: invite._id,
      provider: authUser.provider,
      subject: authUser.sub,
      name: authUser.name,
      email: authUser.email,
      status: 'pending',
      appliedAt: new Date(),
    });

    // Increment usage
    await TeamInviteModel.updateOne(
      { _id: invite._id },
      {
        $inc: { usedCount: 1 },
        $push: {
          usageLog: {
            userKey,
            userName: authUser.name,
            joinedAt: new Date(),
          },
        },
      }
    );

    // Notify manager of new applicant
    emitToManager(String(invite.managerId), 'applicant:new', {
      applicantId: String(applicant._id),
      teamId: String(invite.teamId),
      teamName: team.name,
      applicantName: authUser.name,
    });

    return res.json({
      success: true,
      applicationSubmitted: true,
      team: {
        id: String(team._id),
        name: team.name,
        description: team.description,
      },
      message: `Thanks for applying to ${team.name}! The manager has been notified and will review your application.`,
    });
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error('[invites] POST /invites/redeem failed', err);
    return res.status(500).json({ message: 'Failed to redeem invite' });
  }
});

export default router;
