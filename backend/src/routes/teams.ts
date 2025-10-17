import crypto from 'crypto';
import { Router } from 'express';
import mongoose from 'mongoose';
import { z } from 'zod';

import { requireAuth, AuthenticatedUser } from '../middleware/requireAuth';
import { resolveManagerForRequest } from '../utils/manager';
import { emitToManager, emitToTeams, emitToUser } from '../socket/server';
import { TeamModel, normalizeTeamName } from '../models/team';
import { TeamMemberModel } from '../models/teamMember';
import { TeamInviteModel } from '../models/teamInvite';
import { TeamMessageModel } from '../models/teamMessage';
import { EventModel } from '../models/event';

const router = Router();

const createTeamSchema = z.object({
  name: z.string().min(1, 'name is required').max(200),
  description: z.string().max(500).optional(),
});

const updateTeamSchema = z.object({
  name: z.string().min(1, 'name is required').max(200).optional(),
  description: z.string().max(500).optional(),
});

const inviteRecipientSchema = z
  .object({
    email: z.string().email().optional(),
    provider: z.string().min(1).optional(),
    subject: z.string().min(1).optional(),
    name: z.string().max(200).optional(),
  })
  .refine(
    (value) => {
      if (value.email) return true;
      return !!value.provider && !!value.subject;
    },
    { message: 'Recipient requires an email or provider+subject identifier' }
  );

const createInviteSchema = z.object({
  recipients: z.array(inviteRecipientSchema).min(1, 'At least one recipient is required'),
  expiresInDays: z.number().int().min(1).max(90).optional(),
  message: z.string().max(1000).optional(),
});

const addMemberSchema = z.object({
  provider: z.string().min(1, 'provider is required'),
  subject: z.string().min(1, 'subject is required'),
  email: z.string().email().optional(),
  name: z.string().max(200).optional(),
  status: z.enum(['pending', 'active']).optional(),
});

const paginationSchema = z.object({
  limit: z
    .number()
    .int()
    .min(1)
    .max(100)
    .default(50),
  before: z.string().nullish(),
});

const defaultInviteExpiryDays = 14;

function generateInviteToken(): string {
  return crypto.randomBytes(32).toString('hex');
}

function buildUserKey(provider: string, subject: string): string {
  return `${provider}:${subject}`;
}

router.get('/teams', requireAuth, async (req, res) => {
  try {
    const manager = await resolveManagerForRequest(req);
    const managerId = manager._id as mongoose.Types.ObjectId;

    const teams = await TeamModel.find({ managerId: managerId })
      .sort({ createdAt: -1 })
      .lean();

    const teamIds = teams.map((team) => team._id);

    const memberCounts = await TeamMemberModel.aggregate([
      { $match: { teamId: { $in: teamIds }, status: { $ne: 'left' } } },
      { $group: { _id: '$teamId', count: { $sum: 1 } } },
    ]);

    const countMap = new Map<string, number>();
    for (const entry of memberCounts) {
      countMap.set(String(entry._id), entry.count);
    }

    const inviteCounts = await TeamInviteModel.aggregate([
      { $match: { teamId: { $in: teamIds }, status: 'pending' } },
      { $group: { _id: '$teamId', count: { $sum: 1 } } },
    ]);

    const inviteMap = new Map<string, number>();
    for (const entry of inviteCounts) {
      inviteMap.set(String(entry._id), entry.count);
    }

    const payload = teams.map((team) => ({
      id: String(team._id),
      name: team.name,
      description: team.description,
      createdAt: team.createdAt,
      updatedAt: team.updatedAt,
      memberCount: countMap.get(String(team._id)) ?? 0,
      pendingInvites: inviteMap.get(String(team._id)) ?? 0,
    }));

    return res.json({ teams: payload });
  } catch (err) {
    return res.status(500).json({ message: 'Failed to fetch teams' });
  }
});

