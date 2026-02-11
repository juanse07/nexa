/**
 * AI Provider configuration for Groq ↔ Together AI auto-switching.
 * First N requests/month use Groq, then auto-switch to Together AI.
 * The limit (N) is stored per-user/manager in MongoDB — changeable anytime without deploys.
 */

export interface AIProviderConfig {
  name: 'groq' | 'together';
  apiKey: string;
  baseUrl: string;
  model: string;
  supportsReasoning: boolean;
}

/** Map Groq model names → Together AI equivalents */
const GROQ_TO_TOGETHER_MODEL: Record<string, string> = {
  'openai/gpt-oss-20b': 'meta-llama/Meta-Llama-3.1-70B-Instruct-Turbo',
  'llama-3.1-8b-instant': 'meta-llama/Meta-Llama-3.1-8B-Instruct-Turbo',
};

/**
 * Get full provider config (URL, key, model) for a given provider + Groq model name.
 */
export function getProviderConfig(provider: 'groq' | 'together', groqModel: string): AIProviderConfig {
  if (provider === 'together') {
    return {
      name: 'together',
      apiKey: process.env.TOGETHER_API_KEY || '',
      baseUrl: 'https://api.together.xyz/v1/chat/completions',
      model: GROQ_TO_TOGETHER_MODEL[groqModel] || GROQ_TO_TOGETHER_MODEL['openai/gpt-oss-20b'],
      supportsReasoning: false,
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
 * Decide which provider to use based on monthly Groq usage.
 * Falls back to Groq if Together API key is missing.
 */
export function resolveProvider(groqUsed: number, groqLimit: number): 'groq' | 'together' {
  if (groqUsed < groqLimit) return 'groq';
  if (!process.env.TOGETHER_API_KEY) return 'groq';
  return 'together';
}
