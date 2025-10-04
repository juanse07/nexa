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
import clientsRouter from './routes/clients';
import eventsRouter from './routes/events';
import healthRouter from './routes/health';
import rolesRouter from './routes/roles';
import managersRouter from './routes/managers';
import tariffsRouter from './routes/tariffs';
import usersRouter from './routes/users';

const logger = pino({ level: process.env.LOG_LEVEL || 'info' });

async function createServer() {
  const app = express();

  // CORS
  const origins = (ENV.allowedOrigins || '')
    .split(',')
    .map((s) => s.trim())
    .filter((s) => s.length > 0);
  app.use(
    cors({
      origin: origins.length > 0 ? origins : undefined,
      credentials: true,
    })
  );
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
  app.use('/api', clientsRouter);
  app.use('/api', rolesRouter);
  app.use('/api', tariffsRouter);
  app.use('/api', usersRouter);
  app.use('/api', managersRouter);
  app.use('/api/auth', authRouter);

  // Admin maintenance: recompute role_stats for all events
  app.post('/api/admin/recompute-role-stats', async (req, res) => {
    try {
      const provided = (req.headers['x-admin-key'] as string) || (req.query.key as string) || '';
      if (!ENV.adminKey || provided !== ENV.adminKey) {
        return res.status(401).json({ message: 'Unauthorized' });
      }

      const events = await EventModel.find().lean();
      let updated = 0;
      for (const ev of events as any[]) {
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
          return { role: r.role, capacity, taken, remaining, is_full: remaining === 0 && capacity > 0 };
        });
        await EventModel.updateOne({ _id: ev._id }, { $set: { role_stats: stats } });
        updated += 1;
      }
      return res.json({ updated });
    } catch (err) {
      return res.status(500).json({ message: 'Failed to recompute role stats' });
    }
  });

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