router.post('/teams', requireAuth, async (req, res) => {
  try {
    const manager = await resolveManagerForRequest(req);
    const managerId = manager._id as mongoose.Types.ObjectId;
    const parsed = createTeamSchema.safeParse(req.body);
    if (!parsed.success) {
      return res.status(400).json({ message: 'Validation failed', details: parsed.error.format() });
    }

    const { name, description } = parsed.data;

    const normalizedName = normalizeTeamName(name);
    const existing = await TeamModel.findOne({ managerId: managerId, normalizedName }).lean();
    if (existing) {
      return res.status(409).json({ message: 'Team with that name already exists' });
    }

    const created = await TeamModel.create({
      managerId,
      name,
      normalizedName,
      description,
    });

    const payload = {
      id: String(created._id),
      name: created.name,
      description: created.description,
      createdAt: created.createdAt,
      updatedAt: created.updatedAt,
    };

    emitToManager(String(managerId), 'team:created', payload);

    return res.status(201).json(payload);
  } catch (err) {
    return res.status(500).json({ message: 'Failed to create team' });
  }
});

router.patch('/teams/:teamId', requireAuth, async (req, res) => {
  try {
    const manager = await resolveManagerForRequest(req);
    const managerId = manager._id as mongoose.Types.ObjectId;
    const teamIdParam = req.params.teamId ?? '';
    if (!mongoose.Types.ObjectId.isValid(teamIdParam)) {
      return res.status(400).json({ message: 'Invalid team id' });
    }
    const teamObjectId = new mongoose.Types.ObjectId(teamIdParam);

    const parsed = updateTeamSchema.safeParse(req.body);
    if (!parsed.success) {
      return res.status(400).json({ message: 'Validation failed', details: parsed.error.format() });
    }

    const updates: Record<string, unknown> = {};
    if (parsed.data.name) {
      const normalizedName = normalizeTeamName(parsed.data.name);
      const conflict = await TeamModel.findOne({
        managerId,
        normalizedName,
        _id: { $ne: teamObjectId },
      }).lean();
      if (conflict) {
        return res.status(409).json({ message: 'Another team with that name already exists' });
      }
      updates.name = parsed.data.name.trim();
      updates.normalizedName = normalizedName;
    }
    if (Object.prototype.hasOwnProperty.call(parsed.data, 'description')) {
      updates.description = parsed.data.description ?? undefined;
    }
    updates.updatedAt = new Date();

    const updated = await TeamModel.findOneAndUpdate(
      { _id: teamObjectId, managerId },
      { $set: updates },
      { new: true }
    ).lean();

    if (!updated) {
      return res.status(404).json({ message: 'Team not found' });
    }

    const payload = {
      id: String(updated._id),
      name: updated.name,
      description: updated.description,
      createdAt: updated.createdAt,
      updatedAt: updated.updatedAt,
    };

    emitToManager(String(managerId), 'team:updated', payload);

    return res.json(payload);
  } catch (err) {
    return res.status(500).json({ message: 'Failed to update team' });
  }
});

router.delete('/teams/:teamId', requireAuth, async (req, res) => {
  try {
    const manager = await resolveManagerForRequest(req);
    const managerId = manager._id as mongoose.Types.ObjectId;
    const teamIdParam = req.params.teamId ?? '';
    if (!mongoose.Types.ObjectId.isValid(teamIdParam)) {
      return res.status(400).json({ message: 'Invalid team id' });
    }

    const objectId = new mongoose.Types.ObjectId(teamIdParam);

    const team = await TeamModel.findOne({ _id: objectId, managerId }).lean();
    if (!team) {
      return res.status(404).json({ message: 'Team not found' });
    }

    const isReferenced = await EventModel.exists({
      managerId,
      audience_team_ids: objectId,
    });
    if (isReferenced) {
      return res.status(409).json({ message: 'Team is referenced by existing events' });
    }

    await Promise.all([
      TeamModel.deleteOne({ _id: objectId }),
      TeamMemberModel.deleteMany({ teamId: objectId }),
      TeamInviteModel.deleteMany({ teamId: objectId }),
      TeamMessageModel.deleteMany({ teamId: objectId }),
    ]);

    emitToManager(String(managerId), 'team:deleted', { teamId: String(objectId) });
    emitToTeams([String(objectId)], 'team:deleted', { teamId: String(objectId) });

    return res.json({ message: 'Team deleted' });
  } catch (err) {
    return res.status(500).json({ message: 'Failed to delete team' });
  }
});

