import mongoose from 'mongoose';
import { EventModel } from '../models/event';
import { TeamModel } from '../models/team';
import { TeamMemberModel } from '../models/teamMember';
import { ManagerModel } from '../models/manager';
import { UserModel } from '../models/user';
import { AvailabilityModel } from '../models/availability';
import { ConversationModel } from '../models/conversation';
import { ChatMessageModel } from '../models/chatMessage';
import { StaffProfileModel } from '../models/staffProfile';
import { checkIfEventFulfilled, computeRoleStats } from '../utils/eventCapacity';
import { sanitizeTeamIds, timeToMinutes, sendEventNotifications } from '../utils/eventHelpers';
import { emitToManager, emitToTeams, emitToUser } from '../socket/server';
import { notificationService } from './notificationService';

// ---------------------------------------------------------------------------
// Shared types
// ---------------------------------------------------------------------------

interface AvailabilityWarning {
  userKey: string;
  date: string;
  unavailableFrom: string;
  unavailableTo: string;
}

interface SharePublicResult {
  success: boolean;
  notifiedCount: number;
  teamCount: number;
  availabilityWarnings: AvailabilityWarning[];
  error?: string;
}

interface SharePrivateResult {
  success: boolean;
  notifiedCount: number;
  availabilityWarnings: AvailabilityWarning[];
  error?: string;
}

