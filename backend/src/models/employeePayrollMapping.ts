import mongoose, { Document, Model, Schema } from 'mongoose';

export type PayrollProvider = 'adp' | 'paychex' | 'gusto';
export type WorkerType = 'w2' | '1099';

export interface EmployeePayrollMappingDocument extends Document {
  managerId: mongoose.Types.ObjectId;
  userKey: string;              // FlowShift staff identifier (provider:subject)
  staffName: string;            // Cached name for display
  provider: PayrollProvider;
  externalEmployeeId: string;   // ADP File Number, Paychex Employee ID, etc.
  workerType: WorkerType;
  department?: string;          // ADP department code
  earningsCode?: string;        // Override default REG earnings code
  createdAt: Date;
  updatedAt: Date;
}

const EmployeePayrollMappingSchema = new Schema<EmployeePayrollMappingDocument>(
  {
    managerId: {
      type: Schema.Types.ObjectId,
      ref: 'Manager',
      required: true,
      index: true,
    },
    userKey: {
      type: String,
      required: true,
      trim: true,
    },
    staffName: {
      type: String,
      trim: true,
      default: '',
    },
    provider: {
      type: String,
      required: true,
      enum: ['adp', 'paychex', 'gusto'],
    },
    externalEmployeeId: {
      type: String,
      required: true,
      trim: true,
    },
    workerType: {
      type: String,
      required: true,
      enum: ['w2', '1099'],
      default: 'w2',
    },
    department: {
      type: String,
      trim: true,
    },
    earningsCode: {
      type: String,
      trim: true,
    },
  },
  { timestamps: true },
);

// One mapping per staff member per provider per manager
EmployeePayrollMappingSchema.index(
  { managerId: 1, userKey: 1, provider: 1 },
  { unique: true },
);

export const EmployeePayrollMappingModel: Model<EmployeePayrollMappingDocument> =
  mongoose.models.EmployeePayrollMapping ||
  mongoose.model<EmployeePayrollMappingDocument>(
    'EmployeePayrollMapping',
    EmployeePayrollMappingSchema,
    'employee_payroll_mappings',
  );
