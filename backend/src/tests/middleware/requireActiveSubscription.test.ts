import express from 'express';
import request from 'supertest';
import { requireAuth } from '../../middleware/requireAuth';
import { requireActiveSubscription } from '../../middleware/requireActiveSubscription';
import { UserModel } from '../../models/user';
import { generateTestToken, createAuthenticatedStaffUser, createAuthenticatedManager } from '../helpers';

function buildApp() {
  const app = express();
  app.use(express.json());
  app.post('/test', requireAuth, requireActiveSubscription, (req: any, res) => {
    res.json({ success: true });
  });
  return app;
}

describe('requireActiveSubscription middleware', () => {
  const app = buildApp();

  it('returns 403 with readOnly for expired free user', async () => {
    const { token } = await createAuthenticatedStaffUser({
      subscription_tier: 'free',
      subscription_status: 'expired',
      createdAt: new Date('2024-01-01'), // old account, free month over
    });

    const res = await request(app)
      .post('/test')
      .set('Authorization', `Bearer ${token}`)
      .send({});

    expect(res.status).toBe(403);
    expect(res.body.readOnly).toBe(true);
    expect(res.body.message).toBe('Active subscription required');
  });

  it('passes for pro active user', async () => {
    const { token } = await createAuthenticatedStaffUser({
      subscription_tier: 'pro',
      subscription_status: 'active',
    });

    const res = await request(app)
      .post('/test')
      .set('Authorization', `Bearer ${token}`)
      .send({});

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
  });

  it('passes for free user in free month (new account)', async () => {
    const { token } = await createAuthenticatedStaffUser({
      subscription_tier: 'free',
      subscription_status: 'free_month',
      // createdAt defaults to now, so within 30 days
    });

    const res = await request(app)
      .post('/test')
      .set('Authorization', `Bearer ${token}`)
      .send({});

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
  });

  it('passes for free user with future override', async () => {
    const { token } = await createAuthenticatedStaffUser({
      subscription_tier: 'free',
      subscription_status: 'free_month',
      createdAt: new Date('2024-01-01'), // old
      free_month_end_override: new Date(Date.now() + 10 * 24 * 60 * 60 * 1000), // 10 days from now
    });

    const res = await request(app)
      .post('/test')
      .set('Authorization', `Bearer ${token}`)
      .send({});

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
  });

  it('always passes for managers (skips subscription check)', async () => {
    const { token } = await createAuthenticatedManager({
      subscription_tier: 'free',
      subscription_status: 'expired',
    });

    const res = await request(app)
      .post('/test')
      .set('Authorization', `Bearer ${token}`)
      .send({});

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
  });

  it('returns 403 for cancelled pro user after free month', async () => {
    const { token } = await createAuthenticatedStaffUser({
      subscription_tier: 'pro',
      subscription_status: 'cancelled',
      createdAt: new Date('2024-01-01'), // old account
    });

    const res = await request(app)
      .post('/test')
      .set('Authorization', `Bearer ${token}`)
      .send({});

    expect(res.status).toBe(403);
    expect(res.body.readOnly).toBe(true);
  });
});
