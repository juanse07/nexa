import mongoose, { Document, Model, Schema } from 'mongoose';

export interface UserDocument extends Document {
  provider: 'google' | 'apple';
  subject: string;
  email?: string;
  name?: string;
  picture?: string;
  createdAt: Date;
  updatedAt: Date;
}

const UserSchema = new Schema<UserDocument>(
  {
    provider: { type: String, required: true, enum: ['google', 'apple'] },
    subject: { type: String, required: true },
    email: { type: String, trim: true },
    name: { type: String, trim: true },
    picture: { type: String, trim: true },
  },
  { timestamps: true }
);

UserSchema.index({ provider: 1, subject: 1 }, { unique: true });

export const UserModel: Model<UserDocument> =
  mongoose.models.User || mongoose.model<UserDocument>('User', UserSchema);


