import { Router } from 'express';
import { z } from 'zod';
import { requireAuth } from '../middleware/requireAuth';
import axios from 'axios';
import geoip from 'geoip-lite';
import multer from 'multer';
import FormData from 'form-data';
import fs from 'fs';
import { getDateTimeContext, getWelcomeDateContext, getFullSystemContext } from '../utils/dateContext';

const router = Router();

// Configure multer for audio file uploads
const upload = multer({
  storage: multer.diskStorage({
    destination: '/tmp',
    filename: (req, file, cb) => {
      const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
      cb(null, `audio-${uniqueSuffix}-${file.originalname}`);
    }
  }),
  limits: {
    fileSize: 25 * 1024 * 1024, // 25MB max (Whisper API limit)
  },
  fileFilter: (req, file, cb) => {
    // Accept all files - let Whisper API validate the format
    // Whisper supports: mp3, mp4, mpeg, mpga, m4a, wav, webm, flac
    // MIME type detection can be unreliable, especially on mobile platforms
    cb(null, true);
  }
});

/**
 * Get the user's timezone from their IP address
 * Falls back to UTC if geolocation fails
 */
function getTimezoneFromRequest(req: any): string {
  try {
    // Get IP address from request
    // Check x-forwarded-for header first (for proxies/load balancers)
    const forwarded = req.headers['x-forwarded-for'];
    let ip = forwarded ? forwarded.split(',')[0].trim() : req.ip || req.connection.remoteAddress;

    // Remove IPv6 prefix if present
    if (ip && ip.startsWith('::ffff:')) {
      ip = ip.substring(7);
    }

    // Skip localhost/private IPs
    if (!ip || ip === '127.0.0.1' || ip === '::1' || ip.startsWith('192.168.') || ip.startsWith('10.')) {
      console.log('[Timezone] Using UTC for localhost/private IP:', ip);
      return 'UTC';
    }

    // Lookup IP geolocation
    const geo = geoip.lookup(ip);

    if (geo?.timezone) {
      console.log(`[Timezone] Detected timezone ${geo.timezone} for IP ${ip}`);
      return geo.timezone;
    }

    console.log(`[Timezone] No timezone found for IP ${ip}, using UTC`);
    return 'UTC';
  } catch (error) {
    console.error('[Timezone] Error detecting timezone:', error);
    return 'UTC';
  }
}

/**
 * GET /api/ai/system-info
 * Returns current date/time context for AI chat welcome messages and system prompts
 * Automatically detects user's timezone from IP address
 * Used by frontend to display contextual greetings
 */
router.get('/ai/system-info', requireAuth, async (req, res) => {
  try {
    const timezone = getTimezoneFromRequest(req);

    return res.json({
      dateTimeContext: getDateTimeContext(timezone),
      welcomeContext: getWelcomeDateContext(timezone),
      fullContext: getFullSystemContext(timezone),
      detectedTimezone: timezone,
    });
  } catch (err: any) {
    console.error('[ai/system-info] Error:', err);
    return res.status(500).json({ message: 'Failed to get system info' });
  }
});

/**
 * POST /api/ai/transcribe
 * Transcribe audio to text using OpenAI Whisper API
 * Accepts audio file upload and returns transcribed text
 */
