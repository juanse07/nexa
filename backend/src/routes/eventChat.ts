import express, { Request, Response } from 'express';
import mongoose from 'mongoose';
import { EventModel } from '../models/event';
import { EventChatMessageModel } from '../models/eventChatMessage';
import { UserModel } from '../models/user';
import { ManagerModel } from '../models/manager';
import { requireAuth } from '../middleware/requireAuth';
import { emitToEventChat } from '../socket/server';
import { notificationService } from '../services/notificationService';

const router = express.Router();

/**
 * GET /api/events/:eventId/chat/messages
 * Get chat messages for an event
 */
router.get('/events/:eventId/chat/messages', requireAuth, async (req: Request, res: Response) => {
  try {
    const { eventId } = req.params;
    const limit = parseInt(req.query.limit as string) || 50;
    const before = req.query.before as string; // Pagination cursor (message ID)

    if (!eventId || !mongoose.Types.ObjectId.isValid(eventId)) {
      return res.status(400).json({ message: 'Invalid event ID' });
    }

    // Verify user has access to this event
    const event = await EventModel.findById(eventId).lean();
    if (!event) {
      return res.status(404).json({ message: 'Event not found' });
    }

    const authUser = (req as any).authUser;
    const userKey = `${authUser.provider}:${authUser.sub}`;

    // Check if user is the manager or accepted staff
    const isManager = authUser.managerId && event.managerId.toString() === authUser.managerId;
    const isAcceptedStaff = (event.accepted_staff || []).some(
      (staff: any) => staff.userKey === userKey
    );

    if (!isManager && !isAcceptedStaff) {
      return res.status(403).json({ message: 'Access denied' });
    }

    // Build query
    const query: any = { eventId: new mongoose.Types.ObjectId(eventId) };
    if (before && mongoose.Types.ObjectId.isValid(before)) {
      query._id = { $lt: new mongoose.Types.ObjectId(before) };
    }

    // Get messages
    const messages = await EventChatMessageModel
      .find(query)
      .sort({ createdAt: -1 })
      .limit(limit)
      .lean();

    return res.json({
      messages: messages.reverse(), // Oldest first for display
      hasMore: messages.length === limit,
      chatEnabled: event.chatEnabled || false,
    });

  } catch (error) {
    console.error('[EventChat] Get messages error:', error);
    return res.status(500).json({ message: 'Failed to get messages' });
  }
});

/**
 * POST /api/events/:eventId/chat/messages
 * Send a chat message
 */
