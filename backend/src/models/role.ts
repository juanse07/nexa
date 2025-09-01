import mongoose, { Document, Model, Schema } from 'mongoose';

export interface RoleDocument extends Document {
  name: string;
  normalizedName: string;
  createdAt: Date;
  updatedAt: Date;
}

const RoleSchema = new Schema<RoleDocument>(
  {
    name: { type: String, required: true, trim: true },
    normalizedName: { type: String, required: true, trim: true, unique: true, index: true },
  },
  { timestamps: true }
);

RoleSchema.pre('validate', function normalizeName(next) {
  if (this.name) {
    this.normalizedName = this.name.trim().toLowerCase();
  }
  next();
});

export const RoleModel: Model<RoleDocument> =
  mongoose.models.Role || mongoose.model<RoleDocument>('Role', RoleSchema, 'roles');


