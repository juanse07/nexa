import dotenv from 'dotenv';
dotenv.config();

export const ENV = {
  port: parseInt(process.env.PORT || '4000', 10),
  mongoUri: process.env.MONGO_URI || '',
  nodeEnv: process.env.NODE_ENV || 'development',
  dbFallback: process.env.DB_FALLBACK || '', // set to 'memory' to enable in-memory DB fallback
};
