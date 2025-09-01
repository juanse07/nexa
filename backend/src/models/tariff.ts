import mongoose, { Document, Model, Schema } from 'mongoose';

export interface TariffDocument extends Document {
  clientId: mongoose.Types.ObjectId;
  roleId: mongoose.Types.ObjectId;
  rate: number; // hourly or flat, caller-defined semantics
  currency: string; // e.g., USD
  createdAt: Date;
  updatedAt: Date;
}

const TariffSchema = new Schema<TariffDocument>(
  {
    clientId: { type: Schema.Types.ObjectId, ref: 'Client', required: true, index: true },
    roleId: { type: Schema.Types.ObjectId, ref: 'Role', required: true, index: true },
    rate: { type: Number, required: true, min: 0 },
    currency: { type: String, required: true, trim: true, default: 'USD' },
  },
  { timestamps: true }
);

TariffSchema.index({ clientId: 1, roleId: 1 }, { unique: true });

export const TariffModel: Model<TariffDocument> =
  mongoose.models.Tariff || mongoose.model<TariffDocument>('Tariff', TariffSchema, 'tariffs');


