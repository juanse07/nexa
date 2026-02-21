import mongoose, { Document, Model, Schema, Types } from 'mongoose';

export type OrgSubscriptionStatus = 'trialing' | 'active' | 'past_due' | 'canceled' | 'unpaid' | 'none';
export type OrgSubscriptionTier = 'free' | 'pro';
export type OrgMemberRole = 'owner' | 'admin' | 'member';
export type OrgStaffPolicy = 'open' | 'restricted';

export interface ApprovedStaffEntry {
  provider: string;
  subject: string;
  name?: string;
  email?: string;
  addedBy: Types.ObjectId;
  addedAt: Date;
}

export interface OrgMember {
  managerId: Types.ObjectId;
  role: OrgMemberRole;
  joinedAt: Date;
}

export interface OrgPendingInvite {
  email: string;
  role: OrgMemberRole;
  token: string;
  expiresAt: Date;
  invitedBy: Types.ObjectId;
}

export interface OrganizationDocument extends Document {
  name: string;
  slug: string;
  stripeCustomerId: string;
  stripeSubscriptionId?: string;
  subscriptionStatus: OrgSubscriptionStatus;
  subscriptionTier: OrgSubscriptionTier;
  currentPeriodEnd?: Date;
  cancelAtPeriodEnd?: boolean;
  managerSeatsIncluded: number;
  staffSeatsIncluded: number;
  staffPolicy: OrgStaffPolicy;
  approvedStaff: ApprovedStaffEntry[];
  members: OrgMember[];
  pendingInvites: OrgPendingInvite[];
  createdAt: Date;
  updatedAt: Date;
}

const OrganizationSchema = new Schema<OrganizationDocument>(
  {
    name: { type: String, required: true, trim: true },
    slug: { type: String, required: true, trim: true, lowercase: true },
    stripeCustomerId: { type: String, trim: true },
    stripeSubscriptionId: { type: String, trim: true },
    subscriptionStatus: {
      type: String,
      enum: ['trialing', 'active', 'past_due', 'canceled', 'unpaid', 'none'],
      default: 'none',
    },
    subscriptionTier: {
      type: String,
      enum: ['free', 'pro'],
      default: 'free',
    },
    currentPeriodEnd: { type: Date },
    cancelAtPeriodEnd: { type: Boolean, default: false },
    managerSeatsIncluded: { type: Number, default: 5 },
    staffSeatsIncluded: { type: Number, default: 0 }, // 0 = unlimited
    staffPolicy: {
      type: String,
      enum: ['open', 'restricted'],
      default: 'open',
    },
    approvedStaff: [{
      provider: { type: String, required: true, trim: true },
      subject: { type: String, required: true, trim: true },
      name: { type: String, trim: true },
      email: { type: String, trim: true },
      addedBy: { type: Schema.Types.ObjectId, ref: 'Manager', required: true },
      addedAt: { type: Date, default: Date.now },
    }],
    members: [{
      managerId: { type: Schema.Types.ObjectId, ref: 'Manager', required: true },
      role: { type: String, enum: ['owner', 'admin', 'member'], required: true },
      joinedAt: { type: Date, default: Date.now },
    }],
    pendingInvites: [{
      email: { type: String, required: true, trim: true, lowercase: true },
      role: { type: String, enum: ['owner', 'admin', 'member'], default: 'member' },
      token: { type: String, required: true },
      expiresAt: { type: Date, required: true },
      invitedBy: { type: Schema.Types.ObjectId, ref: 'Manager', required: true },
    }],
  },
  { timestamps: true }
);

OrganizationSchema.index({ slug: 1 }, { unique: true });
OrganizationSchema.index({ stripeCustomerId: 1 }, { unique: true, sparse: true });
OrganizationSchema.index({ stripeSubscriptionId: 1 }, { unique: true, sparse: true });
OrganizationSchema.index({ 'members.managerId': 1 });
OrganizationSchema.index({ _id: 1, 'approvedStaff.provider': 1, 'approvedStaff.subject': 1 });

export const OrganizationModel: Model<OrganizationDocument> =
  mongoose.models.Organization || mongoose.model<OrganizationDocument>('Organization', OrganizationSchema);
