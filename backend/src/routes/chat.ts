import { Router } from 'express';
import { requireAuth, AuthenticatedRequest } from '../middleware/requireAuth';
import { ConversationModel } from '../models/conversation';
import { ChatMessageModel } from '../models/chatMessage';
import { ManagerModel } from '../models/manager';
import { UserModel } from '../models/user';
import { emitToManager, emitToUser } from '../socket/server';
import mongoose from 'mongoose';

const router = Router();

/**
 * GET /chat/conversations
 * Get all conversations for the authenticated user (manager or user)
 */
router.get('/conversations', requireAuth, async (req, res) => {
  try {
    const { managerId, provider, sub } = (req as AuthenticatedRequest).authUser;
    const userKey = `${provider}:${sub}`;

    let conversations;

    if (managerId) {
      // Manager: get all conversations with users
      const managerObjectId = new mongoose.Types.ObjectId(managerId);
      conversations = await ConversationModel.find({ managerId: managerObjectId })
        .sort({ lastMessageAt: -1 })
        .lean();

      // Populate user info
      const userKeys = conversations.map(c => c.userKey);
      const users = await UserModel.find({
        $expr: {
          $in: [
            { $concat: ['$provider', ':', '$subject'] },
            userKeys
          ]
        }
      }).lean();

      const userMap = new Map(
        users.map(u => [`${u.provider}:${u.subject}`, u])
      );

      const result = conversations.map(conv => ({
        id: conv._id.toString(),
        userKey: conv.userKey,
        userName: userMap.get(conv.userKey)?.name ||
                  userMap.get(conv.userKey)?.first_name ||
                  'User',
        userPicture: userMap.get(conv.userKey)?.picture,
        userEmail: userMap.get(conv.userKey)?.email,
        lastMessageAt: conv.lastMessageAt,
        lastMessagePreview: conv.lastMessagePreview,
        unreadCount: conv.unreadCountManager,
        updatedAt: conv.updatedAt,
      }));

      return res.json({ conversations: result });
    } else {
      // User: get conversation with their manager(s)
      conversations = await ConversationModel.find({ userKey })
        .sort({ lastMessageAt: -1 })
        .lean();

      // Populate manager info
      const managerIds = conversations.map(c => c.managerId);
      const managers = await ManagerModel.find({
        _id: { $in: managerIds }
      }).lean();

      const managerMap = new Map(
        managers.map(m => [m._id.toString(), m])
      );

      const result = conversations
        .filter(conv => {
          if (!conv.managerId) {
            console.log('[CHAT ERROR] Filtering out conversation with missing managerId:', conv._id);
            return false;
          }
          return true;
        })
        .map(conv => {
          console.log('[CHAT DEBUG] User conversation - convId:', conv._id, 'managerId:', conv.managerId, 'type:', typeof conv.managerId);

          return {
            id: conv._id.toString(),
            managerId: conv.managerId.toString(),
            managerName: managerMap.get(conv.managerId.toString())?.name ||
                         managerMap.get(conv.managerId.toString())?.first_name ||
                         'Manager',
            managerPicture: managerMap.get(conv.managerId.toString())?.picture,
            managerEmail: managerMap.get(conv.managerId.toString())?.email,
            lastMessageAt: conv.lastMessageAt,
            lastMessagePreview: conv.lastMessagePreview,
            unreadCount: conv.unreadCountUser,
            updatedAt: conv.updatedAt,
          };
        });

      return res.json({ conversations: result });
    }
  } catch (error) {
    console.error('Error fetching conversations:', error);
    return res.status(500).json({ error: 'Failed to fetch conversations' });
  }
});

/**
 * GET /chat/conversations/:conversationId/messages
 * Get messages for a specific conversation
 */
