import mongoose, { Document, Model, Schema } from 'mongoose';

export interface ManagerDocument extends Document {
  provider: 'google' | 'apple' | 'phone';
  subject: string;
  email?: string;
  name?: string; // original OAuth full name
  first_name?: string;
  last_name?: string;
  auth_phone_number?: string; // verified phone for authentication (E.164 format)
  picture?: string; // optional override picture
  app_id?: string; // optional 9-digit app id

  // Linked authentication methods (for account linking)
  linked_providers?: Array<{
    provider: 'google' | 'apple' | 'phone';
    subject: string;
    linked_at: Date;
  }>;

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

  // Personalized venue discovery
  preferredCity?: string; // DEPRECATED: Use cities array instead. Kept for backward compatibility
  cities?: Array<{
    name: string; // e.g., "Denver, CO, USA"
    isTourist: boolean; // true = tourist city (strict search), false = metro area (broad search)
  }>;
  venueList?: Array<{
    name: string;
    address: string;
    city: string;
    cityName?: string; // Links venue to cities array entry
    source?: 'ai' | 'manual'; // Track if venue was AI-discovered or manually added
  }>;
  venueListUpdatedAt?: Date;

  createdAt: Date;
  updatedAt: Date;
}

const ManagerSchema = new Schema<ManagerDocument>(
  {
    provider: { type: String, required: true, enum: ['google', 'apple', 'phone'] },
    subject: { type: String, required: true },
    email: { type: String, trim: true },
    name: { type: String, trim: true },
    first_name: { type: String, trim: true },
    last_name: { type: String, trim: true },
    auth_phone_number: { type: String, trim: true }, // E.164 format for phone auth
    picture: { type: String, trim: true },
    app_id: { type: String, trim: true },

    // Linked authentication methods
    linked_providers: [{
      provider: { type: String, required: true, enum: ['google', 'apple', 'phone'] },
      subject: { type: String, required: true },
      linked_at: { type: Date, default: Date.now },
    }],

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

    // Personalized venue discovery
    preferredCity: { type: String, trim: true }, // DEPRECATED: kept for backward compatibility
    cities: [{
      name: { type: String, required: true, trim: true },
      isTourist: { type: Boolean, required: true, default: false },
    }],
    venueList: [{
      name: { type: String, required: true },
      address: { type: String, required: true },
      city: { type: String, required: true },
      cityName: { type: String, trim: true }, // Links to cities array entry
      source: { type: String, enum: ['ai', 'manual'], default: 'ai' },
    }],
    venueListUpdatedAt: { type: Date },
  },
  { timestamps: true }
);

ManagerSchema.index({ provider: 1, subject: 1 }, { unique: true });
ManagerSchema.index({ app_id: 1 }, { unique: false, sparse: true });
ManagerSchema.index({ qonversion_user_id: 1 }, { unique: false, sparse: true });
ManagerSchema.index({ auth_phone_number: 1 }, { unique: true, sparse: true }); // Phone auth lookup

export const ManagerModel: Model<ManagerDocument> =
  mongoose.models.Manager || mongoose.model<ManagerDocument>('Manager', ManagerSchema);


