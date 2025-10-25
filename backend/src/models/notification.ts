import mongoose, { Document, Model, Schema } from 'mongoose';

export interface NotificationDocument extends Document {
  userId: mongoose.Types.ObjectId;
  userType: 'user' | 'manager';
  type: 'chat' | 'task' | 'event' | 'hours' | 'system' | 'marketing';
  title: string;
  body: string;
  data?: Record<string, any>;

  // OneSignal tracking
  oneSignalNotificationId?: string;
  oneSignalResponse?: Record<string, any>;

  // Status tracking
  status: 'pending' | 'sent' | 'failed' | 'delivered' | 'clicked';
  sentAt?: Date;
  deliveredAt?: Date;
  clickedAt?: Date;
  readAt?: Date;

  // Error tracking
  error?: string;
  retryCount: number;

  createdAt: Date;
  updatedAt: Date;
}

const NotificationSchema = new Schema<NotificationDocument>(
  {
    userId: {
      type: Schema.Types.ObjectId,
      required: true,
      refPath: 'userType'
    },
    userType: {
      type: String,
      required: true,
      enum: ['user', 'manager']
    },
    type: {
      type: String,
      required: true,
      enum: ['chat', 'task', 'event', 'hours', 'system', 'marketing']
    },
    title: {
      type: String,
      required: true,
      maxlength: 100
    },
    body: {
      type: String,
      required: true,
      maxlength: 500
    },
    data: {
      type: Schema.Types.Mixed
    },

    // OneSignal tracking
    oneSignalNotificationId: {
      type: String,
      sparse: true
    },
    oneSignalResponse: {
      type: Schema.Types.Mixed
    },

    // Status tracking
    status: {
      type: String,
      required: true,
      enum: ['pending', 'sent', 'failed', 'delivered', 'clicked'],
      default: 'pending'
    },
    sentAt: Date,
    deliveredAt: Date,
    clickedAt: Date,
    readAt: Date,

    // Error tracking
    error: String,
    retryCount: {
      type: Number,
      default: 0
    },
  },
  { timestamps: true }
);

// Indexes for efficient querying
NotificationSchema.index({ userId: 1, createdAt: -1 });
NotificationSchema.index({ userId: 1, status: 1 });
NotificationSchema.index({ userId: 1, readAt: 1 });
NotificationSchema.index({ oneSignalNotificationId: 1 }, { sparse: true });
NotificationSchema.index({ createdAt: 1 }, { expireAfterSeconds: 2592000 }); // Auto-delete after 30 days

export const NotificationModel: Model<NotificationDocument> =
  mongoose.models.Notification || mongoose.model<NotificationDocument>('Notification', NotificationSchema);