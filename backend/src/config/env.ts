import * as dotenv from 'dotenv';
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
  allowedOrigins: process.env.ALLOWED_ORIGINS || '',
  // Auth - now supports comma-separated lists for multiple apps
  jwtSecret: process.env.BACKEND_JWT_SECRET || '',
  googleClientIdIos: parseCommaSeparated(process.env.GOOGLE_CLIENT_ID_IOS),
  googleClientIdAndroid: parseCommaSeparated(process.env.GOOGLE_CLIENT_ID_ANDROID),
  googleClientIdWeb: parseCommaSeparated(process.env.GOOGLE_CLIENT_ID_WEB),
  googleServerClientId: parseCommaSeparated(process.env.GOOGLE_SERVER_CLIENT_ID),
  appleBundleId: parseCommaSeparated(process.env.APPLE_BUNDLE_ID),
  appleServiceId: parseCommaSeparated(process.env.APPLE_SERVICE_ID),
  // Admin
  adminKey: process.env.ADMIN_KEY || '',
  // Firebase Admin SDK (for phone auth)
  firebaseProjectId: process.env.FIREBASE_PROJECT_ID || '',
  firebaseClientEmail: process.env.FIREBASE_CLIENT_EMAIL || '',
  firebasePrivateKey: process.env.FIREBASE_PRIVATE_KEY || '',

  // Cloudflare R2 Storage
  r2AccountId: process.env.R2_ACCOUNT_ID || '',
  r2AccessKeyId: process.env.R2_ACCESS_KEY_ID || '',
  r2SecretAccessKey: process.env.R2_SECRET_ACCESS_KEY || '',
  r2BucketName: process.env.R2_BUCKET_NAME || 'nexa-files',
  r2PublicUrl: process.env.R2_PUBLIC_URL || '', // e.g., https://pub-xxx.r2.dev or custom domain
};
