import mongoose, { Document, Model, Schema } from 'mongoose';

export interface AvailabilityDocument extends Document {
  userKey: string;
  date: string; // ISO date string (YYYY-MM-DD) or similar plain date
  startTime: string; // e.g., HH:mm
  endTime: string; // e.g., HH:mm
  status: 'available' | 'unavailable';
  notes?: string;
  personalEventId?: mongoose.Types.ObjectId;
  source?: 'manual' | 'personal_event';
  createdAt: Date;
  updatedAt: Date;
}

const AvailabilitySchema = new Schema<AvailabilityDocument>(
  {
    userKey: { type: String, required: true, trim: true, index: true },
    date: { type: String, required: true, trim: true },
    startTime: { type: String, required: true, trim: true },
    endTime: { type: String, required: true, trim: true },
    status: { type: String, required: true, enum: ['available', 'unavailable'] },
    notes: { type: String, trim: true },
    personalEventId: { type: Schema.Types.ObjectId, ref: 'PersonalEvent' },
    source: { type: String, enum: ['manual', 'personal_event'] },
  },
  { timestamps: true }
);

AvailabilitySchema.index({ userKey: 1, date: 1, startTime: 1, endTime: 1 }, { unique: true });

export const AvailabilityModel: Model<AvailabilityDocument> =
  mongoose.models.Availability || mongoose.model<AvailabilityDocument>('Availability', AvailabilitySchema, 'availability');


