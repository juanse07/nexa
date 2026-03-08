import mongoose, { Document, Schema } from 'mongoose';

export interface AttendanceLogDocument extends Document {
  eventId: mongoose.Types.ObjectId;
  managerId: mongoose.Types.ObjectId;
  userKey: string;
  clockInAt: Date;
  clockOutAt?: Date;
  estimatedHours?: number;

  // Location tracking
  clockInLocation?: {
    latitude: number;
    longitude: number;
    accuracy?: number;
    source: 'manual' | 'geofence' | 'voice_assistant' | 'bulk_manager';
  };
  clockOutLocation?: {
    latitude: number;
    longitude: number;
    accuracy?: number;
  };

  // Auto clock-out tracking
  autoClockOut?: boolean;
  autoClockOutReason?: 'shift_end_buffer' | 'forgot_clock_out' | 'manager_override';

  // Manager override for bulk clock-in
  overrideBy?: string;
  overrideNote?: string;

  // Official hours from client sign-in sheet
  sheetSignInTime?: Date;
  sheetSignOutTime?: Date;
  approvedHours?: number;

  // Approval workflow
  status: 'clocked' | 'pending_sheet' | 'sheet_submitted' | 'approved' | 'disputed';
  approvedBy?: string;
  approvedAt?: Date;

  // Notes
  managerNotes?: string;
  discrepancyNote?: string;
}

const attendanceLogSchema = new Schema<AttendanceLogDocument>(
  {
    eventId: { type: Schema.Types.ObjectId, ref: 'Event', required: true, index: true },
    managerId: { type: Schema.Types.ObjectId, ref: 'Manager', required: true, index: true },
    userKey: { type: String, required: true, index: true },
    clockInAt: { type: Date, required: true },
    clockOutAt: { type: Date },
    estimatedHours: { type: Number },

    clockInLocation: {
      latitude: Number,
      longitude: Number,
      accuracy: Number,
      source: { type: String, enum: ['manual', 'geofence', 'voice_assistant', 'bulk_manager'] },
    },
    clockOutLocation: {
      latitude: Number,
      longitude: Number,
      accuracy: Number,
    },

    autoClockOut: { type: Boolean },
    autoClockOutReason: { type: String, enum: ['shift_end_buffer', 'forgot_clock_out', 'manager_override'] },

    overrideBy: { type: String },
    overrideNote: { type: String },

    sheetSignInTime: { type: Date },
    sheetSignOutTime: { type: Date },
    approvedHours: { type: Number },

    status: {
      type: String,
      enum: ['clocked', 'pending_sheet', 'sheet_submitted', 'approved', 'disputed'],
      default: 'clocked',
    },
    approvedBy: { type: String },
    approvedAt: { type: Date },

    managerNotes: { type: String },
    discrepancyNote: { type: String },
  },
  { timestamps: true }
);

// Compound indexes for common query patterns
attendanceLogSchema.index({ eventId: 1, userKey: 1 });                    // Clock-in/out per staff per event
attendanceLogSchema.index({ userKey: 1, clockInAt: -1 });                 // Staff shift history
attendanceLogSchema.index({ managerId: 1, clockInAt: -1 });               // Manager attendance report
attendanceLogSchema.index({ eventId: 1, clockOutAt: 1 });                 // Find active sessions (null clockOutAt)
attendanceLogSchema.index({ managerId: 1, status: 1, clockInAt: -1 });    // Approval workflow

export const AttendanceLogModel = mongoose.model<AttendanceLogDocument>(
  'AttendanceLog',
  attendanceLogSchema
);
