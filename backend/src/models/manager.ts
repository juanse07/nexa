import mongoose, { Document, Model, Schema } from 'mongoose';

export interface ManagerDocument extends Document {
  provider: 'google' | 'apple';
  subject: string;
  email?: string;
  name?: string; // original OAuth full name
  first_name?: string;
  last_name?: string;
  picture?: string; // optional override picture
  app_id?: string; // optional 9-digit app id

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

  createdAt: Date;
  updatedAt: Date;
}

const ManagerSchema = new Schema<ManagerDocument>(
  {
    provider: { type: String, required: true, enum: ['google', 'apple'] },
    subject: { type: String, required: true },
    email: { type: String, trim: true },
    name: { type: String, trim: true },
    first_name: { type: String, trim: true },
    last_name: { type: String, trim: true },
    picture: { type: String, trim: true },
    app_id: { type: String, trim: true },

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
  },
  { timestamps: true }
);

ManagerSchema.index({ provider: 1, subject: 1 }, { unique: true });
ManagerSchema.index({ app_id: 1 }, { unique: false, sparse: true });

export const ManagerModel: Model<ManagerDocument> =
  mongoose.models.Manager || mongoose.model<ManagerDocument>('Manager', ManagerSchema);


