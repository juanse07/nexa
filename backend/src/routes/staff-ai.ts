import { Router } from 'express';
import { z } from 'zod';
import mongoose from 'mongoose';
import { requireAuth } from '../middleware/requireAuth';
import { requireActiveSubscription } from '../middleware/requireActiveSubscription';
import { isInFreeMonth } from '../utils/subscriptionUtils';
import axios from 'axios';
import geoip from 'geoip-lite';
import multer from 'multer';
import FormData from 'form-data';
import fs from 'fs';
import { getDateTimeContext, getWelcomeDateContext, getFullSystemContext } from '../utils/dateContext';
import { getProviderConfig } from '../utils/aiProvider';
import { extractLastUserMessage } from '../utils/cascadeRouter';
import { EventModel } from '../models/event';
import { UserModel } from '../models/user';
import { AvailabilityModel } from '../models/availability';
import { PersonalEventModel } from '../models/personalEvent';
import { TeamMemberModel } from '../models/teamMember';
import { ConversationModel } from '../models/conversation';
import { ChatMessageModel } from '../models/chatMessage';
import { ManagerModel } from '../models/manager';
import { emitToManager } from '../socket/server';
import { computeRoleStats } from '../utils/eventCapacity';
import { logAIUsage } from '../utils/logAIUsage';
import { enrichEventsWithTariffs } from './events';

const router = Router();

// Configure multer for audio file uploads (same as manager AI)
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
    cb(null, true);
  }
});

/**
 * Get the user's timezone from their IP address
 * Falls back to UTC if geolocation fails
 */
function getTimezoneFromRequest(req: any): string {
  try {
    const forwarded = req.headers['x-forwarded-for'];
    let ip = forwarded ? forwarded.split(',')[0].trim() : req.ip || req.connection.remoteAddress;

    if (ip && ip.startsWith('::ffff:')) {
      ip = ip.substring(7);
    }

    if (!ip || ip === '127.0.0.1' || ip === '::1' || ip.startsWith('192.168.') || ip.startsWith('10.')) {
      console.log('[Timezone] Using UTC for localhost/private IP:', ip);
      return 'UTC';
    }

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
 * GET /api/ai/staff/system-info
 * Returns current date/time context for staff AI chat
 */
router.get('/ai/staff/system-info', requireAuth, async (req, res) => {
  try {
    const timezone = getTimezoneFromRequest(req);

    return res.json({
      dateTimeContext: getDateTimeContext(timezone),
      welcomeContext: getWelcomeDateContext(timezone),
      fullContext: getFullSystemContext(timezone),
      detectedTimezone: timezone,
    });
  } catch (err: any) {
    console.error('[ai/staff/system-info] Error:', err);
    return res.status(500).json({ message: 'Failed to get system info' });
  }
});

/**
 * POST /api/ai/staff/extract
 * Groq-powered extraction endpoint for personal events:
 * - Images: Llama 4 Scout 17B vision model
 * - Text/PDFs: Llama 3.1 8B Instant text model
 * Accepts text or base64 image input and returns structured personal event data
 */
const staffExtractionSchema = z.object({
  input: z.string().min(1, 'input is required'),
  isImage: z.boolean().optional().default(false),
  multi: z.boolean().optional().default(false),
});

router.post('/ai/staff/extract', requireAuth, async (req, res) => {
  try {
    const validated = staffExtractionSchema.parse(req.body);
    const { input, isImage, multi } = validated;

    const groqKey = process.env.GROQ_API_KEY;
    if (!groqKey) {
      console.error('[ai/staff/extract] GROQ_API_KEY not configured');
      return res.status(500).json({ message: 'Groq API key not configured on server' });
    }

    const visionModel = 'meta-llama/llama-4-scout-17b-16e-instruct';
    const textModel = 'llama-3.1-8b-instant';
    const groqBaseUrl = 'https://api.groq.com/openai/v1';

    const singlePrompt =
      'You are a structured information extractor for personal work events. ' +
      'Extract fields: title, date (YYYY-MM-DD), start_time (HH:mm), end_time (HH:mm), ' +
      'role, client, hourly_rate (number), currency (string, e.g. "USD"), location, notes. ' +
      'Return strict JSON only. Use null for missing fields. Do not include any text outside the JSON object.';

    const multiPrompt =
      'You are a structured information extractor for work schedules. ' +
      'The document may contain MULTIPLE shifts/events. Extract ALL of them. ' +
      'For each event extract: title, date (YYYY-MM-DD), start_time (HH:mm), end_time (HH:mm), ' +
      'role, client, hourly_rate (number), currency (string, e.g. "USD"), location, notes. ' +
      'Return a JSON ARRAY of objects. Use null for missing fields. ' +
      'Do not include any text outside the JSON array. Example: [{...}, {...}]';

    const systemPrompt = multi ? multiPrompt : singlePrompt;

    const maxTokens = multi ? 4000 : 800;
    const userText = multi
      ? 'Extract ALL shifts/events from this document and return a JSON array.'
      : 'Extract structured personal event info and return only JSON.';

    let requestBody: any;
    if (isImage) {
      requestBody = {
        model: visionModel,
        messages: [
          { role: 'system', content: systemPrompt },
          {
            role: 'user',
            content: [
              { type: 'text', text: userText },
              {
                type: 'image_url',
                image_url: { url: `data:image/png;base64,${input}` },
              },
            ],
          },
        ],
        temperature: 0,
        max_tokens: maxTokens,
      };
    } else {
      requestBody = {
        model: textModel,
        messages: [
          { role: 'system', content: systemPrompt },
          {
            role: 'user',
            content: `${userText}\n\n${input}`,
          },
        ],
        temperature: 0,
        max_tokens: maxTokens,
      };
    }

    const headers = {
      'Authorization': `Bearer ${groqKey}`,
      'Content-Type': 'application/json',
    };

    // Call Groq API with retries
    let response: any;
    for (let attempt = 1; attempt <= 3; attempt++) {
      try {
        response = await axios.post(`${groqBaseUrl}/chat/completions`, requestBody, {
          headers,
          validateStatus: () => true,
        });
        if (response.status !== 429 && response.status < 500) break;
        if (attempt < 3) {
          await new Promise(r => setTimeout(r, Math.pow(2, attempt - 1) * 1000));
        }
      } catch (err) {
        if (attempt >= 3) throw err;
        await new Promise(r => setTimeout(r, Math.pow(2, attempt - 1) * 1000));
      }
    }

    if (response.status >= 300) {
      console.error(`[ai/staff/extract] Groq API error:`, response.status);
      console.error(`[ai/staff/extract] Error details:`, JSON.stringify(response.data, null, 2));
      if (response.status === 429) {
        return res.status(429).json({
          message: 'AI rate limit exceeded. Please try again later.',
        });
      }
      return res.status(response.status).json({
        message: `Groq API error: ${response.statusText}`,
        details: response.data,
      });
    }

    const content = response.data.choices?.[0]?.message?.content || '';

    // Try to extract JSON — array first (for multi), then single object
    const arrStart = content.indexOf('[');
    const arrEnd = content.lastIndexOf(']');
    const objStart = content.indexOf('{');
    const objEnd = content.lastIndexOf('}');

    let parsed: any = null;

    // Attempt array parse first (covers multi mode)
    if (arrStart !== -1 && arrEnd !== -1 && arrEnd > arrStart) {
      try {
        parsed = JSON.parse(content.substring(arrStart, arrEnd + 1));
      } catch (_) { /* fall through to object parse */ }
    }

    // Attempt single object parse
    if (!parsed && objStart !== -1 && objEnd !== -1 && objEnd > objStart) {
      try {
        parsed = JSON.parse(content.substring(objStart, objEnd + 1));
      } catch (parseErr) {
        console.error('[ai/staff/extract] Failed to parse JSON:', parseErr);
        return res.status(500).json({ message: 'Failed to parse response from AI' });
      }
    }

    if (!parsed) {
      return res.status(500).json({ message: 'No valid JSON found in AI response' });
    }

    // Normalize response shape based on multi flag
    if (multi) {
      const arr = Array.isArray(parsed) ? parsed : [parsed];
      return res.json({ extracted: arr });
    } else {
      // Backward compatible: single object
      const single = Array.isArray(parsed) ? parsed[0] : parsed;
      return res.json({ extracted: single });
    }
  } catch (err: any) {
    console.error('[ai/staff/extract] Error:', err);
    if (err instanceof z.ZodError) {
      return res.status(400).json({ message: 'Invalid request data', errors: err.issues });
    }
    return res.status(500).json({ message: err.message || 'Failed to extract data' });
  }
});

/**
 * POST /api/ai/staff/reset-limits (ADMIN)
 * Reset AI message limits for all users (for testing/admin purposes)
 */
router.post('/ai/staff/reset-limits', async (req, res) => {
  try {
    const result = await UserModel.updateMany(
      {},
      { $set: { ai_messages_used_this_month: 0 } }
    );

    return res.json({
      success: true,
      message: `Reset AI message limits for ${result.modifiedCount} users`,
      matched: result.matchedCount,
      modified: result.modifiedCount,
    });
  } catch (err: any) {
    console.error('[ai/staff/reset-limits] Error:', err);
    return res.status(500).json({ message: err.message });
  }
});

/**
 * POST /api/ai/staff/transcribe
 * Transcribe audio to text using Groq Whisper API (fast & cheap!)
 * Accepts audio file upload and optional terminology parameter
 * Same as manager transcription but scoped to staff
 */
router.post('/ai/staff/transcribe', requireAuth, upload.single('audio'), async (req, res) => {
  let tempFilePath: string | null = null;
  const transcribeStartTime = Date.now();

  try {
    if (!req.file) {
      return res.status(400).json({ message: 'No audio file provided' });
    }

    tempFilePath = req.file.path;

    const groqKey = process.env.GROQ_API_KEY;
    if (!groqKey) {
      console.error('[ai/staff/transcribe] GROQ_API_KEY not configured');
      return res.status(500).json({ message: 'Groq API key not configured on server' });
    }

    // Get user's terminology preference (jobs, shifts, or events)
    // Defaults to 'shifts' if not provided
    const terminology = (req.body.terminology || 'shifts').toLowerCase();
    const singularTerm = terminology.endsWith('s') ? terminology.slice(0, -1) : terminology;

    console.log(`[ai/staff/transcribe] Using terminology: ${terminology} (singular: ${singularTerm})`);

    const groqWhisperUrl = 'https://api.groq.com/openai/v1';

    const formData = new FormData();
    formData.append('file', fs.createReadStream(tempFilePath), {
      filename: req.file.originalname,
      contentType: req.file.mimetype,
    });
    formData.append('model', 'whisper-large-v3-turbo');

    // Bilingual domain prompt with user's terminology for better transcription context
    const domainPrompt = `${terminology} turnos server mesero bartender cantinero venue ${singularTerm}`;
    formData.append('prompt', domainPrompt);

    const headers: any = {
      'Authorization': `Bearer ${groqKey}`,
      ...formData.getHeaders(),
    };

    console.log('[ai/staff/transcribe] Calling Groq Whisper API...');

    const response = await axios.post(
      `${groqWhisperUrl}/audio/transcriptions`,
      formData,
      { headers, validateStatus: () => true }
    );

    if (tempFilePath) {
      fs.unlinkSync(tempFilePath);
      tempFilePath = null;
    }

    if (response.status >= 300) {
      console.error('[ai/staff/transcribe] Groq Whisper API error:', response.status, response.data);
      if (response.status === 429) {
        return res.status(429).json({
          message: 'Groq API rate limit reached. Please try again later.',
        });
      }
      return res.status(response.status).json({
        message: `Groq Whisper API error: ${response.statusText}`,
        details: response.data,
      });
    }

    const transcribedText = response.data.text;
    if (!transcribedText) {
      return res.status(500).json({ message: 'Failed to transcribe audio' });
    }

    console.log('[ai/staff/transcribe] Transcription successful:', transcribedText.substring(0, 100));

    logAIUsage({
      userType: 'staff',
      endpoint: 'staff/transcribe',
      provider: 'groq',
      model: 'whisper-large-v3-turbo',
      inputTokens: 0,
      outputTokens: 0,
      totalTokens: 0,
      durationMs: Date.now() - transcribeStartTime,
      audioDurationSec: response.data.duration || undefined,
    }).catch(() => {});

    return res.json({
      text: transcribedText,
      duration: response.data.duration || null,
    });
  } catch (err: any) {
    if (tempFilePath && fs.existsSync(tempFilePath)) {
      try {
        fs.unlinkSync(tempFilePath);
      } catch (unlinkErr) {
        console.error('[ai/staff/transcribe] Failed to delete temp file:', unlinkErr);
      }
    }

    console.error('[ai/staff/transcribe] Error:', err);
    if (err.code === 'LIMIT_FILE_SIZE') {
      return res.status(413).json({ message: 'Audio file too large. Maximum size is 25MB.' });
    }
    return res.status(500).json({ message: err.message || 'Failed to transcribe audio' });
  }
});

/**
 * Clean AI response by removing common fluff phrases and quotes
 */
function cleanAIResponse(text: string): string {
  let cleaned = text;

  // Remove common AI preambles (case insensitive)
  const fluffPhrases = [
    /^Here's your message:?\s*/i,
    /^Here's the translation:?\s*/i,
    /^I'm happy to assist you with the translation\.?\s*/i,
    /^I'd be happy to help\.?\s*/i,
    /^Sure!?\s*/i,
    /^Of course!?\s*/i,
    /^Here is the translated text:?\s*/i,
    /^Translation:?\s*/i,
    /^Translated message:?\s*/i,
  ];

  for (const phrase of fluffPhrases) {
    cleaned = cleaned.replace(phrase, '');
  }

  // Remove surrounding quotes (single or double)
  cleaned = cleaned.replace(/^["'](.*)["']$/s, '$1');

  // Remove any trailing/leading whitespace again
  cleaned = cleaned.trim();

  return cleaned;
}

/**
 * POST /api/ai/staff/compose-message
 * AI-powered message composition for staff to communicate with managers
 * Supports: Running late, time off requests, questions, custom messages, translation, polishing, professionalizing
 */
router.post('/ai/staff/compose-message', requireAuth, async (req, res) => {
  const composeStartTime = Date.now();
  try {
    const groqKey = process.env.GROQ_API_KEY;
    if (!groqKey) {
      return res.status(500).json({ message: 'AI service not configured' });
    }

    const schema = z.object({
      scenario: z.enum(['late', 'timeoff', 'question', 'custom', 'translate', 'polish', 'professionalize']),
      context: z.object({
        message: z.string().optional(),
        details: z.string().optional(),
        language: z.enum(['en', 'es', 'auto']).default('auto')
      }).optional()
    });

    const validated = schema.parse(req.body);
    const { scenario, context } = validated;

    console.log(`[ai/staff/compose-message] Scenario: ${scenario}, Context:`, context);

    // Build scenario-specific prompt
    let userPrompt = '';

    switch (scenario) {
      case 'late':
        userPrompt = `Compose a professional message to my manager explaining that I'll be running late to my shift. ${context?.details || 'I will be approximately 10 minutes late.'}`;
        break;

      case 'timeoff':
        userPrompt = `Compose a professional message to my manager requesting time off. ${context?.details || 'I would like to request time off for personal reasons.'}`;
        break;

      case 'question':
        userPrompt = `Compose a professional message to my manager asking a question. ${context?.details || 'I have a question about my upcoming shift.'}`;
        break;

      case 'custom':
        userPrompt = context?.message || context?.details || 'Help me write a professional message to my manager.';
        break;

      case 'translate':
        userPrompt = `Translate this message to professional English: ${context?.message || ''}`;
        break;

      case 'polish':
        userPrompt = `Make this message more professional and polite: ${context?.message || ''}`;
        break;

      case 'professionalize':
        userPrompt = `Rewrite this message to be professional, friendly, and concise (2-3 sentences max): ${context?.message || ''}`;
        break;
    }

    // Professional message composition system prompt
    const systemPrompt = `You are a professional communication assistant for hospitality and events industry staff.

TONE & STYLE:
- Professional yet warm and friendly
- Respectful toward managers
- Concise (2-3 sentences maximum)
- Empathetic and understanding
- Natural conversational tone

SCENARIO GUIDELINES:

RUNNING LATE:
- Apologize sincerely and briefly
- Give specific ETA if possible
- Show commitment to arriving ASAP
- Example: "Hi, I sincerely apologize for running late. I'll be there in 10 minutes. I'm on my way now."

TIME OFF REQUEST:
- Be respectful and grateful
- State dates/duration clearly
- Offer to help with coverage if possible
- Example: "Hello, I would like to request time off from [date] to [date]. I understand if this causes any inconvenience and am happy to help find coverage. Thank you for considering my request."

ASKING QUESTIONS:
- Be direct but polite
- Show you checked available info first
- Thank them for their time
- Example: "Hi, I have a quick question about tomorrow's shift. I checked the details but wanted to confirm the dress code. Thank you!"

CUSTOM/POLISH:
- Maintain professional tone
- Keep it clear and concise
- Ensure respectful language
- Remove overly casual or unprofessional elements

TRANSLATION:
- Detect input language automatically
- If Spanish → translate to natural, professional English
- If English → return as-is or polish if needed
- Maintain equivalent tone in translation
- Use hospitality industry appropriate terms

HOSPITALITY INDUSTRY TRANSLATION CONTEXT:
Spanish phrases commonly used by staff should be translated with industry context:
- "dieras turnos" / "me dieras turnos" → "Could you please send me shifts?" or "Could I get my shifts?"
- "turnos" → "shifts" (NOT "schedule" when referring to work assignments)
- "horario" → "schedule" (for time/hours)
- "evento" → "event" (for gigs/jobs)
- "cliente" → "client" (NOT "customer")
- "llegar tarde" → "running late" (NOT "arrive late")
- "pedir permiso" → "request time off" (NOT "ask permission")

OUTPUT RULES - CRITICAL:
- Return ONLY the message text itself
- NO explanations, meta-commentary, or preambles
- NO quotes (single or double) around the message
- NO "Here's your message", "I'm happy to assist", "Here's the translation", or ANY similar phrases
- NO courtesies like "I'd be happy to help", "Sure!", "Of course"
- JUST the actual message content, nothing else
- The output should be ready to send as-is without any editing`;

    // Call Groq with GPT-OSS-20B (131K context, 65K output)
    const response = await axios.post(
      'https://api.groq.com/openai/v1/chat/completions',
      {
        model: 'openai/gpt-oss-20b',
        messages: [
          { role: 'system', content: systemPrompt },
          { role: 'user', content: userPrompt }
        ],
        temperature: 0.7, // Slightly creative but professional
        max_tokens: 200, // Short messages only
      },
      {
        headers: {
          'Authorization': `Bearer ${groqKey}`,
          'Content-Type': 'application/json'
        },
        timeout: 10000
      }
    );

    let composedMessage = response.data.choices?.[0]?.message?.content?.trim();

    if (!composedMessage) {
      return res.status(500).json({ message: 'Failed to compose message' });
    }

    // Accumulate usage from primary response
    const primaryUsage = response.data.usage;
    let composeInputTokens = primaryUsage?.prompt_tokens || 0;
    let composeOutputTokens = primaryUsage?.completion_tokens || 0;
    let composeTotalTokens = primaryUsage?.total_tokens || 0;

    // Clean up AI fluff and quotes
    composedMessage = cleanAIResponse(composedMessage);

    // Detect language and provide translation if needed
    const isSpanish = /[áéíóúñ¿¡]/i.test(composedMessage) || scenario === 'translate';

    let translation = null;
    if (isSpanish && scenario !== 'translate') {
      // Generate English translation
      const translationResponse = await axios.post(
        'https://api.groq.com/openai/v1/chat/completions',
        {
          model: 'openai/gpt-oss-20b',
          messages: [
            {
              role: 'system',
              content: 'You are a professional translator. Translate the following message to natural, professional English. Return ONLY the translated text, nothing else.'
            },
            { role: 'user', content: composedMessage }
          ],
          temperature: 0.3,
          max_tokens: 200,
        },
        {
          headers: {
            'Authorization': `Bearer ${groqKey}`,
            'Content-Type': 'application/json'
          },
          timeout: 10000
        }
      );

      translation = translationResponse.data.choices?.[0]?.message?.content?.trim();
      if (translation) {
        translation = cleanAIResponse(translation);
      }

      // Accumulate translation usage
      const translationUsage = translationResponse.data.usage;
      if (translationUsage) {
        composeInputTokens += translationUsage.prompt_tokens || 0;
        composeOutputTokens += translationUsage.completion_tokens || 0;
        composeTotalTokens += translationUsage.total_tokens || 0;
      }
    }

    console.log(`[ai/staff/compose-message] Success. Original length: ${composedMessage.length}, Has translation: ${!!translation}`);

    logAIUsage({
      userType: 'staff',
      endpoint: 'compose-message',
      provider: 'groq',
      model: 'openai/gpt-oss-20b',
      inputTokens: composeInputTokens,
      outputTokens: composeOutputTokens,
      totalTokens: composeTotalTokens,
      durationMs: Date.now() - composeStartTime,
    }).catch(() => {});

    return res.json({
      original: composedMessage,
      translation: translation,
      language: isSpanish ? 'es' : 'en'
    });

  } catch (err: any) {
    console.error('[ai/staff/compose-message] Error:', err);
    if (err instanceof z.ZodError) {
      return res.status(400).json({ message: 'Invalid request data', errors: err.issues });
    }
    return res.status(500).json({ message: err.message || 'Failed to compose message' });
  }
});

/**
 * GET /api/ai/staff/context
 * Get staff-specific context for AI chat
 * Includes: assigned events, availability history, earnings, team info
 */
router.get('/ai/staff/context', requireAuth, async (req, res) => {
  try {
    const provider = (req as any).user?.provider;
    const subject = (req as any).user?.sub;

    if (!provider || !subject) {
      return res.status(401).json({ message: 'Unauthorized' });
    }

    const userKey = `${provider}:${subject}`;
    console.log(`[ai/staff/context] Loading context for userKey ${userKey}`);

    // Load staff user details by provider and subject
    const user = await UserModel.findOne({ provider, subject })
      .select('_id first_name last_name email phone_number app_id subscription_tier')
      .lean();
    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }

    const userId = String(user._id);
    const subscriptionTier = (user as any).subscription_tier || 'free';

    // Load assigned events where user is in accepted_staff array
    const query = {
      'accepted_staff.userKey': userKey,
      status: { $ne: 'cancelled' }
    };

    console.log('[ai/staff/context] Query:', JSON.stringify(query, null, 2));
    console.log('[ai/staff/context] Query params - userKey:', userKey, 'tier:', subscriptionTier);

    // Dynamic context limit based on subscription tier
    // Free: 10 events (~750 tokens) | Pro: 50 events (~3,750 tokens)
    const eventLimit = subscriptionTier === 'pro' ? 50 : 10;

    // Load upcoming events (future first) for context — past events should use tools
    const now = new Date();
    const upcomingQuery = { ...query, date: { $gte: now } };
    const assignedEvents = await EventModel.find(upcomingQuery)
    .sort({ date: 1 })
    .limit(eventLimit)
    .select('shift_name event_name client_name date start_time end_time venue_name venue_address city state roles accepted_staff status')
    .lean();

    // Get total count so the model knows there are more events
    const totalEventCount = await EventModel.countDocuments(query);
    const pastEventCount = totalEventCount - assignedEvents.length;

    console.log('[ai/staff/context] Found', assignedEvents.length, 'events');
    if (assignedEvents.length > 0 && assignedEvents[0]) {
      console.log('[ai/staff/context] First event:', JSON.stringify({
        eventName: (assignedEvents[0] as any).event_name,
        accepted_staff: (assignedEvents[0] as any).accepted_staff
      }, null, 2));
    }

    // Extract user's role and details from accepted_staff
    const eventsWithUserData = assignedEvents.map((event: any) => {
      const userInEvent = event.accepted_staff?.find((staff: any) =>
        staff.userKey === userKey
      );
      return {
        ...event,
        userRole: userInEvent?.role || userInEvent?.position || 'Unknown',
        userCallTime: null, // Call time is in the roles array, not per-staff
        userStatus: userInEvent?.response || 'pending',
        userPayRate: null, // Pay rate not stored per-accepted staff
      };
    });

    // Calculate total earnings (if pay rates are available)
    let totalEarnings = 0;
    let totalHoursWorked = 0;

    eventsWithUserData.forEach((event: any) => {
      if (event.status === 'completed' && event.userPayRate && event.start_time && event.end_time) {
        // Calculate hours worked (simplified - would need actual clock-in/out in production)
        const start = new Date(`1970-01-01T${event.start_time}`);
        const end = new Date(`1970-01-01T${event.end_time}`);
        const hours = (end.getTime() - start.getTime()) / (1000 * 60 * 60);
        totalHoursWorked += hours;
        totalEarnings += hours * event.userPayRate;
      }
    });

    // TODO: Load availability history (requires availability table)
    // For now, return empty array
    const availabilityHistory: any[] = [];

    // Get team info (manager contact, company name, etc.)
    // TODO: Add Company/Team model
    const teamInfo = {
      companyName: 'Tie Staffing',
      supportEmail: 'support@nexastaffing.com',
      supportPhone: '(555) 123-4567',
    };

    const context = {
      user: {
        id: user._id,
        firstName: user.first_name || 'Staff',
        lastName: user.last_name || 'Member',
        email: user.email,
        phoneNumber: user.phone_number || null,
        appId: user.app_id || null,
      },
      assignedEvents: eventsWithUserData,
      eventSummary: {
        upcomingShown: assignedEvents.length,
        totalEvents: totalEventCount,
        pastEvents: pastEventCount,
        note: pastEventCount > 0
          ? `Staff has ${pastEventCount} past events. Use get_my_schedule with a date_range to query them.`
          : undefined,
      },
      availabilityHistory,
      earnings: {
        totalEarnings: Math.round(totalEarnings * 100) / 100,
        totalHoursWorked: Math.round(totalHoursWorked * 10) / 10,
      },
      teamInfo,
    };

    return res.json(context);
  } catch (err: any) {
    console.error('[ai/staff/context] Error:', err);
    return res.status(500).json({ message: 'Failed to load staff context' });
  }
});

/**
 * GET /api/ai/staff/debug-events
 * TEMPORARY: Debug endpoint to inspect event structure
 * TODO: Remove after debugging
 */
router.get('/ai/staff/debug-events', requireAuth, async (req, res) => {
  try {
    const provider = (req as any).user?.provider;
    const subject = (req as any).user?.sub;

    if (!provider || !subject) {
      return res.status(401).json({ message: 'Unauthorized' });
    }

    const userKey = `${provider}:${subject}`;
    const user = await UserModel.findOne({ provider, subject }).select('_id').lean();
    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }
    const userId = String(user._id);

    // 1. Get a sample event with assignments
    const sampleEvent = await EventModel.findOne({ 'assignments.0': { $exists: true } })
      .select('eventName assignments')
      .lean();

    // 1b. Also get ANY event to see structure
    const anyEvent = await EventModel.findOne()
      .select('eventName assignments members roles userAssignments staffAssignments')
      .lean();

    // 2. Test the query with $or
    const queryWithOr = {
      $or: [
        { 'assignments.memberId': userId },
        { 'assignments.userKey': userKey }
      ],
      status: { $ne: 'cancelled' }
    };

    const eventsFoundWithOr = await EventModel.find(queryWithOr)
      .select('eventName assignments')
      .limit(5)
      .lean();

    // 3. Search by just userKey
    const eventsWithUserKey = await EventModel.find({
      'assignments.userKey': userKey,
      status: { $ne: 'cancelled' }
    })
      .select('eventName assignments')
      .limit(5)
      .lean();

    // 4. Search by just memberId
    const eventsWithMemberId = await EventModel.find({
      'assignments.memberId': userId,
      status: { $ne: 'cancelled' }
    })
      .select('eventName assignments')
      .limit(5)
      .lean();

    return res.json({
      debug: {
        userId,
        userKey,
        sampleEventFromDB: sampleEvent ? {
          eventName: (sampleEvent as any).eventName,
          assignmentsStructure: (sampleEvent as any).assignments?.slice(0, 2)
        } : null,
        anyEventStructure: anyEvent ? {
          eventName: (anyEvent as any).eventName,
          assignments: (anyEvent as any).assignments,
          members: (anyEvent as any).members,
          roles: (anyEvent as any).roles,
          userAssignments: (anyEvent as any).userAssignments,
          staffAssignments: (anyEvent as any).staffAssignments
        } : null,
        queryResults: {
          usingOrOperator: {
            count: eventsFoundWithOr.length,
            events: eventsFoundWithOr.map((e: any) => ({
              eventName: e.eventName,
              assignments: e.assignments
            }))
          },
          usingUserKeyOnly: {
            count: eventsWithUserKey.length,
            events: eventsWithUserKey.map((e: any) => ({
              eventName: e.eventName,
              assignments: e.assignments
            }))
          },
          usingMemberIdOnly: {
            count: eventsWithMemberId.length,
            events: eventsWithMemberId.map((e: any) => ({
              eventName: e.eventName,
              assignments: e.assignments
            }))
          }
        }
      }
    });
  } catch (err: any) {
    console.error('[ai/staff/debug-events] Error:', err);
    return res.status(500).json({ message: 'Failed to debug events', error: err.message });
  }
});

// Schema for chat message request (same as manager)
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
  provider: z.enum(['openai', 'claude', 'groq', 'together']).optional().default('groq'),
  model: z.string().optional(), // Accepted for backward compat — ignored; cascade router selects model server-side
});

