import crypto from 'crypto';
import { Router } from 'express';
import mongoose from 'mongoose';
import { MongoServerError } from 'mongodb';
import { z } from 'zod';

import { requireAuth, AuthenticatedUser } from '../middleware/requireAuth';
import { resolveManagerForRequest } from '../utils/manager';
import { emitToManager, emitToTeams, emitToUser } from '../socket/server';
import { TeamModel, normalizeTeamName } from '../models/team';
import { TeamMemberModel } from '../models/teamMember';
import { TeamInviteModel } from '../models/teamInvite';
import { TeamApplicantModel } from '../models/teamApplicant';
import { TeamMessageModel } from '../models/teamMessage';
import { EventModel } from '../models/event';
import { UserModel } from '../models/user';
import { AvailabilityModel } from '../models/availability';
import { generateUniqueShortCode, isValidShortCodeFormat } from '../utils/inviteCodeGenerator';
import { inviteCreateLimiter } from '../middleware/rateLimiter';

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

const teamMembersQuerySchema = z.object({
  includeUserProfile: z
    .string()
    .transform((val) => val === 'true' || val === '1')
    .optional()
    .default('false'),
});

const createInviteLinkSchema = z.object({
  expiresInDays: z.number().int().min(1).max(90).optional(),
  maxUses: z.number().int().min(1).max(1000).optional().nullable(),
  requireApproval: z.boolean().optional().default(false),
  password: z.string().min(4).max(50).optional(),
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
    const manager = await resolveManagerForRequest(req as any);
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
    const manager = await resolveManagerForRequest(req as any);
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
    const manager = await resolveManagerForRequest(req as any);
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
    const manager = await resolveManagerForRequest(req as any);
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

// IMPORTANT: Specific routes like /teams/my/members must come BEFORE parameterized routes like /teams/:teamId/members
// Get all team members across all manager's teams (for job publishing)
router.get('/teams/my/members', requireAuth, async (req, res) => {
  try {
    const manager = await resolveManagerForRequest(req as any);
    if (!manager || !manager._id) {
      return res.status(400).json({ message: 'Manager not found' });
    }
    const managerId = manager._id as mongoose.Types.ObjectId;

    // eslint-disable-next-line no-console
    console.log(`[teams/my/members] managerId=${managerId}, q=${req.query.q}`);

    // Parse query parameters
    const q = (req.query.q ?? '').toString().trim();
    const cursor = (req.query.cursor ?? '').toString();
    const limit = Math.min(parseInt((req.query.limit ?? '20').toString(), 10) || 20, 100);

    // Build aggregation pipeline
    const pipeline: any[] = [
      {
        $match: {
          managerId: managerId,
          status: 'active', // Only active members for job assignment
        },
      },
    ];

    // eslint-disable-next-line no-console
    console.log(`[teams/my/members] Initial match:`, JSON.stringify(pipeline[0]));

    // Add search filter if provided
    if (q) {
      pipeline.push({
        $match: {
          $or: [
            { name: { $regex: q, $options: 'i' } },
            { email: { $regex: q, $options: 'i' } },
          ],
        },
      });
    }

    // Add cursor-based pagination if provided
    if (cursor) {
      try {
        const cursorId = new mongoose.Types.ObjectId(cursor);
        pipeline.push({
          $match: {
            _id: { $gt: cursorId },
          },
        });
      } catch (e) {
        // Invalid cursor, ignore
      }
    }

    // Join with users collection to get full profile
    pipeline.push({
      $lookup: {
        from: 'users',
        let: { memberProvider: '$provider', memberSubject: '$subject' },
        pipeline: [
          {
            $match: {
              $expr: {
                $and: [
                  { $eq: ['$provider', '$$memberProvider'] },
                  { $eq: ['$subject', '$$memberSubject'] },
                ],
              },
            },
          },
          {
            $project: {
              _id: 1,
              provider: 1,
              subject: 1,
              email: 1,
              name: 1,
              first_name: 1,
              last_name: 1,
              phone_number: 1,
              picture: 1,
            },
          },
        ],
        as: 'userProfile',
      },
    });

    // Sort by creation date
    pipeline.push({ $sort: { _id: 1 } });

    // Limit results
    pipeline.push({ $limit: limit + 1 });

    const members = await TeamMemberModel.aggregate(pipeline);

    // eslint-disable-next-line no-console
    console.log(`[teams/my/members] Found ${members.length} members`);

    // Determine if there are more results
    const hasMore = members.length > limit;
    const items = hasMore ? members.slice(0, limit) : members;
    const nextCursor = hasMore ? String(items[items.length - 1]._id) : null;

    // Format response
    const payload = items.map((member: any) => {
      const userProfile = member.userProfile?.[0];
      return {
        id: String(member._id),
        provider: member.provider,
        subject: member.subject,
        email: userProfile?.email || member.email,
        name: userProfile?.name || member.name,
        first_name: userProfile?.first_name,
        last_name: userProfile?.last_name,
        phone_number: userProfile?.phone_number,
        picture: userProfile?.picture,
      };
    });

    return res.json({
      items: payload,
      nextCursor,
    });
  } catch (err: any) {
    // eslint-disable-next-line no-console
    console.error('[teams] GET /teams/my/members failed', err);
    // If it's a manager resolution error, return 400 with the specific message
    if (err.message && err.message.includes('Manager')) {
      return res.status(400).json({ message: err.message });
    }
    return res.status(500).json({ message: 'Failed to load team members' });
  }
});

router.get('/teams/:teamId/members', requireAuth, async (req, res) => {
  try {
    const manager = await resolveManagerForRequest(req as any);
    const managerId = manager._id as mongoose.Types.ObjectId;
    const teamIdParam = req.params.teamId ?? '';
    if (!mongoose.Types.ObjectId.isValid(teamIdParam)) {
      return res.status(400).json({ message: 'Invalid team id' });
    }
    const teamObjectId = new mongoose.Types.ObjectId(teamIdParam);

    // Parse query parameters
    const queryParsed = teamMembersQuerySchema.safeParse(req.query ?? {});
    const includeUserProfile = queryParsed.success ? queryParsed.data.includeUserProfile : false;

    if (includeUserProfile) {
      // Use aggregation pipeline to join with User collection
      const membersWithProfiles = await TeamMemberModel.aggregate([
        {
          $match: {
            teamId: teamObjectId,
            managerId: managerId,
            status: { $ne: 'left' },
          },
        },
        {
          $lookup: {
            from: 'users', // MongoDB collection name (User model uses 'users')
            let: { memberProvider: '$provider', memberSubject: '$subject' },
            pipeline: [
              {
                $match: {
                  $expr: {
                    $and: [
                      { $eq: ['$provider', '$$memberProvider'] },
                      { $eq: ['$subject', '$$memberSubject'] },
                    ],
                  },
                },
              },
              {
                $project: {
                  _id: 1,
                  provider: 1,
                  subject: 1,
                  email: 1,
                  name: 1,
                  first_name: 1,
                  last_name: 1,
                  phone_number: 1,
                  picture: 1,
                  app_id: 1,
                },
              },
            ],
            as: 'userProfile',
          },
        },
        {
          $sort: { createdAt: -1 },
        },
      ]);

      const payload = membersWithProfiles.map((member: any) => {
        const userProfile = member.userProfile?.[0]; // $lookup returns array
        return {
          id: String(member._id),
          teamId: String(member.teamId),
          provider: member.provider,
          subject: member.subject,
          email: member.email,
          name: member.name,
          status: member.status,
          joinedAt: member.joinedAt,
          createdAt: member.createdAt,
          // Include full user profile if available
          userProfile: userProfile
            ? {
                id: String(userProfile._id),
                provider: userProfile.provider,
                subject: userProfile.subject,
                email: userProfile.email,
                name: userProfile.name,
                firstName: userProfile.first_name,
                lastName: userProfile.last_name,
                phoneNumber: userProfile.phone_number,
                picture: userProfile.picture,
                appId: userProfile.app_id,
              }
            : null,
        };
      });

      return res.json({ members: payload });
    } else {
      // Original behavior - just return team member data
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
    }
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error('[teams] GET /teams/:teamId/members failed', err);
    return res.status(500).json({ message: 'Failed to fetch team members' });
  }
});

router.post('/teams/:teamId/members', requireAuth, async (req, res) => {
  let managerId: mongoose.Types.ObjectId | null = null;
  let teamObjectId: mongoose.Types.ObjectId | null = null;
  let capturedProvider: string | null = null;
  let capturedSubject: string | null = null;

  try {
    const manager = await resolveManagerForRequest(req as any);
    managerId = manager._id as mongoose.Types.ObjectId;
    const managerObjectId = managerId;

    const teamIdParam = req.params.teamId ?? '';
    if (!mongoose.Types.ObjectId.isValid(teamIdParam)) {
      return res.status(400).json({ message: 'Invalid team id' });
    }
    teamObjectId = new mongoose.Types.ObjectId(teamIdParam);

    const parsed = addMemberSchema.safeParse(req.body ?? {});
    if (!parsed.success) {
      return res.status(400).json({ message: 'Validation failed', details: parsed.error.format() });
    }

    const team = await TeamModel.findOne({
      _id: teamObjectId,
      managerId: managerObjectId,
    }).lean();
    if (!team) {
      return res.status(404).json({ message: 'Team not found' });
    }

    const { provider, subject, email, name, status } = parsed.data;
    capturedProvider = provider;
    capturedSubject = subject;
    const desiredStatus = status ?? 'active';

    const setFields: Record<string, unknown> = {
      managerId: managerObjectId,
      email,
      name,
      status: desiredStatus,
      updatedAt: new Date(),
    };

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

    const resolvedMember =
      member ??
      (await TeamMemberModel.findOne({
        teamId: teamObjectId,
        provider,
        subject,
      }).lean());

    if (!resolvedMember) {
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

    const displayName =
      resolvedMember.name ??
      resolvedMember.email ??
      buildUserKey(resolvedMember.provider, resolvedMember.subject);
    await TeamMessageModel.create({
      teamId: resolvedMember.teamId,
      managerId: managerObjectId,
      messageType: 'text',
      body: `${displayName} added to the team`,
      payload: {
        provider,
        subject,
      },
    });

    const memberPayload = {
      id: String(resolvedMember._id),
      teamId: String(resolvedMember.teamId),
      provider: resolvedMember.provider,
      subject: resolvedMember.subject,
      email: resolvedMember.email,
      name: resolvedMember.name,
      status: resolvedMember.status,
      joinedAt: resolvedMember.joinedAt,
      createdAt: resolvedMember.createdAt,
    };

    emitToManager(String(managerObjectId), 'team:memberAdded', memberPayload);
    emitToTeams([String(resolvedMember.teamId)], 'team:memberAdded', memberPayload);
    emitToUser(buildUserKey(provider, subject), 'team:memberAdded', memberPayload);

    return res.status(201).json(memberPayload);
  } catch (err) {
    console.error('[teams] POST /teams/:teamId/members failed', err);

    if (
      err instanceof MongoServerError &&
      err.code === 11000 &&
      teamObjectId &&
      capturedProvider &&
      capturedSubject
    ) {
      const existing = await TeamMemberModel.findOne({
        teamId: teamObjectId,
        provider: capturedProvider,
        subject: capturedSubject,
      }).lean();
      if (existing) {
        const payload = {
          id: String(existing._id),
          teamId: String(existing.teamId),
          provider: existing.provider,
          subject: existing.subject,
          email: existing.email,
          name: existing.name,
          status: existing.status,
          joinedAt: existing.joinedAt,
          createdAt: existing.createdAt,
        };
        return res.status(200).json(payload);
      }
    }

    const details = err instanceof Error ? err.message : undefined;
    return res
      .status(500)
      .json(details ? { message: 'Failed to add member', details } : { message: 'Failed to add member' });
  }
});

router.delete('/teams/:teamId/members/:memberId', requireAuth, async (req, res) => {
  try {
    const manager = await resolveManagerForRequest(req as any);
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
    const manager = await resolveManagerForRequest(req as any);
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
    const manager = await resolveManagerForRequest(req as any);
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
    const manager = await resolveManagerForRequest(req as any);
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
    const manager = await resolveManagerForRequest(req as any);
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

// Create shareable invite link
router.post('/teams/:teamId/invites/create-link', inviteCreateLimiter, requireAuth, async (req, res) => {
  try {
    const manager = await resolveManagerForRequest(req as any);
    const managerId = manager._id as mongoose.Types.ObjectId;
    const teamIdParam = req.params.teamId ?? '';

    if (!mongoose.Types.ObjectId.isValid(teamIdParam)) {
      return res.status(400).json({ message: 'Invalid team id' });
    }
    const teamObjectId = new mongoose.Types.ObjectId(teamIdParam);

    // Verify team exists and belongs to manager
    const team = await TeamModel.findOne({
      _id: teamObjectId,
      managerId,
    }).lean();

    if (!team) {
      return res.status(404).json({ message: 'Team not found' });
    }

    // Validate request body
    const parsed = createInviteLinkSchema.safeParse(req.body ?? {});
    if (!parsed.success) {
      return res.status(400).json({
        message: 'Validation failed',
        details: parsed.error.format(),
      });
    }

    const { expiresInDays, maxUses, requireApproval, password } = parsed.data;

    // Hash password if provided (using Node crypto.scrypt)
    let passwordHash: string | undefined;
    if (password) {
      const salt = crypto.randomBytes(16).toString('hex');
      const hash = await new Promise<string>((resolve, reject) => {
        crypto.scrypt(password, salt, 64, (err, derivedKey) => {
          if (err) reject(err);
          else resolve(`${salt}:${derivedKey.toString('hex')}`);
        });
      });
      passwordHash = hash;
    }

    // Generate unique short code
    const shortCode = await generateUniqueShortCode();

    // Generate standard token for backward compatibility
    const token = generateInviteToken();

    // Calculate expiration date
    let expiresAt: Date | undefined;
    if (expiresInDays) {
      expiresAt = new Date();
      expiresAt.setDate(expiresAt.getDate() + expiresInDays);
    }

    // Create invite
    const invite = await TeamInviteModel.create({
      teamId: teamObjectId,
      managerId,
      invitedBy: managerId,
      token,
      shortCode,
      inviteType: 'link',
      status: 'pending',
      maxUses: maxUses ?? null,
      usedCount: 0,
      requireApproval: requireApproval ?? false,
      passwordHash,
      usageLog: [],
      expiresAt,
    });

    // Build universal link
    const deepLink = `https://join.flowshift.app/invite/${shortCode}`;

    // Generate shareable message
    const expiryText = expiresAt
      ? `Expires: ${expiresAt.toLocaleDateString()}`
      : 'Never expires';

    const shareableMessage = `Join my team on FlowShift! 🎉

Tap this link to join:
${deepLink}

Or enter code: ${shortCode} in the app.

${expiryText}`;

    return res.status(201).json({
      inviteId: String(invite._id),
      shortCode: invite.shortCode,
      deepLink,
      shareableMessage,
      expiresAt: invite.expiresAt,
      maxUses: invite.maxUses,
      usedCount: invite.usedCount,
      requireApproval: invite.requireApproval,
      hasPassword: !!passwordHash,
    });
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error('[teams] POST /teams/:teamId/invites/create-link failed', err);
    return res.status(500).json({ message: 'Failed to create invite link' });
  }
});

// Get all invite links for a team
router.get('/teams/:teamId/invites/links', requireAuth, async (req, res) => {
  try {
    const manager = await resolveManagerForRequest(req as any);
    const managerId = manager._id as mongoose.Types.ObjectId;
    const teamIdParam = req.params.teamId ?? '';

    if (!mongoose.Types.ObjectId.isValid(teamIdParam)) {
      return res.status(400).json({ message: 'Invalid team id' });
    }
    const teamObjectId = new mongoose.Types.ObjectId(teamIdParam);

    // Verify team belongs to manager
    const team = await TeamModel.findOne({
      _id: teamObjectId,
      managerId,
    }).lean();

    if (!team) {
      return res.status(404).json({ message: 'Team not found' });
    }

    // Get all link-type and public-type invites for this team
    const invites = await TeamInviteModel.find({
      teamId: teamObjectId,
      managerId,
      inviteType: { $in: ['link', 'public'] },
    })
      .sort({ createdAt: -1 })
      .limit(50)
      .lean();

    const payload = invites.map((invite) => ({
      id: String(invite._id),
      shortCode: invite.shortCode,
      deepLink: `https://join.flowshift.app/invite/${invite.shortCode}`,
      inviteType: invite.inviteType,
      status: invite.status,
      usedCount: invite.usedCount,
      maxUses: invite.maxUses,
      requireApproval: invite.requireApproval,
      hasPassword: !!invite.passwordHash,
      usageCount: invite.usageLog?.length ?? 0,
      expiresAt: invite.expiresAt,
      createdAt: invite.createdAt,
    }));

    return res.json({ invites: payload });
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error('[teams] GET /teams/:teamId/invites/links failed', err);
    return res.status(500).json({ message: 'Failed to fetch invite links' });
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

    match['$or'] = orConditions;

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

// Revoke an invite link
router.patch('/teams/:teamId/invites/:inviteId/revoke', requireAuth, async (req, res) => {
  try {
    const manager = await resolveManagerForRequest(req as any);
    const managerId = manager._id as mongoose.Types.ObjectId;
    const { teamId: teamIdParam, inviteId: inviteIdParam } = req.params;

    if (!mongoose.Types.ObjectId.isValid(teamIdParam || '') || !mongoose.Types.ObjectId.isValid(inviteIdParam || '')) {
      return res.status(400).json({ message: 'Invalid identifiers' });
    }

    const invite = await TeamInviteModel.findOneAndUpdate(
      {
        _id: new mongoose.Types.ObjectId(inviteIdParam),
        teamId: new mongoose.Types.ObjectId(teamIdParam),
        managerId,
        inviteType: 'link',
        status: 'pending',
      },
      { $set: { status: 'cancelled', updatedAt: new Date() } },
      { new: true }
    ).lean();

    if (!invite) {
      return res.status(404).json({ message: 'Invite link not found or already revoked' });
    }

    return res.json({ message: 'Invite link revoked', inviteId: String(invite._id) });
  } catch (err) {
    console.error('[teams] PATCH /teams/:teamId/invites/:inviteId/revoke failed', err);
    return res.status(500).json({ message: 'Failed to revoke invite link' });
  }
});

// Get usage audit log for an invite link
router.get('/teams/:teamId/invites/:inviteId/usage', requireAuth, async (req, res) => {
  try {
    const manager = await resolveManagerForRequest(req as any);
    const managerId = manager._id as mongoose.Types.ObjectId;
    const { teamId: teamIdParam, inviteId: inviteIdParam } = req.params;

    if (!mongoose.Types.ObjectId.isValid(teamIdParam || '') || !mongoose.Types.ObjectId.isValid(inviteIdParam || '')) {
      return res.status(400).json({ message: 'Invalid identifiers' });
    }

    const invite = await TeamInviteModel.findOne({
      _id: new mongoose.Types.ObjectId(inviteIdParam),
      teamId: new mongoose.Types.ObjectId(teamIdParam),
      managerId,
    }).lean();

    if (!invite) {
      return res.status(404).json({ message: 'Invite not found' });
    }

    return res.json({
      inviteId: String(invite._id),
      shortCode: invite.shortCode,
      usageLog: invite.usageLog ?? [],
      usedCount: invite.usedCount,
    });
  } catch (err) {
    console.error('[teams] GET /teams/:teamId/invites/:inviteId/usage failed', err);
    return res.status(500).json({ message: 'Failed to fetch usage log' });
  }
});

/**
 * GET /teams/members/availability
 * Get availability for all team members across all manager's teams
 * Returns upcoming availability (from today onwards) for all active team members
 */
router.get('/teams/members/availability', requireAuth, async (req, res) => {
  try {
    const manager = await resolveManagerForRequest(req as any);
    const managerId = manager._id as mongoose.Types.ObjectId;

    // Get all active team members for this manager
    const teamMembers = await TeamMemberModel.find({
      managerId: managerId,
      status: 'active',
    }).lean();

    // Build array of userKeys (provider:subject format)
    const userKeys = teamMembers.map((member: any) => `${member.provider}:${member.subject}`);

    if (userKeys.length === 0) {
      return res.json({ availability: [] });
    }

    // Get today's date in YYYY-MM-DD format
    const today = new Date().toISOString().split('T')[0];

    // Fetch availability for all team members (from today onwards)
    const availabilityDocs = await AvailabilityModel.find({
      userKey: { $in: userKeys },
      date: { $gte: today },
    })
      .sort({ userKey: 1, date: 1, startTime: 1 })
      .lean();

    // Map availability docs to include member info
    const availabilityWithMembers = availabilityDocs.map((avail: any) => {
      const member = teamMembers.find(
        (m: any) => `${m.provider}:${m.subject}` === avail.userKey
      );

      return {
        id: String(avail._id),
        userKey: avail.userKey,
        memberName: member?.name || 'Unknown',
        memberEmail: member?.email || '',
        date: avail.date,
        startTime: avail.startTime,
        endTime: avail.endTime,
        status: avail.status,
        createdAt: avail.createdAt,
        updatedAt: avail.updatedAt,
      };
    });

    return res.json({ availability: availabilityWithMembers });
  } catch (err) {
    console.error('[teams] GET /teams/members/availability failed', err);
    return res.status(500).json({ message: 'Failed to fetch team members availability' });
  }
});

// Create public recruitment link
router.post('/teams/:teamId/invites/create-public-link', inviteCreateLimiter, requireAuth, async (req, res) => {
  try {
    const manager = await resolveManagerForRequest(req as any);
    const managerId = manager._id as mongoose.Types.ObjectId;
    const teamIdParam = req.params.teamId ?? '';

    if (!mongoose.Types.ObjectId.isValid(teamIdParam)) {
      return res.status(400).json({ message: 'Invalid team id' });
    }
    const teamObjectId = new mongoose.Types.ObjectId(teamIdParam);

    // Verify team exists and belongs to manager
    const team = await TeamModel.findOne({ _id: teamObjectId, managerId }).lean();
    if (!team) {
      return res.status(404).json({ message: 'Team not found' });
    }

    // Revoke any existing active public link for this team
    await TeamInviteModel.updateMany(
      {
        teamId: teamObjectId,
        managerId,
        inviteType: 'public',
        status: 'pending',
      },
      { $set: { status: 'cancelled', updatedAt: new Date() } }
    );

    // Generate unique short code
    const shortCode = await generateUniqueShortCode();
    const token = crypto.randomBytes(32).toString('hex');

    // Default expiry: 90 days
    const expiresAt = new Date();
    expiresAt.setDate(expiresAt.getDate() + 90);

    const invite = await TeamInviteModel.create({
      teamId: teamObjectId,
      managerId,
      invitedBy: managerId,
      token,
      shortCode,
      inviteType: 'public',
      status: 'pending',
      maxUses: null, // unlimited
      usedCount: 0,
      requireApproval: true, // always requires approval for public links
      usageLog: [],
      expiresAt,
    });

    const deepLink = `https://join.flowshift.app/p/${shortCode}`;

    const shareableMessage = `We're hiring! Join our team on FlowShift 🚀

Apply here: ${deepLink}

Or enter code: ${shortCode} in the FlowShift app.`;

    return res.status(201).json({
      inviteId: String(invite._id),
      shortCode: invite.shortCode,
      deepLink,
      shareableMessage,
      expiresAt: invite.expiresAt,
      inviteType: 'public',
    });
  } catch (err) {
    console.error('[teams] POST /teams/:teamId/invites/create-public-link failed', err);
    return res.status(500).json({ message: 'Failed to create public link' });
  }
});

// Get applicants for a team
router.get('/teams/:teamId/applicants', requireAuth, async (req, res) => {
  try {
    const manager = await resolveManagerForRequest(req as any);
    const managerId = manager._id as mongoose.Types.ObjectId;
    const teamIdParam = req.params.teamId ?? '';

    if (!mongoose.Types.ObjectId.isValid(teamIdParam)) {
      return res.status(400).json({ message: 'Invalid team id' });
    }
    const teamObjectId = new mongoose.Types.ObjectId(teamIdParam);

    // Verify team belongs to manager
    const team = await TeamModel.findOne({ _id: teamObjectId, managerId }).lean();
    if (!team) {
      return res.status(404).json({ message: 'Team not found' });
    }

    const statusFilter = (req.query.status as string) || 'pending';
    const applicants = await TeamApplicantModel.find({
      teamId: teamObjectId,
      status: statusFilter,
    })
      .sort({ appliedAt: -1 })
      .limit(100)
      .lean();

    const payload = applicants.map((a) => ({
      id: String(a._id),
      teamId: String(a.teamId),
      inviteId: String(a.inviteId),
      provider: a.provider,
      subject: a.subject,
      name: a.name,
      email: a.email,
      phoneNumber: a.phoneNumber,
      status: a.status,
      appliedAt: a.appliedAt,
      reviewedAt: a.reviewedAt,
    }));

    return res.json({ applicants: payload });
  } catch (err) {
    console.error('[teams] GET /teams/:teamId/applicants failed', err);
    return res.status(500).json({ message: 'Failed to fetch applicants' });
  }
});

// Approve an applicant
router.post('/teams/:teamId/applicants/:applicantId/approve', requireAuth, async (req, res) => {
  try {
    const manager = await resolveManagerForRequest(req as any);
    const managerId = manager._id as mongoose.Types.ObjectId;
    const { teamId: teamIdParam, applicantId: applicantIdParam } = req.params;

    if (
      !mongoose.Types.ObjectId.isValid(teamIdParam || '') ||
      !mongoose.Types.ObjectId.isValid(applicantIdParam || '')
    ) {
      return res.status(400).json({ message: 'Invalid identifiers' });
    }
    const teamObjectId = new mongoose.Types.ObjectId(teamIdParam);
    const applicantObjectId = new mongoose.Types.ObjectId(applicantIdParam);

    // Find the applicant
    const applicant = await TeamApplicantModel.findOne({
      _id: applicantObjectId,
      teamId: teamObjectId,
      status: 'pending',
    });

    if (!applicant) {
      return res.status(404).json({ message: 'Applicant not found or already reviewed' });
    }

    // Verify team belongs to manager
    const team = await TeamModel.findOne({ _id: teamObjectId, managerId }).lean();
    if (!team) {
      return res.status(404).json({ message: 'Team not found' });
    }

    // Create team member
    await TeamMemberModel.findOneAndUpdate(
      {
        teamId: teamObjectId,
        provider: applicant.provider,
        subject: applicant.subject,
      },
      {
        $set: {
          managerId,
          email: applicant.email,
          name: applicant.name,
          status: 'active',
          joinedAt: new Date(),
          updatedAt: new Date(),
        },
      },
      { upsert: true, new: true, setDefaultsOnInsert: true }
    );

    // Update applicant status
    applicant.status = 'approved';
    applicant.reviewedAt = new Date();
    applicant.reviewedBy = managerId;
    await applicant.save();

    // Log a team message
    const displayName = applicant.name || applicant.email || `${applicant.provider}:${applicant.subject}`;
    await TeamMessageModel.create({
      teamId: teamObjectId,
      managerId,
      messageType: 'text',
      body: `${displayName} was approved and joined the team`,
    });

    // Notify user via Socket.IO
    const userKey = `${applicant.provider}:${applicant.subject}`;
    emitToUser(userKey, 'applicant:approved', {
      teamId: String(teamObjectId),
      teamName: team.name,
    });
    emitToManager(String(managerId), 'applicant:approved', {
      applicantId: String(applicant._id),
      teamId: String(teamObjectId),
    });

    return res.json({
      message: 'Applicant approved',
      applicantId: String(applicant._id),
    });
  } catch (err) {
    console.error('[teams] POST /teams/:teamId/applicants/:applicantId/approve failed', err);
    return res.status(500).json({ message: 'Failed to approve applicant' });
  }
});

// Deny an applicant
router.post('/teams/:teamId/applicants/:applicantId/deny', requireAuth, async (req, res) => {
  try {
    const manager = await resolveManagerForRequest(req as any);
    const managerId = manager._id as mongoose.Types.ObjectId;
    const { teamId: teamIdParam, applicantId: applicantIdParam } = req.params;

    if (
      !mongoose.Types.ObjectId.isValid(teamIdParam || '') ||
      !mongoose.Types.ObjectId.isValid(applicantIdParam || '')
    ) {
      return res.status(400).json({ message: 'Invalid identifiers' });
    }
    const teamObjectId = new mongoose.Types.ObjectId(teamIdParam);
    const applicantObjectId = new mongoose.Types.ObjectId(applicantIdParam);

    const applicant = await TeamApplicantModel.findOne({
      _id: applicantObjectId,
      teamId: teamObjectId,
      status: 'pending',
    });

    if (!applicant) {
      return res.status(404).json({ message: 'Applicant not found or already reviewed' });
    }

    // Verify team belongs to manager
    const team = await TeamModel.findOne({ _id: teamObjectId, managerId }).lean();
    if (!team) {
      return res.status(404).json({ message: 'Team not found' });
    }

    applicant.status = 'denied';
    applicant.reviewedAt = new Date();
    applicant.reviewedBy = managerId;
    await applicant.save();

    emitToManager(String(managerId), 'applicant:denied', {
      applicantId: String(applicant._id),
      teamId: String(teamObjectId),
    });

    return res.json({
      message: 'Applicant denied',
      applicantId: String(applicant._id),
    });
  } catch (err) {
    console.error('[teams] POST /teams/:teamId/applicants/:applicantId/deny failed', err);
    return res.status(500).json({ message: 'Failed to deny applicant' });
  }
});

export default router;
