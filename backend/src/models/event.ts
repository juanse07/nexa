import mongoose, { Document, Model, Schema } from 'mongoose';

export interface RoleRequirement {
  role: string;
  count: number;
  call_time?: string;
}

export interface ClockLocation {
  latitude: number;
  longitude: number;
  accuracy?: number;
  source: 'manual' | 'geofence' | 'voice_assistant' | 'bulk_manager';
}

export interface AttendanceSession {
  // Digital clock-in/out (reference only)
  clockInAt: Date;
  clockOutAt?: Date;
  estimatedHours?: number;

  // Location tracking for geofence validation
  clockInLocation?: ClockLocation;
  clockOutLocation?: {
    latitude: number;
    longitude: number;
    accuracy?: number;
  };

  // Auto clock-out tracking
  autoClockOut?: boolean;
  autoClockOutReason?: 'shift_end_buffer' | 'forgot_clock_out' | 'manager_override';

  // Manager override for bulk clock-in
  overrideBy?: string;  // Manager userKey who performed bulk clock-in
  overrideNote?: string;

  // Official hours from client sign-in sheet (source of truth)
  sheetSignInTime?: Date;
  sheetSignOutTime?: Date;
  approvedHours?: number;

  // Approval workflow
  status?: 'clocked' | 'pending_sheet' | 'sheet_submitted' | 'approved' | 'disputed';
  approvedBy?: string;
  approvedAt?: Date;

  // Notes and documentation
  managerNotes?: string;
  discrepancyNote?: string;
}

export interface AcceptedStaffMember {
  userKey?: string;
  provider?: string;
  subject?: string;
  email?: string;
  name?: string;
  first_name?: string;
  last_name?: string;
  picture?: string;
  response?: string;
  role?: string;
  respondedAt?: Date | string;
  attendance?: AttendanceSession[];
}

export interface RoleStat {
  role: string;
  capacity: number;
  taken: number;
  remaining: number;
  is_full: boolean;
}

// Stores which role each invited staff member was assigned
// Used for private events where each person gets a specific role
export interface InvitedStaffMember {
  userKey: string;    // "provider:subject" format
  roleId: string;     // The role ID or name they were invited for
  roleName: string;   // Cached role name for display
}

export interface EventDocument extends Document {
  managerId: mongoose.Types.ObjectId;

  // Event lifecycle status
  status: 'draft' | 'published' | 'confirmed' | 'fulfilled' | 'in_progress' | 'completed' | 'cancelled';
  publishedAt?: Date;
  publishedBy?: string;
  fulfilledAt?: Date;

  // Auto-completion control
  keepOpen?: boolean; // If true, prevents automatic status change to 'completed'

  // Event visibility type
  // - private: Only invited staff (has audience_user_keys/audience_team_ids)
  // - public: All staff can see (no invitations)
  // - private_public: Has invitations AND publicly visible to all staff
  visibilityType?: 'private' | 'public' | 'private_public';

  // Notification tracking
  notificationsSent?: {
    preShiftReminder?: boolean;
    forgotClockOut?: boolean;
  };

  // Team chat
  chatEnabled?: boolean;
  chatEnabledAt?: Date;

  shift_name?: string;
  event_name?: string; // Deprecated: for backward compatibility
  client_name?: string;
  third_party_company_name?: string;
  date?: Date | string;
  start_time?: string;
  end_time?: string;
  venue_name?: string;
  venue_address?: string;
  venue_latitude?: number;
  venue_longitude?: number;
  google_maps_url?: string;
  city?: string;
  state?: string;
  country?: string;
  contact_name?: string;
  contact_phone?: string;
  contact_email?: string;
  setup_time?: string;
  uniform?: string;
  notes?: string;
  headcount_total?: number;
  roles: RoleRequirement[];
  pay_rate_info?: string;
  accepted_staff?: AcceptedStaffMember[];
  declined_staff?: AcceptedStaffMember[];
  role_stats?: RoleStat[];
  audience_user_keys?: string[];
  audience_team_ids?: mongoose.Types.ObjectId[];
  invited_staff?: InvitedStaffMember[]; // Role assignments for private event invitations

  // Hours approval workflow
  hoursStatus?: 'pending' | 'sheet_submitted' | 'approved' | 'paid';
  signInSheetPhotoUrl?: string;
  hoursSubmittedBy?: string;
  hoursSubmittedAt?: Date;
  hoursApprovedBy?: string;
  hoursApprovedAt?: Date;

  // Optimistic locking for concurrent updates
  version?: number;

  createdAt: Date;
  updatedAt: Date;
}

const RoleRequirementSchema = new Schema<RoleRequirement>(
  {
    role: { type: String, required: true, trim: true },
    count: { type: Number, required: true, min: 1 },
    call_time: { type: String },
  },
  { _id: false }
);

