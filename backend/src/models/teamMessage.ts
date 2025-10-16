import mongoose, { Document, Model, Schema } from 'mongoose';

export type TeamMessageType =
  | 'invite_created'
  | 'invite_accepted'
  | 'invite_declined'
  | 'text';

export interface TeamMessageDocument extends Document {
  teamId: mongoose.Types.ObjectId;
  managerId: mongoose.Types.ObjectId;
  senderKey?: string;
  senderName?: string;
  messageType: TeamMessageType;
  body?: string;
  payload?: Record<string, unknown>;
  createdAt: Date;
  updatedAt: Date;
}

const TeamMessageSchema = new Schema<TeamMessageDocument>(
  {
    teamId: { type: Schema.Types.ObjectId, ref: 'Team', required: true, index: true },
    managerId: { type: Schema.Types.ObjectId, ref: 'Manager', required: true, index: true },
    senderKey: { type: String, trim: true },
    senderName: { type: String, trim: true },
    messageType: {
      type: String,
      enum: ['invite_created', 'invite_accepted', 'invite_declined', 'text'],
      required: true,
    },
    body: { type: String, trim: true },
    payload: { type: Schema.Types.Mixed },
  },
  { timestamps: true }
);

TeamMessageSchema.index({ teamId: 1, createdAt: -1 });

export const TeamMessageModel: Model<TeamMessageDocument> =
  mongoose.models.TeamMessage ||
  mongoose.model<TeamMessageDocument>('TeamMessage', TeamMessageSchema);
