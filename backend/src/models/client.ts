import mongoose, { Document, Model, Schema } from 'mongoose';

export interface ClientDocument extends Document {
  managerId: mongoose.Types.ObjectId;
  name: string;
  normalizedName: string;
  createdAt: Date;
  updatedAt: Date;
}

const ClientSchema = new Schema<ClientDocument>(
  {
    managerId: { type: Schema.Types.ObjectId, ref: 'Manager', required: true, index: true },
    name: { type: String, required: true, trim: true },
    normalizedName: { type: String, required: true, trim: true },
  },
  { timestamps: true }
);

ClientSchema.index({ managerId: 1, normalizedName: 1 }, { unique: true });

ClientSchema.pre('validate', function normalizeName(next) {
  if (this.name) {
    this.normalizedName = this.name.trim().toLowerCase();
  }
  next();
});

export const ClientModel: Model<ClientDocument> =
  mongoose.models.Client || mongoose.model<ClientDocument>('Client', ClientSchema, 'clients');