/**
 * Function/Tool definitions for staff AI
 * Different from manager tools - focused on staff actions
 */
const STAFF_AI_TOOLS = [
  {
    name: 'get_my_schedule',
    description: 'Get my shifts and assigned events, INCLUDING personal gigs. Returns both manager-assigned shifts (source: "manager") and personal events (source: "personal"). Use when I ask about my schedule, upcoming shifts, past shifts, work history, specific dates, or "when do I work". Supports both future and past queries.',
    parameters: {
      type: 'object',
      properties: {
        date_range: {
          type: ['string', 'null'],
          description: 'Date filter. LEAVE EMPTY for upcoming events. Options: "this_week", "last_week", "next_week", "this_month", "last_month", "last_3_months", "last_6_months", "all_past", "YYYY-MM-DD" for a specific date, or "YYYY-MM-DD:YYYY-MM-DD" for a custom range (start:end).'
        },
        limit: {
          type: ['number', 'null'],
          description: 'Number of events to return. Default is 10. Use 1 for "next shift", use specified number for "next N shifts".'
        }
      }
    }
  },
  {
    name: 'mark_availability',
    description: 'Mark my availability for specific dates. Use when I say "I\'m available" or "I can\'t work on...".',
    parameters: {
      type: 'object',
      properties: {
        dates: {
          type: 'array',
          items: { type: 'string' },
          description: 'Array of ISO dates (YYYY-MM-DD). If user says a month that already passed this year, use next year.'
        },
        status: {
          type: 'string',
          enum: ['available', 'unavailable', 'preferred'],
          description: 'Availability status'
        },
        notes: {
          type: ['string', 'null'],
          description: 'Optional notes about availability'
        }
      },
      required: ['dates', 'status']
    }
  },
  {
    name: 'accept_shift',
    description: 'Accept a shift/event. Use when I say "accept the shift" or "I\'ll take it". Requires event_id (from get_my_schedule). Role is auto-detected from invitation or must be specified.',
    parameters: {
      type: 'object',
      properties: {
        event_id: {
          type: 'string',
          description: 'The event ID to accept (get this from get_my_schedule results)'
        },
        role: {
          type: ['string', 'null'],
          description: 'The role to accept for (e.g. "Server", "Bartender"). Optional if user was invited for a specific role.'
        }
      },
      required: ['event_id']
    }
  },
  {
    name: 'decline_shift',
    description: 'Decline a shift/event. Use when I say "decline" or "I can\'t make it".',
    parameters: {
      type: 'object',
      properties: {
        event_id: {
          type: 'string',
          description: 'The event ID to decline'
        },
        reason: {
          type: ['string', 'null'],
          description: 'Optional reason for declining'
        }
      },
      required: ['event_id']
    }
  },
  {
    name: 'get_earnings_summary',
    description: 'Get my earnings and hours worked, including breakdown by venue, role, and client. Use when I ask about pay, earnings, "how much have I made", or want earnings broken down by venue/location/role/client.',
    parameters: {
      type: 'object',
      properties: {
        date_range: {
          type: ['string', 'null'],
          description: 'Time period: "this_week", "last_week", "this_month", "last_month", "last_3_months", "last_6_months", or custom range "YYYY-MM-DD:YYYY-MM-DD" (e.g. "2025-11-01:2025-11-30" for November 2025)'
        }
      }
    }
  },
  {
    name: 'get_my_unavailable_dates',
    description: 'Get dates I\'ve marked as unavailable. Use when I ask "when am I unavailable", "what days did I block off", "am I available on [date]?".',
    parameters: {
      type: 'object',
      properties: {
        from_date: {
          type: ['string', 'null'],
          description: 'Optional start date (YYYY-MM-DD) to filter. Useful for "am I unavailable next week?"'
        },
        to_date: {
          type: ['string', 'null'],
          description: 'Optional end date (YYYY-MM-DD) to filter.'
        }
      }
    }
  },
  {
    name: 'get_performance',
    description: 'Get my performance statistics: events worked, hours, earnings, breakdown by role and by month. Use for "how am I doing", "my stats", "performance this month/year".',
    parameters: {
      type: 'object',
      properties: {
        period: {
          type: 'string',
          description: 'Time period: "current_month", "last_month", "last_3_months", "last_6_months", "last_year", or custom range "YYYY-MM-DD:YYYY-MM-DD" (e.g. "2025-11-01:2025-11-30"). Default: current_month.'
        }
      }
    }
  },
  {
    name: 'compose_message',
    description: 'Help compose a professional message to send to the manager. Use when staff says "help me write a message", "I need to call off", "tell my manager I\'m running late", "request time off", etc.',
    parameters: {
      type: 'object',
      properties: {
        scenario: {
          type: 'string',
          enum: ['late', 'timeoff', 'calloff', 'question', 'custom'],
          description: 'Type of message: late (running late), timeoff (requesting days off), calloff (calling off a shift), question (asking manager something), custom (other)'
        },
        details: {
          type: 'string',
          description: 'User-provided context: reason, dates, shift name, ETA, etc.'
        }
      },
      required: ['scenario', 'details']
    }
  },
  {
    name: 'send_message_to_manager',
    description: 'Send a message to the staff member\'s manager via the chat system. Use ONLY after composing a message and getting user confirmation to send.',
    parameters: {
      type: 'object',
      properties: {
        message: {
          type: 'string',
          description: 'The final message text to send to the manager'
        },
        manager_id: {
          type: ['string', 'null'],
          description: 'Optional specific manager ID. If not provided, sends to first active manager found.'
        }
      },
      required: ['message']
    }
  },
  {
    name: 'get_shift_details',
    description: 'Get full details about a specific shift/event including pay info, notes, dress code, contact info, and arrival time. Use when staff asks "what are the details for...", "how much does it pay", "what should I wear", "who do I contact", "when should I arrive".',
    parameters: {
      type: 'object',
      properties: {
        event_id: {
          type: 'string',
          description: 'The event ID to get details for (get this from get_my_schedule results)'
        }
      },
      required: ['event_id']
    }
  },
  {
    name: 'create_personal_event',
    description: 'Create a personal event (external gig, side job, personal commitment). Creates a visible event card in My Shifts AND auto-marks staff as unavailable. Use when staff mentions personal gigs, side jobs, freelance work, doctor visits, or wants to block time. Different from mark_availability — this creates a FULL event card with role, client, and pay tracking. 🚨 CRITICAL: ALL EVENTS MUST BE IN THE FUTURE. If user says a month that has passed this year, use NEXT year.',
    parameters: {
      type: 'object',
      properties: {
        title: {
          type: 'string',
          description: 'Name/title of the event (e.g. "Wedding Gig", "Freelance Bartending", "Doctor Appointment")'
        },
        date: {
          type: 'string',
          description: 'Date in YYYY-MM-DD format. 🚨 If user says a day name (e.g. "Saturday"), use the NEXT occurrence. If month has passed this year, use next year.'
        },
        start_time: {
          type: 'string',
          description: 'Start time in HH:mm 24h format (e.g. "14:00" for 2 PM, "4 de la tarde" → "16:00")'
        },
        end_time: {
          type: 'string',
          description: 'End time in HH:mm 24h format (e.g. "22:00" for 10 PM, "11 de la noche" → "23:00")'
        },
        notes: {
          type: ['string', 'null'],
          description: 'Optional notes (e.g. "Bring black vest", "Parking in back lot")'
        },
        location: {
          type: ['string', 'null'],
          description: 'Optional venue/location name or address'
        },
        role: {
          type: ['string', 'null'],
          description: 'Role for the gig (e.g. "Bartender", "Server", "Valet"). ALWAYS extract when staff mentions what they\'ll be doing.'
        },
        client: {
          type: ['string', 'null'],
          description: 'Client/employer name (e.g. "Marriott", "Joe\'s Catering"). ALWAYS extract when staff mentions who they\'re working for.'
        },
        hourly_rate: {
          type: ['number', 'null'],
          description: 'Hourly pay rate in dollars (e.g. 25 for $25/hr). Extract when staff mentions pay/rate.'
        }
      },
      required: ['title', 'date', 'start_time', 'end_time']
    }
  },
  {
    name: 'create_personal_events_bulk',
    description: 'Create multiple personal events at once (max 20). Use for recurring patterns like "I bartend every Saturday in March", "I have gigs on the 10th, 15th, and 22nd", "block off every Monday for school". Each event auto-creates an unavailability record.',
    parameters: {
      type: 'object',
      properties: {
        events: {
          type: 'array',
          description: 'Array of personal event objects (same fields as create_personal_event)',
          items: {
            type: 'object',
            properties: {
              title: { type: 'string', description: 'Event name' },
              date: { type: 'string', description: 'YYYY-MM-DD' },
              start_time: { type: 'string', description: '24h format HH:mm' },
              end_time: { type: 'string', description: '24h format HH:mm' },
              notes: { type: ['string', 'null'] },
              location: { type: ['string', 'null'] },
              role: { type: ['string', 'null'] },
              client: { type: ['string', 'null'] },
              hourly_rate: { type: ['number', 'null'] }
            }
          }
        }
      },
      required: ['events']
    }
  },
  {
    name: 'update_personal_event',
    description: 'Update an existing personal event. Also updates the linked unavailability. Use when staff says "change my gig time", "move my event to Thursday", "update the location". First use get_my_personal_events to find the event ID.',
    parameters: {
      type: 'object',
      properties: {
        event_id: {
          type: 'string',
          description: 'The personal event ID to update (get this from get_my_personal_events results)'
        },
        title: { type: ['string', 'null'], description: 'New title (null = keep current)' },
        date: { type: ['string', 'null'], description: 'New date YYYY-MM-DD (null = keep current). Must be in the future.' },
        start_time: { type: ['string', 'null'], description: 'New start time HH:mm (null = keep current)' },
        end_time: { type: ['string', 'null'], description: 'New end time HH:mm (null = keep current)' },
        notes: { type: ['string', 'null'], description: 'New notes (null = keep current)' },
        location: { type: ['string', 'null'], description: 'New location (null = keep current)' },
        role: { type: ['string', 'null'], description: 'New role (null = keep current)' },
        client: { type: ['string', 'null'], description: 'New client (null = keep current)' },
        hourly_rate: { type: ['number', 'null'], description: 'New hourly rate (null = keep current)' }
      },
      required: ['event_id']
    }
  },
  {
    name: 'update_personal_events_bulk',
    description: 'Update multiple personal events at once with the same field values. Use when staff says "update the location on all my La Tinto events", "change the pay rate on all my Saturday gigs", etc. First use get_my_personal_events to get the event IDs.',
    parameters: {
      type: 'object',
      properties: {
        event_ids: {
          type: 'array',
          items: { type: 'string' },
          description: 'Array of personal event IDs to update (get these from get_my_personal_events results)'
        },
        location: { type: ['string', 'null'], description: 'New location for all events (null = keep current)' },
        role: { type: ['string', 'null'], description: 'New role for all events (null = keep current)' },
        client: { type: ['string', 'null'], description: 'New client for all events (null = keep current)' },
        hourly_rate: { type: ['number', 'null'], description: 'New hourly rate for all events (null = keep current)' },
        notes: { type: ['string', 'null'], description: 'New notes for all events (null = keep current)' },
        title: { type: ['string', 'null'], description: 'New title for all events (null = keep current)' }
      },
      required: ['event_ids']
    }
  },
  {
    name: 'get_my_personal_events',
    description: 'Get my personal events (external gigs, side jobs, personal commitments I created). Use when staff asks specifically about personal events, "my personal gigs", or BEFORE update/delete to find the event ID. Note: get_my_schedule also includes personal events mixed with shifts.',
    parameters: {
      type: 'object',
      properties: {
        date_range: {
          type: ['string', 'null'],
          description: 'Date filter. Same options as get_my_schedule: "this_week", "next_week", "last_week", "this_month", "last_month", "last_3_months", "last_6_months", "all_past", "YYYY-MM-DD", or "YYYY-MM-DD:YYYY-MM-DD". Takes precedence over period.'
        },
        limit: {
          type: ['number', 'null'],
          description: 'Max events to return (default 50, max 50).'
        },
        period: {
          type: ['string', 'null'],
          description: 'Deprecated. Use date_range instead. "future" for upcoming, "past" for past only.'
        }
      }
    }
  },
  {
    name: 'delete_personal_event',
    description: 'Delete a personal event I created. Also removes the linked unavailability. Use when staff says "remove my personal event", "cancel my gig", "delete the wedding event". First use get_my_personal_events to find the event ID.',
    parameters: {
      type: 'object',
      properties: {
        event_id: {
          type: 'string',
          description: 'The personal event ID to delete (get this from get_my_personal_events results)'
        }
      },
      required: ['event_id']
    }
  },
  {
    name: 'search_address',
    description: 'Search for a real address or venue using Google Places. Returns the formatted address with coordinates. Use this BEFORE create_personal_event when the staff mentions a location — resolve it to a proper address first, then pass the formatted_address as the location field.',
    parameters: {
      type: 'object',
      properties: {
        query: {
          type: 'string',
          description: 'Address or venue name to search (e.g. "Cherokee Ranch and Castle", "Marriott Denver", "1600 Pennsylvania Ave")'
        }
      },
      required: ['query']
    }
  },
];