router.get('/conversations/:conversationId/messages', requireAuth, async (req, res) => {
  try {
    const { conversationId } = req.params;
    const { managerId, provider, sub } = (req as AuthenticatedRequest).authUser;
    const userKey = `${provider}:${sub}`;
    const limit = parseInt(req.query.limit as string) || 50;
    const before = req.query.before as string; // ISO date string for pagination

    if (!mongoose.Types.ObjectId.isValid(conversationId as string)) {
      return res.status(400).json({ error: 'Invalid conversation ID' });
    }

    // Verify access to conversation
    const conversation = await ConversationModel.findById(conversationId);
    if (!conversation) {
      return res.status(404).json({ error: 'Conversation not found' });
    }

    const hasAccess = managerId
      ? conversation.managerId.toString() === managerId
      : conversation.userKey === userKey;

    if (!hasAccess) {
      return res.status(403).json({ error: 'Access denied' });
    }

    // Build query
    const query: any = { conversationId: new mongoose.Types.ObjectId(conversationId) };
    if (before) {
      query.createdAt = { $lt: new Date(before) };
    }

    // Fetch messages
    const messages = await ChatMessageModel.find(query)
      .sort({ createdAt: -1 })
      .limit(limit)
      .lean();

    const result = messages.map(msg => ({
      id: msg._id.toString(),
      conversationId: msg.conversationId.toString(),
      senderType: msg.senderType,
      senderName: msg.senderName,
      senderPicture: msg.senderPicture,
      message: msg.message,
      messageType: msg.messageType || 'text',
      metadata: msg.metadata || null,
      readByManager: msg.readByManager,
      readByUser: msg.readByUser,
      createdAt: msg.createdAt,
    })).reverse(); // Reverse to get oldest first

    return res.json({ messages: result });
  } catch (error) {
    console.error('Error fetching messages:', error);
    return res.status(500).json({ error: 'Failed to fetch messages' });
  }
});

/**
 * POST /chat/conversations/:targetId/messages
 * Send a message to a user (if manager) or to manager (if user)
 * targetId: managerId if user is sending, userKey if manager is sending
 */
router.post('/conversations/:targetId/messages', requireAuth, async (req, res) => {
  try {
    const { targetId } = req.params;
    const { message, messageType, metadata } = req.body;
    const { managerId, provider, sub, name, picture } = (req as AuthenticatedRequest).authUser;
    const userKey = `${provider}:${sub}`;

    console.log('[CHAT DEBUG] POST message - targetId:', targetId, 'managerId:', managerId, 'userKey:', userKey);
    console.log('[CHAT DEBUG] messageType:', messageType, 'metadata:', metadata);

    if (!message || typeof message !== 'string' || message.trim().length === 0) {
      return res.status(400).json({ error: 'Message is required' });
    }

    if (message.trim().length > 5000) {
      return res.status(400).json({ error: 'Message is too long (max 5000 characters)' });
    }

    // Determine if sender is a manager (only check JWT token)
    let senderManagerId: mongoose.Types.ObjectId | null = null;
    if (managerId) {
      senderManagerId = new mongoose.Types.ObjectId(managerId);
    }

    console.log('[CHAT DEBUG] Sender is manager?', !!senderManagerId, 'managerId:', senderManagerId?.toString());

    let conversation;
    let targetManagerId: mongoose.Types.ObjectId | null = null;
    let targetUserKey: string;
    let senderType: 'manager' | 'user';

    if (senderManagerId) {
      // Manager sending to user
      senderType = 'manager';
      targetUserKey = targetId as string;

      console.log('[CHAT DEBUG] Manager sending to user. targetUserKey:', targetUserKey);

      // Verify user exists
      const parts = targetUserKey.split(':');
      if (parts.length !== 2) {
        console.log('[CHAT ERROR] Invalid userKey format:', targetUserKey);
        return res.status(400).json({ error: 'Invalid user key format. Expected format: provider:subject' });
      }
      const [provider, subject] = parts;
      const user = await UserModel.findOne({ provider, subject });
      if (!user) {
        console.log('[CHAT ERROR] User not found:', provider, subject);
        return res.status(404).json({ error: 'User not found' });
      }
      console.log('[CHAT DEBUG] User found:', user._id);

      // Find or create conversation
      conversation = await ConversationModel.findOneAndUpdate(
        { managerId: senderManagerId, userKey: targetUserKey },
        {
          $setOnInsert: {
            managerId: senderManagerId,
            userKey: targetUserKey,
          }
        },
        { upsert: true, new: true }
      );

      targetManagerId = senderManagerId;
    } else {
      // User sending to manager
      senderType = 'user';

      console.log('[CHAT DEBUG] User sending message - targetId:', targetId, 'type:', typeof targetId);

      if (!targetId || targetId === 'null' || targetId === 'undefined') {
        console.log('[CHAT ERROR] Manager ID is null or undefined');
        return res.status(400).json({ error: 'Manager ID is required. Please contact your manager to start a conversation.' });
      }

      if (!mongoose.Types.ObjectId.isValid(targetId as string)) {
        console.log('[CHAT ERROR] Invalid manager ID format:', targetId);
        return res.status(400).json({ error: 'Invalid manager ID format' });
      }

      targetManagerId = new mongoose.Types.ObjectId(targetId as string);

      // Verify manager exists
      const manager = await ManagerModel.findById(targetManagerId);
      if (!manager) {
        return res.status(404).json({ error: 'Manager not found' });
      }

      // Find or create conversation
      conversation = await ConversationModel.findOneAndUpdate(
        { managerId: targetManagerId, userKey },
        {
          $setOnInsert: {
            managerId: targetManagerId,
            userKey,
          }
        },
        { upsert: true, new: true }
      );

      targetUserKey = userKey;
    }

    // Create message
    const chatMessage = await ChatMessageModel.create({
      conversationId: conversation._id,
      managerId: targetManagerId,
      userKey: targetUserKey!,
      senderType,
      senderName: name,
      senderPicture: picture,
      message: message.trim(),
      messageType: messageType || 'text',
      metadata: metadata || null,
      readByManager: senderType === 'manager',
      readByUser: senderType === 'user',
    });

    // Update conversation
    await ConversationModel.findByIdAndUpdate(conversation._id, {
      lastMessageAt: chatMessage.createdAt,
      lastMessagePreview: message.trim().substring(0, 200),
      $inc: senderType === 'manager'
        ? { unreadCountUser: 1 }
        : { unreadCountManager: 1 }
    });

    const messagePayload = {
      id: String(chatMessage._id),
      conversationId: String(conversation._id),
      senderType: chatMessage.senderType,
      senderName: chatMessage.senderName,
      senderPicture: chatMessage.senderPicture,
      message: chatMessage.message,
      messageType: chatMessage.messageType,
      metadata: chatMessage.metadata,
      readByManager: chatMessage.readByManager,
      readByUser: chatMessage.readByUser,
      createdAt: chatMessage.createdAt,
    };

    // Emit to recipient via Socket.IO
    if (senderType === 'manager') {
      emitToUser(targetUserKey!, 'chat:message', messagePayload);
    } else {
      emitToManager(targetManagerId!.toString(), 'chat:message', messagePayload);
    }

    return res.status(201).json({ message: messagePayload });
  } catch (error) {
    console.error('Error sending message:', error);
    return res.status(500).json({ error: 'Failed to send message' });
  }
});

