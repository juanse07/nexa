import mongoose, { Document, Model, Schema } from 'mongoose';

export type FlagType = 'unusual_hours' | 'excessive_duration' | 'late_clock_out' | 'location_mismatch';
export type FlagSeverity = 'low' | 'medium' | 'high';
export type FlagStatus = 'pending' | 'approved' | 'dismissed' | 'investigating';

export interface FlagDetails {
  clockInAt: Date;
  clockOutAt?: Date;
  expectedDurationHours?: number;
  actualDurationHours?: number;
  clockInLocation?: {
    latitude: number;
    longitude: number;
  };
  clockOutLocation?: {
    latitude: number;
    longitude: number;
  };
  venueLocation?: {
    latitude: number;
    longitude: number;
  };
  distanceFromVenueMeters?: number;
}

export interface FlaggedAttendanceDocument extends Document {
  eventId: mongoose.Types.ObjectId;
  managerId: mongoose.Types.ObjectId;
  userKey: string;
  staffName?: string;
  eventName?: string;
  eventDate?: Date;

  flagType: FlagType;
  severity: FlagSeverity;
  details: FlagDetails;

  status: FlagStatus;
  reviewedBy?: string;
  reviewedAt?: Date;
  reviewNotes?: string;

  createdAt: Date;
  updatedAt: Date;
}

const FlagDetailsSchema = new Schema<FlagDetails>(
  {
    clockInAt: { type: Date, required: true },
    clockOutAt: { type: Date },
    expectedDurationHours: { type: Number },
    actualDurationHours: { type: Number },
    clockInLocation: {
      type: new Schema(
        {
          latitude: { type: Number, required: true },
          longitude: { type: Number, required: true },
        },
        { _id: false }
      ),
    },
    clockOutLocation: {
      type: new Schema(
        {
          latitude: { type: Number, required: true },
          longitude: { type: Number, required: true },
        },
        { _id: false }
      ),
    },
    venueLocation: {
      type: new Schema(
        {
          latitude: { type: Number, required: true },
          longitude: { type: Number, required: true },
        },
        { _id: false }
      ),
    },
    distanceFromVenueMeters: { type: Number },
  },
  { _id: false }
);

const FlaggedAttendanceSchema = new Schema<FlaggedAttendanceDocument>(
  {
    eventId: {
      type: Schema.Types.ObjectId,
      ref: 'Event',
      required: true,
      index: true,
    },
    managerId: {
      type: Schema.Types.ObjectId,
      ref: 'Manager',
      required: true,
      index: true,
    },
    userKey: { type: String, required: true, trim: true },
    staffName: { type: String, trim: true },
    eventName: { type: String, trim: true },
    eventDate: { type: Date },

    flagType: {
      type: String,
      enum: ['unusual_hours', 'excessive_duration', 'late_clock_out', 'location_mismatch'],
      required: true,
    },
    severity: {
      type: String,
      enum: ['low', 'medium', 'high'],
      required: true,
    },
    details: { type: FlagDetailsSchema, required: true },

    status: {
      type: String,
      enum: ['pending', 'approved', 'dismissed', 'investigating'],
      default: 'pending',
      required: true,
    },
    reviewedBy: { type: String, trim: true },
    reviewedAt: { type: Date },
    reviewNotes: { type: String, trim: true },
  },
  { timestamps: true }
);

// Compound index for efficient manager dashboard queries
FlaggedAttendanceSchema.index({ managerId: 1, status: 1, createdAt: -1 });

// Index for finding flags by event
FlaggedAttendanceSchema.index({ eventId: 1, userKey: 1 });

export const FlaggedAttendanceModel: Model<FlaggedAttendanceDocument> =
  mongoose.models.FlaggedAttendance ||
  mongoose.model<FlaggedAttendanceDocument>('FlaggedAttendance', FlaggedAttendanceSchema);
