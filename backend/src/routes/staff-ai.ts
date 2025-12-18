import { Router } from 'express';
import { z } from 'zod';
import { requireAuth } from '../middleware/requireAuth';
import axios from 'axios';
import geoip from 'geoip-lite';
import multer from 'multer';
import FormData from 'form-data';
import fs from 'fs';
import { getDateTimeContext, getWelcomeDateContext, getFullSystemContext } from '../utils/dateContext';
import { EventModel } from '../models/event';
import { UserModel } from '../models/user';
import { AvailabilityModel } from '../models/availability';

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
    }

    console.log(`[ai/staff/compose-message] Success. Original length: ${composedMessage.length}, Has translation: ${!!translation}`);

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

    const assignedEvents = await EventModel.find(query)
    .sort({ date: 1 })
    .limit(eventLimit)
    .select('event_name client_name date start_time end_time venue_name venue_address city state roles accepted_staff status')
    .lean();

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
  provider: z.enum(['openai', 'claude', 'groq']).optional().default('groq'),
  model: z.string().optional(), // Optional model override for Groq
});

/**
 * Function/Tool definitions for staff AI
 * Different from manager tools - focused on staff actions
 */
const STAFF_AI_TOOLS = [
  {
    name: 'get_my_schedule',
    description: 'Get my shifts and assigned events. Returns up to 10 upcoming events by default. Use this when I ask about my schedule, upcoming shifts, past shifts, specific dates, or "when do I work".',
    parameters: {
      type: 'object',
      properties: {
        date_range: {
          type: ['string', 'null'],
          description: 'Optional date filter. For general schedule questions, LEAVE EMPTY to show upcoming events. Use specific ranges when explicitly asked: "this_week", "next_week", "this_month", "last_month", or "YYYY-MM-DD" for a specific date.'
        },
        limit: {
          type: ['number', 'null'],
          description: 'Number of events to return. Default is 10. Use 1 for "next shift", use specified number for "next N shifts", use 10 for general "my schedule" queries.'
        }
      }
    }
  },
  {
    name: 'mark_availability',
    description: 'Mark my availability for specific dates. Use when I say "I\'m available" or "I can\'t work on...". 🚨 IMPORTANT: If user mentions a month that has already passed this year, use NEXT year.',
    parameters: {
      type: 'object',
      properties: {
        dates: {
          type: 'array',
          items: { type: 'string' },
          description: 'Array of ISO dates (YYYY-MM-DD). If user says a month that already passed this year, use next year. Example: "February" in December 2025 → "2026-02-XX"'
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
    description: 'Accept a shift offer or pending event assignment. Use when I say "accept the shift" or "I\'ll take it".',
    parameters: {
      type: 'object',
      properties: {
        event_id: {
          type: 'string',
          description: 'The event ID to accept'
        }
      },
      required: ['event_id']
    }
  },
  {
    name: 'decline_shift',
    description: 'Decline a shift offer or pending event assignment. Use when I say "decline" or "I can\'t make it".',
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
    description: 'Get my earnings and hours worked. Use when I ask about pay, earnings, or "how much have I made".',
    parameters: {
      type: 'object',
      properties: {
        date_range: {
          type: ['string', 'null'],
          description: 'Optional: "this_week", "last_week", "this_month", "last_month", or ISO date'
        }
      }
    }
  },
  {
    name: 'get_all_my_events',
    description: 'Get ALL my upcoming events/shifts (not limited to a date range). Use when I ask "show me all my events", "what are all my upcoming shifts", "list everything I\'m scheduled for". Shows first 10 in detail, summarizes the rest if more than 10.',
    parameters: {
      type: 'object',
      properties: {}
    }
  },
  {
    name: 'get_my_unavailable_dates',
    description: 'Get dates I\'ve marked as unavailable. Use when I ask "when am I unavailable", "what days did I block off", "show my unavailable dates". Returns first 10 dates if more than 10.',
    parameters: {
      type: 'object',
      properties: {}
    }
  },
  {
    name: 'performance_current_month',
    description: 'Get my performance statistics for the current month. Shows events/shifts analyzed by position (bartender, server, etc), total money earned, and hours worked. Use when I ask about my current month performance, "how am I doing this month", or "my stats this month".',
    parameters: {
      type: 'object',
      properties: {}
    }
  },
  {
    name: 'performance_last_month',
    description: 'Get my performance statistics for last month. Shows events/shifts analyzed by position (bartender, server, etc), total money earned, and hours worked. Use when I ask about last month\'s performance, "how did I do last month", or "my stats last month".',
    parameters: {
      type: 'object',
      properties: {}
    }
  },
  {
    name: 'performance_last_year',
    description: 'Get my performance statistics for the last 12 months. Shows events/shifts analyzed by position (bartender, server, etc), total money earned, and hours worked. Use when I ask about yearly performance, "how did I do this year", "annual stats", or "year in review".',
    parameters: {
      type: 'object',
      properties: {}
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
 * Execute get_my_schedule function
 * Returns upcoming shifts and assigned events
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

    // Parse date range filter
    let dateFilter: any = {};
    const now = new Date();

    if (dateRange) {
      if (dateRange === 'this_week') {
        const startOfWeek = new Date(now);
        startOfWeek.setDate(now.getDate() - now.getDay());
        const endOfWeek = new Date(startOfWeek);
        endOfWeek.setDate(startOfWeek.getDate() + 7);
        dateFilter = { date: { $gte: startOfWeek, $lt: endOfWeek } };
      } else if (dateRange === 'next_week') {
        const startOfNextWeek = new Date(now);
        startOfNextWeek.setDate(now.getDate() - now.getDay() + 7);
        const endOfNextWeek = new Date(startOfNextWeek);
        endOfNextWeek.setDate(startOfNextWeek.getDate() + 7);
        dateFilter = { date: { $gte: startOfNextWeek, $lt: endOfNextWeek } };
      } else if (dateRange === 'this_month') {
        const startOfMonth = new Date(now.getFullYear(), now.getMonth(), 1);
        const endOfMonth = new Date(now.getFullYear(), now.getMonth() + 1, 0);
        dateFilter = { date: { $gte: startOfMonth, $lte: endOfMonth } };
      } else if (dateRange === 'last_month') {
        const startOfLastMonth = new Date(now.getFullYear(), now.getMonth() - 1, 1);
        const endOfLastMonth = new Date(now.getFullYear(), now.getMonth(), 0);
        endOfLastMonth.setHours(23, 59, 59, 999);
        dateFilter = { date: { $gte: startOfLastMonth, $lte: endOfLastMonth } };
        console.log(`[executeGetMySchedule] Last month filter: ${startOfLastMonth.toISOString()} to ${endOfLastMonth.toISOString()}`);
      } else {
        // Assume ISO date (YYYY-MM-DD) - match the entire day
        const specificDate = new Date(dateRange);
        const startOfDay = new Date(specificDate);
        startOfDay.setHours(0, 0, 0, 0);
        const endOfDay = new Date(specificDate);
        endOfDay.setHours(23, 59, 59, 999);
        dateFilter = { date: { $gte: startOfDay, $lte: endOfDay } };
        console.log(`[executeGetMySchedule] Specific date filter: ${dateRange} -> ${startOfDay.toISOString()} to ${endOfDay.toISOString()}`);
      }
    } else {
      // No date filter specified - return ALL upcoming events
      dateFilter = { date: { $gte: now } };
      console.log(`[executeGetMySchedule] No date filter - returning all upcoming events from ${now.toISOString()}`);
    }

    const query = {
      'accepted_staff.userKey': userKey,
      status: { $ne: 'cancelled' },
      ...dateFilter
    };
    console.log('[executeGetMySchedule] Query:', JSON.stringify(query, null, 2));

    // Dynamic limit with user override
    // If limit specified, use it (constrained by subscription tier)
    // Otherwise use default: Free: 10 events | Pro: 50 events
    const maxLimit = subscriptionTier === 'pro' ? 50 : 10;
    const eventLimit = limit
      ? Math.min(limit, maxLimit)  // Use user limit but cap at subscription max
      : maxLimit;  // Default to max for tier

    console.log(`[executeGetMySchedule] Using limit: ${eventLimit} (requested: ${limit || 'default'}, max: ${maxLimit})`);

    const events = await EventModel.find(query)
    .sort({ date: 1 })
    .limit(eventLimit)
    .select('event_name client_name date start_time end_time venue_name venue_address city state accepted_staff status')
    .lean();

    console.log('[executeGetMySchedule] Found', events.length, 'events');
    if (events.length > 0) {
      console.log('[executeGetMySchedule] First event sample:', JSON.stringify({
        event_name: (events[0] as any).event_name,
        client_name: (events[0] as any).client_name,
        venue_name: (events[0] as any).venue_name,
        start_time: (events[0] as any).start_time,
        end_time: (events[0] as any).end_time,
        date: (events[0] as any).date,
      }, null, 2));
    }

    // Extract user's data from accepted_staff for each event
    // Cost optimization: Use abbreviated keys and skip null fields
    const schedule = events.map((event: any) => {
      const userInEvent = event.accepted_staff?.find((staff: any) =>
        staff.userKey === userKey
      );
      return {
        id: event._id,
        name: event.event_name,
        client: event.client_name,
        date: event.date,
        time: `${event.start_time}-${event.end_time}`,
        venue: event.venue_name,
        addr: event.venue_address,
        role: userInEvent?.role || userInEvent?.position || 'Unknown',
        status: userInEvent?.response || 'accepted',
      };
    });

    return {
      success: true,
      message: `${schedule.length} shift(s) found`,
      data: schedule
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

    // Parse date range filter
    // All dates are stored as Date objects (standardized by migration)
    let dateFilter: any = {};
    const now = new Date();

    if (dateRange) {
      if (dateRange === 'this_week') {
        const startOfWeek = new Date(now);
        startOfWeek.setDate(now.getDate() - now.getDay());
        startOfWeek.setHours(0, 0, 0, 0);
        const endOfWeek = new Date(startOfWeek);
        endOfWeek.setDate(startOfWeek.getDate() + 7);
        endOfWeek.setHours(23, 59, 59, 999);
        dateFilter = { date: { $gte: startOfWeek, $lt: endOfWeek } };
      } else if (dateRange === 'last_week') {
        const startOfLastWeek = new Date(now);
        startOfLastWeek.setDate(now.getDate() - now.getDay() - 7);
        startOfLastWeek.setHours(0, 0, 0, 0);
        const endOfLastWeek = new Date(startOfLastWeek);
        endOfLastWeek.setDate(startOfLastWeek.getDate() + 7);
        endOfLastWeek.setHours(23, 59, 59, 999);
        dateFilter = { date: { $gte: startOfLastWeek, $lt: endOfLastWeek } };
      } else if (dateRange === 'this_month') {
        const startOfMonth = new Date(now.getFullYear(), now.getMonth(), 1);
        startOfMonth.setHours(0, 0, 0, 0);
        const endOfMonth = new Date(now.getFullYear(), now.getMonth() + 1, 0, 23, 59, 59, 999);
        dateFilter = { date: { $gte: startOfMonth, $lte: endOfMonth } };
      } else if (dateRange === 'last_month') {
        const startOfLastMonth = new Date(now.getFullYear(), now.getMonth() - 1, 1);
        startOfLastMonth.setHours(0, 0, 0, 0);
        const endOfLastMonth = new Date(now.getFullYear(), now.getMonth(), 0, 23, 59, 59, 999);
        dateFilter = { date: { $gte: startOfLastMonth, $lte: endOfLastMonth } };
      }
    }

    // Use same criteria as context endpoint: all non-cancelled events
    const events = await EventModel.find({
      'accepted_staff.userKey': userKey,
      status: { $ne: 'cancelled' },
      ...dateFilter
    })
    .select('date start_time end_time accepted_staff')
    .lean();

    let totalEarnings = 0;
    let totalHoursWorked = 0;
    let eventCount = 0;

    events.forEach((event: any) => {
      const userInEvent = event.accepted_staff?.find((staff: any) =>
        staff.userKey === userKey
      );

      if (userInEvent && event.start_time && event.end_time) {
        // Calculate hours worked (payRate not available in accepted_staff)
        const start = new Date(`1970-01-01T${event.start_time}`);
        const end = new Date(`1970-01-01T${event.end_time}`);
        const hours = (end.getTime() - start.getTime()) / (1000 * 60 * 60);

        totalHoursWorked += hours;
        // Note: payRate not stored in accepted_staff, cannot calculate earnings
        eventCount++;
      }
    });

    // Cost optimization: Compressed response format
    return {
      success: true,
      message: `${eventCount} completed event(s)`,
      data: {
        earned: Math.round(totalEarnings * 100) / 100,
        hours: Math.round(totalHoursWorked * 10) / 10,
        events: eventCount
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

    // Get first 10 events in detail
    const events = await EventModel.find(query)
      .sort({ date: 1 })
      .limit(10)
      .select('event_name client_name date start_time end_time venue_name venue_address city state accepted_staff status')
      .lean();

    // Extract user's data from accepted_staff for each event
    const detailedEvents = events.map((event: any) => {
      const userInEvent = event.accepted_staff?.find((staff: any) =>
        staff.userKey === userKey
      );
      return {
        id: event._id,
        name: event.event_name,
        client: event.client_name,
        date: event.date,
        time: `${event.start_time}-${event.end_time}`,
        venue: event.venue_name,
        addr: event.venue_address,
        role: userInEvent?.role || userInEvent?.position || 'Unknown',
        status: userInEvent?.response || 'accepted',
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
 * Returns dates marked as unavailable, first 10 if more than 10 exist
 */
async function executeGetMyUnavailableDates(
  userKey: string
): Promise<{ success: boolean; message: string; data?: any }> {
  try {
    console.log(`[executeGetMyUnavailableDates] Getting unavailable dates for userKey ${userKey}`);

    // Get all unavailable dates, sorted by date
    const totalCount = await AvailabilityModel.countDocuments({
      userKey,
      status: 'unavailable'
    });

    console.log(`[executeGetMyUnavailableDates] Total unavailable dates: ${totalCount}`);

    const unavailableDates = await AvailabilityModel.find({
      userKey,
      status: 'unavailable'
    })
      .sort({ date: 1 })
      .limit(10)
      .select('date notes')
      .lean();

    const dates = unavailableDates.map((record: any) => ({
      date: record.date,
      notes: record.notes || null
    }));

    const remainingCount = totalCount - dates.length;

    return {
      success: true,
      message: totalCount === 0
        ? 'No unavailable dates found'
        : `${totalCount} unavailable date(s)`,
      data: {
        dates,
        total: totalCount,
        showing: dates.length,
        remaining: remainingCount > 0 ? remainingCount : 0
      }
    };
  } catch (error: any) {
    console.error('[executeGetMyUnavailableDates] Error:', error);
    return {
      success: false,
      message: `Failed to get unavailable dates: ${error.message}`
    };
  }
}

/**
 * Execute accept_shift function
 * Moves user from pending to accepted in event assignments
 */
async function executeAcceptShift(
  userId: string,
  userKey: string,
  eventId: string
): Promise<{ success: boolean; message: string; data?: any }> {
  try {
    console.log(`[executeAcceptShift] Accepting shift ${eventId} for userId ${userId}`);

    const event = await EventModel.findById(eventId);
    if (!event) {
      return { success: false, message: 'Event not found' };
    }

    // Find user in assignments
    const assignment = (event as any).assignments?.find((a: any) => a.memberId?.toString() === userId);
    if (!assignment) {
      return { success: false, message: 'You are not assigned to this event' };
    }

    // Update assignment status
    assignment.status = 'accepted';
    assignment.respondedAt = new Date();

    await event.save();

    // Cost optimization: Compressed response format
    return {
      success: true,
      message: `Accepted ${(event as any).eventName || 'shift'}`,
      data: { id: eventId, name: (event as any).eventName, date: (event as any).date }
    };
  } catch (error: any) {
    console.error('[executeAcceptShift] Error:', error);
    return {
      success: false,
      message: `Failed to accept shift: ${error.message}`
    };
  }
}

/**
 * Execute decline_shift function
 * Moves user from pending to declined in event assignments
 */
async function executeDeclineShift(
  userId: string,
  userKey: string,
  eventId: string,
  reason?: string
): Promise<{ success: boolean; message: string; data?: any }> {
  try {
    console.log(`[executeDeclineShift] Declining shift ${eventId} for userId ${userId}, reason: ${reason || 'none'}`);

    const event = await EventModel.findById(eventId);
    if (!event) {
      return { success: false, message: 'Event not found' };
    }

    // Find user in assignments
    const assignment = (event as any).assignments?.find((a: any) => a.memberId?.toString() === userId);
    if (!assignment) {
      return { success: false, message: 'You are not assigned to this event' };
    }

    // Update assignment status
    assignment.status = 'declined';
    assignment.respondedAt = new Date();
    if (reason) {
      assignment.response = reason;
    }

    await event.save();

    // Cost optimization: Compressed response format
    return {
      success: true,
      message: `Declined ${(event as any).eventName || 'shift'}`,
      data: { id: eventId, name: (event as any).eventName }
    };
  } catch (error: any) {
    console.error('[executeDeclineShift] Error:', error);
    return {
      success: false,
      message: `Failed to decline shift: ${error.message}`
    };
  }
}

/**
 * Execute performance_current_month function
 * Returns performance statistics for the current month
 */
async function executePerformanceCurrentMonth(
  userId: string,
  userKey: string
): Promise<{ success: boolean; message: string; data?: any }> {
  try {
    console.log(`[executePerformanceCurrentMonth] Getting current month stats for userKey ${userKey}`);

    const now = new Date();
    const startOfMonth = new Date(now.getFullYear(), now.getMonth(), 1);
    startOfMonth.setHours(0, 0, 0, 0);
    const endOfMonth = new Date(now.getFullYear(), now.getMonth() + 1, 0, 23, 59, 59, 999);

    console.log(`[executePerformanceCurrentMonth] Date range: ${startOfMonth.toISOString()} to ${endOfMonth.toISOString()}`);

    // Query shifts for this month where user is in accepted_staff
    // Use same criteria as earnings section: all non-cancelled events
    // All dates are stored as Date objects (standardized by migration)
    const events = await EventModel.find({
      'accepted_staff.userKey': userKey,
      status: { $ne: 'cancelled' },
      date: { $gte: startOfMonth, $lte: endOfMonth }
    }).lean();

    console.log(`[executePerformanceCurrentMonth] Found ${events.length} events in current month`);

    // Analyze by role/position
    const positionStats: Record<string, { count: number; hours: number; earnings: number }> = {};
    let totalHours = 0;
    let totalEarnings = 0;
    let totalEvents = 0;

    for (const event of events) {
      const acceptedStaff = (event as any).accepted_staff || [];
      const userInShift = acceptedStaff.find((staff: any) => staff.userKey === userKey);

      if (userInShift && userInShift.response === 'accepted') {
        const position = userInShift.role || 'Staff';

        // Calculate hours from start_time and end_time
        let hours = 0;
        if ((event as any).start_time && (event as any).end_time) {
          const start = new Date(`1970-01-01T${(event as any).start_time}`);
          const end = new Date(`1970-01-01T${(event as any).end_time}`);
          hours = (end.getTime() - start.getTime()) / (1000 * 60 * 60);
          if (hours < 0) hours += 24; // Handle overnight shifts
        } else {
          hours = 6; // Default assumption if times not specified
        }

        // Extract pay rate from roles array if available
        const roles = (event as any).roles || [];
        const roleInfo = roles.find((r: any) => r.role_name === position);
        const wage = roleInfo?.pay_rate_info?.amount || 0;
        const earnings = wage * hours;

        if (!positionStats[position]) {
          positionStats[position] = { count: 0, hours: 0, earnings: 0 };
        }

        positionStats[position].count++;
        positionStats[position].hours += hours;
        positionStats[position].earnings += earnings;

        totalHours += hours;
        totalEarnings += earnings;
        totalEvents++;
      }
    }

    // Format response
    const positionBreakdown = Object.entries(positionStats).map(([position, stats]) => ({
      position,
      events: stats.count,
      hours: Math.round(stats.hours * 10) / 10,
      earnings: Math.round(stats.earnings * 100) / 100
    }));

    return {
      success: true,
      message: `Performance for ${now.toLocaleString('default', { month: 'long', year: 'numeric' })}`,
      data: {
        period: 'current_month',
        totalEvents,
        totalHours: Math.round(totalHours * 10) / 10,
        totalEarnings: Math.round(totalEarnings * 100) / 100,
        byPosition: positionBreakdown,
        averageWage: totalHours > 0 ? Math.round((totalEarnings / totalHours) * 100) / 100 : 0
      }
    };
  } catch (error: any) {
    console.error('[executePerformanceCurrentMonth] Error:', error);
    return {
      success: false,
      message: `Failed to get performance data: ${error.message}`
    };
  }
}

/**
 * Execute performance_last_month function
 * Returns performance statistics for last month
 */
async function executePerformanceLastMonth(
  userId: string,
  userKey: string
): Promise<{ success: boolean; message: string; data?: any }> {
  try {
    console.log(`[executePerformanceLastMonth] Getting last month stats for userKey ${userKey}`);

    const now = new Date();
    const startOfLastMonth = new Date(now.getFullYear(), now.getMonth() - 1, 1);
    startOfLastMonth.setHours(0, 0, 0, 0);
    const endOfLastMonth = new Date(now.getFullYear(), now.getMonth(), 0, 23, 59, 59, 999);

    console.log(`[executePerformanceLastMonth] Date range: ${startOfLastMonth.toISOString()} to ${endOfLastMonth.toISOString()}`);

    // Query shifts for last month where user is in accepted_staff
    // Use same criteria as earnings section: all non-cancelled events
    // All dates are stored as Date objects (standardized by migration)
    const events = await EventModel.find({
      'accepted_staff.userKey': userKey,
      status: { $ne: 'cancelled' },
      date: { $gte: startOfLastMonth, $lte: endOfLastMonth }
    }).lean();

    console.log(`[executePerformanceLastMonth] Found ${events.length} events in last month`);

    // Analyze by role/position
    const positionStats: Record<string, { count: number; hours: number; earnings: number }> = {};
    let totalHours = 0;
    let totalEarnings = 0;
    let totalEvents = 0;

    for (const event of events) {
      const acceptedStaff = (event as any).accepted_staff || [];
      const userInShift = acceptedStaff.find((staff: any) => staff.userKey === userKey);

      if (userInShift && userInShift.response === 'accepted') {
        const position = userInShift.role || 'Staff';

        // Calculate hours from start_time and end_time
        let hours = 0;
        if ((event as any).start_time && (event as any).end_time) {
          const start = new Date(`1970-01-01T${(event as any).start_time}`);
          const end = new Date(`1970-01-01T${(event as any).end_time}`);
          hours = (end.getTime() - start.getTime()) / (1000 * 60 * 60);
          if (hours < 0) hours += 24; // Handle overnight shifts
        } else {
          hours = 6; // Default assumption if times not specified
        }

        // Extract pay rate from roles array if available
        const roles = (event as any).roles || [];
        const roleInfo = roles.find((r: any) => r.role_name === position);
        const wage = roleInfo?.pay_rate_info?.amount || 0;
        const earnings = wage * hours;

        if (!positionStats[position]) {
          positionStats[position] = { count: 0, hours: 0, earnings: 0 };
        }

        positionStats[position].count++;
        positionStats[position].hours += hours;
        positionStats[position].earnings += earnings;

        totalHours += hours;
        totalEarnings += earnings;
        totalEvents++;
      }
    }

    const positionBreakdown = Object.entries(positionStats).map(([position, stats]) => ({
      position,
      events: stats.count,
      hours: Math.round(stats.hours * 10) / 10,
      earnings: Math.round(stats.earnings * 100) / 100
    }));

    return {
      success: true,
      message: `Performance for ${startOfLastMonth.toLocaleString('default', { month: 'long', year: 'numeric' })}`,
      data: {
        period: 'last_month',
        totalEvents,
        totalHours: Math.round(totalHours * 10) / 10,
        totalEarnings: Math.round(totalEarnings * 100) / 100,
        byPosition: positionBreakdown,
        averageWage: totalHours > 0 ? Math.round((totalEarnings / totalHours) * 100) / 100 : 0
      }
    };
  } catch (error: any) {
    console.error('[executePerformanceLastMonth] Error:', error);
    return {
      success: false,
      message: `Failed to get performance data: ${error.message}`
    };
  }
}

/**
 * Execute performance_last_year function
 * Returns performance statistics for the last 12 months
 */
async function executePerformanceLastYear(
  userId: string,
  userKey: string
): Promise<{ success: boolean; message: string; data?: any }> {
  try {
    console.log(`[executePerformanceLastYear] Getting last 12 months stats for userKey ${userKey}`);

    const now = new Date();
    const startOfYear = new Date(now.getFullYear() - 1, now.getMonth(), now.getDate());
    startOfYear.setHours(0, 0, 0, 0);
    now.setHours(23, 59, 59, 999);

    console.log(`[executePerformanceLastYear] Date range: ${startOfYear.toISOString()} to ${now.toISOString()}`);

    // Query shifts for last 12 months where user is in accepted_staff
    // Use same criteria as earnings section: all non-cancelled events
    // All dates are stored as Date objects (standardized by migration)
    const events = await EventModel.find({
      'accepted_staff.userKey': userKey,
      status: { $ne: 'cancelled' },
      date: { $gte: startOfYear, $lte: now }
    }).lean();

    console.log(`[executePerformanceLastYear] Found ${events.length} events in last 12 months`);

    // Analyze by role/position and by month
    const positionStats: Record<string, { count: number; hours: number; earnings: number }> = {};
    const monthlyStats: Record<string, { events: number; hours: number; earnings: number }> = {};
    let totalHours = 0;
    let totalEarnings = 0;
    let totalEvents = 0;

    for (const event of events) {
      const acceptedStaff = (event as any).accepted_staff || [];
      const userInShift = acceptedStaff.find((staff: any) => staff.userKey === userKey);

      if (userInShift && userInShift.response === 'accepted') {
        const position = userInShift.role || 'Staff';
        const eventDate = new Date((event as any).date);
        const monthKey = `${eventDate.getFullYear()}-${String(eventDate.getMonth() + 1).padStart(2, '0')}`;

        // Calculate hours from start_time and end_time
        let hours = 0;
        if ((event as any).start_time && (event as any).end_time) {
          const start = new Date(`1970-01-01T${(event as any).start_time}`);
          const end = new Date(`1970-01-01T${(event as any).end_time}`);
          hours = (end.getTime() - start.getTime()) / (1000 * 60 * 60);
          if (hours < 0) hours += 24; // Handle overnight shifts
        } else {
          hours = 6; // Default assumption if times not specified
        }

        // Extract pay rate from roles array if available
        const roles = (event as any).roles || [];
        const roleInfo = roles.find((r: any) => r.role_name === position);
        const wage = roleInfo?.pay_rate_info?.amount || 0;
        const earnings = wage * hours;

        // Update position stats
        if (!positionStats[position]) {
          positionStats[position] = { count: 0, hours: 0, earnings: 0 };
        }
        positionStats[position].count++;
        positionStats[position].hours += hours;
        positionStats[position].earnings += earnings;

        // Update monthly stats
        if (!monthlyStats[monthKey]) {
          monthlyStats[monthKey] = { events: 0, hours: 0, earnings: 0 };
        }
        monthlyStats[monthKey].events++;
        monthlyStats[monthKey].hours += hours;
        monthlyStats[monthKey].earnings += earnings;

        totalHours += hours;
        totalEarnings += earnings;
        totalEvents++;
      }
    }

    const positionBreakdown = Object.entries(positionStats).map(([position, stats]) => ({
      position,
      events: stats.count,
      hours: Math.round(stats.hours * 10) / 10,
      earnings: Math.round(stats.earnings * 100) / 100
    }));

    // Calculate monthly average
    const monthCount = Object.keys(monthlyStats).length || 1;
    const monthlyAverage = {
      events: Math.round(totalEvents / monthCount * 10) / 10,
      hours: Math.round(totalHours / monthCount * 10) / 10,
      earnings: Math.round(totalEarnings / monthCount * 100) / 100
    };

    return {
      success: true,
      message: 'Performance for last 12 months',
      data: {
        period: 'last_year',
        totalEvents,
        totalHours: Math.round(totalHours * 10) / 10,
        totalEarnings: Math.round(totalEarnings * 100) / 100,
        byPosition: positionBreakdown,
        monthlyAverage,
        averageWage: totalHours > 0 ? Math.round((totalEarnings / totalHours) * 100) / 100 : 0,
        monthsCovered: monthCount
      }
    };
  } catch (error: any) {
    console.error('[executePerformanceLastYear] Error:', error);
    return {
      success: false,
      message: `Failed to get performance data: ${error.message}`
    };
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
      return await executeGetAllMyEvents(userId, userKey);

    case 'get_my_unavailable_dates':
      return await executeGetMyUnavailableDates(userKey);

    case 'accept_shift':
      return await executeAcceptShift(userId, userKey, functionArgs.event_id);

    case 'decline_shift':
      return await executeDeclineShift(userId, userKey, functionArgs.event_id, functionArgs.reason);

    case 'performance_current_month':
      return await executePerformanceCurrentMonth(userId, userKey);

    case 'performance_last_month':
      return await executePerformanceLastMonth(userId, userKey);

    case 'performance_last_year':
      return await executePerformanceLastYear(userId, userKey);

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
router.post('/ai/staff/chat/message', requireAuth, async (req, res) => {
  try {
    const oauthProvider = (req as any).user?.provider;
    const subject = (req as any).user?.sub;

    if (!oauthProvider || !subject) {
      return res.status(401).json({ message: 'Unauthorized' });
    }

    // Load staff user details by provider and subject
    const user = await UserModel.findOne({ provider: oauthProvider, subject })
      .select('_id first_name last_name email phone_number app_id subscription_tier')
      .lean();
    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }

    const userId = String(user._id);
    const userKey = `${oauthProvider}:${subject}`;
    const subscriptionTier = (user as any).subscription_tier || 'free';

    // Free tier message limit enforcement (50 messages/month)
    if (subscriptionTier === 'free') {
      // Get mutable user document for updating counters
      const mutableUser = await UserModel.findOne({ provider: oauthProvider, subject });
      if (!mutableUser) {
        return res.status(404).json({ message: 'User not found' });
      }

      // Check if we need to reset monthly counter
      const now = new Date();
      const resetDate = mutableUser.ai_messages_reset_date || new Date();

      if (now > resetDate) {
        // Reset counter for new month
        mutableUser.ai_messages_used_this_month = 0;
        const nextMonth = new Date(now);
        nextMonth.setMonth(nextMonth.getMonth() + 1);
        nextMonth.setDate(1);
        nextMonth.setHours(0, 0, 0, 0);
        mutableUser.ai_messages_reset_date = nextMonth;
        console.log(`[ai/staff/chat/message] Reset message counter for user ${userId}, next reset: ${nextMonth.toISOString()}`);
      }

      // Check message limit (20 for free tier - changed from 50 to reduce costs)
      const messagesUsed = mutableUser.ai_messages_used_this_month || 0;
      const messageLimit = 20;

      if (messagesUsed >= messageLimit) {
        console.log(`[ai/staff/chat/message] User ${userId} hit message limit (${messagesUsed}/${messageLimit})`);
        return res.status(402).json({
          message: `You've reached your monthly AI message limit (${messageLimit} messages). Upgrade to Pro for unlimited messages!`,
          upgradeRequired: true,
          usage: {
            used: messagesUsed,
            limit: messageLimit,
            resetDate: mutableUser.ai_messages_reset_date,
          },
        });
      }

      // Increment counter
      mutableUser.ai_messages_used_this_month = messagesUsed + 1;
      await mutableUser.save();

      console.log(`[ai/staff/chat/message] Message count for user ${userId}: ${messagesUsed + 1}/${messageLimit}`);
    }

    const validated = chatMessageSchema.parse(req.body);
    const { messages, temperature, maxTokens, model } = validated;

    console.log(`[ai/staff/chat/message] Using Groq, model: ${model || 'llama-3.1-8b-instant'} for user ${userId}, userKey ${userKey}, tier: ${subscriptionTier}`);

    const timezone = getTimezoneFromRequest(req);

    // Always use Groq (optimized for cost and performance)
    return await handleStaffGroqRequest(messages, temperature, maxTokens, res, timezone, userId, userKey, subscriptionTier, model);
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
 * Supports: llama-3.1-8b-instant (default, fast) and openai/gpt-oss-20b (advanced reasoning)
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
  model?: string
) {
  const groqKey = process.env.GROQ_API_KEY;
  if (!groqKey) {
    console.error('[Groq] API key not configured');
    return res.status(500).json({ message: 'Groq API key not configured on server' });
  }

  // Use GPT-OSS-20B for function calling (131K context, OpenAI-compatible tools)
  const groqModel = model || 'openai/gpt-oss-20b';  // 20B params, 131K context, 65K max output
  const isReasoningModel = false;

  console.log(`[Groq] Staff using model: ${groqModel}`);

  // Optimize prompt structure: CRITICAL rules FIRST (open-source models follow early instructions better)
  const systemInstructions = `
🚫 ABSOLUTE RULES - MUST FOLLOW (TOP PRIORITY):
1. **NEVER show raw JSON, code blocks, or technical data** to the user
2. **NEVER display IDs, timestamps, or internal field names** (like eventId, staffId, _id)
3. **NEVER display function results or API responses** in their raw form
4. **ALWAYS use [LINK:Venue Name] format** for venues - NO EXCEPTIONS
   Example: "Venue: [LINK:Seawell Ballroom]" - This makes venues clickable in the app
5. **When handling dates**: If user mentions a month that has ALREADY PASSED this year → use NEXT year
   Example: If today is December 2025 and user says "February" → use February 2026

🎯 CONFIRMATION STYLE - ALWAYS USE NATURAL LANGUAGE:
When you ACCEPT, DECLINE, or UPDATE something:
✅ GOOD: "Done! You're confirmed for **Saturday, January 25th** at [LINK:The Grand Ballroom]."
✅ GOOD: "Got it! I've marked you as unavailable for that date."
✅ GOOD: "All set! The shift has been declined."
❌ BAD: "Shift accepted successfully. Event ID: 507f1f77bcf86cd799439011"
❌ BAD: "Status updated: {accepted: true, eventId: '...'}"
❌ BAD: "Success: true, message: 'Availability marked'"

🌍 LANGUAGE:
ALWAYS respond in the SAME LANGUAGE the user is speaking.
- If user writes in Spanish → respond in Spanish
- If user writes in English → respond in English

📅 EVENT LIST FORMAT:
- Date: "Monday, Nov 15th" (readable format)
- Time: "8:00 AM - 5:00 PM" (not "08:00:00")
- Role: Your role for the event
- Venue: [LINK:Venue Name] ← MUST use this format
- Client: Client name
- Money: "$150" (not "150.00")
- Hide: addresses, database IDs, null fields

📊 HOW MANY EVENTS TO SHOW:
- "my schedule" → Show next 10 upcoming events
- "next shift" → Show ONLY 1 event (the earliest)
- "next [N] shifts" → Show exactly N events
- "this week" / "this month" → Show all events in that period
- Always include a count like "Here are your next 10 shifts:"`;

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

  // Build tools array for Chat Completions API
  const groqTools = STAFF_AI_TOOLS.map(tool => ({
    type: 'function',
    function: {
      name: tool.name,
      description: tool.description,
      parameters: tool.parameters
    }
  }));

  // Build request body with model-specific optimizations
  const requestBody: any = {
    model: groqModel,
    messages: processedMessages,
    temperature: isReasoningModel ? 0.5 : temperature, // Lower temp for reasoning stability
    max_tokens: isReasoningModel ? 4000 : maxTokens,    // Much higher for reasoning models
    tools: groqTools,
    tool_choice: 'auto'
  };

  // Add reasoning parameters for gpt-oss models
  if (isReasoningModel) {
    requestBody.reasoning_format = 'hidden'; // Hide reasoning tokens, show only final answer
    console.log(`[Groq] Using reasoning mode with ${requestBody.max_tokens} max tokens`);
  }

  const headers = {
    'Authorization': `Bearer ${groqKey}`,
    'Content-Type': 'application/json',
  };

  // Retry logic with exponential backoff
  const maxRetries = 3;
  let lastError: any = null;

  for (let attempt = 1; attempt <= maxRetries; attempt++) {
    try {
      console.log(`[Groq] Attempt ${attempt}/${maxRetries} - Calling /v1/chat/completions...`);

      // Extended timeout for reasoning models (120s vs 60s)
      const timeout = isReasoningModel ? 120000 : 60000;

      const response = await axios.post(
        'https://api.groq.com/openai/v1/chat/completions',
        requestBody,
        { headers, validateStatus: () => true, timeout }
      );

      console.log('[Groq] Response status:', response.status);

      // Handle rate limits with retry
      if (response.status === 429) {
        const retryAfter = parseInt(response.headers['retry-after'] || '5', 10);
        if (attempt < maxRetries) {
          console.log(`[Groq] Rate limited, retrying after ${retryAfter}s...`);
          await new Promise(resolve => setTimeout(resolve, retryAfter * 1000));
          continue;
        }
        return res.status(429).json({
          message: 'Groq API rate limit reached. Please try again later.',
        });
      }

      // Handle other errors
      if (response.status >= 300) {
        console.error('[Groq] API error:', response.status, response.data);

        // Store error
        lastError = { status: response.status, data: response.data };

        // Llama model error - return error details
        console.log('[Groq] Llama model error:', response.status);

        return res.status(response.status).json({
          message: `Groq API error: ${response.statusText}`,
          details: response.data,
        });
      }

      // Parse successful response
      const choice = response.data.choices?.[0];
      if (!choice) {
        throw new Error('No choices in response');
      }

      const assistantMessage = choice.message;

      // Handle tool calls (including parallel calls for llama)
      if (assistantMessage.tool_calls && assistantMessage.tool_calls.length > 0) {
        console.log(`[Groq] ${assistantMessage.tool_calls.length} tool call(s) requested`);

        // Execute tool calls in parallel
        const toolResults = await Promise.all(
          assistantMessage.tool_calls.map(async (toolCall: any) => {
            const functionName = toolCall.function.name;
            const functionArgs = JSON.parse(toolCall.function.arguments);

            console.log(`[Groq] Executing ${functionName}:`, functionArgs);

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
          })
        );

        // Second request with tool results
        const messagesWithToolResults = [
          ...processedMessages,
          assistantMessage,
          ...toolResults
        ];

        const secondResponse = await axios.post(
          'https://api.groq.com/openai/v1/chat/completions',
          {
            model: requestBody.model, // Use same model as first request
            messages: messagesWithToolResults,
            temperature: requestBody.temperature,
            max_tokens: requestBody.max_tokens,
          },
          { headers, validateStatus: () => true, timeout: 60000 }
        );

        if (secondResponse.status >= 300) {
          console.error('[Groq] Second API call error:', secondResponse.status);
          throw new Error(`Second API call failed: ${secondResponse.statusText}`);
        }

        const finalContent = secondResponse.data.choices?.[0]?.message?.content;

        if (!finalContent) {
          throw new Error('No content in second response');
        }

        return res.json({
          content: finalContent,
          provider: 'groq',
          model: requestBody.model,
          toolsUsed: assistantMessage.tool_calls.map((tc: any) => tc.function.name)
        });
      }

      // No tool calls, return content directly
      const content = assistantMessage.content;
      if (!content) {
        throw new Error('No content in response');
      }

      return res.json({
        content,
        provider: 'groq',
        model: requestBody.model
      });

    } catch (error: any) {
      lastError = error;
      console.error(`[Groq] Attempt ${attempt}/${maxRetries} failed:`, {
        message: error.message,
        status: error.response?.status,
        data: error.response?.data
      });

      // If this was the last attempt, fall through to error handler
      if (attempt === maxRetries) break;

      // Exponential backoff: 1s, 2s, 4s
      const backoffMs = Math.pow(2, attempt - 1) * 1000;
      console.log(`[Groq] Retrying after ${backoffMs}ms...`);
      await new Promise(resolve => setTimeout(resolve, backoffMs));
    }
  }

  // All retries exhausted
  return res.status(500).json({
    message: 'Groq API request failed after retries',
    error: lastError?.message || 'Unknown error',
    details: lastError?.response?.data || lastError?.message
  });
}

export default router;