/**
 * PATCH /chat/conversations/:conversationId/read
 * Mark all messages in a conversation as read
 */
router.patch('/conversations/:conversationId/read', requireAuth, async (req, res) => {
  try {
    const { conversationId } = req.params;
    const { managerId, provider, sub } = (req as AuthenticatedRequest).authUser;
    const userKey = `${provider}:${sub}`;

    if (!mongoose.Types.ObjectId.isValid(conversationId as string)) {
      return res.status(400).json({ error: 'Invalid conversation ID' });
    }

    // Verify access
    const conversation = await ConversationModel.findById(conversationId);
    if (!conversation) {
      return res.status(404).json({ error: 'Conversation not found' });
    }

    const hasAccess = managerId
      ? conversation.managerId.toString() === managerId
      : conversation.userKey === userKey;

    if (!hasAccess) {
      return res.status(403).json({ error: 'Access denied' });
    }

    // Update messages
    if (managerId) {
      await ChatMessageModel.updateMany(
        { conversationId: conversation._id, readByManager: false },
        { $set: { readByManager: true } }
      );
      await ConversationModel.findByIdAndUpdate(conversationId, {
        unreadCountManager: 0
      });
    } else {
      await ChatMessageModel.updateMany(
        { conversationId: conversation._id, readByUser: false },
        { $set: { readByUser: true } }
      );
      await ConversationModel.findByIdAndUpdate(conversationId, {
        unreadCountUser: 0
      });
    }

    return res.json({ success: true });
  } catch (error) {
    console.error('Error marking messages as read:', error);
    return res.status(500).json({ error: 'Failed to mark messages as read' });
  }
});

/**
 * GET /chat/managers
 * For users: Get list of their managers to start a chat
 */
router.get('/managers', requireAuth, async (req, res) => {
  try {
    const { managerId, provider, sub } = (req as AuthenticatedRequest).authUser;

    if (managerId) {
      return res.status(403).json({ error: 'Only users can access this endpoint' });
    }

    const userKey = `${provider}:${sub}`;

    // Find teams the user is a member of
    const { TeamMemberModel } = await import('../models/teamMember');
    const memberships = await TeamMemberModel.find({
      provider,
      subject: sub,
      status: 'active'
    }).distinct('teamId');

    // Find managers of those teams
    const { TeamModel } = await import('../models/team');
    const teams = await TeamModel.find({
      _id: { $in: memberships }
    }).distinct('managerId');

    // Get manager details
    const managers = await ManagerModel.find({
      _id: { $in: teams }
    }).lean();

    const result = managers.map(m => ({
      id: m._id.toString(),
      name: m.name || m.first_name || 'Manager',
      email: m.email,
      picture: m.picture,
    }));

    return res.json({ managers: result });
  } catch (error) {
    console.error('Error fetching managers:', error);
    return res.status(500).json({ error: 'Failed to fetch managers' });
  }
});

