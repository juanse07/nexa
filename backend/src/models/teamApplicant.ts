import mongoose, { Document, Model, Schema } from 'mongoose';

export type TeamApplicantStatus = 'pending' | 'approved' | 'denied';

export interface TeamApplicantDocument extends Document {
  teamId: mongoose.Types.ObjectId;
  managerId: mongoose.Types.ObjectId;
  inviteId: mongoose.Types.ObjectId;
  provider: string;
  subject: string;
  name?: string;
  email?: string;
  phoneNumber?: string;
  status: TeamApplicantStatus;
  appliedAt: Date;
  reviewedAt?: Date;
  reviewedBy?: mongoose.Types.ObjectId;
  createdAt: Date;
  updatedAt: Date;
}

const TeamApplicantSchema = new Schema<TeamApplicantDocument>(
  {
    teamId: { type: Schema.Types.ObjectId, ref: 'Team', required: true },
    managerId: { type: Schema.Types.ObjectId, ref: 'Manager', required: true },
    inviteId: { type: Schema.Types.ObjectId, ref: 'TeamInvite', required: true },
    provider: { type: String, required: true, trim: true },
    subject: { type: String, required: true, trim: true },
    name: { type: String, trim: true },
    email: { type: String, trim: true },
    phoneNumber: { type: String, trim: true },
    status: {
      type: String,
      enum: ['pending', 'approved', 'denied'],
      default: 'pending',
    },
    appliedAt: { type: Date, default: Date.now },
    reviewedAt: { type: Date },
    reviewedBy: { type: Schema.Types.ObjectId, ref: 'Manager' },
  },
  { timestamps: true }
);

// Unique compound index: one application per user per team
TeamApplicantSchema.index({ teamId: 1, provider: 1, subject: 1 }, { unique: true });

// Index for listing pending applicants
TeamApplicantSchema.index({ teamId: 1, status: 1 });

export const TeamApplicantModel: Model<TeamApplicantDocument> =
  mongoose.models.TeamApplicant ||
  mongoose.model<TeamApplicantDocument>('TeamApplicant', TeamApplicantSchema);
