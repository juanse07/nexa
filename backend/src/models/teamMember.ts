import mongoose, { Document, Model, Schema } from 'mongoose';

export type TeamMemberStatus = 'pending' | 'active' | 'left';

export interface TeamMemberDocument extends Document {
  teamId: mongoose.Types.ObjectId;
  managerId: mongoose.Types.ObjectId;
  provider: string;
  subject: string;
  email?: string;
  name?: string;
  invitedBy?: mongoose.Types.ObjectId;
  joinedAt: Date;
  status: TeamMemberStatus;
  createdAt: Date;
  updatedAt: Date;
}

const TeamMemberSchema = new Schema<TeamMemberDocument>(
  {
    teamId: { type: Schema.Types.ObjectId, ref: 'Team', required: true, index: true },
    managerId: { type: Schema.Types.ObjectId, ref: 'Manager', required: true, index: true },
    provider: { type: String, required: true, trim: true },
    subject: { type: String, required: true, trim: true },
    email: { type: String, trim: true },
    name: { type: String, trim: true },
    invitedBy: { type: Schema.Types.ObjectId, ref: 'Manager' },
    joinedAt: { type: Date, default: Date.now },
    status: {
      type: String,
      enum: ['pending', 'active', 'left'],
      default: 'pending',
    },
  },
  { timestamps: true, collection: 'teammembers' }
);

TeamMemberSchema.index({ teamId: 1, provider: 1, subject: 1 }, { unique: true });
TeamMemberSchema.index({ provider: 1, subject: 1, status: 1 });
// Compound index for manager access queries - enables fast lookups for "which users can this manager access?"
TeamMemberSchema.index({ managerId: 1, status: 1, provider: 1, subject: 1 });

export const TeamMemberModel: Model<TeamMemberDocument> =
  mongoose.models.TeamMember || mongoose.model<TeamMemberDocument>('TeamMember', TeamMemberSchema);
