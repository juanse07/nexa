import { Router } from 'express';
import mongoose from 'mongoose';
import { z } from 'zod';

import { requireAuth, AuthenticatedUser } from '../middleware/requireAuth';
import { TeamModel } from '../models/team';
import { TeamMemberModel } from '../models/teamMember';
import { TeamInviteModel } from '../models/teamInvite';
import { isValidShortCodeFormat } from '../utils/inviteCodeGenerator';
import { inviteValidateLimiter, inviteRedeemLimiter } from '../middleware/rateLimiter';

const router = Router();

const redeemInviteSchema = z.object({
  shortCode: z.string().min(6).max(6),
});

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
      inviteType: 'link',
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

    const { shortCode } = parsed.data;

    if (!isValidShortCodeFormat(shortCode)) {
      return res.status(400).json({ message: 'Invalid invite code format' });
    }

    // Find invite
    const invite = await TeamInviteModel.findOne({
      shortCode: shortCode.toUpperCase(),
      inviteType: 'link',
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

    // Determine member status based on requireApproval
    const memberStatus = invite.requireApproval ? 'pending' : 'active';

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

    // Create team member
    const member = await TeamMemberModel.findOneAndUpdate(
      {
        teamId: invite.teamId,
        provider: authUser.provider,
        subject: authUser.sub,
      },
      {
        $set: {
          managerId: invite.managerId,
          email: authUser.email,
          name: authUser.name,
          status: memberStatus,
          joinedAt: new Date(),
          updatedAt: new Date(),
        },
      },
      { upsert: true, new: true, setDefaultsOnInsert: true }
    );

    // Increment used count
    await TeamInviteModel.updateOne(
      { _id: invite._id },
      {
        $inc: { usedCount: 1 },
        $set: {
          // Mark as accepted if it was pending
          status: invite.status === 'pending' ? 'accepted' : invite.status,
          acceptedAt: new Date(),
        },
      }
    );

    // Check if max uses reached and update status
    if (invite.maxUses && invite.usedCount + 1 >= invite.maxUses) {
      await TeamInviteModel.updateOne(
        { _id: invite._id },
        { $set: { status: 'accepted' } }
      );
    }

    return res.json({
      success: true,
      team: {
        id: String(team._id),
        name: team.name,
        description: team.description,
      },
      member: {
        id: String(member._id),
        status: member.status,
        joinedAt: member.joinedAt,
      },
      memberStatus: memberStatus,
      requiresApproval: invite.requireApproval,
      message: invite.requireApproval
        ? 'Join request submitted. Waiting for manager approval.'
        : 'Successfully joined team!',
    });
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error('[invites] POST /invites/redeem failed', err);
    return res.status(500).json({ message: 'Failed to redeem invite' });
  }
});

export default router;
