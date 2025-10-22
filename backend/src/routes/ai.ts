import { Router } from 'express';
import { z } from 'zod';
import { requireAuth } from '../middleware/requireAuth';
import axios from 'axios';
import geoip from 'geoip-lite';
import { getDateTimeContext, getWelcomeDateContext, getFullSystemContext } from '../utils/dateContext';

const router = Router();

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
  provider: z.enum(['openai', 'claude']).optional().default('openai'),
});

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
    const textModel = process.env.OPENAI_TEXT_MODEL || 'gpt-4o-mini';
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
    const { messages, temperature, maxTokens, provider } = validated;

    console.log(`[ai/chat/message] Using provider: ${provider}`);

    // Detect user's timezone from IP
    const timezone = getTimezoneFromRequest(req);

    if (provider === 'claude') {
      return await handleClaudeRequest(messages, temperature, maxTokens, res, timezone);
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

  const textModel = process.env.OPENAI_TEXT_MODEL || 'gpt-4o-mini';
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

  const content = response.data.choices?.[0]?.message?.content;
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

  const content = response.data.content?.[0]?.text;
  if (!content) {
    return res.status(500).json({ message: 'Failed to get response from Claude' });
  }

  return res.json({
    content,
    provider: 'claude',
    usage: usage, // Include usage stats for monitoring
  });
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
