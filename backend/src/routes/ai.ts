import { Router } from 'express';
import { z } from 'zod';
import mongoose from 'mongoose';
import { requireAuth } from '../middleware/requireAuth';
import axios from 'axios';
import geoip from 'geoip-lite';
import multer from 'multer';
import FormData from 'form-data';
import fs from 'fs';
import { getDateTimeContext, getWelcomeDateContext, getFullSystemContext } from '../utils/dateContext';
import { EventModel } from '../models/event';
import { ClientModel } from '../models/client';
import { TeamMemberModel } from '../models/teamMember';
import { AvailabilityModel } from '../models/availability';
import { ManagerModel } from '../models/manager';
import { RoleModel } from '../models/role';
import { TariffModel } from '../models/tariff';
import { VenueModel } from '../models/venue';
import { AIChatSummaryModel } from '../models/aiChatSummary';

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
 * GET /api/ai/manager/context
 * Returns manager's context for AI chat including clients, events, and team members
 * Used to populate AI chat with relevant data
 */
router.get('/ai/manager/context', requireAuth, async (req, res) => {
  try {
    const managerId = (req as any).user?._id || (req as any).user?.managerId;

    if (!managerId) {
      return res.status(401).json({ message: 'Manager not found' });
    }

    console.log(`[ai/manager/context] Loading context for managerId ${managerId}`);

    // Load manager details
    const manager = await ManagerModel.findById(managerId)
      .select('email first_name last_name name preferredCity venueList')
      .lean();

    if (!manager) {
      return res.status(404).json({ message: 'Manager not found' });
    }

    // Load manager's clients (limit to 50)
    const clients = await ClientModel.find({ managerId })
      .sort({ created_at: -1 })
      .limit(50)
      .select('_id name contact_name contact_email contact_phone notes tariffs')
      .lean();

    console.log(`[ai/manager/context] Found ${clients.length} clients`);

    // Load recent events (limit to 100 most recent)
    const events = await EventModel.find({ managerId })
      .sort({ date: -1 })
      .limit(100)
      .select('_id event_name client_name date start_time end_time venue_name venue_address status roles accepted_staff')
      .lean();

    console.log(`[ai/manager/context] Found ${events.length} events`);

    // Load team members
    const teamMembers = await TeamMemberModel.find({ managerId })
      .sort({ created_at: -1 })
      .limit(100)
      .select('_id first_name last_name email phone roles preferred_roles availability_status')
      .lean();

    console.log(`[ai/manager/context] Found ${teamMembers.length} team members`);

    // Load recent availability records for team members (last 30 days)
    const thirtyDaysAgo = new Date();
    thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

    const availabilityRecords = await AvailabilityModel.find({
      managerId,
      date: { $gte: thirtyDaysAgo }
    })
      .sort({ date: -1 })
      .limit(500)
      .select('teamMemberId date status notes')
      .lean();

    console.log(`[ai/manager/context] Found ${availabilityRecords.length} availability records`);

    // Group availability by team member
    const availabilityByMember = availabilityRecords.reduce((acc: any, record: any) => {
      const memberId = String(record.teamMemberId);
      if (!acc[memberId]) {
        acc[memberId] = [];
      }
      acc[memberId].push({
        date: record.date,
        status: record.status,
        notes: record.notes
      });
      return acc;
    }, {});

    // Enhance team members with their availability
    const teamMembersWithAvailability = teamMembers.map((member: any) => {
      const memberId = String(member._id);
      return {
        ...member,
        recentAvailability: availabilityByMember[memberId] || []
      };
    });

    // Build context response
    const context = {
      manager: {
        id: manager._id,
        email: manager.email,
        firstName: manager.first_name || 'Manager',
        lastName: manager.last_name || '',
        name: manager.name || 'Manager',
        preferredCity: (manager as any).preferredCity
      },
      venues: (await VenueModel.find({ managerId }).lean()).map((venue: any) => ({
        id: String(venue._id),
        name: venue.name,
        address: venue.address,
        city: venue.city,
        state: venue.state,
        source: venue.source || 'ai'
      })),
      clients: clients.map((client: any) => ({
        id: client._id,
        name: client.name,
        contactName: client.contact_name,
        contactEmail: client.contact_email,
        contactPhone: client.contact_phone,
        notes: client.notes,
        tariffCount: client.tariffs?.length || 0
      })),
      events: events.map((event: any) => ({
        id: event._id,
        eventName: event.event_name,
        clientName: event.client_name,
        date: event.date,
        startTime: event.start_time,
        endTime: event.end_time,
        venueName: event.venue_name,
        venueAddress: event.venue_address,
        status: event.status,
        roles: event.roles,
        staffCount: event.accepted_staff?.length || 0
      })),
      teamMembers: teamMembersWithAvailability.map((member: any) => ({
        id: member._id,
        firstName: member.first_name,
        lastName: member.last_name,
        email: member.email,
        phone: member.phone,
        roles: member.roles,
        preferredRoles: member.preferred_roles,
        availabilityStatus: member.availability_status,
        recentAvailability: member.recentAvailability.slice(0, 10) // Limit to 10 most recent
      })),
      summary: {
        totalClients: clients.length,
        totalEvents: events.length,
        totalTeamMembers: teamMembers.length,
        totalVenues: await VenueModel.countDocuments({ managerId }),
        upcomingEvents: events.filter((e: any) => new Date(e.date) >= new Date()).length,
        pastEvents: events.filter((e: any) => new Date(e.date) < new Date()).length
      }
    };

    return res.json(context);
  } catch (err: any) {
    console.error('[ai/manager/context] Error:', err);
    return res.status(500).json({ message: 'Failed to load manager context' });
  }
});

/**
 * POST /api/ai/transcribe
 * Transcribe audio to text using Groq Whisper API (fast & cheap!)
 * Accepts audio file upload and optional terminology parameter
 * Returns transcribed text
 */
