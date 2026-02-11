import mongoose, { Document, Model, Schema } from 'mongoose';

export interface UserDocument extends Document {
  provider: 'google' | 'apple' | 'phone';
  subject: string;
  email?: string;
  name?: string; // original OAuth full name
  first_name?: string;
  last_name?: string;
  phone_number?: string; // profile phone (for contact)
  auth_phone_number?: string; // verified phone for authentication (E.164 format)
  picture?: string; // optional override picture
  originalPicture?: string; // pre-caricature picture (for revert)
  app_id?: string; // optional 9-digit app id

  // Caricature history (last 10 creations)
  caricatureHistory?: Array<{
    url: string;
    role: string;
    artStyle: string;
    createdAt: Date;
  }>;

  // Linked authentication methods (for account linking)
  linked_providers?: Array<{
    provider: 'google' | 'apple' | 'phone';
    subject: string;
    linked_at: Date;
  }>;

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
  groq_request_limit?: number;

  // Gamification for punctuality
  gamification?: {
    totalPoints: number;
    currentStreak: number;
    longestStreak: number;
    lastPunctualClockIn?: Date;
    streakStartDate?: Date;
    pointsHistory?: Array<{
      points: number;
      reason: 'on_time_clock_in' | 'early_arrival' | 'streak_bonus' | 'perfect_week';
      eventId: string;
      earnedAt: Date;
    }>;
  };

  // Clock-in preferences
  clockInSettings?: {
    preShiftReminderMinutes?: number; // Default: 30
    autoClockOutBuffer?: number; // Minutes after shift end to auto clock-out
    enableVoiceClockIn?: boolean;
  };

  createdAt: Date;
  updatedAt: Date;
}

const UserSchema = new Schema<UserDocument>(
  {
    provider: { type: String, required: true, enum: ['google', 'apple', 'phone'] },
    subject: { type: String, required: true },
    email: { type: String, trim: true },
    name: { type: String, trim: true },
    first_name: { type: String, trim: true },
    last_name: { type: String, trim: true },
    phone_number: { type: String, trim: true },
    auth_phone_number: { type: String, trim: true }, // E.164 format for phone auth
    picture: { type: String, trim: true },
    originalPicture: { type: String, trim: true }, // pre-caricature picture
    app_id: { type: String, trim: true },

    // Caricature history (last 10 creations)
    caricatureHistory: [{
      url: { type: String, required: true },
      role: { type: String, required: true },
      artStyle: { type: String, required: true },
      createdAt: { type: Date, default: Date.now },
    }],

    // Linked authentication methods
    linked_providers: [{
      provider: { type: String, required: true, enum: ['google', 'apple', 'phone'] },
      subject: { type: String, required: true },
      linked_at: { type: Date, default: Date.now },
    }],

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
    groq_request_limit: { type: Number, default: 3 },
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

    // Gamification for punctuality tracking
    gamification: {
      totalPoints: { type: Number, default: 0 },
      currentStreak: { type: Number, default: 0 },
      longestStreak: { type: Number, default: 0 },
      lastPunctualClockIn: { type: Date },
      streakStartDate: { type: Date },
      pointsHistory: [{
        points: { type: Number, required: true },
        reason: {
          type: String,
          enum: ['on_time_clock_in', 'early_arrival', 'streak_bonus', 'perfect_week'],
          required: true,
        },
        eventId: { type: String, required: true },
        earnedAt: { type: Date, default: Date.now },
      }],
    },

    // Clock-in preferences
    clockInSettings: {
      preShiftReminderMinutes: { type: Number, default: 30 },
      autoClockOutBuffer: { type: Number, default: 15 }, // 15 minutes after shift end
      enableVoiceClockIn: { type: Boolean, default: true },
    },
  },
  { timestamps: true }
);

UserSchema.index({ provider: 1, subject: 1 }, { unique: true });
UserSchema.index({ app_id: 1 }, { unique: false, sparse: true });
UserSchema.index({ qonversion_user_id: 1 }, { unique: false, sparse: true });
UserSchema.index({ auth_phone_number: 1 }, { unique: true, sparse: true }); // Phone auth lookup

export const UserModel: Model<UserDocument> =
  mongoose.models.User || mongoose.model<UserDocument>('User', UserSchema);


