import mongoose from 'mongoose';
import { AIUsageModel, AIEndpoint, AIProvider, AIUserType } from '../models/aiUsage';

export interface LogAIUsageParams {
  managerId?: string | mongoose.Types.ObjectId;
  userId?: string | mongoose.Types.ObjectId;
  userType: AIUserType;
  endpoint: AIEndpoint;
  provider: AIProvider;
  model: string;
  inputTokens?: number;
  outputTokens?: number;
  reasoningTokens?: number;
  totalTokens?: number;
  durationMs?: number;
  toolCallCount?: number;
  toolsSelected?: number;
  tier?: 'simple' | 'complex';
  audioDurationSec?: number;
}

/**
 * Fire-and-forget AI usage logger.
 * Always call as: logAIUsage({...}).catch(() => {})
 */
export async function logAIUsage(params: LogAIUsageParams): Promise<void> {
  const doc: Record<string, unknown> = {
    userType: params.userType,
    endpoint: params.endpoint,
    provider: params.provider,
    aiModel: params.model,
    inputTokens: params.inputTokens || 0,
    outputTokens: params.outputTokens || 0,
    reasoningTokens: params.reasoningTokens || 0,
    totalTokens: params.totalTokens || 0,
    durationMs: params.durationMs || 0,
    toolCallCount: params.toolCallCount || 0,
  };

  if (params.managerId) {
    doc.managerId = typeof params.managerId === 'string'
      ? new mongoose.Types.ObjectId(params.managerId)
      : params.managerId;
  }
  if (params.userId) {
    doc.userId = typeof params.userId === 'string'
      ? new mongoose.Types.ObjectId(params.userId)
      : params.userId;
  }
  if (params.tier) doc.tier = params.tier;
  if (params.toolsSelected != null) doc.toolsSelected = params.toolsSelected;
  if (params.audioDurationSec != null) doc.audioDurationSec = params.audioDurationSec;

  await AIUsageModel.create(doc);
}