router.get('/teams/:teamId/members', requireAuth, async (req, res) => {
  try {
    const manager = await resolveManagerForRequest(req);
    const managerId = manager._id as mongoose.Types.ObjectId;
    const teamIdParam = req.params.teamId ?? '';
    if (!mongoose.Types.ObjectId.isValid(teamIdParam)) {
      return res.status(400).json({ message: 'Invalid team id' });
    }
    const teamObjectId = new mongoose.Types.ObjectId(teamIdParam);

    const members = await TeamMemberModel.find({
      teamId: teamObjectId,
      managerId,
      status: { $ne: 'left' },
    })
      .sort({ createdAt: -1 })
      .lean();

    const payload = members.map((member) => ({
      id: String(member._id),
      teamId: String(member.teamId),
      provider: member.provider,
      subject: member.subject,
      email: member.email,
      name: member.name,
      status: member.status,
      joinedAt: member.joinedAt,
      createdAt: member.createdAt,
    }));

    return res.json({ members: payload });
  } catch (err) {
    return res.status(500).json({ message: 'Failed to fetch team members' });
  }
});

router.post('/teams/:teamId/members', requireAuth, async (req, res) => {
  try {
    const manager = await resolveManagerForRequest(req);
    const managerId = manager._id as mongoose.Types.ObjectId;
    const teamIdParam = req.params.teamId ?? '';
    if (!mongoose.Types.ObjectId.isValid(teamIdParam)) {
      return res.status(400).json({ message: 'Invalid team id' });
    }
    const teamObjectId = new mongoose.Types.ObjectId(teamIdParam);

    const parsed = addMemberSchema.safeParse(req.body ?? {});
    if (!parsed.success) {
      return res.status(400).json({ message: 'Validation failed', details: parsed.error.format() });
    }

    const team = await TeamModel.findOne({
      _id: teamObjectId,
      managerId,
    }).lean();
    if (!team) {
      return res.status(404).json({ message: 'Team not found' });
    }

    const { provider, subject, email, name, status } = parsed.data;
    const desiredStatus = status ?? 'active';

    const setFields: Record<string, unknown> = {
      managerId,
      email,
      name,
      status: desiredStatus,
      updatedAt: new Date(),
    };
    if (desiredStatus === 'active') {
      setFields.joinedAt = new Date();
    }

    const member = await TeamMemberModel.findOneAndUpdate(
      {
        teamId: teamObjectId,
        provider,
        subject,
      },
      {
        $set: setFields,
        $setOnInsert: {
          joinedAt: new Date(),
        },
      },
      { upsert: true, new: true, setDefaultsOnInsert: true }
    ).lean();

    if (!member) {
      return res.status(500).json({ message: 'Failed to add member' });
    }

    await TeamInviteModel.updateMany(
      {
        teamId: teamObjectId,
        provider,
        subject,
        status: 'pending',
      },
      {
        $set: {
          status: 'accepted',
          acceptedAt: new Date(),
          claimedByKey: buildUserKey(provider, subject),
        },
      }
    );

    const displayName = (name ?? email ?? buildUserKey(provider, subject)).toString();
    await TeamMessageModel.create({
      teamId: member.teamId,
      managerId,
      messageType: 'text',
      body: `${displayName} added to the team`,
      payload: {
        provider,
        subject,
      },
    });

    const memberPayload = {
      id: String(member._id),
      teamId: String(member.teamId),
      provider: member.provider,
      subject: member.subject,
      email: member.email,
      name: member.name,
      status: member.status,
      joinedAt: member.joinedAt,
      createdAt: member.createdAt,
    };

    emitToManager(String(managerId), 'team:memberAdded', memberPayload);
    emitToTeams([String(member.teamId)], 'team:memberAdded', memberPayload);
    emitToUser(buildUserKey(provider, subject), 'team:memberAdded', memberPayload);

    return res.status(201).json(memberPayload);
  } catch (err) {
    return res.status(500).json({ message: 'Failed to add member' });
  }
});

