import mongoose, { Document, Model, Schema } from 'mongoose';

/**
 * Individual message in an AI chat conversation
 */
export interface ConversationMessage {
  role: 'user' | 'assistant' | 'system';
  content: string;
  timestamp: Date;
  toolsUsed?: string[];
}

/**
 * Outcome of an AI chat conversation
 */
export type ConversationOutcome =
  // Manager outcomes
  | 'event_created'    // Manager confirmed and saved event
  | 'event_cancelled'  // Manager explicitly cancelled
  | 'timeout_saved'    // Auto-saved after countdown
  // Staff outcomes
  | 'availability_marked' // Staff marked availability
  | 'shift_accepted'      // Staff accepted a shift
  | 'shift_declined'      // Staff declined a shift
  | 'question_answered'   // Staff asked a question (general Q&A)
  // Shared outcomes
  | 'abandoned'        // User left without completing
  | 'error';           // Error during conversation

/**
 * User type for the conversation
 */
export type ChatUserType = 'manager' | 'staff';

/**
 * AI Chat Summary document - stores conversation history and metadata
 * for learning and analytics
 */
export interface AIChatSummaryDocument extends Document {
  // User identification (one of these is required)
  managerId?: mongoose.Types.ObjectId;
  userId?: mongoose.Types.ObjectId; // Staff user ID
  userType: ChatUserType;

  // Conversation content
  messages: ConversationMessage[];
  messageCount: number;

  // Extracted event data
  extractedEventData: Record<string, unknown>;
  eventId?: mongoose.Types.ObjectId;

  // Outcome tracking
  outcome: ConversationOutcome;
  outcomeReason?: string;

  // Analytics metadata
  durationMs: number;
  toolCallCount: number;
  toolsUsed: string[];
  inputSource?: 'text' | 'voice' | 'image' | 'pdf';

  // Quality indicators (for learning)
  wasEdited: boolean;
  editedFields?: string[];

  // AI model info
  aiModel: string;
  aiProvider: string;

  // Conversation timestamps
  conversationStartedAt: Date;
  conversationEndedAt: Date;

  // Mongoose timestamps
  createdAt: Date;
  updatedAt: Date;
}

const ConversationMessageSchema = new Schema<ConversationMessage>(
  {
    role: {
      type: String,
      enum: ['user', 'assistant', 'system'],
      required: true,
    },
    content: {
      type: String,
      required: true,
      maxlength: 10000, // Limit individual message size
    },
    timestamp: { type: Date, required: true },
    toolsUsed: { type: [String], default: [] },
  },
  { _id: false }
);

const AIChatSummarySchema = new Schema<AIChatSummaryDocument>(
  {
    // User identification (one of managerId or userId is required)
    managerId: {
      type: Schema.Types.ObjectId,
      ref: 'Manager',
      index: true,
      sparse: true,
    },
    userId: {
      type: Schema.Types.ObjectId,
      ref: 'User',
      index: true,
      sparse: true,
    },
    userType: {
      type: String,
      enum: ['manager', 'staff'],
      required: true,
      index: true,
    },

    // Conversation content
    messages: {
      type: [ConversationMessageSchema],
      required: true,
      validate: {
        validator: (v: ConversationMessage[]) => v.length > 0,
        message: 'At least one message is required',
      },
    },
    messageCount: { type: Number, required: true, min: 1 },

    // Extracted event data
    extractedEventData: { type: Schema.Types.Mixed, required: true },
    eventId: {
      type: Schema.Types.ObjectId,
      ref: 'Event',
      sparse: true,
    },

    // Outcome tracking
    outcome: {
      type: String,
      enum: [
        // Manager outcomes
        'event_created', 'event_cancelled', 'timeout_saved',
        // Staff outcomes
        'availability_marked', 'shift_accepted', 'shift_declined', 'question_answered',
        // Shared outcomes
        'abandoned', 'error',
      ],
      required: true,
      index: true,
    },
    outcomeReason: { type: String, trim: true, maxlength: 500 },

    // Analytics metadata
    durationMs: { type: Number, required: true, min: 0 },
    toolCallCount: { type: Number, required: true, default: 0, min: 0 },
    toolsUsed: { type: [String], default: [] },
    inputSource: {
      type: String,
      enum: ['text', 'voice', 'image', 'pdf'],
      default: 'text',
    },

    // Quality indicators
    wasEdited: { type: Boolean, default: false },
    editedFields: { type: [String], default: [] },

    // AI model info
    aiModel: { type: String, required: true },
    aiProvider: { type: String, required: true, default: 'groq' },

    // Conversation timestamps
    conversationStartedAt: { type: Date, required: true },
    conversationEndedAt: { type: Date, required: true },
  },
  { timestamps: true }
);

// Compound indexes for common queries
AIChatSummarySchema.index({ managerId: 1, createdAt: -1 }); // Manager's conversations by date
AIChatSummarySchema.index({ userId: 1, createdAt: -1 });    // Staff's conversations by date
AIChatSummarySchema.index({ userType: 1, createdAt: -1 });  // Filter by user type
AIChatSummarySchema.index({ outcome: 1, createdAt: -1 });    // Filter by outcome
AIChatSummarySchema.index({ toolsUsed: 1 });                 // Tool usage analytics
AIChatSummarySchema.index({ managerId: 1, outcome: 1, wasEdited: 1 }); // Context examples query (manager)
AIChatSummarySchema.index({ userId: 1, outcome: 1 }); // Context examples query (staff)

// Pre-save: auto-calculate messageCount
AIChatSummarySchema.pre('validate', function calculateMessageCount(next) {
  if (this.messages) {
    this.messageCount = this.messages.length;
  }
  next();
});

export const AIChatSummaryModel: Model<AIChatSummaryDocument> =
  mongoose.models.AIChatSummary ||
  mongoose.model<AIChatSummaryDocument>('AIChatSummary', AIChatSummarySchema, 'aichatsummaries');
