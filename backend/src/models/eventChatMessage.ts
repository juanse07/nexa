import mongoose, { Document, Model, Schema } from 'mongoose';

export interface EventChatMessageDocument extends Document {
  eventId: mongoose.Types.ObjectId;

  // Sender info
  senderId: mongoose.Types.ObjectId;
  senderType: 'user' | 'manager';
  senderName: string;
  senderAvatar?: string;

  // Message content
  message: string;
  messageType: 'text' | 'system';

  // Metadata
  readBy: mongoose.Types.ObjectId[];
  deliveredTo: mongoose.Types.ObjectId[];

  createdAt: Date;
  updatedAt: Date;
}

const EventChatMessageSchema = new Schema<EventChatMessageDocument>(
  {
    eventId: {
      type: Schema.Types.ObjectId,
      ref: 'Event',
      required: true,
      index: true
    },

    senderId: {
      type: Schema.Types.ObjectId,
      required: true
    },

    senderType: {
      type: String,
      enum: ['user', 'manager'],
      required: true
    },

    senderName: {
      type: String,
      required: true,
      trim: true
    },

    senderAvatar: {
      type: String,
      trim: true
    },

    message: {
      type: String,
      required: true,
      trim: true,
      maxlength: 2000
    },

    messageType: {
      type: String,
      enum: ['text', 'system'],
      default: 'text'
    },

    readBy: {
      type: [Schema.Types.ObjectId],
      default: []
    },

    deliveredTo: {
      type: [Schema.Types.ObjectId],
      default: []
    },
  },
  { timestamps: true }
);

// Compound index for efficient querying by event
EventChatMessageSchema.index({ eventId: 1, createdAt: -1 });

export const EventChatMessageModel: Model<EventChatMessageDocument> =
  mongoose.models.EventChatMessage ||
  mongoose.model<EventChatMessageDocument>('EventChatMessage', EventChatMessageSchema);
