import mongoose, { Document, Model, Schema } from 'mongoose';

export interface RoleRequirement {
  role?: string;
  count?: number;
  call_time?: string;
}

export interface EventDocument extends Document {
  event_name?: string;
  client_name?: string;
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
  roles?: RoleRequirement[];
  pay_rate_info?: string;
  createdAt: Date;
  updatedAt: Date;
}

const RoleRequirementSchema = new Schema<RoleRequirement>(
  {
    role: { type: String },
    count: { type: Number },
    call_time: { type: String },
  },
  { _id: false }
);

const EventSchema = new Schema<EventDocument>(
  {
    event_name: { type: String, trim: true },
    client_name: { type: String, trim: true },
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
    roles: { type: [RoleRequirementSchema], default: [] },
    pay_rate_info: { type: String, trim: true },
  },
  { timestamps: true }
);

export const EventModel: Model<EventDocument> =
  mongoose.models.Event || mongoose.model<EventDocument>('Event', EventSchema);


