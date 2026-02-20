import { getTestApp, createAuthenticatedStaffUser, createAuthenticatedManager } from '../helpers';

describe('GET /api/subscription/status', () => {
  it('returns freeMonth data for new staff user', async () => {
    const app = await getTestApp();
    const { token } = await createAuthenticatedStaffUser({
      subscription_tier: 'free',
      subscription_status: 'free_month',
    });

    const res = await app
      .get('/api/subscription/status')
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(200);
    expect(res.body.tier).toBe('free');
    expect(res.body.isReadOnly).toBe(false);
    expect(res.body.freeMonth).toBeDefined();
    expect(res.body.freeMonth.active).toBe(true);
    expect(res.body.freeMonth.daysRemaining).toBeGreaterThan(0);
    expect(res.body.freeMonth.daysRemaining).toBeLessThanOrEqual(30);
    expect(res.body.freeMonth.endDate).toBeDefined();
    expect(res.body.userType).toBe('staff');
  });

  it('returns isReadOnly=true for expired staff user', async () => {
    const app = await getTestApp();
    const { token } = await createAuthenticatedStaffUser({
      subscription_tier: 'free',
      subscription_status: 'expired',
      createdAt: new Date('2024-01-01'),
    });

    const res = await app
      .get('/api/subscription/status')
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(200);
    expect(res.body.isReadOnly).toBe(true);
    expect(res.body.freeMonth.active).toBe(false);
    expect(res.body.freeMonth.daysRemaining).toBe(0);
  });

  it('returns isReadOnly=false for pro user', async () => {
    const app = await getTestApp();
    const { token } = await createAuthenticatedStaffUser({
      subscription_tier: 'pro',
      subscription_status: 'active',
    });

    const res = await app
      .get('/api/subscription/status')
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(200);
    expect(res.body.tier).toBe('pro');
    expect(res.body.isReadOnly).toBe(false);
    expect(res.body.isActive).toBe(true);
  });

  it('does not include freeMonth for managers', async () => {
    const app = await getTestApp();
    const { token } = await createAuthenticatedManager();

    const res = await app
      .get('/api/subscription/status')
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(200);
    expect(res.body.userType).toBe('manager');
    expect(res.body.freeMonth).toBeNull();
    expect(res.body.isReadOnly).toBe(false);
  });
});
