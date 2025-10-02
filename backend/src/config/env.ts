import dotenv from 'dotenv';
dotenv.config();

/**
 * Parses comma-separated values into an array
 * Returns empty array if value is empty or undefined
 */
function parseCommaSeparated(value: string | undefined): string[] {
  if (!value) return [];
  return value.split(',').map(v => v.trim()).filter(Boolean);
}

export const ENV = {
  port: parseInt(process.env.PORT || '4000', 10),
  mongoUri: process.env.MONGO_URI || '',
  nodeEnv: process.env.NODE_ENV || 'development',
  dbFallback: process.env.DB_FALLBACK || '', // set to 'memory' to enable in-memory DB fallback
  allowedOrigins: process.env.ALLOWED_ORIGINS || '',
  // Auth - now supports comma-separated lists for multiple apps
  jwtSecret: process.env.BACKEND_JWT_SECRET || '',
  googleClientIdIos: parseCommaSeparated(process.env.GOOGLE_CLIENT_ID_IOS),
  googleClientIdAndroid: parseCommaSeparated(process.env.GOOGLE_CLIENT_ID_ANDROID),
  googleClientIdWeb: parseCommaSeparated(process.env.GOOGLE_CLIENT_ID_WEB),
  googleServerClientId: parseCommaSeparated(process.env.GOOGLE_SERVER_CLIENT_ID),
  appleBundleId: parseCommaSeparated(process.env.APPLE_BUNDLE_ID),
  // Admin
  adminKey: process.env.ADMIN_KEY || '',
};
