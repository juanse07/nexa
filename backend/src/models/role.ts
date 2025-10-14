import mongoose, { Document, Model, Schema } from 'mongoose';

export interface RoleDocument extends Document {
  managerId: mongoose.Types.ObjectId;
  name: string;
  normalizedName: string;
  createdAt: Date;
  updatedAt: Date;
}

const RoleSchema = new Schema<RoleDocument>(
  {
    managerId: { type: Schema.Types.ObjectId, ref: 'Manager', required: true, index: true },
    name: { type: String, required: true, trim: true },
    normalizedName: { type: String, required: true, trim: true },
  },
  { timestamps: true }
);

RoleSchema.index({ managerId: 1, normalizedName: 1 }, { unique: true });

RoleSchema.pre('validate', function normalizeName(next) {
  if (this.name) {
    this.normalizedName = this.name.trim().toLowerCase();
  }
  next();
});

export const RoleModel: Model<RoleDocument> =
  mongoose.models.Role || mongoose.model<RoleDocument>('Role', RoleSchema, 'roles');

