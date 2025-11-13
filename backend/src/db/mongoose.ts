import mongoose from 'mongoose';
import { ENV } from '../config/env';

/**
 * Builds the MongoDB connection URI with environment-specific database name
 * @returns Complete MongoDB URI with database name
 */
function buildMongoUri(): string {
  if (!ENV.mongoUri) {
    throw new Error('MONGO_URI environment variable is required');
  }

  // Determine database name based on NODE_ENV
  // IMPORTANT: Using 'test' for production because that's where the data is
  const dbName = ENV.nodeEnv === 'production' ? 'test' : 'nexa_test';

  // Parse the URI to append database name
  // MongoDB URIs can have format: mongodb+srv://user:pass@host/[database]?options
  // or: mongodb://user:pass@host:port/[database]?options

  let uri = ENV.mongoUri.trim();

  // Remove trailing slash if present
  if (uri.endsWith('/')) {
    uri = uri.slice(0, -1);
  }

  // Check if URI already has a database name specified
  // Pattern: protocol://credentials@host[/database][?options]
  const protocolMatch = uri.match(/^mongodb(\+srv)?:\/\//);
  if (!protocolMatch) {
    throw new Error('Invalid MongoDB URI format');
  }

  const afterProtocol = uri.substring(protocolMatch[0].length);
  const queryStartIndex = afterProtocol.indexOf('?');

  let baseUri: string;
  let queryString: string = '';

  if (queryStartIndex !== -1) {
    // Split into base and query parameters
    const beforeQuery = afterProtocol.substring(0, queryStartIndex);
    queryString = afterProtocol.substring(queryStartIndex);

    // Remove existing database name if present (after last /)
    const lastSlashIndex = beforeQuery.lastIndexOf('/');
    if (lastSlashIndex !== -1) {
      baseUri = protocolMatch[0] + beforeQuery.substring(0, lastSlashIndex);
    } else {
      baseUri = protocolMatch[0] + beforeQuery;
    }
  } else {
    // No query string, remove existing database name if present
    const lastSlashIndex = afterProtocol.lastIndexOf('/');
    if (lastSlashIndex !== -1) {
      baseUri = protocolMatch[0] + afterProtocol.substring(0, lastSlashIndex);
    } else {
      baseUri = uri;
    }
  }

  // Construct final URI with database name
  const finalUri = `${baseUri}/${dbName}${queryString}`;

  // eslint-disable-next-line no-console
  console.log(`[MongoDB] Connecting to database: ${dbName} (NODE_ENV=${ENV.nodeEnv})`);

  return finalUri;
}

export async function connectToDatabase(): Promise<void> {
  try {
    const uri = buildMongoUri();

    await mongoose.connect(uri, {
      serverSelectionTimeoutMS: 15000,
      maxPoolSize: 50,
      minPoolSize: 10,
      socketTimeoutMS: 45000,
    });

    // eslint-disable-next-line no-console
    console.log('[MongoDB] Successfully connected to database');
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error('[MongoDB] Connection failed:', err);
    throw err as Error;
  }
}
