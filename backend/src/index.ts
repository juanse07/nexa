import compression from 'compression';
import cors from 'cors';
import express from 'express';
import helmet from 'helmet';
import pino from 'pino';
import pinoHttp from 'pino-http';

import { ENV } from './config/env';
import { connectToDatabase } from './db/mongoose';
import { EventModel } from './models/event';
import authRouter from './routes/auth';
import eventsRouter from './routes/events';
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
  // Direct handler for listing events to avoid any routing ambiguity
  app.get('/api/events', async (_req, res) => {
    try {
      const events = await EventModel.find().sort({ createdAt: -1 }).lean();
      res.json(events);
    } catch (err) {
      res.status(500).json({ error: 'Internal Server Error' });
    }
  });
  app.use('/api', eventsRouter);
  app.use('/api/auth', authRouter);

  app.get('/', (_req, res) => {
    res.send('Nexa backend is running');
  });

  // Health check route
app.get('/healthz', (_req, res) => {
  res.status(200).send('ok');
});
  return app;
}

async function start() {
  try {
    await connectToDatabase();
    logger.info('DB initialized');

    const app = await createServer();
    app.listen(ENV.port, '0.0.0.0', () => {
      logger.info(`Server listening on http://localhost:${ENV.port}`);
    });
  } catch (err) {
    logger.error({ err }, 'Failed to start server');
    process.exit(1);
  }
}

void start();
