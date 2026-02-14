import crypto from 'crypto';
import { Router } from 'express';
import mongoose from 'mongoose';
import { z } from 'zod';

import { requireAuth, AuthenticatedUser } from '../middleware/requireAuth';
import { TeamModel } from '../models/team';
import { TeamMemberModel } from '../models/teamMember';
import { TeamInviteModel } from '../models/teamInvite';
import { UserModel } from '../models/user';
import { ManagerModel } from '../models/manager';
import { ConversationModel } from '../models/conversation';
import { ChatMessageModel } from '../models/chatMessage';
import { TeamApplicantModel } from '../models/teamApplicant';
import { isValidShortCodeFormat } from '../utils/inviteCodeGenerator';
import { inviteValidateLimiter, inviteRedeemLimiter } from '../middleware/rateLimiter';
import { emitToUser, emitToManager } from '../socket/server';

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

    // Find invite by short code (match both 'link' and 'public' types)
    const invite = await TeamInviteModel.findOne({
      shortCode: shortCode.toUpperCase(),
      inviteType: { $in: ['link', 'public'] },
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

    // Find invite (match both 'link' and 'public' types)
    const invite = await TeamInviteModel.findOne({
      shortCode: shortCode.toUpperCase(),
      inviteType: { $in: ['link', 'public'] },
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

    // PUBLIC LINK: Create an applicant record instead of a team member
    if (invite.inviteType === 'public') {
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
    }

    // STANDARD LINK: Create team member directly
    const memberStatus = invite.requireApproval ? 'pending' : 'active';

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

    // Increment used count and log usage
    await TeamInviteModel.updateOne(
      { _id: invite._id },
      {
        $inc: { usedCount: 1 },
        $set: {
          // Mark as accepted if it was pending
          status: invite.status === 'pending' ? 'accepted' : invite.status,
          acceptedAt: new Date(),
        },
        $push: {
          usageLog: {
            userKey,
            userName: authUser.name,
            joinedAt: new Date(),
          },
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

    // Send automated welcome message (only if member is active, not pending)
    if (memberStatus === 'active') {
      try {
        // Get manager details for the message sender
        const manager = await ManagerModel.findById(invite.managerId).lean();
        if (manager) {
          // Use team's custom welcome message or default template
          const welcomeText = team.welcomeMessage
            ? team.welcomeMessage.replace('{teamName}', team.name)
            : `Welcome to ${team.name}! We're excited to have you on the team.`;

          // Create or get conversation
          let conversation = await ConversationModel.findOne({
            managerId: invite.managerId,
            userKey: userKey,
          });

          if (!conversation) {
            conversation = await ConversationModel.create({
              managerId: invite.managerId,
              userKey: userKey,
              lastMessageAt: new Date(),
              lastMessagePreview: welcomeText.substring(0, 200),
              unreadCountManager: 0,
              unreadCountUser: 1,
              createdAt: new Date(),
              updatedAt: new Date(),
            });
          }

          // Create welcome message
          const welcomeMessage = await ChatMessageModel.create({
            conversationId: conversation._id,
            managerId: invite.managerId,
            userKey: userKey,
            senderType: 'manager',
            message: welcomeText,
            messageType: 'text',
            metadata: {
              automated: true,
              type: 'welcome',
            },
            readByManager: true,
            readByUser: false,
            createdAt: new Date(),
          });

          // Update conversation
          await ConversationModel.updateOne(
            { _id: conversation._id },
            {
              $set: {
                lastMessageAt: new Date(),
                lastMessagePreview: welcomeText.substring(0, 200),
                unreadCountUser: conversation.unreadCountUser + 1,
                updatedAt: new Date(),
              },
            }
          );

          // Emit message to user via Socket.IO for real-time delivery
          emitToUser(userKey, 'chat:message', {
            id: String(welcomeMessage._id),
            conversationId: String(conversation._id),
            managerId: String(invite.managerId),
            userKey: userKey,
            senderType: 'manager',
            message: welcomeText,
            messageType: 'text',
            readByManager: true,
            readByUser: false,
            createdAt: welcomeMessage.createdAt.toISOString(),
            metadata: welcomeMessage.metadata,
          });

          // eslint-disable-next-line no-console
          console.log(`[invites] Sent welcome message to ${userKey} for team ${team.name}`);
        }
      } catch (welcomeErr) {
        // Log error but don't fail the invite redemption
        // eslint-disable-next-line no-console
        console.error('[invites] Failed to send welcome message (non-fatal):', welcomeErr);
      }
    }

    return res.json({
      success: true,
      applicationSubmitted: false,
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
