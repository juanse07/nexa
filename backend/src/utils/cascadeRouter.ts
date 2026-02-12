/**
 * AI Chat Cascade Router
 *
 * Deterministically routes queries by complexity:
 *   Simple (70%) → openai/gpt-oss-20b @ Together AI (cheap, fast)
 *   Complex (30%) → openai/gpt-oss-120b @ Groq (reasoning power)
 *
 * Replaces the old Groq/Together quota cycling approach.
 */

export interface CascadeSelection {
  provider: 'groq' | 'together';
  model: string;
  tier: 'simple' | 'complex';
}

/** Extract the last user-role message text from a messages array. */
export function extractLastUserMessage(messages: { role: string; content: string }[]): string {
  if (!messages || messages.length === 0) return '';
  for (let i = messages.length - 1; i >= 0; i--) {
    const msg = messages[i];
    if (msg && msg.role === 'user' && msg.content) {
      return msg.content;
    }
  }
  return '';
}

/** Keyword-based complexity classification (English + Spanish). */
export function isComplexQuery(userMessage: string): boolean {
  if (!userMessage) return false;
  const lower = userMessage.toLowerCase();

  const complexityIndicators = [
    // Analysis (clearly analytical verbs)
    'analyze', 'compare', 'recommend', 'optimize', 'prioritize',
    // Strategy (multi-step phrasing)
    'should i', 'what if', 'how can i', 'best way to',
    'focus on', 'invest in',
    // Trends & prediction
    'predict', 'forecast', 'historically',
    // Comparative (multi-factor only)
    'most valuable', 'versus', 'vs', 'difference between',
    // Multi-dimensional
    'taking into account', 'holistic',
    // Strategy keywords from PDF
    'strategy', 'maximize', 'grow',
    // Spanish (analytical only)
    'analizar', 'comparar', 'recomendar', 'optimizar',
  ];

  return complexityIndicators.some((kw) => lower.includes(kw));
}

/**
 * Select model + provider based on query complexity.
 *
 * Classify the latest user message:
 *   complex → groq  / openai/gpt-oss-120b
 *   simple  → together / openai/gpt-oss-20b
 */
export function selectModelForQuery(
  messages: { role: string; content: string }[],
): CascadeSelection {
  const lastMessage = extractLastUserMessage(messages);
  const complex = isComplexQuery(lastMessage);

  if (complex) {
    return { provider: 'groq', model: 'openai/gpt-oss-120b', tier: 'complex' };
  }

  // Fall back to groq if Together key is missing
  if (!process.env.TOGETHER_API_KEY) {
    return { provider: 'groq', model: 'openai/gpt-oss-20b', tier: 'simple' };
  }

  return { provider: 'together', model: 'openai/gpt-oss-20b', tier: 'simple' };
}

// ---------------------------------------------------------------------------
// Method 2: Tool-Based Routing
// After the AI picks tools on the small model, check whether those tools
// require deeper reasoning. If so, the follow-up synthesis call should use
// the larger model on Groq.
// ---------------------------------------------------------------------------

/** Tools that require multi-metric analysis, judgment, or trend reasoning. */
const COMPLEX_TOOLS = new Set([
  'get_top_staff',        // comparative ranking across metrics
  'get_top_clients',      // comparative ranking across metrics
  'get_revenue_summary',  // financial trend analysis
  'get_busy_periods',     // trend / demand analysis
  'get_role_demand',      // demand forecasting
  'merge_clients',        // requires judgment (dedup)
  'merge_roles',          // requires judgment (dedup)
  'get_staff_leaderboard', // multi-metric comparison
]);

/**
 * Given the tool calls the AI chose, decide whether the synthesis step
 * should be escalated to the larger model.
 *
 * Escalate when:
 *  - Any single tool call is in the COMPLEX_TOOLS set, OR
 *  - The AI wants to orchestrate >2 tools simultaneously (multi-tool query)
 */
export function shouldEscalateFromTools(toolCalls: { function: { name: string } }[]): boolean {
  if (!toolCalls || toolCalls.length === 0) return false;

  if (toolCalls.some((tc) => COMPLEX_TOOLS.has(tc.function.name))) return true;

  if (toolCalls.length > 2) return true;

  return false;
}

/** Config for the escalated (complex) model. */
export const ESCALATION_MODEL = 'openai/gpt-oss-120b';
export const ESCALATION_PROVIDER: 'groq' = 'groq';
