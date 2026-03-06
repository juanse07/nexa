import mongoose, { Document, Model, Schema, Types } from 'mongoose';

export interface PersonalEventDocument extends Document {
  userKey: string;
  title: string;
  date: Date;
  startTime: string;   // HH:mm
  endTime: string;      // HH:mm
  notes?: string;
  location?: string;
  role?: string;        // e.g. "Bartender", "Server"
  client?: string;      // e.g. "Marriott", "Joe's Catering"
  hourlyRate?: number;  // e.g. 25
  currency?: string;    // e.g. "USD", "$"
  availabilityId?: Types.ObjectId;
  createdAt: Date;
  updatedAt: Date;
}

const PersonalEventSchema = new Schema<PersonalEventDocument>(
  {
    userKey: { type: String, required: true, trim: true, index: true },
    title: { type: String, required: true, trim: true },
    date: { type: Date, required: true },
    startTime: { type: String, required: true, trim: true },
    endTime: { type: String, required: true, trim: true },
    notes: { type: String, trim: true },
    location: { type: String, trim: true },
    role: { type: String, trim: true },
    client: { type: String, trim: true },
    hourlyRate: { type: Number },
    currency: { type: String, trim: true, default: '$' },
    availabilityId: { type: Schema.Types.ObjectId, ref: 'Availability' },
  },
  { timestamps: true }
);

PersonalEventSchema.index({ userKey: 1, date: 1 });

export const PersonalEventModel: Model<PersonalEventDocument> =
  mongoose.models.PersonalEvent ||
  mongoose.model<PersonalEventDocument>('PersonalEvent', PersonalEventSchema, 'personal_events');
