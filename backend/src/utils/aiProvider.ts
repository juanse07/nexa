/**
 * AI Provider configuration for Groq ↔ Together AI percentage-based routing.
 * Each subscription tier defines a togetherAiPercent (0–100) that controls
 * the probability of routing a request to Together AI vs Groq.
 */

export interface AIProviderConfig {
  name: 'groq' | 'together';
  apiKey: string;
  baseUrl: string;
  model: string;
  supportsReasoning: boolean;
}

/**
 * Get full provider config (URL, key, model) for a given provider + Groq model name.
 * Together AI offers the same models — pass through the model name directly.
 */
export function getProviderConfig(provider: 'groq' | 'together', groqModel: string): AIProviderConfig {
  if (provider === 'together') {
    return {
      name: 'together',
      apiKey: process.env.TOGETHER_API_KEY || '',
      baseUrl: 'https://api.together.xyz/v1/chat/completions',
      model: groqModel,
      supportsReasoning: true,
    };
  }

  return {
    name: 'groq',
    apiKey: process.env.GROQ_API_KEY || '',
    baseUrl: 'https://api.groq.com/openai/v1/chat/completions',
    model: groqModel,
    supportsReasoning: true,
  };
}

/**
 * Decide which provider to use based on message count and tier percentage.
 * Uses a deterministic cycle of 10: the first (100-togetherPercent)/10 slots
 * go to Groq, the rest to Together. Paying users get Groq first in each cycle.
 * Falls back to Groq if Together API key is missing.
 */
export function resolveProvider(messageIndex: number, togetherPercent: number): 'groq' | 'together' {
  if (!process.env.TOGETHER_API_KEY) return 'groq';
  const groqSlots = (100 - togetherPercent) / 10;
  return messageIndex % 10 < groqSlots ? 'groq' : 'together';
}
