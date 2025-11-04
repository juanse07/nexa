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
      .select('email first_name last_name name')
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
        name: manager.name || 'Manager'
      },
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
    formData.append('model', 'whisper-large-v3');

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
          type: 'string',
          description: 'Optional currency code (defaults to USD)'
        }
      },
      required: ['client_name', 'role_name', 'rate']
    }
  },
  {
    name: 'create_event',
    description: 'Create a new staffing event. IMPORTANT: Managers only care about CALL TIME (when staff should arrive), NOT guest arrival time. Call time is the staff arrival time.',
    parameters: {
      type: 'object',
      properties: {
        client_name: {
          type: 'string',
          description: 'Name of the client/company'
        },
        date: {
          type: 'string',
          description: 'Event date in ISO format (YYYY-MM-DD)'
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
          type: 'string',
          description: 'Name of the venue/location'
        },
        venue_address: {
          type: 'string',
          description: 'Full street address of the venue'
        },
        roles: {
          type: 'array',
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
          type: 'string',
          description: 'Dress code/uniform requirements (optional)'
        },
        notes: {
          type: 'string',
          description: 'Additional details, instructions, event name if needed, special requirements'
        },
        contact_name: {
          type: 'string',
          description: 'On-site contact person name'
        },
        contact_phone: {
          type: 'string',
          description: 'On-site contact phone number'
        },
        headcount_total: {
          type: 'number',
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

      case 'search_events': {
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
          return 'No events found matching the criteria';
        }

        const results = events.map(e =>
          `${e.event_name} - Client: ${e.client_name}, Date: ${e.date}, Venue: ${e.venue_name || 'TBD'}, Status: ${e.status || 'pending'}`
        ).join('\n');

        return `Found ${events.length} event(s):\n${results}`;
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

      case 'create_event': {
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

        // Auto-generate event name from client and date
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

    // Get managerId from authenticated user
    const managerId = (req as any).user?._id || (req as any).user?.managerId;
    if (!managerId) {
      return res.status(401).json({ message: 'Manager not found' });
    }

    // Detect user's timezone from IP
    const timezone = getTimezoneFromRequest(req);

    if (provider === 'claude') {
      return await handleClaudeRequest(messages, temperature, maxTokens, res, timezone, managerId);
    } else if (provider === 'groq') {
      return await handleGroqRequest(messages, temperature, maxTokens, res, timezone, model, managerId);
    } else {
      return await handleOpenAIRequest(messages, temperature, maxTokens, res, timezone, managerId);
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
  timezone?: string,
  managerId?: mongoose.Types.ObjectId
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

    // Execute the function call
    const toolCall = toolCalls[0];
    const functionName = toolCall.function?.name;
    const functionArgs = JSON.parse(toolCall.function?.arguments || '{}');

    console.log('[OpenAI] Executing function:', functionName, functionArgs);

    // Execute the function call
    if (!managerId) {
      return res.status(401).json({ message: 'Manager ID required for function calls' });
    }

    const toolResponse = await executeFunctionCall(functionName, functionArgs, managerId);

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
  timezone?: string,
  managerId?: mongoose.Types.ObjectId
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

    console.log('[Claude] Executing function:', toolName, toolInput);

    // Execute the function call
    if (!managerId) {
      return res.status(401).json({ message: 'Manager ID required for function calls' });
    }

    const toolResponse = await executeFunctionCall(toolName, toolInput, managerId);

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
  model?: string,
  managerId?: mongoose.Types.ObjectId
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

    console.log(`[Groq] Using model: ${groqModel} with ${useResponsesAPI ? 'Responses' : 'Chat Completions'} API`);

    // Build messages with date context
    const dateContext = getFullSystemContext(timezone);
    const processedMessages: any[] = [];

    let hasSystemMessage = false;
    for (const msg of messages) {
      if (msg.role === 'system') {
        processedMessages.push({
          role: 'system',
          content: `${dateContext}\n\n${msg.content}`
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
        content: dateContext
      });
    }

    // Build tools array based on API type
    let groqTools: any[];
    if (useResponsesAPI) {
      // Responses API: flat structure
      groqTools = AI_TOOLS.map(tool => ({
        type: 'function',
        name: tool.name,
        description: tool.description,
        parameters: tool.parameters
      }));
    } else {
      // Chat Completions API: nested structure
      groqTools = AI_TOOLS.map(tool => ({
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
      // GPT-OSS uses reasoning mode which needs more tokens
      const adjustedMaxTokens = maxTokens * 3; // Triple for reasoning overhead
      requestBody = {
        model: groqModel,
        input: processedMessages,
        temperature,
        max_output_tokens: adjustedMaxTokens,
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
      console.error('[Groq] API error:', response.status, JSON.stringify(response.data));
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

        if (!managerId) {
          return res.status(401).json({ message: 'Manager ID required for function calls' });
        }

        const toolResponse = await executeFunctionCall(functionName, functionArgs, managerId);

        // Second request for Responses API
        const messagesWithFunctionResult = [
          ...processedMessages,
          { role: 'assistant', content: functionCallBlock.text || '' },
          { role: 'user', content: `Function ${functionName} returned: ${toolResponse}\n\nPlease present this naturally.` }
        ];

        const secondResponse = await axios.post(
          `${groqBaseUrl}${apiEndpoint}`,
          {
            model: groqModel,
            input: messagesWithFunctionResult,
            temperature,
            max_output_tokens: maxTokens * 3, // GPT-OSS reasoning mode needs more tokens
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
      console.log('[Groq] Output blocks structure:', JSON.stringify(outputBlocks, null, 2));

      const messageBlock = outputBlocks.find((block: any) => block.type === 'message');
      console.log('[Groq] Message block:', JSON.stringify(messageBlock, null, 2));

      const textContent = messageBlock?.content?.find((item: any) => item.type === 'output_text');
      const content = textContent?.text;

      if (!content) {
        console.error('[Groq] No text content found. messageBlock:', messageBlock, 'textContent:', textContent);
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

        if (!managerId) {
          return res.status(401).json({ message: 'Manager ID required for function calls' });
        }

        const toolResponse = await executeFunctionCall(functionName, functionArgs, managerId);

        // Second request for Chat Completions API
        const messagesWithToolResult = [
          ...processedMessages,
          assistantMessage,
          {
            role: 'tool',
            tool_call_id: toolCall.id,
            content: toolResponse
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
          toolCall: { name: functionName, arguments: functionArgs }
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
