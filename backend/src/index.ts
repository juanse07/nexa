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
      const withStats = (events || []).map((ev: any) => {
        const accepted = ev.accepted_staff || [];
        const roleToAcceptedCount = accepted.reduce((acc: Record<string, number>, m: any) => {
          const key = (m?.role || '').toLowerCase();
          if (!key) return acc;
          acc[key] = (acc[key] || 0) + 1;
          return acc;
        }, {} as Record<string, number>);
        const stats = (ev.roles || []).map((r: any) => {
          const key = (r?.role || '').toLowerCase();
          const capacity = r?.count || 0;
          const taken = roleToAcceptedCount[key] || 0;
          const remaining = Math.max(capacity - taken, 0);
          return {
            role: r.role,
            capacity,
            taken,
            remaining,
          };
        });
        return { ...ev, role_stats: stats };
      });
      res.json(withStats);
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