router.post('/ai/transcribe', requireAuth, upload.single('audio'), async (req, res) => {
  let tempFilePath: string | null = null;

  try {
    if (!req.file) {
      return res.status(400).json({ message: 'No audio file provided' });
    }

    tempFilePath = req.file.path;

    const openaiKey = process.env.OPENAI_API_KEY;
    if (!openaiKey) {
      console.error('[ai/transcribe] OPENAI_API_KEY not configured');
      return res.status(500).json({ message: 'OpenAI API key not configured on server' });
    }

    const openaiBaseUrl = process.env.OPENAI_BASE_URL || 'https://api.openai.com/v1';

    // Create form data for Whisper API
    const formData = new FormData();
    formData.append('file', fs.createReadStream(tempFilePath), {
      filename: req.file.originalname,
      contentType: req.file.mimetype,
    });
    formData.append('model', 'whisper-1');

    // Auto-detect language (supports English, Spanish, and 96 other languages)
    // By not specifying 'language', Whisper will detect it automatically
    // This allows Spanish-speaking users to use voice input naturally

    // Add domain-specific prompt to improve accuracy for event staffing terminology
    const domainPrompt = `Event staffing and catering terminology including:
venues, clients, roles like server bartender captain sous chef,
dates, times, headcount, call time, setup time, uniform,
common client names and venue names`;
    formData.append('prompt', domainPrompt);

    const headers: any = {
      'Authorization': `Bearer ${openaiKey}`,
      ...formData.getHeaders(),
    };

    const orgId = process.env.OPENAI_ORG_ID;
    if (orgId) {
      headers['OpenAI-Organization'] = orgId;
    }

    console.log('[ai/transcribe] Calling Whisper API...');

    const response = await axios.post(
      `${openaiBaseUrl}/audio/transcriptions`,
      formData,
      { headers, validateStatus: () => true }
    );

    // Clean up temp file
    if (tempFilePath) {
      fs.unlinkSync(tempFilePath);
      tempFilePath = null;
    }

    if (response.status >= 300) {
      console.error('[ai/transcribe] Whisper API error:', response.status, response.data);
      if (response.status === 429) {
        return res.status(429).json({
          message: 'OpenAI API rate limit reached. Please try again later.',
        });
      }
      return res.status(response.status).json({
        message: `Whisper API error: ${response.statusText}`,
        details: response.data,
      });
    }

    const transcribedText = response.data.text;
    if (!transcribedText) {
      return res.status(500).json({ message: 'Failed to transcribe audio' });
    }

    console.log('[ai/transcribe] Transcription successful:', transcribedText.substring(0, 100));

    return res.json({
      text: transcribedText,
      duration: response.data.duration || null,
    });
  } catch (err: any) {
    // Clean up temp file on error
    if (tempFilePath && fs.existsSync(tempFilePath)) {
      try {
        fs.unlinkSync(tempFilePath);
      } catch (unlinkErr) {
        console.error('[ai/transcribe] Failed to delete temp file:', unlinkErr);
      }
    }

    console.error('[ai/transcribe] Error:', err);
    if (err.code === 'LIMIT_FILE_SIZE') {
      return res.status(413).json({ message: 'Audio file too large. Maximum size is 25MB.' });
    }
    return res.status(500).json({ message: err.message || 'Failed to transcribe audio' });
  }
});

// Schema for extraction request
const extractionSchema = z.object({
  input: z.string().min(1, 'input is required'),
  isImage: z.boolean().optional().default(false),
});

// Schema for chat message request
const chatMessageSchema = z.object({
  messages: z.array(
    z.object({
      role: z.enum(['system', 'user', 'assistant']),
      content: z.union([
        z.string(),
        z.array(
          z.object({
            type: z.string(),
            text: z.string().optional(),
            image_url: z.object({ url: z.string() }).optional(),
          })
        ),
      ]),
    })
  ),
  temperature: z.number().optional().default(0.7),
  maxTokens: z.number().optional().default(500),
  provider: z.enum(['openai', 'claude', 'groq']).optional().default('groq'),
  model: z.string().optional(), // Optional model override for Groq
});

/**
 * Function/Tool definitions for AI models
 * These enable both OpenAI and Claude to query database information
 */
const AI_TOOLS = [
  {
    name: 'search_addresses',
    description: 'Search venue addresses from existing events in the database. Use this when users ask about addresses, venues, or locations.',
    parameters: {
      type: 'object',
      properties: {
        query: {
          type: 'string',
          description: 'Search query - can be venue name, address, city, or any location-related term'
        },
        client_name: {
          type: 'string',
          description: 'Optional: Filter results by client name'
        }
      },
      required: ['query']
    }
  },
  {
    name: 'search_events',
    description: 'Find events by various criteria from the database. Use this when users ask about specific events, dates, or want to see event lists.',
    parameters: {
      type: 'object',
      properties: {
        client_name: {
          type: 'string',
          description: 'Filter by client name'
        },
        date: {
          type: 'string',
          description: 'ISO date (YYYY-MM-DD) or month filter (e.g., "2024-03")'
        },
        venue_name: {
          type: 'string',
          description: 'Filter by venue name'
        },
        event_name: {
          type: 'string',
          description: 'Search by event name'
        }
      }
    }
  },
  {
    name: 'check_availability',
    description: 'Check team member availability for a specific date and time. Use this when users ask about staff availability or scheduling.',
    parameters: {
      type: 'object',
      properties: {
        date: {
          type: 'string',
          description: 'ISO date (YYYY-MM-DD) to check availability'
        },
        role: {
          type: 'string',
          description: 'Optional: Filter by specific role (e.g., "Server", "Bartender")'
        },
        member_name: {
          type: 'string',
          description: 'Optional: Check specific team member by name'
        }
      },
      required: ['date']
    }
  },
  {
    name: 'get_client_info',
    description: 'Get detailed information about a specific client including their events and tariffs.',
    parameters: {
      type: 'object',
      properties: {
        client_name: {
          type: 'string',
          description: 'The name of the client to look up'
        }
      },
      required: ['client_name']
    }
  }
];

