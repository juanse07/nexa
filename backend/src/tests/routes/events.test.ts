import { getTestApp, createAuthenticatedManager, createAuthenticatedStaffUser, createTestEvent } from '../helpers';

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

describe('Events API', () => {
  let app: any;

  beforeEach(async () => {
    app = await getTestApp();
  });

  // ── POST /api/events ─────────────────────────────────

  describe('POST /api/events', () => {
    it('returns 401 without auth', async () => {
      const res = await app.post('/api/events').send({});
      expect(res.status).toBe(401);
    });

    it('creates an event with valid data', async () => {
      const { token } = await createAuthenticatedManager();
      const res = await app.post('/api/events').set('Authorization', `Bearer ${token}`).send({
        event_name: 'Gala',
        client_name: 'Acme',
        date: '2025-12-20',
        start_time: '18:00',
        end_time: '23:00',
        roles: [{ role: 'Server', count: 3 }],
      });
      expect(res.status).toBe(201);
      expect(res.body.event_name).toBe('Gala');
      expect(res.body.roles).toHaveLength(1);
    });

    it('returns 400 for missing roles', async () => {
      const { token } = await createAuthenticatedManager();
      const res = await app.post('/api/events').set('Authorization', `Bearer ${token}`).send({
        event_name: 'No Roles',
      });
      expect(res.status).toBe(400);
    });

    it('returns 400 for role count < 1', async () => {
      const { token } = await createAuthenticatedManager();
      const res = await app.post('/api/events').set('Authorization', `Bearer ${token}`).send({
        event_name: 'Bad Count',
        roles: [{ role: 'Server', count: 0 }],
      });
      expect(res.status).toBe(400);
    });
  });

  // ── GET /api/events ──────────────────────────────────

  describe('GET /api/events', () => {
    it('returns 401 without auth', async () => {
      const res = await app.get('/api/events');
      expect(res.status).toBe(401);
    });

    it('returns empty events for new manager', async () => {
      const { token } = await createAuthenticatedManager();
      const res = await app.get('/api/events').set('Authorization', `Bearer ${token}`);
      expect(res.status).toBe(200);
      expect(res.body.events).toEqual([]);
    });

    it('isolates events between managers', async () => {
      const { manager: m1, token: t1 } = await createAuthenticatedManager();
      const { token: t2 } = await createAuthenticatedManager();
      await createTestEvent(m1._id);
      const res1 = await app.get('/api/events').set('Authorization', `Bearer ${t1}`);
      expect(res1.body.events.length).toBe(1);
      const res2 = await app.get('/api/events').set('Authorization', `Bearer ${t2}`);
      expect(res2.body.events.length).toBe(0);
    });
  });

  // ── GET /api/events/:id ──────────────────────────────

  describe('GET /api/events/:id', () => {
    it('returns the event', async () => {
      const { manager, token } = await createAuthenticatedManager();
      const event = await createTestEvent(manager._id);
      const res = await app.get(`/api/events/${event._id}`).set('Authorization', `Bearer ${token}`);
      expect(res.status).toBe(200);
      expect(res.body._id).toBe(String(event._id));
    });

    it('returns 404 for non-existent', async () => {
      const { token } = await createAuthenticatedManager();
      const res = await app.get('/api/events/507f1f77bcf86cd799439011').set('Authorization', `Bearer ${token}`);
      expect(res.status).toBe(404);
    });
  });

  // ── PATCH /api/events/:id ────────────────────────────

  describe('PATCH /api/events/:id', () => {
    it('updates an event', async () => {
      const { manager, token } = await createAuthenticatedManager();
      const event = await createTestEvent(manager._id);
      const res = await app.patch(`/api/events/${event._id}`).set('Authorization', `Bearer ${token}`).send({
        event_name: 'Updated Name',
        roles: [{ role: 'Server', count: 2 }],
      });
      expect(res.status).toBe(200);
      expect(res.body.event_name).toBe('Updated Name');
    });

    it('returns 404 for non-existent event', async () => {
      const { token } = await createAuthenticatedManager();
      const res = await app.patch('/api/events/507f1f77bcf86cd799439011').set('Authorization', `Bearer ${token}`).send({
        event_name: 'X',
        roles: [{ role: 'A', count: 1 }],
      });
      expect(res.status).toBe(404);
    });

    it('returns 404 for wrong manager', async () => {
      const { manager: m1 } = await createAuthenticatedManager();
      const { token: t2 } = await createAuthenticatedManager();
      const event = await createTestEvent(m1._id);
      const res = await app.patch(`/api/events/${event._id}`).set('Authorization', `Bearer ${t2}`).send({
        event_name: 'Hijack',
        roles: [{ role: 'A', count: 1 }],
      });
      expect(res.status).toBe(404);
    });
  });

  // ── DELETE /api/events/:id ───────────────────────────

  describe('DELETE /api/events/:id', () => {
    it('deletes an event', async () => {
      const { manager, token } = await createAuthenticatedManager();
      const event = await createTestEvent(manager._id);
      const res = await app.delete(`/api/events/${event._id}`).set('Authorization', `Bearer ${token}`);
      expect(res.status).toBe(200);
    });

    it('returns 404 for wrong manager', async () => {
      const { manager: m1 } = await createAuthenticatedManager();
      const { token: t2 } = await createAuthenticatedManager();
      const event = await createTestEvent(m1._id);
      const res = await app.delete(`/api/events/${event._id}`).set('Authorization', `Bearer ${t2}`);
      expect(res.status).toBe(404);
    });
  });

  // ── POST /api/events/:id/publish ─────────────────────

  describe('POST /api/events/:id/publish', () => {
    it('publishes a draft event', async () => {
      const { manager, token } = await createAuthenticatedManager();
      const event = await createTestEvent(manager._id, { status: 'draft' });
      const res = await app.post(`/api/events/${event._id}/publish`).set('Authorization', `Bearer ${token}`).send({});
      expect(res.status).toBe(200);
    });

    it('returns 404 for non-existent event', async () => {
      const { token } = await createAuthenticatedManager();
      const res = await app.post('/api/events/507f1f77bcf86cd799439011/publish').set('Authorization', `Bearer ${token}`);
      expect(res.status).toBe(404);
    });
  });

  // ── POST /api/events/:id/respond ─────────────────────

  describe('POST /api/events/:id/respond', () => {
    it('returns 401 without auth', async () => {
      const res = await app.post('/api/events/507f1f77bcf86cd799439011/respond').send({});
      expect(res.status).toBe(401);
    });

    it('accepts a staff member for a published event', async () => {
      const { manager } = await createAuthenticatedManager();
      const event = await createTestEvent(manager._id, { status: 'published' });
      const { user, token: staffToken } = await createAuthenticatedStaffUser();
      const res = await app.post(`/api/events/${event._id}/respond`).set('Authorization', `Bearer ${staffToken}`).send({
        response: 'accept',
        role: 'Bartender',
      });
      expect(res.status).toBe(200);
    });

    it('rejects when role is full', async () => {
      const { manager } = await createAuthenticatedManager();
      // Create event with capacity 1 for Bartender, already filled
      const event = await createTestEvent(manager._id, {
        status: 'published',
        roles: [{ role: 'Bartender', count: 1 }],
        accepted_staff: [{ userKey: 'google:existing', name: 'Existing', role: 'Bartender', response: 'accepted' }],
        role_stats: [{ role: 'Bartender', capacity: 1, taken: 1, remaining: 0, is_full: true }],
      });
      const { token: staffToken } = await createAuthenticatedStaffUser();
      const res = await app.post(`/api/events/${event._id}/respond`).set('Authorization', `Bearer ${staffToken}`).send({
        response: 'accept',
        role: 'Bartender',
      });
      // Should be rejected (role full)
      expect([400, 409]).toContain(res.status);
    });
  });

  // ── POST /api/events/:id/clock-in ────────────────────

  describe('POST /api/events/:id/clock-in', () => {
    it('returns 401 without auth', async () => {
      const res = await app.post('/api/events/507f1f77bcf86cd799439011/clock-in').send({});
      expect(res.status).toBe(401);
    });

    it('allows clock-in for accepted staff', async () => {
      const { manager } = await createAuthenticatedManager();
      const { user, token: staffToken } = await createAuthenticatedStaffUser();
      const userKey = `${user.provider}:${user.subject}`;
      const event = await createTestEvent(manager._id, {
        status: 'published',
        accepted_staff: [{ userKey, name: 'Staff', role: 'Server', response: 'accepted' }],
      });
      const res = await app.post(`/api/events/${event._id}/clock-in`).set('Authorization', `Bearer ${staffToken}`).send({});
      expect(res.status).toBe(200);
    });
  });

  // ── POST /api/events/:id/clock-out ───────────────────

  describe('POST /api/events/:id/clock-out', () => {
    it('returns 401 without auth', async () => {
      const res = await app.post('/api/events/507f1f77bcf86cd799439011/clock-out').send({});
      expect(res.status).toBe(401);
    });
  });

  // ── POST /api/events/batch ───────────────────────────

  describe('POST /api/events/batch', () => {
    it('returns 401 without auth', async () => {
      const res = await app.post('/api/events/batch').send({ events: [] });
      expect(res.status).toBe(401);
    });

    it('returns 400 for empty events array', async () => {
      const { token } = await createAuthenticatedManager();
      const res = await app.post('/api/events/batch').set('Authorization', `Bearer ${token}`).send({ events: [] });
      expect(res.status).toBe(400);
    });

    it('returns 400 for more than 30 events', async () => {
      const { token } = await createAuthenticatedManager();
      const events = Array.from({ length: 31 }, (_, i) => ({
        event_name: `Event ${i}`,
        roles: [{ role: 'Server', count: 1 }],
      }));
      const res = await app.post('/api/events/batch').set('Authorization', `Bearer ${token}`).send({ events });
      expect(res.status).toBe(400);
    });
  });

  // ── GET /api/events/user/:userKey ──────────────────

  describe('GET /api/events/user/:userKey', () => {
    it('returns 401 without auth', async () => {
      const res = await app.get('/api/events/user/google:some-user');
      expect(res.status).toBe(401);
    });

    it('manager sees only their own events for a staff member', async () => {
      const { manager, token } = await createAuthenticatedManager();
      const staffUserKey = 'google:shared-staff-1';
      await createTestEvent(manager._id, {
        accepted_staff: [{ userKey: staffUserKey, role: 'Server', response: 'accepted' }],
      });

      const res = await app.get(`/api/events/user/${staffUserKey}`).set('Authorization', `Bearer ${token}`);
      expect(res.status).toBe(200);
      expect(res.body.events).toHaveLength(1);
    });

    it('two managers with the same staff member see only their respective events', async () => {
      const { manager: m1, token: t1 } = await createAuthenticatedManager();
      const { manager: m2, token: t2 } = await createAuthenticatedManager();
      const staffUserKey = 'google:shared-staff-2';

      await createTestEvent(m1._id, {
        event_name: 'M1 Event',
        accepted_staff: [{ userKey: staffUserKey, role: 'Server', response: 'accepted' }],
      });
      await createTestEvent(m2._id, {
        event_name: 'M2 Event',
        accepted_staff: [{ userKey: staffUserKey, role: 'Bartender', response: 'accepted' }],
      });

      const res1 = await app.get(`/api/events/user/${staffUserKey}`).set('Authorization', `Bearer ${t1}`);
      expect(res1.status).toBe(200);
      expect(res1.body.events).toHaveLength(1);
      expect(res1.body.events[0].event_name).toBe('M1 Event');

      const res2 = await app.get(`/api/events/user/${staffUserKey}`).set('Authorization', `Bearer ${t2}`);
      expect(res2.status).toBe(200);
      expect(res2.body.events).toHaveLength(1);
      expect(res2.body.events[0].event_name).toBe('M2 Event');
    });

    it('staff can query their own events', async () => {
      const { user, token: staffToken } = await createAuthenticatedStaffUser();
      const { manager } = await createAuthenticatedManager();
      const staffUserKey = `${user.provider}:${user.subject}`;

      await createTestEvent(manager._id, {
        accepted_staff: [{ userKey: staffUserKey, role: 'Server', response: 'accepted' }],
      });

      const res = await app.get(`/api/events/user/${staffUserKey}`).set('Authorization', `Bearer ${staffToken}`);
      expect(res.status).toBe(200);
      expect(res.body.events).toHaveLength(1);
    });

    it('staff cannot query another staff member\'s events', async () => {
      const { token: staffToken } = await createAuthenticatedStaffUser();
      const res = await app.get('/api/events/user/google:someone-else').set('Authorization', `Bearer ${staffToken}`);
      expect(res.status).toBe(403);
    });
  });
});
