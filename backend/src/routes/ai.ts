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
import { getProviderConfig } from '../utils/aiProvider';
import { extractLastUserMessage } from '../utils/cascadeRouter';
import { EventModel } from '../models/event';
import { ClientModel } from '../models/client';
import { TeamMemberModel } from '../models/teamMember';
import { AvailabilityModel } from '../models/availability';
import { ManagerModel } from '../models/manager';
import { RoleModel } from '../models/role';
import { TariffModel } from '../models/tariff';
import { AIChatSummaryModel } from '../models/aiChatSummary';
import { ConversationModel } from '../models/conversation';
import { ChatMessageModel } from '../models/chatMessage';
import { FlaggedAttendanceModel } from '../models/flaggedAttendance';
import { UserModel } from '../models/user';
import { TeamModel } from '../models/team';
import { emitToManager, emitToTeams, emitToUser } from '../socket/server';
import { notificationService } from '../services/notificationService';
import { computeRoleStats } from '../utils/eventCapacity';
import { logAIUsage } from '../utils/logAIUsage';
import { shareEventPublic, shareEventPrivate, sendDirectInvitation } from '../services/eventShareService';

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
 * Accepts audio file upload and optional terminology parameter
 * Returns transcribed text
 */
router.post('/ai/transcribe', requireAuth, upload.single('audio'), async (req, res) => {
  let tempFilePath: string | null = null;
  const transcribeStartTime = Date.now();

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

    logAIUsage({
      managerId: (req as any).user?.managerId,
      userType: 'manager',
      endpoint: 'transcribe',
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
  multi: z.boolean().optional().default(false),
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
  provider: z.enum(['openai', 'claude', 'groq', 'together']).optional().default('groq'),
  model: z.string().optional(), // Accepted for backward compat — ignored; cascade router selects model server-side
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
    name: 'search_events',
    description: 'Search and filter events/shifts. Use scope "upcoming" for active/future jobs, "past" for completed, or omit for all. Returns IDs (needed for update_event), pay, staffing, contacts, and details.',
    parameters: {
      type: 'object',
      properties: {
        scope: {
          type: ['string', 'null'],
          description: '"upcoming" = future + not completed/cancelled, "past" = completed or past date, omit for all'
        },
        status: {
          type: ['string', 'null'],
          description: 'Filter by specific status: draft, published, confirmed, fulfilled, in_progress, completed, cancelled'
        },
        client_name: {
          type: ['string', 'null'],
          description: 'Filter by client name'
        },
        date: {
          type: ['string', 'null'],
          description: 'ISO date (YYYY-MM-DD) or month (YYYY-MM). Overrides scope date range.'
        },
        venue_name: {
          type: ['string', 'null'],
          description: 'Filter by venue name'
        },
        event_name: {
          type: ['string', 'null'],
          description: 'Search by event/shift name'
        },
        days_past: {
          type: ['number', 'null'],
          description: 'Days in the past to include (default: 30, only when no scope/date)'
        },
        days_future: {
          type: ['number', 'null'],
          description: 'Days in the future to include (default: 60, only when no scope/date)'
        },
        visibility: {
          type: ['string', 'null'],
          description: 'Filter by visibility: public, private'
        },
        hours_status: {
          type: ['string', 'null'],
          description: 'Filter by hours approval: pending, sheet_submitted, approved, paid'
        },
        limit: {
          type: ['number', 'null'],
          description: 'Max results (default: 50)'
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
    description: 'Get detailed statistics for a specific staff member with monthly breakdown. Use when manager asks "show me Maria\'s stats", "how many hours has John worked?", "how did she do in February vs March?", etc.',
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
    name: 'get_punctuality_report',
    description: 'Get staff punctuality/lateness report. Shows who clocked in late, how late, and who never clocked in (no-shows). Use when manager asks "who is always late?", "punctuality report", "did everyone show up?", "is Maria on time?", "quién llega tarde?", "tardy", etc.',
    parameters: {
      type: 'object',
      properties: {
        staff_name: {
          type: ['string', 'null'],
          description: 'Optional: specific staff name. Omit for all-staff overview.'
        },
        days: {
          type: ['number', 'null'],
          description: 'Time period in days (default: 30)'
        },
        threshold_minutes: {
          type: ['number', 'null'],
          description: 'Grace period in minutes before counting as late (default: 5)'
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
    description: 'Makes a draft event visible to staff. Can be public (open shifts to all teams) or private (only visible to specific people). Use after create_event when user confirms.',
    parameters: {
      type: 'object',
      properties: {
        event_id: {
          type: 'string',
          description: 'The event ID returned by create_event'
        },
        visibility: {
          type: 'string',
          enum: ['public', 'private'],
          description: "public = visible to all teams (default). private = only target_staff can see it."
        },
        target_staff: {
          type: 'array',
          items: { type: 'string' },
          description: 'Names of specific staff to share with. Required if visibility is private. Use get_team_members first to find names.'
        },
        target_team_ids: {
          type: 'array',
          items: { type: 'string' },
          description: 'IDs of specific teams to publish to. Provided in PUBLISH INFO from create_event response. If omitted, publishes to ALL teams.'
        }
      },
      required: ['event_id']
    }
  },
  {
    name: 'invite_staff_to_event',
    description: 'Invites one specific staff member to a single role within an event. Sends a direct chat message they can accept or decline. Use when manager says "invite Jane as bartender".',
    parameters: {
      type: 'object',
      properties: {
        event_id: { type: 'string', description: 'The event ID' },
        staff_name: { type: 'string', description: 'Name of the staff member to invite' },
        role_name: { type: 'string', description: 'The specific role they are being invited for' }
      },
      required: ['event_id', 'staff_name', 'role_name']
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
        },
        target_team_ids: {
          type: 'array',
          items: { type: 'string' },
          description: 'IDs of specific teams to publish to. Provided in PUBLISH INFO from create_events_bulk response. If omitted, publishes to ALL teams.'
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
  // get_events_summary removed — merged into search_events
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
    description: 'Update an existing event/shift. Use when user wants to modify event details (venue, date, time, roles, notes, etc.). REQUIRES event_id - get it from search_events first. Only include fields that need to change.',
    parameters: {
      type: 'object',
      properties: {
        event_id: {
          type: 'string',
          description: 'The event ID (from search_events results). Required to identify which event to update.'
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

// ---------------------------------------------------------------------------
// Punctuality / Lateness Computation
// ---------------------------------------------------------------------------

interface PunctualityEventDetail {
  date: string;
  clientName: string;
  role: string;
  status: 'on_time' | 'late' | 'no_show';
  minutesLate: number;
  bulkClockIn: boolean;
}

interface PunctualityRecord {
  staffKey: string;
  staffName: string;
  onTimeCount: number;
  lateCount: number;
  noShowCount: number;
  totalLateMinutes: number;
  totalEvents: number;
  eventDetails: PunctualityEventDetail[];
}

/**
 * Compute punctuality stats from a set of events.
 *
 * For each accepted staff member on each event, compares their first clockInAt
 * against the expected arrival time (role call_time → event start_time fallback).
 *
 * @param events       - Pre-queried events (must include accepted_staff, date, start_time, roles, client_name, status)
 * @param staffUserKey - If set, only compute for this specific staff member
 * @param staffNamePattern - Fallback regex pattern when userKey is unavailable
 * @param thresholdMinutes - Grace period before marking late (default 5 min)
 */
function computePunctuality(
  events: any[],
  staffUserKey?: string | null,
  staffNamePattern?: string | null,
  thresholdMinutes: number = 5
): PunctualityRecord[] {
  const recordMap = new Map<string, PunctualityRecord>();

  for (const event of events) {
    if (!event.accepted_staff || !Array.isArray(event.accepted_staff)) continue;

    // Only evaluate completed/fulfilled/in_progress events (future drafts are meaningless)
    const eventStatus = event.status;
    if (!['completed', 'fulfilled', 'in_progress'].includes(eventStatus)) continue;

    const eventDate = event.date ? new Date(event.date) : null;
    if (!eventDate) continue;

    for (const staff of event.accepted_staff) {
      // Filter: only accepted staff
      if (staff.response !== 'accepted' && staff.response !== 'accept') continue;

      // Filter to specific staff if requested
      if (staffUserKey && staff.userKey !== staffUserKey) continue;
      if (!staffUserKey && staffNamePattern && !new RegExp(staffNamePattern, 'i').test(staff.name || '')) continue;

      // Determine expected arrival time
      // Priority: role-specific call_time → event start_time
      let expectedTimeStr: string | null = null;

      if (staff.role && event.roles && Array.isArray(event.roles)) {
        const matchedRole = event.roles.find(
          (r: any) => r.role && r.call_time && r.role.toLowerCase() === staff.role.toLowerCase()
        );
        if (matchedRole?.call_time) {
          expectedTimeStr = matchedRole.call_time;
        }
      }

      if (!expectedTimeStr && event.start_time) {
        expectedTimeStr = event.start_time;
      }

      if (!expectedTimeStr) continue; // Can't compute without an expected time

      // Build full expected datetime
      const timeParts = expectedTimeStr.split(':').map(Number);
      const expH = timeParts[0] ?? 0;
      const expM = timeParts[1] ?? 0;
      const expectedDt = new Date(eventDate);
      expectedDt.setHours(expH, expM, 0, 0);

      // Staff key for grouping
      const key = staff.userKey || staff.name || 'unknown';
      if (!recordMap.has(key)) {
        recordMap.set(key, {
          staffKey: key,
          staffName: staff.name || staff.first_name || 'Unknown',
          onTimeCount: 0,
          lateCount: 0,
          noShowCount: 0,
          totalLateMinutes: 0,
          totalEvents: 0,
          eventDetails: []
        });
      }
      const record = recordMap.get(key)!;
      record.totalEvents++;

      const attendance = staff.attendance;
      const hasClockIn = attendance && Array.isArray(attendance) && attendance.length > 0 && attendance[0].clockInAt;

      if (!hasClockIn) {
        // No attendance → no-show (only meaningful for completed events)
        record.noShowCount++;
        record.eventDetails.push({
          date: eventDate.toISOString().slice(0, 10),
          clientName: event.client_name || 'Unknown',
          role: staff.role || 'N/A',
          status: 'no_show',
          minutesLate: 0,
          bulkClockIn: false
        });
        continue;
      }

      // Use first session's clockInAt
      const clockIn = new Date(attendance[0].clockInAt);
      const diffMinutes = (clockIn.getTime() - expectedDt.getTime()) / (1000 * 60);
      const isBulk = !!attendance[0].overrideBy;

      if (diffMinutes <= thresholdMinutes) {
        record.onTimeCount++;
        record.eventDetails.push({
          date: eventDate.toISOString().slice(0, 10),
          clientName: event.client_name || 'Unknown',
          role: staff.role || 'N/A',
          status: 'on_time',
          minutesLate: 0,
          bulkClockIn: isBulk
        });
      } else {
        const minsLate = Math.round(diffMinutes);
        record.lateCount++;
        record.totalLateMinutes += minsLate;
        record.eventDetails.push({
          date: eventDate.toISOString().slice(0, 10),
          clientName: event.client_name || 'Unknown',
          role: staff.role || 'N/A',
          status: 'late',
          minutesLate: minsLate,
          bulkClockIn: isBulk
        });
      }
    }
  }

  return Array.from(recordMap.values());
}

/**
 * Execute a function call from the AI model
 * Handles all function types: queries and creates
 */
async function executeFunctionCall(
  functionName: string,
  functionArgs: any,
  rawManagerId: mongoose.Types.ObjectId | string
): Promise<string> {
  // Ensure managerId is an ObjectId — JWT gives us a string, but aggregate() needs ObjectId
  const managerId = rawManagerId instanceof mongoose.Types.ObjectId
    ? rawManagerId
    : new mongoose.Types.ObjectId(String(rawManagerId));
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

      case 'search_events': {
        const {
          scope, status, client_name, date, venue_name, event_name,
          days_past = 30, days_future = 60, visibility, hours_status,
          limit: resultLimit = 50
        } = functionArgs;

        const filter: any = { managerId };
        const today = new Date();
        today.setHours(0, 0, 0, 0);

        // Scope shortcuts (date + status combos)
        if (scope === 'upcoming') {
          filter.date = { $gte: today };
          filter.status = { $nin: ['completed', 'cancelled'] };
        } else if (scope === 'past') {
          filter.$or = [
            { date: { $lt: today } },
            { status: { $in: ['completed', 'cancelled'] } }
          ];
        } else if (!date) {
          // Default: date range window (only when no explicit date/scope)
          const pastDate = new Date(today);
          pastDate.setDate(pastDate.getDate() - days_past);
          const futureDate = new Date(today);
          futureDate.setDate(futureDate.getDate() + days_future);
          filter.date = { $gte: pastDate, $lte: futureDate };
        }

        // Explicit date overrides scope's date filter
        if (date) {
          if (date.length === 7) {
            const startDate = new Date(`${date}-01`);
            const endDate = new Date(startDate);
            endDate.setMonth(endDate.getMonth() + 1);
            filter.date = { $gte: startDate, $lt: endDate };
          } else {
            filter.date = new Date(date);
          }
        }

        // Explicit status overrides scope's status filter
        if (status) {
          filter.status = status;
        }

        // Optional filters
        if (visibility) filter.visibilityType = visibility;
        if (hours_status) filter.hoursStatus = hours_status;

        // Cross-field name search (from search_shifts)
        const nameTerms: string[] = [];
        if (client_name) nameTerms.push(client_name);
        if (venue_name) nameTerms.push(venue_name);
        if (event_name) nameTerms.push(event_name);

        if (nameTerms.length > 0) {
          const orConditions: any[] = [];
          for (const term of nameTerms) {
            const regex = new RegExp(term, 'i');
            orConditions.push(
              { client_name: regex },
              { venue_name: regex },
              { event_name: regex },
              { shift_name: regex }
            );
          }
          // Combine with existing $or (from scope=past) using $and
          if (filter.$or) {
            const existingOr = filter.$or;
            delete filter.$or;
            filter.$and = [{ $or: existingOr }, { $or: orConditions }];
          } else {
            filter.$or = orConditions;
          }
        }

        // Log the final filter for debugging
        console.log(`[search_events] Filter:`, JSON.stringify(filter));

        const events = await EventModel.find(filter)
          .select('_id event_name shift_name client_name date venue_name venue_address city start_time end_time roles pay_rate_info status accepted_staff declined_staff contact_name contact_phone setup_time uniform notes visibilityType hoursStatus role_stats keepOpen')
          .sort({ date: scope === 'past' ? -1 : 1 })
          .limit(Math.min(resultLimit, 50))
          .lean();

        if (events.length === 0) {
          return `No events found matching the criteria.`;
        }

        const results = events.map((e: any) => {
          const dateStr = e.date ? new Date(e.date).toLocaleDateString('en-US', { weekday: 'short', month: 'short', day: 'numeric', year: 'numeric' }) : 'No date';
          const timeStr = e.start_time ? `${e.start_time} - ${e.end_time || '?'}` : '';
          const staffCount = e.accepted_staff?.length || 0;
          const totalNeeded = e.roles?.reduce((sum: number, r: any) => sum + (r.count || r.quantity || 0), 0) || 0;
          const payInfo = e.roles?.map((r: any) => `${r.role || r.role_name}: ${r.pay_rate_info || 'no rate'}`).join(', ');

          let line = `[ID: ${e._id}] ${dateStr}: ${e.event_name || e.shift_name || 'Unnamed'} (${e.client_name || 'No client'}) at ${e.venue_name || 'TBD'}`;
          if (timeStr) line += `, ${timeStr}`;
          line += `, Status: ${e.status || 'draft'}, Staff: ${staffCount}/${totalNeeded}`;
          if (e.visibilityType) line += `, Visibility: ${e.visibilityType}`;
          if (payInfo) line += `, Pay: ${payInfo}`;
          if (e.contact_name) line += `, Contact: ${e.contact_name}${e.contact_phone ? ` (${e.contact_phone})` : ''}`;
          if (e.setup_time) line += `, Setup: ${e.setup_time}`;
          if (e.uniform) line += `, Uniform: ${e.uniform}`;
          if (e.notes) line += `, Notes: ${e.notes}`;
          if (e.venue_address) line += `, Address: ${e.venue_address}`;
          if (e.hoursStatus && e.hoursStatus !== 'pending') line += `, Hours: ${e.hoursStatus}`;
          if (e.keepOpen) line += ` [kept open]`;
          return line;
        }).join('\n');

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

        const { mergeClients: mergeClientsFn } = await import('../services/catalogMergeService');
        const mergeResult = await mergeClientsFn(
          managerId,
          [sourceClient._id.toString()],
          targetClient._id.toString()
        );

        let result = `✅ Successfully merged "${sourceClient.name}" into "${targetClient.name}"`;
        if (mergeResult.eventsTransferred > 0) {
          result += `\n   📋 ${mergeResult.eventsTransferred} event(s) transferred`;
        }
        if (mergeResult.tariffsTransferred > 0) {
          result += `\n   💰 ${mergeResult.tariffsTransferred} tariff(s) transferred`;
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
          const availableClients = await ClientModel.find({ managerId }).select('name').lean();
          const clientNames = availableClients.map(c => c.name).join(', ');
          return `❌ Client "${client_name}" not found. Available clients: ${clientNames || 'none'}. Would you like me to create "${client_name}" first?`;
        }

        // Find role
        const role = await RoleModel.findOne({
          managerId,
          normalizedName: role_name.toLowerCase()
        }).lean();

        if (!role) {
          const availableRoles = await RoleModel.find({ managerId }).select('name').lean();
          const roleNames = availableRoles.map(r => r.name).join(', ');
          return `❌ Role "${role_name}" not found. Available roles: ${roleNames || 'none'}. Would you like me to create "${role_name}" first?`;
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

        const { mergeRoles: mergeRolesFn } = await import('../services/catalogMergeService');
        const mergeResult = await mergeRolesFn(
          managerId,
          [sourceRole._id.toString()],
          targetRole._id.toString()
        );

        let result = `✅ Successfully merged "${sourceRole.name}" into "${targetRole.name}"`;
        if (mergeResult.eventsTransferred > 0) {
          result += `\n   📋 ${mergeResult.eventsTransferred} event(s) updated`;
        }
        if (mergeResult.tariffsTransferred > 0) {
          result += `\n   💰 ${mergeResult.tariffsTransferred} tariff(s) transferred`;
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

        if (metric === 'punctuality') {
          // Reuse same matchFilter already constructed above
          const punctEvents = await EventModel.find(matchFilter)
            .select('accepted_staff date start_time roles client_name status')
            .lean();

          if (punctEvents.length === 0) {
            return `No completed events found for the last ${days} days${role_name ? ` with role "${role_name}"` : ''}.`;
          }

          const punctRecords = computePunctuality(punctEvents, null, null, 5);

          // Filter to staff with ≥ 3 events (avoid misleading 100%/0% scores)
          const qualified = punctRecords.filter(r => r.totalEvents >= 3);

          if (qualified.length === 0) {
            return `Not enough data — no staff member has 3+ completed events in the last ${days} days.`;
          }

          // Sort by on-time percentage descending (best first — "top" semantics)
          qualified.sort((a, b) => {
            const aPct = a.onTimeCount / a.totalEvents;
            const bPct = b.onTimeCount / b.totalEvents;
            return bPct - aPct;
          });

          const limited = qualified.slice(0, maxLimit);
          const list = limited.map((r, i) => {
            const onTimePct = Math.round((r.onTimeCount / r.totalEvents) * 100);
            return `${i + 1}. ${r.staffName} — ${onTimePct}% on time (${r.onTimeCount}/${r.totalEvents} events), ${r.lateCount} late, ${r.noShowCount} no-shows`;
          }).join('\n');

          return `⏱️ Most Punctual Staff (last ${days} days)${role_name ? ` - ${role_name}` : ''}:\n${list}`;
        }

        return `Metric "${metric}" not supported. Use: hours_worked, events_completed, points, or punctuality.`;
      }

      case 'get_staff_stats': {
        const { staff_name, days = 30 } = functionArgs;
        const startDate = new Date();
        startDate.setDate(startDate.getDate() - days);
        startDate.setHours(0, 0, 0, 0);

        // Resolve staff member's userKey for exact matching (same as staff-side)
        const teamMember = await TeamMemberModel.findOne({
          managerId,
          $or: [
            { name: new RegExp(staff_name, 'i') },
            { email: new RegExp(staff_name, 'i') }
          ]
        }).lean();

        const staffUserKey = teamMember ? `${teamMember.provider}:${teamMember.subject}` : null;

        // Query by userKey (exact) if available, fallback to name regex
        // Upper-bound to end of today — future events aren't "worked" yet (matches staff-side)
        const endDate = new Date();
        endDate.setHours(23, 59, 59, 999);
        const staffFilter: any = {
          managerId,
          date: { $gte: startDate, $lte: endDate },
          status: { $ne: 'cancelled' }
        };
        if (staffUserKey) {
          staffFilter['accepted_staff.userKey'] = staffUserKey;
        } else {
          staffFilter['accepted_staff.name'] = new RegExp(staff_name, 'i');
        }

        const events = await EventModel.find(staffFilter)
          .select('_id accepted_staff client_name start_time end_time date status roles')
          .lean();

        if (events.length === 0) {
          return `No events found for staff member "${staff_name}" in the last ${days} days.`;
        }

        // Calculate stats
        let totalHours = 0;
        let eventCount = 0;
        const rolesWorked = new Set<string>();
        const clientsWorked = new Set<string>();
        const monthlyStats: Record<string, { events: number; hours: number }> = {};

        for (const event of events) {
          const staffEntry = staffUserKey
            ? event.accepted_staff?.find(s => s.userKey === staffUserKey)
            : event.accepted_staff?.find(s => s.name?.toLowerCase().includes(staff_name.toLowerCase()));

          if (staffEntry && (staffEntry.response === 'accepted' || staffEntry.response === 'accept')) {
            // Hours: prefer approved attendance (matches staff-side/Flutter earnings)
            let hours = 0;
            for (const session of staffEntry.attendance || []) {
              if (session.approvedHours != null && session.status === 'approved') {
                hours += session.approvedHours;
              }
            }

            // Fallback: scheduled shift duration if no approved attendance
            if (hours === 0 && event.start_time && event.end_time) {
              const s = new Date(`1970-01-01T${event.start_time}`);
              const e = new Date(`1970-01-01T${event.end_time}`);
              hours = (e.getTime() - s.getTime()) / (1000 * 60 * 60);
              if (hours < 0) hours += 24;
            }

            // Skip events with zero hours (matches staff-side behavior)
            if (hours === 0) continue;

            eventCount++;
            if (staffEntry.role) rolesWorked.add(staffEntry.role);
            if (event.client_name) clientsWorked.add(event.client_name);

            const monthKey = event.date ? new Date(event.date).toISOString().slice(0, 7) : 'unknown';
            if (!monthlyStats[monthKey]) monthlyStats[monthKey] = { events: 0, hours: 0 };
            monthlyStats[monthKey].events++;

            totalHours += hours;
            monthlyStats[monthKey].hours += hours;
          }
        }

        const avgHoursPerEvent = eventCount > 0 ? (totalHours / eventCount).toFixed(1) : 0;

        // Compute punctuality for this staff member
        let punctualityInfo = '';
        const punctRecords = computePunctuality(events, staffUserKey, staffUserKey ? null : staff_name, 5);
        const pr = punctRecords.length > 0 ? punctRecords[0] : null;
        if (pr && pr.totalEvents > 0) {
          const onTimePct = Math.round((pr.onTimeCount / pr.totalEvents) * 100);
          punctualityInfo = `\n⏱️ Punctuality: ${pr.onTimeCount}/${pr.totalEvents} on time (${onTimePct}%)`;
          if (pr.lateCount > 0) {
            const avgLate = Math.round(pr.totalLateMinutes / pr.lateCount);
            punctualityInfo += `\n⚠️ Late: ${pr.lateCount} times (avg ${avgLate} min)`;
          }
          if (pr.noShowCount > 0) {
            punctualityInfo += `\n❌ No-shows: ${pr.noShowCount}`;
          }
        }

        // Try to find gamification data
        let gamificationInfo = '';
        if (teamMember) {
          const user = await UserModel.findOne({
            userKey: staffUserKey
          }).lean();

          if ((user as any)?.gamification) {
            const gam = (user as any).gamification;
            gamificationInfo = `\n🏆 Points: ${gam.totalPoints || 0}
🔥 Current Streak: ${gam.currentStreak || 0} days
⭐ Longest Streak: ${gam.longestStreak || 0} days`;
          }
        }

        const byMonth = Object.entries(monthlyStats)
          .sort(([a], [b]) => a.localeCompare(b))
          .map(([month, s]) => `  ${month}: ${s.events} events, ${s.hours.toFixed(1)} hrs`)
          .join('\n');

        return `📊 Stats for ${staff_name} (last ${days} days):
📋 Events Worked: ${eventCount}
⏱️ Total Hours: ${totalHours.toFixed(1)}
📈 Avg Hours/Event: ${avgHoursPerEvent}
👔 Roles: ${Array.from(rolesWorked).join(', ') || 'N/A'}
🏢 Clients: ${Array.from(clientsWorked).join(', ') || 'N/A'}${punctualityInfo}${gamificationInfo}
📅 By Month:\n${byMonth}`;
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
        })
          .select('_id status accepted_staff client_name date')
          .lean();

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
        const events = await EventModel.find(matchFilter)
          .select('_id client_name accepted_staff date')
          .lean();

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

      case 'get_punctuality_report': {
        const { staff_name, days = 30, threshold_minutes = 5 } = functionArgs;
        const startDate = new Date();
        startDate.setDate(startDate.getDate() - days);
        startDate.setHours(0, 0, 0, 0);

        const eventFilter: any = {
          managerId,
          date: { $gte: startDate },
          status: { $in: ['completed', 'fulfilled', 'in_progress'] }
        };

        let staffUserKey: string | null = null;
        let staffNamePattern: string | null = null;

        if (staff_name) {
          // Resolve staff member's userKey
          const teamMember = await TeamMemberModel.findOne({
            managerId,
            $or: [
              { name: new RegExp(staff_name, 'i') },
              { email: new RegExp(staff_name, 'i') }
            ]
          }).lean();

          if (teamMember) {
            staffUserKey = `${teamMember.provider}:${teamMember.subject}`;
            eventFilter['accepted_staff.userKey'] = staffUserKey;
          } else {
            staffNamePattern = staff_name;
            eventFilter['accepted_staff.name'] = new RegExp(staff_name, 'i');
          }
        }

        const events = await EventModel.find(eventFilter)
          .select('accepted_staff date start_time end_time roles client_name status')
          .lean();

        if (events.length === 0) {
          return staff_name
            ? `No events found for "${staff_name}" in the last ${days} days.`
            : `No completed events found in the last ${days} days.`;
        }

        const records = computePunctuality(events, staffUserKey, staffNamePattern, threshold_minutes);

        if (records.length === 0) {
          return staff_name
            ? `No punctuality data found for "${staff_name}" — they may not have been on any completed events.`
            : `No punctuality data found for the last ${days} days.`;
        }

        // Single staff → detailed view
        if (staff_name && records.length === 1) {
          const rec = records[0]!;
          const onTimePct = rec.totalEvents > 0 ? Math.round((rec.onTimeCount / rec.totalEvents) * 100) : 0;
          const avgLate = rec.lateCount > 0 ? Math.round(rec.totalLateMinutes / rec.lateCount) : 0;

          let details = '';
          const issues = rec.eventDetails.filter(d => d.status !== 'on_time');
          if (issues.length > 0) {
            details = '\n\n📋 Late/missed details:\n' + issues.map(d => {
              if (d.status === 'no_show') {
                return `  ❌ ${d.date} — ${d.clientName} — No-show`;
              }
              const bulk = d.bulkClockIn ? ' (bulk clock-in)' : '';
              return `  ⚠️ ${d.date} — ${d.clientName} — ${d.minutesLate} min late${bulk}`;
            }).join('\n');
          }

          return `⏱️ Punctuality Report for ${rec.staffName} (last ${days} days):
📊 ${rec.totalEvents} events total
✅ On time: ${rec.onTimeCount} (${onTimePct}%)
⚠️ Late: ${rec.lateCount}${rec.lateCount > 0 ? ` (avg ${avgLate} min late)` : ''}
❌ No-show: ${rec.noShowCount}${details}`;
        }

        // All staff → ranked overview (worst punctuality first)
        const sorted = records
          .filter(r => r.totalEvents > 0)
          .sort((a, b) => {
            const aOnTime = a.onTimeCount / a.totalEvents;
            const bOnTime = b.onTimeCount / b.totalEvents;
            return aOnTime - bOnTime; // worst first
          });

        const list = sorted.map((r, i) => {
          const onTimePct = Math.round((r.onTimeCount / r.totalEvents) * 100);
          return `${i + 1}. ${r.staffName} — ${onTimePct}% on time, ${r.lateCount} late, ${r.noShowCount} no-shows (${r.totalEvents} events)`;
        }).join('\n');

        return `⏱️ Staff Punctuality (last ${days} days):\n${list}`;
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

        // Dedup guard: if an identical event was created in the last 5 minutes, return it
        const fiveMinAgo = new Date(Date.now() - 5 * 60 * 1000);
        const existingDup = await EventModel.findOne({
          managerId,
          client_name,
          date: eventDate,
          start_time: call_time,
          end_time,
          createdAt: { $gte: fiveMinAgo },
        }).lean();

        if (existingDup) {
          // Pre-fetch teams for the response (same as normal create path)
          const dupTeams = await TeamModel.find({ managerId }).select('name _id').sort({ name: 1 }).lean();
          let dupSummary = `⚠️ This event already exists (created moments ago). Event ID: ${existingDup._id}\n`;
          dupSummary += `👥 Client: ${existingDup.client_name} | 📅 Date: ${date} | Status: ${existingDup.status}\n`;
          dupSummary += `Use this event ID instead of creating a new one.`;
          if (existingDup.status === 'draft' && dupTeams.length > 0) {
            if (dupTeams.length === 1) {
              dupSummary += `\n\n📤 PUBLISH INFO: Event is DRAFT. Manager has 1 team: "${dupTeams[0]!.name}" (team_id: ${dupTeams[0]!._id}). Ask if they want to publish. Call publish_event with event_id: "${existingDup._id}" and target_team_ids: ["${dupTeams[0]!._id}"].`;
            } else {
              const teamList = dupTeams.map(t => `"${t.name}" (team_id: ${t._id})`).join(', ');
              dupSummary += `\n\n📤 PUBLISH INFO: Event is DRAFT. Manager has ${dupTeams.length} teams: ${teamList}. Ask which team to publish to.`;
            }
          }
          return dupSummary;
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
        summary += `\n📝 Status: DRAFT`;

        // Pre-fetch teams so the AI can present publish options immediately
        // (avoids a separate get_teams call that the model often fails to make)
        const teams = await TeamModel.find({ managerId }).select('name _id').sort({ name: 1 }).lean();
        if (teams.length === 1) {
          summary += `\n\n📤 PUBLISH INFO: Manager has 1 team: "${teams[0]!.name}" (team_id: ${teams[0]!._id}). Ask if they want to publish to this team. If yes, call publish_event with target_team_ids: ["${teams[0]!._id}"].`;
        } else if (teams.length > 1) {
          const teamList = teams.map(t => `"${t.name}" (team_id: ${t._id})`).join(', ');
          summary += `\n\n📤 PUBLISH INFO: Manager has ${teams.length} teams: ${teamList}. Ask which team to publish to (or all). Use the team_id(s) in publish_event's target_team_ids. Do NOT call get_teams — you already have the info.`;
        } else {
          summary += `\n\n📤 PUBLISH INFO: Manager has no teams. They can still publish as open shift (call publish_event without target_team_ids).`;
        }

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

        // Dedup guard: check each event against recently created ones (last 5 min)
        const bulkFiveMinAgo = new Date(Date.now() - 5 * 60 * 1000);
        const recentEvents = await EventModel.find({
          managerId,
          createdAt: { $gte: bulkFiveMinAgo },
        }).select('_id client_name date start_time status').lean();

        if (recentEvents.length > 0) {
          // Check each incoming event against recent ones
          const matchedDups: any[] = [];
          for (const ev of events) {
            const evDate = new Date(ev.date).toISOString().slice(0, 10);
            const match = recentEvents.find((r: any) => {
              const rDate = new Date(r.date).toISOString().slice(0, 10);
              return r.client_name === ev.client_name && rDate === evDate && r.start_time === ev.call_time;
            });
            if (match) matchedDups.push(match);
          }

          // If most events already exist, block the creation
          if (matchedDups.length >= Math.ceil(events.length / 2)) {
            // Get ALL recent events for this client to show complete picture
            const allRecent = recentEvents.filter((r: any) =>
              events.some((ev: any) => r.client_name === ev.client_name)
            );
            const bulkDupTeams = await TeamModel.find({ managerId }).select('name _id').sort({ name: 1 }).lean();
            let dupMsg = `⚠️ These events already exist (created moments ago). Found ${allRecent.length} matching events:\n`;
            allRecent.forEach((d: any, i: number) => {
              const dt = new Date(d.date).toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
              dupMsg += `  ${i + 1}. ${d.client_name} — ${dt} — ID: ${d._id} (${d.status})\n`;
            });
            dupMsg += `\nDo NOT create new events. Use these existing event IDs.`;

            const draftDups = allRecent.filter((d: any) => d.status === 'draft');
            if (draftDups.length > 0) {
              const draftIds = draftDups.map((d: any) => `"${d._id}"`).join(', ');
              if (bulkDupTeams.length === 1) {
                dupMsg += `\n\n📤 PUBLISH INFO: ${draftDups.length} are DRAFT. Manager has 1 team: "${bulkDupTeams[0]!.name}" (team_id: ${bulkDupTeams[0]!._id}). To publish, call publish_events_bulk with event_ids: [${draftIds}] and target_team_ids: ["${bulkDupTeams[0]!._id}"].`;
              } else if (bulkDupTeams.length > 1) {
                const teamList = bulkDupTeams.map(t => `"${t.name}" (team_id: ${t._id})`).join(', ');
                dupMsg += `\n\n📤 PUBLISH INFO: ${draftDups.length} are DRAFT. Manager has ${bulkDupTeams.length} teams: ${teamList}. To publish, call publish_events_bulk with event_ids: [${draftIds}] and target_team_ids.`;
              } else {
                dupMsg += `\n\n📤 PUBLISH INFO: ${draftDups.length} are DRAFT. No teams. To publish, call publish_events_bulk with event_ids: [${draftIds}].`;
              }
            }
            return dupMsg;
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

          // Pre-fetch teams for publish flow (fat response pattern)
          const bulkTeams = await TeamModel.find({ managerId }).select('name _id').sort({ name: 1 }).lean();
          if (bulkTeams.length === 1) {
            summary += `\n\n📤 PUBLISH INFO: Manager has 1 team: "${bulkTeams[0]!.name}" (team_id: ${bulkTeams[0]!._id}). Ask if they want to publish all to this team. If yes, call publish_events_bulk with event_ids: [${ids.map(id => `"${id}"`).join(', ')}] and target_team_ids: ["${bulkTeams[0]!._id}"].`;
          } else if (bulkTeams.length > 1) {
            const bulkTeamList = bulkTeams.map(t => `"${t.name}" (team_id: ${t._id})`).join(', ');
            summary += `\n\n📤 PUBLISH INFO: Manager has ${bulkTeams.length} teams: ${bulkTeamList}. Ask which team to publish to (or all). Use publish_events_bulk with event_ids: [${ids.map(id => `"${id}"`).join(', ')}] and target_team_ids.`;
          } else {
            summary += `\n\n📤 PUBLISH INFO: No teams found. Call publish_events_bulk with event_ids: [${ids.map(id => `"${id}"`).join(', ')}] (publishes as open shift).`;
          }

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
        const { event_id, visibility, target_staff, target_team_ids } = functionArgs;

        if (!event_id || !mongoose.Types.ObjectId.isValid(event_id)) {
          return '❌ Invalid event_id. Please provide the event ID from create_event.';
        }

        // Get manager info for the service calls
        const mgrInfo = await ManagerModel.findById(managerId).select('first_name last_name name email').lean();
        const mgrName = (mgrInfo as any)?.first_name && (mgrInfo as any)?.last_name
          ? `${(mgrInfo as any).first_name} ${(mgrInfo as any).last_name}`
          : (mgrInfo as any)?.name || 'Manager';
        const mgrEmail = (mgrInfo as any)?.email || '';

        // Determine effective share type
        const isPrivate = visibility === 'private' || (target_staff && target_staff.length > 0);

        if (isPrivate && target_staff && target_staff.length > 0) {
          // Resolve staff names to userKeys (fuzzy match)
          const resolvedUserKeys: string[] = [];
          const notFoundNames: string[] = [];

          for (const staffName of target_staff) {
            const nameRegex = new RegExp(staffName.split(/\s+/).join('.*'), 'i');
            const members = await TeamMemberModel.find({
              managerId,
              status: 'active',
              $or: [{ name: nameRegex }, { email: new RegExp(staffName, 'i') }],
            }).lean();

            if (members.length === 1 && members[0]?.provider && members[0]?.subject) {
              resolvedUserKeys.push(`${members[0]!.provider}:${members[0]!.subject}`);
            } else if (members.length > 1) {
              const names = members.map((m: any) => m.name || m.email).join(', ');
              return `❌ Multiple matches for "${staffName}": ${names}. Please be more specific.`;
            } else {
              notFoundNames.push(staffName);
            }
          }

          if (resolvedUserKeys.length === 0) {
            return `❌ No staff found matching: ${notFoundNames.join(', ')}. Use get_team_members to see available staff.`;
          }

          const result = await shareEventPrivate({
            managerId,
            eventId: event_id,
            targetUserKeys: resolvedUserKeys,
            managerName: mgrName,
            managerEmail: mgrEmail,
          });

          if (!result.success) return `❌ ${result.error}`;

          let response = `✅ Shared privately with ${result.notifiedCount} staff member(s).`;
          if (notFoundNames.length > 0) {
            response += `\n⚠️ Could not find: ${notFoundNames.join(', ')}`;
          }
          return response;
        }

        // Public publish — optionally scoped to specific teams
        const result = await shareEventPublic({
          managerId,
          eventId: event_id,
          targetTeamIds: target_team_ids?.length ? target_team_ids : null,
          managerName: mgrName,
          managerEmail: mgrEmail,
        });

        if (!result.success) return `❌ ${result.error}`;
        return `✅ Published! ${result.notifiedCount} staff notified across ${result.teamCount} team(s).`;
      }

      case 'invite_staff_to_event': {
        const { event_id, staff_name, role_name } = functionArgs;

        if (!event_id || !mongoose.Types.ObjectId.isValid(event_id)) {
          return '❌ Invalid event_id.';
        }
        if (!staff_name || !role_name) {
          return '❌ Both staff_name and role_name are required.';
        }

        // Resolve staff name to userKey (fuzzy match)
        const nameRegex = new RegExp(staff_name.split(/\s+/).join('.*'), 'i');
        const members = await TeamMemberModel.find({
          managerId,
          status: 'active',
          $or: [{ name: nameRegex }, { email: new RegExp(staff_name, 'i') }],
        }).lean();

        if (members.length === 0) {
          return `❌ No team member found matching "${staff_name}". Use get_team_members to see available staff.`;
        }
        if (members.length > 1) {
          const names = members.map((m: any) => m.name || m.email || 'Unknown').join(', ');
          return `Found ${members.length} matches: ${names}. Please be more specific.`;
        }

        const member = members[0] as any;
        const inviteeUserKey = `${member.provider}:${member.subject}`;
        const memberName = member.name || member.email || 'Team Member';

        // Get manager info
        const mgr = await ManagerModel.findById(managerId).select('first_name last_name name picture').lean();
        const invMgrName = (mgr as any)?.first_name && (mgr as any)?.last_name
          ? `${(mgr as any).first_name} ${(mgr as any).last_name}`
          : (mgr as any)?.name || 'Manager';
        const invMgrPicture = (mgr as any)?.picture || null;

        const result = await sendDirectInvitation({
          managerId,
          eventId: event_id,
          inviteeUserKey,
          roleName: role_name,
          managerName: invMgrName,
          managerPicture: invMgrPicture,
        });

        if (!result.success) return `❌ ${result.error}`;
        return `✅ Invitation sent to ${memberName} for the ${result.roleName} role.`;
      }

      case 'publish_events_bulk': {
        const { event_ids = [], target_team_ids } = functionArgs;

        if (!Array.isArray(event_ids) || event_ids.length === 0) {
          return '❌ No event IDs provided.';
        }

        const results: string[] = [];
        let successCount = 0;

        for (const eid of event_ids) {
          try {
            const result = await executeFunctionCall('publish_event', { event_id: eid, target_team_ids }, managerId);
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

      // get_events_summary handler removed — merged into search_events

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
          return `❌ Missing event_id. Use search_events first to find the event, then use the [ID: ...] value.`;
        }

        // Validate event_id is a valid ObjectId
        if (!mongoose.Types.ObjectId.isValid(event_id)) {
          return `❌ Invalid event ID "${event_id}". Use search_events to find the correct event ID.`;
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

        let updateResponse = `✅ Successfully updated event (ID: ${event_id})\n${changedFields.join('\n')}`;

        // If event is still draft, offer publish with pre-fetched team info
        if (existingEvent.status === 'draft') {
          const updateTeams = await TeamModel.find({ managerId }).select('name _id').sort({ name: 1 }).lean();
          if (updateTeams.length === 1) {
            updateResponse += `\n\n📤 PUBLISH INFO: Event is still DRAFT. Manager has 1 team: "${updateTeams[0]!.name}" (team_id: ${updateTeams[0]!._id}). Ask if they want to publish now.`;
          } else if (updateTeams.length > 1) {
            const updateTeamList = updateTeams.map(t => `"${t.name}" (team_id: ${t._id})`).join(', ');
            updateResponse += `\n\n📤 PUBLISH INFO: Event is still DRAFT. Manager has ${updateTeams.length} teams: ${updateTeamList}. Ask which team to publish to.`;
          }
        }

        return updateResponse;
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
    const { input, isImage, multi } = validated;

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

    const singlePrompt =
      'You are a structured information extractor for catering event staffing. Extract fields: event_name, client_name, date (ISO 8601), start_time, end_time, venue_name, venue_address, city, state, country, contact_name, contact_phone, contact_email, setup_time, uniform, notes, headcount_total, roles (list of {role, count, call_time}), pay_rate_info. Return strict JSON.';

    const multiPrompt =
      'You are a structured information extractor for catering event staffing. ' +
      'The document may contain MULTIPLE events. Extract ALL of them. ' +
      'For each event extract: event_name, client_name, date (ISO 8601), start_time, end_time, ' +
      'venue_name, venue_address, city, state, country, contact_name, contact_phone, contact_email, ' +
      'setup_time, uniform, notes, headcount_total, roles (list of {role, count, call_time}), pay_rate_info. ' +
      'Return a JSON ARRAY of objects. Do not include any text outside the JSON array. Example: [{...}, {...}]';

    const systemPrompt = multi ? multiPrompt : singlePrompt;
    const maxTokens = multi ? 4000 : 800;
    const userText = multi
      ? 'Extract ALL events from this document and return a JSON array.'
      : 'Extract structured event staffing info and return only JSON.';

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
      // Input is text
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

    // Try to extract JSON — array first (for multi), then single object
    const arrStart = content.indexOf('[');
    const arrEnd = content.lastIndexOf(']');
    const objStart = content.indexOf('{');
    const objEnd = content.lastIndexOf('}');

    let parsed: any = null;

    if (arrStart !== -1 && arrEnd !== -1 && arrEnd > arrStart) {
      try {
        parsed = JSON.parse(content.substring(arrStart, arrEnd + 1));
      } catch (_) { /* fall through */ }
    }

    if (!parsed && objStart !== -1 && objEnd !== -1 && objEnd > objStart) {
      try {
        parsed = JSON.parse(content.substring(objStart, objEnd + 1));
      } catch (parseErr) {
        console.error('[ai/extract] Failed to parse JSON:', parseErr);
        return res.status(500).json({ message: 'Failed to parse response from AI' });
      }
    }

    if (!parsed) {
      return res.status(500).json({ message: 'No valid JSON found in AI response' });
    }

    if (multi) {
      const arr = Array.isArray(parsed) ? parsed : [parsed];
      return res.json({ extracted: arr });
    } else {
      // Backward compatible: return raw object (no wrapper)
      const single = Array.isArray(parsed) ? parsed[0] : parsed;
      return res.json(single);
    }
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

    // Get managerId from authenticated user
    const managerId = (req as any).user?._id || (req as any).user?.managerId;
    if (!managerId) {
      return res.status(401).json({ message: 'Manager not found' });
    }

    // Load manager for Groq usage tracking
    const manager = await ManagerModel.findById(managerId);
    if (!manager) {
      return res.status(404).json({ message: 'Manager not found' });
    }

    // Always use 120B with high reasoning — no cascade, no keyword routing.
    const selectedProvider = 'groq' as const;
    const selectedModel = 'openai/gpt-oss-120b';

    console.log(`[ai/chat/message] provider=${selectedProvider}, model=${selectedModel}`);

    // Detect user's timezone from IP
    const timezone = getTimezoneFromRequest(req);

    return await handleGroqRequest(messages, temperature, maxTokens, res, timezone, selectedModel, managerId, selectedProvider, 'complex');
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
 * Build a compact manager context summary (~80-120 tokens) for system prompt injection.
 * Replaces the full context blob (~3,000-5,000 tokens) that was previously sent by the frontend.
 * Runs 5 lightweight count/select queries in parallel.
 */
async function getCompactManagerContext(managerId: mongoose.Types.ObjectId): Promise<string> {
  const today = new Date();
  today.setHours(0, 0, 0, 0);

  const [recentClients, totalClients, upcomingEvents, totalEvents, activeTeam] = await Promise.all([
    ClientModel.find({ managerId }).select('name').sort({ created_at: -1 }).limit(5).lean(),
    ClientModel.countDocuments({ managerId }),
    EventModel.countDocuments({ managerId, date: { $gte: today } }),
    EventModel.countDocuments({ managerId }),
    TeamMemberModel.countDocuments({ managerId, status: 'active' }),
  ]);

  const recentNames = recentClients.map((c: any) => c.name).join(', ');
  const pastEvents = totalEvents - upcomingEvents;

  return `📋 YOUR DATA:
- ${totalClients} clients${recentNames ? ` (recent: ${recentNames})` : ''}
- ${totalEvents} events (${upcomingEvents} upcoming, ${pastEvents} past)
- ${activeTeam} active team members
Use your tools to look up specific details — do not guess from this summary.`;
}

/**
 * Handle Groq chat request for manager with optimized Chat Completions API
 * Model is selected by cascade router: Tier 1 (simple) → gpt-oss-20b @ Together, Tier 2 (complex) → gpt-oss-120b @ Groq
 * Features: Parallel tool calls, prompt caching, retry logic, reasoning mode
 */
async function handleGroqRequest(
  messages: any[],
  temperature: number,
  maxTokens: number,
  res: any,
  timezone?: string,
  model?: string,
  managerId?: mongoose.Types.ObjectId,
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

  console.log(`[AI:${config.name}] Manager using model: ${config.model}`);

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
        console.log(`[AI:${config.name}] Injected ${examples.length} context example(s) from past conversations`);
      }
    } catch (error) {
      console.error(`[AI:${config.name}] Failed to fetch context examples:`, error);
      // Continue without examples - non-blocking
    }
  }

  // Optimize prompt structure: CRITICAL rules FIRST (open-source models follow early instructions better)
  const systemInstructions = `
🤖 YOUR IDENTITY — "VALERIO":
- Your name is **Valerio**. You are the AI assistant built into the FlowShift platform for managers.

🚫 ABSOLUTE RULES - MUST FOLLOW (TOP PRIORITY):
1. **NEVER show raw JSON, code blocks, or technical data** to the user
2. **NEVER display IDs, timestamps, or internal field names** (like _id, createdAt, managerId)
3. **NEVER display function results or API responses** in their raw form
4. **NEVER ask the user to provide dates in a specific format** - convert automatically
5. **NEVER mention YYYY-MM-DD, ISO format, or any technical format** to the user
6. **NEVER create events in the past** - ALL event dates MUST be today or in the future

🔄 CONVERSATIONAL FOLLOW-UP (CRITICAL):
When you just asked the user a question (e.g., "Which team should I publish to?", "Would you like to publish?", "Should I use this client?"), their NEXT message is the ANSWER to your question. Do NOT interpret it as a new unrelated request. For example:
- You asked "Which team?" → user says "Rivera" → that means the team named Rivera, NOT "create a client called Rivera"
- You asked "Want to publish?" → user says "Si" → that means YES to publish, NOT a new query
Always check your last message before interpreting a short user reply.

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
- After creating: The create_event response includes PUBLISH INFO with the manager's teams and their IDs.
- Use this info to ask "Would you like me to publish this to [team name]?" (or list teams if multiple).
- If user says yes (or picks a team): call publish_event immediately with the target_team_ids from the PUBLISH INFO. Do NOT call get_teams — you already have the IDs.
- If user says "all" / "todos": call publish_event without target_team_ids.
- NEVER show team IDs to the user — only show team names.

📤 SHARING EVENTS WITH STAFF:
After you create an event, it is a DRAFT. You must share it to make it visible. You have three ways:
1. **Public (Open Shifts)**: To make an event visible to ALL your teams, use publish_event with visibility: 'public' (this is the default). Ask: "Should I publish this as an open shift for all your teams?"
2. **Private (Select Group)**: To share with only specific people, use publish_event with visibility: 'private' and provide their names in target_staff. Ask: "Should I share this privately with specific people? If so, who?"
3. **Direct Invitation (1-on-1)**: To invite one person to a specific role, use invite_staff_to_event. This sends a direct chat message they can accept or decline. Use when the manager says "Invite Jane to the bartender role."

Default behavior:
- If manager says "publish" / "yes" / "send to everyone" → use publish_event with target_team_ids from the PUBLISH INFO (do NOT call get_teams)
- If manager says "all teams" / "todos los equipos" → use publish_event without target_team_ids (publishes to all)
- If manager says "share with Maria and Juan only" → use publish_event with visibility: 'private' + target_staff
- If manager says "invite Jane as bartender" → use invite_staff_to_event

📦 BULK CREATION:
- For recurring patterns ("every Saturday in March", "3 shifts next week"): use create_events_bulk
- Present full list summary before creating, ask for confirmation
- After bulk creation: The response includes PUBLISH INFO with event IDs and team IDs.
- Ask "Would you like me to publish all of these to [team name]?"
- If user says yes: call publish_events_bulk with event_ids and target_team_ids from the PUBLISH INFO. Do NOT call create_events_bulk again — the events already exist.
- ⚠️ CRITICAL: When user says "yes"/"si"/"publish" after bulk creation, that means PUBLISH the existing drafts. NEVER re-create them. Use publish_events_bulk with the IDs from the previous response.

💬 MESSAGING STAFF:
- Individual: Use send_message_to_staff with staff_name and message
  - If you don't know the exact name, use get_team_members first
  - Compose a professional message based on what the manager asks
- Bulk: Use send_message_to_all_staff to broadcast to entire team
  - ALWAYS confirm before sending bulk: "This will message X team members. Send it?"
  - Only call after explicit confirmation
- Messages are delivered as real chat messages with push notifications

🔧 ENRICHED TOOL DATA — AVOID REDUNDANT CALLS:
- search_events returns IDs, pay rates, contact info, setup time, staffing counts, visibility, hours status, and notes.
  → Use scope "upcoming" when user asks about upcoming/active/next/pending jobs.
  → Use scope "past" for completed/finished events.
  → No scope = date range window (default 30 past, 60 future).
  → Can also filter by specific status, visibility, hours_status, client, venue, event name.
  → When user asks "who's the contact?" or "what's the pay?" after viewing events, data is already there — do NOT call again.
- get_staff_stats returns a monthly breakdown (byMonth) with events and hours per month.
  → When user asks "how did she do in February vs March?", use the PREVIOUS get_staff_stats result. Do NOT call the tool again.

🚫 DO NOT output EVENT_COMPLETE, EVENT_UPDATE, or other markers. Use the create_event / update_event tools instead.
`;

  const dateContext = getFullSystemContext(timezone);

  // Inject compact manager context (counts + recent names) server-side
  // Replaces the ~3-5K token frontend context blob with ~80-120 tokens
  let compactContext = '';
  if (managerId) {
    try {
      compactContext = await getCompactManagerContext(managerId);
    } catch (error) {
      console.error(`[AI:${config.name}] Failed to fetch compact context:`, error);
    }
  }

  // Put static instructions FIRST (cacheable), dynamic date context LAST (not cached)
  // Include context examples from successful past conversations for learning
  const systemContent = `${systemInstructions}\n\n${dateContext}${compactContext ? '\n\n' + compactContext : ''}${contextExamplesPrompt ? '\n\n' + contextExamplesPrompt : ''}`;

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

  // Send all tools — the model knows which ones it needs.
  // Pre-filtering by keywords was fragile (typos, conjugations, short confirmations broke it).
  const lastUserMsg = extractLastUserMessage(messages);
  console.log(`[AI:${config.name}] Sending all ${AI_TOOLS.length} tools for query: "${lastUserMsg.substring(0, 80)}"`);

  const groqTools = AI_TOOLS.map(tool => ({
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
    temperature: isReasoningModel ? 0.6 : temperature,
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
        const MAX_TOOL_CALLS = 10;
        let toolCalls: any[] = assistantMessage.tool_calls;

        // Cap tool calls to prevent runaway requests (model sometimes requests 40+)
        if (toolCalls.length > MAX_TOOL_CALLS) {
          console.warn(`[AI:${config.name}] Tool call cap: ${toolCalls.length} requested, limiting to ${MAX_TOOL_CALLS}`);
          toolCalls = toolCalls.slice(0, MAX_TOOL_CALLS);
          assistantMessage.tool_calls = toolCalls;
        }

        console.log(`[AI:${config.name}] ${toolCalls.length} tool call(s) requested`);

        if (!managerId) {
          return res.status(401).json({ message: 'Manager ID required for function calls' });
        }

        // Deduplicate identical tool calls (same function + same args → execute once)
        const dedupCache = new Map<string, string>();
        const toolResults = await Promise.all(
          toolCalls.map(async (toolCall: any) => {
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
                  content: `Error: Failed to parse function arguments. The AI provided malformed JSON: ${parseError.message}`
                };
              }

              // Dedup: if same function + same args already executed, reuse result
              const dedupKey = `${functionName}:${JSON.stringify(functionArgs)}`;
              if (dedupCache.has(dedupKey)) {
                console.log(`[AI:${config.name}] Dedup hit for ${functionName} — reusing cached result`);
                return {
                  role: 'tool',
                  tool_call_id: toolCall.id,
                  content: dedupCache.get(dedupKey)!,
                };
              }

              console.log(`[AI:${config.name}] Executing ${functionName}:`, functionArgs);

              const result = await executeFunctionCall(functionName, functionArgs, managerId);
              dedupCache.set(dedupKey, result);

              return {
                role: 'tool',
                tool_call_id: toolCall.id,
                content: result
              };
            } catch (execError: any) {
              console.error(`[AI:${config.name}] Tool execution failed for ${functionName}:`, execError);
              return {
                role: 'tool',
                tool_call_id: toolCall.id,
                content: `Error executing ${functionName}: ${execError.message}`
              };
            }
          })
        );

        // Multi-step tool calling loop (supports chaining e.g. get_clients_list → create_event → publish_event)
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
        // --- finish_reason-driven tool call loop (industry standard) ---
        // Instead of a fixed step count, let the model signal when it's done
        // via finish_reason. Safety cap prevents infinite loops.
        const SAFETY_CAP = 15;
        const TOKEN_BUDGET = 100000; // Stay under Groq's ~128K context window

        // Same model for synthesis — always 120B, no escalation needed.
        let synthesisConfig = config;
        let synthesisModel = requestBody.model;

        const synthesisHeaders = {
          'Authorization': `Bearer ${synthesisConfig.apiKey}`,
          'Content-Type': 'application/json',
        };
        const secondTimeout = (synthesisConfig.supportsReasoning && synthesisModel.includes('gpt-oss')) ? 120000 : 60000;

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
            const tufError = response.data?.error;
            console.log(`[AI:${synthesisConfig.name}] tool_use_failed detected:`, tufError?.message, '| failed_generation:', tufError?.failed_generation?.substring?.(0, 200) || 'none');
            console.log(`[AI:${synthesisConfig.name}] currentMessages structure:`, currentMessages.map((m: any) => ({ role: m.role, hasContent: !!m.content, hasToolCalls: !!m.tool_calls, contentLen: typeof m.content === 'string' ? m.content.length : 0 })));
            console.log(`[AI:${synthesisConfig.name}] tools sent:`, groqTools.length, 'tool names:', groqTools.map((t: any) => t.function?.name).join(', '));

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
                content: `Based on that data and our conversation above, please complete what I asked for. If I gave a short confirmation like "si", "yes", or "do it", look at what you previously proposed and proceed with creating it. Confirm what you created. Do NOT just summarize the data - actually respond to what I asked for.`
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
                  const result = await executeFunctionCall(functionName, functionArgs, managerId);
                  return {
                    role: 'tool',
                    tool_call_id: toolCall.id,
                    content: result
                  };
                } catch (execError: any) {
                  console.error(`[AI:${synthesisConfig.name}] Tool execution failed for ${functionName}:`, execError);
                  return {
                    role: 'tool',
                    tool_call_id: toolCall.id,
                    content: `Error executing ${functionName}: ${execError.message}`
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

          // Include recent conversation context so confirmations like "Si" have meaning.
          // Strip tool_calls from assistant messages to avoid "tool choice is none" errors
          const nonSystemMsgs = processedMessages.filter((m: any) => m.role !== 'system');
          const recentCtx = nonSystemMsgs.slice(-6)
            .filter((m: any) => m.role === 'user' || (m.role === 'assistant' && m.content))
            .map((m: any) => ({ role: m.role, content: typeof m.content === 'string' ? m.content : JSON.stringify(m.content) }));

          // Attempt a synthesis call without tools (same pattern as tool_use_failed fallback)
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
                    content: `Based on our conversation above and these results, summarize what you did. If I gave a short confirmation, look at what you previously proposed. Confirm what was created/updated. Be concise.`
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

        // Persist key tool context (event IDs, PUBLISH INFO) across conversation turns.
        // The model's text response omits IDs (per prompt rules), but subsequent turns need them.
        // Append a hidden TOOL_CONTEXT block that the frontend stores in history but strips from display.
        const toolContextParts: string[] = [];
        for (const msg of currentMessages) {
          if (msg.role === 'tool' && typeof msg.content === 'string') {
            // Extract lines with actionable data (IDs, publish info)
            const lines = msg.content.split('\n');
            for (const line of lines) {
              if (line.includes('PUBLISH INFO') || line.includes('Event ID') || line.includes('event_ids:')) {
                toolContextParts.push(line.trim());
              }
            }
            // Also capture event ID lines from create responses (e.g., "✅ Event created! Event ID: xxx")
            const idMatch = msg.content.match(/Event ID:\s*([a-f0-9]{24})/i);
            if (idMatch) {
              toolContextParts.push(`Event ID: ${idMatch[1]}`);
            }
            // Capture bulk event ID lists
            const bulkIdsMatch = msg.content.match(/Event IDs:\s*(.+)/);
            if (bulkIdsMatch) {
              toolContextParts.push(`Event IDs: ${bulkIdsMatch[1]}`);
            }
          }
        }
        if (toolContextParts.length > 0) {
          const uniqueContext = [...new Set(toolContextParts)];
          finalContent += `\n\n---TOOL_CONTEXT---\n${uniqueContext.join('\n')}`;
          console.log(`[AI:${synthesisConfig.name}] Appended ${uniqueContext.length} tool context lines for cross-turn persistence`);
        }

        console.log(`[AI:${synthesisConfig.name}] Total usage - prompt: ${totalUsage.prompt_tokens}, completion: ${totalUsage.completion_tokens}, reasoning: ${totalUsage.reasoning_tokens}, total: ${totalUsage.total_tokens}`);
        logAIUsage({
          managerId,
          userType: 'manager',
          endpoint: 'chat/message',
          provider: synthesisConfig.name as 'groq' | 'together',
          model: synthesisModel,
          inputTokens: totalUsage.prompt_tokens,
          outputTokens: totalUsage.completion_tokens,
          reasoningTokens: totalUsage.reasoning_tokens,
          totalTokens: totalUsage.total_tokens,
          durationMs: Date.now() - requestStartTime,
          toolCallCount: allToolsUsed.length,
          toolsSelected: AI_TOOLS.length,
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
        managerId,
        userType: 'manager',
        endpoint: 'chat/message',
        provider: config.name as 'groq' | 'together',
        model: requestBody.model,
        inputTokens: totalUsage.prompt_tokens,
        outputTokens: totalUsage.completion_tokens,
        reasoningTokens: totalUsage.reasoning_tokens,
        totalTokens: totalUsage.total_tokens,
        durationMs: Date.now() - requestStartTime,
        toolCallCount: 0,
        toolsSelected: AI_TOOLS.length,
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

/**
 * POST /api/ai/manager/compose-broadcast
 * AI-powered message composition for manager broadcast messages.
 * Supports compose (from instructions) and polish (rewrite existing draft).
 */
router.post('/ai/manager/compose-broadcast', requireAuth, async (req, res) => {
  const composeStartTime = Date.now();
  try {
    const { managerId } = (req as any).authUser;
    if (!managerId) {
      return res.status(403).json({ message: 'Only managers can compose broadcasts' });
    }

    const groqKey = process.env.GROQ_API_KEY;
    if (!groqKey) {
      return res.status(500).json({ message: 'AI service not configured' });
    }

    const schema = z.object({
      message: z.string().min(1).max(5000),
      scenario: z.enum(['compose', 'polish']),
      eventContext: z.object({
        eventName: z.string().nullish(),
        date: z.string().nullish(),
        startTime: z.string().nullish(),
        endTime: z.string().nullish(),
        location: z.string().nullish(),
        clientName: z.string().nullish(),
      }).nullish(),
    });

    const validated = schema.parse(req.body);
    const { message, scenario, eventContext } = validated;

    console.log(`[ai/manager/compose-broadcast] Scenario: ${scenario}, Input length: ${message.length}, Event: ${eventContext?.eventName || 'none'}`);

    // Build event context string for the prompt
    let eventInfo = '';
    if (eventContext) {
      const parts: string[] = [];
      if (eventContext.eventName) parts.push(`Event: ${eventContext.eventName}`);
      if (eventContext.date) parts.push(`Date: ${eventContext.date}`);
      if (eventContext.startTime && eventContext.endTime) parts.push(`Time: ${eventContext.startTime} – ${eventContext.endTime}`);
      else if (eventContext.startTime) parts.push(`Time: ${eventContext.startTime}`);
      if (eventContext.location) parts.push(`Location: ${eventContext.location}`);
      if (eventContext.clientName) parts.push(`Client: ${eventContext.clientName}`);
      if (parts.length > 0) eventInfo = `\n\nEVENT CONTEXT (use these details naturally in the message):\n${parts.join('\n')}`;
    }

    const userPrompt = scenario === 'compose'
      ? `Based on these instructions, compose a professional broadcast message from a manager to their event staff team:\n\n${message}${eventInfo}`
      : `Polish and professionalize this broadcast message from a manager to their staff team:\n\n${message}${eventInfo}`;

    const systemPrompt = `You are a professional communication assistant for event and hospitality managers.

TONE & STYLE:
- Authoritative but warm and approachable
- Clear and direct — staff should know exactly what's expected
- Concise (2-4 sentences for most messages, up to 6 for detailed instructions)
- Professional yet conversational — avoid corporate jargon

COMPOSE MODE (instructions → message):
- Transform manager's casual instructions into a polished staff-facing message
- Include all relevant details (times, dress code, locations, etc.)
- When event context is provided, weave in relevant event details naturally (name, time, location)
- Address staff collectively ("Hi team," or "Hello everyone,")
- End with an encouraging or appreciative note when appropriate

POLISH MODE (draft → improved):
- Maintain the original intent and information
- Improve clarity, tone, and professionalism
- Fix grammar and awkward phrasing
- Keep the manager's voice — don't over-formalize
- If event context is provided, you may incorporate missing details that are relevant

OUTPUT RULES - CRITICAL:
- Return ONLY the message text itself
- NO explanations, meta-commentary, or preambles
- NO quotes around the message
- NO "Here's your message" or similar phrases
- The output should be ready to send as-is`;

    const response = await axios.post(
      'https://api.groq.com/openai/v1/chat/completions',
      {
        model: 'openai/gpt-oss-20b',
        messages: [
          { role: 'system', content: systemPrompt },
          { role: 'user', content: userPrompt },
        ],
        temperature: 0.7,
        max_tokens: 300,
      },
      {
        headers: {
          'Authorization': `Bearer ${groqKey}`,
          'Content-Type': 'application/json',
        },
        timeout: 10000,
      }
    );

    let composedMessage = response.data.choices?.[0]?.message?.content?.trim();
    if (!composedMessage) {
      return res.status(500).json({ message: 'Failed to compose message' });
    }

    // Accumulate usage
    const primaryUsage = response.data.usage;
    let composeInputTokens = primaryUsage?.prompt_tokens || 0;
    let composeOutputTokens = primaryUsage?.completion_tokens || 0;
    let composeTotalTokens = primaryUsage?.total_tokens || 0;

    // Clean up AI fluff — inline version of cleanAIResponse
    const fluffPhrases = [
      /^Here's your message:?\s*/i,
      /^Here's the broadcast:?\s*/i,
      /^Here is the message:?\s*/i,
      /^I'd be happy to help\.?\s*/i,
      /^Sure!?\s*/i,
      /^Of course!?\s*/i,
    ];
    for (const phrase of fluffPhrases) {
      composedMessage = composedMessage.replace(phrase, '');
    }
    composedMessage = composedMessage.replace(/^["'](.*)["']$/s, '$1').trim();

    // Detect language and provide translation if needed
    const isSpanish = /[áéíóúñ¿¡]/i.test(composedMessage);

    let translation = null;
    if (isSpanish) {
      const translationResponse = await axios.post(
        'https://api.groq.com/openai/v1/chat/completions',
        {
          model: 'openai/gpt-oss-20b',
          messages: [
            {
              role: 'system',
              content: 'You are a professional translator. Translate the following message to natural, professional English. Return ONLY the translated text, nothing else.',
            },
            { role: 'user', content: composedMessage },
          ],
          temperature: 0.3,
          max_tokens: 300,
        },
        {
          headers: {
            'Authorization': `Bearer ${groqKey}`,
            'Content-Type': 'application/json',
          },
          timeout: 10000,
        }
      );

      translation = translationResponse.data.choices?.[0]?.message?.content?.trim();
      if (translation) {
        translation = translation.replace(/^["'](.*)["']$/s, '$1').trim();
      }

      const translationUsage = translationResponse.data.usage;
      if (translationUsage) {
        composeInputTokens += translationUsage.prompt_tokens || 0;
        composeOutputTokens += translationUsage.completion_tokens || 0;
        composeTotalTokens += translationUsage.total_tokens || 0;
      }
    }

    console.log(`[ai/manager/compose-broadcast] Success. Length: ${composedMessage.length}, Translation: ${!!translation}`);

    logAIUsage({
      userType: 'manager',
      endpoint: 'compose-broadcast',
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
      language: isSpanish ? 'es' : 'en',
    });
  } catch (err: any) {
    console.error('[ai/manager/compose-broadcast] Error:', err);
    if (err instanceof z.ZodError) {
      return res.status(400).json({ message: 'Invalid request data', errors: err.issues });
    }
    return res.status(500).json({ message: err.message || 'Failed to compose broadcast' });
  }
});

export default router;