/**
 * Execute mark_availability function
 * Creates/updates availability records for the staff member
 */
async function executeMarkAvailability(
  userKey: string,
  dates: string[],
  status: 'available' | 'unavailable' | 'preferred',
  notes?: string
): Promise<{ success: boolean; message: string; data?: any }> {
  try {
    console.log(`[executeMarkAvailability] Marking ${status} for ${dates.length} dates for userKey ${userKey}`);

    // For now, create full-day availability records (00:00 to 23:59)
    // In a more advanced system, you could parse specific time ranges from notes
    const results = [];

    for (const date of dates) {
      // Try to update existing record, or create new one
      const result = await AvailabilityModel.findOneAndUpdate(
        { userKey, date, startTime: '00:00', endTime: '23:59' },
        {
          userKey,
          date,
          startTime: '00:00',
          endTime: '23:59',
          status: status === 'preferred' ? 'available' : status, // Map 'preferred' to 'available'
        },
        { upsert: true, new: true }
      ).lean();

      results.push(result);
    }

    // Cost optimization: Compressed response format
    return {
      success: true,
      message: `Marked ${status} for ${dates.length} date(s)`,
      data: { dates, status }
    };
  } catch (error: any) {
    console.error('[executeMarkAvailability] Error:', error);
    return {
      success: false,
      message: `Failed to mark availability: ${error.message}`
    };
  }
}

/**
 * Parse pay rate from various formats:
 * - String: "$18/hr", "$25.50/hr", "$30 per hour"
 * - Object: { amount: 18, type: 'hourly' }
 * - Number: 18
 * Returns hourly rate as number, or 0 if unparseable
 */
function parsePayRate(payRateInfo: any): number {
  if (!payRateInfo) return 0;
  if (typeof payRateInfo === 'number') return payRateInfo;
  if (typeof payRateInfo === 'object' && payRateInfo.amount) return Number(payRateInfo.amount) || 0;
  if (typeof payRateInfo === 'string') {
    // Extract number from strings like "$18/hr", "$25.50/hr", "$30 per hour"
    const match = payRateInfo.match(/\$?([\d.]+)/);
    return match ? parseFloat(match[1] || '0') : 0;
  }
  return 0;
}

// ── Commute calculation (Nominatim + OSRM) ──────────────────────────────
// Ports the same free APIs used by Flutter's CommuteService to the backend
// so AI tools can include distance/time data in schedule responses.

const NOMINATIM_BASE = 'https://nominatim.openstreetmap.org';
const OSRM_BASE = 'https://router.project-osrm.org';
const COMMUTE_USER_AGENT = 'FlowShiftAPI/1.0';
const COMMUTE_TIMEOUT = 5000; // ms

// In-memory geocode cache: address → {lat,lng} | null
const geocodeCache = new Map<string, { lat: number; lng: number } | null>();

/**
 * Geocode an address to lat/lng via Nominatim.
 * Returns cached result if available.
 */
async function geocodeAddress(address: string): Promise<{ lat: number; lng: number } | null> {
  const key = address.trim();
  if (!key) return null;
  if (geocodeCache.has(key)) return geocodeCache.get(key) || null;

  try {
    const resp = await axios.get(`${NOMINATIM_BASE}/search`, {
      params: { q: key, format: 'json', limit: 1 },
      headers: { 'User-Agent': COMMUTE_USER_AGENT, 'Accept-Language': 'en' },
      timeout: COMMUTE_TIMEOUT,
    });
    const list = resp.data;
    if (!Array.isArray(list) || list.length === 0) {
      // Retry without first comma segment (strips venue name prefix)
      const commaIdx = key.indexOf(',');
      if (commaIdx > 0) {
        const stripped = key.substring(commaIdx + 1).trim();
        const retryResp = await axios.get(`${NOMINATIM_BASE}/search`, {
          params: { q: stripped, format: 'json', limit: 1 },
          headers: { 'User-Agent': COMMUTE_USER_AGENT, 'Accept-Language': 'en' },
          timeout: COMMUTE_TIMEOUT,
        });
        const retryList = retryResp.data;
        if (Array.isArray(retryList) && retryList.length > 0) {
          const coords = { lat: parseFloat(retryList[0].lat), lng: parseFloat(retryList[0].lon) };
          if (!isNaN(coords.lat) && !isNaN(coords.lng)) {
            geocodeCache.set(key, coords);
            return coords;
          }
        }
      }
      geocodeCache.set(key, null);
      return null;
    }
    const coords = { lat: parseFloat(list[0].lat), lng: parseFloat(list[0].lon) };
    if (isNaN(coords.lat) || isNaN(coords.lng)) {
      geocodeCache.set(key, null);
      return null;
    }
    geocodeCache.set(key, coords);
    return coords;
  } catch (err) {
    geocodeCache.set(key, null);
    return null;
  }
}

/**
 * Compute driving distance (miles) and duration (minutes) between two points
 * using OSRM's free routing API.
 */
async function computeCommute(
  homeLat: number, homeLng: number, venueAddress: string
): Promise<{ miles: number; minutes: number } | null> {
  try {
    const dest = await geocodeAddress(venueAddress);
    if (!dest) return null;

    const resp = await axios.get(
      `${OSRM_BASE}/route/v1/driving/${homeLng},${homeLat};${dest.lng},${dest.lat}`,
      {
        params: { overview: 'false' },
        headers: { 'User-Agent': COMMUTE_USER_AGENT },
        timeout: COMMUTE_TIMEOUT,
      }
    );
    const body = resp.data;
    if (body?.code !== 'Ok' || !body.routes?.length) return null;

    const route = body.routes[0];
    const distanceMeters = route.distance ?? 0;
    const durationSeconds = route.duration ?? 0;
    return {
      miles: Math.round((distanceMeters / 1609.344) * 10) / 10,
      minutes: Math.round(durationSeconds / 60),
    };
  } catch {
    return null;
  }
}

/**
 * Build a Mongoose { date: { $gte, $lte } } filter from a date_range string.
 * Shared by get_my_schedule, get_my_personal_events, and get_earnings_summary.
 *
 * Supports: this_week, last_week, next_week, this_month, last_month,
 *           last_3_months, last_6_months, all_past, YYYY-MM-DD, YYYY-MM-DD:YYYY-MM-DD
 *
 * Returns empty object {} if dateRange is falsy (caller decides default behavior).
 */
function buildDateFilter(dateRange?: string): Record<string, any> {
  if (!dateRange) return {};

  const now = new Date();

  if (dateRange === 'this_week') {
    const start = new Date(now);
    start.setDate(now.getDate() - now.getDay());
    start.setHours(0, 0, 0, 0);
    const end = new Date(start);
    end.setDate(start.getDate() + 6);
    end.setHours(23, 59, 59, 999);
    return { date: { $gte: start, $lte: end } };
  }
  if (dateRange === 'last_week') {
    const start = new Date(now);
    start.setDate(now.getDate() - now.getDay() - 7);
    start.setHours(0, 0, 0, 0);
    const end = new Date(start);
    end.setDate(start.getDate() + 6);
    end.setHours(23, 59, 59, 999);
    return { date: { $gte: start, $lte: end } };
  }
  if (dateRange === 'next_week') {
    const start = new Date(now);
    start.setDate(now.getDate() - now.getDay() + 7);
    start.setHours(0, 0, 0, 0);
    const end = new Date(start);
    end.setDate(start.getDate() + 6);
    end.setHours(23, 59, 59, 999);
    return { date: { $gte: start, $lte: end } };
  }
  if (dateRange === 'this_month') {
    const start = new Date(now.getFullYear(), now.getMonth(), 1);
    const end = new Date(now.getFullYear(), now.getMonth() + 1, 0, 23, 59, 59, 999);
    return { date: { $gte: start, $lte: end } };
  }
  if (dateRange === 'last_month') {
    const start = new Date(now.getFullYear(), now.getMonth() - 1, 1);
    const end = new Date(now.getFullYear(), now.getMonth(), 0, 23, 59, 59, 999);
    return { date: { $gte: start, $lte: end } };
  }
  if (dateRange === 'last_3_months') {
    const start = new Date(now.getFullYear(), now.getMonth() - 3, 1);
    start.setHours(0, 0, 0, 0);
    return { date: { $gte: start, $lte: now } };
  }
  if (dateRange === 'last_6_months') {
    const start = new Date(now.getFullYear(), now.getMonth() - 6, 1);
    start.setHours(0, 0, 0, 0);
    return { date: { $gte: start, $lte: now } };
  }
  if (dateRange === 'all_past') {
    return { date: { $lt: now } };
  }
  if (dateRange.includes(':')) {
    const parts = dateRange.split(':');
    const startDate = new Date(parts[0] || dateRange);
    startDate.setHours(0, 0, 0, 0);
    const endDate = new Date(parts[1] || parts[0] || dateRange);
    endDate.setHours(23, 59, 59, 999);
    return { date: { $gte: startDate, $lte: endDate } };
  }
  // Assume ISO date (YYYY-MM-DD) — match the entire day
  const specificDate = new Date(dateRange);
  if (!isNaN(specificDate.getTime())) {
    const startOfDay = new Date(specificDate);
    startOfDay.setHours(0, 0, 0, 0);
    const endOfDay = new Date(specificDate);
    endOfDay.setHours(23, 59, 59, 999);
    return { date: { $gte: startOfDay, $lte: endOfDay } };
  }
  // Unrecognized — return empty so caller can handle
  return {};
}

/**
 * Execute get_my_schedule function
 * Returns upcoming shifts and assigned events, INCLUDING personal events
 */
async function executeGetMySchedule(
  userId: string,
  userKey: string,
  dateRange?: string,
  limit?: number,
  subscriptionTier: 'free' | 'pro' = 'free'
): Promise<{ success: boolean; message: string; data?: any }> {
  try {
    console.log(`[executeGetMySchedule] Getting schedule for userId ${userId}, userKey ${userKey}, range: ${dateRange || 'all'}, tier: ${subscriptionTier}`);

    // Build date filter using shared helper
    const now = new Date();
    let dateFilter = buildDateFilter(dateRange);
    if (!dateRange || Object.keys(dateFilter).length === 0) {
      // No date filter or unrecognized range — return upcoming events
      dateFilter = { date: { $gte: now } };
      console.log(`[executeGetMySchedule] No date filter - returning upcoming events from ${now.toISOString()}`);
    } else {
      console.log(`[executeGetMySchedule] Date filter for '${dateRange}':`, JSON.stringify(dateFilter));
    }

    // Dynamic limit: generous for reading own history, model needs full picture
    // Free: 30 events | Pro: 100 events
    const maxLimit = subscriptionTier === 'pro' ? 100 : 30;
    const eventLimit = limit
      ? Math.min(limit, maxLimit)
      : maxLimit;

    console.log(`[executeGetMySchedule] Using limit: ${eventLimit} (requested: ${limit || 'default'}, max: ${maxLimit})`);

    // --- Fetch manager-assigned shifts ---
    const managerQuery = {
      'accepted_staff.userKey': userKey,
      status: { $ne: 'cancelled' },
      ...dateFilter
    };
    console.log('[executeGetMySchedule] Manager query:', JSON.stringify(managerQuery, null, 2));

    const managerEvents = await EventModel.find(managerQuery)
      .sort({ date: 1 })
      .limit(eventLimit)
      .select('shift_name event_name client_name date start_time end_time venue_name venue_address city state accepted_staff status roles pay_rate_info')
      .lean();

    console.log('[executeGetMySchedule] Found', managerEvents.length, 'manager events');

    // Map manager events with source tag
    const managerSchedule = managerEvents.map((event: any) => {
      const userInEvent = event.accepted_staff?.find((staff: any) =>
        staff.userKey === userKey
      );
      const userRole = userInEvent?.role || userInEvent?.position;
      const roleInfo = event.roles?.find((r: any) => r.role_name === userRole || r.role === userRole);
      return {
        id: event._id,
        source: 'manager' as const,
        name: event.shift_name || event.event_name || event.client_name || 'Untitled',
        client: event.client_name,
        date: event.date,
        time: `${event.start_time}-${event.end_time}`,
        venue: event.venue_name,
        addr: event.venue_address,
        role: userRole || 'Unknown',
        pay: roleInfo?.pay_rate_info || event.pay_rate_info || null,
        status: userInEvent?.response || 'accept',
      };
    });

    // --- Fetch personal events with the same date filter ---
    const personalQuery = { userKey, ...dateFilter };
    const personalEvents = await PersonalEventModel.find(personalQuery)
      .sort({ date: 1 })
      .limit(eventLimit)
      .lean();

    console.log('[executeGetMySchedule] Found', personalEvents.length, 'personal events');

    const personalSchedule = personalEvents.map((pe: any) => ({
      id: String(pe._id),
      source: 'personal' as const,
      name: pe.title || 'Personal Event',
      client: pe.client || null,
      date: pe.date,
      time: `${pe.startTime}-${pe.endTime}`,
      venue: pe.location || null,
      addr: null,
      role: pe.role || null,
      pay: pe.hourlyRate ? `$${pe.hourlyRate}/hr` : null,
      status: 'personal',
      notes: pe.notes || null,
    }));

    // --- Merge, sort by date, apply combined limit ---
    const merged = [...managerSchedule, ...personalSchedule]
      .sort((a, b) => new Date(a.date).getTime() - new Date(b.date).getTime())
      .slice(0, eventLimit);

    // NOTE: Commute/miles enrichment removed from AI chat — the Flutter client
    // pre-computes distances via CommuteService and appends them to the prompt
    // in the "My Shifts Breakdown" sheet. This avoids slow geocoding/OSRM calls
    // that were adding ~2-4s latency per shift in full-chat responses.

    const shiftCount = merged.filter(e => e.source === 'manager').length;
    const personalCount = merged.filter(e => e.source === 'personal').length;
    const parts: string[] = [];
    if (shiftCount > 0) parts.push(`${shiftCount} shift${shiftCount !== 1 ? 's' : ''}`);
    if (personalCount > 0) parts.push(`${personalCount} personal`);
    const summary = parts.length > 0 ? `${merged.length} event(s) found (${parts.join(', ')})` : '0 events found';

    return {
      success: true,
      message: summary,
      data: merged
    };
  } catch (error: any) {
    console.error('[executeGetMySchedule] Error:', error);
    return {
      success: false,
      message: `Failed to get schedule: ${error.message}`
    };
  }
}

/**
 * Execute get_earnings_summary function
 * Calculates total earnings and hours worked
 */
