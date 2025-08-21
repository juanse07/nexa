import { MongoMemoryServer } from 'mongodb-memory-server';
import mongoose from 'mongoose';
import { ENV } from '../config/env';

let memoryServer: MongoMemoryServer | null = null;

async function connectToMemoryServer(): Promise<void> {
  memoryServer = await MongoMemoryServer.create();
  const uri = memoryServer.getUri();
  await mongoose.connect(uri, {
    serverSelectionTimeoutMS: 15000,
  });
}

export async function connectToDatabase(): Promise<void> {
  if (!ENV.mongoUri) {
    if (ENV.dbFallback === 'memory') {
      await connectToMemoryServer();
      return;
    }
    throw new Error('Missing MONGO_URI and DB_FALLBACK is not set to memory');
  }
  try {
    await mongoose.connect(ENV.mongoUri, {
      serverSelectionTimeoutMS: 15000,
    });
  } catch (err) {
    if (ENV.dbFallback === 'memory') {
      // eslint-disable-next-line no-console
      console.warn('Failed to connect to MongoDB using MONGO_URI. Falling back to in-memory DB. Error:', err);
      await connectToMemoryServer();
      return;
    }
    throw err as Error;
  }
}