/**
 * GET /chat/debug/check-conversations
 * Debug endpoint to check for conversations with missing managerIds
 */
router.get('/debug/check-conversations', requireAuth, async (req, res) => {
  try {
    const conversations = await ConversationModel.find({}).lean();
    const issues: any[] = [];

    for (const conv of conversations) {
      if (!conv.managerId) {
        issues.push({
          conversationId: conv._id.toString(),
          userKey: conv.userKey,
          issue: 'Missing managerId'
        });
      }
    }

    return res.json({
      total: conversations.length,
      issues: issues.length,
      problemConversations: issues,
    });
  } catch (error) {
    console.error('Error checking conversations:', error);
    return res.status(500).json({ error: 'Failed to check conversations' });
  }
});

/**
 * POST /chat/invitations/:messageId/respond
 * Staff member accepts or declines an event invitation
 */
router.post('/invitations/:messageId/respond', requireAuth, async (req, res) => {
  try {
    const { messageId } = req.params;
    const { accept, eventId, roleId } = req.body;
    const { managerId, provider, sub, name } = (req as AuthenticatedRequest).authUser;
    const userKey = `${provider}:${sub}`;

    console.log('[INVITATION] Respond - messageId:', messageId, 'accept:', accept, 'eventId:', eventId, 'roleId:', roleId);

    // Validate input
    if (!messageId || !mongoose.Types.ObjectId.isValid(messageId)) {
      return res.status(400).json({ error: 'Invalid message ID' });
    }

    if (typeof accept !== 'boolean') {
      return res.status(400).json({ error: 'accept must be a boolean' });
    }

    if (!eventId || !roleId) {
      return res.status(400).json({ error: 'eventId and roleId are required' });
    }

    // Only users can respond to invitations (not managers)
    if (managerId) {
      return res.status(403).json({ error: 'Only staff members can respond to invitations' });
    }

    // Find the message
    const message = await ChatMessageModel.findById(messageId);
    if (!message) {
      return res.status(404).json({ error: 'Message not found', code: 'MESSAGE_NOT_FOUND' });
    }

    // Verify user has access to this message
    if (message.userKey !== userKey) {
      return res.status(403).json({ error: 'Access denied' });
    }

    // Verify it's an invitation message
    if (message.messageType !== 'eventInvitation') {
      return res.status(400).json({ error: 'Message is not an event invitation' });
    }

    // Check if already responded
    if (message.metadata?.status && message.metadata.status !== 'pending') {
      return res.status(400).json({
        error: 'Invitation already responded to',
        code: 'INVITATION_ALREADY_RESPONDED',
        currentStatus: message.metadata.status
      });
    }

    // If accepting, update the event roster
    let updatedEvent = null;
    if (accept) {
      const { EventModel } = await import('../models/event');

      // Find the event
      const event = await EventModel.findById(eventId);
      if (!event) {
        return res.status(404).json({ error: 'Event not found', code: 'EVENT_NOT_FOUND' });
      }

      // Find the role (use any to bypass TypeScript strict typing)
      const role: any = event.roles.find((r: any) =>
        (r._id?.toString() === roleId || r.role_id?.toString() === roleId || r.role === roleId)
      );

      if (!role) {
        return res.status(404).json({ error: 'Role not found in event', code: 'ROLE_NOT_FOUND' });
      }

      // Check if role is full
      const confirmedUserIds: string[] = role.confirmed_user_ids || [];
      const quantity: number = role.quantity || role.count || 0;

      if (confirmedUserIds.length >= quantity) {
        return res.status(400).json({
          error: 'Event role is already full',
          code: 'EVENT_ROLE_FULL',
          role: role.role_name || role.role,
          filled: confirmedUserIds.length,
          needed: quantity
        });
      }

      // Add user to confirmed_user_ids
      if (!confirmedUserIds.includes(userKey)) {
        confirmedUserIds.push(userKey);
        await EventModel.updateOne(
          { _id: eventId, 'roles._id': role._id || role.role_id },
          { $set: { 'roles.$.confirmed_user_ids': confirmedUserIds, updatedAt: new Date() } }
        );
      }

      // Also add user to accepted_staff array so they appear in "My Events"
      const acceptedStaff = event.accepted_staff || [];
      const existingStaffMember = acceptedStaff.find((s: any) => s.userKey === userKey);

      if (!existingStaffMember) {
        // Add new staff member to accepted_staff
        const newStaffMember = {
          userKey,
          provider,
          subject: sub,
          email: (req as AuthenticatedRequest).authUser.email,
          name: name || '',
          picture: (req as AuthenticatedRequest).authUser.picture,
          role: role.role_name || role.role,
          response: 'accept',
          respondedAt: new Date()
        };

        console.log('[ACCEPT DEBUG] Adding to accepted_staff:', newStaffMember);
        console.log('[ACCEPT DEBUG] Event ID:', eventId);
        const updateResult = await EventModel.updateOne(
          { _id: eventId },
          { $push: { accepted_staff: newStaffMember }, $set: { updatedAt: new Date() } }
        );
        console.log('[ACCEPT DEBUG] Update result:', updateResult);
      } else {
        console.log('[ACCEPT DEBUG] User already in accepted_staff');
      }

      updatedEvent = await EventModel.findById(eventId).lean();
    }

    // Update the message metadata
    const respondedAt = new Date();
    const updatedMessage = await ChatMessageModel.findByIdAndUpdate(
      messageId,
      {
        $set: {
          'metadata.status': accept ? 'accepted' : 'declined',
          'metadata.respondedAt': respondedAt
        }
      },
      { new: true }
    );

    // Emit socket event to manager
    const responsePayload = {
      messageId: messageId,
      conversationId: message.conversationId.toString(),
      status: accept ? 'accepted' : 'declined',
      respondedAt: respondedAt.toISOString(),
      userId: userKey,
      userName: name,
      eventId,
      roleId
    };

    emitToManager(message.managerId.toString(), 'invitation:responded', responsePayload);

    console.log('[INVITATION] Response successful - status:', accept ? 'accepted' : 'declined');

    const response: any = {
      success: true,
      message: accept ? 'Invitation accepted' : 'Invitation declined',
      updatedMessage: {
        id: (updatedMessage as any)._id.toString(),
        metadata: (updatedMessage as any).metadata
      }
    };

    if (updatedEvent) {
      response.updatedEvent = updatedEvent;
    }

    return res.json(response);

  } catch (error) {
    console.error('Error responding to invitation:', error);
    return res.status(500).json({ error: 'Failed to respond to invitation' });
  }
});

