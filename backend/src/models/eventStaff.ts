import mongoose, { Document, Schema } from 'mongoose';

export interface EventStaffDocument extends Document {
  eventId: mongoose.Types.ObjectId;
  managerId: mongoose.Types.ObjectId;
  userKey: string;
  provider?: string;
  subject?: string;
  email?: string;
  name?: string;
  first_name?: string;
  last_name?: string;
  picture?: string;
  response: 'accept' | 'decline';
  role?: string;
  respondedAt?: Date;
}

const eventStaffSchema = new Schema<EventStaffDocument>(
  {
    eventId: { type: Schema.Types.ObjectId, ref: 'Event', required: true },
    managerId: { type: Schema.Types.ObjectId, required: true },
    userKey: { type: String, required: true },
    provider: { type: String },
    subject: { type: String },
    email: { type: String },
    name: { type: String },
    first_name: { type: String },
    last_name: { type: String },
    picture: { type: String },
    response: { type: String, enum: ['accept', 'decline'], required: true },
    role: { type: String },
    respondedAt: { type: Date },
  },
  { timestamps: true }
);

// One entry per staff per event (prevents duplicate accept/decline)
eventStaffSchema.index({ eventId: 1, userKey: 1 }, { unique: true });

// Capacity check: count accepted staff per role for an event
eventStaffSchema.index({ eventId: 1, response: 1, role: 1 });

// "My shifts" query — staff looking up their accepted/declined events
eventStaffSchema.index({ userKey: 1, response: 1 });

// Manager-scoped staff queries
eventStaffSchema.index({ managerId: 1, userKey: 1, response: 1 });

// Staff shift history sorted by respondedAt
eventStaffSchema.index({ userKey: 1, respondedAt: -1 });

export const EventStaffModel = mongoose.model<EventStaffDocument>(
  'EventStaff',
  eventStaffSchema
);
