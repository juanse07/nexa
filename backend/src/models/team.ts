import mongoose, { Document, Model, Schema } from 'mongoose';

export interface TeamDocument extends Document {
  managerId: mongoose.Types.ObjectId;
  name: string;
  normalizedName: string;
  description?: string;
  createdAt: Date;
  updatedAt: Date;
}

function normalizeName(value: string): string {
  return value.trim().toLowerCase();
}

const TeamSchema = new Schema<TeamDocument>(
  {
    managerId: { type: Schema.Types.ObjectId, ref: 'Manager', required: true, index: true },
    name: { type: String, required: true, trim: true },
    normalizedName: { type: String, required: true, trim: true },
    description: { type: String, trim: true },
  },
  { timestamps: true }
);

TeamSchema.index({ managerId: 1, normalizedName: 1 }, { unique: true });

TeamSchema.pre('validate', function (next) {
  if (this.name) {
    this.name = this.name.trim();
    this.normalizedName = normalizeName(this.name);
  }
  next();
});

export const TeamModel: Model<TeamDocument> =
  mongoose.models.Team || mongoose.model<TeamDocument>('Team', TeamSchema);

export { normalizeName as normalizeTeamName };
