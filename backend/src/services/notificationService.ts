import * as OneSignal from '@onesignal/node-onesignal';
import { UserDocument, UserModel } from '../models/user';
import { ManagerDocument, ManagerModel } from '../models/manager';
import { NotificationDocument, NotificationModel } from '../models/notification';
import mongoose from 'mongoose';

// OneSignal configuration for Manager app
const ONESIGNAL_APP_ID_MANAGER = process.env.ONESIGNAL_APP_ID || '';
const ONESIGNAL_REST_API_KEY_MANAGER = process.env.ONESIGNAL_REST_API_KEY || '';

// OneSignal configuration for Staff app
const ONESIGNAL_APP_ID_STAFF = process.env.ONESIGNAL_APP_ID2 || '';
const ONESIGNAL_REST_API_KEY_STAFF = process.env.ONESIGNAL_REST_API_KEY2 || '';

// Initialize OneSignal client for Manager app
const managerConfiguration = OneSignal.createConfiguration({
  restApiKey: ONESIGNAL_REST_API_KEY_MANAGER,
});
const managerClient = new OneSignal.DefaultApi(managerConfiguration);

// Initialize OneSignal client for Staff app
const staffConfiguration = OneSignal.createConfiguration({
  restApiKey: ONESIGNAL_REST_API_KEY_STAFF,
});
const staffClient = new OneSignal.DefaultApi(staffConfiguration);

export type NotificationType = 'chat' | 'task' | 'event' | 'hours' | 'system' | 'marketing';

interface NotificationData {
  type: NotificationType;
  conversationId?: string;
  messageId?: string;
  taskId?: string;
  eventId?: string;
  timesheetId?: string;
  [key: string]: any;
}

class NotificationService {
  /**
   * Initialize OneSignal configuration
   */
  async initialize(): Promise<void> {
    const managerConfigured = ONESIGNAL_APP_ID_MANAGER && ONESIGNAL_REST_API_KEY_MANAGER;
    const staffConfigured = ONESIGNAL_APP_ID_STAFF && ONESIGNAL_REST_API_KEY_STAFF;

    if (!managerConfigured && !staffConfigured) {
      console.warn('⚠️  OneSignal credentials not configured. Push notifications disabled.');
      return;
    }

    if (managerConfigured) {
      console.log('✅ OneSignal Manager App initialized:', ONESIGNAL_APP_ID_MANAGER.substring(0, 8) + '...');
    }
    if (staffConfigured) {
      console.log('✅ OneSignal Staff App initialized:', ONESIGNAL_APP_ID_STAFF.substring(0, 8) + '...');
    }
  }

