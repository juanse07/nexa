import mongoose from 'mongoose';
import { ENV } from '../config/env';

export async function connectToDatabase(): Promise<void> {
  if (!ENV.mongoUri) {
    throw new Error('Missing MONGO_URI in environment');
  }
  await mongoose.connect(ENV.mongoUri, {
    serverSelectionTimeoutMS: 15000,
  });
}
