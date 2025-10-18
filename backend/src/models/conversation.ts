import mongoose, { Document, Model, Schema } from 'mongoose';

export interface ConversationDocument extends Document {
  managerId: mongoose.Types.ObjectId;
  userKey: string; // provider:subject format (e.g., "google:123456")
  lastMessageAt?: Date;
  lastMessagePreview?: string;
  unreadCountManager: number; // unread messages for manager
  unreadCountUser: number; // unread messages for user
  createdAt: Date;
  updatedAt: Date;
}

const ConversationSchema = new Schema<ConversationDocument>(
  {
    managerId: {
      type: Schema.Types.ObjectId,
      ref: 'Manager',
      required: true,
      index: true
    },
    userKey: {
      type: String,
      required: true,
      trim: true,
      index: true
    },
    lastMessageAt: { type: Date },
    lastMessagePreview: { type: String, trim: true, maxlength: 200 },
    unreadCountManager: { type: Number, default: 0, min: 0 },
    unreadCountUser: { type: Number, default: 0, min: 0 },
  },
  { timestamps: true }
);

// Compound unique index to ensure one conversation per manager-user pair
ConversationSchema.index({ managerId: 1, userKey: 1 }, { unique: true });

// Index for querying conversations by last message time
ConversationSchema.index({ managerId: 1, lastMessageAt: -1 });
ConversationSchema.index({ userKey: 1, lastMessageAt: -1 });

export const ConversationModel: Model<ConversationDocument> =
  mongoose.models.Conversation ||
  mongoose.model<ConversationDocument>('Conversation', ConversationSchema);