async function executeGetEarningsSummary(
  userId: string,
  userKey: string,
  dateRange?: string
): Promise<{ success: boolean; message: string; data?: any }> {
  try {
    console.log(`[executeGetEarningsSummary] Getting earnings for userId ${userId}, userKey ${userKey}, range: ${dateRange || 'all'}`);

    // Use shared date filter builder
    const dateFilter = buildDateFilter(dateRange);
    if (dateRange && Object.keys(dateFilter).length === 0) {
      console.warn(`[executeGetEarningsSummary] Unrecognized date range: ${dateRange}`);
      return {
        success: false,
        message: `Unrecognized date range "${dateRange}". Use: "this_week", "last_week", "this_month", "last_month", "last_3_months", "last_6_months", or custom "YYYY-MM-DD:YYYY-MM-DD" (e.g. "2025-11-01:2025-11-30").`
      };
    }

    console.log(`[executeGetEarningsSummary] Date filter for '${dateRange}':`, JSON.stringify(dateFilter));

    // Use same criteria as context endpoint: all non-cancelled events
    const rawEvents = await EventModel.find({
      'accepted_staff.userKey': userKey,
      status: { $ne: 'cancelled' },
      ...dateFilter
    })
    .select('date start_time end_time accepted_staff roles pay_rate_info managerId client_name venue_name')
    .lean();

    // Enrich events with tariff rates (same as Flutter earnings page)
    const events = await enrichEventsWithTariffs(rawEvents);

    let totalEarnings = 0;
    let totalHoursWorked = 0;
    let eventCount = 0;
    const venueTotals: Record<string, { earned: number; hours: number; events: number }> = {};
    const roleTotals: Record<string, { earned: number; hours: number; events: number }> = {};
    const clientTotals: Record<string, { earned: number; hours: number; events: number }> = {};

    events.forEach((event: any) => {
      const userInEvent = event.accepted_staff?.find((staff: any) =>
        staff.userKey === userKey
      );
      if (!userInEvent) return;

      // Hours: prefer approved attendance hours (matches Flutter earnings page)
      let hours = 0;
      const attendance = userInEvent.attendance || [];
      for (const session of attendance) {
        if (session.approvedHours != null && session.status === 'approved') {
          hours += session.approvedHours;
        }
      }

      // Strict: only count approved hours (matches Flutter earnings page)
      if (hours === 0) return;

      totalHoursWorked += hours;

      // Pay rate: prefer tariff rate (from catalog), fallback to pay_rate_info string
      const userRole = userInEvent.role || userInEvent.position;
      const roleInfo = event.roles?.find((r: any) => r.role_name === userRole || r.role === userRole);
      const tariffRate = roleInfo?.tariff?.rate;
      const wage = tariffRate || parsePayRate(roleInfo?.pay_rate_info) || parsePayRate(event.pay_rate_info);
      const eventEarnings = wage * hours;
      totalEarnings += eventEarnings;
      eventCount++;

      // Bucket into venue breakdown
      const venueName = event.venue_name || 'Unknown Venue';
      if (!venueTotals[venueName]) venueTotals[venueName] = { earned: 0, hours: 0, events: 0 };
      venueTotals[venueName].earned += eventEarnings;
      venueTotals[venueName].hours += hours;
      venueTotals[venueName].events++;

      // Bucket into role breakdown
      const roleName = userRole || 'Unknown Role';
      if (!roleTotals[roleName]) roleTotals[roleName] = { earned: 0, hours: 0, events: 0 };
      roleTotals[roleName].earned += eventEarnings;
      roleTotals[roleName].hours += hours;
      roleTotals[roleName].events++;

      // Bucket into client breakdown
      const clientName = event.client_name || 'Unknown Client';
      if (!clientTotals[clientName]) clientTotals[clientName] = { earned: 0, hours: 0, events: 0 };
      clientTotals[clientName].earned += eventEarnings;
      clientTotals[clientName].hours += hours;
      clientTotals[clientName].events++;
    });

    const round2 = (n: number) => Math.round(n * 100) / 100;
    const round1 = (n: number) => Math.round(n * 10) / 10;

    // Cost optimization: Compressed response format with venue/role breakdowns
    return {
      success: true,
      message: `${eventCount} completed event(s)`,
      data: {
        earned: round2(totalEarnings),
        hours: round1(totalHoursWorked),
        events: eventCount,
        byVenue: Object.entries(venueTotals)
          .map(([name, s]) => ({ name, earned: round2(s.earned), hours: round1(s.hours), events: s.events }))
          .sort((a, b) => b.earned - a.earned),
        byRole: Object.entries(roleTotals)
          .map(([name, s]) => ({ name, earned: round2(s.earned), hours: round1(s.hours), events: s.events }))
          .sort((a, b) => b.earned - a.earned),
        byClient: Object.entries(clientTotals)
          .map(([name, s]) => ({ name, earned: round2(s.earned), hours: round1(s.hours), events: s.events }))
          .sort((a, b) => b.earned - a.earned)
      }
    };
  } catch (error: any) {
    console.error('[executeGetEarningsSummary] Error:', error);
    return {
      success: false,
      message: `Failed to get earnings summary: ${error.message}`
    };
  }
}

/**
 * Execute get_all_my_events function
 * Returns ALL upcoming events, shows first 10 in detail and summarizes the rest
 */
async function executeGetAllMyEvents(
  userId: string,
  userKey: string
): Promise<{ success: boolean; message: string; data?: any }> {
  try {
    console.log(`[executeGetAllMyEvents] Getting all upcoming events for userKey ${userKey}`);

    const now = new Date();
    const query = {
      'accepted_staff.userKey': userKey,
      status: { $ne: 'cancelled' },
      date: { $gte: now }
    };

    // Get total count first
    const totalCount = await EventModel.countDocuments(query);
    console.log(`[executeGetAllMyEvents] Total upcoming events: ${totalCount}`);

    // Get first 30 events in detail
    const events = await EventModel.find(query)
      .sort({ date: 1 })
      .limit(30)
      .select('shift_name event_name client_name date start_time end_time venue_name venue_address city state accepted_staff status roles pay_rate_info')
      .lean();

    // Extract user's data from accepted_staff for each event
    const detailedEvents = events.map((event: any) => {
      const userInEvent = event.accepted_staff?.find((staff: any) =>
        staff.userKey === userKey
      );
      const userRole = userInEvent?.role || userInEvent?.position;
      const roleInfo = event.roles?.find((r: any) => r.role_name === userRole || r.role === userRole);
      return {
        id: event._id,
        name: event.shift_name || event.event_name || event.client_name || 'Untitled',
        client: event.client_name,
        date: event.date,
        time: `${event.start_time}-${event.end_time}`,
        venue: event.venue_name,
        addr: event.venue_address,
        role: userRole || 'Unknown',
        pay: roleInfo?.pay_rate_info || event.pay_rate_info || null,
        status: userInEvent?.response || 'accept',
      };
    });

    const remainingCount = totalCount - detailedEvents.length;

    return {
      success: true,
      message: totalCount === 0
        ? 'No upcoming events found'
        : `${totalCount} total event(s)`,
      data: {
        events: detailedEvents,
        total: totalCount,
        showing: detailedEvents.length,
        remaining: remainingCount > 0 ? remainingCount : 0
      }
    };
  } catch (error: any) {
    console.error('[executeGetAllMyEvents] Error:', error);
    return {
      success: false,
      message: `Failed to get events: ${error.message}`
    };
  }
}

/**
 * Execute get_my_unavailable_dates function
 * Returns dates marked as unavailable, with optional date range filtering
 */
async function executeGetMyUnavailableDates(
  userKey: string,
  fromDate?: string,
  toDate?: string
): Promise<{ success: boolean; message: string; data?: any }> {
  try {
    console.log(`[executeGetMyUnavailableDates] Getting unavailable dates for userKey ${userKey}, from: ${fromDate || 'any'}, to: ${toDate || 'any'}`);

    const query: any = { userKey, status: 'unavailable' };

    // Add date filter if provided
    if (fromDate || toDate) {
      query.date = {};
      if (fromDate) {
        const start = new Date(fromDate);
        start.setHours(0, 0, 0, 0);
        query.date.$gte = start;
      }
      if (toDate) {
        const end = new Date(toDate);
        end.setHours(23, 59, 59, 999);
        query.date.$lte = end;
      }
    }

    const totalCount = await AvailabilityModel.countDocuments(query);
    console.log(`[executeGetMyUnavailableDates] Total matching: ${totalCount}`);

    const unavailableDates = await AvailabilityModel.find(query)
      .sort({ date: 1 })
      .limit(20)
      .select('date notes')
      .lean();

    const dates = unavailableDates.map((record: any) => ({
      date: record.date,
      notes: record.notes || null
    }));

    return {
      success: true,
      message: totalCount === 0
        ? 'No unavailable dates found'
        : `${totalCount} unavailable date(s)`,
      data: {
        dates,
        total: totalCount,
        showing: dates.length,
        remaining: Math.max(totalCount - dates.length, 0)
      }
    };
  } catch (error: any) {
    console.error('[executeGetMyUnavailableDates] Error:', error);
    return { success: false, message: `Failed to get unavailable dates: ${error.message}` };
  }
}

/**
 * Execute accept_shift function
 * Atomically adds user to accepted_staff, removes from declined_staff if present
 * Matches the logic in events.ts POST /events/:id/respond
 */
async function executeAcceptShift(
  userId: string,
  userKey: string,
  eventId: string,
  role?: string
): Promise<{ success: boolean; message: string; data?: any }> {
  try {
    console.log(`[executeAcceptShift] Accepting shift ${eventId} for userKey ${userKey}, role: ${role || 'auto-detect'}`);

    const event = await EventModel.findById(eventId).lean();
    if (!event) {
      return { success: false, message: 'Event not found' };
    }

    // Check if already accepted
    const alreadyAccepted = (event.accepted_staff || []).some((s: any) => s.userKey === userKey);
    if (alreadyAccepted) {
      const eventName = (event as any).shift_name || (event as any).event_name || (event as any).client_name || 'this shift';
      return { success: false, message: `You already accepted ${eventName}` };
    }

    // Determine role: explicit > invited_staff > first role with capacity
    let resolvedRole = role;
    if (!resolvedRole) {
      // Check if user was invited for a specific role
      const invitation = (event as any).invited_staff?.find((s: any) => s.userKey === userKey);
      if (invitation?.roleName) {
        resolvedRole = invitation.roleName;
      }
    }
    if (!resolvedRole) {
      // Find first role with available spots
      const roleStats = computeRoleStats((event.roles || []) as any[], (event.accepted_staff || []) as any[]);
      const availableRole = roleStats.find(r => !r.is_full && r.remaining > 0);
      if (availableRole) {
        resolvedRole = availableRole.role;
      }
    }
    if (!resolvedRole) {
      return { success: false, message: 'No available roles for this event. Please specify which role you want.' };
    }

    // Verify role exists and has capacity
    const roleReq = (event.roles || []).find((r: any) => (r.role || '').toLowerCase() === resolvedRole!.toLowerCase());
    if (!roleReq) {
      const availableRoles = (event.roles || []).map((r: any) => r.role).join(', ');
      return { success: false, message: `Role '${resolvedRole}' not found. Available roles: ${availableRoles}` };
    }

    // Look up staff user info
    const user = await UserModel.findById(userId).select('first_name last_name email name picture provider subject').lean();

    const staffDoc = {
      userKey,
      provider: (user as any)?.provider,
      subject: (user as any)?.subject,
      email: (user as any)?.email,
      name: (user as any)?.name || `${(user as any)?.first_name || ''} ${(user as any)?.last_name || ''}`.trim(),
      first_name: (user as any)?.first_name,
      last_name: (user as any)?.last_name,
      picture: (user as any)?.picture,
      response: 'accept',
      role: resolvedRole,
      respondedAt: new Date(),
    };

    // Atomic update: push to accepted_staff, pull from declined_staff
    const roleCapacity = roleReq.count || 0;
    const updatedEvent = await EventModel.findOneAndUpdate(
      {
        _id: eventId,
        'accepted_staff.userKey': { $ne: userKey },
        $expr: {
          $lt: [
            { $size: { $filter: { input: { $ifNull: ['$accepted_staff', []] }, as: 'staff', cond: { $eq: [{ $toLower: { $ifNull: ['$$staff.role', ''] } }, resolvedRole!.toLowerCase()] } } } },
            roleCapacity
          ]
        }
      },
      {
        $pull: { declined_staff: { userKey } } as any,
        $push: { accepted_staff: staffDoc } as any,
        $inc: { version: 1 },
        $set: { updatedAt: new Date() }
      },
      { new: true }
    );

    if (!updatedEvent) {
      return { success: false, message: `No spots left for role '${resolvedRole}'` };
    }

    // Update role_stats
    const newRoleStats = computeRoleStats((updatedEvent.roles as any[]) || [], (updatedEvent.accepted_staff as any[]) || []);
    await EventModel.updateOne({ _id: eventId }, { $set: { role_stats: newRoleStats } });

    const eventName = (updatedEvent as any).shift_name || (updatedEvent as any).event_name || (updatedEvent as any).client_name || 'shift';
    return {
      success: true,
      message: `Accepted ${eventName} as ${resolvedRole}`,
      data: { id: eventId, name: eventName, date: (updatedEvent as any).date, role: resolvedRole }
    };
  } catch (error: any) {
    console.error('[executeAcceptShift] Error:', error);
    return { success: false, message: `Failed to accept shift: ${error.message}` };
  }
}

/**
 * Execute decline_shift function
 * Atomically removes from accepted_staff (if previously accepted), adds to declined_staff
 */
async function executeDeclineShift(
  userId: string,
  userKey: string,
  eventId: string,
  reason?: string
): Promise<{ success: boolean; message: string; data?: any }> {
  try {
    console.log(`[executeDeclineShift] Declining shift ${eventId} for userKey ${userKey}, reason: ${reason || 'none'}`);

    const event = await EventModel.findById(eventId).lean();
    if (!event) {
      return { success: false, message: 'Event not found' };
    }

    // Check if already declined
    const alreadyDeclined = (event as any).declined_staff?.some((s: any) => s.userKey === userKey);
    if (alreadyDeclined) {
      return { success: false, message: 'You already declined this shift' };
    }

    // Look up staff user info
    const user = await UserModel.findById(userId).select('first_name last_name email name picture provider subject').lean();

    const staffDoc = {
      userKey,
      provider: (user as any)?.provider,
      subject: (user as any)?.subject,
      email: (user as any)?.email,
      name: (user as any)?.name || `${(user as any)?.first_name || ''} ${(user as any)?.last_name || ''}`.trim(),
      first_name: (user as any)?.first_name,
      last_name: (user as any)?.last_name,
      picture: (user as any)?.picture,
      response: reason || 'decline',
      respondedAt: new Date(),
    };

    // Atomic: pull from accepted_staff, push to declined_staff
    const updatedEvent = await EventModel.findOneAndUpdate(
      { _id: eventId },
      {
        $pull: { accepted_staff: { userKey } } as any,
        $push: { declined_staff: staffDoc } as any,
        $inc: { version: 1 },
        $set: { updatedAt: new Date() }
      },
      { new: true }
    );

    if (!updatedEvent) {
      return { success: false, message: 'Event not found' };
    }

    // Update role_stats
    const newRoleStats = computeRoleStats((updatedEvent.roles as any[]) || [], (updatedEvent.accepted_staff as any[]) || []);
    await EventModel.updateOne({ _id: eventId }, { $set: { role_stats: newRoleStats } });

    const eventName = (updatedEvent as any).shift_name || (updatedEvent as any).event_name || (updatedEvent as any).client_name || 'shift';
    return {
      success: true,
      message: `Declined ${eventName}`,
      data: { id: eventId, name: eventName }
    };
  } catch (error: any) {
    console.error('[executeDeclineShift] Error:', error);
    return { success: false, message: `Failed to decline shift: ${error.message}` };
  }
}

/**
 * Unified performance function — replaces 3 separate tools
 * Supports: current_month, last_month, last_3_months, last_6_months, last_year
 */
async function executeGetPerformance(
  userId: string,
  userKey: string,
  period: string = 'current_month'
): Promise<{ success: boolean; message: string; data?: any }> {
  try {
    console.log(`[executeGetPerformance] Getting ${period} stats for userKey ${userKey}`);

    const now = new Date();
    let start: Date;
    let end: Date = new Date(now);
    end.setHours(23, 59, 59, 999);
    let periodLabel: string;

    switch (period) {
      case 'last_month': {
        start = new Date(now.getFullYear(), now.getMonth() - 1, 1);
        end = new Date(now.getFullYear(), now.getMonth(), 0, 23, 59, 59, 999);
        periodLabel = start.toLocaleString('default', { month: 'long', year: 'numeric' });
        break;
      }
      case 'last_3_months': {
        start = new Date(now.getFullYear(), now.getMonth() - 3, 1);
        periodLabel = 'Last 3 months';
        break;
      }
      case 'last_6_months': {
        start = new Date(now.getFullYear(), now.getMonth() - 6, 1);
        periodLabel = 'Last 6 months';
        break;
      }
      case 'last_year': {
        start = new Date(now.getFullYear() - 1, now.getMonth(), now.getDate());
        periodLabel = 'Last 12 months';
        break;
      }
      default: {
        if (period.includes(':')) {
          // Custom range: "YYYY-MM-DD:YYYY-MM-DD"
          const parts = period.split(':');
          start = new Date(parts[0] || period);
          start.setHours(0, 0, 0, 0);
          end = new Date(parts[1] || parts[0] || period);
          end.setHours(23, 59, 59, 999);
          const startStr = start.toLocaleDateString('default', { month: 'short', day: 'numeric', year: 'numeric' });
          const endStr = end.toLocaleDateString('default', { month: 'short', day: 'numeric', year: 'numeric' });
          periodLabel = `${startStr} – ${endStr}`;
        } else {
          // current_month fallback
          start = new Date(now.getFullYear(), now.getMonth(), 1);
          end = new Date(now.getFullYear(), now.getMonth() + 1, 0, 23, 59, 59, 999);
          periodLabel = now.toLocaleString('default', { month: 'long', year: 'numeric' });
        }
        break;
      }
    }
    start.setHours(0, 0, 0, 0);

    console.log(`[executeGetPerformance] Date range: ${start.toISOString()} to ${end.toISOString()}`);

    const rawEvents = await EventModel.find({
      'accepted_staff.userKey': userKey,
      status: { $ne: 'cancelled' },
      date: { $gte: start, $lte: end }
    }).lean();

    // Enrich with tariff rates (same as Flutter earnings page)
    const events = await enrichEventsWithTariffs(rawEvents);

    console.log(`[executeGetPerformance] Found ${events.length} events`);

    const positionStats: Record<string, { count: number; hours: number; earnings: number }> = {};
    const monthlyStats: Record<string, { events: number; hours: number; earnings: number }> = {};
    let totalHours = 0;
    let totalEarnings = 0;
    let totalEvents = 0;

    for (const event of events) {
      const acceptedStaff = (event as any).accepted_staff || [];
      const userInShift = acceptedStaff.find((staff: any) => staff.userKey === userKey);

      if (userInShift && (userInShift.response === 'accepted' || userInShift.response === 'accept')) {
        const position = userInShift.role || 'Staff';
        const eventDate = new Date((event as any).date);
        const monthKey = `${eventDate.getFullYear()}-${String(eventDate.getMonth() + 1).padStart(2, '0')}`;

        // Hours: prefer approved attendance hours (matches Flutter earnings page)
        let hours = 0;
        const attendance = userInShift.attendance || [];
        for (const session of attendance) {
          if (session.approvedHours != null && session.status === 'approved') {
            hours += session.approvedHours;
          }
        }

        // Fallback: scheduled shift duration if no approved attendance
        if (hours === 0 && (event as any).start_time && (event as any).end_time) {
          const s = new Date(`1970-01-01T${(event as any).start_time}`);
          const e = new Date(`1970-01-01T${(event as any).end_time}`);
          hours = (e.getTime() - s.getTime()) / (1000 * 60 * 60);
          if (hours < 0) hours += 24;
        }

        if (hours === 0) continue;

        // Pay rate: prefer tariff rate (from catalog), fallback to pay_rate_info string
        const roles = (event as any).roles || [];
        const roleInfo = roles.find((r: any) => r.role_name === position || r.role === position);
        const tariffRate = roleInfo?.tariff?.rate;
        const wage = tariffRate || parsePayRate(roleInfo?.pay_rate_info) || parsePayRate((event as any).pay_rate_info);
        const earnings = wage * hours;

        if (!positionStats[position]) positionStats[position] = { count: 0, hours: 0, earnings: 0 };
        positionStats[position].count++;
        positionStats[position].hours += hours;
        positionStats[position].earnings += earnings;

        if (!monthlyStats[monthKey]) monthlyStats[monthKey] = { events: 0, hours: 0, earnings: 0 };
        monthlyStats[monthKey].events++;
        monthlyStats[monthKey].hours += hours;
        monthlyStats[monthKey].earnings += earnings;

        totalHours += hours;
        totalEarnings += earnings;
        totalEvents++;
      }
    }

    const byPosition = Object.entries(positionStats).map(([position, stats]) => ({
      position,
      events: stats.count,
      hours: Math.round(stats.hours * 10) / 10,
      earnings: Math.round(stats.earnings * 100) / 100
    }));

    const result: any = {
      period,
      periodLabel,
      totalEvents,
      totalHours: Math.round(totalHours * 10) / 10,
      totalEarnings: Math.round(totalEarnings * 100) / 100,
      byPosition,
      byMonth: Object.entries(monthlyStats)
        .map(([month, s]) => ({ month, events: s.events, hours: Math.round(s.hours * 10) / 10, earnings: Math.round(s.earnings * 100) / 100 }))
        .sort((a, b) => a.month.localeCompare(b.month)),
      averageWage: totalHours > 0 ? Math.round((totalEarnings / totalHours) * 100) / 100 : 0
    };

    // Add monthly breakdown for multi-month periods
    if (period !== 'current_month' && period !== 'last_month') {
      const monthCount = Object.keys(monthlyStats).length || 1;
      result.monthlyAverage = {
        events: Math.round(totalEvents / monthCount * 10) / 10,
        hours: Math.round(totalHours / monthCount * 10) / 10,
        earnings: Math.round(totalEarnings / monthCount * 100) / 100
      };
      result.monthsCovered = monthCount;
    }

    return { success: true, message: `Performance for ${periodLabel}`, data: result };
  } catch (error: any) {
    console.error('[executeGetPerformance] Error:', error);
    return { success: false, message: `Failed to get performance data: ${error.message}` };
  }
}

