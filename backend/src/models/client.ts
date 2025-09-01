import mongoose, { Document, Model, Schema } from 'mongoose';

export interface ClientDocument extends Document {
  name: string;
  normalizedName: string;
  createdAt: Date;
  updatedAt: Date;
}

const ClientSchema = new Schema<ClientDocument>(
  {
    name: { type: String, required: true, trim: true },
    normalizedName: { type: String, required: true, trim: true, index: true, unique: true },
  },
  { timestamps: true }
);

ClientSchema.pre('validate', function normalizeName(next) {
  if (this.name) {
    this.normalizedName = this.name.trim().toLowerCase();
  }
  next();
});

export const ClientModel: Model<ClientDocument> =
  mongoose.models.Client || mongoose.model<ClientDocument>('Client', ClientSchema, 'clients');


