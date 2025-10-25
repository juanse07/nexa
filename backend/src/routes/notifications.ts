import express, { Request, Response } from 'express';
import { z } from 'zod';
import { requireAuth as authenticateToken } from '../middleware/requireAuth';
import { notificationService, NotificationType } from '../services/notificationService';

const router = express.Router();

// Validation schemas
const RegisterDeviceSchema = z.object({
  oneSignalPlayerId: z.string().min(1),
  deviceType: z.enum(['ios', 'android', 'web']),
});

const UpdatePreferencesSchema = z.object({
  chat: z.boolean().optional(),
  tasks: z.boolean().optional(),
  events: z.boolean().optional(),
  hoursApproval: z.boolean().optional(),
  system: z.boolean().optional(),
  marketing: z.boolean().optional(),
});

const MarkReadSchema = z.object({
  notificationId: z.string().min(1),
});

const TestNotificationSchema = z.object({
  title: z.string().optional(),
  body: z.string().optional(),
  type: z.enum(['chat', 'task', 'event', 'hours', 'system', 'marketing']).optional(),
});

/**
 * @route POST /api/notifications/register-device
 * @desc Register or update a device for push notifications
 */
router.post('/register-device', authenticateToken, async (req: Request, res: Response) => {
  try {
    const authUser = (req as any).authUser;

    // Determine user ID and type based on JWT content
    const userId = authUser.managerId || authUser.userId || authUser.id;
    const userType: 'user' | 'manager' = authUser.managerId ? 'manager' : 'user';

    if (!userId) {
      return res.status(400).json({
        error: 'User ID not found',
        hint: 'JWT token must contain either managerId or userId',
      });
    }

    const validation = RegisterDeviceSchema.safeParse(req.body);

    if (!validation.success) {
      return res.status(400).json({
        error: 'Invalid request data',
        details: validation.error.issues,
      });
    }

    const { oneSignalPlayerId, deviceType } = validation.data;

    const success = await notificationService.registerDevice(
      userId,
      oneSignalPlayerId,
      deviceType,
      userType
    );

    if (success) {
      res.json({
        message: 'Device registered successfully',
        userId,
        deviceType,
      });
    } else {
      res.status(500).json({ error: 'Failed to register device' });
    }
  } catch (error) {
    console.error('Register device error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

/**
 * @route DELETE /api/notifications/unregister-device
 * @desc Unregister a device (on logout)
 */
router.delete('/unregister-device', authenticateToken, async (req: Request, res: Response) => {
  try {
    const authUser = (req as any).authUser;
    const { oneSignalPlayerId } = req.body;

    if (!oneSignalPlayerId) {
      return res.status(400).json({ error: 'OneSignal Player ID required' });
    }

    const success = await notificationService.unregisterDevice(
      authUser.id,
      oneSignalPlayerId,
      authUser.role
    );

    if (success) {
      res.json({ message: 'Device unregistered successfully' });
    } else {
      res.status(500).json({ error: 'Failed to unregister device' });
    }
  } catch (error) {
    console.error('Unregister device error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

/**
 * @route GET /api/notifications/history
 * @desc Get notification history for the authenticated user
 */
router.get('/history', authenticateToken, async (req: Request, res: Response) => {
  try {
    const authUser = (req as any).authUser;
    const limit = parseInt(req.query.limit as string) || 50;
    const offset = parseInt(req.query.offset as string) || 0;

    const notifications = await notificationService.getUserNotifications(
      authUser.id,
      limit,
      offset
    );

    res.json({
      notifications,
      pagination: {
        limit,
        offset,
        total: notifications.length,
      },
    });
  } catch (error) {
    console.error('Get notification history error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

/**
 * @route PATCH /api/notifications/preferences
 * @desc Update notification preferences
 */
router.patch('/preferences', authenticateToken, async (req: Request, res: Response) => {
  try {
    const authUser = (req as any).authUser;
    const validation = UpdatePreferencesSchema.safeParse(req.body);

    if (!validation.success) {
      return res.status(400).json({
        error: 'Invalid preferences data',
        details: validation.error.issues,
      });
    }

    const success = await notificationService.updatePreferences(
      authUser.id,
      validation.data as any,
      authUser.role
    );

    if (success) {
      res.json({
        message: 'Preferences updated successfully',
        preferences: validation.data,
      });
    } else {
      res.status(500).json({ error: 'Failed to update preferences' });
    }
  } catch (error) {
    console.error('Update preferences error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

/**
 * @route POST /api/notifications/mark-read
 * @desc Mark a notification as read
 */
router.post('/mark-read', authenticateToken, async (req: Request, res: Response) => {
  try {
    const authUser = (req as any).authUser;
    const validation = MarkReadSchema.safeParse(req.body);

    if (!validation.success) {
      return res.status(400).json({
        error: 'Invalid request data',
        details: validation.error.issues,
      });
    }

    const { notificationId } = validation.data;

    const success = await notificationService.markAsRead(
      notificationId,
      authUser.id
    );

    if (success) {
      res.json({ message: 'Notification marked as read' });
    } else {
      res.status(404).json({ error: 'Notification not found' });
    }
  } catch (error) {
    console.error('Mark as read error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

/**
 * @route POST /api/notifications/mark-all-read
 * @desc Mark all notifications as read for the user
 */
router.post('/mark-all-read', authenticateToken, async (req: Request, res: Response) => {
  try {
    const authUser = (req as any).authUser;

    // Get all unread notifications
    const notifications = await notificationService.getUserNotifications(authUser.id, 100, 0);
    const unreadNotifications = notifications.filter(n => !n.readAt);

    // Mark each as read
    await Promise.all(
      unreadNotifications.map(n =>
        notificationService.markAsRead((n._id as any).toString(), authUser.id)
      )
    );

    res.json({
      message: 'All notifications marked as read',
      count: unreadNotifications.length,
    });
  } catch (error) {
    console.error('Mark all as read error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

/**
 * @route GET /api/notifications/unread-count
 * @desc Get count of unread notifications
 */
router.get('/unread-count', authenticateToken, async (req: Request, res: Response) => {
  try {
    const authUser = (req as any).authUser;
    const count = await notificationService.getUnreadCount(authUser.id);

    res.json({ count });
  } catch (error) {
    console.error('Get unread count error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

/**
 * @route POST /api/notifications/test
 * @desc Send a test notification to the authenticated user (for testing)
 */
router.post('/test', authenticateToken, async (req: Request, res: Response) => {
  try {
    const authUser = (req as any).authUser;

    // Determine user ID and type based on JWT content
    // Managers have 'managerId' field, regular users would have 'userId'
    const userId = authUser.managerId || authUser.userId || authUser.id;
    const userType: 'user' | 'manager' = authUser.managerId ? 'manager' : 'user';

    console.log('[TEST NOTIF] Received test notification request');
    console.log('[TEST NOTIF] Auth user:', { userId, userType, provider: authUser.provider, email: authUser.email });
    console.log('[TEST NOTIF] Request body:', JSON.stringify(req.body));

    if (!userId) {
      return res.status(400).json({
        error: 'User ID not found',
        hint: 'JWT token must contain either managerId or userId',
      });
    }

    const validation = TestNotificationSchema.safeParse(req.body);

    const data = validation.success ? validation.data : {};

    const title = data.title || '🔔 Test Notification';
    const body = data.body || 'This is a test notification from Nexa!';
    const type = data.type || 'system';

    console.log('[TEST NOTIF] Sending notification with:', { title, body, type, userId, userType });

    const notification = await notificationService.sendToUser(
      userId,
      title,
      body,
      { type, test: true },
      userType
    );

    console.log('[TEST NOTIF] Notification service returned:', notification ? 'success' : 'null');

    if (notification) {
      res.json({
        message: 'Test notification sent successfully',
        notification: {
          id: (notification._id as any),
          title,
          body,
          type,
        },
      });
    } else {
      console.log('[TEST NOTIF] Returning 500 error - notification service returned null');
      res.status(500).json({
        error: 'Failed to send test notification',
        hint: 'Make sure you have registered a device and enabled notifications',
      });
    }
  } catch (error) {
    console.error('[TEST NOTIF] Exception occurred:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

/**
 * @route POST /api/notifications/webhook/onesignal
 * @desc Webhook endpoint for OneSignal delivery/click events
 */
router.post('/webhook/onesignal', async (req: Request, res: Response) => {
  try {
    const { event, notificationId } = req.body;

    if (event && notificationId) {
      await notificationService.handleDeliveryWebhook(
        notificationId,
        event as 'delivered' | 'clicked'
      );
    }

    res.json({ received: true });
  } catch (error) {
    console.error('OneSignal webhook error:', error);
    res.status(500).json({ error: 'Webhook processing failed' });
  }
});

export default router;