router.delete('/teams/:teamId/members/:memberId', requireAuth, async (req, res) => {
  try {
    const manager = await resolveManagerForRequest(req);
    const managerId = manager._id as mongoose.Types.ObjectId;
    const teamIdParam = req.params.teamId ?? '';
    const memberIdParam = req.params.memberId ?? '';
    if (!mongoose.Types.ObjectId.isValid(teamIdParam) || !mongoose.Types.ObjectId.isValid(memberIdParam)) {
      return res.status(400).json({ message: 'Invalid identifiers' });
    }
    const teamObjectId = new mongoose.Types.ObjectId(teamIdParam);
    const memberObjectId = new mongoose.Types.ObjectId(memberIdParam);

    const result = await TeamMemberModel.findOneAndUpdate(
      {
        _id: memberObjectId,
        teamId: teamObjectId,
        managerId,
      },
      { $set: { status: 'left', updatedAt: new Date() } },
      { new: true }
    ).lean();

    if (!result) {
      return res.status(404).json({ message: 'Membership not found' });
    }

    await TeamMessageModel.create({
      teamId: result.teamId,
      managerId,
      messageType: 'text',
      body: `${result.name ?? buildUserKey(result.provider, result.subject)} left the team`,
    });

    const payload = {
      teamId: String(result.teamId),
      memberId: String(result._id),
      provider: result.provider,
      subject: result.subject,
    };

    emitToManager(String(managerId), 'team:memberRemoved', payload);
    emitToTeams([String(result.teamId)], 'team:memberRemoved', payload);
    emitToUser(buildUserKey(result.provider, result.subject), 'team:memberRemoved', payload);

    return res.json({ message: 'Member removed' });
  } catch (err) {
    return res.status(500).json({ message: 'Failed to remove member' });
  }
});

router.get('/teams/:teamId/messages', requireAuth, async (req, res) => {
  try {
    const manager = await resolveManagerForRequest(req);
    const managerId = manager._id as mongoose.Types.ObjectId;
    const teamIdParam = req.params.teamId ?? '';
    const paginationParams = paginationSchema.safeParse({
      limit: req.query.limit ? Number(req.query.limit) : undefined,
      before: req.query.before,
    });
    if (!paginationParams.success) {
      return res.status(400).json({ message: 'Invalid pagination params' });
    }

    if (!mongoose.Types.ObjectId.isValid(teamIdParam)) {
      return res.status(400).json({ message: 'Invalid team id' });
    }
    const teamObjectId = new mongoose.Types.ObjectId(teamIdParam);

    const { limit, before } = paginationParams.data;
    const match: Record<string, unknown> = {
      teamId: teamObjectId,
      managerId,
    };

    if (before) {
      match._id = { $lt: new mongoose.Types.ObjectId(before) };
    }

    const messages = await TeamMessageModel.find(match)
      .sort({ _id: -1 })
      .limit(limit)
      .lean();

    const payload = messages.map((message) => ({
      id: String(message._id),
      teamId: String(message.teamId),
      messageType: message.messageType,
      body: message.body,
      payload: message.payload,
      senderKey: message.senderKey,
      senderName: message.senderName,
      createdAt: message.createdAt,
    }));

    return res.json({ messages: payload });
  } catch (err) {
    return res.status(500).json({ message: 'Failed to fetch messages' });
  }
});