router.post('/events/:eventId/chat/messages', requireAuth, async (req: Request, res: Response) => {
  try {
    const { eventId } = req.params;
    const { message } = req.body;

    if (!eventId || !mongoose.Types.ObjectId.isValid(eventId)) {
      return res.status(400).json({ message: 'Invalid event ID' });
    }

    if (!message || typeof message !== 'string' || message.trim().length === 0) {
      return res.status(400).json({ message: 'Message is required' });
    }

    if (message.length > 2000) {
      return res.status(400).json({ message: 'Message too long (max 2000 characters)' });
    }

    // Verify event exists and chat is enabled
    const event = await EventModel.findById(eventId).lean();
    if (!event) {
      return res.status(404).json({ message: 'Event not found' });
    }

    if (!event.chatEnabled) {
      return res.status(403).json({ message: 'Chat is not enabled for this event' });
    }

    const authUser = (req as any).authUser;
    const userKey = `${authUser.provider}:${authUser.sub}`;

    // Check if user is the manager or accepted staff
    const isManager = authUser.managerId && event.managerId.toString() === authUser.managerId;
    const isAcceptedStaff = (event.accepted_staff || []).some(
      (staff: any) => staff.userKey === userKey
    );

    if (!isManager && !isAcceptedStaff) {
      return res.status(403).json({ message: 'Access denied' });
    }

    // Get sender info
    let senderId: string;
    let senderType: 'user' | 'manager';
    let senderName: string;
    let senderAvatar: string | undefined;

    if (isManager && authUser.managerId) {
      const manager = await ManagerModel.findById(authUser.managerId).lean();
      senderId = authUser.managerId;
      senderType = 'manager';
      senderName = manager?.name || 'Manager';
      senderAvatar = manager?.picture;
    } else {
      const user = await UserModel.findOne({
        provider: authUser.provider,
        sub: authUser.sub
      }).lean();

      if (!user) {
        return res.status(404).json({ message: 'User not found' });
      }

      senderId = user._id.toString();
      senderType = 'user';
      senderName = `${user.first_name || ''} ${user.last_name || ''}`.trim() || user.email || 'Staff';
      senderAvatar = user.picture;
    }

    // Create message
    const chatMessage = await EventChatMessageModel.create({
      eventId: new mongoose.Types.ObjectId(eventId),
      senderId: new mongoose.Types.ObjectId(senderId),
      senderType,
      senderName,
      senderAvatar,
      message: message.trim(),
      messageType: 'text',
    });

    console.log(`[EventChat] Message sent in event ${eventId} by ${senderName}`);

    // Broadcast to all clients in the event chat room
    emitToEventChat(eventId, 'event_chat:message', {
      message: chatMessage.toObject(),
    });

    // Send push notifications to all team members (except sender)
    try {
      const acceptedStaff = event.accepted_staff || [];
      const recipientIds: string[] = [];

      // Collect recipient user IDs (staff members)
      for (const staff of acceptedStaff) {
        const staffUserKey = staff.userKey as string;
        if (!staffUserKey) continue;

        const [provider, sub] = staffUserKey.split(':');
        if (!provider || !sub) continue;

        const staffUser = await UserModel.findOne({ provider, sub }).select('_id').lean();
        if (staffUser && staffUser._id.toString() !== senderId) {
          recipientIds.push(staffUser._id.toString());
        }
      }

      // Also notify manager if they're not the sender
      if (senderType !== 'manager') {
        const manager = await ManagerModel.findById(event.managerId).select('_id').lean();
        if (manager) {
          // Send to manager app
          await notificationService.sendToUser(
            manager._id.toString(),
            `💬 ${senderName}`,
            message.trim().substring(0, 100), // Truncate long messages
            {
              type: 'event',
              eventId: eventId,
              messageId: (chatMessage._id as any).toString(),
              action: 'team_chat_message',
              eventName: event.event_name || 'Event',
            },
            'manager',
            '3B82F6' // Blue accent for team chat
          );
        }
      }

      // Send notifications to all staff recipients
      if (recipientIds.length > 0) {
        await notificationService.sendToMultipleUsers(
          recipientIds,
          `💬 ${senderName}`,
          message.trim().substring(0, 100), // Truncate long messages
          {
            type: 'event',
            eventId: eventId,
            messageId: (chatMessage._id as any).toString(),
            action: 'team_chat_message',
            eventName: event.event_name || 'Event',
          },
          'user',
          '3B82F6' // Blue accent for team chat
        );

        console.log(`[EventChat] Sent ${recipientIds.length} push notifications for message ${chatMessage._id}`);
      }
    } catch (notifError) {
      console.error('[EventChat] Failed to send push notifications:', notifError);
      // Don't fail the request if notifications fail
    }

    return res.status(201).json({ message: chatMessage });

  } catch (error) {
    console.error('[EventChat] Send message error:', error);
    return res.status(500).json({ message: 'Failed to send message' });
  }
});

/**
 * PATCH /api/events/:eventId/chat/enable
 * Enable/disable chat for an event (manager only)
 */
router.patch('/events/:eventId/chat/enable', requireAuth, async (req: Request, res: Response) => {
  try {
    const { eventId } = req.params;
    const { enabled } = req.body;

    if (!eventId || !mongoose.Types.ObjectId.isValid(eventId)) {
      return res.status(400).json({ message: 'Invalid event ID' });
    }

    if (typeof enabled !== 'boolean') {
      return res.status(400).json({ message: 'Enabled must be a boolean' });
    }

    const authUser = (req as any).authUser;

    // Verify user is a manager
    if (!authUser.managerId) {
      return res.status(403).json({ message: 'Only managers can enable/disable chat' });
    }

    const managerId = authUser.managerId; // Store for type safety

    // Verify event belongs to this manager
    const event = await EventModel.findOne({
      _id: new mongoose.Types.ObjectId(eventId),
      managerId: new mongoose.Types.ObjectId(managerId)
    });

    if (!event) {
      return res.status(404).json({ message: 'Event not found' });
    }

    // Update chat status
    event.chatEnabled = enabled;
    if (enabled && !event.chatEnabledAt) {
      event.chatEnabledAt = new Date();
    }
    await event.save();

    // Post system message
    if (enabled) {
      const systemMessage = await EventChatMessageModel.create({
        eventId: new mongoose.Types.ObjectId(eventId),
        senderId: new mongoose.Types.ObjectId(managerId),
        senderType: 'manager',
        senderName: 'System',
        message: 'Team chat has been enabled for this event',
        messageType: 'system',
      });

      // Broadcast system message to all clients
      emitToEventChat(eventId, 'event_chat:message', {
        message: systemMessage.toObject(),
      });
    }

    console.log(`[EventChat] Chat ${enabled ? 'enabled' : 'disabled'} for event ${eventId}`);

    return res.json({
      chatEnabled: event.chatEnabled,
      chatEnabledAt: event.chatEnabledAt,
    });

  } catch (error) {
    console.error('[EventChat] Enable chat error:', error);
    return res.status(500).json({ message: 'Failed to update chat status' });
  }
});

export default router;
