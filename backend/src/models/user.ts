import mongoose, { Document, Model, Schema } from 'mongoose';

export interface UserDocument extends Document {
  provider: 'google' | 'apple';
  subject: string;
  email?: string;
  name?: string; // original OAuth full name
  first_name?: string;
  last_name?: string;
  phone_number?: string;
  picture?: string; // optional override picture
  app_id?: string; // optional 9-digit app id

  // User preferences
  eventTerminology?: 'shift' | 'job' | 'event'; // How user prefers to call events in notifications

  // OneSignal fields
  oneSignalUserId?: string;
  notificationPreferences?: {
    chat: boolean;
    tasks: boolean;
    events: boolean;
    hoursApproval: boolean;
    system: boolean;
    marketing: boolean;
  };
  devices?: Array<{
    oneSignalPlayerId: string;
    deviceType: 'ios' | 'android' | 'web';
    lastActive: Date;
  }>;

  // Subscription fields
  subscription_tier?: 'free' | 'pro';
  subscription_status?: 'active' | 'trial' | 'expired' | 'cancelled' | 'grace_period';
  subscription_platform?: 'ios' | 'android' | 'web' | null;
  qonversion_user_id?: string;
  subscription_started_at?: Date;
  subscription_expires_at?: Date;
  ai_messages_used_this_month?: number;
  ai_messages_reset_date?: Date;

  createdAt: Date;
  updatedAt: Date;
}

const UserSchema = new Schema<UserDocument>(
  {
    provider: { type: String, required: true, enum: ['google', 'apple'] },
    subject: { type: String, required: true },
    email: { type: String, trim: true },
    name: { type: String, trim: true },
    first_name: { type: String, trim: true },
    last_name: { type: String, trim: true },
    phone_number: { type: String, trim: true },
    picture: { type: String, trim: true },
    app_id: { type: String, trim: true },

    // User preferences
    eventTerminology: { type: String, enum: ['shift', 'job', 'event'], default: 'shift' },

    // OneSignal fields
    oneSignalUserId: { type: String, sparse: true },
    notificationPreferences: {
      chat: { type: Boolean, default: true },
      tasks: { type: Boolean, default: true },
      events: { type: Boolean, default: true },
      hoursApproval: { type: Boolean, default: true },
      system: { type: Boolean, default: true },
      marketing: { type: Boolean, default: false },
    },
    devices: [{
      oneSignalPlayerId: { type: String, required: true },
      deviceType: { type: String, enum: ['ios', 'android', 'web'], required: true },
      lastActive: { type: Date, default: Date.now },
    }],

    // Subscription fields
    subscription_tier: { type: String, enum: ['free', 'pro'], default: 'free' },
    subscription_status: {
      type: String,
      enum: ['active', 'trial', 'expired', 'cancelled', 'grace_period'],
      default: 'active'
    },
    subscription_platform: {
      type: String,
      enum: ['ios', 'android', 'web', null],
      default: null
    },
    qonversion_user_id: { type: String, sparse: true },
    subscription_started_at: { type: Date, default: null },
    subscription_expires_at: { type: Date, default: null },
    ai_messages_used_this_month: { type: Number, default: 0 },
    ai_messages_reset_date: {
      type: Date,
      default: function() {
        const date = new Date();
        date.setMonth(date.getMonth() + 1);
        date.setDate(1);
        date.setHours(0, 0, 0, 0);
        return date;
      }
    },
  },
  { timestamps: true }
);

UserSchema.index({ provider: 1, subject: 1 }, { unique: true });
UserSchema.index({ app_id: 1 }, { unique: false, sparse: true });
UserSchema.index({ qonversion_user_id: 1 }, { unique: false, sparse: true });

export const UserModel: Model<UserDocument> =
  mongoose.models.User || mongoose.model<UserDocument>('User', UserSchema);


