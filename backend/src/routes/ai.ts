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
import { ConversationModel } from '../models/conversation';
import { ChatMessageModel } from '../models/chatMessage';
import { FlaggedAttendanceModel } from '../models/flaggedAttendance';
import { UserModel } from '../models/user';
import { TeamModel } from '../models/team';
import { emitToManager, emitToTeams, emitToUser } from '../socket/server';
import { notificationService } from '../services/notificationService';
import { computeRoleStats } from '../utils/eventCapacity';

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
    name: 'delete_client',
    description: 'Delete a client from the manager\'s account. Use this when the manager wants to remove a client, especially duplicate or mistakenly created clients. WARNING: This will also delete all tariffs associated with this client.',
    parameters: {
      type: 'object',
      properties: {
        client_name: {
          type: 'string',
          description: 'The exact name of the client to delete'
        }
      },
      required: ['client_name']
    }
  },
  {
    name: 'merge_clients',
    description: 'Merge two clients by transferring all events and tariffs from the source client to the target client, then deleting the source. Use this to clean up duplicate clients (e.g., "serenpety" typo should be merged into "Serendipity").',
    parameters: {
      type: 'object',
      properties: {
        source_client_name: {
          type: 'string',
          description: 'The name of the client to merge FROM (this one will be deleted after merge)'
        },
        target_client_name: {
          type: 'string',
          description: 'The name of the client to merge INTO (this one will be kept)'
        }
      },
      required: ['source_client_name', 'target_client_name']
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
    name: 'delete_role',
    description: 'Delete a role/position type from the manager\'s account. Use this when the manager wants to remove a role, especially duplicate or unused roles. WARNING: This will also delete all tariffs associated with this role.',
    parameters: {
      type: 'object',
      properties: {
        role_name: {
          type: 'string',
          description: 'The exact name of the role to delete'
        }
      },
      required: ['role_name']
    }
  },
  {
    name: 'merge_roles',
    description: 'Merge two roles by transferring all tariffs from the source role to the target role, then deleting the source. Use this to clean up duplicate roles (e.g., "server" typo should be merged into "Server").',
    parameters: {
      type: 'object',
      properties: {
        source_role_name: {
          type: 'string',
          description: 'The name of the role to merge FROM (this one will be deleted after merge)'
        },
        target_role_name: {
          type: 'string',
          description: 'The name of the role to merge INTO (this one will be kept)'
        }
      },
      required: ['source_role_name', 'target_role_name']
    }
  },
  {
    name: 'delete_tariff',
    description: 'Delete a specific tariff/pricing rate for a client-role combination. Use this when the manager wants to remove a pricing rate.',
    parameters: {
      type: 'object',
      properties: {
        client_name: {
          type: 'string',
          description: 'The name of the client'
        },
        role_name: {
          type: 'string',
          description: 'The name of the role'
        }
      },
      required: ['client_name', 'role_name']
    }
  },
  {
    name: 'get_roles_list',
    description: 'Get the list of all roles/position types in the manager\'s account. Use this when the user asks about roles, wants to see all roles, or needs to reference role names.',
    parameters: {
      type: 'object',
      properties: {},
      required: []
    }
  },
  {
    name: 'get_tariffs_list',
    description: 'Get the list of all tariffs/pricing rates in the manager\'s account. Shows which roles have rates set for which clients.',
    parameters: {
      type: 'object',
      properties: {
        client_name: {
          type: ['string', 'null'],
          description: 'Optional: Filter tariffs by specific client name'
        }
      },
      required: []
    }
  },
  // ===== STATISTICS & ANALYTICS FUNCTIONS =====
  {
    name: 'get_top_staff',
    description: 'Find top performing staff members by various metrics. Use when manager asks "who\'s my best bartender?", "top servers", "most reliable staff", etc.',
    parameters: {
      type: 'object',
      properties: {
        metric: {
          type: 'string',
          enum: ['hours_worked', 'events_completed', 'punctuality', 'points'],
          description: 'Metric to rank by: hours_worked (total hours), events_completed (number of events), punctuality (on-time rate), points (gamification)'
        },
        role_name: {
          type: ['string', 'null'],
          description: 'Optional: Filter by specific role (e.g., "Bartender", "Server")'
        },
        limit: {
          type: ['number', 'null'],
          description: 'Number of results to return (default: 5, max: 20)'
        },
        days: {
          type: ['number', 'null'],
          description: 'Time period in days (default: 30)'
        }
      },
      required: ['metric']
    }
  },
  {
    name: 'get_staff_stats',
    description: 'Get detailed statistics for a specific staff member. Use when manager asks "show me Maria\'s stats", "how many hours has John worked?", etc.',
    parameters: {
      type: 'object',
      properties: {
        staff_name: {
          type: 'string',
          description: 'Name of the staff member to look up'
        },
        days: {
          type: ['number', 'null'],
          description: 'Time period in days (default: 30)'
        }
      },
      required: ['staff_name']
    }
  },
  {
    name: 'get_staff_leaderboard',
    description: 'Get gamification leaderboard showing points, streaks, and achievements. Use when manager asks "show leaderboard", "who has the most points?", etc.',
    parameters: {
      type: 'object',
      properties: {
        limit: {
          type: ['number', 'null'],
          description: 'Number of results (default: 10)'
        }
      },
      required: []
    }
  },
  {
    name: 'get_client_stats',
    description: 'Get statistics for a specific client including events, hours, and revenue. Use when manager asks about a specific client\'s activity.',
    parameters: {
      type: 'object',
      properties: {
        client_name: {
          type: 'string',
          description: 'Name of the client'
        },
        days: {
          type: ['number', 'null'],
          description: 'Time period in days (default: 90)'
        }
      },
      required: ['client_name']
    }
  },
  {
    name: 'get_top_clients',
    description: 'Find top clients by various metrics. Use when manager asks "who\'s my biggest client?", "which client has most events?", etc.',
    parameters: {
      type: 'object',
      properties: {
        metric: {
          type: 'string',
          enum: ['events', 'hours', 'revenue', 'staff_used'],
          description: 'Metric to rank by'
        },
        limit: {
          type: ['number', 'null'],
          description: 'Number of results (default: 5)'
        },
        days: {
          type: ['number', 'null'],
          description: 'Time period in days (default: 90)'
        }
      },
      required: ['metric']
    }
  },
  {
    name: 'get_revenue_summary',
    description: 'Calculate revenue/billing metrics using approved hours and tariff rates. Use when manager asks "what\'s my revenue?", "billing summary", etc.',
    parameters: {
      type: 'object',
      properties: {
        group_by: {
          type: 'string',
          enum: ['client', 'role', 'month', 'week'],
          description: 'How to group the revenue breakdown'
        },
        client_name: {
          type: ['string', 'null'],
          description: 'Optional: Filter by specific client'
        },
        days: {
          type: ['number', 'null'],
          description: 'Time period in days (default: 30)'
        }
      },
      required: ['group_by']
    }
  },
  {
    name: 'get_billing_status',
    description: 'Get hours approval status breakdown. Use when manager asks "pending hours?", "hours to approve?", "billing status?", etc.',
    parameters: {
      type: 'object',
      properties: {
        days: {
          type: ['number', 'null'],
          description: 'Time period in days (default: 30)'
        }
      },
      required: []
    }
  },
  {
    name: 'get_role_demand',
    description: 'Show which roles are most in-demand. Use when manager asks "most requested role?", "role demand?", etc.',
    parameters: {
      type: 'object',
      properties: {
        limit: {
          type: ['number', 'null'],
          description: 'Number of results (default: 10)'
        },
        days: {
          type: ['number', 'null'],
          description: 'Time period in days (default: 30)'
        }
      },
      required: []
    }
  },
  {
    name: 'get_event_summary',
    description: 'Get overview of event activity. Use when manager asks "event summary", "how many events?", "event stats?", etc.',
    parameters: {
      type: 'object',
      properties: {
        days: {
          type: ['number', 'null'],
          description: 'Time period in days (default: 30)'
        },
        status: {
          type: ['string', 'null'],
          description: 'Optional: Filter by status (draft, published, completed, cancelled)'
        }
      },
      required: []
    }
  },
  {
    name: 'get_busy_periods',
    description: 'Identify peak times for scheduling. Use when manager asks "busiest day?", "when do I have most events?", etc.',
    parameters: {
      type: 'object',
      properties: {
        group_by: {
          type: 'string',
          enum: ['day_of_week', 'month'],
          description: 'How to group: day_of_week (Mon-Sun) or month'
        },
        days: {
          type: ['number', 'null'],
          description: 'Time period in days (default: 90)'
        }
      },
      required: ['group_by']
    }
  },
  {
    name: 'get_attendance_issues',
    description: 'Get summary of attendance flags/anomalies needing review. Use when manager asks "attendance issues?", "any flags?", etc.',
    parameters: {
      type: 'object',
      properties: {
        days: {
          type: ['number', 'null'],
          description: 'Time period in days (default: 30)'
        },
        status: {
          type: ['string', 'null'],
          description: 'Filter by status: pending (default), all'
        }
      },
      required: []
    }
  },
  {
    name: 'create_event',
    description: 'Create a new event/shift as DRAFT (crear evento/turno). Use when user wants to: create event, make shift, add job, schedule staff, create trabajo, crear evento, agendar personal. IMPORTANT: Managers only care about CALL TIME (when staff should arrive), NOT guest arrival time. Call time is the staff arrival time. 🚨 CRITICAL: ALL EVENTS MUST BE IN THE FUTURE - never create events for past dates. After creating, ALWAYS ask the user if they want to publish it to staff.',
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
    name: 'create_events_bulk',
    description: 'Create multiple events/shifts at once as DRAFTS (max 30). Use for recurring patterns like "every Saturday in March", "3 shifts next week", etc. After creating, offer to publish all with publish_events_bulk.',
    parameters: {
      type: 'object',
      properties: {
        events: {
          type: 'array',
          description: 'Array of event objects (same fields as create_event)',
          items: {
            type: 'object',
            properties: {
              client_name: { type: 'string' },
              date: { type: 'string', description: 'YYYY-MM-DD' },
              call_time: { type: 'string', description: '24h format HH:MM' },
              end_time: { type: 'string', description: '24h format HH:MM' },
              venue_name: { type: ['string', 'null'] },
              venue_address: { type: ['string', 'null'] },
              roles: {
                type: 'array',
                items: {
                  type: 'object',
                  properties: {
                    role: { type: 'string' },
                    count: { type: 'number' }
                  }
                }
              },
              uniform: { type: ['string', 'null'] },
              notes: { type: ['string', 'null'] },
              contact_name: { type: ['string', 'null'] },
              contact_phone: { type: ['string', 'null'] },
              headcount_total: { type: ['number', 'null'] }
            }
          }
        }
      },
      required: ['events']
    }
  },
  {
    name: 'publish_event',
    description: 'Publish a draft event to all staff teams. Sends push notifications. Use after create_event when user confirms they want to publish. Requires event_id from create_event result.',
    parameters: {
      type: 'object',
      properties: {
        event_id: {
          type: 'string',
          description: 'The event ID returned by create_event'
        }
      },
      required: ['event_id']
    }
  },
  {
    name: 'publish_events_bulk',
    description: 'Publish multiple draft events at once. Use after create_events_bulk when user confirms. Partial success is OK — returns per-event results.',
    parameters: {
      type: 'object',
      properties: {
        event_ids: {
          type: 'array',
          description: 'Array of event IDs to publish',
          items: { type: 'string' }
        }
      },
      required: ['event_ids']
    }
  },
  {
    name: 'get_teams',
    description: 'Get list of manager\'s teams. Use when you need to know which teams the manager has, or for context about publishing.',
    parameters: {
      type: 'object',
      properties: {},
      required: []
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
    description: 'Get list of all active team members/staff with their names and emails. Use this when user asks about team, staff, who is on the team, or needs to find a specific member.',
    parameters: {
      type: 'object',
      properties: {
        name_filter: {
          type: ['string', 'null'],
          description: 'Optional: Filter by name (partial match, case-insensitive)'
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
  },
  {
    name: 'send_message_to_staff',
    description: 'Send a chat message to a specific team member. Use when manager says "message Juan", "tell Maria she\'s confirmed", "let Alex know about the shift change", etc. Use get_team_members first if you need to find the person\'s name.',
    parameters: {
      type: 'object',
      properties: {
        staff_name: {
          type: 'string',
          description: 'Name of the staff member to message (first name, last name, or full name)'
        },
        message: {
          type: 'string',
          description: 'The message to send'
        }
      },
      required: ['staff_name', 'message']
    }
  },
  {
    name: 'send_message_to_all_staff',
    description: 'Send a message to ALL active team members at once (bulk broadcast). Use when manager says "tell everyone", "notify all staff", "send a message to the whole team", etc. WARNING: This sends to every active team member.',
    parameters: {
      type: 'object',
      properties: {
        message: {
          type: 'string',
          description: 'The message to broadcast to all team members'
        }
      },
      required: ['message']
    }
  },
  {
    name: 'update_event',
    description: 'Update an existing event/shift. Use when user wants to modify event details (venue, date, time, roles, notes, etc.). REQUIRES event_id - get it from search_shifts first. Only include fields that need to change.',
    parameters: {
      type: 'object',
      properties: {
        event_id: {
          type: 'string',
          description: 'The event ID (from search_shifts results). Required to identify which event to update.'
        },
        client_name: {
          type: ['string', 'null'],
          description: 'New client name'
        },
        date: {
          type: ['string', 'null'],
          description: 'New date in ISO format YYYY-MM-DD'
        },
        call_time: {
          type: ['string', 'null'],
          description: 'New call time in 24h format (e.g., "16:00")'
        },
        end_time: {
          type: ['string', 'null'],
          description: 'New end time in 24h format (e.g., "23:00")'
        },
        venue_name: {
          type: ['string', 'null'],
          description: 'New venue name'
        },
        venue_address: {
          type: ['string', 'null'],
          description: 'New venue address'
        },
        roles: {
          type: ['array', 'null'],
          description: 'New staff roles (replaces existing roles)',
          items: {
            type: 'object',
            properties: {
              role: { type: 'string' },
              count: { type: 'number' }
            }
          }
        },
        uniform: {
          type: ['string', 'null'],
          description: 'New uniform/dress code'
        },
        notes: {
          type: ['string', 'null'],
          description: 'New notes/instructions'
        },
        contact_name: {
          type: ['string', 'null'],
          description: 'New contact person name'
        },
        contact_phone: {
          type: ['string', 'null'],
          description: 'New contact phone number'
        },
        headcount_total: {
          type: ['number', 'null'],
          description: 'New guest headcount'
        }
      },
      required: ['event_id']
    }
  }
];

/**
 * Send a chat message from a manager to a staff member
 * Reusable helper for both individual and bulk messaging
 */
async function sendManagerMessage(
  managerId: mongoose.Types.ObjectId,
  targetUserKey: string,
  senderName: string,
  senderPicture: string | null,
  message: string
): Promise<{ success: boolean; conversationId?: string; error?: string }> {
  try {
    // Find or create conversation
    const conversation = await ConversationModel.findOneAndUpdate(
      { managerId, userKey: targetUserKey },
      { $setOnInsert: { managerId, userKey: targetUserKey } },
      { upsert: true, new: true }
    );

    // Create chat message
    const chatMessage = await ChatMessageModel.create({
      conversationId: conversation._id,
      managerId,
      userKey: targetUserKey,
      senderType: 'manager',
      senderName,
      senderPicture,
      message,
      messageType: 'text',
      readByManager: true,
      readByUser: false,
    });

    // Update conversation metadata
    await ConversationModel.findByIdAndUpdate(conversation._id, {
      lastMessageAt: chatMessage.createdAt,
      lastMessagePreview: message.substring(0, 200),
      $inc: { unreadCountUser: 1 }
    });

    // Emit real-time socket notification
    const messagePayload = {
      id: String(chatMessage._id),
      conversationId: String(conversation._id),
      senderType: 'manager',
      senderName,
      senderPicture,
      message: chatMessage.message,
      messageType: 'text',
      readByManager: true,
      readByUser: false,
      createdAt: chatMessage.createdAt,
    };
    emitToUser(targetUserKey, 'chat:message', messagePayload);

    // Send push notification
    const user = await UserModel.findOne({
      $expr: {
        $eq: [
          { $concat: ['$provider', ':', '$subject'] },
          targetUserKey
        ]
      }
    });
    if (user) {
      const notifBody = message.length > 100 ? message.substring(0, 100) + '...' : message;
      await notificationService.sendToUser(
        (user._id as any).toString(),
        senderName,
        notifBody,
        {
          type: 'chat',
          conversationId: String(conversation._id),
          messageId: String(chatMessage._id),
          senderName,
          managerId: managerId.toString()
        },
        'user'
      );
    }

    return { success: true, conversationId: String(conversation._id) };
  } catch (error: any) {
    console.error('[sendManagerMessage] Error:', error);
    return { success: false, error: error.message };
  }
}

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
          `[ID: ${e._id}] ${e.event_name || e.shift_name || 'Unnamed'} - Client: ${e.client_name}, Date: ${e.date}, Venue: ${e.venue_name || 'TBD'}, Status: ${e.status || 'pending'}`
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

      case 'delete_client': {
        const { client_name } = functionArgs;

        // Find client by name (case-insensitive)
        const client = await ClientModel.findOne({
          managerId,
          normalizedName: client_name.toLowerCase()
        }).lean();

        if (!client) {
          return `❌ Client "${client_name}" not found. Please check the spelling and try again.`;
        }

        // Check if client has events associated
        const eventCount = await EventModel.countDocuments({
          managerId,
          client_name: new RegExp(`^${client.name}$`, 'i')
        });

        // Delete associated tariffs first
        const deletedTariffs = await TariffModel.deleteMany({
          managerId,
          clientId: client._id
        });

        // Delete the client
        await ClientModel.deleteOne({ _id: client._id });

        let result = `✅ Successfully deleted client "${client.name}"`;
        if (deletedTariffs.deletedCount > 0) {
          result += `\n   Also removed ${deletedTariffs.deletedCount} associated tariff(s)`;
        }
        if (eventCount > 0) {
          result += `\n   ⚠️ Note: ${eventCount} event(s) still reference this client name`;
        }

        return result;
      }

      case 'merge_clients': {
        const { source_client_name, target_client_name } = functionArgs;

        // Find source client (the one to be merged and deleted)
        const sourceClient = await ClientModel.findOne({
          managerId,
          normalizedName: source_client_name.toLowerCase()
        }).lean();

        if (!sourceClient) {
          return `❌ Source client "${source_client_name}" not found. Please check the spelling.`;
        }

        // Find target client (the one to keep)
        const targetClient = await ClientModel.findOne({
          managerId,
          normalizedName: target_client_name.toLowerCase()
        }).lean();

        if (!targetClient) {
          return `❌ Target client "${target_client_name}" not found. Please check the spelling.`;
        }

        if (sourceClient._id.toString() === targetClient._id.toString()) {
          return `❌ Cannot merge a client with itself. Please specify two different clients.`;
        }

        // Transfer events from source to target
        const eventsUpdated = await EventModel.updateMany(
          {
            managerId,
            client_name: new RegExp(`^${sourceClient.name}$`, 'i')
          },
          {
            $set: { client_name: targetClient.name }
          }
        );

        // Transfer tariffs from source to target (if they don't already exist for target)
        const sourceTariffs = await TariffModel.find({
          managerId,
          clientId: sourceClient._id
        }).lean();

        let tariffsTransferred = 0;
        for (const tariff of sourceTariffs) {
          // Check if target already has this tariff
          const existingTariff = await TariffModel.findOne({
            managerId,
            clientId: targetClient._id,
            roleId: tariff.roleId
          }).lean();

          if (!existingTariff) {
            // Transfer tariff to target client
            await TariffModel.create({
              managerId,
              clientId: targetClient._id,
              roleId: tariff.roleId,
              rate: tariff.rate,
              currency: tariff.currency
            });
            tariffsTransferred++;
          }
        }

        // Delete source client's tariffs
        await TariffModel.deleteMany({
          managerId,
          clientId: sourceClient._id
        });

        // Delete source client
        await ClientModel.deleteOne({ _id: sourceClient._id });

        let result = `✅ Successfully merged "${sourceClient.name}" into "${targetClient.name}"`;
        if (eventsUpdated.modifiedCount > 0) {
          result += `\n   📋 ${eventsUpdated.modifiedCount} event(s) transferred`;
        }
        if (tariffsTransferred > 0) {
          result += `\n   💰 ${tariffsTransferred} tariff(s) transferred`;
        }
        result += `\n   🗑️ "${sourceClient.name}" has been deleted`;

        return result;
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

      case 'delete_role': {
        const { role_name } = functionArgs;

        // Find role by name (case-insensitive)
        const role = await RoleModel.findOne({
          managerId,
          normalizedName: role_name.toLowerCase()
        }).lean();

        if (!role) {
          return `❌ Role "${role_name}" not found. Please check the spelling and try again.`;
        }

        // Check if role is used in any events
        const eventsWithRole = await EventModel.countDocuments({
          managerId,
          'roles.role': new RegExp(`^${role.name}$`, 'i')
        });

        // Delete associated tariffs first
        const deletedTariffs = await TariffModel.deleteMany({
          managerId,
          roleId: role._id
        });

        // Delete the role
        await RoleModel.deleteOne({ _id: role._id });

        let result = `✅ Successfully deleted role "${role.name}"`;
        if (deletedTariffs.deletedCount > 0) {
          result += `\n   Also removed ${deletedTariffs.deletedCount} associated tariff(s)`;
        }
        if (eventsWithRole > 0) {
          result += `\n   ⚠️ Note: ${eventsWithRole} event(s) still reference this role`;
        }

        return result;
      }

      case 'merge_roles': {
        const { source_role_name, target_role_name } = functionArgs;

        // Find source role (the one to be merged and deleted)
        const sourceRole = await RoleModel.findOne({
          managerId,
          normalizedName: source_role_name.toLowerCase()
        }).lean();

        if (!sourceRole) {
          return `❌ Source role "${source_role_name}" not found. Please check the spelling.`;
        }

        // Find target role (the one to keep)
        const targetRole = await RoleModel.findOne({
          managerId,
          normalizedName: target_role_name.toLowerCase()
        }).lean();

        if (!targetRole) {
          return `❌ Target role "${target_role_name}" not found. Please check the spelling.`;
        }

        if (sourceRole._id.toString() === targetRole._id.toString()) {
          return `❌ Cannot merge a role with itself. Please specify two different roles.`;
        }

        // Update events to use target role instead of source
        const eventsUpdated = await EventModel.updateMany(
          {
            managerId,
            'roles.role': new RegExp(`^${sourceRole.name}$`, 'i')
          },
          {
            $set: { 'roles.$[elem].role': targetRole.name }
          },
          {
            arrayFilters: [{ 'elem.role': new RegExp(`^${sourceRole.name}$`, 'i') }]
          }
        );

        // Transfer tariffs from source to target (if they don't already exist for target)
        const sourceTariffs = await TariffModel.find({
          managerId,
          roleId: sourceRole._id
        }).lean();

        let tariffsTransferred = 0;
        for (const tariff of sourceTariffs) {
          // Check if target already has this tariff for the same client
          const existingTariff = await TariffModel.findOne({
            managerId,
            clientId: tariff.clientId,
            roleId: targetRole._id
          }).lean();

          if (!existingTariff) {
            // Transfer tariff to target role
            await TariffModel.create({
              managerId,
              clientId: tariff.clientId,
              roleId: targetRole._id,
              rate: tariff.rate,
              currency: tariff.currency
            });
            tariffsTransferred++;
          }
        }

        // Delete source role's tariffs
        await TariffModel.deleteMany({
          managerId,
          roleId: sourceRole._id
        });

        // Delete source role
        await RoleModel.deleteOne({ _id: sourceRole._id });

        let result = `✅ Successfully merged "${sourceRole.name}" into "${targetRole.name}"`;
        if (eventsUpdated.modifiedCount > 0) {
          result += `\n   📋 ${eventsUpdated.modifiedCount} event(s) updated`;
        }
        if (tariffsTransferred > 0) {
          result += `\n   💰 ${tariffsTransferred} tariff(s) transferred`;
        }
        result += `\n   🗑️ "${sourceRole.name}" has been deleted`;

        return result;
      }

      case 'delete_tariff': {
        const { client_name, role_name } = functionArgs;

        // Find client
        const client = await ClientModel.findOne({
          managerId,
          normalizedName: client_name.toLowerCase()
        }).lean();

        if (!client) {
          return `❌ Client "${client_name}" not found.`;
        }

        // Find role
        const role = await RoleModel.findOne({
          managerId,
          normalizedName: role_name.toLowerCase()
        }).lean();

        if (!role) {
          return `❌ Role "${role_name}" not found.`;
        }

        // Find and delete the tariff
        const deletedTariff = await TariffModel.findOneAndDelete({
          managerId,
          clientId: client._id,
          roleId: role._id
        }).lean();

        if (!deletedTariff) {
          return `❌ No tariff found for ${client_name} - ${role_name}. Nothing to delete.`;
        }

        return `✅ Successfully deleted tariff for ${client.name} - ${role.name} (was $${deletedTariff.rate} ${deletedTariff.currency}/hour)`;
      }

      case 'get_roles_list': {
        const roles = await RoleModel.find({ managerId })
          .select('name')
          .sort({ name: 1 })
          .lean();

        if (roles.length === 0) {
          return 'No roles found in your account. You can create roles as needed.';
        }

        const roleList = roles.map(r => r.name).join(', ');
        return `You have ${roles.length} role(s): ${roleList}`;
      }

      case 'get_tariffs_list': {
        const { client_name } = functionArgs;

        let filter: any = { managerId };

        // If client_name provided, filter by client
        if (client_name) {
          const client = await ClientModel.findOne({
            managerId,
            normalizedName: client_name.toLowerCase()
          }).lean();

          if (!client) {
            return `❌ Client "${client_name}" not found.`;
          }
          filter.clientId = client._id;
        }

        const tariffs = await TariffModel.find(filter)
          .populate('clientId', 'name')
          .populate('roleId', 'name')
          .sort({ 'clientId.name': 1, 'roleId.name': 1 })
          .lean();

        if (tariffs.length === 0) {
          if (client_name) {
            return `No tariffs found for client "${client_name}".`;
          }
          return 'No tariffs found in your account. You can create tariffs using create_tariff.';
        }

        const tariffList = tariffs.map(t => {
          const clientName = (t.clientId as any)?.name || 'Unknown';
          const roleName = (t.roleId as any)?.name || 'Unknown';
          return `${clientName} - ${roleName}: $${t.rate} ${t.currency}/hour`;
        }).join('\n');

        return `You have ${tariffs.length} tariff(s):\n${tariffList}`;
      }

      // ===== STATISTICS & ANALYTICS HANDLERS =====

      case 'get_top_staff': {
        const { metric, role_name, limit = 5, days = 30 } = functionArgs;
        const startDate = new Date();
        startDate.setDate(startDate.getDate() - days);
        const maxLimit = Math.min(limit, 20);

        // Build match filter
        const matchFilter: any = {
          managerId,
          date: { $gte: startDate },
          status: { $in: ['completed', 'fulfilled', 'in_progress'] }
        };

        if (role_name) {
          matchFilter['accepted_staff.role'] = new RegExp(role_name, 'i');
        }

        if (metric === 'hours_worked') {
          const results = await EventModel.aggregate([
            { $match: matchFilter },
            { $unwind: '$accepted_staff' },
            ...(role_name ? [{ $match: { 'accepted_staff.role': new RegExp(role_name, 'i') } }] : []),
            { $unwind: { path: '$accepted_staff.attendance', preserveNullAndEmptyArrays: true } },
            {
              $group: {
                _id: '$accepted_staff.userKey',
                name: { $first: '$accepted_staff.name' },
                totalHours: { $sum: { $ifNull: ['$accepted_staff.attendance.approvedHours', '$accepted_staff.attendance.estimatedHours'] } },
                eventsCount: { $addToSet: '$_id' }
              }
            },
            { $addFields: { eventCount: { $size: '$eventsCount' } } },
            { $sort: { totalHours: -1 } },
            { $limit: maxLimit }
          ]);

          if (results.length === 0) {
            return `No staff data found for the last ${days} days${role_name ? ` with role "${role_name}"` : ''}.`;
          }

          const list = results.map((r, i) =>
            `${i + 1}. ${r.name || 'Unknown'} - ${r.totalHours?.toFixed(1) || 0} hours (${r.eventCount} events)`
          ).join('\n');

          return `📊 Top Staff by Hours Worked (last ${days} days)${role_name ? ` - ${role_name}` : ''}:\n${list}`;
        }

        if (metric === 'events_completed') {
          const results = await EventModel.aggregate([
            { $match: matchFilter },
            { $unwind: '$accepted_staff' },
            ...(role_name ? [{ $match: { 'accepted_staff.role': new RegExp(role_name, 'i') } }] : []),
            {
              $group: {
                _id: '$accepted_staff.userKey',
                name: { $first: '$accepted_staff.name' },
                eventCount: { $sum: 1 }
              }
            },
            { $sort: { eventCount: -1 } },
            { $limit: maxLimit }
          ]);

          if (results.length === 0) {
            return `No staff data found for the last ${days} days${role_name ? ` with role "${role_name}"` : ''}.`;
          }

          const list = results.map((r, i) =>
            `${i + 1}. ${r.name || 'Unknown'} - ${r.eventCount} events`
          ).join('\n');

          return `📊 Top Staff by Events Completed (last ${days} days)${role_name ? ` - ${role_name}` : ''}:\n${list}`;
        }

        if (metric === 'points') {
          // Get team members for this manager
          const teamMembers = await TeamMemberModel.find({ managerId, status: 'active' }).lean();
          const userKeys = teamMembers.map(tm => `${tm.provider}:${tm.subject}`);

          const users = await UserModel.find({
            userKey: { $in: userKeys },
            'gamification.totalPoints': { $gt: 0 }
          })
            .sort({ 'gamification.totalPoints': -1 })
            .limit(maxLimit)
            .lean();

          if (users.length === 0) {
            return 'No staff with gamification points found.';
          }

          const list = users.map((u: any, i) =>
            `${i + 1}. ${u.name || u.first_name || 'Unknown'} - ${u.gamification?.totalPoints || 0} pts (${u.gamification?.currentStreak || 0} day streak)`
          ).join('\n');

          return `🏆 Top Staff by Points:\n${list}`;
        }

        return `Metric "${metric}" not supported. Use: hours_worked, events_completed, or points.`;
      }

      case 'get_staff_stats': {
        const { staff_name, days = 30 } = functionArgs;
        const startDate = new Date();
        startDate.setDate(startDate.getDate() - days);

        // Find events where this staff worked
        const events = await EventModel.find({
          managerId,
          date: { $gte: startDate },
          'accepted_staff.name': new RegExp(staff_name, 'i')
        }).lean();

        if (events.length === 0) {
          return `No events found for staff member "${staff_name}" in the last ${days} days.`;
        }

        // Calculate stats
        let totalHours = 0;
        let eventCount = 0;
        const rolesWorked = new Set<string>();
        const clientsWorked = new Set<string>();

        for (const event of events) {
          const staffEntry = event.accepted_staff?.find(s =>
            s.name?.toLowerCase().includes(staff_name.toLowerCase())
          );
          if (staffEntry) {
            eventCount++;
            if (staffEntry.role) rolesWorked.add(staffEntry.role);
            if (event.client_name) clientsWorked.add(event.client_name);

            for (const attendance of staffEntry.attendance || []) {
              totalHours += attendance.approvedHours || attendance.estimatedHours || 0;
            }
          }
        }

        const avgHoursPerEvent = eventCount > 0 ? (totalHours / eventCount).toFixed(1) : 0;

        // Try to find gamification data
        let gamificationInfo = '';
        const teamMember = await TeamMemberModel.findOne({
          managerId,
          $or: [
            { name: new RegExp(staff_name, 'i') },
            { email: new RegExp(staff_name, 'i') }
          ]
        }).lean();

        if (teamMember) {
          const user = await UserModel.findOne({
            userKey: `${teamMember.provider}:${teamMember.subject}`
          }).lean();

          if ((user as any)?.gamification) {
            const gam = (user as any).gamification;
            gamificationInfo = `\n🏆 Points: ${gam.totalPoints || 0}
🔥 Current Streak: ${gam.currentStreak || 0} days
⭐ Longest Streak: ${gam.longestStreak || 0} days`;
          }
        }

        return `📊 Stats for ${staff_name} (last ${days} days):
📋 Events Worked: ${eventCount}
⏱️ Total Hours: ${totalHours.toFixed(1)}
📈 Avg Hours/Event: ${avgHoursPerEvent}
👔 Roles: ${Array.from(rolesWorked).join(', ') || 'N/A'}
🏢 Clients: ${Array.from(clientsWorked).join(', ') || 'N/A'}${gamificationInfo}`;
      }

      case 'get_staff_leaderboard': {
        const { limit = 10 } = functionArgs;
        const maxLimit = Math.min(limit, 20);

        // Get team members for this manager
        const teamMembers = await TeamMemberModel.find({ managerId, status: 'active' }).lean();
        const userKeys = teamMembers.map(tm => `${tm.provider}:${tm.subject}`);

        const users = await UserModel.find({
          userKey: { $in: userKeys }
        })
          .sort({ 'gamification.totalPoints': -1 })
          .limit(maxLimit)
          .lean();

        if (users.length === 0) {
          return 'No staff found for leaderboard.';
        }

        const medals = ['🥇', '🥈', '🥉'];
        const list = users.map((u: any, i) => {
          const medal = i < 3 ? medals[i] : `${i + 1}.`;
          const points = u.gamification?.totalPoints || 0;
          const streak = u.gamification?.currentStreak || 0;
          return `${medal} ${u.name || u.first_name || 'Unknown'} - ${points} pts${streak > 0 ? ` (🔥${streak} day streak)` : ''}`;
        }).join('\n');

        return `🏆 Staff Leaderboard:\n${list}`;
      }

      case 'get_client_stats': {
        const { client_name, days = 90 } = functionArgs;
        const startDate = new Date();
        startDate.setDate(startDate.getDate() - days);

        // Find events for this client
        const events = await EventModel.find({
          managerId,
          client_name: new RegExp(client_name, 'i'),
          date: { $gte: startDate }
        }).lean();

        if (events.length === 0) {
          return `No events found for client "${client_name}" in the last ${days} days.`;
        }

        // Calculate stats
        let totalHours = 0;
        let totalStaff = 0;
        const statusCounts: Record<string, number> = {};
        const rolesUsed = new Map<string, number>();

        for (const event of events) {
          statusCounts[event.status || 'unknown'] = (statusCounts[event.status || 'unknown'] || 0) + 1;

          for (const staff of event.accepted_staff || []) {
            totalStaff++;
            if (staff.role) {
              rolesUsed.set(staff.role, (rolesUsed.get(staff.role) || 0) + 1);
            }
            for (const attendance of staff.attendance || []) {
              totalHours += attendance.approvedHours || attendance.estimatedHours || 0;
            }
          }
        }

        // Get tariffs for revenue estimate
        const client = await ClientModel.findOne({
          managerId,
          normalizedName: client_name.toLowerCase()
        }).lean();

        let revenueEstimate = '';
        if (client) {
          const tariffs = await TariffModel.find({ managerId, clientId: client._id }).lean();
          if (tariffs.length > 0) {
            const avgRate = tariffs.reduce((sum, t) => sum + t.rate, 0) / tariffs.length;
            revenueEstimate = `\n💰 Est. Revenue: $${(totalHours * avgRate).toFixed(2)} (avg rate $${avgRate.toFixed(2)}/hr)`;
          }
        }

        const topRoles = Array.from(rolesUsed.entries())
          .sort((a, b) => b[1] - a[1])
          .slice(0, 3)
          .map(([role, count]) => `${role} (${count})`)
          .join(', ');

        return `📊 Stats for ${client_name} (last ${days} days):
📋 Total Events: ${events.length}
📈 Status: ${Object.entries(statusCounts).map(([s, c]) => `${s}: ${c}`).join(', ')}
👥 Staff Assignments: ${totalStaff}
⏱️ Total Hours: ${totalHours.toFixed(1)}
👔 Top Roles: ${topRoles || 'N/A'}${revenueEstimate}`;
      }

      case 'get_top_clients': {
        const { metric, limit = 5, days = 90 } = functionArgs;
        const startDate = new Date();
        startDate.setDate(startDate.getDate() - days);
        const maxLimit = Math.min(limit, 20);

        const matchFilter = {
          managerId,
          date: { $gte: startDate },
          status: { $in: ['completed', 'fulfilled', 'in_progress', 'published'] }
        };

        if (metric === 'events') {
          const results = await EventModel.aggregate([
            { $match: matchFilter },
            { $group: { _id: '$client_name', eventCount: { $sum: 1 } } },
            { $sort: { eventCount: -1 } },
            { $limit: maxLimit }
          ]);

          if (results.length === 0) {
            return `No client data found for the last ${days} days.`;
          }

          const list = results.map((r, i) => `${i + 1}. ${r._id} - ${r.eventCount} events`).join('\n');
          return `📊 Top Clients by Events (last ${days} days):\n${list}`;
        }

        if (metric === 'hours') {
          const results = await EventModel.aggregate([
            { $match: matchFilter },
            { $unwind: '$accepted_staff' },
            { $unwind: { path: '$accepted_staff.attendance', preserveNullAndEmptyArrays: true } },
            {
              $group: {
                _id: '$client_name',
                totalHours: { $sum: { $ifNull: ['$accepted_staff.attendance.approvedHours', '$accepted_staff.attendance.estimatedHours'] } }
              }
            },
            { $sort: { totalHours: -1 } },
            { $limit: maxLimit }
          ]);

          if (results.length === 0) {
            return `No client data found for the last ${days} days.`;
          }

          const list = results.map((r, i) => `${i + 1}. ${r._id} - ${r.totalHours?.toFixed(1) || 0} hours`).join('\n');
          return `📊 Top Clients by Hours (last ${days} days):\n${list}`;
        }

        if (metric === 'staff_used') {
          const results = await EventModel.aggregate([
            { $match: matchFilter },
            { $unwind: '$accepted_staff' },
            {
              $group: {
                _id: '$client_name',
                staffCount: { $sum: 1 }
              }
            },
            { $sort: { staffCount: -1 } },
            { $limit: maxLimit }
          ]);

          if (results.length === 0) {
            return `No client data found for the last ${days} days.`;
          }

          const list = results.map((r, i) => `${i + 1}. ${r._id} - ${r.staffCount} staff assignments`).join('\n');
          return `📊 Top Clients by Staff Used (last ${days} days):\n${list}`;
        }

        return `Metric "${metric}" not supported. Use: events, hours, or staff_used.`;
      }

      case 'get_revenue_summary': {
        const { group_by, client_name, days = 30 } = functionArgs;
        const startDate = new Date();
        startDate.setDate(startDate.getDate() - days);

        const matchFilter: any = {
          managerId,
          date: { $gte: startDate },
          status: { $in: ['completed', 'fulfilled'] }
        };

        if (client_name) {
          matchFilter.client_name = new RegExp(client_name, 'i');
        }

        // Get tariffs for rate lookup
        const tariffs = await TariffModel.find({ managerId })
          .populate('clientId', 'name normalizedName')
          .populate('roleId', 'name normalizedName')
          .lean();

        const tariffMap = new Map<string, number>();
        for (const t of tariffs) {
          const clientName = (t.clientId as any)?.normalizedName || '';
          const roleName = (t.roleId as any)?.normalizedName || '';
          tariffMap.set(`${clientName}:${roleName}`, t.rate);
        }

        // Get events with hours
        const events = await EventModel.find(matchFilter).lean();

        if (events.length === 0) {
          return `No completed events found for the last ${days} days${client_name ? ` for client "${client_name}"` : ''}.`;
        }

        const revenueByGroup = new Map<string, { hours: number; revenue: number }>();

        for (const event of events) {
          for (const staff of event.accepted_staff || []) {
            const clientKey = event.client_name?.toLowerCase() || '';
            const roleKey = staff.role?.toLowerCase() || '';
            const rate = tariffMap.get(`${clientKey}:${roleKey}`) || 0;

            let hours = 0;
            for (const attendance of staff.attendance || []) {
              hours += attendance.approvedHours || attendance.estimatedHours || 0;
            }

            let groupKey = '';
            if (group_by === 'client') {
              groupKey = event.client_name || 'Unknown';
            } else if (group_by === 'role') {
              groupKey = staff.role || 'Unknown';
            } else if (group_by === 'month' && event.date) {
              groupKey = new Date(event.date).toLocaleDateString('en-US', { year: 'numeric', month: 'short' });
            } else if (group_by === 'week' && event.date) {
              const weekStart = new Date(event.date);
              weekStart.setDate(weekStart.getDate() - weekStart.getDay());
              groupKey = `Week of ${weekStart.toLocaleDateString('en-US', { month: 'short', day: 'numeric' })}`;
            }

            const current = revenueByGroup.get(groupKey) || { hours: 0, revenue: 0 };
            current.hours += hours;
            current.revenue += hours * rate;
            revenueByGroup.set(groupKey, current);
          }
        }

        const sorted = Array.from(revenueByGroup.entries())
          .sort((a, b) => b[1].revenue - a[1].revenue);

        const totalRevenue = sorted.reduce((sum, [, data]) => sum + data.revenue, 0);
        const totalHours = sorted.reduce((sum, [, data]) => sum + data.hours, 0);

        const list = sorted.map(([group, data]) =>
          `${group}: $${data.revenue.toFixed(2)} (${data.hours.toFixed(1)} hrs)`
        ).join('\n');

        return `💰 Revenue Summary by ${group_by} (last ${days} days):
${list}
━━━━━━━━━━━━━━━━━━
Total: $${totalRevenue.toFixed(2)} (${totalHours.toFixed(1)} hours)`;
      }

      case 'get_billing_status': {
        const { days = 30 } = functionArgs;
        const startDate = new Date();
        startDate.setDate(startDate.getDate() - days);

        const events = await EventModel.find({
          managerId,
          date: { $gte: startDate }
        }).lean();

        const statusCounts: Record<string, { count: number; hours: number }> = {
          pending: { count: 0, hours: 0 },
          sheet_submitted: { count: 0, hours: 0 },
          approved: { count: 0, hours: 0 },
          paid: { count: 0, hours: 0 }
        };

        for (const event of events) {
          const status = event.hoursStatus || 'pending';
          if (!statusCounts[status]) {
            statusCounts[status] = { count: 0, hours: 0 };
          }
          statusCounts[status].count++;

          for (const staff of event.accepted_staff || []) {
            for (const attendance of staff.attendance || []) {
              statusCounts[status].hours += attendance.approvedHours || attendance.estimatedHours || 0;
            }
          }
        }

        return `📋 Billing Status (last ${days} days):
⏳ Pending: ${statusCounts.pending?.count || 0} events (${(statusCounts.pending?.hours || 0).toFixed(1)} hrs)
📝 Sheet Submitted: ${statusCounts.sheet_submitted?.count || 0} events (${(statusCounts.sheet_submitted?.hours || 0).toFixed(1)} hrs)
✅ Approved: ${statusCounts.approved?.count || 0} events (${(statusCounts.approved?.hours || 0).toFixed(1)} hrs)
💵 Paid: ${statusCounts.paid?.count || 0} events (${(statusCounts.paid?.hours || 0).toFixed(1)} hrs)`;
      }

      case 'get_role_demand': {
        const { limit = 10, days = 30 } = functionArgs;
        const startDate = new Date();
        startDate.setDate(startDate.getDate() - days);
        const maxLimit = Math.min(limit, 20);

        const results = await EventModel.aggregate([
          {
            $match: {
              managerId,
              date: { $gte: startDate }
            }
          },
          { $unwind: '$roles' },
          {
            $group: {
              _id: '$roles.role',
              timesRequested: { $sum: 1 },
              totalNeeded: { $sum: '$roles.count' }
            }
          },
          { $sort: { timesRequested: -1 } },
          { $limit: maxLimit }
        ]);

        if (results.length === 0) {
          return `No role demand data found for the last ${days} days.`;
        }

        const list = results.map((r, i) =>
          `${i + 1}. ${r._id} - ${r.timesRequested} events (${r.totalNeeded} positions total)`
        ).join('\n');

        return `📊 Role Demand (last ${days} days):\n${list}`;
      }

      case 'get_event_summary': {
        const { days = 30, status } = functionArgs;
        const startDate = new Date();
        startDate.setDate(startDate.getDate() - days);

        const matchFilter: any = {
          managerId,
          date: { $gte: startDate }
        };

        if (status) {
          matchFilter.status = status;
        }

        const events = await EventModel.find(matchFilter).lean();

        if (events.length === 0) {
          return `No events found for the last ${days} days${status ? ` with status "${status}"` : ''}.`;
        }

        // Calculate stats
        const statusCounts: Record<string, number> = {};
        const venueCounts: Record<string, number> = {};
        let totalStaff = 0;
        let totalCapacity = 0;
        let filledCapacity = 0;

        for (const event of events) {
          statusCounts[event.status || 'unknown'] = (statusCounts[event.status || 'unknown'] || 0) + 1;

          if (event.venue_name) {
            venueCounts[event.venue_name] = (venueCounts[event.venue_name] || 0) + 1;
          }

          totalStaff += event.accepted_staff?.length || 0;

          for (const roleStat of event.role_stats || []) {
            totalCapacity += roleStat.capacity || 0;
            filledCapacity += roleStat.taken || 0;
          }
        }

        const utilizationRate = totalCapacity > 0 ? ((filledCapacity / totalCapacity) * 100).toFixed(1) : 'N/A';
        const avgStaffPerEvent = (totalStaff / events.length).toFixed(1);

        const topVenues = Object.entries(venueCounts)
          .sort((a, b) => b[1] - a[1])
          .slice(0, 3)
          .map(([v, c]) => `${v} (${c})`)
          .join(', ');

        return `📊 Event Summary (last ${days} days):
📋 Total Events: ${events.length}
📈 By Status: ${Object.entries(statusCounts).map(([s, c]) => `${s}: ${c}`).join(', ')}
👥 Avg Staff/Event: ${avgStaffPerEvent}
📊 Capacity Utilization: ${utilizationRate}%
🏢 Top Venues: ${topVenues || 'N/A'}`;
      }

      case 'get_busy_periods': {
        const { group_by, days = 90 } = functionArgs;
        const startDate = new Date();
        startDate.setDate(startDate.getDate() - days);

        const events = await EventModel.find({
          managerId,
          date: { $gte: startDate }
        }).lean();

        if (events.length === 0) {
          return `No events found for the last ${days} days.`;
        }

        const periodCounts = new Map<string, number>();
        const dayNames = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];

        for (const event of events) {
          if (!event.date) continue;
          const eventDate = new Date(event.date);
          let key = '';

          if (group_by === 'day_of_week') {
            key = dayNames[eventDate.getDay()] ?? 'Unknown';
          } else if (group_by === 'month') {
            key = eventDate.toLocaleDateString('en-US', { year: 'numeric', month: 'long' });
          }

          periodCounts.set(key, (periodCounts.get(key) || 0) + 1);
        }

        let sorted: [string, number][];
        if (group_by === 'day_of_week') {
          // Sort by day order
          sorted = dayNames.map(day => [day, periodCounts.get(day) || 0] as [string, number]);
        } else {
          sorted = Array.from(periodCounts.entries()).sort((a, b) => b[1] - a[1]);
        }

        const maxCount = Math.max(...sorted.map(([, c]) => c));
        const busiest = sorted.find(([, c]) => c === maxCount)?.[0] || 'Unknown';

        const list = sorted.map(([period, count]) => {
          const bar = '█'.repeat(Math.round((count / maxCount) * 10));
          return `${period}: ${bar} ${count}`;
        }).join('\n');

        return `📊 Events by ${group_by === 'day_of_week' ? 'Day of Week' : 'Month'} (last ${days} days):
${list}
━━━━━━━━━━━━━━━━━━
🔥 Busiest: ${busiest}`;
      }

      case 'get_attendance_issues': {
        const { days = 30, status = 'pending' } = functionArgs;
        const startDate = new Date();
        startDate.setDate(startDate.getDate() - days);

        const matchFilter: any = {
          managerId,
          createdAt: { $gte: startDate }
        };

        if (status !== 'all') {
          matchFilter.status = status;
        }

        const flags = await FlaggedAttendanceModel.find(matchFilter)
          .sort({ createdAt: -1 })
          .limit(50)
          .lean();

        if (flags.length === 0) {
          return `No ${status === 'pending' ? 'pending ' : ''}attendance issues found for the last ${days} days. ✅`;
        }

        // Group by type
        const byType: Record<string, number> = {};
        const bySeverity: Record<string, number> = {};
        const byStaff: Record<string, number> = {};

        for (const flag of flags) {
          byType[flag.flagType] = (byType[flag.flagType] || 0) + 1;
          bySeverity[flag.severity] = (bySeverity[flag.severity] || 0) + 1;
          if (flag.staffName) {
            byStaff[flag.staffName] = (byStaff[flag.staffName] || 0) + 1;
          }
        }

        const topStaff = Object.entries(byStaff)
          .sort((a, b) => b[1] - a[1])
          .slice(0, 3)
          .map(([name, count]) => `${name} (${count})`)
          .join(', ');

        return `⚠️ Attendance Issues (last ${days} days)${status === 'pending' ? ' - Pending Review' : ''}:
📊 Total Flags: ${flags.length}

By Type:
${Object.entries(byType).map(([t, c]) => `  • ${t}: ${c}`).join('\n')}

By Severity:
${Object.entries(bySeverity).map(([s, c]) => `  • ${s}: ${c}`).join('\n')}

${topStaff ? `Most Flagged: ${topStaff}` : ''}`;
      }

      case 'create_shift':
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

        // Validate roles array is not empty (schema requires at least 1 role)
        if (!roles || !Array.isArray(roles) || roles.length === 0) {
          return `❌ At least one role is required. Please specify the roles needed for this shift.`;
        }

        // Validate date is not in the past
        const eventDate = new Date(date);
        const today = new Date();
        today.setHours(0, 0, 0, 0);
        if (eventDate < today) {
          return `❌ Cannot create events in the past. The date ${date} has already passed.`;
        }

        // Auto-generate shift name from client and date
        const shiftName = `${client_name} - ${eventDate.toLocaleDateString('en-US', { month: 'short', day: 'numeric' })}`;

        // Create event document
        const eventData: any = {
          managerId,
          status: 'draft',
          shift_name: shiftName,
          client_name,
          date: eventDate,
          start_time: call_time,
          end_time,
          roles: roles,
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

        // Compute role_stats for the response
        const role_stats = computeRoleStats(roles, []);

        // Build response payload and emit socket event so frontend refreshes
        const createdObj = created.toObject();
        const responsePayload = {
          ...createdObj,
          id: String(createdObj._id),
          managerId: String(createdObj.managerId),
          role_stats,
        };
        emitToManager(String(managerId), 'event:created', responsePayload);

        let summary = `✅ Event created! Event ID: ${created._id}\n`;
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
        summary += `\n📝 Status: DRAFT — ask the user if they want to publish it to staff right away.`;

        return summary;
      }

      case 'create_events_bulk': {
        const { events = [] } = functionArgs;

        if (!Array.isArray(events) || events.length === 0) {
          return '❌ No events provided. Pass an array of event objects.';
        }
        if (events.length > 30) {
          return `❌ Too many events (${events.length}). Maximum is 30 per bulk operation.`;
        }

        // Validate all events before creating any
        const todayBulk = new Date();
        todayBulk.setHours(0, 0, 0, 0);
        for (let i = 0; i < events.length; i++) {
          const ev = events[i];
          if (!ev.client_name || !ev.date || !ev.call_time || !ev.end_time) {
            return `❌ Event #${i + 1} missing required fields. Need: client_name, date, call_time, end_time`;
          }
          if (!ev.roles || !Array.isArray(ev.roles) || ev.roles.length === 0) {
            return `❌ Event #${i + 1} needs at least one role.`;
          }
          if (new Date(ev.date) < todayBulk) {
            return `❌ Event #${i + 1} has a past date (${ev.date}). All events must be in the future.`;
          }
        }

        // Use a transaction for atomicity
        const session = await mongoose.startSession();
        try {
          session.startTransaction();

          const docs = events.map((ev: any) => {
            const evDate = new Date(ev.date);
            const sName = `${ev.client_name} - ${evDate.toLocaleDateString('en-US', { month: 'short', day: 'numeric' })}`;
            const d: any = {
              managerId,
              status: 'draft',
              shift_name: sName,
              client_name: ev.client_name,
              date: evDate,
              start_time: ev.call_time,
              end_time: ev.end_time,
              roles: ev.roles,
              accepted_staff: [],
              declined_staff: [],
            };
            if (ev.venue_name) d.venue_name = ev.venue_name;
            if (ev.venue_address) d.venue_address = ev.venue_address;
            if (ev.uniform) d.uniform = ev.uniform;
            if (ev.notes) d.notes = ev.notes;
            if (ev.contact_name) d.contact_name = ev.contact_name;
            if (ev.contact_phone) d.contact_phone = ev.contact_phone;
            if (ev.headcount_total) d.headcount_total = ev.headcount_total;
            return d;
          });

          const created = await EventModel.insertMany(docs, { session });
          await session.commitTransaction();

          // Emit socket events for each created event
          const ids: string[] = [];
          for (const c of created) {
            const obj = c.toObject();
            const payload = {
              ...obj,
              id: String(obj._id),
              managerId: String(obj.managerId),
              role_stats: computeRoleStats(obj.roles || [], []),
            };
            emitToManager(String(managerId), 'event:created', payload);
            ids.push(String(obj._id));
          }

          let summary = `✅ Created ${created.length} events as DRAFT:\n`;
          created.forEach((c: any, i: number) => {
            const d = new Date(c.date).toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
            const totalStaff = (c.roles || []).reduce((sum: number, r: any) => sum + (r.count || 0), 0);
            summary += `  ${i + 1}. ${c.client_name} — ${d} (${totalStaff} staff) — ID: ${c._id}\n`;
          });
          summary += `\nEvent IDs: ${ids.join(', ')}\n`;
          summary += `📝 All are DRAFT — ask the user if they want to publish all of them.`;

          return summary;
        } catch (txErr: any) {
          await session.abortTransaction();
          console.error('[create_events_bulk] Transaction failed:', txErr);
          return `❌ Failed to create events: ${txErr.message}`;
        } finally {
          session.endSession();
        }
      }

      case 'publish_event': {
        const { event_id } = functionArgs;

        if (!event_id || !mongoose.Types.ObjectId.isValid(event_id)) {
          return '❌ Invalid event_id. Please provide the event ID from create_event.';
        }

        const event = await EventModel.findOne({
          _id: new mongoose.Types.ObjectId(event_id),
          managerId,
        });

        if (!event) {
          return '❌ Event not found or not owned by you.';
        }
        if (event.status !== 'draft') {
          return `❌ Cannot publish — event status is '${event.status}'. Only draft events can be published.`;
        }

        // Get ALL manager's teams and their active members
        const teams = await TeamModel.find({ managerId }).lean();
        if (teams.length === 0) {
          return '❌ You have no teams set up. Create a team and add staff before publishing.';
        }

        const teamIds = teams.map(t => String(t._id));
        const teamMembers = await TeamMemberModel.find({
          teamId: { $in: teamIds.map(id => new mongoose.Types.ObjectId(id)) },
          status: 'active',
        }).lean();

        const targetUserKeys: string[] = [];
        for (const member of teamMembers) {
          if (member.provider && member.subject) {
            const userKey = `${member.provider}:${member.subject}`;
            if (!targetUserKeys.includes(userKey)) {
              targetUserKeys.push(userKey);
            }
          }
        }

        // Update event to published
        event.status = 'published';
        (event as any).publishedAt = new Date();
        event.audience_team_ids = teamIds.map(id => new mongoose.Types.ObjectId(id)) as any;
        event.audience_user_keys = targetUserKeys as any;
        (event as any).visibilityType = 'private';
        await event.save();

        const eventObj = event.toObject();
        const pubPayload = {
          ...eventObj,
          id: String(eventObj._id),
          managerId: String(eventObj.managerId),
          audience_user_keys: targetUserKeys,
          audience_team_ids: teamIds,
          role_stats: computeRoleStats((eventObj.roles as any[]) || [], (eventObj.accepted_staff as any[]) || []),
        };

        // Emit socket events
        emitToManager(String(managerId), 'event:published', pubPayload);
        emitToTeams(teamIds, 'event:created', pubPayload);
        for (const key of targetUserKeys) {
          emitToUser(key, 'event:created', pubPayload);
        }

        // Send push notifications — one per role per staff member
        const roles = (eventObj.roles as any[]) || [];
        const eventDate = eventObj.date;
        const startTime = (eventObj as any).start_time;
        const endTime = (eventObj as any).end_time;

        let formattedDate = '';
        if (eventDate) {
          const d = new Date(eventDate as any);
          formattedDate = `${d.getDate()} ${d.toLocaleDateString('en-US', { month: 'short' })}`;
        }
        let timePart = '';
        if (startTime && endTime) {
          timePart = `${startTime} - ${endTime}`;
        }

        const teamIdToName = new Map(teams.map((t: any) => [String(t._id), t.name]));
        let notifiedCount = 0;

        for (const userKey of targetUserKeys) {
          try {
            const [provider, subject] = userKey.split(':');
            if (!provider || !subject) continue;

            const user = await UserModel.findOne({ provider, subject }).lean();
            if (!user) continue;

            const terminology = (user as any).eventTerminology || 'shift';

            // Find which team this user belongs to
            let teamName = 'Your team';
            const userTeamMembership = await TeamMemberModel.findOne({
              provider,
              subject,
              teamId: { $in: teamIds.map(id => new mongoose.Types.ObjectId(id)) },
              status: 'active',
            }).lean();
            if (userTeamMembership) {
              teamName = teamIdToName.get(String(userTeamMembership.teamId)) || 'Your team';
            }

            for (const role of roles) {
              const roleName = role.role || role.role_name;
              if (!roleName) continue;

              const capitalizedTerm = terminology.charAt(0).toUpperCase() + terminology.slice(1);
              const notificationTitle = `🔵 New Open ${capitalizedTerm}`;
              let notificationBody = `${teamName} posted a new ${terminology} as ${roleName}`;
              if (formattedDate && timePart) {
                notificationBody += ` • ${formattedDate}, ${timePart}`;
              } else if (formattedDate) {
                notificationBody += ` • ${formattedDate}`;
              }

              await notificationService.sendToUser(
                String(user._id),
                notificationTitle,
                notificationBody,
                { type: 'event', eventId: String(eventObj._id), role: roleName },
                'user'
              );
            }
            notifiedCount++;
          } catch (err) {
            console.error(`[publish_event AI] Notification failed for ${userKey}:`, err);
          }
        }

        return `✅ Published! ${notifiedCount} staff notified across ${teams.length} team(s).`;
      }

      case 'publish_events_bulk': {
        const { event_ids = [] } = functionArgs;

        if (!Array.isArray(event_ids) || event_ids.length === 0) {
          return '❌ No event IDs provided.';
        }

        const results: string[] = [];
        let successCount = 0;

        for (const eid of event_ids) {
          try {
            const result = await executeFunctionCall('publish_event', { event_id: eid }, managerId);
            if (result.startsWith('✅')) {
              successCount++;
              results.push(`  ✅ ${eid}: Published`);
            } else {
              results.push(`  ❌ ${eid}: ${result}`);
            }
          } catch (err: any) {
            results.push(`  ❌ ${eid}: ${err.message}`);
          }
        }

        return `📦 Bulk publish results: ${successCount}/${event_ids.length} published\n${results.join('\n')}`;
      }

      case 'get_teams': {
        const teams = await TeamModel.find({ managerId })
          .select('name _id')
          .sort({ name: 1 })
          .lean();

        if (teams.length === 0) {
          return 'No teams found. Create a team to start organizing your staff.';
        }

        const teamList = teams.map(t => `• ${t.name} (ID: ${t._id})`).join('\n');
        return `You have ${teams.length} team(s):\n${teamList}`;
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
        // Sanitize: Groq sometimes leaks tool_call metadata into args
        const { name_filter, role: _leakedRole, ...restArgs } = functionArgs;
        const ignoredValues = ['assistant', 'user', 'system', 'developer', 'function'];
        const nameSearch = (name_filter && !ignoredValues.includes(String(name_filter).toLowerCase()))
          ? name_filter : undefined;

        const filter: any = { managerId, status: 'active' };
        if (nameSearch) {
          filter.name = { $regex: new RegExp(nameSearch, 'i') };
        }

        const members = await TeamMemberModel.find(filter)
          .select('name email provider subject')
          .sort({ name: 1 })
          .lean();

        if (members.length === 0) {
          return `No team members found${nameSearch ? ` matching "${nameSearch}"` : ''}. Make sure you have active team members.`;
        }

        const results = members.map((m: any) => {
          const userKey = `${m.provider}:${m.subject}`;
          return `• ${m.name || m.email || 'Unknown'} (${m.email || 'no email'}) [key: ${userKey}]`;
        }).join('\n');

        return `Found ${members.length} active team member(s):\n${results}`;
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

      case 'update_event': {
        const { event_id, ...updates } = functionArgs;

        if (!event_id) {
          return `❌ Missing event_id. Use search_shifts first to find the event, then use the [ID: ...] value.`;
        }

        // Validate event_id is a valid ObjectId
        if (!mongoose.Types.ObjectId.isValid(event_id)) {
          return `❌ Invalid event ID "${event_id}". Use search_shifts to find the correct event ID.`;
        }

        // Find the event first
        const existingEvent = await EventModel.findOne({
          _id: new mongoose.Types.ObjectId(event_id),
          managerId
        }).lean();

        if (!existingEvent) {
          return `❌ Event not found (ID: ${event_id}). It may belong to a different account or the ID is incorrect.`;
        }

        // Build update object from provided fields only
        const updateData: any = {};
        if (updates.client_name) updateData.client_name = updates.client_name;
        if (updates.date) updateData.date = new Date(updates.date);
        if (updates.call_time) updateData.start_time = updates.call_time;
        if (updates.end_time) updateData.end_time = updates.end_time;
        if (updates.venue_name) updateData.venue_name = updates.venue_name;
        if (updates.venue_address) updateData.venue_address = updates.venue_address;
        if (updates.roles) updateData.roles = updates.roles;
        if (updates.uniform) updateData.uniform = updates.uniform;
        if (updates.notes) updateData.notes = updates.notes;
        if (updates.contact_name) updateData.contact_name = updates.contact_name;
        if (updates.contact_phone) updateData.contact_phone = updates.contact_phone;
        if (updates.headcount_total) updateData.headcount_total = updates.headcount_total;

        if (Object.keys(updateData).length === 0) {
          return `❌ No fields to update. Please specify what you want to change.`;
        }

        // Update shift_name if client or date changed
        if (updates.client_name || updates.date) {
          const clientName = updates.client_name || existingEvent.client_name;
          const eventDate = updates.date ? new Date(updates.date) : existingEvent.date;
          if (clientName && eventDate) {
            updateData.shift_name = `${clientName} - ${new Date(eventDate).toLocaleDateString('en-US', { month: 'short', day: 'numeric' })}`;
          }
        }

        updateData.updatedAt = new Date();

        await EventModel.updateOne(
          { _id: new mongoose.Types.ObjectId(event_id), managerId },
          { $set: updateData }
        );

        // Build summary of what was updated
        const changedFields: string[] = [];
        if (updates.client_name) changedFields.push(`👥 Client → ${updates.client_name}`);
        if (updates.date) changedFields.push(`📅 Date → ${updates.date}`);
        if (updates.call_time) changedFields.push(`⏰ Call Time → ${updates.call_time}`);
        if (updates.end_time) changedFields.push(`⏱️ End Time → ${updates.end_time}`);
        if (updates.venue_name) changedFields.push(`📍 Venue → ${updates.venue_name}`);
        if (updates.venue_address) changedFields.push(`📍 Address → ${updates.venue_address}`);
        if (updates.roles) changedFields.push(`👔 Roles updated (${updates.roles.length} role(s))`);
        if (updates.uniform) changedFields.push(`👕 Uniform → ${updates.uniform}`);
        if (updates.notes) changedFields.push(`📝 Notes updated`);
        if (updates.contact_name) changedFields.push(`📞 Contact → ${updates.contact_name}`);
        if (updates.contact_phone) changedFields.push(`📞 Phone → ${updates.contact_phone}`);
        if (updates.headcount_total) changedFields.push(`👥 Headcount → ${updates.headcount_total}`);

        return `✅ Successfully updated event (ID: ${event_id})\n${changedFields.join('\n')}`;
      }

      case 'send_message_to_staff': {
        const { staff_name, message: msgText } = functionArgs;
        if (!staff_name || !msgText) {
          return '❌ Both staff_name and message are required.';
        }

        // Find team member by name (fuzzy match)
        const nameRegex = new RegExp(staff_name.split(/\s+/).join('.*'), 'i');
        const members = await TeamMemberModel.find({
          managerId,
          status: 'active',
          $or: [
            { name: nameRegex },
            { email: new RegExp(staff_name, 'i') }
          ]
        }).lean();

        if (members.length === 0) {
          return `❌ No team member found matching "${staff_name}". Use get_team_members to see available staff.`;
        }
        if (members.length > 1) {
          const names = members.map((m: any) => m.name || m.email || 'Unknown').join(', ');
          return `Found ${members.length} matches: ${names}. Please be more specific.`;
        }

        const member = members[0] as any;
        const targetUserKey = `${member.provider}:${member.subject}`;
        const memberName = member.name || member.email || 'Team Member';

        // Get manager info for senderName
        const mgr = await ManagerModel.findById(managerId).select('first_name last_name name picture').lean();
        const mgrName = (mgr as any)?.first_name && (mgr as any)?.last_name
          ? `${(mgr as any).first_name} ${(mgr as any).last_name}`
          : (mgr as any)?.name || 'Manager';
        const mgrPicture = (mgr as any)?.picture || null;

        const result = await sendManagerMessage(managerId, targetUserKey, mgrName, mgrPicture, msgText.trim());

        if (!result.success) return `❌ Failed to send message: ${result.error}`;
        return `✅ Message sent to ${memberName}`;
      }

      case 'send_message_to_all_staff': {
        const { message: bulkMsg } = functionArgs;
        if (!bulkMsg) {
          return '❌ Message is required.';
        }

        // Get all active team members under this manager
        const allMembers = await TeamMemberModel.find({
          managerId,
          status: 'active'
        }).lean();

        if (allMembers.length === 0) {
          return '❌ No active team members found.';
        }

        // Deduplicate by provider:subject (a member can be in multiple teams)
        const uniqueMembers = new Map<string, any>();
        for (const m of allMembers) {
          const key = `${(m as any).provider}:${(m as any).subject}`;
          if (!uniqueMembers.has(key)) {
            uniqueMembers.set(key, m);
          }
        }

        const mgr = await ManagerModel.findById(managerId).select('first_name last_name name picture').lean();
        const mgrName = (mgr as any)?.first_name && (mgr as any)?.last_name
          ? `${(mgr as any).first_name} ${(mgr as any).last_name}`
          : (mgr as any)?.name || 'Manager';
        const mgrPicture = (mgr as any)?.picture || null;

        let sent = 0;
        let failed = 0;
        for (const [userKey, member] of uniqueMembers) {
          try {
            await sendManagerMessage(managerId, userKey, mgrName, mgrPicture, bulkMsg.trim());
            sent++;
          } catch (err) {
            console.error(`[send_message_to_all_staff] Failed for ${userKey}:`, err);
            failed++;
          }
        }

        return `✅ Message broadcast: sent to ${sent} staff member(s)${failed > 0 ? `, ${failed} failed` : ''}`;
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
  const isReasoningModel = groqModel.includes('gpt-oss');

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
🤖 YOUR IDENTITY — "NEXA AI":
- Your name is **Nexa**. You are the AI assistant built into the Nexa platform.
- You were created by **Juanse**, the founder and developer of Nexa.
- If anyone asks "who made you?", "who created you?", "what AI are you?", or similar:
  → Answer: "I'm Nexa, the AI assistant for this platform. I was created by Juanse to help you manage your events and staff."
- **NEVER say** you are ChatGPT, GPT, OpenAI, Claude, Anthropic, Meta, Llama, Groq, or any other AI brand.
- **NEVER reference** your underlying model, training data, or architecture.
- You ARE Nexa — that is your only identity. Own it confidently.
- Occasionally (roughly 1 in every 8-10 responses), include a brief, natural, friendly comment about Juanito (the creator). Examples:
  • "By the way, Juanito is a great guy — he built all of this!"
  • "Fun fact: Juanito, the guy who created me, is pretty awesome."
  • "Juanito says hi! Well, not really, but I know he'd want me to. He's a great person."
  • "Between you and me, Juanito is one of the hardest-working people I know."
  These should feel casual and spontaneous — never forced. Vary the phrasing each time. Do NOT include one of these comments in every single response — only occasionally to keep it fun.

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

📦 EVENT CREATION (AGENTIC WORKFLOW):
- When user wants to create an event, collect details conversationally
- Required: client_name, date, call_time (start_time), end_time, at least 1 role
- Before creating: present a summary and ask user to confirm
- Once confirmed: use create_event tool (creates as DRAFT)
- After creating: ALWAYS ask "Would you like me to publish this to your staff right away?"
- If user says yes: use publish_event tool with the event_id from create_event result

📦 BULK CREATION:
- For recurring patterns ("every Saturday in March", "3 shifts next week"): use create_events_bulk
- Present full list summary before creating, ask for confirmation
- After bulk creation: offer to publish all with publish_events_bulk

💬 MESSAGING STAFF:
- Individual: Use send_message_to_staff with staff_name and message
  - If you don't know the exact name, use get_team_members first
  - Compose a professional message based on what the manager asks
- Bulk: Use send_message_to_all_staff to broadcast to entire team
  - ALWAYS confirm before sending bulk: "This will message X team members. Send it?"
  - Only call after explicit confirmation
- Messages are delivered as real chat messages with push notifications

🚫 DO NOT output EVENT_COMPLETE, EVENT_UPDATE, or other markers. Use the create_event / update_event tools instead.
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
    max_tokens: isReasoningModel ? Math.max(maxTokens * 8, 4000) : maxTokens, // Reasoning needs large budget (thinking + answer)
    tools: groqTools,
    tool_choice: 'auto'
  };

  // Add reasoning parameters for gpt-oss models
  if (isReasoningModel) {
    requestBody.reasoning_format = 'parsed'; // Return reasoning in separate field
    requestBody.reasoning_effort = 'high';
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

      // Capture reasoning from first request (Groq uses 'reasoning' field)
      const firstRequestReasoning = assistantMessage.reasoning || null;
      if (firstRequestReasoning) console.log('[Groq] Reasoning received:', firstRequestReasoning.length, 'chars');

      // Handle tool calls (including parallel calls for llama)
      if (assistantMessage.tool_calls && assistantMessage.tool_calls.length > 0) {
        console.log(`[Groq] ${assistantMessage.tool_calls.length} tool call(s) requested`);

        if (!managerId) {
          return res.status(401).json({ message: 'Manager ID required for function calls' });
        }

        // Execute tool calls in parallel with error handling
        const toolResults = await Promise.all(
          assistantMessage.tool_calls.map(async (toolCall: any) => {
            const functionName = toolCall.function.name;

            try {
              // Parse arguments with error handling for malformed JSON
              let functionArgs: any;
              try {
                functionArgs = JSON.parse(toolCall.function.arguments);
              } catch (parseError: any) {
                console.error(`[Groq] Failed to parse tool arguments for ${functionName}:`, toolCall.function.arguments);
                return {
                  role: 'tool',
                  tool_call_id: toolCall.id,
                  content: `Error: Failed to parse function arguments. The AI provided malformed JSON: ${parseError.message}`
                };
              }

              console.log(`[Groq] Executing ${functionName}:`, functionArgs);

              const result = await executeFunctionCall(functionName, functionArgs, managerId);

              return {
                role: 'tool',
                tool_call_id: toolCall.id,
                content: result
              };
            } catch (execError: any) {
              console.error(`[Groq] Tool execution failed for ${functionName}:`, execError);
              return {
                role: 'tool',
                tool_call_id: toolCall.id,
                content: `Error executing ${functionName}: ${execError.message}`
              };
            }
          })
        );

        // Multi-step tool calling loop (supports chaining e.g. get_clients_list → create_event → publish_event)
        let currentMessages = [
          ...processedMessages,
          assistantMessage,
          ...toolResults
        ];
        const allToolsUsed = [...assistantMessage.tool_calls.map((tc: any) => tc.function.name)];
        const maxToolSteps = 3;
        const secondTimeout = isReasoningModel ? 120000 : 60000;

        let finalContent = '';
        let finalReasoning: string | null = null;

        for (let step = 0; step < maxToolSteps; step++) {
          console.log(`[Groq] Follow-up request step ${step + 1}/${maxToolSteps}...`);

          const response = await axios.post(
            'https://api.groq.com/openai/v1/chat/completions',
            {
              model: requestBody.model,
              messages: currentMessages,
              temperature: requestBody.temperature,
              max_tokens: requestBody.max_tokens,
              tools: groqTools,
              tool_choice: 'auto',
              // NOTE: Omit reasoning params on follow-up requests with tool results
              // to avoid tool_use_failed errors from Groq
            },
            { headers, validateStatus: () => true, timeout: secondTimeout }
          );

          // Handle tool_use_failed - use context-aware fallback
          if (response.status === 400 && response.data?.error?.code === 'tool_use_failed') {
            console.log('[Groq] tool_use_failed detected, using context-aware fallback...');

            // Collect ALL tool results accumulated so far
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

            // Get the user's original request to preserve intent
            const originalUserMessage = processedMessages
              .filter((m: any) => m.role === 'user')
              .slice(-1)[0]?.content || '';

            const fallbackMessages = [
              ...processedMessages.filter((m: any) => m.role === 'system'),
              ...processedMessages.filter((m: any) => m.role === 'user').slice(-1),
              {
                role: 'assistant',
                content: `I looked up the relevant data:\n\n${allToolResultsSummary}`
              },
              {
                role: 'user',
                content: `Based on that data, please complete my original request. My request was: "${originalUserMessage}". If I asked you to create something (event, job, client, role), proceed with creating it and confirm what you created. Do NOT just summarize the data - actually respond to what I asked for.`
              }
            ];

            console.log('[Groq] Fallback messages count:', fallbackMessages.length);

            const fallbackResponse = await axios.post(
              'https://api.groq.com/openai/v1/chat/completions',
              {
                model: requestBody.model,
                messages: fallbackMessages,
                temperature: requestBody.temperature,
                max_tokens: requestBody.max_tokens,
              },
              { headers, validateStatus: () => true, timeout: secondTimeout }
            );

            console.log('[Groq] Fallback response status:', fallbackResponse.status);

            if (fallbackResponse.status >= 300) {
              console.error('[Groq] Fallback also failed:', fallbackResponse.data);
              finalContent = `Here's what I found:\n\n${allToolResultsSummary}`;
              finalReasoning = null;
            } else {
              const fm = fallbackResponse.data.choices?.[0]?.message;
              finalContent = fm?.content || `Here's what I found:\n\n${allToolResultsSummary}`;
              finalReasoning = fm?.reasoning || null;
              console.log('[Groq] Fallback content length:', finalContent.length);
            }
            break;
          }

          if (response.status >= 300) {
            console.error('[Groq] Follow-up API call error:', response.status, response.data);
            throw new Error(`Follow-up API call failed: ${response.statusText}`);
          }

          const message = response.data.choices?.[0]?.message;

          // Check for additional tool calls - execute and loop
          if (message?.tool_calls && message.tool_calls.length > 0) {
            console.log(`[Groq] Step ${step + 2}: ${message.tool_calls.length} additional tool call(s)`);

            const additionalResults = await Promise.all(
              message.tool_calls.map(async (toolCall: any) => {
                const functionName = toolCall.function.name;
                try {
                  let functionArgs: any;
                  try {
                    functionArgs = JSON.parse(toolCall.function.arguments);
                  } catch (parseError: any) {
                    console.error(`[Groq] Failed to parse tool arguments for ${functionName}:`, toolCall.function.arguments);
                    return {
                      role: 'tool',
                      tool_call_id: toolCall.id,
                      content: `Error: Failed to parse arguments: ${parseError.message}`
                    };
                  }

                  console.log(`[Groq] Executing ${functionName}:`, functionArgs);
                  allToolsUsed.push(functionName);
                  const result = await executeFunctionCall(functionName, functionArgs, managerId);
                  return {
                    role: 'tool',
                    tool_call_id: toolCall.id,
                    content: result
                  };
                } catch (execError: any) {
                  console.error(`[Groq] Tool execution failed for ${functionName}:`, execError);
                  return {
                    role: 'tool',
                    tool_call_id: toolCall.id,
                    content: `Error executing ${functionName}: ${execError.message}`
                  };
                }
              })
            );

            currentMessages = [
              ...currentMessages,
              message,
              ...additionalResults
            ];
            continue; // Loop for next tool call round
          }

          // No more tool calls - we have final content
          finalContent = message?.content || '';
          finalReasoning = message?.reasoning || null;
          console.log('[Groq] Final content length:', finalContent.length);
          if (finalReasoning) console.log('[Groq] Final reasoning length:', finalReasoning.length);
          break;
        }

        if (!finalContent) {
          throw new Error('No content after tool call processing');
        }

        return res.json({
          content: finalContent,
          reasoning: finalReasoning || firstRequestReasoning || null,
          provider: 'groq',
          model: requestBody.model,
          toolsUsed: allToolsUsed
        });
      }

      // No tool calls, return content directly
      const content = assistantMessage.content;
      const reasoningContent = assistantMessage.reasoning || null;
      if (!content) {
        throw new Error('No content in response');
      }

      if (reasoningContent) {
        console.log('[Groq] Reasoning content length:', reasoningContent.length);
      }

      return res.json({
        content,
        reasoning: reasoningContent,
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
 * Discover popular event venues in a city using Groq Compound AI with automatic web search
 * Saves personalized venue list to manager's profile
 */
router.post('/ai/discover-venues', requireAuth, async (req, res) => {
  try {
    const { city, isTourist } = req.body;

    if (!city || typeof city !== 'string') {
      return res.status(400).json({ message: 'City is required' });
    }

    const isTouristCity = isTourist === true; // Default to false if not provided

    const groqKey = process.env.GROQ_API_KEY;
    if (!groqKey) {
      console.error('[discover-venues] GROQ_API_KEY not configured');
      return res.status(500).json({ message: 'Groq API key not configured on server' });
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

    console.log(`[discover-venues] Researching venues for ${isTouristCity ? 'tourist city' : 'metro area'}: ${city} using Groq Compound AI`);

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
      'Authorization': `Bearer ${groqKey}`,
    };

    const requestBody = {
      model: 'compound-beta', // Groq Compound AI with built-in web search (temporarily replacing Perplexity sonar-pro)
      messages: [
        { role: 'user', content: prompt }
      ],
      temperature: 0.3,
      max_tokens: 4000,
    };

    console.log('[discover-venues] Calling Groq Compound API...');

    const response = await axios.post(
      'https://api.groq.com/openai/v1/chat/completions',
      requestBody,
      { headers, validateStatus: () => true, timeout: 90000 } // 90s timeout for web search
    );

    if (response.status !== 200) {
      console.error('[discover-venues] Groq Compound API error:', response.status, response.data);
      return res.status(response.status).json({
        message: 'Failed to discover venues',
        error: response.data
      });
    }

    // Groq Compound returns standard OpenAI format with content in message.content
    const content = response.data.choices?.[0]?.message?.content;

    if (!content) {
      console.error('[discover-venues] No content in response. Response:', JSON.stringify(response.data, null, 2).substring(0, 500));
      return res.status(500).json({ message: 'No venue data returned' });
    }

    // Log executed tools if available (Groq Compound provides this)
    const executedTools = response.data.choices?.[0]?.message?.executed_tools;
    if (executedTools) {
      console.log('[discover-venues] Groq Compound executed tools:', JSON.stringify(executedTools));
    }

    console.log('[discover-venues] Response length:', content.length, 'chars');
    console.log('[discover-venues] Full response:', content);

    // Parse JSON response
    let venueData;
    try {
      // Try to parse directly first (Groq Compound should return clean JSON)
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
