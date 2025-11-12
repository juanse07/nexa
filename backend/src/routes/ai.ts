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
      venues: ((manager as any).venueList || []).map((venue: any) => ({
        name: venue.name,
        address: venue.address,
        city: venue.city,
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
        totalVenues: ((manager as any).venueList || []).length,
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
 * Accepts audio file upload and returns transcribed text
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

    // Minimal domain prompt for faster transcription
    const domainPrompt = 'event staffing: server bartender captain chef venue client';
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
    description: 'Search venue addresses from existing events in the database. Use this when users ask about addresses, venues, or locations.',
    parameters: {
      type: 'object',
      properties: {
        query: {
          type: 'string',
          description: 'Search query - can be venue name, address, city, or any location-related term'
        },
        client_name: {
          type: ['string', 'null'],
          description: 'Optional: Filter results by client name'
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
    description: 'Create a new staffing shift. IMPORTANT: Managers only care about CALL TIME (when staff should arrive), NOT guest arrival time. Call time is the staff arrival time.',
    parameters: {
      type: 'object',
      properties: {
        client_name: {
          type: 'string',
          description: 'Name of the client/company'
        },
        date: {
          type: 'string',
          description: 'Shift date in ISO format (YYYY-MM-DD)'
        },
        call_time: {
          type: 'string',
          description: 'CALL TIME - when staff should ARRIVE (e.g., "17:00" or "5:00 PM"). This is what managers care about.'
        },
        end_time: {
          type: 'string',
          description: 'When staff shift ENDS (e.g., "23:00" or "11:00 PM")'
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

        if (events.length === 0) {
          return `No addresses found matching "${query}"${client_name ? ` for client ${client_name}` : ''}`;
        }

        const results = events.map(e =>
          `${e.venue_name || 'Unknown'} - ${e.venue_address || 'No address'}, ${e.city || 'Unknown city'} (Event: ${e.event_name}, Client: ${e.client_name}, Date: ${e.date})`
        ).join('\n');

        return `Found ${events.length} address(es):\n${results}`;
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

        // Auto-generate shift name from client and date
        const eventDate = new Date(date);
        const eventName = `${client_name} - ${eventDate.toLocaleDateString('en-US', { month: 'short', day: 'numeric' })}`;

        // Create event document
        const eventData: any = {
          managerId,
          status: 'draft',
          event_name: eventName,
          client_name,
          date: eventDate,
          start_time: call_time,  // Call time = start time (when staff arrives)
          end_time,
          city: 'Denver Metro',  // Default city
          state: 'CO',           // Default state
          roles: roles || [],
          accepted_staff: [],
          declined_staff: []
        };

        // Add optional fields
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

  // TEMPORARY: Force GPT-OSS only (skip Llama)
  const groqModel = 'openai/gpt-oss-20b';
  const isReasoningModel = true;

  console.log(`[Groq] Manager FORCING GPT-OSS model: ${groqModel} (Llama fallback disabled)`);

  // Optimize prompt structure for caching: static content first (cached), dynamic last
  const dateContext = getFullSystemContext(timezone);

  const languageInstructions = `
🌍 LANGUAGE RULE - CRITICAL:
ALWAYS respond in the SAME LANGUAGE the user is speaking.
- If user writes in Spanish → respond in Spanish
- If user writes in English → respond in English
- Match the user's language exactly, even mid-conversation
`;

  const systemContent = `${dateContext}\n\n${languageInstructions}`;

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

        // TEMPORARY: Llama fallback disabled - fail immediately with GPT-OSS errors
        console.log('[Groq] GPT-OSS failed, NO FALLBACK (Llama fallback temporarily disabled)');

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

    // Smart merge for multi-city support:
    // 1. Keep ALL venues from OTHER cities (preserve other cities' venues)
    const existingVenues = manager.venueList || [];
    const venuesFromOtherCities = existingVenues.filter((v: any) =>
      v.cityName && v.cityName !== city
    );

    // 2. Keep manual venues from THIS city
    const manualVenuesThisCity = existingVenues
      .filter((v: any) => v.cityName === city && v.source === 'manual');

    console.log(`[discover-venues] Preserving ${venuesFromOtherCities.length} venues from other cities`);
    console.log(`[discover-venues] Preserving ${manualVenuesThisCity.length} manual venues from ${city}`);

    // 3. Add new AI venues for THIS city
    const aiVenues = validatedVenues.map(v => ({ ...v, source: 'ai' as const }));

    // 4. Remove duplicate AI venues (case-insensitive name match)
    const manualNames = new Set(manualVenuesThisCity.map((v: any) => v.name.toLowerCase().trim()));
    const uniqueAIVenues = aiVenues.filter((v: any) => !manualNames.has(v.name.toLowerCase().trim()));
    console.log(`[discover-venues] Adding ${uniqueAIVenues.length} unique AI venues for ${city} (${aiVenues.length - uniqueAIVenues.length} duplicates removed)`);

    // 5. Combine all venues: other cities + this city's manual + this city's AI
    const finalVenues = [
      ...venuesFromOtherCities,
      ...manualVenuesThisCity,
      ...uniqueAIVenues
    ];

    console.log(`[discover-venues] Total venues after update: ${finalVenues.length} (${venuesFromOtherCities.length} from other cities, ${manualVenuesThisCity.length} manual + ${uniqueAIVenues.length} AI from ${city})`);

    // Save with retry logic for version conflicts
    let retries = 3;
    let saved = false;
    let lastError: any = null;

    while (retries > 0 && !saved) {
      try {
        // Refresh manager document to get latest version
        const freshManager = await ManagerModel.findOne({
          provider: (req as any).authUser.provider,
          subject: (req as any).authUser.sub,
        });

        if (!freshManager) {
          return res.status(404).json({ message: 'Manager not found' });
        }

        // Update only venueList and timestamp (NOT preferredCity - it's deprecated)
        freshManager.venueList = finalVenues;
        freshManager.venueListUpdatedAt = new Date();
        await freshManager.save();

        saved = true;
        console.log(`[discover-venues] Successfully saved venues`);
      } catch (saveError: any) {
        lastError = saveError;
        if (saveError.name === 'VersionError' && retries > 1) {
          console.log(`[discover-venues] Version conflict, retrying... (${retries - 1} retries left)`);
          retries--;
          // Wait a bit before retrying (exponential backoff)
          await new Promise(resolve => setTimeout(resolve, 100 * (4 - retries)));
        } else {
          retries = 0;
        }
      }
    }

    if (!saved) {
      console.error('[discover-venues] Failed to save after retries:', lastError);
      return res.status(500).json({
        message: 'Failed to save venues due to concurrent updates. Please try again.',
        error: lastError?.message
      });
    }

    return res.json({
      success: true,
      city,
      venueCount: validatedVenues.length,
      venues: validatedVenues,
      updatedAt: manager.venueListUpdatedAt,
    });

  } catch (error: any) {
    console.error('[discover-venues] Error:', error);
    return res.status(500).json({
      message: 'Failed to discover venues',
      error: error.message
    });
  }
});

export default router;
