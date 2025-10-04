import mongoose, { Document, Model, Schema } from 'mongoose';

export interface ManagerDocument extends Document {
  provider: 'google' | 'apple';
  subject: string;
  email?: string;
  name?: string; // original OAuth full name
  first_name?: string;
  last_name?: string;
  picture?: string; // optional override picture
  app_id?: string; // optional 9-digit app id
  createdAt: Date;
  updatedAt: Date;
}

const ManagerSchema = new Schema<ManagerDocument>(
  {
    provider: { type: String, required: true, enum: ['google', 'apple'] },
    subject: { type: String, required: true },
    email: { type: String, trim: true },
    name: { type: String, trim: true },
    first_name: { type: String, trim: true },
    last_name: { type: String, trim: true },
    picture: { type: String, trim: true },
    app_id: { type: String, trim: true },
  },
  { timestamps: true }
);

ManagerSchema.index({ provider: 1, subject: 1 }, { unique: true });
ManagerSchema.index({ app_id: 1 }, { unique: false, sparse: true });

export const ManagerModel: Model<ManagerDocument> =
  mongoose.models.Manager || mongoose.model<ManagerDocument>('Manager', ManagerSchema);