/**
 * Execute compose_message function
 * Returns structured data so the AI model can compose the message in its response
 */
async function executeComposeMessage(
  userKey: string,
  scenario: string,
  details: string
): Promise<{ success: boolean; message: string; data?: any }> {
  console.log(`[executeComposeMessage] Scenario: ${scenario}, Details: ${details}`);

  const [provider, subject] = userKey.split(':');

  // Look up all managers this staff member belongs to
  const teamMembers = await TeamMemberModel.find({
    provider,
    subject,
    status: 'active'
  }).select('managerId').lean();

  const managerIds = [...new Set(teamMembers.map(tm => tm.managerId.toString()))];
  const managers = await ManagerModel.find({ _id: { $in: managerIds } })
    .select('first_name last_name name')
    .lean();

  const managerList = managers.map((m: any) => ({
    id: String(m._id),
    name: m.first_name && m.last_name
      ? `${m.first_name} ${m.last_name}`
      : m.name || 'Manager'
  }));

  return {
    success: true,
    message: managerList.length === 1
      ? `Ready to compose. Manager: ${managerList[0]!.name}`
      : `Staff has ${managerList.length} managers. Ask which one.`,
    data: {
      scenario,
      details,
      ready_to_compose: true,
      managers: managerList,
    }
  };
}

/**
 * Execute send_message_to_manager function
 * Sends a chat message from the staff member to their manager
 */
