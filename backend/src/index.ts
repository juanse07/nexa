import compression from 'compression';
import cors from 'cors';
import express from 'express';
import helmet from 'helmet';
import http from 'http';
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
import syncRouter from './routes/sync';
import chatRouter from './routes/chat';
import aiRouter from './routes/ai';
import staffAiRouter from './routes/staff-ai';
import subscriptionRouter from './routes/subscription';
import placesRouter from './routes/places';
import { initSocket } from './socket/server';
import teamsRouter from './routes/teams';
import invitesRouter from './routes/invites';
import notificationsRouter from './routes/notifications';
import eventChatRouter from './routes/eventChat';
import privacyRouter from './routes/privacy';
import venuesRouter from './routes/venues';
import { notificationScheduler } from './services/notificationScheduler';

const logger = pino({ level: process.env.LOG_LEVEL || 'info' });

async function createServer() {
  const app = express();

  // CORS
  const origins = (ENV.allowedOrigins || '')
    .split(',')
    .map((s) => s.trim())
    .filter((s) => s.length > 0);

  // Allow Cloudflare Pages preview deployments and custom domain
  app.use(
    cors({
      origin: (origin, callback) => {
        // Allow requests with no origin (like mobile apps or Postman)
        if (!origin) return callback(null, true);

        // Allow exact matches from ALLOWED_ORIGINS
        if (origins.includes(origin)) return callback(null, true);

        // Allow localhost for development
        if (origin && origin.match(/^http:\/\/localhost(:\d+)?$/)) {
          return callback(null, true);
        }

        // Allow any Cloudflare Pages subdomain for nexa-web
        if (origin.match(/^https:\/\/[a-z0-9]+\.nexa-web\.pages\.dev$/)) {
          return callback(null, true);
        }

        // Allow custom domain app.nexapymesoft.com
        if (origin === 'https://app.nexapymesoft.com') {
          return callback(null, true);
        }

        // Deny all other origins
        callback(new Error('Not allowed by CORS'));
      },
      credentials: true,
    })
  );
  app.use(helmet());
  app.use(compression());
  app.use(express.json({ limit: '50mb' })); // Increased for sign-in sheet photos
  app.use(express.urlencoded({ limit: '50mb', extended: true }));
  app.use(pinoHttp({ logger }));

  app.use('/api', healthRouter);
  app.use('/api', eventsRouter);
  app.use('/api', eventChatRouter); // Event team chat
  app.use('/api', clientsRouter);
  app.use('/api', rolesRouter);
  app.use('/api', tariffsRouter);
  app.use('/api', usersRouter);
  app.use('/api', managersRouter);
  app.use('/api', teamsRouter);
  app.use('/api', invitesRouter); // Invite endpoints (validate, redeem)
  app.use('/api/chat', chatRouter);
  app.use('/api/auth', authRouter);
  app.use('/api/notifications', notificationsRouter);
  app.use('/api', syncRouter);
  app.use('/api', aiRouter);
  app.use('/api', staffAiRouter);
  app.use('/api', subscriptionRouter);
  app.use('/api', placesRouter);
  app.use('/api', venuesRouter);

  // Privacy and legal pages (served at root, not under /api)
  app.use(privacyRouter);

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

  // Admin maintenance: standardize all event dates to Date objects
  app.post('/api/admin/standardize-dates', async (req, res) => {
    try {
      const provided = (req.headers['x-admin-key'] as string) || (req.query.key as string) || '';
      if (!ENV.adminKey || provided !== ENV.adminKey) {
        return res.status(401).json({ message: 'Unauthorized' });
      }

      const allEvents = await EventModel.find({}).lean();
      let stringDateCount = 0;
      let dateObjectCount = 0;
      let nullDateCount = 0;
      let convertedCount = 0;

      // Analyze current state
      for (const event of allEvents) {
        if (event.date == null) {
          nullDateCount++;
        } else if (typeof event.date === 'string') {
          stringDateCount++;
        } else if (event.date instanceof Date) {
          dateObjectCount++;
        }
      }

      if (stringDateCount === 0) {
        return res.json({
          message: 'All dates are already standardized',
          stats: { stringDates: 0, dateObjects: dateObjectCount, null: nullDateCount }
        });
      }

      // Convert string dates to Date objects
      for (const event of allEvents) {
        if (event.date != null && typeof event.date === 'string') {
          const dateObj = new Date(event.date as string);
          if (!isNaN(dateObj.getTime())) {
            await EventModel.updateOne({ _id: event._id }, { $set: { date: dateObj } });
            convertedCount++;
          }
        }
      }

      return res.json({
        message: `Successfully converted ${convertedCount} dates`,
        converted: convertedCount,
        before: { stringDates: stringDateCount, dateObjects: dateObjectCount },
        after: { stringDates: 0, dateObjects: dateObjectCount + convertedCount }
      });
    } catch (err) {
      return res.status(500).json({ message: 'Failed to standardize dates' });
    }
  });

  app.get('/', (_req, res) => {
    res.send('Tie backend is running');
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

    // Initialize notification scheduler
    notificationScheduler.initialize();
    logger.info('Notification scheduler initialized');

    const app = await createServer();
    const server = http.createServer(app);
    initSocket(server);
    server.listen(ENV.port, '0.0.0.0', () => {
      logger.info(`Server listening on http://localhost:${ENV.port}`);
    });
  } catch (err) {
    logger.error({ err }, 'Failed to start server');
    process.exit(1);
  }
}

void start();
