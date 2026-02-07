import { getTestApp, createAuthenticatedManager, createTestClient, createTestRole } from '../helpers';

// Mock socket and notification services
jest.mock('../../socket/server', () => ({
  initSocket: jest.fn(),
  emitToManager: jest.fn(),
  emitToTeams: jest.fn(),
  emitToUser: jest.fn(),
}));
jest.mock('../../services/notificationService', () => ({
  notificationService: { sendToUser: jest.fn(), sendToMultipleUsers: jest.fn() },
}));
jest.mock('../../services/notificationScheduler', () => ({
  notificationScheduler: { initialize: jest.fn(), scheduleEventReminders: jest.fn(), cancelEventReminders: jest.fn() },
}));

describe('Catalog API', () => {
  let app: any;

  beforeEach(async () => {
    app = await getTestApp();
  });

  // ── Clients ──────────────────────────────────────────

  describe('GET /api/clients', () => {
    it('returns 401 without auth', async () => {
      const res = await app.get('/api/clients');
      expect(res.status).toBe(401);
    });

    it('returns empty array for new manager', async () => {
      const { token } = await createAuthenticatedManager();
      const res = await app.get('/api/clients').set('Authorization', `Bearer ${token}`);
      expect(res.status).toBe(200);
      expect(res.body).toEqual([]);
    });

    it('returns only this manager\'s clients', async () => {
      const { manager: m1, token: t1 } = await createAuthenticatedManager();
      const { token: t2 } = await createAuthenticatedManager();
      await createTestClient(m1._id, 'Client A');
      const res1 = await app.get('/api/clients').set('Authorization', `Bearer ${t1}`);
      expect(res1.body.length).toBe(1);
      const res2 = await app.get('/api/clients').set('Authorization', `Bearer ${t2}`);
      expect(res2.body.length).toBe(0);
    });
  });

  describe('POST /api/clients', () => {
    it('creates a client', async () => {
      const { token } = await createAuthenticatedManager();
      const res = await app.post('/api/clients').set('Authorization', `Bearer ${token}`).send({ name: 'Acme' });
      expect(res.status).toBe(201);
      expect(res.body.name).toBe('Acme');
      expect(res.body.id).toBeDefined();
    });

    it('returns 400 for missing name', async () => {
      const { token } = await createAuthenticatedManager();
      const res = await app.post('/api/clients').set('Authorization', `Bearer ${token}`).send({});
      expect(res.status).toBe(400);
    });

    it('returns 409 for duplicate (case-insensitive)', async () => {
      const { token } = await createAuthenticatedManager();
      await app.post('/api/clients').set('Authorization', `Bearer ${token}`).send({ name: 'Acme' });
      const res = await app.post('/api/clients').set('Authorization', `Bearer ${token}`).send({ name: 'acme' });
      expect(res.status).toBe(409);
    });

    it('allows same name for different managers', async () => {
      const { token: t1 } = await createAuthenticatedManager();
      const { token: t2 } = await createAuthenticatedManager();
      const r1 = await app.post('/api/clients').set('Authorization', `Bearer ${t1}`).send({ name: 'Shared' });
      const r2 = await app.post('/api/clients').set('Authorization', `Bearer ${t2}`).send({ name: 'Shared' });
      expect(r1.status).toBe(201);
      expect(r2.status).toBe(201);
    });
  });

  describe('PATCH /api/clients/:id', () => {
    it('updates a client name', async () => {
      const { manager, token } = await createAuthenticatedManager();
      const client = await createTestClient(manager._id, 'Old');
      const res = await app.patch(`/api/clients/${client._id}`).set('Authorization', `Bearer ${token}`).send({ name: 'New' });
      expect(res.status).toBe(200);
      expect(res.body.name).toBe('New');
    });

    it('returns 404 for non-existent client', async () => {
      const { token } = await createAuthenticatedManager();
      const fakeId = '507f1f77bcf86cd799439011';
      const res = await app.patch(`/api/clients/${fakeId}`).set('Authorization', `Bearer ${token}`).send({ name: 'X' });
      expect(res.status).toBe(404);
    });
  });

  describe('DELETE /api/clients/:id', () => {
    it('deletes a client', async () => {
      const { manager, token } = await createAuthenticatedManager();
      const client = await createTestClient(manager._id, 'ToDelete');
      const res = await app.delete(`/api/clients/${client._id}`).set('Authorization', `Bearer ${token}`);
      expect(res.status).toBe(200);
    });

    it('returns 404 for wrong manager\'s client', async () => {
      const { manager: m1 } = await createAuthenticatedManager();
      const { token: t2 } = await createAuthenticatedManager();
      const client = await createTestClient(m1._id, 'NotYours');
      const res = await app.delete(`/api/clients/${client._id}`).set('Authorization', `Bearer ${t2}`);
      expect(res.status).toBe(404);
    });
  });

  // ── Roles ────────────────────────────────────────────

  describe('GET /api/roles', () => {
    it('returns 401 without auth', async () => {
      const res = await app.get('/api/roles');
      expect(res.status).toBe(401);
    });

    it('returns roles list', async () => {
      const { manager, token } = await createAuthenticatedManager();
      await createTestRole(manager._id, 'Server');
      const res = await app.get('/api/roles').set('Authorization', `Bearer ${token}`);
      expect(res.status).toBe(200);
      expect(res.body.length).toBe(1);
    });
  });

  describe('POST /api/roles', () => {
    it('creates a role', async () => {
      const { token } = await createAuthenticatedManager();
      const res = await app.post('/api/roles').set('Authorization', `Bearer ${token}`).send({ name: 'Bartender' });
      expect(res.status).toBe(201);
      expect(res.body.name).toBe('Bartender');
    });

    it('returns 409 for duplicate role', async () => {
      const { token } = await createAuthenticatedManager();
      await app.post('/api/roles').set('Authorization', `Bearer ${token}`).send({ name: 'Bartender' });
      const res = await app.post('/api/roles').set('Authorization', `Bearer ${token}`).send({ name: 'bartender' });
      expect(res.status).toBe(409);
    });

    it('returns 400 for missing name', async () => {
      const { token } = await createAuthenticatedManager();
      const res = await app.post('/api/roles').set('Authorization', `Bearer ${token}`).send({});
      expect(res.status).toBe(400);
    });
  });

  describe('DELETE /api/roles/:id', () => {
    it('deletes a role', async () => {
      const { manager, token } = await createAuthenticatedManager();
      const role = await createTestRole(manager._id, 'ToDelete');
      const res = await app.delete(`/api/roles/${role._id}`).set('Authorization', `Bearer ${token}`);
      expect(res.status).toBe(200);
    });
  });

  // ── Tariffs ──────────────────────────────────────────

  describe('GET /api/tariffs', () => {
    it('returns 401 without auth', async () => {
      const res = await app.get('/api/tariffs');
      expect(res.status).toBe(401);
    });

    it('returns empty array', async () => {
      const { token } = await createAuthenticatedManager();
      const res = await app.get('/api/tariffs').set('Authorization', `Bearer ${token}`);
      expect(res.status).toBe(200);
      expect(res.body).toEqual([]);
    });
  });

  describe('POST /api/tariffs', () => {
    it('creates a tariff', async () => {
      const { manager, token } = await createAuthenticatedManager();
      const client = await createTestClient(manager._id, 'C');
      const role = await createTestRole(manager._id, 'R');
      const res = await app.post('/api/tariffs').set('Authorization', `Bearer ${token}`).send({
        clientId: String(client._id),
        roleId: String(role._id),
        rate: 30,
        currency: 'USD',
      });
      expect(res.status).toBe(201);
      expect(res.body.rate).toBe(30);
    });

    it('returns 404 for non-existent client', async () => {
      const { manager, token } = await createAuthenticatedManager();
      const role = await createTestRole(manager._id, 'R');
      const res = await app.post('/api/tariffs').set('Authorization', `Bearer ${token}`).send({
        clientId: '507f1f77bcf86cd799439011',
        roleId: String(role._id),
        rate: 20,
        currency: 'USD',
      });
      expect(res.status).toBe(404);
    });

    it('returns 400 for missing fields', async () => {
      const { token } = await createAuthenticatedManager();
      const res = await app.post('/api/tariffs').set('Authorization', `Bearer ${token}`).send({});
      expect(res.status).toBe(400);
    });
  });
});