/**
 * GET /chat/invitations/:messageId/event
 * Fetch event details for an invitation message
 * This bypasses normal event visibility rules since having the invitation IS permission to view
 */
router.get('/invitations/:messageId/event', requireAuth, async (req, res) => {
  try {
    const { messageId } = req.params;
    const { provider, sub } = (req as AuthenticatedRequest).authUser;
    const userKey = `${provider}:${sub}`;

    console.log('[INVITATION EVENT] Fetch event for messageId:', messageId);

    // Validate messageId
    if (!messageId || !mongoose.Types.ObjectId.isValid(messageId)) {
      return res.status(400).json({ error: 'Invalid message ID' });
    }

    // Find the message
    const message = await ChatMessageModel.findById(messageId);
    if (!message) {
      return res.status(404).json({ error: 'Message not found' });
    }

    // Verify user has access to this message
    if (message.userKey !== userKey) {
      return res.status(403).json({ error: 'Access denied' });
    }

    // Verify it's an invitation
    if (message.messageType !== 'eventInvitation') {
      return res.status(400).json({ error: 'Message is not an event invitation' });
    }

    // Get event ID from metadata
    const eventId = message.metadata?.eventId;
    if (!eventId) {
      return res.status(400).json({ error: 'No event ID in invitation' });
    }

    // Fetch the event directly (bypass visibility checks since user has invitation)
    const { EventModel } = await import('../models/event');
    const event = await EventModel.findById(eventId).lean();

    if (!event) {
      return res.status(404).json({ error: 'Event not found' });
    }

    console.log('[INVITATION EVENT] Found event:', (event as any).event_name || (event as any).title);

    // Return event data in same format as /events endpoint
    return res.json({
      id: String(event._id),
      ...event,
    });

  } catch (error) {
    console.error('Error fetching invitation event:', error);
    return res.status(500).json({ error: 'Failed to fetch event details' });
  }
});

export default router;
