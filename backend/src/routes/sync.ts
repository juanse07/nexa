import { Router } from 'express';
import { EventModel } from '../models/event';
import { UserModel } from '../models/user';
import { ClientModel } from '../models/client';
import { RoleModel } from '../models/role';
import { TariffModel } from '../models/tariff';

const router = Router();

// Server-Sent Events endpoint for real-time Change Streams
router.get('/sync/stream', async (req, res) => {
  // Set headers for SSE
  res.setHeader('Content-Type', 'text/event-stream');
  res.setHeader('Cache-Control', 'no-cache');
  res.setHeader('Connection', 'keep-alive');
  res.setHeader('X-Accel-Buffering', 'no'); // Disable nginx buffering

  // Send initial connection message
  res.write('data: {"type":"connected"}\n\n');

  // Set up Change Streams for all collections
  const eventStream = EventModel.watch([], { fullDocument: 'updateLookup' });
  const userStream = UserModel.watch([], { fullDocument: 'updateLookup' });
  const clientStream = ClientModel.watch([], { fullDocument: 'updateLookup' });
  const roleStream = RoleModel.watch([], { fullDocument: 'updateLookup' });
  const tariffStream = TariffModel.watch([], { fullDocument: 'updateLookup' });

  // Handle changes for events
  eventStream.on('change', (change) => {
    try {
      const message = {
        type: 'change',
        collection: 'events',
        operationType: change.operationType,
        documentId: change.documentKey?._id,
        fullDocument: change.fullDocument,
        timestamp: new Date().toISOString(),
      };
      res.write(`data: ${JSON.stringify(message)}\n\n`);
    } catch (err) {
      // eslint-disable-next-line no-console
      console.error('Error sending event change:', err);
    }
  });

  // Handle changes for users
  userStream.on('change', (change) => {
    try {
      const message = {
        type: 'change',
        collection: 'users',
        operationType: change.operationType,
        documentId: change.documentKey?._id,
        fullDocument: change.fullDocument,
        timestamp: new Date().toISOString(),
      };
      res.write(`data: ${JSON.stringify(message)}\n\n`);
    } catch (err) {
      // eslint-disable-next-line no-console
      console.error('Error sending user change:', err);
    }
  });

  // Handle changes for clients
  clientStream.on('change', (change) => {
    try {
      const message = {
        type: 'change',
        collection: 'clients',
        operationType: change.operationType,
        documentId: change.documentKey?._id,
        fullDocument: change.fullDocument,
        timestamp: new Date().toISOString(),
      };
      res.write(`data: ${JSON.stringify(message)}\n\n`);
    } catch (err) {
      // eslint-disable-next-line no-console
      console.error('Error sending client change:', err);
    }
  });

  // Handle changes for roles
  roleStream.on('change', (change) => {
    try {
      const message = {
        type: 'change',
        collection: 'roles',
        operationType: change.operationType,
        documentId: change.documentKey?._id,
        fullDocument: change.fullDocument,
        timestamp: new Date().toISOString(),
      };
      res.write(`data: ${JSON.stringify(message)}\n\n`);
    } catch (err) {
      // eslint-disable-next-line no-console
      console.error('Error sending role change:', err);
    }
  });

  // Handle changes for tariffs
  tariffStream.on('change', (change) => {
    try {
      const message = {
        type: 'change',
        collection: 'tariffs',
        operationType: change.operationType,
        documentId: change.documentKey?._id,
        fullDocument: change.fullDocument,
        timestamp: new Date().toISOString(),
      };
      res.write(`data: ${JSON.stringify(message)}\n\n`);
    } catch (err) {
      // eslint-disable-next-line no-console
      console.error('Error sending tariff change:', err);
    }
  });

  // Send heartbeat every 30 seconds to keep connection alive
  const heartbeat = setInterval(() => {
    res.write(': heartbeat\n\n');
  }, 30000);

  // Clean up on client disconnect
  req.on('close', () => {
    clearInterval(heartbeat);
    eventStream.close();
    userStream.close();
    clientStream.close();
    roleStream.close();
    tariffStream.close();
  });
});

export default router;
