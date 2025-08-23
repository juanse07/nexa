import dotenv from 'dotenv';
dotenv.config();

export const ENV = {
  port: parseInt(process.env.PORT || '4000', 10),
  mongoUri: process.env.MONGO_URI || '',
  nodeEnv: process.env.NODE_ENV || 'development',
  dbFallback: process.env.DB_FALLBACK || '', // set to 'memory' to enable in-memory DB fallback
  // Auth
  jwtSecret: process.env.BACKEND_JWT_SECRET || '',
  googleClientIdIos: process.env.GOOGLE_CLIENT_ID_IOS || '',
  googleClientIdAndroid: process.env.GOOGLE_CLIENT_ID_ANDROID || '',
  googleClientIdWeb: process.env.GOOGLE_CLIENT_ID_WEB || '',
  appleBundleId: process.env.APPLE_BUNDLE_ID || '',
};