const AcceptedStaffMemberSchema = new Schema<AcceptedStaffMember>(
  {
    userKey: { type: String, trim: true },
    provider: { type: String, trim: true },
    subject: { type: String, trim: true },
    email: { type: String, trim: true },
    name: { type: String, trim: true },
    first_name: { type: String, trim: true },
    last_name: { type: String, trim: true },
    picture: { type: String, trim: true },
    response: { type: String, trim: true },
    role: { type: String, trim: true },
    respondedAt: { type: Date },
    attendance: {
      type: [
        new Schema<AttendanceSession>(
          {
            clockInAt: { type: Date, required: true },
            clockOutAt: { type: Date },
            estimatedHours: { type: Number },
            // Location tracking for geofence validation
            clockInLocation: {
              type: new Schema(
                {
                  latitude: { type: Number, required: true },
                  longitude: { type: Number, required: true },
                  accuracy: { type: Number },
                  source: {
                    type: String,
                    enum: ['manual', 'geofence', 'voice_assistant', 'bulk_manager'],
                    default: 'manual',
                  },
                },
                { _id: false }
              ),
            },
            clockOutLocation: {
              type: new Schema(
                {
                  latitude: { type: Number, required: true },
                  longitude: { type: Number, required: true },
                  accuracy: { type: Number },
                },
                { _id: false }
              ),
            },
            // Auto clock-out tracking
            autoClockOut: { type: Boolean, default: false },
            autoClockOutReason: {
              type: String,
              enum: ['shift_end_buffer', 'forgot_clock_out', 'manager_override'],
            },
            // Manager override for bulk clock-in
            overrideBy: { type: String, trim: true },
            overrideNote: { type: String, trim: true },
            // Hours from sign-in sheet
            sheetSignInTime: { type: Date },
            sheetSignOutTime: { type: Date },
            approvedHours: { type: Number },
            status: {
              type: String,
              enum: ['clocked', 'pending_sheet', 'sheet_submitted', 'approved', 'disputed'],
            },
            approvedBy: { type: String },
            approvedAt: { type: Date },
            managerNotes: { type: String },
            discrepancyNote: { type: String },
          },
          { _id: false }
        ),
      ],
      default: [],
    },
  },
  { _id: false }
);

const RoleStatSchema = new Schema<RoleStat>(
  {
    role: { type: String, required: true, trim: true },
    capacity: { type: Number, required: true, min: 0 },
    taken: { type: Number, required: true, min: 0 },
    remaining: { type: Number, required: true, min: 0 },
    is_full: { type: Boolean, required: true },
  },
  { _id: false }
);

// Schema for tracking which role each invited user was assigned
const InvitedStaffMemberSchema = new Schema<InvitedStaffMember>(
  {
    userKey: { type: String, required: true, trim: true },
    roleId: { type: String, required: true, trim: true },
    roleName: { type: String, required: true, trim: true },
  },
  { _id: false }
);

const EventSchema = new Schema<EventDocument>(
  {
    managerId: { type: Schema.Types.ObjectId, ref: 'Manager', required: true, index: true },

    // Event lifecycle status
    status: {
      type: String,
      enum: ['draft', 'published', 'confirmed', 'fulfilled', 'in_progress', 'completed', 'cancelled'],
      default: 'draft',
      required: true,
      index: true,
    },
    publishedAt: { type: Date },
    publishedBy: { type: String, trim: true },
    fulfilledAt: { type: Date },

    // Auto-completion control
    keepOpen: { type: Boolean, default: false },

    // Event visibility type
    visibilityType: {
      type: String,
      enum: ['private', 'public', 'private_public'],
      default: 'private',
    },

    shift_name: { type: String, trim: true },
    event_name: { type: String, trim: true }, // Deprecated: for backward compatibility
    client_name: { type: String, trim: true },
    third_party_company_name: { type: String, trim: true },
    date: { type: Date },
    start_time: { type: String, trim: true },
    end_time: { type: String, trim: true },
    venue_name: { type: String, trim: true },
    venue_address: { type: String, trim: true },
    venue_latitude: { type: Number },
    venue_longitude: { type: Number },
    google_maps_url: { type: String, trim: true },
    city: { type: String, trim: true },
    state: { type: String, trim: true },
    country: { type: String, trim: true },
    contact_name: { type: String, trim: true },
    contact_phone: { type: String, trim: true },
    contact_email: { type: String, trim: true },
    setup_time: { type: String, trim: true },
    uniform: { type: String, trim: true },
    notes: { type: String, trim: true },
    headcount_total: { type: Number },
    roles: {
      type: [RoleRequirementSchema],
      required: true,
      validate: {
        validator: function (arr: unknown) {
          return Array.isArray(arr) && arr.length > 0;
        },
        message: 'At least one role is required',
      },
    },
    pay_rate_info: { type: String, trim: true },
    accepted_staff: { type: [AcceptedStaffMemberSchema], default: [] },
    declined_staff: { type: [AcceptedStaffMemberSchema], default: [] },
    role_stats: { type: [RoleStatSchema], default: [] },
    audience_user_keys: { type: [String], default: [] },
    audience_team_ids: { type: [Schema.Types.ObjectId], ref: 'Team', default: [] },
    invited_staff: { type: [InvitedStaffMemberSchema], default: [] },

    // Hours approval workflow
    hoursStatus: {
      type: String,
      enum: ['pending', 'sheet_submitted', 'approved', 'paid'],
      default: 'pending',
    },
    signInSheetPhotoUrl: { type: String, trim: true },
    hoursSubmittedBy: { type: String, trim: true },
    hoursSubmittedAt: { type: Date },
    hoursApprovedBy: { type: String, trim: true },
    hoursApprovedAt: { type: Date },

    // Notification tracking
    notificationsSent: {
      type: {
        preShiftReminder: { type: Boolean, default: false },
        forgotClockOut: { type: Boolean, default: false },
      },
      default: {},
    },

    // Team chat
    chatEnabled: { type: Boolean, default: false },
    chatEnabledAt: { type: Date },

    // Optimistic locking for concurrent updates
    version: { type: Number, default: 0, min: 0 },
  },
  { timestamps: true }
);

// Compound index for efficient filtering by manager and status
EventSchema.index({ managerId: 1, status: 1 });

// Index for efficient lookups when checking user acceptance
// Sparse index because not all events have accepted_staff
EventSchema.index({ 'accepted_staff.userKey': 1 }, { sparse: true });

// Index for efficient date-based queries (published events)
EventSchema.index({ status: 1, date: 1 });

export const EventModel: Model<EventDocument> =
  mongoose.models.Event || mongoose.model<EventDocument>('Event', EventSchema, 'shifts');