async function executeSendMessageToManager(
  userKey: string,
  userId: string,
  messageText: string,
  managerId?: string | null
): Promise<{ success: boolean; message: string; data?: any }> {
  try {
    console.log(`[executeSendMessageToManager] Sending message for userKey ${userKey}`);

    const [provider, subject] = userKey.split(':');

    // Get the user's name for senderName
    const user = await UserModel.findById(userId).select('first_name last_name picture').lean();
    const senderName = user
      ? `${(user as any).first_name || ''} ${(user as any).last_name || ''}`.trim() || 'Staff Member'
      : 'Staff Member';
    const senderPicture = (user as any)?.picture || null;

    // Find manager: use provided ID or look up via TeamMember
    let targetManagerId: any;
    if (managerId) {
      targetManagerId = managerId;
    } else {
      const teamMember = await TeamMemberModel.findOne({
        provider,
        subject,
        status: 'active'
      }).select('managerId').lean();

      if (!teamMember) {
        return { success: false, message: 'Could not find your manager. You may not be on any active team.' };
      }
      targetManagerId = teamMember.managerId;
    }

    // Verify manager exists
    const manager = await ManagerModel.findById(targetManagerId).select('first_name last_name name').lean();
    if (!manager) {
      return { success: false, message: 'Manager not found' };
    }

    const managerName = (manager as any).first_name && (manager as any).last_name
      ? `${(manager as any).first_name} ${(manager as any).last_name}`
      : (manager as any).name || 'Manager';
    const managerFirstName = (manager as any).first_name || managerName.split(' ')[0];

    // Replace placeholder names in the message (AI sometimes uses these)
    let finalMessage = messageText.trim()
      .replace(/\[Manager Name\]/gi, managerName)
      .replace(/\[Manager's Name\]/gi, managerName)
      .replace(/\[manager name\]/gi, managerName)
      .replace(/\[Your Manager\]/gi, managerName)
      .replace(/Dear Manager/gi, `Dear ${managerFirstName}`)
      .replace(/Hi Manager,/gi, `Hi ${managerFirstName},`)
      .replace(/Hello Manager,/gi, `Hello ${managerFirstName},`);

    // Find or create conversation
    const conversation = await ConversationModel.findOneAndUpdate(
      { managerId: targetManagerId, userKey },
      { $setOnInsert: { managerId: targetManagerId, userKey } },
      { upsert: true, new: true }
    );

    // Create chat message
    const chatMessage = await ChatMessageModel.create({
      conversationId: conversation._id,
      managerId: targetManagerId,
      userKey,
      senderType: 'user',
      senderName,
      senderPicture,
      message: finalMessage,
      messageType: 'text',
      readByManager: false,
      readByUser: true,
    });

    // Update conversation metadata
    await ConversationModel.findByIdAndUpdate(conversation._id, {
      lastMessageAt: chatMessage.createdAt,
      lastMessagePreview: finalMessage.substring(0, 200),
      $inc: { unreadCountManager: 1 }
    });

    // Emit real-time notification to manager
    const messagePayload = {
      id: String(chatMessage._id),
      conversationId: String(conversation._id),
      senderType: 'user',
      senderName,
      senderPicture,
      message: chatMessage.message,
      messageType: 'text',
      readByManager: false,
      readByUser: true,
      createdAt: chatMessage.createdAt,
    };
    emitToManager(targetManagerId.toString(), 'chat:message', messagePayload);

    console.log(`[executeSendMessageToManager] Message sent to ${managerName} (${targetManagerId})`);

    return {
      success: true,
      message: `Message sent to ${managerName}`,
      data: { managerName, conversationId: String(conversation._id) }
    };
  } catch (error: any) {
    console.error('[executeSendMessageToManager] Error:', error);
    return { success: false, message: `Failed to send message: ${error.message}` };
  }
}

/**
 * Execute get_shift_details function
 * Returns full event details including pay, notes, roles
 */
async function executeGetShiftDetails(
  eventId: string,
  userKey: string,
  userId?: string
): Promise<{ success: boolean; message: string; data?: any }> {
  try {
    console.log(`[executeGetShiftDetails] Getting details for event ${eventId}`);

    const event = await EventModel.findOne({
      _id: eventId,
      'accepted_staff.userKey': userKey
    })
      .select('shift_name event_name client_name date start_time end_time venue_name venue_address city state notes roles pay_rate_info uniform accepted_staff status contact_name contact_phone contact_email setup_time')
      .lean();

    if (!event) {
      return { success: false, message: 'Event not found or you are not assigned to it' };
    }

    const e = event as any;

    // Find user's specific assignment in accepted_staff
    const userInEvent = e.accepted_staff?.find((staff: any) => staff.userKey === userKey);

    // Find role details matching user's position
    const userRole = userInEvent?.role || userInEvent?.position;
    const roleInfo = e.roles?.find((r: any) => r.role_name === userRole || r.role === userRole);

    const data: any = {
      name: e.shift_name || e.event_name || e.client_name || 'Untitled',
      client: e.client_name,
      date: e.date,
      time: `${e.start_time} - ${e.end_time}`,
      venue: e.venue_name,
      address: e.venue_address,
      city: e.city,
      state: e.state,
      notes: e.notes || null,
      status: e.status,
      yourRole: userRole || 'Not assigned',
      yourStatus: userInEvent?.response || 'unknown',
      payRate: roleInfo?.pay_rate_info || e.pay_rate_info || null,
      uniform: e.uniform || null,
      contactName: e.contact_name || null,
      contactPhone: e.contact_phone || null,
      contactEmail: e.contact_email || null,
      setupTime: e.setup_time || null,
      roleDetails: roleInfo ? {
        name: roleInfo.role_name || roleInfo.role,
        quantity: roleInfo.quantity || roleInfo.count,
        payRate: roleInfo.pay_rate_info,
      } : null,
      allRoles: e.roles?.map((r: any) => ({
        name: r.role_name || r.role,
        quantity: r.quantity || r.count,
        payRate: r.pay_rate_info,
      })) || [],
    };

    // Enrich with commute data if user has home coordinates
    if (userId) {
      try {
        const user = await UserModel.findById(userId).select('homeCoordinates').lean();
        const home = user?.homeCoordinates;
        const venueAddr = e.venue_address || e.venue_name;
        if (home?.lat && home?.lng && venueAddr) {
          const commute = await computeCommute(home.lat, home.lng, venueAddr);
          if (commute) {
            data.miles = commute.miles;
            data.commute_min = commute.minutes;
          }
        }
      } catch (commuteErr) {
        console.warn('[executeGetShiftDetails] Commute enrichment failed (non-fatal):', commuteErr);
      }
    }

    return { success: true, message: 'Event details found', data };
  } catch (error: any) {
    console.error('[executeGetShiftDetails] Error:', error);
    return { success: false, message: `Failed to get event details: ${error.message}` };
  }
}

/**
 * Execute create_personal_event — creates event + linked availability
 * Includes 5-minute dedup guard and estimated earnings calculation (like manager create_event)
 */
async function executeCreatePersonalEvent(
  userKey: string,
  title: string,
  date: string,
  startTime: string,
  endTime: string,
  notes?: string,
  location?: string,
  role?: string,
  client?: string,
  hourlyRate?: number,
): Promise<{ success: boolean; message: string; data?: any }> {
  try {
    // Validate required fields
    if (!title || !date || !startTime || !endTime) {
      return { success: false, message: '❌ Missing required fields. Need: title, date, start_time, end_time' };
    }

    const eventDate = new Date(date + 'T00:00:00');
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    if (eventDate < today) {
      return { success: false, message: `❌ Cannot create events in the past. The date ${date} has already passed.` };
    }

    // 5-minute dedup guard — prevent duplicate creation
    const fiveMinAgo = new Date(Date.now() - 5 * 60 * 1000);
    const existingDup = await PersonalEventModel.findOne({
      userKey, title, date: eventDate, startTime,
      createdAt: { $gte: fiveMinAgo },
    }).lean();

    if (existingDup) {
      const dupDate = existingDup.date instanceof Date ? existingDup.date.toISOString().split('T')[0] : String(existingDup.date);
      return {
        success: true,
        message: `⚠️ This event already exists (created moments ago).\n📌 "${existingDup.title}" on ${dupDate} from ${existingDup.startTime} to ${existingDup.endTime}\nEvent ID: ${existingDup._id}\nDo NOT create again — use this existing event.`,
        data: { id: String(existingDup._id), alreadyExists: true },
      };
    }

    const personalEvent = await PersonalEventModel.create({
      userKey, title, date: eventDate, startTime, endTime,
      notes: notes || undefined, location: location || undefined,
      role: role || undefined, client: client || undefined,
      hourlyRate: hourlyRate ?? undefined,
    });

    // Auto-create linked unavailability
    const avail = await AvailabilityModel.create({
      userKey, date, startTime, endTime,
      status: 'unavailable',
      notes: notes || undefined,
      personalEventId: personalEvent._id,
      source: 'personal_event',
    });

    personalEvent.availabilityId = avail._id as any;
    await personalEvent.save();

    // Build rich response (fat response pattern — like manager create_event)
    let summary = `✅ Personal event created! Event ID: ${personalEvent._id}\n`;
    summary += `📌 ${title}\n`;
    summary += `📅 Date: ${date}\n`;
    summary += `⏰ Time: ${startTime} – ${endTime}\n`;
    if (role) summary += `👔 Role: ${role}\n`;
    if (client) summary += `🏢 Client: ${client}\n`;
    if (location) summary += `📍 Location: ${location}\n`;
    if (notes) summary += `📝 Notes: ${notes}\n`;

    // Calculate estimated earnings
    if (hourlyRate && hourlyRate > 0) {
      const startParts = startTime.split(':').map(Number);
      const endParts = endTime.split(':').map(Number);
      const startMins = startParts[0] * 60 + startParts[1];
      const endMins = endParts[0] * 60 + endParts[1];
      const hours = endMins > startMins ? (endMins - startMins) / 60.0 : 0;
      if (hours > 0) {
        const total = hours * hourlyRate;
        summary += `💰 Pay: $${hourlyRate}/hr × ${hours.toFixed(1)}h = ~$${total.toFixed(0)}\n`;
      } else {
        summary += `💰 Rate: $${hourlyRate}/hr\n`;
      }
    }

    summary += `\n🚫 Managers will see you as unavailable during this time.`;

    return {
      success: true,
      message: summary,
      data: {
        id: String(personalEvent._id),
        title, date, startTime, endTime,
        notes: notes || null, location: location || null,
        role: role || null, client: client || null,
        hourlyRate: hourlyRate ?? null,
      },
    };
  } catch (err: any) {
    console.error('[executeCreatePersonalEvent] Error:', err);
    return { success: false, message: 'Failed to create personal event.' };
  }
}

/**
 * Execute create_personal_events_bulk — bulk create personal events + linked availability
 * Supports up to 20 events at once with dedup guard (like manager create_events_bulk)
 */
async function executeCreatePersonalEventsBulk(
  userKey: string,
  events: any[],
): Promise<{ success: boolean; message: string; data?: any }> {
  try {
    if (!Array.isArray(events) || events.length === 0) {
      return { success: false, message: '❌ No events provided. Pass an array of event objects.' };
    }
    if (events.length > 20) {
      return { success: false, message: `❌ Too many events (${events.length}). Maximum is 20 per bulk operation.` };
    }

    // Validate all events before creating any
    const todayBulk = new Date();
    todayBulk.setHours(0, 0, 0, 0);
    for (let i = 0; i < events.length; i++) {
      const ev = events[i];
      if (!ev.title || !ev.date || !ev.start_time || !ev.end_time) {
        return { success: false, message: `❌ Event #${i + 1} missing required fields. Need: title, date, start_time, end_time` };
      }
      if (new Date(ev.date) < todayBulk) {
        return { success: false, message: `❌ Event #${i + 1} has a past date (${ev.date}). All events must be in the future.` };
      }
    }

    // Dedup guard: check against recently created events (last 5 min)
    const bulkFiveMinAgo = new Date(Date.now() - 5 * 60 * 1000);
    const recentEvents = await PersonalEventModel.find({
      userKey,
      createdAt: { $gte: bulkFiveMinAgo },
    }).select('_id title date startTime').lean();

    if (recentEvents.length > 0) {
      let matchedCount = 0;
      for (const ev of events) {
        const evDateStr = new Date(ev.date).toISOString().slice(0, 10);
        const match = recentEvents.find((r: any) => {
          const rDate = r.date instanceof Date ? r.date.toISOString().slice(0, 10) : String(r.date);
          return r.title === ev.title && rDate === evDateStr && r.startTime === ev.start_time;
        });
        if (match) matchedCount++;
      }

      // If >=50% already exist, block creation
      if (matchedCount >= Math.ceil(events.length / 2)) {
        let dupMsg = `⚠️ These events already exist (created moments ago). Found ${recentEvents.length} recent events:\n`;
        recentEvents.forEach((d: any, i: number) => {
          const dt = d.date instanceof Date ? d.date.toISOString().split('T')[0] : String(d.date);
          dupMsg += `  ${i + 1}. ${d.title} — ${dt} — ID: ${d._id}\n`;
        });
        dupMsg += `\nDo NOT create again. Use these existing event IDs.`;
        return { success: true, message: dupMsg, data: { alreadyExists: true } };
      }
    }

    // Pre-generate ObjectIds and build document arrays for bulk insert
    let totalEarnings = 0;
    const availabilityDocs: any[] = [];
    const personalEventDocs: any[] = [];

    for (const ev of events) {
      const personalEventId = new mongoose.Types.ObjectId();
      const availabilityId = new mongoose.Types.ObjectId();
      const evDate = new Date(ev.date + 'T00:00:00');

      availabilityDocs.push({
        _id: availabilityId,
        userKey,
        date: ev.date,
        startTime: ev.start_time,
        endTime: ev.end_time,
        status: 'unavailable',
        notes: ev.notes || undefined,
        personalEventId,
        source: 'personal_event',
      });

      personalEventDocs.push({
        _id: personalEventId,
        userKey,
        title: ev.title,
        date: evDate,
        startTime: ev.start_time,
        endTime: ev.end_time,
        notes: ev.notes || undefined,
        location: ev.location || undefined,
        role: ev.role || undefined,
        client: ev.client || undefined,
        hourlyRate: ev.hourly_rate ?? undefined,
        availabilityId,
      });

      // Calculate earnings for this event
      if (ev.hourly_rate && ev.hourly_rate > 0) {
        const sp = ev.start_time.split(':').map(Number) as number[];
        const ep = ev.end_time.split(':').map(Number) as number[];
        const hours = (((ep[0] || 0) * 60 + (ep[1] || 0)) - ((sp[0] || 0) * 60 + (sp[1] || 0))) / 60.0;
        if (hours > 0) totalEarnings += hours * ev.hourly_rate;
      }
    }

    // Bulk insert both collections in a transaction (atomic: all-or-nothing)
    const session = await mongoose.startSession();
    let created: any[];
    try {
      session.startTransaction();
      await AvailabilityModel.insertMany(availabilityDocs, { session });
      created = await PersonalEventModel.insertMany(personalEventDocs, { session });
      await session.commitTransaction();
    } catch (txErr) {
      await session.abortTransaction();
      throw txErr;
    } finally {
      session.endSession();
    }

    let summary = `✅ Created ${created.length} personal events:\n`;
    created.forEach((c: any, i: number) => {
      const dt = c.date instanceof Date ? c.date.toISOString().split('T')[0] : String(c.date);
      summary += `  ${i + 1}. ${c.title}${c.role ? ` (${c.role})` : ''} — ${dt} ${c.startTime}–${c.endTime}${c.client ? ` for ${c.client}` : ''} — ID: ${c._id}\n`;
    });

    if (totalEarnings > 0) {
      summary += `\n💰 Total estimated earnings: ~$${totalEarnings.toFixed(0)}`;
    }
    summary += `\n🚫 Managers will see you as unavailable for all these time slots.`;

    return {
      success: true,
      message: summary,
      data: {
        events: created.map((c: any) => ({
          id: String(c._id),
          title: c.title,
          date: c.date instanceof Date ? c.date.toISOString().split('T')[0] : String(c.date),
        })),
      },
    };
  } catch (err: any) {
    console.error('[executeCreatePersonalEventsBulk] Error:', err);
    return { success: false, message: `Failed to create events: ${err.message}` };
  }
}

/**
 * Execute update_personal_event — update event + linked availability
 */
async function executeUpdatePersonalEvent(
  userKey: string,
  eventId: string,
  updates: {
    title?: string;
    date?: string;
    startTime?: string;
    endTime?: string;
    notes?: string;
    location?: string;
    role?: string;
    client?: string;
    hourlyRate?: number;
  },
): Promise<{ success: boolean; message: string; data?: any }> {
  try {
    const existing = await PersonalEventModel.findOne({ _id: eventId, userKey });
    if (!existing) {
      return { success: false, message: 'Personal event not found or does not belong to you.' };
    }

    // Validate new date is not in the past
    if (updates.date) {
      const newDate = new Date(updates.date + 'T00:00:00');
      const today = new Date();
      today.setHours(0, 0, 0, 0);
      if (newDate < today) {
        return { success: false, message: `❌ Cannot move event to a past date (${updates.date}).` };
      }
    }

    // Apply updates to personal event
    const changes: string[] = [];
    if (updates.date) { (existing as any).date = new Date(updates.date + 'T00:00:00'); changes.push(`date → ${updates.date}`); }
    if (updates.title) { existing.title = updates.title; changes.push(`title → "${updates.title}"`); }
    if (updates.startTime) { existing.startTime = updates.startTime; changes.push(`start → ${updates.startTime}`); }
    if (updates.endTime) { existing.endTime = updates.endTime; changes.push(`end → ${updates.endTime}`); }
    if (updates.notes !== undefined) { existing.notes = updates.notes || undefined; changes.push('notes updated'); }
    if (updates.location !== undefined) { existing.location = updates.location || undefined; changes.push(`location → "${updates.location}"`); }
    if (updates.role !== undefined) { (existing as any).role = updates.role || undefined; changes.push(`role → "${updates.role}"`); }
    if (updates.client !== undefined) { (existing as any).client = updates.client || undefined; changes.push(`client → "${updates.client}"`); }
    if (updates.hourlyRate !== undefined) { (existing as any).hourlyRate = updates.hourlyRate ?? undefined; changes.push(`rate → $${updates.hourlyRate}/hr`); }
    await existing.save();

    // Update linked availability record
    if (existing.availabilityId) {
      const availUpdates: any = { status: 'unavailable', source: 'personal_event' };
      if (updates.date) availUpdates.date = updates.date;
      if (updates.startTime) availUpdates.startTime = updates.startTime;
      if (updates.endTime) availUpdates.endTime = updates.endTime;
      if (updates.notes !== undefined) availUpdates.notes = updates.notes;
      await AvailabilityModel.findByIdAndUpdate(existing.availabilityId, availUpdates);
    }

    const dateStr = existing.date instanceof Date ? existing.date.toISOString().split('T')[0] : String(existing.date);

    return {
      success: true,
      message: `✅ Personal event "${existing.title}" updated.\n📅 ${dateStr} ${existing.startTime}–${existing.endTime}\nChanges: ${changes.join(', ')}`,
      data: {
        id: String(existing._id),
        title: existing.title,
        date: dateStr,
        startTime: existing.startTime,
        endTime: existing.endTime,
        role: (existing as any).role || null,
        client: (existing as any).client || null,
        hourlyRate: (existing as any).hourlyRate ?? null,
      },
    };
  } catch (err: any) {
    console.error('[executeUpdatePersonalEvent] Error:', err);
    return { success: false, message: 'Failed to update personal event.' };
  }
}

/**
 * Execute update_personal_events_bulk — apply the same field updates to multiple personal events
 */
async function executeUpdatePersonalEventsBulk(
  userKey: string,
  eventIds: string[],
  updates: {
    title?: string;
    location?: string;
    role?: string;
    client?: string;
    hourlyRate?: number;
    notes?: string;
  },
): Promise<{ success: boolean; message: string; data?: any }> {
  try {
    if (!eventIds || eventIds.length === 0) {
      return { success: false, message: 'No event IDs provided.' };
    }
    if (eventIds.length > 50) {
      return { success: false, message: 'Too many events (max 50).' };
    }

    // Build the $set object from provided updates
    const setFields: any = {};
    const changeDescriptions: string[] = [];
    if (updates.title !== undefined) { setFields.title = updates.title; changeDescriptions.push(`title → "${updates.title}"`); }
    if (updates.location !== undefined) { setFields.location = updates.location; changeDescriptions.push(`location → "${updates.location}"`); }
    if (updates.role !== undefined) { setFields.role = updates.role; changeDescriptions.push(`role → "${updates.role}"`); }
    if (updates.client !== undefined) { setFields.client = updates.client; changeDescriptions.push(`client → "${updates.client}"`); }
    if (updates.hourlyRate !== undefined) { setFields.hourlyRate = updates.hourlyRate; changeDescriptions.push(`rate → $${updates.hourlyRate}/hr`); }
    if (updates.notes !== undefined) { setFields.notes = updates.notes; changeDescriptions.push('notes updated'); }

    if (Object.keys(setFields).length === 0) {
      return { success: false, message: 'No fields to update.' };
    }

    // Update all matching events that belong to this user
    const result = await PersonalEventModel.updateMany(
      { _id: { $in: eventIds }, userKey },
      { $set: setFields }
    );

    const updatedCount = result.modifiedCount || 0;
    const matchedCount = result.matchedCount || 0;

    console.log(`[executeUpdatePersonalEventsBulk] Updated ${updatedCount}/${matchedCount} of ${eventIds.length} events for userKey=${userKey}. Changes: ${changeDescriptions.join(', ')}`);

    if (matchedCount === 0) {
      return { success: false, message: 'No matching personal events found. Make sure the event IDs are correct.' };
    }

    return {
      success: true,
      message: `✅ Updated ${updatedCount} personal event(s).\nChanges: ${changeDescriptions.join(', ')}`,
      data: { updatedCount, matchedCount, requested: eventIds.length, changes: changeDescriptions },
    };
  } catch (err: any) {
    console.error('[executeUpdatePersonalEventsBulk] Error:', err);
    return { success: false, message: 'Failed to bulk-update personal events.' };
  }
}

/**
 * Execute get_my_personal_events — list user's personal events
 * Supports date_range (same as get_my_schedule) with backward-compat for legacy period param
 */
async function executeGetMyPersonalEvents(
  userKey: string,
  period?: string,
  dateRange?: string,
  limit?: number,
): Promise<{ success: boolean; message: string; data?: any }> {
  try {
    const filter: any = { userKey };
    const today = new Date();
    today.setHours(0, 0, 0, 0);

    // date_range takes precedence over legacy period param
    if (dateRange) {
      const df = buildDateFilter(dateRange);
      if (Object.keys(df).length > 0) {
        Object.assign(filter, df);
      } else {
        // Unrecognized dateRange — fall through to default (all events)
        console.warn(`[executeGetMyPersonalEvents] Unrecognized date_range: ${dateRange}`);
      }
    } else if (period === 'future') {
      filter.date = { $gte: today };
    } else if (period === 'past') {
      filter.date = { $lt: today };
    }

    const eventLimit = Math.min(limit || 50, 50);

    const events = await PersonalEventModel.find(filter)
      .sort({ date: 1 })
      .limit(eventLimit)
      .lean();

    if (events.length === 0) {
      return { success: true, message: 'You have no personal events.', data: { events: [] } };
    }

    const mapped = events.map((e: any) => ({
      id: String(e._id),
      title: e.title,
      date: e.date instanceof Date ? e.date.toISOString().split('T')[0] : String(e.date),
      startTime: e.startTime,
      endTime: e.endTime,
      notes: e.notes || null,
      location: e.location || null,
      role: e.role || null,
      client: e.client || null,
      hourlyRate: e.hourlyRate ?? null,
    }));

    return {
      success: true,
      message: `Found ${events.length} personal event(s).`,
      data: { events: mapped },
    };
  } catch (err: any) {
    console.error('[executeGetMyPersonalEvents] Error:', err);
    return { success: false, message: 'Failed to retrieve personal events.' };
  }
}

/**
 * Execute delete_personal_event — delete event + linked availability
 */
async function executeDeletePersonalEvent(
  userKey: string,
  eventId: string,
): Promise<{ success: boolean; message: string }> {
  try {
    const existing = await PersonalEventModel.findOne({ _id: eventId, userKey });
    if (!existing) {
      return { success: false, message: 'Personal event not found or does not belong to you.' };
    }

    // Delete linked availability
    if (existing.availabilityId) {
      await AvailabilityModel.findByIdAndDelete(existing.availabilityId);
    }

    const title = existing.title;
    await PersonalEventModel.deleteOne({ _id: eventId });

    return { success: true, message: `Personal event "${title}" deleted. You are no longer marked as unavailable for that time.` };
  } catch (err: any) {
    console.error('[executeDeletePersonalEvent] Error:', err);
    return { success: false, message: 'Failed to delete personal event.' };
  }
}

/**
 * Execute search_address — resolve a query to a formatted address via Google Places
 */
async function executeSearchAddress(
  query: string,
): Promise<{ success: boolean; message: string; data?: any }> {
  try {
    const googleMapsKey = process.env.GOOGLE_MAPS_API_KEY;
    if (!googleMapsKey) {
      return { success: false, message: 'Google Maps API key not configured on server.' };
    }

    // Step 1: Autocomplete
    const acParams = new URLSearchParams({
      input: query,
      key: googleMapsKey,
      location: '39.7392,-104.9903',
      radius: '450000',
      region: 'us',
      components: 'country:us',
    });

    const acResponse = await axios.get(
      `https://maps.googleapis.com/maps/api/place/autocomplete/json?${acParams.toString()}`
    );

    const predictions = acResponse.data?.predictions || [];
    if (predictions.length === 0) {
      return { success: false, message: `No results found for "${query}". Try a more specific address or venue name.` };
    }

    // Step 2: Get details for top result
    const placeId = predictions[0].place_id;
    const detParams = new URLSearchParams({
      place_id: placeId,
      key: googleMapsKey,
      fields: 'formatted_address,geometry,address_components,name',
    });

    const detResponse = await axios.get(
      `https://maps.googleapis.com/maps/api/place/details/json?${detParams.toString()}`
    );

    if (detResponse.data?.status !== 'OK') {
      return { success: false, message: 'Could not resolve address details.' };
    }

    const result = detResponse.data.result;
    const formatted = result.formatted_address || query;
    const lat = result.geometry?.location?.lat;
    const lng = result.geometry?.location?.lng;
    const name = result.name || '';

    console.log(`[executeSearchAddress] Resolved "${query}" → "${formatted}"`);

    return {
      success: true,
      message: `Found: ${name ? name + ' — ' : ''}${formatted}`,
      data: {
        formatted_address: formatted,
        name,
        latitude: lat,
        longitude: lng,
        place_id: placeId,
      }
    };
  } catch (err: any) {
    console.error('[executeSearchAddress] Error:', err.message);
    return { success: false, message: 'Failed to search address.' };
  }
}

/**
 * Execute staff function based on name and arguments
 */
async function executeStaffFunction(
  functionName: string,
  functionArgs: any,
  userId: string,
  userKey: string,
  subscriptionTier: 'free' | 'pro' = 'free'
): Promise<{ success: boolean; message: string; data?: any }> {
  console.log(`[executeStaffFunction] Executing ${functionName} with args:`, functionArgs, 'tier:', subscriptionTier);

  switch (functionName) {
    case 'mark_availability':
      return await executeMarkAvailability(
        userKey,
        functionArgs.dates || [],
        functionArgs.status || 'unavailable',
        functionArgs.notes
      );

    case 'get_my_schedule':
      return await executeGetMySchedule(userId, userKey, functionArgs.date_range, functionArgs.limit, subscriptionTier);

    case 'get_earnings_summary':
      return await executeGetEarningsSummary(userId, userKey, functionArgs.date_range);

    case 'get_all_my_events':
      // Backward compat: redirect to get_my_schedule with no date filter
      return await executeGetAllMyEvents(userId, userKey);

    case 'get_my_unavailable_dates':
      return await executeGetMyUnavailableDates(userKey, functionArgs.from_date, functionArgs.to_date);

    case 'accept_shift':
      return await executeAcceptShift(userId, userKey, functionArgs.event_id, functionArgs.role);

    case 'decline_shift':
      return await executeDeclineShift(userId, userKey, functionArgs.event_id, functionArgs.reason);

    case 'get_performance':
      return await executeGetPerformance(userId, userKey, functionArgs.period || 'current_month');

    // Backward compat: old tool names still work
    case 'performance_current_month':
      return await executeGetPerformance(userId, userKey, 'current_month');
    case 'performance_last_month':
      return await executeGetPerformance(userId, userKey, 'last_month');
    case 'performance_last_year':
      return await executeGetPerformance(userId, userKey, 'last_year');

    case 'compose_message':
      return await executeComposeMessage(userKey, functionArgs.scenario, functionArgs.details);

    case 'send_message_to_manager':
      return await executeSendMessageToManager(userKey, userId, functionArgs.message, functionArgs.manager_id);

    case 'get_shift_details':
      return await executeGetShiftDetails(functionArgs.event_id, userKey, userId);

    case 'create_personal_event':
      return await executeCreatePersonalEvent(
        userKey,
        functionArgs.title,
        functionArgs.date,
        functionArgs.start_time,
        functionArgs.end_time,
        functionArgs.notes,
        functionArgs.location,
        functionArgs.role,
        functionArgs.client,
        functionArgs.hourly_rate != null ? Number(functionArgs.hourly_rate) : undefined,
      );

    case 'create_personal_events_bulk':
      return await executeCreatePersonalEventsBulk(userKey, functionArgs.events);

    case 'update_personal_event':
      return await executeUpdatePersonalEvent(userKey, functionArgs.event_id, {
        title: functionArgs.title || undefined,
        date: functionArgs.date || undefined,
        startTime: functionArgs.start_time || undefined,
        endTime: functionArgs.end_time || undefined,
        notes: functionArgs.notes,
        location: functionArgs.location,
        role: functionArgs.role,
        client: functionArgs.client,
        hourlyRate: functionArgs.hourly_rate != null ? Number(functionArgs.hourly_rate) : undefined,
      });

    case 'update_personal_events_bulk':
      return await executeUpdatePersonalEventsBulk(userKey, functionArgs.event_ids || [], {
        title: functionArgs.title || undefined,
        location: functionArgs.location,
        role: functionArgs.role,
        client: functionArgs.client,
        hourlyRate: functionArgs.hourly_rate != null ? Number(functionArgs.hourly_rate) : undefined,
        notes: functionArgs.notes,
      });

    case 'get_my_personal_events':
      return await executeGetMyPersonalEvents(userKey, functionArgs.period, functionArgs.date_range, functionArgs.limit);

    case 'delete_personal_event':
      return await executeDeletePersonalEvent(userKey, functionArgs.event_id);

    case 'search_address':
      return await executeSearchAddress(functionArgs.query);

    default:
      return {
        success: false,
        message: `Unknown function: ${functionName}`
      };
  }
}

/**
 * POST /api/ai/staff/chat/message
 * Staff AI chat endpoint (OpenAI or Claude)
 * Scoped to staff user's own data
 */
router.post('/ai/staff/chat/message', requireAuth, requireActiveSubscription, async (req, res) => {
  try {
    const oauthProvider = (req as any).user?.provider;
    const subject = (req as any).user?.sub;

    if (!oauthProvider || !subject) {
      return res.status(401).json({ message: 'Unauthorized' });
    }

    // Load staff user details by provider and subject
    const user = await UserModel.findOne({ provider: oauthProvider, subject })
      .select('_id first_name last_name email phone_number app_id subscription_tier createdAt free_month_end_override')
      .lean();
    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }

    const userId = String(user._id);
    const userKey = `${oauthProvider}:${subject}`;
    const subscriptionTier = (user as any).subscription_tier || 'free';
    const userInFreeMonth = isInFreeMonth(user);

    // Tier-specific AI message limits
    // Free month users: unlimited (no counting)
    // Subscribed tiers: enforce per-tier limit with monthly reset
    // Read-only users are already blocked by requireActiveSubscription middleware
    const TIER_AI_LIMITS: Record<string, number> = { starter: 3, pro: 25, premium: 50 };
    const tierLimit = TIER_AI_LIMITS[subscriptionTier];

    if (tierLimit != null) {
      // Subscribed tier — enforce monthly limit
      const mutableUser = await UserModel.findOne({ provider: oauthProvider, subject });
      if (!mutableUser) {
        return res.status(404).json({ message: 'User not found' });
      }

      // Reset monthly counter if needed
      const now = new Date();
      const resetDate = mutableUser.ai_messages_reset_date || new Date();

      if (now > resetDate) {
        mutableUser.ai_messages_used_this_month = 0;
        const nextMonth = new Date(now);
        nextMonth.setMonth(nextMonth.getMonth() + 1);
        nextMonth.setDate(1);
        nextMonth.setHours(0, 0, 0, 0);
        mutableUser.ai_messages_reset_date = nextMonth;
        console.log(`[ai/staff/chat/message] Reset message counter for user ${userId}, next reset: ${nextMonth.toISOString()}`);
      }

      const messagesUsed = mutableUser.ai_messages_used_this_month || 0;

      if (messagesUsed >= tierLimit) {
        const canUpgrade = subscriptionTier === 'starter';
        console.log(`[ai/staff/chat/message] ${subscriptionTier} user ${userId} hit message limit (${messagesUsed}/${tierLimit})`);
        return res.status(402).json({
          message: canUpgrade
            ? `You've used your ${tierLimit} AI messages this month. Upgrade to Pro for ${TIER_AI_LIMITS.pro} messages/month.`
            : `You've reached your monthly AI message limit (${tierLimit} messages). Your limit resets next month.`,
          upgradeRequired: canUpgrade,
          usage: {
            used: messagesUsed,
            limit: tierLimit,
            resetDate: mutableUser.ai_messages_reset_date,
          },
        });
      }

      mutableUser.ai_messages_used_this_month = messagesUsed + 1;
      await mutableUser.save();

      console.log(`[ai/staff/chat/message] ${subscriptionTier} message count for user ${userId}: ${messagesUsed + 1}/${tierLimit}`);
    } else if (userInFreeMonth) {
      // Free month: unlimited AI messages (no counting)
      console.log(`[ai/staff/chat/message] Free month user ${userId} — unlimited AI`);
    }

    const validated = chatMessageSchema.parse(req.body);
    const { messages, temperature, maxTokens, model } = validated;

    // Always use 120B with high reasoning — no cascade, no keyword routing.
    const selectedProvider = 'groq' as const;
    const selectedModel = 'openai/gpt-oss-120b';

    console.log(`[ai/staff/chat/message] provider=${selectedProvider}, model=${selectedModel} for user ${userId}, subscription: ${subscriptionTier}`);

    const timezone = getTimezoneFromRequest(req);

    return await handleStaffGroqRequest(messages, temperature, maxTokens, res, timezone, userId, userKey, subscriptionTier, selectedModel, selectedProvider, 'complex');
  } catch (err: any) {
    console.error('[ai/staff/chat/message] Error:', err);
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
 * Handle Groq chat request for staff with optimized Chat Completions API
 * Model is selected by cascade router: Tier 1 (simple) → gpt-oss-20b @ Together, Tier 2 (complex) → gpt-oss-120b @ Groq
 * Features: Parallel tool calls, prompt caching, retry logic, reasoning mode with extended tokens
 */
async function handleStaffGroqRequest(
  messages: any[],
  temperature: number,
  maxTokens: number,
  res: any,
  timezone?: string,
  userId?: string,
  userKey?: string,
  subscriptionTier?: 'free' | 'pro',
  model?: string,
  provider: 'groq' | 'together' = 'groq',
  cascadeTier: 'simple' | 'complex' = 'simple'
) {
  const requestStartTime = Date.now();
  const groqModel = model || 'openai/gpt-oss-120b';
  const config = getProviderConfig(provider, groqModel);

  if (!config.apiKey) {
    console.error(`[AI:${config.name}] API key not configured`);
    return res.status(500).json({ message: `${config.name} API key not configured on server` });
  }

  const isReasoningModel = config.supportsReasoning && groqModel.includes('gpt-oss');

  console.log(`[AI:${config.name}] Staff using model: ${config.model}`);

  // Optimize prompt structure: CRITICAL rules FIRST (open-source models follow early instructions better)
  const systemInstructions = `
🤖 YOUR IDENTITY — "VALERIO":
- Your name is **Valerio**. You are the AI assistant built into the FlowShift platform for staff members.

🎯 YOUR JOB: Help staff members view their schedule, shifts, earnings, and availability.
**YOU MUST ALWAYS ANSWER QUESTIONS** - never refuse to provide information about their work.

✅ WHAT YOU MUST DO:
1. **ALWAYS answer questions** about shifts, schedule, jobs, events, earnings
2. **ALWAYS convert data to friendly natural language** - users should see nice readable text
3. **ALWAYS use [LINK:Venue Name] format** for venues (makes them clickable in app)
4. **ALWAYS respond in the user's language** (Spanish → Spanish, English → English)

❌ WHAT YOU MUST NOT DO:
1. Never show raw JSON, code blocks, or technical formatting
2. Never show IDs, timestamps, or database field names (like _id, eventId)
3. Never REFUSE to show information - always convert it to friendly text
4. Never say "I cannot provide information" - you CAN and MUST provide it in a friendly way

📅 HOW TO FORMAT EVENTS/SHIFTS:
When showing schedule information, use this friendly format:

**📋 Your Next 3 Shifts:**

1. **Saturday, Jan 25th** • 4:00 PM - 11:00 PM
   📍 [LINK:Mission Ballroom]
   🚗 15.8 mi · 22 min each way
   👔 Bartender • Client: Epicurean

2. **Sunday, Jan 26th** • 10:00 AM - 6:00 PM
   📍 [LINK:Convention Center]
   🚗 8.2 mi · 14 min each way
   👔 Server • Client: Tech Corp

3. 🏷️ **Monday, Jan 27th** • 6:00 PM - 10:00 PM *(Personal)*
   📍 Marriott Downtown
   🚗 5.1 mi · 10 min each way
   👔 Bartender • $30/hr

(Use emojis, bold text, and clear formatting. Tag personal events with 🏷️ and *(Personal)* to distinguish from manager shifts.
When event data includes "miles" and "commute_min" fields, show the 🚗 commute line under the venue. If those fields are missing, omit the commute line.)

📊 HOW MANY TO SHOW:
- "my schedule" / "my shifts" / "my jobs" → Show next 7-10 upcoming
- "next shift" → Show ONLY 1 (the soonest one)
- "next 7 jobs" → Show exactly 7
- "this week" / "this month" → All events in that period

🔧 CRITICAL TOOL USAGE:
- The context data only shows UPCOMING events. It does NOT contain past/completed events.
- When user asks about ANY specific date range, past events, history, or "show me shifts from X to Y":
  → You MUST call get_my_schedule with the appropriate date_range. NEVER answer from context alone.
- get_my_schedule now returns BOTH manager-assigned shifts (source: "manager") AND personal events (source: "personal").
  → When showing results, label personal events distinctly with 🏷️ Personal tag so staff can tell them apart from assigned shifts.
  → Personal events have source: "personal" and status: "personal" in the data.
- The eventSummary.pastEvents count tells you how many past events exist — use the tool to fetch them.
- get_earnings_summary ALWAYS returns earnings broken down by venue, role, AND client (byVenue, byRole, byClient arrays).
  → ALWAYS include total earned, total hours, AND total events in your initial earnings response. Never skip hours or event count.
  → When user asks "break it down by venue/role/client/location", look at the PREVIOUS get_earnings_summary result in conversation — the breakdown is already there. Do NOT call the tool again.
  → Format the breakdown as a numbered list with earned amount, hours, and event count per entry.
- get_performance returns byPosition (role breakdown) AND byMonth (monthly breakdown).
  → When user asks "how many hours in February?" or "break it down by month", use the PREVIOUS get_performance result. Do NOT call the tool again.
- get_my_schedule and get_all_my_events include pay rate per shift.
  → When user asks "how much does this pay?" after viewing their schedule, the pay info is already there. Do NOT call get_shift_details just for pay.
- Use get_my_personal_events ONLY for personal-event-specific queries (e.g. "show my personal gigs") or when you need the event ID for update/delete operations. For general schedule queries, get_my_schedule already includes personal events.
- get_my_schedule and get_shift_details include commute data (miles, commute_min) when the user has a home address set in their profile.
  → Use this to answer "how far is my next shift?", "analyze my commute this week", etc.
  → If commute fields are missing, the user hasn't set a home address — suggest they set it in Profile → Home Address.
  → For weekly/monthly commute analysis, sum up miles and minutes across events and present totals + averages.

🗓️ DATE HANDLING FOR SCHEDULE QUERIES:
- When user asks about past months (e.g. "October to December", "last summer", "January shifts"):
  → These are PAST events. Use the most recent past occurrence (e.g. Oct-Dec 2025, NOT 2026).
  → Staff want to review their work history. Default to PAST unless they say "upcoming" or "next".
- When ambiguous and could be past OR future, ASK: "Do you mean October-December 2025 or 2026?"
- Only use future dates when user explicitly says "next", "upcoming", or the month hasn't happened yet this year.

📅 AVAILABILITY (mark_availability only):
- The "already passed → next year" rule ONLY applies here: when MARKING availability for future dates.
  Example: User says "I'm unavailable in February" in December 2025 → use February 2026.
- Use mark_availability tool directly — it saves to the database immediately
- After marking, confirm naturally: "Done! Marked you as unavailable for Feb 15-17."
- Expand date ranges to individual ISO dates: "Feb 15-17" → ["2026-02-15", "2026-02-16", "2026-02-17"]

📌 PERSONAL EVENTS (AGENTIC WORKFLOW):
Tools: create_personal_event, create_personal_events_bulk, update_personal_event, update_personal_events_bulk, get_my_personal_events, delete_personal_event, search_address
NOTE: get_my_schedule already includes personal events alongside shifts. Use get_my_personal_events only for personal-specific queries or to find an event ID before update/delete.

WHEN TO USE:
- Staff mentions personal gigs, side jobs, freelance work, doctor visits, school, or blocking time
- Triggers: "I have a wedding gig Saturday", "Add my freelance event", "I bartend every Saturday at Marriott"
- Different from mark_availability — creates a FULL event card in My Shifts with role, client, and pay tracking

ADDRESS LOOKUP (search_address):
- When staff mentions a venue or location (e.g. "at Cherokee Ranch", "at the Marriott downtown"), call search_address FIRST to resolve it to a real address
- Pass the formatted_address from search_address as the location in create_personal_event
- Example flow: "gig at Cherokee Ranch" → search_address("Cherokee Ranch") → gets "Cherokee Ranch and Castle, 6113 N Daniels Park Rd, Sedalia, CO 80135" → use that as location
- If search_address returns no results, use the staff's original text as-is

SINGLE EVENT (create_personal_event):
- Executes directly — no confirmation needed
- ALWAYS extract role, client, and hourly_rate when staff mentions them
- Example: "I'm bartending at Marriott Saturday 4-10pm for $30/hr" → role: "Bartender", client: "Marriott", hourly_rate: 30
- After creating, present the summary with estimated earnings: "Done! Added Bartender gig at Marriott — $30/hr × 6h = ~$180"
- The response includes FULL event details. Do NOT call get_my_personal_events after creating.

BULK CREATION (create_personal_events_bulk):
- For recurring patterns: "every Saturday in March", "I have 3 gigs next week", "block off all Mondays for school"
- Present a summary of all events BEFORE creating. Ask user to confirm.
- After creation, show the full list with total estimated earnings.
- ⚠️ CRITICAL: When user says "yes"/"si"/"create" after you present the summary, create them. If they already exist (dedup guard triggers), do NOT recreate.

UPDATING (update_personal_event / update_personal_events_bulk):
- First use get_my_personal_events to find the event ID(s)
- Single event: call update_personal_event with only the fields that changed
- Multiple events with same change: call update_personal_events_bulk with all event IDs + the shared field values
  Example: "update the address on all my La Tinto events" → get IDs → update_personal_events_bulk with event_ids + location
- ⚠️ NEVER claim data is already correct without COMPARING the exact field value from get_my_personal_events against the new value. If user asks to update, ALWAYS call the update tool.
- Also updates the linked unavailability automatically

DELETING (delete_personal_event):
- First use get_my_personal_events to find the event ID
- Then call delete_personal_event — also removes linked unavailability
- Confirm: "Done! Removed 'Wedding Gig' and you're available again for that time slot."

💬 MESSAGING:
- When user wants to send a message to their manager (call off, running late, time off, etc.):
  1. First use compose_message — it returns the manager name(s) and IDs
  2. Use the ACTUAL manager name in the message (e.g., "Hi Juan," NOT "Hi [Manager Name],"). NEVER use placeholders like [Manager Name]!
  3. If compose_message returns MULTIPLE managers, ask: "Which manager should I send this to?" and list them by name
  4. Present the drafted message and ask: "Want me to send this to [manager name]?"
  5. ONLY call send_message_to_manager after explicit confirmation ("yes", "send it", "go ahead")
  6. Pass the correct manager_id when calling send_message_to_manager (from compose_message response)
  7. Never send without asking first!

📋 SHIFT DETAILS:
- When user asks about specific shift details (pay, notes, what to wear), use get_shift_details
- If they don't specify which shift, use get_my_schedule first to find it, then get_shift_details
- Present all details in a friendly, readable format`;

  const dateContext = getFullSystemContext(timezone);

  // Put static instructions FIRST (cacheable), dynamic date context LAST (not cached)
  const systemContent = `${systemInstructions}\n\n${dateContext}`;

  // Build messages: system prompt first (cached), then conversation
  const processedMessages: any[] = [];
  let hasSystemMessage = false;

  for (const msg of messages) {
    if (msg.role === 'system') {
      processedMessages.push({
        role: 'system',
        content: `${systemContent}\n\n${msg.content}`
      });
      hasSystemMessage = true;
    } else {
      processedMessages.push({
        role: msg.role,
        content: typeof msg.content === 'string' ? msg.content : JSON.stringify(msg.content)
      });
    }
  }

  if (!hasSystemMessage) {
    processedMessages.unshift({
      role: 'system',
      content: systemContent
    });
  }

  // Send all tools — with only 10 staff tools, pre-filtering adds fragility for no benefit.
  const lastUserMsg = extractLastUserMessage(messages);
  console.log(`[AI:${config.name}] Sending all ${STAFF_AI_TOOLS.length} staff tools for query: "${lastUserMsg.substring(0, 80)}"`);

  const groqTools = STAFF_AI_TOOLS.map(tool => ({
    type: 'function',
    function: {
      name: tool.name,
      description: tool.description,
      parameters: tool.parameters
    }
  }));

  // Medium reasoning on 120B is the sweet spot: fast + capable.
  // Reasoning only applies to the first call (Groq rejects it on follow-ups with tool results).
  // Since the first call is just tool selection, medium effort is sufficient.
  const reasoningEffort = 'medium';
  const maxOutputTokens = 3000;

  // Build request body with model-specific optimizations
  const requestBody: any = {
    model: config.model,
    messages: processedMessages,
    temperature: isReasoningModel ? 0.5 : temperature,
    max_tokens: isReasoningModel ? maxOutputTokens : maxTokens,
    tools: groqTools,
    tool_choice: 'auto'
  };

  // Add provider-specific reasoning parameters
  if (isReasoningModel) {
    requestBody.reasoning_effort = reasoningEffort;
    if (config.name === 'groq') {
      requestBody.reasoning_format = 'parsed'; // Groq-only: separates reasoning into message.reasoning
    } else if (config.name === 'together') {
      requestBody.reasoning = { enabled: true }; // Together AI uses reasoning object
    }
    console.log(`[AI:${config.name}] Using reasoning mode (effort=${reasoningEffort}) with ${requestBody.max_tokens} max tokens`);
  }

  const headers = {
    'Authorization': `Bearer ${config.apiKey}`,
    'Content-Type': 'application/json',
  };

  // Retry logic with exponential backoff
  const maxRetries = 3;
  let lastError: any = null;

  for (let attempt = 1; attempt <= maxRetries; attempt++) {
    try {
      console.log(`[AI:${config.name}] Attempt ${attempt}/${maxRetries} - Calling /v1/chat/completions...`);

      // Extended timeout for reasoning models (120s vs 60s)
      const timeout = isReasoningModel ? 120000 : 60000;

      const response = await axios.post(
        config.baseUrl,
        requestBody,
        { headers, validateStatus: () => true, timeout }
      );

      console.log(`[AI:${config.name}] Response status:`, response.status);

      // Handle rate limits with retry
      if (response.status === 429) {
        const retryAfter = parseInt(response.headers['retry-after'] || '5', 10);
        if (attempt < maxRetries) {
          console.log(`[AI:${config.name}] Rate limited, retrying after ${retryAfter}s...`);
          await new Promise(resolve => setTimeout(resolve, retryAfter * 1000));
          continue;
        }
        return res.status(429).json({
          message: `${config.name} API rate limit reached. Please try again later.`,
        });
      }

      // Handle other errors
      if (response.status >= 300) {
        console.error(`[AI:${config.name}] API error:`, response.status, response.data);

        lastError = { status: response.status, data: response.data };

        console.log(`[AI:${config.name}] Model error:`, response.status);

        return res.status(response.status).json({
          message: `${config.name} API error: ${response.statusText}`,
          details: response.data,
        });
      }

      // Parse successful response
      const choice = response.data.choices?.[0];
      if (!choice) {
        throw new Error('No choices in response');
      }

      const assistantMessage = choice.message;

      // Track token usage across all requests in this conversation turn
      const totalUsage = {
        prompt_tokens: 0,
        completion_tokens: 0,
        reasoning_tokens: 0,
        total_tokens: 0,
      };
      const apiUsage = response.data.usage;
      if (apiUsage) {
        totalUsage.prompt_tokens += apiUsage.prompt_tokens || 0;
        totalUsage.completion_tokens += apiUsage.completion_tokens || 0;
        totalUsage.reasoning_tokens += apiUsage.completion_tokens_details?.reasoning_tokens || 0;
        totalUsage.total_tokens += apiUsage.total_tokens || 0;
        console.log(`[AI:${config.name}] Usage - prompt: ${totalUsage.prompt_tokens}, completion: ${totalUsage.completion_tokens}, reasoning: ${totalUsage.reasoning_tokens}, total: ${totalUsage.total_tokens}`);
      }

      // Capture reasoning from first request
      const firstRequestReasoning = assistantMessage.reasoning || null;
      if (firstRequestReasoning) console.log(`[AI:${config.name}] Reasoning received:`, firstRequestReasoning.length, 'chars');

      // Handle tool calls (including parallel calls for llama)
      if (assistantMessage.tool_calls && assistantMessage.tool_calls.length > 0) {
        console.log(`[AI:${config.name}] ${assistantMessage.tool_calls.length} tool call(s) requested`);

        // Execute tool calls in parallel with error handling
        const toolResults = await Promise.all(
          assistantMessage.tool_calls.map(async (toolCall: any) => {
            const functionName = toolCall.function.name;

            try {
              let functionArgs: any;
              try {
                functionArgs = JSON.parse(toolCall.function.arguments);
              } catch (parseError: any) {
                console.error(`[AI:${config.name}] Failed to parse tool arguments for ${functionName}:`, toolCall.function.arguments);
                return {
                  role: 'tool',
                  tool_call_id: toolCall.id,
                  content: JSON.stringify({ error: `Failed to parse function arguments: ${parseError.message}` })
                };
              }

              console.log(`[AI:${config.name}] Executing ${functionName}:`, functionArgs);

              const result = await executeStaffFunction(
                functionName,
                functionArgs,
                userId!,
                userKey!,
                subscriptionTier || 'free'
              );

              return {
                role: 'tool',
                tool_call_id: toolCall.id,
                content: JSON.stringify(result)
              };
            } catch (execError: any) {
              console.error(`[AI:${config.name}] Tool execution failed for ${functionName}:`, execError);
              return {
                role: 'tool',
                tool_call_id: toolCall.id,
                content: JSON.stringify({ error: `Error executing ${functionName}: ${execError.message}` })
              };
            }
          })
        );

        // Multi-step tool calling loop (supports chaining e.g. get_schedule → check_availability)
        // CRITICAL: Strip `reasoning` from assistant message before sending in follow-up.
        // Groq returns { role, content, tool_calls, reasoning } when reasoning is enabled,
        // but rejects follow-up requests that contain `reasoning` in message history (tool_use_failed 400).
        const sanitizedAssistant: any = { role: assistantMessage.role, content: assistantMessage.content };
        if (assistantMessage.tool_calls) sanitizedAssistant.tool_calls = assistantMessage.tool_calls;

        let currentMessages = [
          ...processedMessages,
          sanitizedAssistant,
          ...toolResults
        ];
        const allToolsUsed = [...assistantMessage.tool_calls.map((tc: any) => tc.function.name)];

        // Same model for synthesis — always 120B, no escalation needed.
        let synthesisConfig = config;
        let synthesisModel = requestBody.model;

        const synthesisHeaders = {
          'Authorization': `Bearer ${synthesisConfig.apiKey}`,
          'Content-Type': 'application/json',
        };
        const secondTimeout = (synthesisConfig.supportsReasoning && synthesisModel.includes('gpt-oss')) ? 120000 : 60000;

        // --- finish_reason-driven tool call loop (industry standard) ---
        // Instead of a fixed step count, let the model signal when it's done
        // via finish_reason. Safety cap prevents infinite loops.
        const SAFETY_CAP = 15;
        const TOKEN_BUDGET = 100000; // Stay under Groq's ~128K context window

        let finalContent = '';
        let finalReasoning: string | null = null;
        let step = 0;

        while (step < SAFETY_CAP) {
          step++;

          // Token budget guard — stop before hitting context window limits
          if (totalUsage.prompt_tokens > TOKEN_BUDGET) {
            console.warn(`[AI:${synthesisConfig.name}] Token budget exceeded (${totalUsage.prompt_tokens}/${TOKEN_BUDGET}), forcing synthesis`);
            break;
          }

          console.log(`[AI:${synthesisConfig.name}] Follow-up step ${step}/${SAFETY_CAP}...`);

          const response = await axios.post(
            synthesisConfig.baseUrl,
            {
              model: synthesisModel,
              messages: currentMessages,
              temperature: requestBody.temperature,
              max_tokens: requestBody.max_tokens,
              tools: groqTools,
              tool_choice: 'auto',
              // NOTE: Omit reasoning params on follow-up requests with tool results
              // to avoid tool_use_failed errors from Groq
            },
            { headers: synthesisHeaders, validateStatus: () => true, timeout: secondTimeout }
          );

          // Accumulate usage from follow-up request
          const followUpUsage = response.data?.usage;
          if (followUpUsage) {
            totalUsage.prompt_tokens += followUpUsage.prompt_tokens || 0;
            totalUsage.completion_tokens += followUpUsage.completion_tokens || 0;
            totalUsage.reasoning_tokens += followUpUsage.completion_tokens_details?.reasoning_tokens || 0;
            totalUsage.total_tokens += followUpUsage.total_tokens || 0;
          }

          const finishReason = response.data.choices?.[0]?.finish_reason;
          const message = response.data.choices?.[0]?.message;
          console.log(`[AI:${synthesisConfig.name}] Step ${step} finish_reason=${finishReason}`);

          // Handle tool_use_failed - use context-aware fallback
          if (response.status === 400 && response.data?.error?.code === 'tool_use_failed') {
            console.log(`[AI:${synthesisConfig.name}] tool_use_failed detected, using context-aware fallback...`);

            const allToolResultsSummary = currentMessages
              .filter((m: any) => m.role === 'tool')
              .map((tr: any) => {
                try {
                  const parsed = typeof tr.content === 'string' ? JSON.parse(tr.content) : tr.content;
                  return JSON.stringify(parsed, null, 2);
                } catch {
                  return tr.content;
                }
              }).join('\n\n');

            // Include recent conversation context (not just last user msg)
            // so short confirmations like "Si"/"yes" have the assistant question they're answering.
            // CRITICAL: Strip tool_calls from assistant messages — if the model sees prior tool_calls
            // in history but no tools array, it tries to call tools anyway → Groq 400 "tool choice is none"
            const nonSystemMessages = processedMessages.filter((m: any) => m.role !== 'system');
            const recentContext = nonSystemMessages.slice(-6)
              .filter((m: any) => m.role === 'user' || (m.role === 'assistant' && m.content))
              .map((m: any) => ({ role: m.role, content: typeof m.content === 'string' ? m.content : JSON.stringify(m.content) }));

            const fallbackMessages = [
              ...processedMessages.filter((m: any) => m.role === 'system'),
              ...recentContext,
              {
                role: 'assistant',
                content: `I looked up the relevant data:\n\n${allToolResultsSummary}`
              },
              {
                role: 'user',
                content: `Based on that data and our conversation above, please complete what I asked for. If I gave a short confirmation like "si", "yes", or "do it", look at what you previously proposed and proceed. If I asked about my schedule, shifts, or availability, present the information clearly. Do NOT just summarize the data - actually respond to what I asked for.`
              }
            ];

            console.log(`[AI:${synthesisConfig.name}] Fallback messages count:`, fallbackMessages.length);

            const fallbackResponse = await axios.post(
              synthesisConfig.baseUrl,
              {
                model: synthesisModel,
                messages: fallbackMessages,
                temperature: requestBody.temperature,
                max_tokens: requestBody.max_tokens,
              },
              { headers: synthesisHeaders, validateStatus: () => true, timeout: secondTimeout }
            );

            console.log(`[AI:${synthesisConfig.name}] Fallback response status:`, fallbackResponse.status);

            if (fallbackResponse.status >= 300) {
              console.error(`[AI:${synthesisConfig.name}] Fallback also failed:`, fallbackResponse.data);
              finalContent = `Here's what I found:\n\n${allToolResultsSummary}`;
              finalReasoning = null;
            } else {
              const fm = fallbackResponse.data.choices?.[0]?.message;
              finalContent = fm?.content || `Here's what I found:\n\n${allToolResultsSummary}`;
              finalReasoning = fm?.reasoning || null;
              console.log(`[AI:${synthesisConfig.name}] Fallback content length:`, finalContent.length);
            }
            break;
          }

          if (response.status >= 300) {
            console.error(`[AI:${synthesisConfig.name}] Follow-up API call error:`, response.status, response.data);
            throw new Error(`Follow-up API call failed: ${response.statusText}`);
          }

          // --- finish_reason-driven exit conditions ---

          // Model says it's done — extract content and stop
          if (finishReason === 'stop' || finishReason === 'end_turn') {
            finalContent = message?.content || '';
            finalReasoning = message?.reasoning || null;
            console.log(`[AI:${synthesisConfig.name}] Model done (${finishReason}), content length: ${finalContent.length}`);
            if (finalReasoning) console.log(`[AI:${synthesisConfig.name}] Reasoning length: ${finalReasoning.length}`);
            break;
          }

          // Model hit max_tokens — take partial content + warning
          if (finishReason === 'length') {
            finalContent = (message?.content || '') + '\n\n*(Response truncated due to length)*';
            finalReasoning = message?.reasoning || null;
            console.warn(`[AI:${synthesisConfig.name}] Response truncated (finish_reason=length)`);
            break;
          }

          // Model wants to call more tools
          if (message?.tool_calls && message.tool_calls.length > 0) {
            console.log(`[AI:${synthesisConfig.name}] Step ${step}: ${message.tool_calls.length} tool call(s) [${message.tool_calls.map((tc: any) => tc.function.name).join(', ')}]`);

            const additionalResults = await Promise.all(
              message.tool_calls.map(async (toolCall: any) => {
                const functionName = toolCall.function.name;
                try {
                  let functionArgs: any;
                  try {
                    functionArgs = JSON.parse(toolCall.function.arguments);
                  } catch (parseError: any) {
                    console.error(`[AI:${synthesisConfig.name}] Failed to parse tool arguments for ${functionName}:`, toolCall.function.arguments);
                    return {
                      role: 'tool',
                      tool_call_id: toolCall.id,
                      content: `Error: Failed to parse arguments: ${parseError.message}`
                    };
                  }

                  console.log(`[AI:${synthesisConfig.name}] Executing ${functionName}:`, functionArgs);
                  allToolsUsed.push(functionName);
                  const result = await executeStaffFunction(
                    functionName,
                    functionArgs,
                    userId!,
                    userKey!,
                    subscriptionTier || 'free'
                  );
                  return {
                    role: 'tool',
                    tool_call_id: toolCall.id,
                    content: JSON.stringify(result)
                  };
                } catch (execError: any) {
                  console.error(`[AI:${synthesisConfig.name}] Tool execution failed for ${functionName}:`, execError);
                  return {
                    role: 'tool',
                    tool_call_id: toolCall.id,
                    content: JSON.stringify({ error: `Error executing ${functionName}: ${execError.message}` })
                  };
                }
              })
            );

            // Strip reasoning from assistant message to prevent tool_use_failed on next iteration
            const sanitizedMsg: any = { role: message.role, content: message.content };
            if (message.tool_calls) sanitizedMsg.tool_calls = message.tool_calls;

            currentMessages = [
              ...currentMessages,
              sanitizedMsg,
              ...additionalResults
            ];
            continue; // Loop for next tool call round
          }

          // Unexpected finish_reason or no tool calls and no 'stop' — take whatever content exists
          console.warn(`[AI:${synthesisConfig.name}] Unexpected state: finish_reason=${finishReason}, has_content=${!!message?.content}, has_tools=${!!message?.tool_calls}`);
          finalContent = message?.content || '';
          finalReasoning = message?.reasoning || null;
          break;
        }

        // Safety cap or token budget exhausted — synthesize instead of dumping raw JSON
        if (!finalContent && (step >= SAFETY_CAP || totalUsage.prompt_tokens > TOKEN_BUDGET)) {
          console.warn(`[AI:${synthesisConfig.name}] Loop exhausted (step=${step}, tokens=${totalUsage.prompt_tokens}), attempting synthesis...`);

          const allToolResultsSummary = currentMessages
            .filter((m: any) => m.role === 'tool')
            .map((tr: any) => {
              try {
                const parsed = typeof tr.content === 'string' ? JSON.parse(tr.content) : tr.content;
                return JSON.stringify(parsed, null, 2);
              } catch {
                return tr.content;
              }
            }).join('\n\n');

          const nonSystemMsgs = processedMessages.filter((m: any) => m.role !== 'system');
          const recentCtx = nonSystemMsgs.slice(-6)
            .filter((m: any) => m.role === 'user' || (m.role === 'assistant' && m.content))
            .map((m: any) => ({ role: m.role, content: typeof m.content === 'string' ? m.content : JSON.stringify(m.content) }));

          try {
            const synthesisResponse = await axios.post(
              synthesisConfig.baseUrl,
              {
                model: synthesisModel,
                messages: [
                  ...processedMessages.filter((m: any) => m.role === 'system'),
                  ...recentCtx,
                  {
                    role: 'assistant',
                    content: `I completed the requested actions. Here are the results:\n\n${allToolResultsSummary}`
                  },
                  {
                    role: 'user',
                    content: `Based on our conversation above and these results, summarize what you did. Be concise.`
                  }
                ],
                temperature: requestBody.temperature,
                max_tokens: requestBody.max_tokens,
              },
              { headers: synthesisHeaders, validateStatus: () => true, timeout: secondTimeout }
            );

            if (synthesisResponse.status < 300) {
              const sm = synthesisResponse.data.choices?.[0]?.message;
              finalContent = sm?.content || '';
              finalReasoning = sm?.reasoning || null;
              console.log(`[AI:${synthesisConfig.name}] Synthesis fallback succeeded, content length: ${finalContent.length}`);
            }
          } catch (synthError: any) {
            console.error(`[AI:${synthesisConfig.name}] Synthesis fallback failed:`, synthError.message);
          }

          // Last resort: raw summary
          if (!finalContent) {
            finalContent = allToolResultsSummary || 'Done! The requested actions have been completed.';
          }
        } else if (!finalContent) {
          finalContent = 'Done! The requested actions have been completed.';
        }

        console.log(`[AI:${synthesisConfig.name}] Total usage - prompt: ${totalUsage.prompt_tokens}, completion: ${totalUsage.completion_tokens}, reasoning: ${totalUsage.reasoning_tokens}, total: ${totalUsage.total_tokens}`);
        logAIUsage({
          userId,
          userType: 'staff',
          endpoint: 'staff/chat/message',
          provider: synthesisConfig.name as 'groq' | 'together',
          model: synthesisModel,
          inputTokens: totalUsage.prompt_tokens,
          outputTokens: totalUsage.completion_tokens,
          reasoningTokens: totalUsage.reasoning_tokens,
          totalTokens: totalUsage.total_tokens,
          durationMs: Date.now() - requestStartTime,
          toolCallCount: allToolsUsed.length,
          toolsSelected: STAFF_AI_TOOLS.length,
          tier: cascadeTier,
        }).catch(() => {});
        return res.json({
          content: finalContent,
          reasoning: finalReasoning || firstRequestReasoning || null,
          provider: synthesisConfig.name,
          model: synthesisModel,
          toolsUsed: allToolsUsed,
          usage: totalUsage,
        });
      }

      // No tool calls, return content directly
      const content = assistantMessage.content;
      const reasoningContent = assistantMessage.reasoning || null;
      if (!content) {
        throw new Error('No content in response');
      }

      if (reasoningContent) {
        console.log(`[AI:${config.name}] Reasoning content length:`, reasoningContent.length);
      }

      logAIUsage({
        userId,
        userType: 'staff',
        endpoint: 'staff/chat/message',
        provider: config.name as 'groq' | 'together',
        model: requestBody.model,
        inputTokens: totalUsage.prompt_tokens,
        outputTokens: totalUsage.completion_tokens,
        reasoningTokens: totalUsage.reasoning_tokens,
        totalTokens: totalUsage.total_tokens,
        durationMs: Date.now() - requestStartTime,
        toolCallCount: 0,
        toolsSelected: STAFF_AI_TOOLS.length,
        tier: cascadeTier,
      }).catch(() => {});
      return res.json({
        content,
        reasoning: reasoningContent,
        provider: config.name,
        model: requestBody.model,
        usage: totalUsage,
      });

    } catch (error: any) {
      lastError = error;
      console.error(`[AI:${config.name}] Attempt ${attempt}/${maxRetries} failed:`, {
        message: error.message,
        status: error.response?.status,
        data: error.response?.data
      });

      // If this was the last attempt, fall through to error handler
      if (attempt === maxRetries) break;

      // Exponential backoff: 1s, 2s, 4s
      const backoffMs = Math.pow(2, attempt - 1) * 1000;
      console.log(`[AI:${config.name}] Retrying after ${backoffMs}ms...`);
      await new Promise(resolve => setTimeout(resolve, backoffMs));
    }
  }

  // All retries exhausted
  return res.status(500).json({
    message: `${config.name} API request failed after retries`,
    error: lastError?.message || 'Unknown error',
    details: lastError?.response?.data || lastError?.message
  });
}

// ============================================================================
// STAFF AI CHAT SUMMARY ENDPOINTS - For learning and analytics
// ============================================================================

import { AIChatSummaryModel } from '../models/aiChatSummary';

/**
 * Zod schema for staff conversation message
 */
const staffConversationMessageSchema = z.object({
  role: z.enum(['user', 'assistant', 'system']),
  content: z.string().max(10000),
  timestamp: z.string(), // ISO string
});

/**
 * Zod schema for saving staff chat summary
 */
const saveStaffChatSummarySchema = z.object({
  messages: z.array(staffConversationMessageSchema).min(1),
  outcome: z.enum([
    'availability_marked', 'shift_accepted', 'shift_declined', 'question_answered',
    'abandoned', 'error',
  ]),
  outcomeReason: z.string().max(500).optional().nullable(),
  durationMs: z.number().min(0),
  toolsUsed: z.array(z.string()).optional(),
  inputSource: z.enum(['text', 'voice']).optional(),
  aiModel: z.string(),
  aiProvider: z.string(),
  conversationStartedAt: z.string(),
  conversationEndedAt: z.string(),
  // Staff-specific context
  actionData: z.record(z.unknown()).optional(), // Data related to the action (availability, shift, etc.)
});

/**
 * POST /api/ai/staff/chat/summary
 * Save staff AI chat conversation summary
 */
router.post('/ai/staff/chat/summary', requireAuth, async (req, res) => {
  try {
    const authUser = (req as any).user || (req as any).authUser;
    const { provider, sub: subject } = authUser || {};

    if (!provider || !subject) {
      return res.status(401).json({ error: 'Staff authentication required' });
    }

    // Find the user ID
    const user = await UserModel.findOne({ provider, subject }).select('_id').lean();
    if (!user) {
      return res.status(404).json({ error: 'Staff user not found' });
    }

    // Validate request body
    const parseResult = saveStaffChatSummarySchema.safeParse(req.body);
    if (!parseResult.success) {
      return res.status(400).json({
        error: 'Validation failed',
        details: parseResult.error.flatten(),
      });
    }

    const data = parseResult.data;

    // Convert string timestamps to Date objects
    const messages = data.messages.map(m => ({
      ...m,
      timestamp: new Date(m.timestamp),
    }));

    // Create the summary document
    const summary = new AIChatSummaryModel({
      userId: user._id,
      userType: 'staff',
      messages,
      extractedEventData: data.actionData || {}, // Use actionData for staff
      outcome: data.outcome,
      outcomeReason: data.outcomeReason,
      durationMs: data.durationMs,
      toolCallCount: 0, // Staff AI doesn't use tool calls like manager
      toolsUsed: data.toolsUsed || [],
      inputSource: data.inputSource || 'text',
      wasEdited: false, // Staff AI doesn't have edit functionality
      editedFields: [],
      aiModel: data.aiModel,
      aiProvider: data.aiProvider,
      conversationStartedAt: new Date(data.conversationStartedAt),
      conversationEndedAt: new Date(data.conversationEndedAt),
    });

    await summary.save();

    console.log(`[staff/chat/summary] Saved conversation summary for user ${user._id}, outcome: ${data.outcome}`);

    return res.status(201).json({
      message: 'Staff chat summary saved successfully',
      id: summary._id,
    });
  } catch (error: any) {
    console.error('[staff/chat/summary] Error saving summary:', error);
    return res.status(500).json({
      error: 'Failed to save staff chat summary',
      message: error.message,
    });
  }
});

/**
 * GET /api/ai/staff/chat/summaries
 * List staff conversation summaries with pagination
 */
router.get('/ai/staff/chat/summaries', requireAuth, async (req, res) => {
  try {
    const authUser = (req as any).user || (req as any).authUser;
    const { provider, sub: subject } = authUser || {};

    if (!provider || !subject) {
      return res.status(401).json({ error: 'Staff authentication required' });
    }

    const user = await UserModel.findOne({ provider, subject }).select('_id').lean();
    if (!user) {
      return res.status(404).json({ error: 'Staff user not found' });
    }

    const page = Math.max(1, parseInt(req.query.page as string) || 1);
    const limit = Math.min(50, Math.max(1, parseInt(req.query.limit as string) || 20));
    const skip = (page - 1) * limit;

    const [summaries, total] = await Promise.all([
      AIChatSummaryModel.find({ userId: user._id, userType: 'staff' })
        .sort({ createdAt: -1 })
        .skip(skip)
        .limit(limit)
        .select('outcome messageCount durationMs inputSource aiModel createdAt')
        .lean(),
      AIChatSummaryModel.countDocuments({ userId: user._id, userType: 'staff' }),
    ]);

    return res.json({
      summaries: summaries.map(s => ({
        id: s._id,
        outcome: s.outcome,
        messageCount: s.messageCount,
        durationMs: s.durationMs,
        durationFormatted: `${Math.round(s.durationMs / 1000)}s`,
        inputSource: s.inputSource,
        aiModel: s.aiModel,
        createdAt: s.createdAt,
      })),
      pagination: {
        page,
        limit,
        total,
        totalPages: Math.ceil(total / limit),
      },
    });
  } catch (error: any) {
    console.error('[staff/chat/summaries] Error:', error);
    return res.status(500).json({
      error: 'Failed to fetch summaries',
      message: error.message,
    });
  }
});

export default router;