router.post('/teams/:teamId/invites', requireAuth, async (req, res) => {
  try {
    const manager = await resolveManagerForRequest(req);
    const managerId = manager._id as mongoose.Types.ObjectId;
    const teamIdParam = req.params.teamId ?? '';
    if (!mongoose.Types.ObjectId.isValid(teamIdParam)) {
      return res.status(400).json({ message: 'Invalid team id' });
    }
    const teamObjectId = new mongoose.Types.ObjectId(teamIdParam);

    const team = await TeamModel.findOne({
      _id: teamObjectId,
      managerId,
    }).lean();
    if (!team) {
      return res.status(404).json({ message: 'Team not found' });
    }
    const teamIdString = String(team._id);

    const parsed = createInviteSchema.safeParse(req.body);
    if (!parsed.success) {
      return res.status(400).json({ message: 'Validation failed', details: parsed.error.format() });
    }

    const { recipients, expiresInDays, message } = parsed.data;
    const expiresAt = new Date();
    expiresAt.setDate(expiresAt.getDate() + (expiresInDays ?? defaultInviteExpiryDays));

    const createdInvites = [] as any[];
    const skipped: { recipient: string; reason: string }[] = [];

    for (const recipient of recipients) {
      const key = recipient.provider && recipient.subject
        ? buildUserKey(recipient.provider, recipient.subject)
        : recipient.email ?? 'unknown';

      if (recipient.provider && recipient.subject) {
        const existingMember = await TeamMemberModel.findOne({
          teamId: teamObjectId,
          provider: recipient.provider,
          subject: recipient.subject,
          status: { $ne: 'left' },
        }).lean();
        if (existingMember) {
          skipped.push({ recipient: key, reason: 'already a member' });
          continue;
        }
      }

      const invite = await TeamInviteModel.create({
        teamId: teamObjectId,
        managerId,
        invitedBy: managerId,
        token: generateInviteToken(),
        email: recipient.email,
        provider: recipient.provider,
        subject: recipient.subject,
        status: 'pending',
        expiresAt,
      });

      createdInvites.push({
        id: String(invite._id),
        token: invite.token,
        email: invite.email,
        provider: invite.provider,
        subject: invite.subject,
        status: invite.status,
        expiresAt: invite.expiresAt,
      });

      await TeamMessageModel.create({
        teamId: teamObjectId,
        managerId,
        messageType: 'invite_created',
        body: message ?? undefined,
        payload: {
          inviteId: String(invite._id),
          email: invite.email,
          provider: invite.provider,
          subject: invite.subject,
        },
      });
    }

    return res.status(201).json({ invites: createdInvites, skipped });
  } catch (err) {
    return res.status(500).json({ message: 'Failed to create invites' });
  }
});

router.get('/teams/:teamId/invites', requireAuth, async (req, res) => {
  try {
    const manager = await resolveManagerForRequest(req);
    const managerId = manager._id as mongoose.Types.ObjectId;
    const teamIdParam = req.params.teamId ?? '';
    if (!mongoose.Types.ObjectId.isValid(teamIdParam)) {
      return res.status(400).json({ message: 'Invalid team id' });
    }
    const teamObjectId = new mongoose.Types.ObjectId(teamIdParam);

    const invites = await TeamInviteModel.find({
      teamId: teamObjectId,
      managerId,
    })
      .sort({ createdAt: -1 })
      .limit(200)
      .lean();

    const payload = invites.map((invite) => ({
      id: String(invite._id),
      email: invite.email,
      provider: invite.provider,
      subject: invite.subject,
      status: invite.status,
      expiresAt: invite.expiresAt,
      createdAt: invite.createdAt,
      acceptedAt: invite.acceptedAt,
    }));

    return res.json({ invites: payload });
  } catch (err) {
    return res.status(500).json({ message: 'Failed to fetch invites' });
  }
});

