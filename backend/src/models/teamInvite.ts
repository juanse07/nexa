import mongoose, { Document, Model, Schema } from 'mongoose';

export type TeamInviteStatus = 'pending' | 'accepted' | 'declined' | 'cancelled' | 'expired';
export type TeamInviteType = 'targeted' | 'link';

export interface InviteUsageEntry {
  userKey: string;
  userName?: string;
  joinedAt: Date;
}

export interface TeamInviteDocument extends Document {
  teamId: mongoose.Types.ObjectId;
  managerId: mongoose.Types.ObjectId;
  invitedBy?: mongoose.Types.ObjectId;
  token: string;
  shortCode?: string; // 6-character code for shareable links
  inviteType: TeamInviteType; // 'targeted' for email invites, 'link' for shareable
  email?: string;
  provider?: string;
  subject?: string;
  status: TeamInviteStatus;
  maxUses?: number; // null/undefined = unlimited, or set limit
  usedCount: number; // Track redemptions
  requireApproval: boolean; // Manager must approve after join
  passwordHash?: string; // bcrypt hash of optional password
  usageLog: InviteUsageEntry[]; // Audit log of who joined via this link
  expiresAt?: Date;
  acceptedAt?: Date;
  claimedByKey?: string;
  createdAt: Date;
  updatedAt: Date;
}

const TeamInviteSchema = new Schema<TeamInviteDocument>(
  {
    teamId: { type: Schema.Types.ObjectId, ref: 'Team', required: true, index: true },
    managerId: { type: Schema.Types.ObjectId, ref: 'Manager', required: true, index: true },
    invitedBy: { type: Schema.Types.ObjectId, ref: 'Manager' },
    token: { type: String, required: true, unique: true, index: true },
    shortCode: { type: String, sparse: true, unique: true, index: true, uppercase: true }, // NEW
    inviteType: { type: String, enum: ['targeted', 'link'], default: 'targeted' }, // NEW
    email: { type: String, trim: true },
    provider: { type: String, trim: true },
    subject: { type: String, trim: true },
    status: {
      type: String,
      enum: ['pending', 'accepted', 'declined', 'cancelled', 'expired'],
      default: 'pending',
    },
    maxUses: { type: Number, default: null }, // null = unlimited
    usedCount: { type: Number, default: 0 },
    requireApproval: { type: Boolean, default: false },
    passwordHash: { type: String },
    usageLog: { type: [{ userKey: String, userName: String, joinedAt: { type: Date, default: Date.now } }], default: [] },
    expiresAt: { type: Date },
    acceptedAt: { type: Date },
    claimedByKey: { type: String, trim: true },
  },
  { timestamps: true }
);

TeamInviteSchema.index({ managerId: 1, teamId: 1, status: 1 });
TeamInviteSchema.index({ teamId: 1, email: 1, status: 1 });
TeamInviteSchema.index({ teamId: 1, provider: 1, subject: 1, status: 1 });

export const TeamInviteModel: Model<TeamInviteDocument> =
  mongoose.models.TeamInvite ||
  mongoose.model<TeamInviteDocument>('TeamInvite', TeamInviteSchema);
