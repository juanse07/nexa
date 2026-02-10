import mongoose, { Document, Model, Schema } from 'mongoose';

export interface StaffGroupDocument extends Document {
  managerId: mongoose.Types.ObjectId;
  name: string;
  normalizedName: string;
  color?: string;
  createdAt: Date;
  updatedAt: Date;
}

function normalizeName(value: string): string {
  return value.trim().toLowerCase();
}

const StaffGroupSchema = new Schema<StaffGroupDocument>(
  {
    managerId: { type: Schema.Types.ObjectId, ref: 'Manager', required: true, index: true },
    name: { type: String, required: true, trim: true },
    normalizedName: { type: String, required: true, trim: true },
    color: { type: String, trim: true },
  },
  { timestamps: true, collection: 'staffgroups' }
);

StaffGroupSchema.index({ managerId: 1, normalizedName: 1 }, { unique: true });

StaffGroupSchema.pre('validate', function (next) {
  if (this.name) {
    this.name = this.name.trim();
    this.normalizedName = normalizeName(this.name);
  }
  next();
});

export const StaffGroupModel: Model<StaffGroupDocument> =
  mongoose.models.StaffGroup || mongoose.model<StaffGroupDocument>('StaffGroup', StaffGroupSchema);
