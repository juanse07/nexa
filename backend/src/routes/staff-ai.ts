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
 * Transcribe audio to text using OpenAI Whisper API
 * Same as manager transcription but scoped to staff
 */
router.post('/ai/staff/transcribe', requireAuth, upload.single('audio'), async (req, res) => {
  let tempFilePath: string | null = null;

  try {
    if (!req.file) {
      return res.status(400).json({ message: 'No audio file provided' });
    }

    tempFilePath = req.file.path;

    const openaiKey = process.env.OPENAI_API_KEY;
    if (!openaiKey) {
      console.error('[ai/staff/transcribe] OPENAI_API_KEY not configured');
      return res.status(500).json({ message: 'OpenAI API key not configured on server' });
    }

    const openaiBaseUrl = process.env.OPENAI_BASE_URL || 'https://api.openai.com/v1';

    const formData = new FormData();
    formData.append('file', fs.createReadStream(tempFilePath), {
      filename: req.file.originalname,
      contentType: req.file.mimetype,
    });
    formData.append('model', 'whisper-1');

    // Bilingual domain prompt for better Spanish/English transcription accuracy
    // Auto-detection enabled (no language parameter) - supports 98+ languages
    const domainPrompt = `Event staffing terminology / Terminología de eventos:
shifts availability schedule venues server bartender captain chef cook,
dates times hours worked pay rate earnings accept decline shift,
turnos disponibilidad horario locales mesero cantinero capitán chef cocinero,
fechas horas trabajadas tarifa pago ganancias aceptar rechazar turno`;
    formData.append('prompt', domainPrompt);

    const headers: any = {
      'Authorization': `Bearer ${openaiKey}`,
      ...formData.getHeaders(),
    };

    const orgId = process.env.OPENAI_ORG_ID;
    if (orgId) {
      headers['OpenAI-Organization'] = orgId;
    }

    console.log('[ai/staff/transcribe] Calling Whisper API...');

    const response = await axios.post(
      `${openaiBaseUrl}/audio/transcriptions`,
      formData,
      { headers, validateStatus: () => true }
    );

    if (tempFilePath) {
      fs.unlinkSync(tempFilePath);
      tempFilePath = null;
    }

    if (response.status >= 300) {
      console.error('[ai/staff/transcribe] Whisper API error:', response.status, response.data);
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
      .select('_id first_name last_name email phone_number app_id')
      .lean();
    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }

    const userId = String(user._id);

    // DEBUG: First, let's see what ANY event looks like in the database
    const sampleEvent = await EventModel.findOne({ 'assignments.0': { $exists: true } })
      .select('eventName assignments')
      .lean();

    if (sampleEvent) {
      console.log('[ai/staff/context] Sample event from DB:', JSON.stringify({
        eventName: (sampleEvent as any).eventName,
        assignments: (sampleEvent as any).assignments?.slice(0, 2) // First 2 assignments
      }, null, 2));
    } else {
      console.log('[ai/staff/context] No events with assignments found in DB');
    }

    // Load assigned events (events where this user is in assignments array)
    // Search by both memberId AND userKey since events might use either format
    const query = {
      $or: [
        { 'assignments.memberId': userId },
        { 'assignments.userKey': userKey }
      ],
      status: { $ne: 'cancelled' }
    };

    console.log('[ai/staff/context] Query:', JSON.stringify(query, null, 2));
    console.log('[ai/staff/context] Query params - userId:', userId, 'userKey:', userKey);

    const assignedEvents = await EventModel.find(query)
    .sort({ date: 1 })
    .limit(100)
    .select('eventName clientName date startTime endTime venueName venueAddress city state roles assignments status')
    .lean();

    // DEBUG: Log query results
    console.log('[ai/staff/context] Found', assignedEvents.length, 'events');
    if (assignedEvents.length > 0 && assignedEvents[0]) {
      console.log('[ai/staff/context] Matched event assignments:', JSON.stringify((assignedEvents[0] as any).assignments));
    }

    // Extract user's role assignments and calculate hours/earnings
    const eventsWithUserData = assignedEvents.map((event: any) => {
      // Find assignment by either memberId or userKey
      const userAssignment = event.assignments?.find((a: any) =>
        a.memberId?.toString() === userId || a.userKey === userKey
      );
      return {
        ...event,
        userRole: userAssignment?.role || 'Unknown',
        userCallTime: userAssignment?.callTime || null,
        userStatus: userAssignment?.status || 'pending',
        userPayRate: userAssignment?.payRate || null,
      };
    });

    // Calculate total earnings (if pay rates are available)
    let totalEarnings = 0;
    let totalHoursWorked = 0;

    eventsWithUserData.forEach((event: any) => {
      if (event.status === 'completed' && event.userPayRate && event.startTime && event.endTime) {
        // Calculate hours worked (simplified - would need actual clock-in/out in production)
        const start = new Date(`1970-01-01T${event.startTime}`);
        const end = new Date(`1970-01-01T${event.endTime}`);
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
  provider: z.enum(['openai', 'claude']).optional().default('claude'),
});

/**
 * Function/Tool definitions for staff AI
 * Different from manager tools - focused on staff actions
 */
const STAFF_AI_TOOLS = [
  {
    name: 'get_my_schedule',
    description: 'Get my upcoming shifts and assigned events. Use this when I ask about my schedule, upcoming shifts, or "when do I work".',
    parameters: {
      type: 'object',
      properties: {
        date_range: {
          type: 'string',
          description: 'Optional date range filter: "this_week", "next_week", "this_month", or ISO date like "2025-12-01"'
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

    return {
      success: true,
      message: `Successfully marked ${status} for ${dates.length} date(s): ${dates.join(', ')}`,
      data: { dates, status, count: results.length }
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
  dateRange?: string
): Promise<{ success: boolean; message: string; data?: any }> {
  try {
    console.log(`[executeGetMySchedule] Getting schedule for userId ${userId}, userKey ${userKey}, range: ${dateRange || 'all'}`);

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
      } else {
        // Assume ISO date
        dateFilter = { date: new Date(dateRange) };
      }
    } else {
      // Default: upcoming events only
      dateFilter = { date: { $gte: now } };
    }

    const events = await EventModel.find({
      $or: [
        { 'assignments.memberId': userId },
        { 'assignments.userKey': userKey }
      ],
      status: { $ne: 'cancelled' },
      ...dateFilter
    })
    .sort({ date: 1 })
    .limit(50)
    .select('eventName clientName date startTime endTime venueName venueAddress city state assignments status')
    .lean();

    // Extract user's assignment data for each event
    const schedule = events.map((event: any) => {
      const userAssignment = event.assignments?.find((a: any) =>
        a.memberId?.toString() === userId || a.userKey === userKey
      );
      return {
        eventId: event._id,
        eventName: event.eventName,
        clientName: event.clientName,
        date: event.date,
        startTime: event.startTime,
        endTime: event.endTime,
        venueName: event.venueName,
        venueAddress: event.venueAddress,
        role: userAssignment?.role || 'Unknown',
        callTime: userAssignment?.callTime,
        status: userAssignment?.status || 'pending',
        payRate: userAssignment?.payRate,
      };
    });

    return {
      success: true,
      message: `Found ${schedule.length} upcoming shift(s)`,
      data: { schedule, count: schedule.length }
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
      $or: [
        { 'assignments.memberId': userId },
        { 'assignments.userKey': userKey }
      ],
      status: 'completed',
      ...dateFilter
    })
    .select('date startTime endTime assignments')
    .lean();

    let totalEarnings = 0;
    let totalHoursWorked = 0;
    let eventCount = 0;

    events.forEach((event: any) => {
      const userAssignment = event.assignments?.find((a: any) =>
        a.memberId?.toString() === userId || a.userKey === userKey
      );

      if (userAssignment?.payRate && event.startTime && event.endTime) {
        // Calculate hours worked
        const start = new Date(`1970-01-01T${event.startTime}`);
        const end = new Date(`1970-01-01T${event.endTime}`);
        const hours = (end.getTime() - start.getTime()) / (1000 * 60 * 60);

        totalHoursWorked += hours;
        totalEarnings += hours * userAssignment.payRate;
        eventCount++;
      }
    });

    return {
      success: true,
      message: `Earnings calculated for ${eventCount} completed event(s)`,
      data: {
        totalEarnings: Math.round(totalEarnings * 100) / 100,
        totalHoursWorked: Math.round(totalHoursWorked * 10) / 10,
        eventCount,
        dateRange: dateRange || 'all_time'
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

    return {
      success: true,
      message: `Successfully accepted shift for ${(event as any).eventName || 'event'} on ${(event as any).date}`,
      data: {
        eventId,
        eventName: (event as any).eventName,
        date: (event as any).date,
        role: assignment.role
      }
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

    return {
      success: true,
      message: `Successfully declined shift for ${(event as any).eventName || 'event'} on ${(event as any).date}`,
      data: {
        eventId,
        eventName: (event as any).eventName,
        date: (event as any).date,
        reason: reason || 'Not specified'
      }
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
  userKey: string
): Promise<{ success: boolean; message: string; data?: any }> {
  console.log(`[executeStaffFunction] Executing ${functionName} with args:`, functionArgs);

  switch (functionName) {
    case 'mark_availability':
      return await executeMarkAvailability(
        userKey,
        functionArgs.dates || [],
        functionArgs.status || 'unavailable',
        functionArgs.notes
      );

    case 'get_my_schedule':
      return await executeGetMySchedule(userId, userKey, functionArgs.date_range);

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
      .select('_id first_name last_name email phone_number app_id')
      .lean();
    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }

    const userId = String(user._id);
    const userKey = `${oauthProvider}:${subject}`;

    const validated = chatMessageSchema.parse(req.body);
    const { messages, temperature, maxTokens, provider } = validated;

    console.log(`[ai/staff/chat/message] Using provider: ${provider} for user ${userId}, userKey ${userKey}`);

    const timezone = getTimezoneFromRequest(req);

    if (provider === 'claude') {
      return await handleStaffClaudeRequest(messages, temperature, maxTokens, res, timezone, userId, userKey);
    } else {
      return await handleStaffOpenAIRequest(messages, temperature, maxTokens, res, timezone, userId, userKey);
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
  userKey?: string
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
  const enhancedMessages = messages.map((msg, index) => {
    if (msg.role === 'system' && index === 0) {
      return {
        ...msg,
        content: `${dateContext}\n\n${msg.content}`
      };
    }
    return msg;
  });

  const hasSystemMessage = messages.some(msg => msg.role === 'system');
  const finalMessages = hasSystemMessage
    ? enhancedMessages
    : [{ role: 'system', content: dateContext }, ...messages];

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
    const functionResult = await executeStaffFunction(functionName, functionArgs, userId!, userKey!);
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
  userKey?: string
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
    const functionResult = await executeStaffFunction(toolName, toolInput, userId!, userKey!);
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

export default router;
