import { getTestApp, createAuthenticatedManager, createAuthenticatedStaffUser, generateTestToken } from '../helpers';
import { UserModel } from '../../models/user';
import { ManagerModel } from '../../models/manager';

// Mock external auth providers
jest.mock('google-auth-library', () => ({
  OAuth2Client: jest.fn().mockImplementation(() => ({
    verifyIdToken: jest.fn().mockResolvedValue({
      getPayload: () => ({
        sub: 'google-123',
        email: 'test@gmail.com',
        name: 'Test User',
        picture: 'https://lh3.googleusercontent.com/photo.jpg',
      }),
    }),
  })),
}));

jest.mock('jose', () => ({
  createRemoteJWKSet: jest.fn(),
  jwtVerify: jest.fn().mockResolvedValue({
    payload: {
      sub: 'apple-123',
      email: 'test@icloud.com',
    },
  }),
}));

jest.mock('../../config/firebase', () => ({
  firebaseAuth: {
    verifyIdToken: jest.fn().mockResolvedValue({
      uid: 'firebase-123',
      phone_number: '+1234567890',
    }),
  },
}));

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

describe('Auth API', () => {
  let app: any;

  beforeEach(async () => {
    app = await getTestApp();
  });

  // ── Staff Google Auth ────────────────────────────────

  describe('POST /api/auth/google', () => {
    it('returns 400 when no token provided', async () => {
      const res = await app.post('/api/auth/google').send({});
      expect(res.status).toBe(400);
    });

    it('returns 200 with valid idToken', async () => {
      const res = await app.post('/api/auth/google').send({ idToken: 'valid-google-token' });
      expect(res.status).toBe(200);
      expect(res.body.token).toBeDefined();
      expect(res.body.user.provider).toBe('google');
    });

    it('creates user document on first login', async () => {
      await app.post('/api/auth/google').send({ idToken: 'valid-google-token' });
      const user = await UserModel.findOne({ provider: 'google', subject: 'google-123' });
      expect(user).toBeTruthy();
      expect(user!.email).toBe('test@gmail.com');
    });

    it('upserts on repeat login', async () => {
      await app.post('/api/auth/google').send({ idToken: 'valid-google-token' });
      await app.post('/api/auth/google').send({ idToken: 'valid-google-token' });
      const count = await UserModel.countDocuments({ provider: 'google', subject: 'google-123' });
      expect(count).toBe(1);
    });
  });

  // ── Staff Apple Auth ─────────────────────────────────

  describe('POST /api/auth/apple', () => {
    it('returns 400 when no token provided', async () => {
      const res = await app.post('/api/auth/apple').send({});
      expect(res.status).toBe(400);
    });

    it('returns 200 with valid identityToken', async () => {
      const res = await app.post('/api/auth/apple').send({ identityToken: 'valid-apple-token' });
      expect(res.status).toBe(200);
      expect(res.body.token).toBeDefined();
      expect(res.body.user.provider).toBe('apple');
    });
  });

  // ── Manager Google Auth ──────────────────────────────

  describe('POST /api/auth/manager/google', () => {
    it('returns 400 when no token', async () => {
      const res = await app.post('/api/auth/manager/google').send({});
      expect(res.status).toBe(400);
    });

    it('creates manager and returns JWT with managerId', async () => {
      const res = await app.post('/api/auth/manager/google').send({ idToken: 'valid-google-token' });
      expect(res.status).toBe(200);
      expect(res.body.token).toBeDefined();
      const manager = await ManagerModel.findOne({ provider: 'google', subject: 'google-123' });
      expect(manager).toBeTruthy();
    });
  });

  // ── Manager Apple Auth ───────────────────────────────

  describe('POST /api/auth/manager/apple', () => {
    it('returns 400 when no token', async () => {
      const res = await app.post('/api/auth/manager/apple').send({});
      expect(res.status).toBe(400);
    });

    it('returns 200 with valid identityToken', async () => {
      const res = await app.post('/api/auth/manager/apple').send({ identityToken: 'valid-apple-token' });
      expect(res.status).toBe(200);
      expect(res.body.token).toBeDefined();
    });
  });

  // ── Staff Phone Auth ─────────────────────────────────

  describe('POST /api/auth/phone', () => {
    it('returns 400 when no token', async () => {
      const res = await app.post('/api/auth/phone').send({});
      expect(res.status).toBe(400);
    });

    it('creates user with phone provider', async () => {
      const res = await app.post('/api/auth/phone').send({ firebaseIdToken: 'valid-firebase-token' });
      expect(res.status).toBe(200);
      expect(res.body.token).toBeDefined();
      const user = await UserModel.findOne({ provider: 'phone', subject: 'firebase-123' });
      expect(user).toBeTruthy();
    });
  });

  // ── Manager Phone Auth ───────────────────────────────

  describe('POST /api/auth/manager/phone', () => {
    it('returns 400 when no token', async () => {
      const res = await app.post('/api/auth/manager/phone').send({});
      expect(res.status).toBe(400);
    });

    it('creates manager with phone provider', async () => {
      const res = await app.post('/api/auth/manager/phone').send({ firebaseIdToken: 'valid-firebase-token' });
      expect(res.status).toBe(200);
      expect(res.body.token).toBeDefined();
      const manager = await ManagerModel.findOne({ provider: 'phone', subject: 'firebase-123' });
      expect(manager).toBeTruthy();
    });
  });

  // ── Link Phone ───────────────────────────────────────

  describe('POST /api/auth/link-phone', () => {
    it('links phone to staff account', async () => {
      const { user, token } = await createAuthenticatedStaffUser();
      const res = await app.post('/api/auth/link-phone').set('Authorization', `Bearer ${token}`).send({
        firebaseIdToken: 'valid-firebase-token',
      });
      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
    });
  });

  // ── Unlink Phone ─────────────────────────────────────

  describe('POST /api/auth/unlink-phone', () => {
    it('unlinks phone from staff account', async () => {
      const { token } = await createAuthenticatedStaffUser();
      const res = await app.post('/api/auth/unlink-phone').set('Authorization', `Bearer ${token}`);
      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
    });
  });

  // ── Manager Link Phone ───────────────────────────────

  describe('POST /api/auth/manager/link-phone', () => {
    it('links phone to manager account', async () => {
      const { token } = await createAuthenticatedManager();
      const res = await app.post('/api/auth/manager/link-phone').set('Authorization', `Bearer ${token}`).send({
        firebaseIdToken: 'valid-firebase-token',
      });
      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
    });
  });

  // ── Manager Unlink Phone ─────────────────────────────

  describe('POST /api/auth/manager/unlink-phone', () => {
    it('unlinks phone from manager account', async () => {
      const { token } = await createAuthenticatedManager();
      const res = await app.post('/api/auth/manager/unlink-phone').set('Authorization', `Bearer ${token}`);
      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
    });
  });
});
