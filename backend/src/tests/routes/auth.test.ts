import { getTestApp, createAuthenticatedManager, createAuthenticatedStaffUser, generateTestToken } from '../helpers';
import { UserModel } from '../../models/user';
import { ManagerModel } from '../../models/manager';

// Provide test Google Client IDs so audience check passes
jest.mock('../../config/env', () => ({
  ENV: {
    port: 4000,
    mongoUri: 'mongodb://localhost:27017/test',
    nodeEnv: 'test',
    allowedOrigins: '',
    jwtSecret: 'test-jwt-secret-for-testing',
    googleClientIdIos: ['test-ios-client-id'],
    googleClientIdAndroid: ['test-android-client-id'],
    googleClientIdWeb: ['test-web-client-id'],
    googleServerClientId: [],
    appleBundleId: ['com.test.app'],
    appleServiceId: ['com.test.service'],
    adminKey: '',
    firebaseProjectId: '',
    firebaseClientEmail: '',
    firebasePrivateKey: '',
    r2AccountId: '',
    r2AccessKeyId: '',
    r2SecretAccessKey: '',
    r2BucketName: 'test-bucket',
    r2PublicUrl: '',
  },
}));

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

  // ── Account Linking (Cross-Provider) ──────────────────

  describe('Account Linking', () => {
    const jose = require('jose');

    it('auto-links Apple to existing Google user with same email', async () => {
      // Step 1: Sign in with Google → creates user with email test@gmail.com
      await app.post('/api/auth/google').send({ idToken: 'valid-google-token' });
      const googleUser = await UserModel.findOne({ provider: 'google', subject: 'google-123' });
      expect(googleUser).toBeTruthy();

      // Step 2: Sign in with Apple using the SAME email
      (jose.jwtVerify as jest.Mock).mockResolvedValueOnce({
        payload: { sub: 'apple-same-email', email: 'test@gmail.com' },
      });
      const res = await app.post('/api/auth/apple').send({ identityToken: 'valid-apple-token' });

      expect(res.status).toBe(200);
      // JWT should use the Google (primary) identity
      expect(res.body.user.provider).toBe('google');
      expect(res.body.user.subject).toBe('google-123');

      // Only one user document should exist
      const userCount = await UserModel.countDocuments({ email: 'test@gmail.com' });
      expect(userCount).toBe(1);

      // Apple identity should be in linked_providers
      const linked = await UserModel.findOne({ provider: 'google', subject: 'google-123' });
      expect(linked!.linked_providers).toEqual(
        expect.arrayContaining([
          expect.objectContaining({ provider: 'apple', subject: 'apple-same-email' }),
        ]),
      );
    });

    it('returns primary identity on subsequent sign-in via linked provider', async () => {
      // Setup: Google user with Apple already linked
      await UserModel.create({
        provider: 'google',
        subject: 'google-primary',
        email: 'linked@test.com',
        name: 'Primary User',
        linked_providers: [{ provider: 'apple', subject: 'apple-linked', linked_at: new Date() }],
      });

      // Sign in with the linked Apple identity
      (jose.jwtVerify as jest.Mock).mockResolvedValueOnce({
        payload: { sub: 'apple-linked', email: 'linked@test.com' },
      });
      const res = await app.post('/api/auth/apple').send({ identityToken: 'valid-apple-token' });

      expect(res.status).toBe(200);
      // Should return the primary (Google) identity
      expect(res.body.user.provider).toBe('google');
      expect(res.body.user.subject).toBe('google-primary');
    });

    it('creates separate user when Apple hides email', async () => {
      // Google user exists
      await app.post('/api/auth/google').send({ idToken: 'valid-google-token' });

      // Apple sign-in with no email (Hide My Email)
      (jose.jwtVerify as jest.Mock).mockResolvedValueOnce({
        payload: { sub: 'apple-no-email' },
      });
      const res = await app.post('/api/auth/apple').send({ identityToken: 'valid-apple-token' });

      expect(res.status).toBe(200);
      expect(res.body.user.provider).toBe('apple');
      expect(res.body.user.subject).toBe('apple-no-email');

      // Two separate users should exist
      const googleUser = await UserModel.findOne({ provider: 'google', subject: 'google-123' });
      const appleUser = await UserModel.findOne({ provider: 'apple', subject: 'apple-no-email' });
      expect(googleUser).toBeTruthy();
      expect(appleUser).toBeTruthy();
    });

    it('does not cross-link users with different emails', async () => {
      // Google user with email A
      await app.post('/api/auth/google').send({ idToken: 'valid-google-token' });

      // Apple user with different email (default mock: test@icloud.com)
      const res = await app.post('/api/auth/apple').send({ identityToken: 'valid-apple-token' });

      expect(res.status).toBe(200);
      expect(res.body.user.provider).toBe('apple');
      expect(res.body.user.subject).toBe('apple-123');

      // Two separate users
      const googleUser = await UserModel.findOne({ provider: 'google', subject: 'google-123' });
      const appleUser = await UserModel.findOne({ provider: 'apple', subject: 'apple-123' });
      expect(googleUser).toBeTruthy();
      expect(appleUser).toBeTruthy();
      expect(googleUser!.linked_providers?.length ?? 0).toBe(0);
    });

    it('auto-links Apple to existing Google manager with same email', async () => {
      // Step 1: Sign in as manager with Google
      await app.post('/api/auth/manager/google').send({ idToken: 'valid-google-token' });
      const googleMgr = await ManagerModel.findOne({ provider: 'google', subject: 'google-123' });
      expect(googleMgr).toBeTruthy();

      // Step 2: Sign in as manager with Apple using same email
      (jose.jwtVerify as jest.Mock).mockResolvedValueOnce({
        payload: { sub: 'apple-mgr-same', email: 'test@gmail.com' },
      });
      const res = await app.post('/api/auth/manager/apple').send({ identityToken: 'valid-apple-token' });

      expect(res.status).toBe(200);
      expect(res.body.user.provider).toBe('google');
      expect(res.body.user.subject).toBe('google-123');

      // Only one manager document
      const mgrCount = await ManagerModel.countDocuments({ email: 'test@gmail.com' });
      expect(mgrCount).toBe(1);

      // Apple linked
      const linked = await ManagerModel.findOne({ provider: 'google', subject: 'google-123' });
      expect(linked!.linked_providers).toEqual(
        expect.arrayContaining([
          expect.objectContaining({ provider: 'apple', subject: 'apple-mgr-same' }),
        ]),
      );
    });
  });
});
