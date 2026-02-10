import mongoose, { Document, Model, Schema } from 'mongoose';

export interface StaffProfileDocument extends Document {
  managerId: mongoose.Types.ObjectId;
  userKey: string; // provider:subject
  notes: string;
  rating: number; // 1-5, 0 = unrated
  isFavorite: boolean;
  groupIds: mongoose.Types.ObjectId[];
  createdAt: Date;
  updatedAt: Date;
}

const StaffProfileSchema = new Schema<StaffProfileDocument>(
  {
    managerId: { type: Schema.Types.ObjectId, ref: 'Manager', required: true },
    userKey: { type: String, required: true, trim: true },
    notes: { type: String, default: '' },
    rating: { type: Number, default: 0, min: 0, max: 5 },
    isFavorite: { type: Boolean, default: false },
    groupIds: { type: [Schema.Types.ObjectId], ref: 'StaffGroup', default: [] },
  },
  { timestamps: true, collection: 'staffprofiles' }
);

StaffProfileSchema.index({ managerId: 1, userKey: 1 }, { unique: true });
StaffProfileSchema.index({ managerId: 1, isFavorite: 1 });
StaffProfileSchema.index({ managerId: 1, groupIds: 1 });

export const StaffProfileModel: Model<StaffProfileDocument> =
  mongoose.models.StaffProfile || mongoose.model<StaffProfileDocument>('StaffProfile', StaffProfileSchema);