router.post('/ai/transcribe', requireAuth, upload.single('audio'), async (req, res) => {
  let tempFilePath: string | null = null;

  try {
    if (!req.file) {
      return res.status(400).json({ message: 'No audio file provided' });
    }

    tempFilePath = req.file.path;

    const groqKey = process.env.GROQ_API_KEY;
    if (!groqKey) {
      console.error('[ai/transcribe] GROQ_API_KEY not configured');
      return res.status(500).json({ message: 'Groq API key not configured on server' });
    }

    // Get user's terminology preference (jobs, shifts, or events)
    // Defaults to 'shifts' if not provided
    const terminology = (req.body.terminology || 'shifts').toLowerCase();
    const singularTerm = terminology.endsWith('s') ? terminology.slice(0, -1) : terminology;

    console.log(`[ai/transcribe] Using terminology: ${terminology} (singular: ${singularTerm})`);

    // Groq Whisper endpoint (NOT the Responses API endpoint)
    const groqWhisperUrl = 'https://api.groq.com/openai/v1';

    // Create form data for Whisper API
    const formData = new FormData();
    formData.append('file', fs.createReadStream(tempFilePath), {
      filename: req.file.originalname,
      contentType: req.file.mimetype,
    });
    formData.append('model', 'whisper-large-v3-turbo');

    // Auto-detect language (supports English, Spanish, and 96 other languages)
    // By not specifying 'language', Whisper will detect it automatically
    // This allows Spanish-speaking users to use voice input naturally

    // Domain prompt with user's terminology for better context
    const domainPrompt = `${terminology} staffing: server bartender captain chef venue client ${singularTerm}`;
    formData.append('prompt', domainPrompt);

    const headers: any = {
      'Authorization': `Bearer ${groqKey}`,
      ...formData.getHeaders(),
    };

    console.log('[ai/transcribe] Calling Groq Whisper API...');

    const response = await axios.post(
      `${groqWhisperUrl}/audio/transcriptions`,
      formData,
      { headers, validateStatus: () => true }
    );

    // Clean up temp file
    if (tempFilePath) {
      fs.unlinkSync(tempFilePath);
      tempFilePath = null;
    }

    if (response.status >= 300) {
      console.error('[ai/transcribe] Groq Whisper API error:', response.status, response.data);
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
    description: '🔍 PRIMARY SEARCH TOOL - Use this for 95% of venue/address lookups. HYBRID approach: searches your past events database first (fast, shows history), then automatically falls back to Google Places if not found. Examples: "Find Seawell Ballroom", "What\'s the address for The Westin", "Where is client ABC\'s usual venue".',
    parameters: {
      type: 'object',
      properties: {
        query: {
          type: 'string',
          description: 'Search query - can be venue name, address, city, or any location-related term'
        },
        client_name: {
          type: ['string', 'null'],
          description: 'Optional: Filter results by client name (only applies to database search)'
        }
      },
      required: ['query']
    }
  },
  {
    name: 'search_shifts',
    description: 'Find shifts by various criteria from the database. Use this when users ask about specific shifts, dates, or want to see shift lists.',
    parameters: {
      type: 'object',
      properties: {
        client_name: {
          type: ['string', 'null'],
          description: 'Filter by client name'
        },
        date: {
          type: ['string', 'null'],
          description: 'ISO date (YYYY-MM-DD) or month filter (e.g., "2024-03")'
        },
        venue_name: {
          type: ['string', 'null'],
          description: 'Filter by venue name'
        },
        event_name: {
          type: ['string', 'null'],
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
          type: ['string', 'null'],
          description: 'Optional: Filter by specific role (e.g., "Server", "Bartender")'
        },
        member_name: {
          type: ['string', 'null'],
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
  },
  {
    name: 'create_client',
    description: 'Create a new client for the manager. Use this when the manager wants to add a new client to their account.',
    parameters: {
      type: 'object',
      properties: {
        name: {
          type: 'string',
          description: 'The name of the client/company to create'
        }
      },
      required: ['name']
    }
  },
  {
    name: 'create_role',
    description: 'Create a new role/position type for events (e.g., Server, Bartender, Chef). Use this when the manager wants to add a new role type.',
    parameters: {
      type: 'object',
      properties: {
        name: {
          type: 'string',
          description: 'The name of the role to create (e.g., "Server", "Bartender", "Chef")'
        }
      },
      required: ['name']
    }
  },
  {
    name: 'create_tariff',
    description: 'Create or update a pricing rate (tariff) for a specific client-role combination. Use this when the manager wants to set hourly rates for different roles at specific clients.',
    parameters: {
      type: 'object',
      properties: {
        client_name: {
          type: 'string',
          description: 'The name of the client this tariff is for'
        },
        role_name: {
          type: 'string',
          description: 'The name of the role this tariff is for'
        },
        rate: {
          type: 'number',
          description: 'The hourly rate in dollars (e.g., 25.50)'
        },
        currency: {
          type: ['string', 'null'],
          description: 'Optional currency code (defaults to USD)'
        }
      },
      required: ['client_name', 'role_name', 'rate']
    }
  },
  {
    name: 'create_shift',
    description: 'Create a new event/shift (crear evento/turno). Use when user wants to: create event, make shift, add job, schedule staff, create trabajo, crear evento, agendar personal. IMPORTANT: Managers only care about CALL TIME (when staff should arrive), NOT guest arrival time. Call time is the staff arrival time. 🚨 CRITICAL: ALL EVENTS MUST BE IN THE FUTURE - never create events for past dates.',
    parameters: {
      type: 'object',
      properties: {
        client_name: {
          type: 'string',
          description: 'Name of the client/company'
        },
        date: {
          type: 'string',
          description: 'Shift date in ISO format YYYY-MM-DD. 🚨 CRITICAL: If user says a month that has already passed this year, use NEXT year. Example: If today is December 2025 and user says "February", use 2026-02-XX not 2025-02-XX. NEVER create events in the past.'
        },
        call_time: {
          type: 'string',
          description: 'CALL TIME - when staff should ARRIVE. Convert to 24h format (e.g., "4pm" → "16:00", "4 de la tarde" → "16:00")'
        },
        end_time: {
          type: 'string',
          description: 'When shift ENDS. Convert to 24h format (e.g., "11pm" → "23:00", "11 de la noche" → "23:00")'
        },
        venue_name: {
          type: ['string', 'null'],
          description: 'Name of the venue/location'
        },
        venue_address: {
          type: ['string', 'null'],
          description: 'Full street address of the venue'
        },
        roles: {
          type: ['array', 'null'],
          description: 'Staff roles needed with counts',
          items: {
            type: 'object',
            properties: {
              role: { type: 'string', description: 'Role name (e.g., Server, Bartender)' },
              count: { type: 'number', description: 'How many needed' }
            }
          }
        },
        uniform: {
          type: ['string', 'null'],
          description: 'Dress code/uniform requirements (optional)'
        },
        notes: {
          type: ['string', 'null'],
          description: 'Additional details, instructions, shift name if needed, special requirements'
        },
        contact_name: {
          type: ['string', 'null'],
          description: 'On-site contact person name'
        },
        contact_phone: {
          type: ['string', 'null'],
          description: 'On-site contact phone number'
        },
        headcount_total: {
          type: ['number', 'null'],
          description: 'Expected guest headcount/attendance'
        }
      },
      required: ['date', 'call_time', 'end_time', 'client_name']
    }
  },
  {
    name: 'search_venue',
    description: '🌍 EXPLORATORY SEARCH - Use ONLY for location-based browsing or venue type discovery (NOT for finding specific venues). Examples: "Show me ballrooms in Boulder", "Find hotels near Denver airport", "List conference centers in Colorado Springs". ⚠️ For specific venue lookups like "Find The Westin", use search_addresses instead.',
    parameters: {
      type: 'object',
      properties: {
        query: {
          type: 'string',
          description: 'Venue TYPE or category to search for (e.g., "ballroom", "conference center", "hotels", "restaurants")'
        },
        location: {
          type: ['string', 'null'],
          description: 'City or area to search in (e.g., "Denver", "Boulder", "Colorado Springs"). If not provided, uses default Denver area.'
        },
        limit: {
          type: ['number', 'null'],
          description: 'Maximum number of results to return (default: 5, max: 10)'
        }
      },
      required: ['query']
    }
  },
  {
    name: 'get_clients_list',
    description: 'Get the list of all clients/companies in the manager\'s account. Use this when the user asks about clients, wants to see all clients, or needs to reference client names.',
    parameters: {
      type: 'object',
      properties: {},
      required: []
    }
  },
  {
    name: 'get_events_summary',
    description: 'Get summary of recent and upcoming events. Use this when user asks about events, schedule, or wants to see what\'s happening. Returns events from the past 30 days and future 60 days.',
    parameters: {
      type: 'object',
      properties: {
        client_name: {
          type: ['string', 'null'],
          description: 'Optional: Filter events by specific client name'
        },
        days_past: {
          type: ['number', 'null'],
          description: 'Optional: How many days in the past to include (default: 30)'
        },
        days_future: {
          type: ['number', 'null'],
          description: 'Optional: How many days in the future to include (default: 60)'
        }
      },
      required: []
    }
  },
  {
    name: 'get_team_members',
    description: 'Get list of all team members/staff with their roles and current availability status. Use this when user asks about team, staff, or who is available.',
    parameters: {
      type: 'object',
      properties: {
        role: {
          type: ['string', 'null'],
          description: 'Optional: Filter by specific role (e.g., "Server", "Bartender")'
        }
      },
      required: []
    }
  },
  {
    name: 'get_venues_history',
    description: 'Get list of venues from past events. Use this when user asks about venues they\'ve used before or wants to see venue history.',
    parameters: {
      type: 'object',
      properties: {
        limit: {
          type: ['number', 'null'],
          description: 'Maximum number of venues to return (default: 20)'
        }
      },
      required: []
    }
  }
];

/**
 * Execute a function call from the AI model
 * Handles all function types: queries and creates
 */
async function executeFunctionCall(
  functionName: string,
  functionArgs: any,
  managerId: mongoose.Types.ObjectId
): Promise<string> {
  console.log(`[executeFunctionCall] Executing ${functionName} with args:`, functionArgs);

  try {
    switch (functionName) {
      case 'search_addresses': {
        const { query, client_name } = functionArgs;
        const filter: any = { managerId };

        if (client_name) {
          filter.client_name = new RegExp(client_name, 'i');
        }

        if (query) {
          filter.$or = [
            { venue_name: new RegExp(query, 'i') },
            { venue_address: new RegExp(query, 'i') },
            { city: new RegExp(query, 'i') }
          ];
        }

        const events = await EventModel.find(filter)
          .select('venue_name venue_address city state event_name client_name date')
          .sort({ date: -1 })
          .limit(20)
          .lean();

        // HYBRID SEARCH: If no database results, fallback to Google Places API
        if (events.length === 0) {
          console.log(`[search_addresses] No database results for "${query}", falling back to Google Places API`);

          try {
            const googleMapsKey = process.env.GOOGLE_MAPS_API_KEY;

            if (!googleMapsKey) {
              return `No addresses found in your past events for "${query}"${client_name ? ` for client ${client_name}` : ''}. (Google Places search unavailable - API key not configured)`;
            }

            // Use Places Autocomplete API as fallback
            const params = new URLSearchParams({
              input: query,
              key: googleMapsKey,
              location: '39.7392,-104.9903', // Default: Denver, CO
              radius: '50000', // 50km radius
              region: 'us',
              components: 'country:us'
            });

            const url = `https://maps.googleapis.com/maps/api/place/autocomplete/json?${params.toString()}`;
            const response = await axios.get(url);

            if (response.data.status === 'OK' && response.data.predictions && response.data.predictions.length > 0) {
              const venues = response.data.predictions.slice(0, 5);
              const results = venues.map((venue: any) =>
                `${venue.structured_formatting?.main_text || venue.description} - ${venue.description}`
              ).join('\n');

              return `No matches in your past events, but I found these venues via Google Places:\n${results}`;
            }
          } catch (error: any) {
            console.error('[search_addresses] Google Places fallback error:', error);
            // Continue to return no results message below
          }

          return `No addresses found matching "${query}"${client_name ? ` for client ${client_name}` : ''}`;
        }

        const results = events.map(e =>
          `${e.venue_name || 'Unknown'} - ${e.venue_address || 'No address'}, ${e.city || 'Unknown city'} (Event: ${e.event_name}, Client: ${e.client_name}, Date: ${e.date})`
        ).join('\n');

        return `Found ${events.length} address(es) from your past events:\n${results}`;
      }

      case 'search_venue': {
        const { query, location, limit = 5 } = functionArgs;

        try {
          const googleMapsKey = process.env.GOOGLE_MAPS_API_KEY;

          if (!googleMapsKey) {
            return 'Google Maps API key not configured. Cannot search venues.';
          }

          // Build search query - combine venue query with location if provided
          const searchQuery = location
            ? `${query} in ${location}`
            : query;

          // Use Places Autocomplete API for venue search
          const params = new URLSearchParams({
            input: searchQuery,
            key: googleMapsKey,
            location: '39.7392,-104.9903', // Default: Denver, CO
            radius: '50000', // 50km radius
            region: 'us',
            components: 'country:us'
          });

          const url = `https://maps.googleapis.com/maps/api/place/autocomplete/json?${params.toString()}`;
          const response = await axios.get(url);

          if (response.data.status !== 'OK' && response.data.status !== 'ZERO_RESULTS') {
            console.error('[search_venue] API error:', response.data.status, response.data.error_message);
            return `Failed to search venues: ${response.data.status}${response.data.error_message ? ' - ' + response.data.error_message : ''}`;
          }

          if (response.data.status === 'ZERO_RESULTS' || !response.data.predictions || response.data.predictions.length === 0) {
            return `No venues found for "${query}"${location ? ` in ${location}` : ''}`;
          }

          // Format results - limit to requested number
          const venues = response.data.predictions.slice(0, Math.min(limit, 10));
          const results = venues.map((venue: any) =>
            `${venue.structured_formatting?.main_text || venue.description} - ${venue.description}`
          ).join('\n');

          return `Found ${venues.length} venue(s):\n${results}`;

        } catch (error: any) {
          console.error('[search_venue] Error:', error);
          return `Failed to search venues: ${error.message}`;
        }
      }

      case 'search_shifts': {
        const { client_name, date, venue_name, event_name } = functionArgs;
        const filter: any = { managerId };

        if (client_name) filter.client_name = new RegExp(client_name, 'i');
        if (venue_name) filter.venue_name = new RegExp(venue_name, 'i');
        if (event_name) filter.event_name = new RegExp(event_name, 'i');

        if (date) {
          if (date.length === 7) {
            // Month filter: YYYY-MM
            const startDate = new Date(`${date}-01`);
            const endDate = new Date(startDate);
            endDate.setMonth(endDate.getMonth() + 1);
            filter.date = { $gte: startDate, $lt: endDate };
          } else {
            // Exact date: YYYY-MM-DD
            filter.date = new Date(date);
          }
        }

        const events = await EventModel.find(filter)
          .sort({ date: -1 })
          .limit(50)
          .lean();

        if (events.length === 0) {
          return 'No shifts found matching the criteria';
        }

        const results = events.map(e =>
          `${e.event_name} - Client: ${e.client_name}, Date: ${e.date}, Venue: ${e.venue_name || 'TBD'}, Status: ${e.status || 'pending'}`
        ).join('\n');

        return `Found ${events.length} shift(s):\n${results}`;
      }

      case 'check_availability': {
        const { date } = functionArgs;
        // Note: Availability system needs refactoring - returning context data for now
        return `Availability checking is being updated. Please check the Team Members section in your context for team availability information.`;
      }

      case 'get_client_info': {
        const { client_name } = functionArgs;

        const client = await ClientModel.findOne({
          managerId,
          normalizedName: client_name.toLowerCase()
        }).lean();

        if (!client) {
          return `Client "${client_name}" not found`;
        }

        // Get events for this client
        const events = await EventModel.find({
          managerId,
          client_name: new RegExp(client_name, 'i')
        })
          .sort({ date: -1 })
          .limit(20)
          .lean();

        // Get tariffs for this client
        const tariffs = await TariffModel.find({
          managerId,
          clientId: client._id
        })
          .populate('roleId', 'name')
          .lean();

        let result = `Client: ${client.name}\n`;
        result += `Events (${events.length}):\n`;
        if (events.length > 0) {
          result += events.map(e => `  - ${e.event_name} on ${e.date}`).join('\n');
        } else {
          result += '  No events found';
        }

        result += `\n\nTariffs (${tariffs.length}):\n`;
        if (tariffs.length > 0) {
          result += tariffs.map(t => {
            const roleName = (t.roleId as any)?.name || 'Unknown';
            return `  - ${roleName}: $${t.rate} ${t.currency}`;
          }).join('\n');
        } else {
          result += '  No tariffs set';
        }

        return result;
      }

      case 'create_client': {
        const { name } = functionArgs;
        const trimmedName = name.trim();

        // Check if client already exists
        const existing = await ClientModel.findOne({
          managerId,
          normalizedName: trimmedName.toLowerCase()
        }).lean();

        if (existing) {
          return `Client "${trimmedName}" already exists`;
        }

        // Create new client
        const created = await ClientModel.create({
          managerId,
          name: trimmedName
        });

        return `✅ Successfully created client "${created.name}" (ID: ${created._id})`;
      }

      case 'create_role': {
        const { name } = functionArgs;
        const trimmedName = name.trim();

        // Check if role already exists
        const existing = await RoleModel.findOne({
          managerId,
          normalizedName: trimmedName.toLowerCase()
        }).lean();

        if (existing) {
          return `Role "${trimmedName}" already exists`;
        }

        // Create new role
        const created = await RoleModel.create({
          managerId,
          name: trimmedName
        });

        return `✅ Successfully created role "${created.name}" (ID: ${created._id})`;
      }

      case 'create_tariff': {
        const { client_name, role_name, rate, currency = 'USD' } = functionArgs;

        // Find client
        const client = await ClientModel.findOne({
          managerId,
          normalizedName: client_name.toLowerCase()
        }).lean();

        if (!client) {
          return `❌ Client "${client_name}" not found. Please create the client first using create_client.`;
        }

        // Find role
        const role = await RoleModel.findOne({
          managerId,
          normalizedName: role_name.toLowerCase()
        }).lean();

        if (!role) {
          return `❌ Role "${role_name}" not found. Please create the role first using create_role.`;
        }

        // Create or update tariff
        const result = await TariffModel.updateOne(
          {
            managerId,
            clientId: client._id,
            roleId: role._id
          },
          {
            $set: {
              managerId,
              clientId: client._id,  // Include in $set for upsert safety
              roleId: role._id,      // Include in $set for upsert safety
              rate,
              currency,
              updatedAt: new Date()
            },
            $setOnInsert: { createdAt: new Date() }
          },
          { upsert: true }
        );

        if (result.upsertedId) {
          return `✅ Successfully created tariff for ${client_name} - ${role_name}: $${rate} ${currency}/hour`;
        } else {
          return `✅ Successfully updated tariff for ${client_name} - ${role_name}: $${rate} ${currency}/hour`;
        }
      }

      case 'create_shift': {
        const {
          client_name,
          date,
          call_time,
          end_time,
          venue_name,
          venue_address,
          roles = [],
          uniform,
          notes,
          contact_name,
          contact_phone,
          headcount_total
        } = functionArgs;

        // Validate required fields
        if (!client_name || !date || !call_time || !end_time) {
          return `❌ Missing required fields. Need: client_name, date, call_time (staff arrival), end_time`;
        }

        // Validate roles array is not empty (schema requires at least 1 role)
        if (!roles || !Array.isArray(roles) || roles.length === 0) {
          return `❌ At least one role is required. Please specify the roles needed for this shift.`;
        }

        // Auto-generate shift name from client and date
        const eventDate = new Date(date);
        const shiftName = `${client_name} - ${eventDate.toLocaleDateString('en-US', { month: 'short', day: 'numeric' })}`;

        // Create event document
        const eventData: any = {
          managerId,
          status: 'draft',
          shift_name: shiftName,  // Use shift_name, not deprecated event_name
          client_name,
          date: eventDate,
          start_time: call_time,  // Call time = start time (when staff arrives)
          end_time,
          roles: roles,  // Already validated to have at least 1 role
          accepted_staff: [],
          declined_staff: []
        };

        // Add optional fields (city/state are now truly optional, not hardcoded)
        if (venue_name) eventData.venue_name = venue_name;
        if (venue_address) eventData.venue_address = venue_address;
        if (uniform) eventData.uniform = uniform;
        if (notes) eventData.notes = notes;
        if (contact_name) eventData.contact_name = contact_name;
        if (contact_phone) eventData.contact_phone = contact_phone;
        if (headcount_total) eventData.headcount_total = headcount_total;

        const created = await EventModel.create(eventData);

        let summary = `✅ Successfully created event (ID: ${created._id})\n`;
        summary += `👥 Client: ${client_name}\n`;
        summary += `📅 Date: ${date}\n`;
        summary += `⏰ Call Time: ${call_time} (staff arrival)\n`;
        summary += `⏱️  End Time: ${end_time}\n`;
        if (venue_name) summary += `📍 Venue: ${venue_name}\n`;
        if (venue_address) summary += `   Address: ${venue_address}\n`;
        if (roles.length > 0) {
          summary += `👔 Staff needed:\n`;
          roles.forEach((r: any) => {
            summary += `   - ${r.count}x ${r.role}\n`;
          });
        }
        if (uniform) summary += `👕 Uniform: ${uniform}\n`;
        if (headcount_total) summary += `👥 Guest count: ${headcount_total}\n`;
        summary += `\n📝 Status: DRAFT (ready to publish to staff)`;

        return summary;
      }

      case 'get_clients_list': {
        const clients = await ClientModel.find({ managerId })
          .select('name')
          .sort({ name: 1 })
          .lean();

        if (clients.length === 0) {
          return 'No clients found in your account. You can create clients as needed.';
        }

        const clientList = clients.map(c => c.name).join(', ');
        return `You have ${clients.length} client(s): ${clientList}`;
      }

      case 'get_events_summary': {
        const { client_name, days_past = 30, days_future = 60 } = functionArgs;

        const filter: any = { managerId };
        if (client_name) {
          filter.client_name = new RegExp(client_name, 'i');
        }

        const today = new Date();
        const pastDate = new Date(today);
        pastDate.setDate(pastDate.getDate() - days_past);
        const futureDate = new Date(today);
        futureDate.setDate(futureDate.getDate() + days_future);

        filter.date = { $gte: pastDate, $lte: futureDate };

        const events = await EventModel.find(filter)
          .select('event_name client_name date venue_name city start_time end_time')
          .sort({ date: 1 })
          .limit(50)
          .lean();

        if (events.length === 0) {
          return `No events found${client_name ? ` for client ${client_name}` : ''} in the specified date range.`;
        }

        const results = events.map((e: any) => {
          const dateStr = e.date ? new Date(e.date).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' }) : 'No date';
          const timeStr = e.start_time ? `${e.start_time} - ${e.end_time || '?'}` : '';
          return `${dateStr}: ${e.event_name || 'Unnamed'} (${e.client_name || 'No client'}) at ${e.venue_name || 'TBD'}${timeStr ? `, ${timeStr}` : ''}`;
        }).join('\n');

        return `Found ${events.length} event(s):\n${results}`;
      }

      case 'get_team_members': {
        const { role } = functionArgs;

        const filter: any = { managerId };
        if (role) {
          filter.roles = { $elemMatch: { $regex: new RegExp(role, 'i') } };
        }

        const members = await TeamMemberModel.find(filter)
          .select('first_name last_name roles email phone')
          .sort({ last_name: 1, first_name: 1 })
          .lean();

        if (members.length === 0) {
          return `No team members found${role ? ` with role "${role}"` : ''}`;
        }

        const results = members.map((m: any) => {
          const name = `${m.first_name} ${m.last_name}`;
          const rolesStr = Array.isArray(m.roles) ? m.roles.join(', ') : 'No roles';
          return `${name} - ${rolesStr}`;
        }).join('\n');

        return `Found ${members.length} team member(s):\n${results}`;
      }

      case 'get_venues_history': {
        const { limit = 20 } = functionArgs;

        const events = await EventModel.find({ managerId })
          .select('venue_name venue_address city state')
          .sort({ date: -1 })
          .limit(limit)
          .lean();

        if (events.length === 0) {
          return 'No venues found in your event history.';
        }

        // Deduplicate venues by name
        const venuesMap = new Map();
        for (const e of events) {
          if (e.venue_name && !venuesMap.has(e.venue_name)) {
            venuesMap.set(e.venue_name, e);
          }
        }

        const venues = Array.from(venuesMap.values()).slice(0, limit);
        const results = venues.map(v =>
          `${v.venue_name} - ${v.venue_address || 'No address'}, ${v.city || '?'}, ${v.state || '?'}`
        ).join('\n');

        return `Found ${venues.length} venue(s) from your history:\n${results}`;
      }

      default:
        return `Unknown function: ${functionName}`;
    }
  } catch (error: any) {
    console.error(`[executeFunctionCall] Error executing ${functionName}:`, error);
    return `Error executing ${functionName}: ${error.message}`;
  }
}

/**
 * POST /api/ai/extract
 * Groq-powered extraction endpoint:
 * - Images: Llama 4 Scout 17B vision model
 * - Text/PDFs: Llama 3.1 8B Instant text model
 * Accepts text or base64 image input and returns structured event data
 */
router.post('/ai/extract', requireAuth, async (req, res) => {
  try {
    const validated = extractionSchema.parse(req.body);
    const { input, isImage } = validated;

    // Use Groq for both vision and text extraction
    const groqKey = process.env.GROQ_API_KEY;

    if (!groqKey) {
      console.error('[ai/extract] GROQ_API_KEY not configured');
      return res.status(500).json({ message: 'Groq API key not configured on server' });
    }

    // Groq models: Llama 4 Scout for vision, Llama 3.1 for text
    const visionModel = 'meta-llama/llama-4-scout-17b-16e-instruct';
    const textModel = 'llama-3.1-8b-instant'; // Fast Groq text model
    const groqBaseUrl = 'https://api.groq.com/openai/v1';

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

    // Always use Groq API for both vision and text
    const headers: any = {
      'Authorization': `Bearer ${groqKey}`,
      'Content-Type': 'application/json',
    };

    // Call Groq API with retries
    const response = await callOpenAIWithRetries(
      `${groqBaseUrl}/chat/completions`,
      headers,
      requestBody
    );

    if (response.status >= 300) {
      console.error(`[ai/extract] Groq API error:`, response.status);
      console.error(`[ai/extract] Error details:`, JSON.stringify(response.data, null, 2));
      console.error(`[ai/extract] Request body:`, JSON.stringify(requestBody, null, 2));
      if (response.status === 429) {
        return res.status(429).json({
          message: 'Groq API rate limit or quota exceeded. Please try again later.',
        });
      }
      return res.status(response.status).json({
        message: `Groq API error: ${response.statusText}`,
        details: response.data,
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
        return res.status(500).json({ message: 'Failed to parse response from AI' });
      }
    }

    return res.status(500).json({ message: 'No valid JSON found in AI response' });
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

    console.log(`[ai/chat/message] Using Groq, model: ${model || 'llama-3.1-8b-instant'}`);

    // Get managerId from authenticated user
    const managerId = (req as any).user?._id || (req as any).user?.managerId;
    if (!managerId) {
      return res.status(401).json({ message: 'Manager not found' });
    }

    // Detect user's timezone from IP
    const timezone = getTimezoneFromRequest(req);

    // Always use Groq (optimized for cost and performance)
    return await handleGroqRequest(messages, temperature, maxTokens, res, timezone, model, managerId);
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
 * Format context examples from past successful conversations for prompt injection
 * Helps the AI learn from the manager's successful interaction patterns
 */
function formatContextExamples(examples: any[]): string {
  if (!examples || examples.length === 0) return '';

  const formattedExamples = examples.map((ex, index) => {
    // Extract key info from the conversation
    const userMessages = ex.messages
      .filter((m: any) => m.role === 'user')
      .slice(0, 2) // First 2 user messages only
      .map((m: any) => m.content.substring(0, 200)) // Truncate long messages
      .join(' → ');

    const eventData = ex.extractedEventData || {};
    const summary = [
      eventData.client_name && `Client: ${eventData.client_name}`,
      eventData.date && `Date: ${eventData.date}`,
      eventData.venue_name && `Venue: ${eventData.venue_name}`,
    ].filter(Boolean).join(', ');

    return `Example ${index + 1}: "${userMessages}" → Created: ${summary || 'Event'}`;
  }).join('\n');

  return `
📚 LEARNING FROM PAST SUCCESS (Manager's successful conversations):
These are examples of successful event creations from this manager. Use similar patterns:
${formattedExamples}

Use these examples to understand how this manager typically communicates and creates events.
`;
}

/**
 * Handle Groq chat request for manager with optimized Chat Completions API
 * Supports: llama-3.1-8b-instant (fast/cheap) and openai/gpt-oss-20b (reasoning)
 * Features: Parallel tool calls, prompt caching, retry logic, reasoning mode
 */
async function handleGroqRequest(
  messages: any[],
  temperature: number,
  maxTokens: number,
  res: any,
  timezone?: string,
  model?: string,
  managerId?: mongoose.Types.ObjectId
) {
  const groqKey = process.env.GROQ_API_KEY;
  if (!groqKey) {
    console.error('[Groq] API key not configured');
    return res.status(500).json({ message: 'Groq API key not configured on server' });
  }

  // Use GPT-OSS-20B for function calling (131K context, OpenAI-compatible tools)
  const groqModel = model || 'openai/gpt-oss-20b';  // 20B params, 131K context, 65K max output
  const isReasoningModel = false;

  console.log(`[Groq] Manager using model: ${groqModel}`);

  // Fetch context examples from successful past conversations (for learning)
  let contextExamplesPrompt = '';
  if (managerId) {
    try {
      const examples = await AIChatSummaryModel.find({
        managerId,
        outcome: 'event_created',
        wasEdited: false,
        messageCount: { $lte: 8 }, // Very short conversations only
      })
        .sort({ createdAt: -1 })
        .limit(2)
        .select('messages extractedEventData')
        .lean();

      if (examples.length > 0) {
        contextExamplesPrompt = formatContextExamples(examples);
        console.log(`[Groq] Injected ${examples.length} context example(s) from past conversations`);
      }
    } catch (error) {
      console.error('[Groq] Failed to fetch context examples:', error);
      // Continue without examples - non-blocking
    }
  }

  // Optimize prompt structure: CRITICAL rules FIRST (open-source models follow early instructions better)
  const systemInstructions = `
🚫 ABSOLUTE RULES - MUST FOLLOW (TOP PRIORITY):
1. **NEVER show raw JSON, code blocks, or technical data** to the user
2. **NEVER display IDs, timestamps, or internal field names** (like _id, createdAt, managerId)
3. **NEVER display function results or API responses** in their raw form
4. **NEVER ask the user to provide dates in a specific format** - convert automatically
5. **NEVER mention YYYY-MM-DD, ISO format, or any technical format** to the user
6. **NEVER create events in the past** - ALL event dates MUST be today or in the future

🎯 CONFIRMATION STYLE - ALWAYS USE NATURAL LANGUAGE:
When you CREATE, UPDATE, or DELETE something:
✅ GOOD: "Done! I've created the event for **Saturday, January 25th** at **The Grand Ballroom**."
✅ GOOD: "Got it! The shift is now scheduled for 4 PM with 3 bartenders."
✅ GOOD: "All set! Juan has been added to the event."
❌ BAD: "Event created successfully. Event ID: 507f1f77bcf86cd799439011"
❌ BAD: "Shift created with the following details: {date: '2025-01-25', ...}"
❌ BAD: "Success: true, message: 'Event created'"

📅 DATE & TIME HANDLING:
- Accept ANY natural language date: "February 3", "3 de febrero", "next Friday", "tomorrow"
- YOU must automatically convert to ISO format (YYYY-MM-DD) when calling functions
- 🚨 CRITICAL FUTURE DATE RULE: Check the system context for the current date!
  - If user says a month that has ALREADY PASSED this year → use NEXT year
  - Example: If today is December 2025 and user says "February" → use February 2026
  - NEVER create events for dates that have already passed
- If the date is ambiguous (missing month or day), ask for that specific info, NOT the format
- Same for times: accept "4pm", "4 de la tarde" → convert to "16:00" internally

🌍 LANGUAGE:
ALWAYS respond in the SAME LANGUAGE the user is speaking.
- If user writes in Spanish → respond in Spanish
- If user writes in English → respond in English

📋 FORMATTING:
- Present dates as "Saturday, January 25th" not "2025-01-25"
- Present times as "4:00 PM" not "16:00:00"
- Use bullet points for lists
- Use markdown: **bold** for important terms
`;

  const dateContext = getFullSystemContext(timezone);

  // Put static instructions FIRST (cacheable), dynamic date context LAST (not cached)
  // Include context examples from successful past conversations for learning
  const systemContent = `${systemInstructions}\n\n${dateContext}${contextExamplesPrompt ? '\n\n' + contextExamplesPrompt : ''}`;

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
  const groqTools = AI_TOOLS.map(tool => ({
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
    temperature: isReasoningModel ? 0.6 : temperature, // Higher temp for reasoning
    max_tokens: isReasoningModel ? maxTokens * 2 : maxTokens, // More tokens for reasoning
    tools: groqTools,
    tool_choice: 'auto'
  };

  // Add reasoning parameters for gpt-oss models
  if (isReasoningModel) {
    requestBody.reasoning_format = 'hidden'; // Hide reasoning, show only final answer
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

      const response = await axios.post(
        'https://api.groq.com/openai/v1/chat/completions',
        requestBody,
        { headers, validateStatus: () => true, timeout: 60000 }
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

        if (!managerId) {
          return res.status(401).json({ message: 'Manager ID required for function calls' });
        }

        // Execute tool calls in parallel
        const toolResults = await Promise.all(
          assistantMessage.tool_calls.map(async (toolCall: any) => {
            const functionName = toolCall.function.name;
            const functionArgs = JSON.parse(toolCall.function.arguments);

            console.log(`[Groq] Executing ${functionName}:`, functionArgs);

            const result = await executeFunctionCall(functionName, functionArgs, managerId);

            return {
              role: 'tool',
              tool_call_id: toolCall.id,
              content: result
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

/**
 * POST /api/ai/discover-venues
 * Discover popular event venues in a city using Perplexity AI with automatic web search
 * Saves personalized venue list to manager's profile
 */
router.post('/ai/discover-venues', requireAuth, async (req, res) => {
  try {
    const { city, isTourist } = req.body;

    if (!city || typeof city !== 'string') {
      return res.status(400).json({ message: 'City is required' });
    }

    const isTouristCity = isTourist === true; // Default to false if not provided

    const perplexityKey = process.env.PERPLEXITY_API_KEY;
    if (!perplexityKey) {
      console.error('[discover-venues] PERPLEXITY_API_KEY not configured');
      return res.status(500).json({ message: 'Perplexity API key not configured on server' });
    }

    // Get manager from auth
    if (!(req as any).authUser?.provider || !(req as any).authUser?.sub) {
      return res.status(401).json({ message: 'Unauthorized' });
    }

    const manager = await ManagerModel.findOne({
      provider: (req as any).authUser.provider,
      subject: (req as any).authUser.sub,
    });

    if (!manager) {
      return res.status(404).json({ message: 'Manager not found' });
    }

    console.log(`[discover-venues] Researching venues for ${isTouristCity ? 'tourist city' : 'metro area'}: ${city} using Perplexity AI`);

    // Extract city name and state from "City, State, Country" format
    const metroArea = city.includes(',') ? (city.split(',')[0] || city).trim() : city;
    const state = city.includes(',') ? (city.split(',')[1] || '').trim() : '';

    // Determine venue capacity and search strategy based on city type
    const venueCapacity = isTouristCity ? 30 : 80;
    const minVenues = isTouristCity ? 10 : 70;

    // Create prompt based on city type
    let prompt: string;

    if (isTouristCity) {
      // Tourist city: Search ONLY within the specific city limits
      prompt = `Find event venues located specifically IN ${metroArea}${state ? ', ' + state : ''}.

CRITICAL: Only include venues that are PHYSICALLY LOCATED in ${metroArea} itself, not in nearby cities or the surrounding metro area.

Find ${minVenues}-${venueCapacity} venues including:
1. **HOTELS** - Hotels, resorts, lodges with event spaces, ballrooms, or meeting rooms in ${metroArea}
2. **WEDDING VENUES** - Wedding venues, reception halls, banquet facilities in ${metroArea}
3. **RESTAURANTS & BARS** - Restaurants, breweries, wineries with private event rooms or buyout options in ${metroArea}
4. **EVENT CENTERS** - Conference centers, community centers, event halls in ${metroArea}
5. **UNIQUE VENUES** - Historic buildings, museums, theaters, galleries with event spaces in ${metroArea}
6. **OUTDOOR VENUES** - Parks, gardens, ranches, ski resorts (if applicable) in ${metroArea}

CRITICAL: DO NOT include venues from nearby cities. For example, if searching for ${metroArea}, do NOT include venues from other cities even if they are close by.

For EACH venue, provide:
- Exact official name
- Complete address (street number, street, city, state, ZIP)
- City name (must be ${metroArea})

Return ONLY this JSON format (no markdown, no explanations):
{
  "venues": [
    {"name": "Example Hotel & Resort", "address": "123 Main St, ${metroArea}, ${state} 12345", "city": "${metroArea}"}
  ]
}

Return ${minVenues}-${venueCapacity} venues that are all located in ${metroArea}.`;
    } else {
      // Metro city: Search ENTIRE metropolitan area (current behavior)
      prompt = `Find the ${minVenues}-${venueCapacity} MOST POPULAR and LARGEST event venues in the ${city} metropolitan area and surrounding region.

CRITICAL INSTRUCTIONS:
1. PRIORITIZE THE BIGGEST AND MOST WELL-KNOWN VENUES FIRST
2. Include venues from the ENTIRE metro area (downtown, suburbs, all cities in the region)
3. Focus on venues that host MAJOR events (thousands of people, large weddings, big conferences)
4. Do NOT focus only on small local venues in one specific suburb

MUST INCLUDE these types of major venues (search the entire metro area):
1. **STADIUMS & ARENAS** - Sports venues, amphitheaters (like Ball Arena, stadiums, major concert venues)
2. **CONVENTION CENTERS** - Major convention centers and conference facilities
3. **MAJOR HOTELS** - Large hotels with ballrooms and event spaces (Marriott, Hilton, Hyatt, etc.)
4. **POPULAR WEDDING VENUES** - Well-known wedding venues and reception halls across the metro
5. **CONCERT HALLS & THEATERS** - Major performance venues and concert halls
6. **MUSEUMS & CULTURAL CENTERS** - Major museums and cultural venues
7. **COUNTRY CLUBS & GOLF COURSES** - Upscale venues with event spaces
8. **UNIQUE POPULAR VENUES** - Well-known breweries, wineries, historic buildings, specialty venues

Search across ALL cities in the ${metroArea} metro area, not just one suburb. Include downtown venues, suburban venues, and everything in between.

For EACH venue, provide:
- Exact official name
- Complete address (street number, street, city, state, ZIP)
- City name

Return ONLY this JSON format (no markdown, no explanations):
{
  "venues": [
    {"name": "Ball Arena", "address": "1000 Chopper Cir, Denver, CO 80204", "city": "Denver"},
    {"name": "Colorado Convention Center", "address": "700 14th St, Denver, CO 80202", "city": "Denver"}
  ]
}

YOU MUST RETURN AT LEAST ${minVenues} VENUES. Prioritize the most popular and largest venues first.`;
    }

    const headers = {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${perplexityKey}`,
    };

    const requestBody = {
      model: 'sonar-pro', // Premium model for better quality and accuracy
      messages: [
        { role: 'user', content: prompt }
      ],
      temperature: 0.3,
      max_tokens: 4000, // Increased for more venues
    };

    console.log('[discover-venues] Calling Perplexity API...');

    const response = await axios.post(
      'https://api.perplexity.ai/chat/completions',
      requestBody,
      { headers, validateStatus: () => true, timeout: 90000 } // 90s timeout for web search
    );

    if (response.status !== 200) {
      console.error('[discover-venues] Perplexity API error:', response.status, response.data);
      return res.status(response.status).json({
        message: 'Failed to discover venues',
        error: response.data
      });
    }

    // Perplexity returns standard OpenAI format with content in message.content
    const content = response.data.choices?.[0]?.message?.content;

    if (!content) {
      console.error('[discover-venues] No content in response. Response:', JSON.stringify(response.data, null, 2).substring(0, 500));
      return res.status(500).json({ message: 'No venue data returned' });
    }

    console.log('[discover-venues] Response length:', content.length, 'chars');
    console.log('[discover-venues] Full response:', content);

    // Parse JSON response
    let venueData;
    try {
      // Try to parse directly first (Perplexity should return clean JSON)
      let cleanedContent = content.trim();

      // Remove markdown code blocks if present
      if (cleanedContent.startsWith('```')) {
        cleanedContent = cleanedContent
          .replace(/```json\n?/g, '')
          .replace(/```\n?/g, '')
          .trim();
      }

      // Try direct parsing first
      try {
        venueData = JSON.parse(cleanedContent);
      } catch (directParseError) {
        // If that fails, extract JSON object from text using brace counting
        const jsonStartPattern = /\{\s*"venues"\s*:\s*\[/;
        const startMatch = cleanedContent.match(jsonStartPattern);

        if (!startMatch) {
          throw new Error('Could not find JSON start pattern in response');
        }

        const startIndex = cleanedContent.indexOf(startMatch[0]);
        let braceCount = 0;
        let endIndex = -1;

        for (let i = startIndex; i < cleanedContent.length; i++) {
          if (cleanedContent[i] === '{') braceCount++;
          else if (cleanedContent[i] === '}') {
            braceCount--;
            if (braceCount === 0) {
              endIndex = i + 1;
              break;
            }
          }
        }

        if (endIndex === -1) {
          throw new Error('Could not find matching closing brace');
        }

        const jsonString = cleanedContent.substring(startIndex, endIndex);
        venueData = JSON.parse(jsonString);
      }

      console.log('[discover-venues] Successfully parsed JSON');
    } catch (parseError) {
      console.error('[discover-venues] Failed to parse JSON:', parseError);
      console.error('[discover-venues] Content sample:', content.substring(0, 1000));
      return res.status(500).json({ message: 'Failed to parse venue data' });
    }

    const venues = venueData.venues;
    if (!Array.isArray(venues) || venues.length === 0) {
      console.error('[discover-venues] No venues in response');
      return res.status(500).json({ message: 'No venues found' });
    }

    // Validate and clean venue data
    const rawVenues = venues
      .filter(v => v.name && v.address && v.city)
      .map(v => ({
        name: String(v.name).trim(),
        address: String(v.address).trim(),
        city: String(v.city).trim(),
        cityName: city, // Link venue to city from request
      }));

    // Remove duplicates within AI results (case-insensitive name match)
    const seenNames = new Set<string>();
    const validatedVenues = rawVenues
      .filter(v => {
        const normalizedName = v.name.toLowerCase().trim();
        if (seenNames.has(normalizedName)) {
          return false; // Skip duplicate
        }
        seenNames.add(normalizedName);
        return true;
      })
      .slice(0, venueCapacity); // Cap at capacity (30 for tourist cities, 80 for metro)

    if (validatedVenues.length === 0) {
      return res.status(500).json({ message: 'No valid venues found' });
    }

    const duplicatesRemoved = rawVenues.length - validatedVenues.length;
    console.log(`[discover-venues] Found ${validatedVenues.length} unique AI venues (removed ${duplicatesRemoved} duplicates from AI response)`);

    // Save to new venues collection instead of embedded venueList
    try {
      // 1. Get existing manual/places venues for this city (to avoid duplicates)
      const existingManualVenues = await VenueModel.find({
        managerId: manager._id,
        city: { $regex: new RegExp(`^${metroArea}$`, 'i') },
        source: { $in: ['manual', 'places'] }
      }).lean();

      const manualNames = new Set(existingManualVenues.map(v => v.name.toLowerCase().trim()));
      console.log(`[discover-venues] Found ${existingManualVenues.length} existing manual/places venues for ${metroArea}`);

      // 2. Delete existing AI venues for this city (will be replaced)
      const deleteResult = await VenueModel.deleteMany({
        managerId: manager._id,
        city: { $regex: new RegExp(`^${metroArea}$`, 'i') },
        source: 'ai'
      });
      console.log(`[discover-venues] Deleted ${deleteResult.deletedCount} existing AI venues for ${metroArea}`);

      // 3. Filter out AI venues that duplicate existing manual venues
      const uniqueAIVenues = validatedVenues.filter(v =>
        !manualNames.has(v.name.toLowerCase().trim())
      );
      console.log(`[discover-venues] Adding ${uniqueAIVenues.length} unique AI venues (${validatedVenues.length - uniqueAIVenues.length} duplicates of manual venues skipped)`);

      // 4. Bulk insert new AI venues
      if (uniqueAIVenues.length > 0) {
        const venueDocs = uniqueAIVenues.map(v => ({
          managerId: manager._id,
          name: v.name,
          normalizedName: v.name.toLowerCase().trim(),
          address: v.address,
          city: v.city || metroArea,
          state: state || undefined,
          source: 'ai' as const,
        }));

        await VenueModel.insertMany(venueDocs, { ordered: false });
        console.log(`[discover-venues] Successfully inserted ${uniqueAIVenues.length} AI venues to collection`);
      }

      // 5. Get total venue count for this manager
      const totalVenueCount = await VenueModel.countDocuments({ managerId: manager._id });
      console.log(`[discover-venues] Total venues in collection for manager: ${totalVenueCount}`);

      return res.json({
        success: true,
        city,
        venueCount: uniqueAIVenues.length,
        venues: uniqueAIVenues.map(v => ({
          name: v.name,
          address: v.address,
          city: v.city || metroArea,
          source: 'ai'
        })),
        updatedAt: new Date(),
      });

    } catch (saveError: any) {
      console.error('[discover-venues] Failed to save venues:', saveError);
      return res.status(500).json({
        message: 'Failed to save venues to database',
        error: saveError?.message
      });
    }

  } catch (error: any) {
    console.error('[discover-venues] Error:', error);
    return res.status(500).json({
      message: 'Failed to discover venues',
      error: error.message
    });
  }
});

// ============================================================================
// AI CHAT SUMMARY ENDPOINTS - For learning and analytics
// ============================================================================

/**
 * Zod schema for conversation message
 */
const conversationMessageSchema = z.object({
  role: z.enum(['user', 'assistant', 'system']),
  content: z.string().max(10000),
  timestamp: z.string(), // ISO string, parsed later (Dart's toIso8601String doesn't include Z)
  toolsUsed: z.array(z.string()).optional(),
});

/**
 * Zod schema for saving chat summary
 */
const saveChatSummarySchema = z.object({
  messages: z.array(conversationMessageSchema).min(1),
  extractedEventData: z.record(z.unknown()),
  eventId: z.string().optional().nullable(),
  outcome: z.enum(['event_created', 'event_cancelled', 'timeout_saved', 'abandoned', 'error']),
  outcomeReason: z.string().max(500).optional().nullable(),
  durationMs: z.number().min(0),
  toolCallCount: z.number().min(0),
  toolsUsed: z.array(z.string()),
  inputSource: z.enum(['text', 'voice', 'image', 'pdf']).optional(),
  wasEdited: z.boolean(),
  editedFields: z.array(z.string()).optional(),
  aiModel: z.string(),
  aiProvider: z.string(),
  conversationStartedAt: z.string(), // ISO string, parsed later
  conversationEndedAt: z.string(), // ISO string, parsed later
});

/**
 * POST /api/ai/chat/summary
 * Save AI chat conversation summary when event is created
 */
router.post('/ai/chat/summary', requireAuth, async (req, res) => {
  try {
    const authUser = (req as any).user;
    const managerId = authUser?.managerId;

    if (!managerId) {
      return res.status(401).json({ error: 'Manager authentication required' });
    }

    // Validate request body
    const parseResult = saveChatSummarySchema.safeParse(req.body);
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
      managerId: new mongoose.Types.ObjectId(managerId),
      userType: 'manager',
      messages,
      extractedEventData: data.extractedEventData,
      eventId: data.eventId ? new mongoose.Types.ObjectId(data.eventId) : undefined,
      outcome: data.outcome,
      outcomeReason: data.outcomeReason,
      durationMs: data.durationMs,
      toolCallCount: data.toolCallCount,
      toolsUsed: data.toolsUsed,
      inputSource: data.inputSource || 'text',
      wasEdited: data.wasEdited,
      editedFields: data.editedFields || [],
      aiModel: data.aiModel,
      aiProvider: data.aiProvider,
      conversationStartedAt: new Date(data.conversationStartedAt),
      conversationEndedAt: new Date(data.conversationEndedAt),
    });

    await summary.save();

    console.log(`[chat/summary] Saved conversation summary for manager ${managerId}, outcome: ${data.outcome}`);

    return res.status(201).json({
      message: 'Chat summary saved successfully',
      id: summary._id,
    });
  } catch (error: any) {
    console.error('[chat/summary] Error saving summary:', error);
    return res.status(500).json({
      error: 'Failed to save chat summary',
      message: error.message,
    });
  }
});

/**
 * GET /api/ai/chat/context-examples
 * Get successful conversation examples for AI context injection
 * Returns 2-3 short, successful, unedited conversations
 */
router.get('/ai/chat/context-examples', requireAuth, async (req, res) => {
  try {
    const authUser = (req as any).user;
    const managerId = authUser?.managerId;

    if (!managerId) {
      return res.status(401).json({ error: 'Manager authentication required' });
    }

    // Find successful, unedited, short conversations
    const examples = await AIChatSummaryModel.find({
      managerId: new mongoose.Types.ObjectId(managerId),
      outcome: 'event_created',
      wasEdited: false,
      messageCount: { $lte: 10 }, // Short conversations only
    })
      .sort({ createdAt: -1 })
      .limit(3)
      .select('messages extractedEventData messageCount durationMs')
      .lean();

    return res.json({
      examples: examples.map(ex => ({
        messages: ex.messages.slice(0, 6), // Limit to first 6 messages
        eventSummary: {
          clientName: ex.extractedEventData?.client_name,
          date: ex.extractedEventData?.date,
          venueName: ex.extractedEventData?.venue_name,
        },
        messageCount: ex.messageCount,
      })),
      count: examples.length,
    });
  } catch (error: any) {
    console.error('[chat/context-examples] Error:', error);
    return res.status(500).json({
      error: 'Failed to fetch context examples',
      message: error.message,
    });
  }
});

/**
 * GET /api/ai/chat/summaries
 * List conversation summaries with pagination for analytics/review
 */
router.get('/ai/chat/summaries', requireAuth, async (req, res) => {
  try {
    const authUser = (req as any).user;
    const managerId = authUser?.managerId;

    if (!managerId) {
      return res.status(401).json({ error: 'Manager authentication required' });
    }

    const page = Math.max(1, parseInt(req.query.page as string) || 1);
    const limit = Math.min(50, Math.max(1, parseInt(req.query.limit as string) || 20));
    const skip = (page - 1) * limit;

    // Optional filters
    const outcome = req.query.outcome as string;
    const startDate = req.query.startDate as string;
    const endDate = req.query.endDate as string;

    // Build query
    const query: any = {
      managerId: new mongoose.Types.ObjectId(managerId),
    };

    if (outcome) {
      query.outcome = outcome;
    }

    if (startDate || endDate) {
      query.createdAt = {};
      if (startDate) query.createdAt.$gte = new Date(startDate);
      if (endDate) query.createdAt.$lte = new Date(endDate);
    }

    const [summaries, total] = await Promise.all([
      AIChatSummaryModel.find(query)
        .sort({ createdAt: -1 })
        .skip(skip)
        .limit(limit)
        .select('outcome messageCount durationMs toolsUsed inputSource wasEdited aiModel createdAt extractedEventData')
        .lean(),
      AIChatSummaryModel.countDocuments(query),
    ]);

    return res.json({
      summaries: summaries.map(s => ({
        id: s._id,
        outcome: s.outcome,
        messageCount: s.messageCount,
        durationMs: s.durationMs,
        durationFormatted: `${Math.round(s.durationMs / 1000)}s`,
        toolsUsed: s.toolsUsed,
        inputSource: s.inputSource,
        wasEdited: s.wasEdited,
        aiModel: s.aiModel,
        createdAt: s.createdAt,
        eventPreview: s.extractedEventData?.client_name
          ? `${s.extractedEventData.client_name} - ${s.extractedEventData.date || 'No date'}`
          : null,
      })),
      pagination: {
        page,
        limit,
        total,
        totalPages: Math.ceil(total / limit),
      },
    });
  } catch (error: any) {
    console.error('[chat/summaries] Error:', error);
    return res.status(500).json({
      error: 'Failed to fetch summaries',
      message: error.message,
    });
  }
});

/**
 * GET /api/ai/chat/summaries/:id
 * Get single conversation summary with full messages
 */
router.get('/ai/chat/summaries/:id', requireAuth, async (req, res) => {
  try {
    const authUser = (req as any).user;
    const managerId = authUser?.managerId;

    if (!managerId) {
      return res.status(401).json({ error: 'Manager authentication required' });
    }

    const summaryId = req.params.id;

    if (!summaryId || !mongoose.Types.ObjectId.isValid(summaryId)) {
      return res.status(400).json({ error: 'Invalid summary ID' });
    }

    const summary = await AIChatSummaryModel.findOne({
      _id: new mongoose.Types.ObjectId(summaryId),
      managerId: new mongoose.Types.ObjectId(managerId),
    }).lean();

    if (!summary) {
      return res.status(404).json({ error: 'Summary not found' });
    }

    return res.json({ summary });
  } catch (error: any) {
    console.error('[chat/summaries/:id] Error:', error);
    return res.status(500).json({
      error: 'Failed to fetch summary',
      message: error.message,
    });
  }
});

/**
 * GET /api/ai/chat/analytics
 * Get aggregated analytics for AI conversations
 */
router.get('/ai/chat/analytics', requireAuth, async (req, res) => {
  try {
    const authUser = (req as any).user;
    const managerId = authUser?.managerId;

    if (!managerId) {
      return res.status(401).json({ error: 'Manager authentication required' });
    }

    const startDate = req.query.startDate
      ? new Date(req.query.startDate as string)
      : new Date(Date.now() - 30 * 24 * 60 * 60 * 1000); // Default: last 30 days
    const endDate = req.query.endDate
      ? new Date(req.query.endDate as string)
      : new Date();

    const managerObjectId = new mongoose.Types.ObjectId(managerId);

    // Aggregation pipeline
    const [stats, outcomeBreakdown, toolUsage] = await Promise.all([
      // Overall stats
      AIChatSummaryModel.aggregate([
        {
          $match: {
            managerId: managerObjectId,
            createdAt: { $gte: startDate, $lte: endDate },
          },
        },
        {
          $group: {
            _id: null,
            total: { $sum: 1 },
            successful: {
              $sum: { $cond: [{ $eq: ['$outcome', 'event_created'] }, 1, 0] },
            },
            avgDuration: { $avg: '$durationMs' },
            avgMessages: { $avg: '$messageCount' },
            avgToolCalls: { $avg: '$toolCallCount' },
          },
        },
      ]),

      // Outcome breakdown
      AIChatSummaryModel.aggregate([
        {
          $match: {
            managerId: managerObjectId,
            createdAt: { $gte: startDate, $lte: endDate },
          },
        },
        {
          $group: {
            _id: '$outcome',
            count: { $sum: 1 },
          },
        },
      ]),

      // Top tools used
      AIChatSummaryModel.aggregate([
        {
          $match: {
            managerId: managerObjectId,
            createdAt: { $gte: startDate, $lte: endDate },
          },
        },
        { $unwind: '$toolsUsed' },
        {
          $group: {
            _id: '$toolsUsed',
            count: { $sum: 1 },
          },
        },
        { $sort: { count: -1 } },
        { $limit: 10 },
      ]),
    ]);

    const overallStats = stats[0] || {
      total: 0,
      successful: 0,
      avgDuration: 0,
      avgMessages: 0,
      avgToolCalls: 0,
    };

    return res.json({
      period: {
        startDate,
        endDate,
      },
      overall: {
        totalConversations: overallStats.total,
        successfulConversations: overallStats.successful,
        successRate: overallStats.total > 0
          ? Math.round((overallStats.successful / overallStats.total) * 100)
          : 0,
        avgDurationSeconds: Math.round(overallStats.avgDuration / 1000),
        avgMessageCount: Math.round(overallStats.avgMessages * 10) / 10,
        avgToolCalls: Math.round(overallStats.avgToolCalls * 10) / 10,
      },
      outcomeBreakdown: outcomeBreakdown.reduce((acc, item) => {
        acc[item._id] = item.count;
        return acc;
      }, {} as Record<string, number>),
      topToolsUsed: toolUsage.map(t => ({
        tool: t._id,
        count: t.count,
      })),
    });
  } catch (error: any) {
    console.error('[chat/analytics] Error:', error);
    return res.status(500).json({
      error: 'Failed to fetch analytics',
      message: error.message,
    });
  }
});

export default router;
