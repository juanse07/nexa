import mongoose, { Document, Model, Schema, Types } from 'mongoose';

export interface ManagerDocument extends Document {
  provider: 'google' | 'apple' | 'phone' | 'email';
  subject: string;
  organizationId?: Types.ObjectId;
  orgRole?: 'owner' | 'admin' | 'member';
  email?: string;
  name?: string; // original OAuth full name
  first_name?: string;
  last_name?: string;
  auth_phone_number?: string; // verified phone for authentication (E.164 format)
  picture?: string; // optional override picture
  originalPicture?: string; // pre-caricature picture (for revert)
  app_id?: string; // optional 9-digit app id
  passwordHash?: string; // for email/password auth (demo accounts)

  // Refresh tokens (hashed, max 10 per manager for multi-device support)
  refresh_tokens?: Array<{
    token: string; // SHA-256 hash
    expires_at: Date;
    created_at: Date;
  }>;

  // Linked authentication methods (for account linking)
  linked_providers?: Array<{
    provider: 'google' | 'apple' | 'phone' | 'email';
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

  // Caricature history (last 10 creations)
  caricatureHistory?: Array<{
    url: string;
    role: string;
    artStyle: string;
    model?: string; // 'dev' | 'pro'
    overlayText?: string;
    cacheKey?: string;
    cached?: boolean;
    createdAt: Date;
  }>;

  // City preferences (auto-populated from event creation, used by AI context)
  preferredCity?: string;
  cities?: Array<{
    name: string; // e.g., "Denver, CO, USA"
    isTourist: boolean;
  }>;

  // AI provider usage tracking
  groq_messages_used_this_month?: number;
  groq_messages_reset_date?: Date;
  groq_request_limit?: number;

  // Brand customization (Pro tier)
  brandProfile?: {
    logoOriginalUrl?: string;
    logoHeaderUrl?: string;
    logoWatermarkUrl?: string;
    aspectRatio?: number;
    shapeClassification?: 'horizontal' | 'square' | 'vertical' | 'icon';
    primaryColor?: string;
    secondaryColor?: string;
    accentColor?: string;
    neutralColor?: string;
    preferredDocDesign?: string;
    createdAt?: Date;
    updatedAt?: Date;
  };

  // Payroll configuration (org-wide)
  payrollConfig?: {
    provider: 'adp' | 'paychex' | 'gusto' | 'none';
    companyCode?: string;
    defaultDepartment?: string;
    defaultEarningsCode?: string;
    overtimeThreshold?: number;    // Hours per client per period before OT (default 40)
    overtimeMultiplier?: number;   // OT rate multiplier (default 1.5)
  };

  createdAt: Date;
  updatedAt: Date;
}

const ManagerSchema = new Schema<ManagerDocument>(
  {
    provider: { type: String, required: true, enum: ['google', 'apple', 'phone', 'email'] },
    subject: { type: String, required: true },
    email: { type: String, trim: true },
    name: { type: String, trim: true },
    first_name: { type: String, trim: true },
    last_name: { type: String, trim: true },
    auth_phone_number: { type: String, trim: true }, // E.164 format for phone auth
    picture: { type: String, trim: true },
    originalPicture: { type: String, trim: true }, // pre-caricature picture
    app_id: { type: String, trim: true },
    passwordHash: { type: String },

    // Organization (B2B multi-tenant)
    organizationId: { type: Schema.Types.ObjectId, ref: 'Organization', sparse: true },
    orgRole: { type: String, enum: ['owner', 'admin', 'member'] },

    // Refresh tokens (hashed, capped at 10 per manager)
    refresh_tokens: [{
      token: { type: String, required: true },
      expires_at: { type: Date, required: true },
      created_at: { type: Date, default: Date.now },
    }],

    // Linked authentication methods
    linked_providers: [{
      provider: { type: String, required: true, enum: ['google', 'apple', 'phone', 'email'] },
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

    // Caricature history (last 10 creations)
    caricatureHistory: [{
      url: { type: String, required: true },
      role: { type: String, required: true },
      artStyle: { type: String, required: true },
      model: { type: String, enum: ['dev', 'pro'], default: 'dev' },
      overlayText: { type: String },
      cacheKey: { type: String, index: true },
      cached: { type: Boolean, default: false },
      createdAt: { type: Date, default: Date.now },
    }],

    // City preferences (auto-populated from event creation, used by AI context)
    preferredCity: { type: String, trim: true },
    cities: [{
      name: { type: String, required: true, trim: true },
      isTourist: { type: Boolean, required: true, default: false },
    }],

    // Brand customization (Pro tier)
    brandProfile: {
      logoOriginalUrl: { type: String, trim: true },
      logoHeaderUrl: { type: String, trim: true },
      logoWatermarkUrl: { type: String, trim: true },
      aspectRatio: { type: Number },
      shapeClassification: { type: String, enum: ['horizontal', 'square', 'vertical', 'icon'] },
      primaryColor: { type: String, trim: true },
      secondaryColor: { type: String, trim: true },
      accentColor: { type: String, trim: true },
      neutralColor: { type: String, trim: true },
      preferredDocDesign: { type: String, enum: ['plain', 'classic', 'executive', 'modern'], default: 'classic' },
      createdAt: { type: Date },
      updatedAt: { type: Date },
    },

    // Payroll configuration (org-wide)
    payrollConfig: {
      provider: { type: String, enum: ['adp', 'paychex', 'gusto', 'none'], default: 'none' },
      companyCode: { type: String, trim: true },
      defaultDepartment: { type: String, trim: true },
      defaultEarningsCode: { type: String, trim: true, default: 'REG' },
      overtimeThreshold: { type: Number, default: 40 },
      overtimeMultiplier: { type: Number, default: 1.5 },
    },

    // AI provider usage tracking
    groq_messages_used_this_month: { type: Number, default: 0 },
    groq_messages_reset_date: {
      type: Date,
      default: function() {
        const date = new Date();
        date.setMonth(date.getMonth() + 1);
        date.setDate(1);
        date.setHours(0, 0, 0, 0);
        return date;
      }
    },
    groq_request_limit: { type: Number, default: 3 },
  },
  { timestamps: true }
);

ManagerSchema.index({ provider: 1, subject: 1 }, { unique: true });
ManagerSchema.index({ app_id: 1 }, { unique: false, sparse: true });
ManagerSchema.index({ qonversion_user_id: 1 }, { unique: false, sparse: true });
ManagerSchema.index({ auth_phone_number: 1 }, { unique: true, sparse: true }); // Phone auth lookup
ManagerSchema.index({ email: 1 }, { sparse: true }); // Email-based account linking lookup
ManagerSchema.index({ organizationId: 1 }, { sparse: true }); // Org membership lookup
ManagerSchema.index({ 'linked_providers.provider': 1, 'linked_providers.subject': 1 }, { sparse: true }); // Linked provider lookup

export const ManagerModel: Model<ManagerDocument> =
  mongoose.models.Manager || mongoose.model<ManagerDocument>('Manager', ManagerSchema);