/**
 * POST /api/ai/extract
 * Proxy endpoint for OpenAI-based document extraction
 * Accepts text or base64 image input and returns structured event data
 */
router.post('/ai/extract', requireAuth, async (req, res) => {
  try {
    const validated = extractionSchema.parse(req.body);
    const { input, isImage } = validated;

    const openaiKey = process.env.OPENAI_API_KEY;
    if (!openaiKey) {
      console.error('[ai/extract] OPENAI_API_KEY not configured');
      return res.status(500).json({ message: 'OpenAI API key not configured on server' });
    }

    const visionModel = process.env.OPENAI_VISION_MODEL || 'gpt-4o-mini';
    const textModel = process.env.OPENAI_TEXT_MODEL || 'gpt-4o';
    const openaiBaseUrl = process.env.OPENAI_BASE_URL || 'https://api.openai.com/v1';

    const systemPrompt =
      'You are a structured information extractor for catering event staffing. Extract fields: event_name, client_name, date (ISO 8601), start_time, end_time, venue_name, venue_address, city, state, country, contact_name, contact_phone, contact_email, setup_time, uniform, notes, headcount_total, roles (list of {role, count, call_time}), pay_rate_info. Return strict JSON.';

    let requestBody: any;
    if (isImage) {
      // Input is base64 image
      requestBody = {
        model: visionModel,
        messages: [
          { role: 'system', content: systemPrompt },
          {
            role: 'user',
            content: [
              {
                type: 'text',
                text: 'Extract structured event staffing info and return only JSON.',
              },
              {
                type: 'image_url',
                image_url: { url: `data:image/png;base64,${input}` },
              },
            ],
          },
        ],
        temperature: 0,
        max_tokens: 800,
      };
    } else {
      // Input is text
      requestBody = {
        model: textModel,
        messages: [
          { role: 'system', content: systemPrompt },
          {
            role: 'user',
            content: `Extract JSON from the following text:\n\n${input}`,
          },
        ],
        temperature: 0,
        max_tokens: 800,
      };
    }

    const headers: any = {
      'Authorization': `Bearer ${openaiKey}`,
      'Content-Type': 'application/json',
    };

    const orgId = process.env.OPENAI_ORG_ID;
    if (orgId) {
      headers['OpenAI-Organization'] = orgId;
    }

    // Call OpenAI with retries
    const response = await callOpenAIWithRetries(
      `${openaiBaseUrl}/chat/completions`,
      headers,
      requestBody
    );

    if (response.status >= 300) {
      console.error('[ai/extract] OpenAI API error:', response.status, response.data);
      if (response.status === 429) {
        return res.status(429).json({
          message: 'OpenAI API rate limit or quota exceeded. Please try again later.',
        });
      }
      return res.status(response.status).json({
        message: `OpenAI API error: ${response.statusText}`,
      });
    }

    const content = response.data.choices?.[0]?.message?.content || '';

    // Extract JSON from response
    const start = content.indexOf('{');
    const end = content.lastIndexOf('}');
    if (start !== -1 && end !== -1 && end > start) {
      const jsonSlice = content.substring(start, end + 1);
      try {
        const parsed = JSON.parse(jsonSlice);
        return res.json(parsed);
      } catch (parseErr) {
        console.error('[ai/extract] Failed to parse JSON:', parseErr);
        return res.status(500).json({ message: 'Failed to parse response from OpenAI' });
      }
    }

    return res.status(500).json({ message: 'No valid JSON found in OpenAI response' });
  } catch (err: any) {
    console.error('[ai/extract] Error:', err);
    if (err instanceof z.ZodError) {
      return res.status(400).json({ message: 'Invalid request data', errors: err.issues });
    }
    return res.status(500).json({ message: err.message || 'Failed to extract data' });
  }
});

