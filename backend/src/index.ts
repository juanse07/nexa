import compression from 'compression';
import cors from 'cors';
import express from 'express';
import helmet from 'helmet';
import pino from 'pino';
import pinoHttp from 'pino-http';

import mongoose from 'mongoose';
import { ENV } from './config/env';
import { connectToDatabase } from './db/mongoose';
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
  app.use('/api', eventsRouter);

  app.get('/', (_req, res) => {
    res.send('Nexa backend is running');
  });

  // Health check route
app.get('/healthz', (_req, res) => {
  res.status(200).send('ok');
});

const port = Number(process.env.PORT || 4000);
app.listen(port, '0.0.0.0', () => console.log(`Server on ${port}`));

// connect to Mongo after server starts; don't exit on error

(async () => {
  try {
    await mongoose.connect(process.env.MONGODB_URI!);
    console.log('Mongo connected');
  } catch (e:any) {
    console.error('Mongo connect failed:', e.message);
    // optionally: retry later instead of exiting
  }
})();
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
