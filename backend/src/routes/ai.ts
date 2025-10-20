import { Router } from 'express';
import { z } from 'zod';
import { requireAuth } from '../middleware/requireAuth';
import axios from 'axios';

const router = Router();

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
      return res.status(400).json({ message: 'Invalid request data', errors: err.errors });
    }
    return res.status(500).json({ message: err.message || 'Failed to extract data' });
  }
});

/**
 * POST /api/ai/chat/message
 * Proxy endpoint for OpenAI chat completions
 * Used for conversational AI event creation
 */
router.post('/ai/chat/message', requireAuth, async (req, res) => {
  try {
    const validated = chatMessageSchema.parse(req.body);
    const { messages, temperature, maxTokens } = validated;

    const openaiKey = process.env.OPENAI_API_KEY;
    if (!openaiKey) {
      console.error('[ai/chat/message] OPENAI_API_KEY not configured');
      return res.status(500).json({ message: 'OpenAI API key not configured on server' });
    }

    const textModel = process.env.OPENAI_TEXT_MODEL || 'gpt-4o';
    const openaiBaseUrl = process.env.OPENAI_BASE_URL || 'https://api.openai.com/v1';

    const requestBody = {
      model: textModel,
      messages,
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
      console.error('[ai/chat/message] OpenAI API error:', response.status, response.data);
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

    return res.json({ content });
  } catch (err: any) {
    console.error('[ai/chat/message] Error:', err);
    if (err instanceof z.ZodError) {
      return res.status(400).json({ message: 'Invalid request data', errors: err.errors });
    }
    if (err.response?.status === 429) {
      return res.status(429).json({
        message: 'OpenAI API rate limit reached. Please try again later.',
      });
    }
    return res.status(500).json({ message: err.message || 'Failed to get AI response' });
  }
});

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
