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
export function extractLastUserMessage(messages: { role: string; content: any }[]): string {
  if (!messages || messages.length === 0) return '';
  for (let i = messages.length - 1; i >= 0; i--) {
    const msg = messages[i];
    if (msg && msg.role === 'user' && msg.content) {
      return typeof msg.content === 'string' ? msg.content : '';
    }
  }
  return '';
}

/** Extract the last N user-role messages, concatenated (for conversation context). */
export function extractRecentUserMessages(messages: { role: string; content: any }[], count: number = 3): string {
  if (!messages || messages.length === 0) return '';
  const userMsgs: string[] = [];
  for (let i = messages.length - 1; i >= 0 && userMsgs.length < count; i--) {
    const msg = messages[i];
    if (msg && msg.role === 'user' && msg.content && typeof msg.content === 'string') {
      userMsgs.unshift(msg.content);
    }
  }
  return userMsgs.join(' ');
}

/** Keyword-based complexity classification (English + Spanish). */
export function isComplexQuery(userMessage: string): boolean {
  if (!userMessage) return false;
  const lower = userMessage.toLowerCase();

  const complexityIndicators = [
    // Analysis (verb + noun forms)
    'analyze', 'analysis', 'compare', 'recommend', 'optimize', 'prioritize',
    'evaluate', 'assess', 'review', 'breakdown', 'insight',
    // Strategy (multi-step phrasing)
    'should i', 'what if', 'how can i', 'best way to',
    'focus on', 'invest in', 'pros and cons', 'trade-off',
    'which is better', 'improve',
    // Trends & prediction
    'predict', 'forecast', 'historically', 'trend', 'pattern',
    'over time', 'month over month', 'week over week', 'growth rate',
    // Comparative (multi-factor only)
    'most valuable', 'versus', 'vs', 'difference between',
    'rank', 'top performing', 'bottom', 'weakest', 'strongest', 'least',
    // Multi-dimensional / depth
    'taking into account', 'holistic', 'deep ',
    'comprehensive', 'detailed', 'thorough', 'in-depth', 'overview',
    // Strategy keywords
    'strategy', 'maximize', 'grow', 'reduce', 'minimize',
    'cut costs', 'efficiency', 'profitable', 'roi',
    // Why / root cause
    'why ', 'root cause', 'reason for', 'explain why',
    // Summarization (cross-data synthesis)
    'summarize', 'summary', 'recap', 'report',
    // Spanish — analysis
    'analizar', 'analisis', 'comparar', 'recomendar', 'optimizar',
    'evaluar', 'revisar', 'desglose',
    // Spanish — strategy & trends
    'deberia', 'cual es mejor', 'mejorar', 'tendencia', 'patron',
    'crecimiento', 'clasificar', 'peor', 'mejor rendimiento',
    // Spanish — depth & cause
    'detallado', 'completo', 'a fondo', 'por que', 'causa', 'razon',
    // Spanish — summarization
    'resumen', 'resumir', 'reducir', 'eficiencia', 'rentable',
  ];

  return complexityIndicators.some((kw) => lower.includes(kw));
}

/**
 * Detect if the conversation is in an active event workflow (create → publish).
 * These multi-step flows require the 120B model for reliable state tracking.
 */
function isInEventWorkflow(messages: { role: string; content: any }[]): boolean {
  // Check recent assistant messages for event workflow signals
  const recentCount = 6; // look at last 6 messages (3 turns)
  const recent = messages.slice(-recentCount);

  for (const msg of recent) {
    if (!msg || typeof msg.content !== 'string') continue;
    const lower = msg.content.toLowerCase();

    if (msg.role === 'assistant') {
      // Assistant proposed/created/asked about an event
      if (
        lower.includes('publicar') || lower.includes('publish') ||
        lower.includes('equipo') || lower.includes('which team') ||
        lower.includes('creado') || lower.includes('created') ||
        lower.includes('draft') ||
        // Confirmation questions about event creation (any conjugation)
        lower.includes('crearé') || lower.includes('lo creo') ||
        lower.includes('correcto') || lower.includes('correct') ||
        lower.includes('te parece') || lower.includes('look good') ||
        lower.includes('shall i') || lower.includes('want me to') ||
        // Event summary signals (assistant just proposed an event)
        lower.includes('roles:') || lower.includes('hora de llegada') ||
        lower.includes('call time') || lower.includes('start time') ||
        lower.includes('fecha:') || lower.includes('date:') ||
        lower.includes('lugar:') || lower.includes('venue:')
      ) return true;
    }
  }

  // Also check if the user's recent context has event-creation keywords
  const context = extractRecentUserMessages(messages, 3).toLowerCase();
  const eventKeywords = [
    'create', 'crear', 'crea ', 'cre ', 'creame', 'schedule', 'agendar',
    'new event', 'nuevo evento', 'new shift', 'nuevo turno',
    'publish', 'publicar', 'evento', 'event', 'job for', 'trabajo para',
  ];
  if (eventKeywords.some((kw) => context.includes(kw))) return true;

  return false;
}

