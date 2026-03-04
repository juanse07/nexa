import mongoose, { Document, Model, Schema } from 'mongoose';

export interface EventShareLinkDocument extends Document {
  eventId: mongoose.Types.ObjectId;
  managerId: mongoose.Types.ObjectId;
  shortCode: string;
  active: boolean;
  showContactName: boolean;
  showContactPhone: boolean;
  showContactEmail: boolean;
  showManagerPhoto: boolean;
  createdAt: Date;
  updatedAt: Date;
}

const EventShareLinkSchema = new Schema<EventShareLinkDocument>(
  {
    eventId: { type: Schema.Types.ObjectId, ref: 'Event', required: true, index: true },
    managerId: { type: Schema.Types.ObjectId, ref: 'Manager', required: true },
    shortCode: { type: String, required: true, unique: true, index: true, uppercase: true },
    active: { type: Boolean, default: true },
    showContactName: { type: Boolean, default: true },
    showContactPhone: { type: Boolean, default: false },
    showContactEmail: { type: Boolean, default: false },
    showManagerPhoto: { type: Boolean, default: false },
  },
  { timestamps: true }
);

EventShareLinkSchema.index({ eventId: 1, active: 1 });

export const EventShareLinkModel: Model<EventShareLinkDocument> =
  mongoose.models.EventShareLink ||
  mongoose.model<EventShareLinkDocument>('EventShareLink', EventShareLinkSchema);
