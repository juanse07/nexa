import mongoose, { Document, Model, Schema } from 'mongoose';

export interface RoleRequirement {
  role: string;
  count: number;
  call_time?: string;
}

export interface AttendanceSession {
  clockInAt: Date;
  clockOutAt?: Date;
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

export interface EventDocument extends Document {
  event_name?: string;
  client_name?: string;
  third_party_company_name?: string;
  date?: Date | string;
  start_time?: string;
  end_time?: string;
  venue_name?: string;
  venue_address?: string;
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

const EventSchema = new Schema<EventDocument>(
  {
    event_name: { type: String, trim: true },
    client_name: { type: String, trim: true },
    third_party_company_name: { type: String, trim: true },
    date: { type: Date },
    start_time: { type: String, trim: true },
    end_time: { type: String, trim: true },
    venue_name: { type: String, trim: true },
    venue_address: { type: String, trim: true },
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
  },
  { timestamps: true }
);

export const EventModel: Model<EventDocument> =
  mongoose.models.Event || mongoose.model<EventDocument>('Event', EventSchema);