/**
 * Select model + provider based on query complexity.
 *
 * Classify the latest user message:
 *   complex → groq  / openai/gpt-oss-120b
 *   simple  → together / openai/gpt-oss-20b
 *
 * Also escalates to 120B when an active event workflow is detected,
 * since the 20B model cannot reliably track multi-step create→publish flows.
 */
export function selectModelForQuery(
  messages: { role: string; content: any }[],
): CascadeSelection {
  const lastMessage = extractLastUserMessage(messages);
  const complex = isComplexQuery(lastMessage);

  if (complex || isInEventWorkflow(messages)) {
    return { provider: 'groq', model: 'openai/gpt-oss-120b', tier: 'complex' };
  }

  // Route simple tier through Groq — Together AI has chronic latency issues (60s+ timeouts).
  // Groq serves the same gpt-oss-20b model in <1s. Re-enable Together when their infra stabilizes.
  return { provider: 'groq', model: 'openai/gpt-oss-20b', tier: 'simple' };
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
  'get_punctuality_report', // lateness analysis benefits from reasoning
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

// ---------------------------------------------------------------------------
// Dynamic Tool Selection
// Send only the tools relevant to the user's query instead of all tools.
// Manager: 39 tools → 8-16 per request (~2,500-3,500 token savings)
// Staff:   10 tools → 4-7 per request (~300-500 token savings)
// ---------------------------------------------------------------------------

export interface ToolSelectionConfig {
  coreTools: Set<string>;
  categories: Record<string, string[]>;
  keywords: Record<string, string[]>;
}

/** Manager tool selection config (39 tools). */
export const MANAGER_TOOL_CONFIG: ToolSelectionConfig = {
  coreTools: new Set([
    'search_events', 'get_clients_list', 'get_roles_list',
    'get_team_members', 'search_addresses',
  ]),
  categories: {
    EVENT_CRUD: [
      'create_event', 'create_events_bulk', 'publish_event',
      'publish_events_bulk', 'update_event', 'invite_staff_to_event',
      'check_availability', 'get_tariffs_list', 'get_teams',
    ],
    CLIENT_MGMT: [
      'get_client_info', 'create_client', 'delete_client',
      'merge_clients', 'get_client_stats',
    ],
    ROLE_TARIFF: [
      'create_role', 'delete_role', 'merge_roles',
      'get_tariffs_list', 'create_tariff', 'delete_tariff',
    ],
    STAFF_TEAM: [
      'get_teams', 'send_message_to_staff', 'send_message_to_all_staff',
      'check_availability', 'get_staff_stats',
    ],
    ANALYTICS: [
      'get_top_staff', 'get_staff_stats', 'get_staff_leaderboard',
      'get_top_clients', 'get_revenue_summary', 'get_billing_status',
      'get_event_summary', 'get_busy_periods', 'get_attendance_issues',
      'get_role_demand', 'get_punctuality_report',
    ],
    VENUE_LOCATION: [
      'search_venue', 'get_venues_history',
    ],
  },
  keywords: {
    EVENT_CRUD: [
      'create', 'schedule', 'publish', 'update event', 'modify event',
      'change event', 'edit event', 'invite', 'bulk', 'recurring',
      'new event', 'add event', 'set up', 'book', 'same as',
      'previous event', 'last event', 'copy event', 'duplicate',
      'next week', 'next friday', 'next saturday', 'next sunday',
      'this weekend', 'tomorrow', 'tonight',
      'event for', 'shift for', 'gig for',
      'crear', 'crea ', 'creame', 'agendar', 'publicar', 'modificar evento', 'invitar',
      'nuevo evento', 'mismo que', 'evento anterior',
    ],
    CLIENT_MGMT: [
      'client', 'customer', 'company', 'catering', 'agency',
      'cliente', 'empresa',
    ],
    ROLE_TARIFF: [
      'role', 'tariff', 'rate', 'pay rate', 'pricing', 'hourly',
      'bartender', 'server', 'waiter', 'waitress', 'captain',
      'lead server', 'barback', 'busser', 'hostess', 'host',
      'cook', 'chef', 'dishwasher', 'runner', 'valet',
      'rol', 'tarifa', 'precio',
      'mesero', 'mesera', 'capitan', 'cocinero',
    ],
    STAFF_TEAM: [
      'team', 'staff', 'member', 'message', 'notify', 'send to',
      'tell ', 'broadcast', 'available', 'assign', 'who can',
      'equipo', 'personal', 'mensaje', 'notificar', 'disponible',
    ],
    ANALYTICS: [
      'stats', 'statistic', 'top', 'revenue', 'leaderboard', 'hours',
      'billing', 'demand', 'busy', 'attendance', 'performance', 'best',
      'how many', 'how much', 'earnings', 'earned', 'income',
      'report', 'summary', 'numbers', 'breakdown',
      'punctual', 'punctuality', 'on time', 'late', 'lateness',
      'no-show', 'tardy', 'always late', 'show up',
      'estadistica', 'ingresos', 'horas', 'rendimiento', 'mejor',
      'cuanto', 'reporte', 'resumen',
      'puntual', 'puntualidad', 'a tiempo', 'tarde', 'tardanza', 'inasistencia',
    ],
    VENUE_LOCATION: [
      'venue', 'location', 'address', 'where', 'ballroom', 'hotel',
      'banquet', 'terrace', 'lounge', 'garden', 'hall', 'center',
      'lugar', 'direccion', 'ubicacion', 'salon',
    ],
  },
};

/** Staff tool selection config (10 tools). */
export const STAFF_TOOL_CONFIG: ToolSelectionConfig = {
  coreTools: new Set([
    'get_my_schedule', 'get_shift_details',
  ]),
  categories: {
    SHIFT_ACTION: ['accept_shift', 'decline_shift'],
    AVAILABILITY: ['mark_availability', 'get_my_unavailable_dates'],
    EARNINGS: ['get_earnings_summary', 'get_performance'],
    MESSAGING: ['compose_message', 'send_message_to_manager'],
  },
  keywords: {
    SHIFT_ACTION: [
      'accept', 'decline', 'take it', 'take the', 'i\'ll do',
      'aceptar', 'rechazar', 'tomar',
    ],
    AVAILABILITY: [
      'available', 'unavailable', 'block', 'day off', 'days off',
      'can\'t work', 'cannot work', 'off on', 'busy', 'free on',
      'disponible', 'no disponible', 'no puedo', 'dia libre',
      'ocupado', 'ocupada', 'libre',
    ],
    EARNINGS: [
      'earn', 'income', 'pay', 'money', 'salary', 'wage', 'made',
      'stats', 'performance', 'how much', 'how many hours',
      'hours worked', 'total hours',
      'ganar', 'ingreso', 'pago', 'dinero', 'sueldo', 'cuanto',
    ],
    MESSAGING: [
      'message', 'tell my', 'notify', 'let them know',
      'late', 'call off', 'calling off', 'time off', 'sick',
      'mensaje', 'avisar', 'tarde', 'no puedo ir', 'permiso',
    ],
  },
};

/**
 * Match keywords against text and return matching category names.
 */
function matchCategories(text: string, config: ToolSelectionConfig): Set<string> {
  const lower = text.toLowerCase();
  const matched = new Set<string>();
  for (const [category, keywords] of Object.entries(config.keywords)) {
    if (keywords.some((kw) => lower.includes(kw))) {
      matched.add(category);
    }
  }
  return matched;
}

/**
 * Select a subset of tools relevant to the user's query.
 *
 * Strategy:
 * 1. Match the last user message against keyword categories
 * 2. If no match, try recent conversation context (last 3 user messages combined)
 * 3. Falls back to ALL tools only if neither matches (pure greetings, ambiguous)
 * 4. Force-include EVENT_CRUD when an active event workflow is detected
 */
export function selectToolsForQuery<T extends { name: string }>(
  userMessage: string,
  allTools: T[],
  config: ToolSelectionConfig = MANAGER_TOOL_CONFIG,
  conversationContext?: string,
  messages?: { role: string; content: any }[],
): T[] {
  if (!userMessage || userMessage.trim().length === 0) return allTools;

  // Try matching the last message first
  let matchedCategories = matchCategories(userMessage, config);

  // If no match on the last message alone, try conversation context
  // (catches short follow-ups like "Bartenders", "Yes", "Next Friday")
  if (matchedCategories.size === 0 && conversationContext) {
    matchedCategories = matchCategories(conversationContext, config);
  }

  // Force EVENT_CRUD tools when in an active event workflow
  // (create → publish flow requires get_teams, publish_event, etc.)
  if (messages && isInEventWorkflow(messages)) {
    matchedCategories.add('EVENT_CRUD');
  }

  // Fallback: no categories matched → send everything
  if (matchedCategories.size === 0) return allTools;

  // Build set of tool names to include
  const selectedNames = new Set(config.coreTools);
  for (const category of matchedCategories) {
    for (const toolName of config.categories[category] || []) {
      selectedNames.add(toolName);
    }
  }

  // Filter tools preserving original order
  return allTools.filter((tool) => selectedNames.has(tool.name));
}