/**
 * POST /api/ai/chat/message
 * Proxy endpoint for AI chat completions (OpenAI or Claude)
 * Used for conversational AI event creation
 */
router.post('/ai/chat/message', requireAuth, async (req, res) => {
  try {
    const validated = chatMessageSchema.parse(req.body);
    const { messages, temperature, maxTokens, provider, model } = validated;

    console.log(`[ai/chat/message] Using provider: ${provider}, model: ${model || 'default'}`);

    // Detect user's timezone from IP
    const timezone = getTimezoneFromRequest(req);

    if (provider === 'claude') {
      return await handleClaudeRequest(messages, temperature, maxTokens, res, timezone);
    } else if (provider === 'groq') {
      return await handleGroqRequest(messages, temperature, maxTokens, res, timezone, model);
    } else {
      return await handleOpenAIRequest(messages, temperature, maxTokens, res, timezone);
    }
  } catch (err: any) {
    console.error('[ai/chat/message] Error:', err);
    if (err instanceof z.ZodError) {
      return res.status(400).json({ message: 'Invalid request data', errors: err.issues });
    }
    if (err.response?.status === 429) {
      return res.status(429).json({
        message: 'AI API rate limit reached. Please try again later.',
      });
    }
    return res.status(500).json({ message: err.message || 'Failed to get AI response' });
  }
});

/**
 * Handle OpenAI chat request
 */
async function handleOpenAIRequest(
  messages: any[],
  temperature: number,
  maxTokens: number,
  res: any,
  timezone?: string
) {
  const openaiKey = process.env.OPENAI_API_KEY;
  if (!openaiKey) {
    console.error('[OpenAI] API key not configured');
    return res.status(500).json({ message: 'OpenAI API key not configured on server' });
  }

  const textModel = process.env.OPENAI_TEXT_MODEL || 'gpt-4o';
  const openaiBaseUrl = process.env.OPENAI_BASE_URL || 'https://api.openai.com/v1';

  // Inject date/time context into system messages with user's timezone
  const dateContext = getFullSystemContext(timezone);
  const enhancedMessages = messages.map((msg, index) => {
    // Add date context to the first system message
    if (msg.role === 'system' && index === 0) {
      return {
        ...msg,
        content: `${dateContext}\n\n${msg.content}`
      };
    }
    // If no system message exists, add one at the beginning
    return msg;
  });

  // If there's no system message, prepend one with date context
  const hasSystemMessage = messages.some(msg => msg.role === 'system');
  const finalMessages = hasSystemMessage
    ? enhancedMessages
    : [{ role: 'system', content: dateContext }, ...messages];

  const requestBody = {
    model: textModel,
    messages: finalMessages,
    temperature,
    max_tokens: maxTokens,
    tools: AI_TOOLS.map(tool => ({
      type: 'function',
      function: {
        name: tool.name,
        description: tool.description,
        parameters: tool.parameters,
      }
    })),
    tool_choice: 'auto', // Allow model to choose when to use tools
  };

  const headers: any = {
    'Authorization': `Bearer ${openaiKey}`,
    'Content-Type': 'application/json',
  };

  const orgId = process.env.OPENAI_ORG_ID;
  if (orgId) {
    headers['OpenAI-Organization'] = orgId;
  }

  const response = await axios.post(
    `${openaiBaseUrl}/chat/completions`,
    requestBody,
    { headers }
  );

  if (response.status >= 300) {
    console.error('[OpenAI] API error:', response.status, response.data);
    if (response.status === 429) {
      return res.status(429).json({
        message: 'OpenAI API rate limit reached. Please try again later.',
      });
    }
    return res.status(response.status).json({
      message: `OpenAI API error: ${response.statusText}`,
    });
  }

  const message = response.data.choices?.[0]?.message;
  const content = message?.content;
  const toolCalls = message?.tool_calls;

  // If model wants to call a function/tool
  if (toolCalls && toolCalls.length > 0) {
    console.log('[OpenAI] Tool calls requested:', JSON.stringify(toolCalls, null, 2));

    // For now, return a message indicating the tool call
    // The frontend context already contains the data, so we'll format a response
    const toolCall = toolCalls[0];
    const functionName = toolCall.function?.name;
    const functionArgs = JSON.parse(toolCall.function?.arguments || '{}');

    // Note: The data is already in the system context, so we tell the model
    // This is a simplified approach - in production you'd execute the function
    const toolResponse = `The information you requested is already in the context provided above. Please review the "Existing Events" and "Team Members" sections in your system context to answer the user's query about ${functionName}.`;

    return res.json({
      content: toolResponse,
      provider: 'openai',
      toolCall: { name: functionName, arguments: functionArgs }
    });
  }

  if (!content) {
    return res.status(500).json({ message: 'Failed to get response from OpenAI' });
  }

  return res.json({ content, provider: 'openai' });
}