  /**
   * Send notification to a specific user
   * @param accentColor - Optional hex color (without #) for Android notification accent (e.g., "A855F7" for purple)
   */
  async sendToUser(
    userId: string,
    title: string,
    body: string,
    data: NotificationData,
    userType: 'user' | 'manager' = 'user',
    accentColor?: string
  ): Promise<NotificationDocument | null> {
    try {
      console.log(`[NOTIF DEBUG] Starting sendToUser: userId=${userId}, userType=${userType}, title=${title}`);

      // Find user and check preferences
      let user: UserDocument | ManagerDocument | null;

      if (userType === 'manager') {
        user = await ManagerModel.findById(userId);
      } else {
        user = await UserModel.findById(userId);
      }

      if (!user) {
        console.error(`[NOTIF DEBUG] User not found: ${userId}`);
        return null;
      }

      console.log(`[NOTIF DEBUG] User found: ${userId}, devices: ${user.devices?.length || 0}`);

      // Check notification preferences
      if (!this.shouldSendNotification(user, data.type)) {
        console.log(`[NOTIF DEBUG] Notification blocked by user preferences: ${userId}, type: ${data.type}`);
        return null;
      }

      console.log(`[NOTIF DEBUG] Notification preferences OK for type: ${data.type}`);

      // Create notification record
      const notificationDoc = await NotificationModel.create({
        userId: new mongoose.Types.ObjectId(userId),
        userType,
        type: data.type,
        title,
        body,
        data,
        status: 'pending',
      });

      console.log(`[NOTIF DEBUG] Notification record created: ${notificationDoc._id}`);

      // Skip if no devices registered
      if (!user.devices || user.devices.length === 0) {
        console.log(`[NOTIF DEBUG] No devices registered for user: ${userId}`);
        await this.updateNotificationStatus(notificationDoc._id as string, 'failed', 'No devices registered');
        return notificationDoc;
      }

      // Select the correct OneSignal client and app ID based on user type
      const client = userType === 'manager' ? managerClient : staffClient;
      const appId = userType === 'manager' ? ONESIGNAL_APP_ID_MANAGER : ONESIGNAL_APP_ID_STAFF;
      const apiKey = userType === 'manager' ? ONESIGNAL_REST_API_KEY_MANAGER : ONESIGNAL_REST_API_KEY_STAFF;

      console.log(`[NOTIF DEBUG] Using ${userType} OneSignal, appId: ${appId.substring(0, 8)}..., apiKey ending: ...${apiKey.slice(-4)}`);

      // Target using external user ID (OneSignal v5 recommended approach)
      // We set the external user ID when registering: OneSignal.login(userId)
      console.log(`[NOTIF DEBUG] Targeting user by external ID: ${userId}`);

      // Use external_id to target the user (all their devices)
      const notificationPayload: any = {
        app_id: appId,
        include_aliases: {
          external_id: [userId]
        },
        target_channel: 'push',
        contents: { en: body },
        headings: { en: title },
        data: {
          ...data,
          notificationId: (notificationDoc._id as any).toString(),
        },
        ios_sound: 'notification.wav',
        android_sound: 'notification',
        ios_badgeType: 'Increase',
        ios_badgeCount: 1,
      };

      // Add Android accent color if provided (for visual differentiation)
      if (accentColor) {
        notificationPayload.android_accent_color = accentColor;
      }

      console.log(`[NOTIF DEBUG] Sending notification to OneSignal REST API...`);

      // Make direct REST API call
      const response = await fetch('https://onesignal.com/api/v1/notifications', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Basic ${apiKey}`,
        },
        body: JSON.stringify(notificationPayload),
      });

      const responseData = await response.json();
      console.log(`[NOTIF DEBUG] OneSignal API response status: ${response.status}, body:`, JSON.stringify(responseData));

      if (!response.ok) {
        throw new Error(`OneSignal API error: ${response.status} - ${JSON.stringify(responseData)}`);
      }

      // Update notification record
      await this.updateNotificationStatus(
        notificationDoc._id as string,
        'sent',
        undefined,
        responseData.id
      );

      console.log(`✅ Notification sent to ${userId}: ${responseData.id}`);
      return notificationDoc;

    } catch (error) {
      console.error('[NOTIF DEBUG] Failed to send notification - ERROR:', error);
      if (error instanceof Error) {
        console.error('[NOTIF DEBUG] Error stack:', error.stack);
      }
      return null;
    }
  }

  /**
   * Send notification to multiple users
   */
  async sendToMultipleUsers(
    userIds: string[],
    title: string,
    body: string,
    data: NotificationData,
    userType: 'user' | 'manager' = 'user',
    accentColor?: string
  ): Promise<NotificationDocument[]> {
    const results = await Promise.all(
      userIds.map(userId => this.sendToUser(userId, title, body, data, userType, accentColor))
    );
    return results.filter(r => r !== null) as NotificationDocument[];
  }

  /**
   * Send notification to a segment
   */
  async sendToSegment(
    segment: string,
    title: string,
    body: string,
    data: NotificationData,
    appType: 'manager' | 'staff' = 'manager'
  ): Promise<string | null> {
    try {
      const client = appType === 'manager' ? managerClient : staffClient;
      const appId = appType === 'manager' ? ONESIGNAL_APP_ID_MANAGER : ONESIGNAL_APP_ID_STAFF;

      const notification = new OneSignal.Notification();
      notification.app_id = appId;

      notification.contents = { en: body };
      notification.headings = { en: title };
      notification.included_segments = [segment];
      notification.data = data;

      const response = await client.createNotification(notification);
      console.log(`✅ Segment notification sent to ${segment} on ${appType} app: ${response.id}`);
      return response.id || null;

    } catch (error) {
      console.error('Failed to send segment notification:', error);
      return null;
    }
  }

  /**
   * Register or update device token
   */
  async registerDevice(
    userId: string,
    oneSignalPlayerId: string,
    deviceType: 'ios' | 'android' | 'web',
    userType: 'user' | 'manager' = 'user'
  ): Promise<boolean> {
    try {
      // Remove this device from other users (user switched accounts)
      if (userType === 'manager') {
        await ManagerModel.updateMany(
          { 'devices.oneSignalPlayerId': oneSignalPlayerId },
          { $pull: { devices: { oneSignalPlayerId } } }
        );
      } else {
        await UserModel.updateMany(
          { 'devices.oneSignalPlayerId': oneSignalPlayerId },
          { $pull: { devices: { oneSignalPlayerId } } }
        );
      }

      // Add/update device for this user
      let user: UserDocument | ManagerDocument | null;

      if (userType === 'manager') {
        user = await ManagerModel.findById(userId);
      } else {
        user = await UserModel.findById(userId);
      }

      if (!user) return false;

      // Check if device already exists
      const existingDeviceIndex = user.devices?.findIndex(
        (d: any) => d.oneSignalPlayerId === oneSignalPlayerId
      ) ?? -1;

      if (existingDeviceIndex >= 0 && user.devices) {
        // Update existing device
        const device = user.devices[existingDeviceIndex];
        if (device) {
          device.lastActive = new Date();
          device.deviceType = deviceType;
        }
      } else {
        // Add new device
        if (!user.devices) user.devices = [];
        user.devices.push({
          oneSignalPlayerId,
          deviceType,
          lastActive: new Date(),
        });
      }

      // Set OneSignal external user ID if not set
      if (!user.oneSignalUserId) {
        user.oneSignalUserId = userId;
      }

      await user.save();
      console.log(`✅ Device registered for ${userType} ${userId}, total devices now: ${user.devices?.length || 0}`);

      // Verify the save worked by re-fetching
      const verification = userType === 'manager'
        ? await ManagerModel.findById(userId)
        : await UserModel.findById(userId);
      console.log(`[REG VERIFY] After save, devices in DB: ${verification?.devices?.length || 0}`);

      return true;

    } catch (error) {
      console.error('Failed to register device:', error);
      return false;
    }
  }

  /**
   * Unregister device (on logout)
   */
  async unregisterDevice(
    userId: string,
    oneSignalPlayerId: string,
    userType: 'user' | 'manager' = 'user'
  ): Promise<boolean> {
    try {
      if (userType === 'manager') {
        await ManagerModel.findByIdAndUpdate(userId, {
          $pull: { devices: { oneSignalPlayerId } }
        });
      } else {
        await UserModel.findByIdAndUpdate(userId, {
          $pull: { devices: { oneSignalPlayerId } }
        });
      }

      console.log(`✅ Device unregistered for ${userType} ${userId}`);
      return true;

    } catch (error) {
      console.error('Failed to unregister device:', error);
      return false;
    }
  }

  /**
   * Clear all devices for a user (for troubleshooting)
   */
  async clearAllDevices(
    userId: string,
    userType: 'user' | 'manager' = 'user'
  ): Promise<boolean> {
    try {
      if (userType === 'manager') {
        await ManagerModel.findByIdAndUpdate(userId, {
          $set: { devices: [] }
        });
      } else {
        await UserModel.findByIdAndUpdate(userId, {
          $set: { devices: [] }
        });
      }

      console.log(`✅ All devices cleared for ${userType} ${userId}`);
      return true;

    } catch (error) {
      console.error('Failed to clear devices:', error);
      return false;
    }
  }

  /**
   * Update notification preferences
   */
  async updatePreferences(
    userId: string,
    preferences: Partial<Record<NotificationType | 'marketing', boolean>>,
    userType: 'user' | 'manager' = 'user'
  ): Promise<boolean> {
    try {
      const updateData = {
        $set: Object.keys(preferences).reduce((acc, key) => {
          acc[`notificationPreferences.${key}`] = preferences[key as NotificationType] || false;
          return acc;
        }, {} as Record<string, boolean>)
      };

      if (userType === 'manager') {
        await ManagerModel.findByIdAndUpdate(userId, updateData);
      } else {
        await UserModel.findByIdAndUpdate(userId, updateData);
      }

      console.log(`✅ Preferences updated for ${userType} ${userId}`);
      return true;

    } catch (error) {
      console.error('Failed to update preferences:', error);
      return false;
    }
  }

  /**
   * Get notification history for a user
   */
  async getUserNotifications(
    userId: string,
    limit: number = 50,
    offset: number = 0
  ): Promise<NotificationDocument[]> {
    return NotificationModel
      .find({ userId })
      .sort({ createdAt: -1 })
      .limit(limit)
      .skip(offset)
      .exec();
  }

  /**
   * Mark notification as read
   */
  async markAsRead(notificationId: string, userId: string): Promise<boolean> {
    try {
      const result = await NotificationModel.findOneAndUpdate(
        { _id: notificationId, userId },
        {
          readAt: new Date(),
          $set: { status: 'clicked' }
        }
      );
      return result !== null;
    } catch (error) {
      console.error('Failed to mark as read:', error);
      return false;
    }
  }

  /**
   * Get unread notification count
   */
  async getUnreadCount(userId: string): Promise<number> {
    return NotificationModel.countDocuments({
      userId,
      readAt: { $exists: false }
    });
  }

  /**
   * Handle notification delivery webhook from OneSignal
   */
  async handleDeliveryWebhook(
    oneSignalNotificationId: string,
    event: 'delivered' | 'clicked'
  ): Promise<void> {
    try {
      const update = event === 'delivered'
        ? { deliveredAt: new Date(), status: 'delivered' }
        : { clickedAt: new Date(), status: 'clicked' };

      await NotificationModel.findOneAndUpdate(
        { oneSignalNotificationId },
        update
      );
    } catch (error) {
      console.error('Failed to handle delivery webhook:', error);
    }
  }

  // Private helper methods

  private shouldSendNotification(
    user: UserDocument | ManagerDocument,
    type: NotificationType
  ): boolean {
    if (!user.notificationPreferences) return true; // Default to sending

    const prefs = user.notificationPreferences;
    switch (type) {
      case 'chat': return prefs.chat ?? true;
      case 'task': return prefs.tasks ?? true;
      case 'event': return prefs.events ?? true;
      case 'hours': return prefs.hoursApproval ?? true;
      case 'system': return prefs.system ?? true;
      case 'marketing': return prefs.marketing ?? false;
      default: return true;
    }
  }

  private async updateNotificationStatus(
    notificationId: string,
    status: 'pending' | 'sent' | 'failed' | 'delivered' | 'clicked',
    error?: string,
    oneSignalNotificationId?: string
  ): Promise<void> {
    const update: any = { status };

    if (status === 'sent') update.sentAt = new Date();
    if (error) update.error = error;
    if (oneSignalNotificationId) update.oneSignalNotificationId = oneSignalNotificationId;

    await NotificationModel.findByIdAndUpdate(notificationId, update);
  }
}

// Export singleton instance
export const notificationService = new NotificationService();

// Initialize on module load
notificationService.initialize().catch(console.error);