interface DirectInvitationResult {
  success: boolean;
  conversationId?: string;
  messageId?: string;
  roleName?: string;
  error?: string;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/** Check availability conflicts for a set of userKeys against an event. */
async function checkAvailabilityConflicts(
  event: any,
  userKeys: string[]
): Promise<AvailabilityWarning[]> {
  const warnings: AvailabilityWarning[] = [];
  if (!event.date || !event.start_time || !event.end_time || userKeys.length === 0) {
    return warnings;
  }

  const eventDate = new Date(event.date);
  const eventDateStr = eventDate.toISOString().split('T')[0];

  const unavailableStaff = await AvailabilityModel.find({
    userKey: { $in: userKeys },
    date: eventDateStr,
    status: 'unavailable',
  }).lean();

  const eventStartMinutes = timeToMinutes(event.start_time);
  const eventEndMinutes = timeToMinutes(event.end_time);

  for (const avail of unavailableStaff) {
    const unavailStartMinutes = timeToMinutes(avail.startTime);
    const unavailEndMinutes = timeToMinutes(avail.endTime);

    if (eventStartMinutes < unavailEndMinutes && eventEndMinutes > unavailStartMinutes) {
      warnings.push({
        userKey: avail.userKey,
        date: avail.date,
        unavailableFrom: avail.startTime,
        unavailableTo: avail.endTime,
      });
    }
  }

  return warnings;
}

/** Build the standard response/socket payload for a published event. */
function buildEventPayload(event: any, extraFields?: Record<string, any>) {
  const eventObj = typeof event.toObject === 'function' ? event.toObject() : event;
  return {
    ...eventObj,
    id: String(eventObj._id),
    managerId: String(eventObj.managerId),
    audience_user_keys: (eventObj.audience_user_keys || []).map(String),
    audience_team_ids: (eventObj.audience_team_ids || []).map(String),
    audience_group_ids: (eventObj.audience_group_ids || []).map(String),
    role_stats: computeRoleStats(
      (eventObj.roles as any[]) || [],
      (eventObj.accepted_staff as any[]) || []
    ),
    ...extraFields,
  };
}

/** Resolve team member userKeys for a set of team IDs. */
async function resolveTeamMemberKeys(teamIds: string[]): Promise<string[]> {
  if (teamIds.length === 0) return [];
  const members = await TeamMemberModel.find({
    teamId: { $in: teamIds.map(id => new mongoose.Types.ObjectId(id)) },
    status: 'active',
  }).lean();

  const keys = new Set<string>();
  for (const m of members) {
    if (m.provider && m.subject) {
      keys.add(`${m.provider}:${m.subject}`);
    }
  }
  return Array.from(keys);
}

// ---------------------------------------------------------------------------
// shareEventPublic — Publish to teams (open shifts)
// ---------------------------------------------------------------------------

export async function shareEventPublic(params: {
  managerId: mongoose.Types.ObjectId;
  eventId: string;
  targetTeamIds?: string[] | null;
  managerName: string;
  managerEmail: string;
}): Promise<SharePublicResult> {
  const { managerId, eventId, targetTeamIds, managerName, managerEmail } = params;

  const event = await EventModel.findOne({
    _id: new mongoose.Types.ObjectId(eventId),
    managerId,
  });

  if (!event) {
    return { success: false, notifiedCount: 0, teamCount: 0, availabilityWarnings: [], error: 'Event not found or not owned by you.' };
  }
  if (event.status !== 'draft') {
    return { success: false, notifiedCount: 0, teamCount: 0, availabilityWarnings: [], error: `Cannot publish — event status is '${event.status}'. Only draft events can be published.` };
  }
  if (checkIfEventFulfilled(event)) {
    return { success: false, notifiedCount: 0, teamCount: 0, availabilityWarnings: [], error: 'Cannot publish — all positions are already filled.' };
  }

  // Resolve teams
  let teamIds: string[];
  if (targetTeamIds && targetTeamIds.length > 0) {
    const validated = await sanitizeTeamIds(managerId, targetTeamIds);
    teamIds = validated.map(String);
  } else {
    // All manager's teams
    const teams = await TeamModel.find({ managerId }).select('_id').lean();
    teamIds = teams.map(t => String(t._id));
  }

  if (teamIds.length === 0) {
    return { success: false, notifiedCount: 0, teamCount: 0, availabilityWarnings: [], error: 'No teams found. Create a team and add staff before publishing.' };
  }

  // Resolve team members
  const targetUserKeys = await resolveTeamMemberKeys(teamIds);

  // Check availability conflicts
  const availabilityWarnings = await checkAvailabilityConflicts(event, targetUserKeys);

  // Infer visibility
  const hasInvitedStaff = (event as any).invited_staff && (event as any).invited_staff.length > 0;
  const visibilityType = hasInvitedStaff ? 'private_public' : 'public';

  // Update event
  event.status = 'published';
  (event as any).publishedAt = new Date();
  (event as any).publishedBy = managerEmail || managerName || String(managerId);
  event.audience_team_ids = teamIds.map(id => new mongoose.Types.ObjectId(id)) as any;
  event.audience_user_keys = targetUserKeys as any;
  (event as any).visibilityType = visibilityType;
  await event.save();

  const payload = buildEventPayload(event, { availabilityWarnings });

  // Emit socket events
  emitToManager(String(managerId), 'event:published', payload);
  emitToTeams(teamIds, 'event:created', payload);
  for (const key of targetUserKeys) {
    emitToUser(key, 'event:created', payload);
  }

  // Send push notifications
  const teams = await TeamModel.find({ _id: { $in: teamIds.map(id => new mongoose.Types.ObjectId(id)) } }).lean();
  const teamIdToName = new Map(teams.map((t: any) => [String(t._id), t.name]));

  const notifiedCount = await sendEventNotifications({
    targetUserKeys,
    event: event.toObject(),
    teamIdToName,
    notificationType: 'new_open',
    managerId: String(managerId),
  });

  return {
    success: true,
    notifiedCount,
    teamCount: teamIds.length,
    availabilityWarnings,
  };
}

// ---------------------------------------------------------------------------
// shareEventPrivate — Publish to specific staff only
// ---------------------------------------------------------------------------

export async function shareEventPrivate(params: {
  managerId: mongoose.Types.ObjectId;
  eventId: string;
  targetUserKeys: string[];
  managerName: string;
  managerEmail: string;
}): Promise<SharePrivateResult> {
  const { managerId, eventId, targetUserKeys, managerName, managerEmail } = params;

  const event = await EventModel.findOne({
    _id: new mongoose.Types.ObjectId(eventId),
    managerId,
  });

  if (!event) {
    return { success: false, notifiedCount: 0, availabilityWarnings: [], error: 'Event not found or not owned by you.' };
  }
  if (event.status !== 'draft') {
    return { success: false, notifiedCount: 0, availabilityWarnings: [], error: `Cannot publish — event status is '${event.status}'. Only draft events can be published.` };
  }
  if (checkIfEventFulfilled(event)) {
    return { success: false, notifiedCount: 0, availabilityWarnings: [], error: 'Cannot publish — all positions are already filled.' };
  }

  // Validate target users are active team members of this manager
  const managerTeams = await TeamModel.find({ managerId }).select('_id').lean();
  const managerTeamIds = managerTeams.map(t => String(t._id));
  const validMembers = await TeamMemberModel.find({
    teamId: { $in: managerTeamIds.map(id => new mongoose.Types.ObjectId(id)) },
    status: 'active',
  }).lean();

  const validUserKeys = new Set(
    validMembers
      .filter(m => m.provider && m.subject)
      .map(m => `${m.provider}:${m.subject}`)
  );

  const filteredUserKeys = targetUserKeys.filter(k => validUserKeys.has(k));
  if (filteredUserKeys.length === 0) {
    return { success: false, notifiedCount: 0, availabilityWarnings: [], error: 'None of the specified staff are active team members.' };
  }

  // Check availability conflicts
  const availabilityWarnings = await checkAvailabilityConflicts(event, filteredUserKeys);

  // Update event
  event.status = 'published';
  (event as any).publishedAt = new Date();
  (event as any).publishedBy = managerEmail || managerName || String(managerId);
  event.audience_user_keys = filteredUserKeys as any;
  (event as any).visibilityType = 'private';
  await event.save();

  const payload = buildEventPayload(event, { availabilityWarnings });

  // Emit socket events
  emitToManager(String(managerId), 'event:published', payload);
  for (const key of filteredUserKeys) {
    emitToUser(key, 'event:created', payload);
  }

  // Send push notifications (use empty team map since this is private)
  const teamIdToName = new Map<string, string>();
  const notifiedCount = await sendEventNotifications({
    targetUserKeys: filteredUserKeys,
    event: event.toObject(),
    teamIdToName,
    notificationType: 'new_open',
    managerId: String(managerId),
  });

  return {
    success: true,
    notifiedCount,
    availabilityWarnings,
  };
}

// ---------------------------------------------------------------------------
// sendDirectInvitation — 1-on-1 chat invitation for a specific role
// ---------------------------------------------------------------------------

export async function sendDirectInvitation(params: {
  managerId: mongoose.Types.ObjectId;
  eventId: string;
  inviteeUserKey: string;
  roleName: string;
  managerName: string;
  managerPicture: string | null;
}): Promise<DirectInvitationResult> {
  const { managerId, eventId, inviteeUserKey, roleName, managerName, managerPicture } = params;

  const event = await EventModel.findOne({
    _id: new mongoose.Types.ObjectId(eventId),
    managerId,
  });

  if (!event) {
    return { success: false, error: 'Event not found or not owned by you.' };
  }

  // Match roleName against event.roles (case-insensitive)
  const matchedRole = event.roles.find(
    (r: any) => r.role?.toLowerCase() === roleName.toLowerCase()
  );
  if (!matchedRole) {
    const available = event.roles.map((r: any) => r.role).join(', ');
    return { success: false, error: `Role "${roleName}" not found on this event. Available roles: ${available}` };
  }

  // Check if invitee already in invited_staff
  const existingInvited = ((event as any).invited_staff || []) as any[];
  const alreadyInvited = existingInvited.some(
    (s: any) => s.userKey === inviteeUserKey
  );
  if (alreadyInvited) {
    return { success: false, error: 'This staff member has already been invited to this event.' };
  }

  // Verify invitee is an active team member of this manager
  const managerTeams = await TeamModel.find({ managerId }).select('_id').lean();
  const managerTeamIds = managerTeams.map(t => t._id);
  const membership = await TeamMemberModel.findOne({
    teamId: { $in: managerTeamIds },
    $expr: {
      $eq: [
        { $concat: ['$provider', ':', '$subject'] },
        inviteeUserKey,
      ],
    },
    status: 'active',
  }).lean();

  if (!membership) {
    return { success: false, error: 'Staff member is not an active team member.' };
  }

  // Find or create conversation (upsert pattern from ai.ts)
  const conversation = await ConversationModel.findOneAndUpdate(
    { managerId, userKey: inviteeUserKey },
    { $setOnInsert: { managerId, userKey: inviteeUserKey } },
    { upsert: true, new: true }
  );

  // Build invitation message text
  let messageText = `You're invited to work as **${matchedRole.role}**`;
  if (event.client_name) {
    messageText += ` for ${event.client_name}`;
  }
  if (event.date) {
    const d = new Date(event.date as any);
    const formattedDate = `${d.getDate()} ${d.toLocaleDateString('en-US', { month: 'short' })}`;
    messageText += ` on ${formattedDate}`;
  }
  if (event.start_time && event.end_time) {
    messageText += `, ${event.start_time} - ${event.end_time}`;
  }
  if (event.venue_name) {
    messageText += ` at ${event.venue_name}`;
  }
  messageText += '. Tap to accept or decline.';

  // Create chat message with eventInvitation type
  const chatMessage = await ChatMessageModel.create({
    conversationId: conversation._id,
    managerId,
    userKey: inviteeUserKey,
    senderType: 'manager',
    senderName: managerName,
    senderPicture: managerPicture,
    message: messageText,
    messageType: 'eventInvitation',
    metadata: {
      eventId: String(event._id),
      roleId: matchedRole.role,
      status: 'pending',
    },
    readByManager: true,
    readByUser: false,
  });

  // Atomic event update: add to invited_staff and audience
  const updateOps: any = {
    $push: {
      invited_staff: {
        userKey: inviteeUserKey,
        roleId: String(matchedRole.role),
        roleName: matchedRole.role,
      },
    },
    $addToSet: { audience_user_keys: inviteeUserKey },
  };

  // If event is still a draft, auto-publish as private
  if (event.status === 'draft') {
    updateOps.$set = {
      status: 'published',
      visibilityType: 'private',
      publishedAt: new Date(),
      publishedBy: managerName || 'Manager',
    };
  }

  await EventModel.updateOne({ _id: event._id }, updateOps);

  // Update conversation metadata
  await ConversationModel.findByIdAndUpdate(conversation._id, {
    lastMessageAt: chatMessage.createdAt,
    lastMessagePreview: messageText.substring(0, 200),
    $inc: { unreadCountUser: 1 },
  });

  // Emit real-time chat message
  const messagePayload = {
    id: String(chatMessage._id),
    conversationId: String(conversation._id),
    senderType: 'manager',
    senderName: managerName,
    senderPicture: managerPicture,
    message: chatMessage.message,
    messageType: 'eventInvitation',
    metadata: chatMessage.metadata,
    readByManager: true,
    readByUser: false,
    createdAt: chatMessage.createdAt,
  };
  emitToUser(inviteeUserKey, 'chat:message', messagePayload);

  // Send push notification (purple dot format)
  const user = await UserModel.findOne({
    $expr: {
      $eq: [
        { $concat: ['$provider', ':', '$subject'] },
        inviteeUserKey,
      ],
    },
  });

  if (user) {
    const notificationTitle = `🟣 ${managerName}`;
    // Build rich notification body
    const bodyParts: string[] = [];
    if (event.date) {
      const d = new Date(event.date as any);
      let datePart = `${d.getDate()} ${d.toLocaleDateString('en-US', { month: 'short' })}`;
      if (event.start_time && event.end_time) {
        datePart += `, ${event.start_time} - ${event.end_time}`;
      }
      bodyParts.push(datePart);
    }
    if (event.client_name) bodyParts.push(event.client_name);
    bodyParts.push(matchedRole.role);

    const notificationBody = bodyParts.join(' • ');

    await notificationService.sendToUser(
      String(user._id),
      notificationTitle,
      notificationBody,
      {
        type: 'chat',
        conversationId: String(conversation._id),
        messageId: String(chatMessage._id),
        senderName: managerName,
        managerId: String(managerId),
      },
      'user'
    );
  }

  return {
    success: true,
    conversationId: String(conversation._id),
    messageId: String(chatMessage._id),
    roleName: matchedRole.role,
  };
}
