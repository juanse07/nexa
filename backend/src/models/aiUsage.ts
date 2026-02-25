import mongoose, { Document, Model, Schema } from 'mongoose';

/**
 * AI Usage tracking document — records token usage for every AI API call
 * across all endpoints (chat, transcription, OCR, brand colors, venues, compose).
 */

export type AIEndpoint =
  | 'chat/message'
  | 'staff/chat/message'
  | 'transcribe'
  | 'staff/transcribe'
  | 'analyze-sheet'
  | 'extract-colors'
  | 'discover-venues'
  | 'compose-message';

export type AIProvider = 'groq' | 'together' | 'openai';

export type AIUserType = 'manager' | 'staff' | 'system';

export interface AIUsageDocument extends Document {
  managerId?: mongoose.Types.ObjectId;
  userId?: mongoose.Types.ObjectId;
  userType: AIUserType;
  endpoint: AIEndpoint;
  provider: AIProvider;
  aiModel: string; // Named aiModel to avoid clash with Document.model
  inputTokens: number;
  outputTokens: number;
  reasoningTokens: number;
  totalTokens: number;
  durationMs: number;
  toolCallCount: number;
  toolsSelected?: number;
  tier?: 'simple' | 'complex';
  audioDurationSec?: number;
  createdAt: Date;
  updatedAt: Date;
}

const AIUsageSchema = new Schema<AIUsageDocument>(
  {
    managerId: {
      type: Schema.Types.ObjectId,
      ref: 'Manager',
      sparse: true,
    },
    userId: {
      type: Schema.Types.ObjectId,
      ref: 'User',
      sparse: true,
    },
    userType: {
      type: String,
      enum: ['manager', 'staff', 'system'],
      required: true,
    },
    endpoint: {
      type: String,
      enum: [
        'chat/message', 'staff/chat/message',
        'transcribe', 'staff/transcribe',
        'analyze-sheet', 'extract-colors',
        'discover-venues', 'compose-message',
      ],
      required: true,
    },
    provider: {
      type: String,
      enum: ['groq', 'together', 'openai'],
      required: true,
    },
    aiModel: { type: String, required: true },
    inputTokens: { type: Number, default: 0, min: 0 },
    outputTokens: { type: Number, default: 0, min: 0 },
    reasoningTokens: { type: Number, default: 0, min: 0 },
    totalTokens: { type: Number, default: 0, min: 0 },
    durationMs: { type: Number, default: 0, min: 0 },
    toolCallCount: { type: Number, default: 0, min: 0 },
    toolsSelected: { type: Number, min: 0 },
    tier: {
      type: String,
      enum: ['simple', 'complex'],
    },
    audioDurationSec: { type: Number, min: 0 },
  },
  { timestamps: true }
);

// Compound indexes for common analytics queries
AIUsageSchema.index({ managerId: 1, createdAt: -1 });
AIUsageSchema.index({ userId: 1, createdAt: -1 });
AIUsageSchema.index({ provider: 1, aiModel: 1, createdAt: -1 });
AIUsageSchema.index({ endpoint: 1, createdAt: -1 });

export const AIUsageModel: Model<AIUsageDocument> =
  mongoose.models.AIUsage ||
  mongoose.model<AIUsageDocument>('AIUsage', AIUsageSchema, 'aiusage');