router.post('/teams/:teamId/invites/:inviteId/cancel', requireAuth, async (req, res) => {
  try {
    const manager = await resolveManagerForRequest(req);
    const managerId = manager._id as mongoose.Types.ObjectId;
    const teamIdParam = req.params.teamId ?? '';
    const inviteIdParam = req.params.inviteId ?? '';
    if (!mongoose.Types.ObjectId.isValid(teamIdParam) || !mongoose.Types.ObjectId.isValid(inviteIdParam)) {
      return res.status(400).json({ message: 'Invalid identifiers' });
    }
    const teamObjectId = new mongoose.Types.ObjectId(teamIdParam);
    const inviteObjectId = new mongoose.Types.ObjectId(inviteIdParam);

    const invite = await TeamInviteModel.findOneAndUpdate(
      {
        _id: inviteObjectId,
        teamId: teamObjectId,
        managerId,
        status: 'pending',
      },
      { $set: { status: 'cancelled', updatedAt: new Date() } },
      { new: true }
    ).lean();

    if (!invite) {
      return res.status(404).json({ message: 'Invite not found or already processed' });
    }

    await TeamMessageModel.create({
      teamId: invite.teamId,
      managerId,
      messageType: 'invite_declined',
      body: 'Invite cancelled by manager',
      payload: { inviteId: String(invite._id) },
    });

    return res.json({ message: 'Invite cancelled' });
  } catch (err) {
    return res.status(500).json({ message: 'Failed to cancel invite' });
  }
});

router.post('/invites/:token/accept', requireAuth, async (req, res) => {
  try {
    const authUser = (req as any).user as AuthenticatedUser;
    const { token } = req.params;
    const invite = await TeamInviteModel.findOne({ token }).lean();
    if (!invite) {
      return res.status(404).json({ message: 'Invite not found' });
    }

    if (invite.status !== 'pending') {
      return res.status(409).json({ message: `Invite already ${invite.status}` });
    }

    if (invite.expiresAt && invite.expiresAt.getTime() < Date.now()) {
      await TeamInviteModel.updateOne({ _id: invite._id }, { $set: { status: 'expired' } });
      return res.status(410).json({ message: 'Invite has expired' });
    }

    const team = await TeamModel.findOne({
      _id: invite.teamId,
      managerId: invite.managerId,
    }).lean();
    if (!team) {
      return res.status(404).json({ message: 'Team not found' });
    }

    const userKey = buildUserKey(authUser.provider, authUser.sub);

    const member = await TeamMemberModel.findOneAndUpdate(
      {
        teamId: invite.teamId,
        provider: authUser.provider,
        subject: authUser.sub,
      },
      {
        $set: {
          managerId: invite.managerId,
          email: authUser.email ?? invite.email,
          name: authUser.name,
          joinedAt: new Date(),
          status: 'active',
        },
      },
      { upsert: true, new: true, setDefaultsOnInsert: true }
    ).lean();

    await TeamInviteModel.updateOne(
      { _id: invite._id },
      {
        $set: {
          status: 'accepted',
          acceptedAt: new Date(),
          claimedByKey: userKey,
        },
      }
    );

    await TeamMessageModel.create({
      teamId: invite.teamId,
      managerId: invite.managerId,
      messageType: 'invite_accepted',
      senderKey: userKey,
      senderName: authUser.name,
      payload: { inviteId: String(invite._id) },
    });
    const memberPayload = {
      id: String(member?._id ?? ''),
      teamId: String(invite.teamId),
      provider: authUser.provider,
      subject: authUser.sub,
      email: member?.email,
      name: member?.name,
      status: member?.status,
      joinedAt: member?.joinedAt,
      createdAt: member?.createdAt,
    };

    return res.json({
      team: {
        id: String(team._id),
        name: team.name,
        description: team.description,
      },
      member: memberPayload,
    });
  } catch (err) {
    return res.status(500).json({ message: 'Failed to accept invite' });
  }
});