/**
 * Handle Claude chat request with prompt caching
 */
async function handleClaudeRequest(
  messages: any[],
  temperature: number,
  maxTokens: number,
  res: any,
  timezone?: string
) {
  const claudeKey = process.env.CLAUDE_API_KEY;
  if (!claudeKey) {
    console.error('[Claude] API key not configured');
    return res.status(500).json({ message: 'Claude API key not configured on server' });
  }

  const claudeModel = process.env.CLAUDE_MODEL || 'claude-sonnet-4-5-20250929';
  const claudeBaseUrl = process.env.CLAUDE_BASE_URL || 'https://api.anthropic.com/v1';

  // Convert OpenAI-style messages to Claude format
  // System message goes in separate 'system' parameter with cache_control
  let systemMessage = '';
  const userMessages: any[] = [];

  // Inject date/time context at the beginning of system message with user's timezone
  const dateContext = getFullSystemContext(timezone);
  systemMessage = `${dateContext}\n\n`;

  for (const msg of messages) {
    if (msg.role === 'system') {
      systemMessage += (systemMessage ? '\n\n' : '') + msg.content;
    } else {
      userMessages.push({
        role: msg.role === 'assistant' ? 'assistant' : 'user',
        content: typeof msg.content === 'string' ? msg.content : JSON.stringify(msg.content),
      });
    }
  }

  // Add cache_control to system message for prompt caching
  // This caches the instructions and context, dramatically reducing costs by up to 90%
  const requestBody = {
    model: claudeModel,
    max_tokens: maxTokens,
    temperature,
    system: systemMessage ? [
      {
        type: 'text',
        text: systemMessage,
        cache_control: { type: 'ephemeral' }, // Enable prompt caching
      },
    ] : 'You are a helpful AI assistant for event staffing.',
    messages: userMessages,
    tools: AI_TOOLS.map(tool => ({
      name: tool.name,
      description: tool.description,
      input_schema: tool.parameters,
    })),
  };

  const headers = {
    'x-api-key': claudeKey,
    'anthropic-version': '2023-06-01',
    'anthropic-beta': 'prompt-caching-2024-07-31', // Enable caching beta
    'Content-Type': 'application/json',
  };

  console.log('[Claude] Calling API with prompt caching enabled...');

  const response = await axios.post(
    `${claudeBaseUrl}/messages`,
    requestBody,
    { headers, validateStatus: () => true }
  );

  if (response.status >= 300) {
    console.error('[Claude] API error:', response.status, response.data);
    if (response.status === 429) {
      return res.status(429).json({
        message: 'Claude API rate limit reached. Please try again later.',
      });
    }
    return res.status(response.status).json({
      message: `Claude API error: ${response.statusText}`,
      details: response.data,
    });
  }

  // Log cache usage statistics
  const usage = response.data.usage;
  if (usage) {
    console.log('[Claude] Token usage:', {
      input: usage.input_tokens,
      output: usage.output_tokens,
      cache_creation: usage.cache_creation_input_tokens || 0,
      cache_read: usage.cache_read_input_tokens || 0,
    });

    // Calculate cost savings from caching
    if (usage.cache_read_input_tokens > 0) {
      const savings = ((usage.cache_read_input_tokens / (usage.input_tokens + usage.cache_read_input_tokens)) * 100).toFixed(1);
      console.log(`[Claude] Prompt caching saved ${savings}% on input tokens`);
    }
  }

  const contentBlocks = response.data.content;
  if (!contentBlocks || contentBlocks.length === 0) {
    return res.status(500).json({ message: 'Failed to get response from Claude' });
  }

  // Check if Claude wants to use a tool
  const toolUseBlock = contentBlocks.find((block: any) => block.type === 'tool_use');
  if (toolUseBlock) {
    console.log('[Claude] Tool use requested:', JSON.stringify(toolUseBlock, null, 2));

    const toolName = toolUseBlock.name;
    const toolInput = toolUseBlock.input;

    // Note: The data is already in the system context, so we tell the model
    // This is a simplified approach - in production you'd execute the function
    const toolResponse = `The information you requested is already in the context provided above. Please review the "Existing Events" and "Team Members" sections in your system context to answer the user's query about ${toolName}.`;

    return res.json({
      content: toolResponse,
      provider: 'claude',
      usage: usage,
      toolCall: { name: toolName, input: toolInput }
    });
  }

  // Extract text content
  const textBlock = contentBlocks.find((block: any) => block.type === 'text');
  const content = textBlock?.text;

  if (!content) {
    return res.status(500).json({ message: 'Failed to get text response from Claude' });
  }

  return res.json({
    content,
    provider: 'claude',
    usage: usage, // Include usage stats for monitoring
  });
}

