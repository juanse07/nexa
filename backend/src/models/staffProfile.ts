import mongoose, { Document, Model, Schema } from 'mongoose';

export interface StaffProfileDocument extends Document {
  managerId: mongoose.Types.ObjectId;
  userKey: string; // provider:subject
  notes: string;
  rating: number; // 1-5, 0 = unrated
  isFavorite: boolean;
  groupIds: mongoose.Types.ObjectId[];
  // Payroll fields (merged from EmployeePayrollMapping)
  externalEmployeeId?: string;   // ADP File Number or Paychex Employee ID
  workerType?: 'w2' | '1099';
  department?: string;
  earningsCode?: string;
  // Smart scheduling fields
  skills?: string[];   // manager-confirmed skill tags, freeform, max 50
  certifications?: Array<{
    name: string;
    expiryDate?: Date;
    verifiedAt?: Date;     // when manager confirmed
  }>;
  preferredRoles?: string[];   // manager-assigned role preferences
  createdAt: Date;
  updatedAt: Date;
}

const StaffProfileSchema = new Schema<StaffProfileDocument>(
  {
    managerId: { type: Schema.Types.ObjectId, ref: 'Manager', required: true },
    userKey: { type: String, required: true, trim: true },
    notes: { type: String, default: '' },
    rating: { type: Number, default: 0, min: 0, max: 5 },
    isFavorite: { type: Boolean, default: false },
    groupIds: { type: [Schema.Types.ObjectId], ref: 'StaffGroup', default: [] },
    // Payroll fields (merged from EmployeePayrollMapping)
    externalEmployeeId: { type: String, trim: true },
    workerType: { type: String, enum: ['w2', '1099'] },
    department: { type: String, trim: true },
    earningsCode: { type: String, trim: true },
    // Smart scheduling fields
    skills: {
      type: [String],
      default: [],
      validate: [(v: string[]) => v.length <= 50, 'Maximum 50 skills allowed'],
    },
    certifications: [{
      name: { type: String, required: true, trim: true },
      expiryDate: { type: Date },
      verifiedAt: { type: Date },
      _id: false,
    }],
    preferredRoles: { type: [String], default: [] },
  },
  { timestamps: true, collection: 'staffprofiles' }
);

StaffProfileSchema.index({ managerId: 1, userKey: 1 }, { unique: true });
StaffProfileSchema.index({ managerId: 1, isFavorite: 1 });
StaffProfileSchema.index({ managerId: 1, groupIds: 1 });
StaffProfileSchema.index({ managerId: 1, skills: 1 });

export const StaffProfileModel: Model<StaffProfileDocument> =
  mongoose.models.StaffProfile || mongoose.model<StaffProfileDocument>('StaffProfile', StaffProfileSchema);