router.post('/invites/:token/decline', requireAuth, async (req, res) => {
  try {
    const authUser = (req as any).user as AuthenticatedUser;
    const { token } = req.params;
    const invite = await TeamInviteModel.findOne({ token }).lean();
    if (!invite) {
      return res.status(404).json({ message: 'Invite not found' });
    }

    if (invite.status !== 'pending') {
      return res.status(409).json({ message: `Invite already ${invite.status}` });
    }

    await TeamInviteModel.updateOne(
      { _id: invite._id },
      { $set: { status: 'declined', updatedAt: new Date() } }
    );

    await TeamMessageModel.create({
      teamId: invite.teamId,
      managerId: invite.managerId,
      messageType: 'invite_declined',
      senderKey: buildUserKey(authUser.provider, authUser.sub),
      senderName: authUser.name,
      payload: { inviteId: String(invite._id) },
    });

    return res.json({ message: 'Invite declined' });
  } catch (err) {
    return res.status(500).json({ message: 'Failed to decline invite' });
  }
});

router.get('/teams/my', requireAuth, async (req, res) => {
  try {
    const authUser = (req as any).user as AuthenticatedUser;
    if (!authUser?.provider || !authUser.sub) {
      return res.status(400).json({ message: 'Missing user identity' });
    }

    const memberships = await TeamMemberModel.find({
      provider: authUser.provider,
      subject: authUser.sub,
      status: 'active',
    })
      .sort({ joinedAt: -1 })
      .lean();

    if (memberships.length === 0) {
      return res.json({ teams: [] });
    }

    const teamIds = memberships
      .map((membership) => membership.teamId)
      .filter((value): value is mongoose.Types.ObjectId => value instanceof mongoose.Types.ObjectId);

    const teams = await TeamModel.find({ _id: { $in: teamIds } }).lean();
    const teamMap = new Map<string, any>(teams.map((team) => [String(team._id), team]));

    const payload = memberships.map((membership) => {
      const team = teamMap.get(String(membership.teamId)) ?? {};
      return {
        membershipId: String(membership._id),
        teamId: String(membership.teamId),
        managerId: membership.managerId ? String(membership.managerId) : undefined,
        name: (team as any).name ?? 'Untitled team',
        description: (team as any).description,
        joinedAt: membership.joinedAt,
      };
    });

    return res.json({ teams: payload });
  } catch (err) {
    return res.status(500).json({ message: 'Failed to load my teams' });
  }
});

router.get('/teams/my/invites', requireAuth, async (req, res) => {
  try {
    const authUser = (req as any).user as AuthenticatedUser;
    if (!authUser?.provider || !authUser.sub) {
      return res.status(400).json({ message: 'Missing user identity' });
    }

    const match: Record<string, any> = {
      status: 'pending',
    };

    const orConditions: Record<string, any>[] = [
      { provider: authUser.provider, subject: authUser.sub },
    ];

    if (authUser.email) {
      orConditions.push({ email: authUser.email });
    }

    match['\$or'] = orConditions;

    const invites = await TeamInviteModel.find(match).sort({ createdAt: -1 }).limit(200).lean();

    if (invites.length === 0) {
      return res.json({ invites: [] });
    }

    const teamIds = invites
      .map((invite) => invite.teamId)
      .filter((value): value is mongoose.Types.ObjectId => value instanceof mongoose.Types.ObjectId);

    const teams = await TeamModel.find({ _id: { $in: teamIds } })
      .select('_id name description managerId')
      .lean();
    const teamMap = new Map<string, any>(teams.map((team) => [String(team._id), team]));

    const payload = invites.map((invite) => {
      const team = teamMap.get(String(invite.teamId)) ?? {};
      return {
        inviteId: String(invite._id),
        teamId: String(invite.teamId),
        teamName: (team as any).name ?? 'Untitled team',
        teamDescription: (team as any).description,
        managerId: invite.managerId ? String(invite.managerId) : undefined,
        email: invite.email,
        provider: invite.provider,
        subject: invite.subject,
        token: invite.token,
        expiresAt: invite.expiresAt,
        createdAt: invite.createdAt,
      };
    });

    return res.json({ invites: payload });
  } catch (err) {
    return res.status(500).json({ message: 'Failed to load invites' });
  }
});

export default router;