/**
 * Handle Groq chat request with Responses API
 * Uses the /v1/responses endpoint (NOT /chat/completions)
 * Cost-optimized alternative to OpenAI/Claude
 */
async function handleGroqRequest(
  messages: any[],
  temperature: number,
  maxTokens: number,
  res: any,
  timezone?: string,
  model?: string
) {
  try {
    const groqKey = process.env.GROQ_API_KEY;
    if (!groqKey) {
      console.error('[Groq] API key not configured');
      return res.status(500).json({ message: 'Groq API key not configured on server' });
    }

    // Use provided model or fall back to env variable or default
    const groqModel = model || process.env.GROQ_MODEL || 'llama-3.1-8b-instant';
    // Hardcode the base URL for Groq Responses API (don't use GROQ_BASE_URL which is for Whisper)
    const groqBaseUrl = 'https://api.groq.com/openai';

    console.log(`[Groq] Using model: ${groqModel}`);

  // Convert messages to Groq Responses API format
  // System message is included in input array with role 'system'
  const dateContext = getFullSystemContext(timezone);

  // Build input array for Groq (includes system message as first message)
  const inputMessages: any[] = [];

  // Find or create system message with date context
  let hasSystemMessage = false;
  for (const msg of messages) {
    if (msg.role === 'system') {
      inputMessages.push({
        role: 'system',
        content: `${dateContext}\n\n${msg.content}`
      });
      hasSystemMessage = true;
    } else {
      inputMessages.push({
        role: msg.role,
        content: typeof msg.content === 'string' ? msg.content : JSON.stringify(msg.content)
      });
    }
  }

  // If no system message exists, prepend one with date context
  if (!hasSystemMessage) {
    inputMessages.unshift({
      role: 'system',
      content: dateContext
    });
  }

  // Groq uses OpenAI-compatible tool structure (nested format)
  const groqTools = AI_TOOLS.map(tool => ({
    type: 'function',
    function: {
      name: tool.name,
      description: tool.description,
      parameters: tool.parameters
    }
  }));

  const requestBody = {
    model: groqModel,
    input: inputMessages, // Groq uses 'input' not 'messages'
    temperature,
    max_output_tokens: maxTokens, // Responses API uses max_output_tokens
    tools: groqTools,
  };

  const headers = {
    'Authorization': `Bearer ${groqKey}`,
    'Content-Type': 'application/json',
  };

  console.log('[Groq] Calling Responses API...');

  const response = await axios.post(
    `${groqBaseUrl}/v1/responses`,
    requestBody,
    { headers, validateStatus: () => true }
  );

  if (response.status >= 300) {
    console.error('[Groq] API error:', response.status, response.data);
    if (response.status === 429) {
      return res.status(429).json({
        message: 'Groq API rate limit reached. Please try again later.',
      });
    }
    return res.status(response.status).json({
      message: `Groq API error: ${response.statusText}`,
      details: response.data,
    });
  }

  // Groq Responses API returns output blocks
  const outputBlocks = response.data.output;
  if (!outputBlocks || outputBlocks.length === 0) {
    return res.status(500).json({ message: 'Failed to get response from Groq' });
  }

  // Check for function calls
  const functionCallBlock = outputBlocks.find((block: any) => block.type === 'function_call');
  if (functionCallBlock) {
    console.log('[Groq] Function call requested:', JSON.stringify(functionCallBlock, null, 2));

    const functionName = functionCallBlock.name;
    const functionArgs = functionCallBlock.arguments;

    // Note: The data is already in the system context, so we tell the model
    // This is a simplified approach - in production you'd execute the function
    const toolResponse = `The information you requested is already in the context provided above. Please review the "Existing Events" and "Team Members" sections in your system context to answer the user's query about ${functionName}.`;

    // For function results, Groq Responses API does NOT support role: 'function'
    // Instead, format as a user message
    const messagesWithFunctionResult = [
      ...inputMessages,
      {
        role: 'assistant',
        content: functionCallBlock.text || ''
      },
      {
        role: 'user',
        content: `Function ${functionName} returned: ${toolResponse}\n\nPlease present this naturally.`
      }
    ];

    // Second request - NO tools array, NO previous_response_id
    const secondResponse = await axios.post(
      `${groqBaseUrl}/v1/responses`,
      {
        model: groqModel,
        input: messagesWithFunctionResult,
        temperature,
        max_output_tokens: maxTokens, // Responses API uses max_output_tokens
      },
      { headers, validateStatus: () => true }
    );

    if (secondResponse.status >= 300) {
      console.error('[Groq] Second API call error:', secondResponse.status, secondResponse.data);
      return res.status(secondResponse.status).json({
        message: `Groq API error: ${secondResponse.statusText}`,
        details: secondResponse.data,
      });
    }

    const secondOutput = secondResponse.data.output;
    const textBlock = secondOutput?.find((block: any) => block.type === 'text');
    const finalContent = textBlock?.text;

    if (!finalContent) {
      return res.status(500).json({ message: 'Failed to get final response from Groq' });
    }

    return res.json({
      content: finalContent,
      provider: 'groq',
      toolCall: { name: functionName, arguments: functionArgs }
    });
  }

  // Extract text content
  const textBlock = outputBlocks.find((block: any) => block.type === 'text');
  const content = textBlock?.text;

  if (!content) {
    return res.status(500).json({ message: 'Failed to get text response from Groq' });
  }

    return res.json({
      content,
      provider: 'groq',
    });
  } catch (error: any) {
    // Enhanced error logging for Groq API failures
    console.error('[Groq] Request failed with error:', {
      message: error.message,
      status: error.response?.status,
      statusText: error.response?.statusText,
      data: error.response?.data,
      stack: error.stack
    });

    return res.status(500).json({
      message: 'Groq API request failed',
      error: error.message,
      details: error.response?.data || error.message
    });
  }
}

/**
 * Helper function to call OpenAI API with exponential backoff retries
 */
async function callOpenAIWithRetries(
  url: string,
  headers: any,
  body: any,
  maxAttempts = 3
): Promise<any> {
  let attempt = 0;
  while (attempt < maxAttempts) {
    attempt++;
    try {
      const response = await axios.post(url, body, { headers, validateStatus: () => true });

      if (response.status === 429 || response.status >= 500) {
        if (attempt < maxAttempts) {
          const backoffSeconds = Math.pow(2, attempt - 1);
          console.log(`[OpenAI] Retry attempt ${attempt}/${maxAttempts} after ${backoffSeconds}s`);
          await new Promise((resolve) => setTimeout(resolve, backoffSeconds * 1000));
          continue;
        }
      }

      return response;
    } catch (error) {
      if (attempt >= maxAttempts) {
        throw error;
      }
      const backoffSeconds = Math.pow(2, attempt - 1);
      console.log(`[OpenAI] Error, retry attempt ${attempt}/${maxAttempts} after ${backoffSeconds}s`);
      await new Promise((resolve) => setTimeout(resolve, backoffSeconds * 1000));
    }
  }
  throw new Error('Max retry attempts reached');
}

export default router;
