import mongoose, { Document, Model, Schema } from 'mongoose';

export interface VenueDocument extends Document {
  managerId: mongoose.Types.ObjectId;
  name: string;
  normalizedName: string;
  address: string;
  city: string;
  state?: string;
  country?: string;
  placeId?: string;
  latitude?: number;
  longitude?: number;
  source: 'manual' | 'ai' | 'places';
  createdAt: Date;
  updatedAt: Date;
}

const VenueSchema = new Schema<VenueDocument>(
  {
    managerId: { type: Schema.Types.ObjectId, ref: 'Manager', required: true, index: true },
    name: { type: String, required: true, trim: true },
    normalizedName: { type: String, required: true, trim: true },
    address: { type: String, required: true, trim: true },
    city: { type: String, required: true, trim: true },
    state: { type: String, trim: true },
    country: { type: String, trim: true },
    placeId: { type: String, trim: true },
    latitude: { type: Number },
    longitude: { type: Number },
    source: {
      type: String,
      enum: ['manual', 'ai', 'places'],
      default: 'manual',
    },
  },
  { timestamps: true }
);

// Compound index for unique venue names per manager
VenueSchema.index({ managerId: 1, normalizedName: 1 }, { unique: true });

// Index for location-based queries
VenueSchema.index({ managerId: 1, city: 1 });

// Pre-validate hook to normalize the name
VenueSchema.pre('validate', function normalizeName(next) {
  if (this.name) {
    this.normalizedName = this.name.trim().toLowerCase();
  }
  next();
});

export const VenueModel: Model<VenueDocument> =
  mongoose.models.Venue || mongoose.model<VenueDocument>('Venue', VenueSchema, 'venues');
