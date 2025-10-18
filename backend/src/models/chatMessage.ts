import mongoose, { Document, Model, Schema } from 'mongoose';

export type SenderType = 'manager' | 'user';

export interface ChatMessageDocument extends Document {
  conversationId: mongoose.Types.ObjectId;
  managerId: mongoose.Types.ObjectId;
  userKey: string; // provider:subject format
  senderType: SenderType; // who sent the message
  senderName?: string; // sender's display name
  senderPicture?: string; // sender's profile picture
  message: string;
  readByManager: boolean;
  readByUser: boolean;
  createdAt: Date;
  updatedAt: Date;
}

const ChatMessageSchema = new Schema<ChatMessageDocument>(
  {
    conversationId: {
      type: Schema.Types.ObjectId,
      ref: 'Conversation',
      required: true,
      index: true
    },
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
    senderType: {
      type: String,
      enum: ['manager', 'user'],
      required: true
    },
    senderName: { type: String, trim: true },
    senderPicture: { type: String, trim: true },
    message: {
      type: String,
      required: true,
      trim: true,
      maxlength: 5000
    },
    readByManager: { type: Boolean, default: false, index: true },
    readByUser: { type: Boolean, default: false, index: true },
  },
  { timestamps: true }
);

// Index for querying messages by conversation and time
ChatMessageSchema.index({ conversationId: 1, createdAt: -1 });

// Index for counting unread messages
ChatMessageSchema.index({ conversationId: 1, readByManager: 1 });
ChatMessageSchema.index({ conversationId: 1, readByUser: 1 });

export const ChatMessageModel: Model<ChatMessageDocument> =
  mongoose.models.ChatMessage ||
  mongoose.model<ChatMessageDocument>('ChatMessage', ChatMessageSchema);
