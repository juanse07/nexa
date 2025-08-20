import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import compression from 'compression';
import pino from 'pino';
import pinoHttp from 'pino-http';

import { ENV } from './config/env';
import { connectToDatabase } from './db/mongoose';
import healthRouter from './routes/health';

const logger = pino({ level: process.env.LOG_LEVEL || 'info' });

async function createServer() {
  const app = express();

  app.use(cors());
  app.use(helmet());
  app.use(compression());
  app.use(express.json({ limit: '2mb' }));
  app.use(pinoHttp({ logger }));

  app.use('/api', healthRouter);

  app.get('/', (_req, res) => {
    res.send('Nexa backend is running');
  });

  return app;
}

async function start() {
  try {
    if (ENV.mongoUri) {
      await connectToDatabase();
      logger.info('Connected to MongoDB');
    } else {
      logger.warn('MONGO_URI not set. Starting without DB connection.');
    }

    const app = await createServer();
    app.listen(ENV.port, () => {
      logger.info(`Server listening on http://localhost:${ENV.port}`);
    });
  } catch (err) {
    logger.error({ err }, 'Failed to start server');
    process.exit(1);
  }
}

void start();
