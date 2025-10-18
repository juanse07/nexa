import { Router } from 'express';
import { requireAuth, AuthenticatedRequest } from '../middleware/auth';
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
router.get('/conversations', requireAuth, async (req: AuthenticatedRequest, res) => {
  try {
    const { managerId, provider, sub } = req.authUser;
    const userKey = `${provider}:${sub}`;

    let conversations;

    if (managerId) {
      // Manager: get all conversations with users
      conversations = await ConversationModel.find({ managerId })
        .sort({ lastMessageAt: -1 })
        .lean();

      // Populate user info
      const userKeys = conversations.map(c => c.userKey);
      const users = await UserModel.find({
        $expr: {
          $eq: [
            { $concat: ['$provider', ':', '$subject'] },
            { $in: userKeys }
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

      const result = conversations.map(conv => ({
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
      }));

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
router.get('/conversations/:conversationId/messages', requireAuth, async (req: AuthenticatedRequest, res) => {
  try {
    const { conversationId } = req.params;
    const { managerId, provider, sub } = req.authUser;
    const userKey = `${provider}:${sub}`;
    const limit = parseInt(req.query.limit as string) || 50;
    const before = req.query.before as string; // ISO date string for pagination

    if (!mongoose.Types.ObjectId.isValid(conversationId)) {
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
router.post('/conversations/:targetId/messages', requireAuth, async (req: AuthenticatedRequest, res) => {
  try {
    const { targetId } = req.params;
    const { message } = req.body;
    const { managerId, provider, sub, name, picture } = req.authUser;
    const userKey = `${provider}:${sub}`;

    if (!message || typeof message !== 'string' || message.trim().length === 0) {
      return res.status(400).json({ error: 'Message is required' });
    }

    if (message.trim().length > 5000) {
      return res.status(400).json({ error: 'Message is too long (max 5000 characters)' });
    }

    let conversation;
    let targetManagerId: mongoose.Types.ObjectId | null = null;
    let targetUserKey: string | null = null;
    let senderType: 'manager' | 'user';

    if (managerId) {
      // Manager sending to user
      senderType = 'manager';
      targetUserKey = targetId;

      // Verify user exists
      const [provider, subject] = targetUserKey.split(':');
      const user = await UserModel.findOne({ provider, subject });
      if (!user) {
        return res.status(404).json({ error: 'User not found' });
      }

      // Find or create conversation
      conversation = await ConversationModel.findOneAndUpdate(
        { managerId: new mongoose.Types.ObjectId(managerId), userKey: targetUserKey },
        {
          $setOnInsert: {
            managerId: new mongoose.Types.ObjectId(managerId),
            userKey: targetUserKey,
          }
        },
        { upsert: true, new: true }
      );

      targetManagerId = new mongoose.Types.ObjectId(managerId);
    } else {
      // User sending to manager
      senderType = 'user';

      if (!mongoose.Types.ObjectId.isValid(targetId)) {
        return res.status(400).json({ error: 'Invalid manager ID' });
      }

      targetManagerId = new mongoose.Types.ObjectId(targetId);

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
      id: chatMessage._id.toString(),
      conversationId: conversation._id.toString(),
      senderType: chatMessage.senderType,
      senderName: chatMessage.senderName,
      senderPicture: chatMessage.senderPicture,
      message: chatMessage.message,
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
router.patch('/conversations/:conversationId/read', requireAuth, async (req: AuthenticatedRequest, res) => {
  try {
    const { conversationId } = req.params;
    const { managerId, provider, sub } = req.authUser;
    const userKey = `${provider}:${sub}`;

    if (!mongoose.Types.ObjectId.isValid(conversationId)) {
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
router.get('/managers', requireAuth, async (req: AuthenticatedRequest, res) => {
  try {
    const { managerId, provider, sub } = req.authUser;

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

export default router;
