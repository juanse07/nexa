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
 * POST /api/ai/staff/transcribe
 * Transcribe audio to text using Groq Whisper API (fast & cheap!)
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

    const groqWhisperUrl = 'https://api.groq.com/openai/v1';

    const formData = new FormData();
    formData.append('file', fs.createReadStream(tempFilePath), {
      filename: req.file.originalname,
      contentType: req.file.mimetype,
    });
    formData.append('model', 'whisper-large-v3');

    // Minimal bilingual prompt for faster transcription
    const domainPrompt = 'shifts turnos server mesero bartender cantinero venue';
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
      companyName: 'Nexa Staffing',
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
    description: 'Get my shifts and assigned events (past or upcoming). Use this when I ask about my schedule, upcoming shifts, past shifts, specific event dates, or "when do I work".',
    parameters: {
      type: 'object',
      properties: {
        date_range: {
          type: 'string',
          description: 'Optional date filter. IMPORTANT: For "next shift", "upcoming shifts", or "do I work" questions, LEAVE EMPTY to find the earliest upcoming event. Use specific ranges when explicitly asked: "this_week" for this week only, "next_week" for next week, "this_month" for this month, "last_month" for previous month, or "YYYY-MM-DD" for a specific date (e.g. "2025-11-13").'
        }
      }
    }
  },
  {
    name: 'mark_availability',
    description: 'Mark my availability for specific dates. Use when I say "I\'m available" or "I can\'t work on..."',
    parameters: {
      type: 'object',
      properties: {
        dates: {
          type: 'array',
          items: { type: 'string' },
          description: 'Array of ISO dates (YYYY-MM-DD) to mark availability for'
        },
        status: {
          type: 'string',
          enum: ['available', 'unavailable', 'preferred'],
          description: 'Availability status'
        },
        notes: {
          type: 'string',
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
          type: 'string',
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
          type: 'string',
          description: 'Optional: "this_week", "last_week", "this_month", "last_month", or ISO date'
        }
      }
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

    // Dynamic limit based on subscription tier
    // Free: 10 events | Pro: 50 events
    const eventLimit = subscriptionTier === 'pro' ? 50 : 10;

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
    let dateFilter: any = {};
    const now = new Date();

    if (dateRange) {
      if (dateRange === 'this_week') {
        const startOfWeek = new Date(now);
        startOfWeek.setDate(now.getDate() - now.getDay());
        const endOfWeek = new Date(startOfWeek);
        endOfWeek.setDate(startOfWeek.getDate() + 7);
        dateFilter = { date: { $gte: startOfWeek, $lt: endOfWeek } };
      } else if (dateRange === 'last_week') {
        const startOfLastWeek = new Date(now);
        startOfLastWeek.setDate(now.getDate() - now.getDay() - 7);
        const endOfLastWeek = new Date(startOfLastWeek);
        endOfLastWeek.setDate(startOfLastWeek.getDate() + 7);
        dateFilter = { date: { $gte: startOfLastWeek, $lt: endOfLastWeek } };
      } else if (dateRange === 'this_month') {
        const startOfMonth = new Date(now.getFullYear(), now.getMonth(), 1);
        const endOfMonth = new Date(now.getFullYear(), now.getMonth() + 1, 0);
        dateFilter = { date: { $gte: startOfMonth, $lte: endOfMonth } };
      } else if (dateRange === 'last_month') {
        const startOfLastMonth = new Date(now.getFullYear(), now.getMonth() - 1, 1);
        const endOfLastMonth = new Date(now.getFullYear(), now.getMonth(), 0);
        dateFilter = { date: { $gte: startOfLastMonth, $lte: endOfLastMonth } };
      }
    }

    const events = await EventModel.find({
      'accepted_staff.userKey': userKey,
      status: 'completed',
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
      return await executeGetMySchedule(userId, userKey, functionArgs.date_range, subscriptionTier);

    case 'get_earnings_summary':
      return await executeGetEarningsSummary(userId, userKey, functionArgs.date_range);

    case 'accept_shift':
      return await executeAcceptShift(userId, userKey, functionArgs.event_id);

    case 'decline_shift':
      return await executeDeclineShift(userId, userKey, functionArgs.event_id, functionArgs.reason);

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

      // Check message limit (50 for free tier)
      const messagesUsed = mutableUser.ai_messages_used_this_month || 0;
      const messageLimit = 50;

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
    const { messages, temperature, maxTokens, provider, model } = validated;

    console.log(`[ai/staff/chat/message] Using provider: ${provider}, model: ${model || 'default'} for user ${userId}, userKey ${userKey}, tier: ${subscriptionTier}`);

    const timezone = getTimezoneFromRequest(req);

    if (provider === 'claude') {
      return await handleStaffClaudeRequest(messages, temperature, maxTokens, res, timezone, userId, userKey, subscriptionTier);
    } else if (provider === 'groq') {
      return await handleStaffGroqRequest(messages, temperature, maxTokens, res, timezone, userId, userKey, subscriptionTier, model);
    } else {
      return await handleStaffOpenAIRequest(messages, temperature, maxTokens, res, timezone, userId, userKey, subscriptionTier);
    }
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
 * Handle OpenAI chat request for staff
 */
async function handleStaffOpenAIRequest(
  messages: any[],
  temperature: number,
  maxTokens: number,
  res: any,
  timezone?: string,
  userId?: string,
  userKey?: string,
  subscriptionTier?: 'free' | 'pro'
) {
  const openaiKey = process.env.OPENAI_API_KEY;
  if (!openaiKey) {
    console.error('[OpenAI] API key not configured');
    return res.status(500).json({ message: 'OpenAI API key not configured on server' });
  }

  const textModel = process.env.OPENAI_TEXT_MODEL || 'gpt-4o';
  const openaiBaseUrl = process.env.OPENAI_BASE_URL || 'https://api.openai.com/v1';

  // Inject date/time context and staff-specific instructions
  const dateContext = getFullSystemContext(timezone);

  // Add user-friendly formatting instructions for staff AI (optimized for token cost)
  const formattingInstructions = `
Format events in summarized list:
- Date: "Monday, Nov 15th" (readable format)
- Time: Call time or event time (e.g., "8:00 AM - 5:00 PM")
- Role: Your role for the event
- Venue: Venue name only (NO address)
- Client: Client name
- Hide: addresses, database IDs, null fields
- Be brief, concise & friendly

IMPORTANT - How many events to show:
- "next shift" / "when is my next shift" → Show ONLY 1 event (the earliest)
- "next 7 jobs" → Show up to 7 events
- "upcoming" / "all upcoming" → Show all events
- "last month" / "shifts from last month" → Show all events from previous month

Clickable venue for "next shift":
- When showing a single next shift, format venue name as: [LINK:Venue Name]
- Example: "Venue: [LINK:Seawell Ballroom]"
- This makes it clickable in the app`;

  const contextWithFormatting = `${dateContext}\n\n${formattingInstructions}`;

  const enhancedMessages = messages.map((msg, index) => {
    if (msg.role === 'system' && index === 0) {
      return {
        ...msg,
        content: `${contextWithFormatting}\n\n${msg.content}`
      };
    }
    return msg;
  });

  const hasSystemMessage = messages.some(msg => msg.role === 'system');
  const finalMessages = hasSystemMessage
    ? enhancedMessages
    : [{ role: 'system', content: contextWithFormatting }, ...messages];

  const requestBody = {
    model: textModel,
    messages: finalMessages,
    temperature,
    max_tokens: maxTokens,
    tools: STAFF_AI_TOOLS.map(tool => ({
      type: 'function',
      function: {
        name: tool.name,
        description: tool.description,
        parameters: tool.parameters,
      }
    })),
    tool_choice: 'auto',
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

    const toolCall = toolCalls[0];
    const functionName = toolCall.function?.name;
    const functionArgs = JSON.parse(toolCall.function?.arguments || '{}');

    // Execute the function
    const functionResult = await executeStaffFunction(functionName, functionArgs, userId!, userKey!, subscriptionTier || 'free');
    console.log('[OpenAI] Function result:', functionResult);

    // Make second API call with function result
    const messagesWithFunctionResult = [
      ...finalMessages,
      {
        role: 'assistant',
        content: null,
        tool_calls: toolCalls
      },
      {
        role: 'tool',
        tool_call_id: toolCall.id,
        content: JSON.stringify(functionResult)
      }
    ];

    const secondResponse = await axios.post(
      `${openaiBaseUrl}/chat/completions`,
      {
        model: textModel,
        messages: messagesWithFunctionResult,
        temperature,
        max_tokens: maxTokens,
      },
      { headers }
    );

    const finalContent = secondResponse.data.choices?.[0]?.message?.content;

    if (!finalContent) {
      return res.status(500).json({ message: 'Failed to get final response from OpenAI' });
    }

    return res.json({
      content: finalContent,
      provider: 'openai',
      functionExecuted: {
        name: functionName,
        success: functionResult.success
      }
    });
  }

  if (!content) {
    return res.status(500).json({ message: 'Failed to get response from OpenAI' });
  }

  return res.json({ content, provider: 'openai' });
}

/**
 * Handle Claude chat request for staff with prompt caching
 */
async function handleStaffClaudeRequest(
  messages: any[],
  temperature: number,
  maxTokens: number,
  res: any,
  timezone?: string,
  userId?: string,
  userKey?: string,
  subscriptionTier?: 'free' | 'pro'
) {
  const claudeKey = process.env.CLAUDE_API_KEY;
  if (!claudeKey) {
    console.error('[Claude] API key not configured');
    return res.status(500).json({ message: 'Claude API key not configured on server' });
  }

  const claudeModel = process.env.CLAUDE_MODEL || 'claude-sonnet-4-5-20250929';
  const claudeBaseUrl = process.env.CLAUDE_BASE_URL || 'https://api.anthropic.com/v1';

  let systemMessage = '';
  const userMessages: any[] = [];

  const dateContext = getFullSystemContext(timezone);

  // Add user-friendly formatting instructions for staff AI (optimized for token cost)
  const formattingInstructions = `
Format events in summarized list:
- Date: "Monday, Nov 15th" (readable format)
- Time: Call time or event time (e.g., "8:00 AM - 5:00 PM")
- Role: Your role for the event
- Venue: Venue name only (NO address)
- Client: Client name
- Hide: addresses, database IDs, null fields
- Be brief, concise & friendly

IMPORTANT - How many events to show:
- "next shift" / "when is my next shift" → Show ONLY 1 event (the earliest)
- "next 7 jobs" → Show up to 7 events
- "upcoming" / "all upcoming" → Show all events
- "last month" / "shifts from last month" → Show all events from previous month

Clickable venue for "next shift":
- When showing a single next shift, format venue name as: [LINK:Venue Name]
- Example: "Venue: [LINK:Seawell Ballroom]"
- This makes it clickable in the app`;

  systemMessage = `${dateContext}\n\n${formattingInstructions}\n\n`;

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

  const requestBody = {
    model: claudeModel,
    max_tokens: maxTokens,
    temperature,
    system: systemMessage ? [
      {
        type: 'text',
        text: systemMessage,
        cache_control: { type: 'ephemeral' },
      },
    ] : 'You are a helpful AI assistant for event staffing.',
    messages: userMessages,
    tools: STAFF_AI_TOOLS.map(tool => ({
      name: tool.name,
      description: tool.description,
      input_schema: tool.parameters,
    })),
  };

  const headers = {
    'x-api-key': claudeKey,
    'anthropic-version': '2023-06-01',
    'anthropic-beta': 'prompt-caching-2024-07-31',
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

  const usage = response.data.usage;
  if (usage) {
    console.log('[Claude] Token usage:', {
      input: usage.input_tokens,
      output: usage.output_tokens,
      cache_creation: usage.cache_creation_input_tokens || 0,
      cache_read: usage.cache_read_input_tokens || 0,
    });

    if (usage.cache_read_input_tokens > 0) {
      const savings = ((usage.cache_read_input_tokens / (usage.input_tokens + usage.cache_read_input_tokens)) * 100).toFixed(1);
      console.log(`[Claude] Prompt caching saved ${savings}% on input tokens`);
    }
  }

  const contentBlocks = response.data.content;
  if (!contentBlocks || contentBlocks.length === 0) {
    return res.status(500).json({ message: 'Failed to get response from Claude' });
  }

  const toolUseBlock = contentBlocks.find((block: any) => block.type === 'tool_use');
  if (toolUseBlock) {
    console.log('[Claude] Tool use requested:', JSON.stringify(toolUseBlock, null, 2));

    const toolName = toolUseBlock.name;
    const toolInput = toolUseBlock.input;
    const toolUseId = toolUseBlock.id;

    // Execute the function
    const functionResult = await executeStaffFunction(toolName, toolInput, userId!, userKey!, subscriptionTier || 'free');
    console.log('[Claude] Function result:', functionResult);

    // Make second API call with function result
    const messagesWithFunctionResult = [
      ...userMessages,
      {
        role: 'assistant',
        content: contentBlocks
      },
      {
        role: 'user',
        content: [
          {
            type: 'tool_result',
            tool_use_id: toolUseId,
            content: JSON.stringify(functionResult)
          }
        ]
      }
    ];

    console.log('[Claude] Calling API with function result...');

    const secondResponse = await axios.post(
      `${claudeBaseUrl}/messages`,
      {
        model: claudeModel,
        max_tokens: maxTokens,
        temperature,
        system: systemMessage ? [
          {
            type: 'text',
            text: systemMessage,
            cache_control: { type: 'ephemeral' },
          },
        ] : 'You are a helpful AI assistant for event staffing.',
        messages: messagesWithFunctionResult,
        tools: STAFF_AI_TOOLS.map(tool => ({
          name: tool.name,
          description: tool.description,
          input_schema: tool.parameters,
        })),
      },
      { headers, validateStatus: () => true }
    );

    if (secondResponse.status >= 300) {
      console.error('[Claude] Second API call error:', secondResponse.status, secondResponse.data);
      return res.status(secondResponse.status).json({
        message: `Claude API error: ${secondResponse.statusText}`,
        details: secondResponse.data,
      });
    }

    const secondUsage = secondResponse.data.usage;
    if (secondUsage) {
      console.log('[Claude] Second call token usage:', {
        input: secondUsage.input_tokens,
        output: secondUsage.output_tokens,
        cache_read: secondUsage.cache_read_input_tokens || 0,
      });
    }

    const secondContentBlocks = secondResponse.data.content;
    const finalTextBlock = secondContentBlocks?.find((block: any) => block.type === 'text');
    const finalContent = finalTextBlock?.text;

    if (!finalContent) {
      return res.status(500).json({ message: 'Failed to get final text response from Claude' });
    }

    return res.json({
      content: finalContent,
      provider: 'claude',
      usage: secondUsage,
      functionExecuted: {
        name: toolName,
        success: functionResult.success
      }
    });
  }

  const textBlock = contentBlocks.find((block: any) => block.type === 'text');
  const content = textBlock?.text;

  if (!content) {
    return res.status(500).json({ message: 'Failed to get text response from Claude' });
  }

  return res.json({
    content,
    provider: 'claude',
    usage: usage,
  });
}

/**
 * Handle Groq chat request for staff with Responses API
 * Uses the /v1/responses endpoint (NOT /chat/completions)
 * Cost-optimized alternative using open-source models
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
  try {
    const groqKey = process.env.GROQ_API_KEY;
    if (!groqKey) {
      console.error('[Groq] API key not configured');
      return res.status(500).json({ message: 'Groq API key not configured on server' });
    }

    // Use provided model or fall back to env variable or default
    const groqModel = model || process.env.GROQ_MODEL || 'llama-3.1-8b-instant';
    const groqBaseUrl = 'https://api.groq.com/openai';

    // Determine which API to use based on model
    const useResponsesAPI = groqModel.includes('gpt-oss') || groqModel.includes('openai/');
    const apiEndpoint = useResponsesAPI ? '/v1/responses' : '/v1/chat/completions';

    console.log(`[Groq] Staff using model: ${groqModel} with ${useResponsesAPI ? 'Responses' : 'Chat Completions'} API`);

    // Build messages with date context and formatting instructions
    const dateContext = getFullSystemContext(timezone);
    const formattingInstructions = `
Format events in summarized list:
- Date: "Monday, Nov 15th" (readable format)
- Time: Call time or event time (e.g., "8:00 AM - 5:00 PM")
- Role: Your role for the event
- Venue: Venue name only (NO address)
- Client: Client name
- Hide: addresses, database IDs, null fields
- Be brief, concise & friendly

IMPORTANT - How many events to show:
- "next shift" / "when is my next shift" → Show ONLY 1 event (the earliest)
- "next 7 jobs" → Show up to 7 events
- "upcoming" / "all upcoming" → Show all events
- "last month" / "shifts from last month" → Show all events from previous month

Clickable venue for "next shift":
- When showing a single next shift, format venue name as: [LINK:Venue Name]
- Example: "Venue: [LINK:Seawell Ballroom]"
- This makes it clickable in the app`;

    const contextWithFormatting = `${dateContext}\n\n${formattingInstructions}`;

    const processedMessages: any[] = [];
    let hasSystemMessage = false;
    for (const msg of messages) {
      if (msg.role === 'system') {
        processedMessages.push({
          role: 'system',
          content: `${contextWithFormatting}\n\n${msg.content}`
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
        content: contextWithFormatting
      });
    }

    // Build tools array based on API type
    let groqTools: any[];
    if (useResponsesAPI) {
      // Responses API: flat structure
      groqTools = STAFF_AI_TOOLS.map(tool => ({
        type: 'function',
        name: tool.name,
        description: tool.description,
        parameters: tool.parameters
      }));
    } else {
      // Chat Completions API: nested structure
      groqTools = STAFF_AI_TOOLS.map(tool => ({
        type: 'function',
        function: {
          name: tool.name,
          description: tool.description,
          parameters: tool.parameters
        }
      }));
    }

    // Build request body based on API type
    let requestBody: any;
    if (useResponsesAPI) {
      requestBody = {
        model: groqModel,
        input: processedMessages,
        temperature,
        max_output_tokens: maxTokens,
        tools: groqTools,
      };
    } else {
      requestBody = {
        model: groqModel,
        messages: processedMessages,
        temperature,
        max_tokens: maxTokens,
        tools: groqTools,
      };
    }

    const headers = {
      'Authorization': `Bearer ${groqKey}`,
      'Content-Type': 'application/json',
    };

    console.log(`[Groq] Calling ${apiEndpoint}...`);

    const response = await axios.post(
      `${groqBaseUrl}${apiEndpoint}`,
      requestBody,
      { headers, validateStatus: () => true }
    );

    console.log('[Groq] Response status:', response.status);

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

    // Parse response based on API type
    if (useResponsesAPI) {
      // Responses API: output blocks format
      const outputBlocks = response.data.output;
      if (!outputBlocks || outputBlocks.length === 0) {
        return res.status(500).json({ message: 'Failed to get response from Groq' });
      }

      // Check for function calls
      const functionCallBlock = outputBlocks.find((block: any) => block.type === 'function_call');
      if (functionCallBlock) {
        console.log('[Groq] Function call requested:', functionCallBlock.name);

        const functionName = functionCallBlock.name;
        const functionArgs = functionCallBlock.arguments;

        const functionResult = await executeStaffFunction(functionName, functionArgs, userId!, userKey!, subscriptionTier || 'free');

        // Second request for Responses API
        const messagesWithFunctionResult = [
          ...processedMessages,
          { role: 'assistant', content: functionCallBlock.text || '' },
          { role: 'user', content: `Function ${functionName} returned: ${JSON.stringify(functionResult)}\n\nPlease present this naturally.` }
        ];

        const secondResponse = await axios.post(
          `${groqBaseUrl}${apiEndpoint}`,
          {
            model: groqModel,
            input: messagesWithFunctionResult,
            temperature,
            max_output_tokens: maxTokens,
          },
          { headers, validateStatus: () => true }
        );

        if (secondResponse.status >= 300) {
          console.error('[Groq] Second API call error:', secondResponse.status);
          return res.status(secondResponse.status).json({
            message: `Groq API error: ${secondResponse.statusText}`,
            details: secondResponse.data,
          });
        }

        const secondOutput = secondResponse.data.output;
        const messageBlock = secondOutput?.find((block: any) => block.type === 'message');
        const textContent = messageBlock?.content?.find((item: any) => item.type === 'output_text');
        const finalContent = textContent?.text;

        if (!finalContent) {
          return res.status(500).json({ message: 'Failed to get final response from Groq' });
        }

        return res.json({
          content: finalContent,
          provider: 'groq',
          functionExecuted: {
            name: functionName,
            success: functionResult.success
          }
        });
      }

      // Extract text content
      const messageBlock = outputBlocks.find((block: any) => block.type === 'message');
      const textContent = messageBlock?.content?.find((item: any) => item.type === 'output_text');
      const content = textContent?.text;

      if (!content) {
        console.error('[Groq] No text content found in output blocks');
        return res.status(500).json({ message: 'Failed to get text response from Groq' });
      }

      return res.json({ content, provider: 'groq' });

    } else {
      // Chat Completions API: choices format
      const choice = response.data.choices?.[0];
      if (!choice) {
        return res.status(500).json({ message: 'Failed to get response from Groq' });
      }

      const assistantMessage = choice.message;

      // Check for tool calls
      if (assistantMessage.tool_calls && assistantMessage.tool_calls.length > 0) {
        const toolCall = assistantMessage.tool_calls[0];
        console.log('[Groq] Tool call requested:', toolCall.function.name);

        const functionName = toolCall.function.name;
        const functionArgs = JSON.parse(toolCall.function.arguments);

        const functionResult = await executeStaffFunction(functionName, functionArgs, userId!, userKey!, subscriptionTier || 'free');

        // Second request for Chat Completions API
        const messagesWithToolResult = [
          ...processedMessages,
          assistantMessage,
          {
            role: 'tool',
            tool_call_id: toolCall.id,
            content: JSON.stringify(functionResult)
          }
        ];

        const secondResponse = await axios.post(
          `${groqBaseUrl}${apiEndpoint}`,
          {
            model: groqModel,
            messages: messagesWithToolResult,
            temperature,
            max_tokens: maxTokens,
          },
          { headers, validateStatus: () => true }
        );

        if (secondResponse.status >= 300) {
          console.error('[Groq] Second API call error:', secondResponse.status);
          return res.status(secondResponse.status).json({
            message: `Groq API error: ${secondResponse.statusText}`,
            details: secondResponse.data,
          });
        }

        const finalContent = secondResponse.data.choices?.[0]?.message?.content;

        if (!finalContent) {
          return res.status(500).json({ message: 'Failed to get final response from Groq' });
        }

        return res.json({
          content: finalContent,
          provider: 'groq',
          functionExecuted: {
            name: functionName,
            success: functionResult.success
          }
        });
      }

      // No tool calls, return content directly
      const content = assistantMessage.content;
      if (!content) {
        return res.status(500).json({ message: 'Failed to get text response from Groq' });
      }

      return res.json({ content, provider: 'groq' });
    }

  } catch (error: any) {
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

export default router;
