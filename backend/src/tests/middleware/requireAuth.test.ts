import express from 'express';
import request from 'supertest';
import { requireAuth } from '../../middleware/requireAuth';
import { generateTestToken } from '../helpers';

function buildApp() {
  const app = express();
  app.use(express.json());
  app.get('/test', requireAuth, (req: any, res) => {
    res.json({ user: req.user, authUser: req.authUser });
  });
  return app;
}

describe('requireAuth middleware', () => {
  const app = buildApp();

  it('returns 401 when no Authorization header', async () => {
    const res = await request(app).get('/test');
    expect(res.status).toBe(401);
  });

  it('returns 401 when token is empty', async () => {
    const res = await request(app).get('/test').set('Authorization', 'Bearer ');
    expect(res.status).toBe(401);
  });

  it('returns 401 when header has no Bearer prefix', async () => {
    const token = generateTestToken({ sub: 'u1', provider: 'google' });
    const res = await request(app).get('/test').set('Authorization', token);
    expect(res.status).toBe(401);
  });

  it('returns 401 for expired token', async () => {
    const jwt = require('jsonwebtoken');
    const expired = jwt.sign(
      { sub: 'u1', provider: 'google' },
      'test-jwt-secret-for-testing',
      { expiresIn: '-1s' }
    );
    const res = await request(app).get('/test').set('Authorization', `Bearer ${expired}`);
    expect(res.status).toBe(401);
    expect(res.body.error).toMatch(/expired/i);
  });

  it('returns 401 for wrong secret', async () => {
    const jwt = require('jsonwebtoken');
    const bad = jwt.sign({ sub: 'u1', provider: 'google' }, 'wrong-secret');
    const res = await request(app).get('/test').set('Authorization', `Bearer ${bad}`);
    expect(res.status).toBe(401);
  });

  it('returns 401 for malformed JWT', async () => {
    const res = await request(app).get('/test').set('Authorization', 'Bearer not.a.jwt');
    expect(res.status).toBe(401);
  });

  it('sets req.user and req.authUser on valid token', async () => {
    const token = generateTestToken({ sub: 'u1', provider: 'google', email: 'a@b.com', managerId: 'm1' });
    const res = await request(app).get('/test').set('Authorization', `Bearer ${token}`);
    expect(res.status).toBe(200);
    expect(res.body.user.sub).toBe('u1');
    expect(res.body.user.provider).toBe('google');
    expect(res.body.user.managerId).toBe('m1');
    expect(res.body.authUser).toEqual(res.body.user);
  });

  it('allows staff token without managerId', async () => {
    const token = generateTestToken({ sub: 's1', provider: 'google' });
    const res = await request(app).get('/test').set('Authorization', `Bearer ${token}`);
    expect(res.status).toBe(200);
    expect(res.body.user.managerId).toBeUndefined();
  });
});
