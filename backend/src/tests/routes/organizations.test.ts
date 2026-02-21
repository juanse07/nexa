import { getTestApp, createAuthenticatedManager, createTestTeam, generateTestToken } from '../helpers';
import { OrganizationModel } from '../../models/organization';
import { ManagerModel } from '../../models/manager';

// Mock env with Stripe keys disabled (unit tests don't call Stripe)
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
    docServiceUrl: 'http://localhost:5000',
    docServiceSecret: '',
    // Stripe keys set to test values — actual calls are mocked
    stripeSecretKey: 'sk_test_fake',
    stripeWebhookSecret: 'whsec_test_fake',
    stripePriceIdPro: 'price_test_pro',
    stripePortalReturnUrl: 'https://flowshift.work',
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

// Mock Stripe service to avoid real API calls
let customerCounter = 0;
jest.mock('../../services/stripeService', () => ({
  createCustomer: jest.fn().mockImplementation(() => {
    customerCounter += 1;
    return Promise.resolve({ id: `cus_test_${customerCounter}` });
  }),
  createCheckoutSession: jest.fn().mockResolvedValue({ url: 'https://checkout.stripe.com/test' }),
  createPortalSession: jest.fn().mockResolvedValue({ url: 'https://billing.stripe.com/test' }),
  constructWebhookEvent: jest.fn(),
}));

describe('Organizations API', () => {
  let app: any;

  beforeEach(async () => {
    app = await getTestApp();
  });

  // ─── Create Organization ────────────────────────────────────────

  describe('POST /api/organizations', () => {
    it('should create an organization and set manager as owner', async () => {
      const { manager, token } = await createAuthenticatedManager();

      const res = await app
        .post('/api/organizations')
        .set('Authorization', `Bearer ${token}`)
        .send({ name: 'Acme Events' });

      expect(res.status).toBe(201);
      expect(res.body.name).toBe('Acme Events');
      expect(res.body.slug).toBe('acme-events');
      expect(res.body.stripeCustomerId).toMatch(/^cus_test_/);
      expect(res.body.members).toHaveLength(1);
      expect(res.body.members[0].role).toBe('owner');

      // Verify manager was updated
      const updatedManager = await ManagerModel.findById(manager._id).lean();
      expect(updatedManager?.organizationId).toBeDefined();
      expect(updatedManager?.orgRole).toBe('owner');
    });

    it('should reject if manager already belongs to an org', async () => {
      const { manager, token } = await createAuthenticatedManager();

      // Create first org
      await app
        .post('/api/organizations')
        .set('Authorization', `Bearer ${token}`)
        .send({ name: 'First Org' });

      // Try to create second org
      const res = await app
        .post('/api/organizations')
        .set('Authorization', `Bearer ${token}`)
        .send({ name: 'Second Org' });

      expect(res.status).toBe(409);
    });

    it('should reject staff users (no managerId)', async () => {
      const token = generateTestToken({ sub: 'staff-1', provider: 'google' });

      const res = await app
        .post('/api/organizations')
        .set('Authorization', `Bearer ${token}`)
        .send({ name: 'Staff Org' });

      expect(res.status).toBe(403);
    });

    it('should validate org name', async () => {
      const { token } = await createAuthenticatedManager();

      const res = await app
        .post('/api/organizations')
        .set('Authorization', `Bearer ${token}`)
        .send({ name: 'A' }); // Too short

      expect(res.status).toBe(400);
    });
  });

  // ─── Get My Organization ────────────────────────────────────────

  describe('GET /api/organizations/mine', () => {
    it('should return null when manager has no org', async () => {
      const { token } = await createAuthenticatedManager();

      const res = await app
        .get('/api/organizations/mine')
        .set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(200);
      expect(res.body.organization).toBeNull();
    });

    it('should return org with member details', async () => {
      const { manager, token } = await createAuthenticatedManager({
        email: 'owner@test.com',
        name: 'Owner Manager',
      });

      // Create org
      await app
        .post('/api/organizations')
        .set('Authorization', `Bearer ${token}`)
        .send({ name: 'My Org' });

      const res = await app
        .get('/api/organizations/mine')
        .set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(200);
      expect(res.body.organization).not.toBeNull();
      expect(res.body.organization.name).toBe('My Org');
      expect(res.body.organization.members).toHaveLength(1);
      expect(res.body.organization.members[0].email).toBe('owner@test.com');
    });
  });

  // ─── Invite & Join ──────────────────────────────────────────────

  describe('Invite flow', () => {
    it('should create an invite and allow another manager to join', async () => {
      const { manager: owner, token: ownerToken } = await createAuthenticatedManager({
        email: 'owner@acme.com',
      });

      // Create org
      const createRes = await app
        .post('/api/organizations')
        .set('Authorization', `Bearer ${ownerToken}`)
        .send({ name: 'Acme Corp' });

      const orgId = createRes.body.id;

      // Invite a member
      const inviteRes = await app
        .post(`/api/organizations/${orgId}/members`)
        .set('Authorization', `Bearer ${ownerToken}`)
        .send({ email: 'newguy@acme.com', role: 'member' });

      expect(inviteRes.status).toBe(201);
      expect(inviteRes.body.invite.token).toBeDefined();

      const inviteToken = inviteRes.body.invite.token;

      // Create a second manager to accept the invite
      const { manager: joiner, token: joinerToken } = await createAuthenticatedManager({
        email: 'newguy@acme.com',
      });

      // Join via invite
      const joinRes = await app
        .post(`/api/organizations/join/${inviteToken}`)
        .set('Authorization', `Bearer ${joinerToken}`);

      expect(joinRes.status).toBe(200);
      expect(joinRes.body.organizationName).toBe('Acme Corp');
      expect(joinRes.body.role).toBe('member');

      // Verify joiner's manager doc was updated
      const updatedJoiner = await ManagerModel.findById(joiner._id).lean();
      expect(String(updatedJoiner?.organizationId)).toBe(orgId);
      expect(updatedJoiner?.orgRole).toBe('member');

      // Verify org now has 2 members
      const org = await OrganizationModel.findById(orgId).lean();
      expect(org?.members).toHaveLength(2);
    });

    it('should reject duplicate invites', async () => {
      const { manager, token: ownerToken } = await createAuthenticatedManager();

      const createRes = await app
        .post('/api/organizations')
        .set('Authorization', `Bearer ${ownerToken}`)
        .send({ name: 'Dup Org' });

      expect(createRes.status).toBe(201);
      const orgId = createRes.body.id;
      expect(orgId).toBeDefined();

      // First invite
      const firstInvite = await app
        .post(`/api/organizations/${orgId}/members`)
        .set('Authorization', `Bearer ${ownerToken}`)
        .send({ email: 'same@acme.com' });

      expect(firstInvite.status).toBe(201);

      // Duplicate invite
      const res = await app
        .post(`/api/organizations/${orgId}/members`)
        .set('Authorization', `Bearer ${ownerToken}`)
        .send({ email: 'same@acme.com' });

      expect(res.status).toBe(409);
    });

    it('should reject join if manager already in an org', async () => {
      // Owner creates org
      const { token: ownerToken } = await createAuthenticatedManager();
      const createRes = await app
        .post('/api/organizations')
        .set('Authorization', `Bearer ${ownerToken}`)
        .send({ name: 'Org A' });
      const orgId = createRes.body.id;

      // Invite
      const inviteRes = await app
        .post(`/api/organizations/${orgId}/members`)
        .set('Authorization', `Bearer ${ownerToken}`)
        .send({ email: 'other@test.com' });

      // Second manager already has their own org
      const { token: joinerToken } = await createAuthenticatedManager({
        email: 'other@test.com',
      });
      await app
        .post('/api/organizations')
        .set('Authorization', `Bearer ${joinerToken}`)
        .send({ name: 'Org B' });

      // Try to join Org A — should fail
      const joinRes = await app
        .post(`/api/organizations/join/${inviteRes.body.invite.token}`)
        .set('Authorization', `Bearer ${joinerToken}`);

      expect(joinRes.status).toBe(409);
    });

    it('should reject expired invite tokens', async () => {
      const { token: ownerToken } = await createAuthenticatedManager();
      const createRes = await app
        .post('/api/organizations')
        .set('Authorization', `Bearer ${ownerToken}`)
        .send({ name: 'Expire Org' });

      const orgId = createRes.body.id;

      // Manually insert an expired invite
      await OrganizationModel.findByIdAndUpdate(orgId, {
        $push: {
          pendingInvites: {
            email: 'expired@test.com',
            role: 'member',
            token: 'expired-token-123',
            expiresAt: new Date(Date.now() - 1000), // Already expired
            invitedBy: orgId,
          },
        },
      });

      const { token: joinerToken } = await createAuthenticatedManager({
        email: 'expired@test.com',
      });

      const res = await app
        .post('/api/organizations/join/expired-token-123')
        .set('Authorization', `Bearer ${joinerToken}`);

      expect(res.status).toBe(404);
    });
  });

  // ─── Remove Member ──────────────────────────────────────────────

  describe('DELETE /api/organizations/:id/members/:managerId', () => {
    it('should allow owner to remove a member', async () => {
      const { token: ownerToken } = await createAuthenticatedManager();
      const createRes = await app
        .post('/api/organizations')
        .set('Authorization', `Bearer ${ownerToken}`)
        .send({ name: 'Remove Org' });
      const orgId = createRes.body.id;

      // Invite + join
      const inviteRes = await app
        .post(`/api/organizations/${orgId}/members`)
        .set('Authorization', `Bearer ${ownerToken}`)
        .send({ email: 'removeme@test.com' });

      const { manager: joiner, token: joinerToken } = await createAuthenticatedManager({
        email: 'removeme@test.com',
      });

      await app
        .post(`/api/organizations/join/${inviteRes.body.invite.token}`)
        .set('Authorization', `Bearer ${joinerToken}`);

      // Remove the member
      const res = await app
        .delete(`/api/organizations/${orgId}/members/${joiner._id}`)
        .set('Authorization', `Bearer ${ownerToken}`);

      expect(res.status).toBe(200);

      // Verify member was removed
      const org = await OrganizationModel.findById(orgId).lean();
      expect(org?.members).toHaveLength(1);

      // Verify manager doc was cleaned
      const updatedJoiner = await ManagerModel.findById(joiner._id).lean();
      expect(updatedJoiner?.organizationId).toBeUndefined();
      expect(updatedJoiner?.orgRole).toBeUndefined();
    });
  });

  // ─── Checkout & Portal ──────────────────────────────────────────

  describe('POST /api/organizations/:id/checkout', () => {
    it('should return a Stripe checkout URL', async () => {
      const { token } = await createAuthenticatedManager();
      const createRes = await app
        .post('/api/organizations')
        .set('Authorization', `Bearer ${token}`)
        .send({ name: 'Checkout Org' });

      const orgId = createRes.body.id;

      const res = await app
        .post(`/api/organizations/${orgId}/checkout`)
        .set('Authorization', `Bearer ${token}`)
        .send({
          successUrl: 'https://flowshift.work/success',
          cancelUrl: 'https://flowshift.work/cancel',
        });

      expect(res.status).toBe(200);
      expect(res.body.url).toBe('https://checkout.stripe.com/test');
    });
  });

  describe('POST /api/organizations/:id/portal', () => {
    it('should return a Stripe portal URL', async () => {
      const { token } = await createAuthenticatedManager();
      const createRes = await app
        .post('/api/organizations')
        .set('Authorization', `Bearer ${token}`)
        .send({ name: 'Portal Org' });

      const orgId = createRes.body.id;

      const res = await app
        .post(`/api/organizations/${orgId}/portal`)
        .set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(200);
      expect(res.body.url).toBe('https://billing.stripe.com/test');
    });
  });

  // ─── Org Subscription Tier Override ─────────────────────────────

  describe('Effective subscription tier', () => {
    it('should return org pro tier via /subscription/manager/usage', async () => {
      const { manager, token } = await createAuthenticatedManager({
        subscription_tier: 'free',
      });

      // Create org with active pro subscription
      const org = await OrganizationModel.create({
        name: 'Pro Org',
        slug: 'pro-org',
        stripeCustomerId: 'cus_pro_test',
        subscriptionStatus: 'active',
        subscriptionTier: 'pro',
        members: [{ managerId: manager._id, role: 'owner', joinedAt: new Date() }],
      });

      await ManagerModel.findByIdAndUpdate(manager._id, {
        organizationId: org._id,
        orgRole: 'owner',
      });

      const res = await app
        .get('/api/subscription/manager/usage')
        .set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(200);
      expect(res.body.tier).toBe('pro');
      expect(res.body.isPro).toBe(true);
      expect(res.body.source).toBe('organization');
    });

    it('should fall through to individual tier when org is free', async () => {
      const { manager, token } = await createAuthenticatedManager({
        subscription_tier: 'pro',
        subscription_status: 'active',
      });

      // Create org with free tier (no Stripe subscription)
      const org = await OrganizationModel.create({
        name: 'Free Org',
        slug: 'free-org',
        subscriptionStatus: 'none',
        subscriptionTier: 'free',
        members: [{ managerId: manager._id, role: 'owner', joinedAt: new Date() }],
      });

      await ManagerModel.findByIdAndUpdate(manager._id, {
        organizationId: org._id,
        orgRole: 'owner',
      });

      const res = await app
        .get('/api/subscription/manager/usage')
        .set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(200);
      // Falls through to individual tier since org subscription is not active
      expect(res.body.tier).toBe('pro');
      expect(res.body.source).toBe('individual');
    });

    it('should return free for manager with no org and no subscription', async () => {
      const { token } = await createAuthenticatedManager({
        subscription_tier: 'free',
      });

      const res = await app
        .get('/api/subscription/manager/usage')
        .set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(200);
      expect(res.body.tier).toBe('free');
      expect(res.body.isPro).toBe(false);
      expect(res.body.source).toBe('individual');
    });
  });

  // ─── Transfer Ownership ─────────────────────────────────────────

  describe('POST /api/organizations/:id/transfer', () => {
    let ownerToken: string;
    let ownerId: string;
    let orgId: string;
    let memberToken: string;
    let memberId: string;

    beforeEach(async () => {
      // Create org with owner
      const { manager: owner, token: oToken } = await createAuthenticatedManager({
        email: 'transfer-owner@test.com',
      });
      ownerToken = oToken;
      ownerId = owner._id.toString();

      const createRes = await app
        .post('/api/organizations')
        .set('Authorization', `Bearer ${ownerToken}`)
        .send({ name: 'Transfer Org' });
      orgId = createRes.body.id;

      // Invite + join a member
      const inviteRes = await app
        .post(`/api/organizations/${orgId}/members`)
        .set('Authorization', `Bearer ${ownerToken}`)
        .send({ email: 'transfer-member@test.com' });

      const { manager: member, token: mToken } = await createAuthenticatedManager({
        email: 'transfer-member@test.com',
      });
      memberToken = mToken;
      memberId = member._id.toString();

      await app
        .post(`/api/organizations/join/${inviteRes.body.invite.token}`)
        .set('Authorization', `Bearer ${memberToken}`);
    });

    it('should transfer ownership from owner to member', async () => {
      const res = await app
        .post(`/api/organizations/${orgId}/transfer`)
        .set('Authorization', `Bearer ${ownerToken}`)
        .send({ newOwnerId: memberId });

      expect(res.status).toBe(200);

      // Verify org members have swapped roles
      const org = await OrganizationModel.findById(orgId).lean();
      const oldOwner = org?.members.find((m) => String(m.managerId) === ownerId);
      const newOwner = org?.members.find((m) => String(m.managerId) === memberId);
      expect(oldOwner?.role).toBe('admin');
      expect(newOwner?.role).toBe('owner');
    });

    it('should update manager documents with new orgRole values', async () => {
      await app
        .post(`/api/organizations/${orgId}/transfer`)
        .set('Authorization', `Bearer ${ownerToken}`)
        .send({ newOwnerId: memberId });

      const oldOwnerDoc = await ManagerModel.findById(ownerId).lean();
      const newOwnerDoc = await ManagerModel.findById(memberId).lean();
      expect(oldOwnerDoc?.orgRole).toBe('admin');
      expect(newOwnerDoc?.orgRole).toBe('owner');
    });

    it('should reject non-owner attempting to transfer', async () => {
      const res = await app
        .post(`/api/organizations/${orgId}/transfer`)
        .set('Authorization', `Bearer ${memberToken}`)
        .send({ newOwnerId: ownerId });

      expect(res.status).toBe(403);
    });

    it('should reject transfer to non-member', async () => {
      const { manager: outsider } = await createAuthenticatedManager({
        email: 'outsider@test.com',
      });

      const res = await app
        .post(`/api/organizations/${orgId}/transfer`)
        .set('Authorization', `Bearer ${ownerToken}`)
        .send({ newOwnerId: outsider._id.toString() });

      expect(res.status).toBe(404);
    });

    it('should reject transfer to self', async () => {
      const res = await app
        .post(`/api/organizations/${orgId}/transfer`)
        .set('Authorization', `Bearer ${ownerToken}`)
        .send({ newOwnerId: ownerId });

      expect(res.status).toBe(400);
      expect(res.body.message).toContain('yourself');
    });
  });

  // ─── Access Control ─────────────────────────────────────────────

  describe('Org membership middleware', () => {
    it('should reject non-members from accessing org endpoints', async () => {
      const { token: ownerToken } = await createAuthenticatedManager();
      const createRes = await app
        .post('/api/organizations')
        .set('Authorization', `Bearer ${ownerToken}`)
        .send({ name: 'Private Org' });

      const orgId = createRes.body.id;

      // Different manager (not in org)
      const { token: outsiderToken } = await createAuthenticatedManager();

      const res = await app
        .get(`/api/organizations/${orgId}`)
        .set('Authorization', `Bearer ${outsiderToken}`);

      expect(res.status).toBe(403);
    });

    it('should reject member from admin-only actions', async () => {
      const { token: ownerToken } = await createAuthenticatedManager();
      const createRes = await app
        .post('/api/organizations')
        .set('Authorization', `Bearer ${ownerToken}`)
        .send({ name: 'Role Org' });
      const orgId = createRes.body.id;

      // Invite + join as member
      const inviteRes = await app
        .post(`/api/organizations/${orgId}/members`)
        .set('Authorization', `Bearer ${ownerToken}`)
        .send({ email: 'member@test.com' });

      const { token: memberToken } = await createAuthenticatedManager({
        email: 'member@test.com',
      });

      await app
        .post(`/api/organizations/join/${inviteRes.body.invite.token}`)
        .set('Authorization', `Bearer ${memberToken}`);

      // Member tries to update org name (requires admin)
      const res = await app
        .patch(`/api/organizations/${orgId}`)
        .set('Authorization', `Bearer ${memberToken}`)
        .send({ name: 'Hacked Name' });

      expect(res.status).toBe(403);
    });
  });

  // ─── Staff Governance ──────────────────────────────────────────

  describe('Staff governance', () => {
    let ownerToken: string;
    let orgId: string;
    let ownerId: any;

    beforeEach(async () => {
      const { manager, token } = await createAuthenticatedManager({ email: 'gov-owner@test.com' });
      ownerToken = token;
      ownerId = manager._id;

      const createRes = await app
        .post('/api/organizations')
        .set('Authorization', `Bearer ${ownerToken}`)
        .send({ name: 'Gov Org' });

      expect(createRes.status).toBe(201);
      orgId = createRes.body.id;
    });

    it('should update staff policy from open to restricted', async () => {
      const res = await app
        .patch(`/api/organizations/${orgId}/policy`)
        .set('Authorization', `Bearer ${ownerToken}`)
        .send({ staffPolicy: 'restricted' });

      expect(res.status).toBe(200);
      expect(res.body.staffPolicy).toBe('restricted');

      // Verify persisted
      const org = await OrganizationModel.findById(orgId).lean();
      expect(org?.staffPolicy).toBe('restricted');
    });

    it('should add staff to the approved pool', async () => {
      const res = await app
        .post(`/api/organizations/${orgId}/staff`)
        .set('Authorization', `Bearer ${ownerToken}`)
        .send({ provider: 'google', subject: 'approved-staff-1', name: 'Jane Doe', email: 'jane@test.com' });

      expect(res.status).toBe(201);
      expect(res.body.entry.provider).toBe('google');
      expect(res.body.entry.subject).toBe('approved-staff-1');
    });

    it('should reject duplicate staff in pool', async () => {
      await app
        .post(`/api/organizations/${orgId}/staff`)
        .set('Authorization', `Bearer ${ownerToken}`)
        .send({ provider: 'google', subject: 'dup-staff' });

      const res = await app
        .post(`/api/organizations/${orgId}/staff`)
        .set('Authorization', `Bearer ${ownerToken}`)
        .send({ provider: 'google', subject: 'dup-staff' });

      expect(res.status).toBe(409);
    });

    it('should list the staff pool', async () => {
      await app
        .post(`/api/organizations/${orgId}/staff`)
        .set('Authorization', `Bearer ${ownerToken}`)
        .send({ provider: 'google', subject: 'list-staff-1', name: 'Alice' });

      const res = await app
        .get(`/api/organizations/${orgId}/staff`)
        .set('Authorization', `Bearer ${ownerToken}`);

      expect(res.status).toBe(200);
      expect(res.body.staff).toHaveLength(1);
      expect(res.body.staff[0].name).toBe('Alice');
    });

    it('should remove staff from the pool', async () => {
      await app
        .post(`/api/organizations/${orgId}/staff`)
        .set('Authorization', `Bearer ${ownerToken}`)
        .send({ provider: 'google', subject: 'remove-me' });

      const res = await app
        .delete(`/api/organizations/${orgId}/staff/google/remove-me`)
        .set('Authorization', `Bearer ${ownerToken}`);

      expect(res.status).toBe(200);

      // Verify removed
      const org = await OrganizationModel.findById(orgId).lean();
      expect(org?.approvedStaff).toHaveLength(0);
    });

    it('should include staffPolicy and approvedStaffCount in GET mine', async () => {
      // Add a staff member
      await app
        .post(`/api/organizations/${orgId}/staff`)
        .set('Authorization', `Bearer ${ownerToken}`)
        .send({ provider: 'google', subject: 'count-staff' });

      const res = await app
        .get('/api/organizations/mine')
        .set('Authorization', `Bearer ${ownerToken}`);

      expect(res.status).toBe(200);
      expect(res.body.organization.staffPolicy).toBe('open');
      expect(res.body.organization.approvedStaffCount).toBe(1);
    });

    // ─── Enforcement tests ─────────────────────────────────────

    it('should block adding unlisted staff when policy is restricted', async () => {
      // Set policy to restricted
      await app
        .patch(`/api/organizations/${orgId}/policy`)
        .set('Authorization', `Bearer ${ownerToken}`)
        .send({ staffPolicy: 'restricted' });

      // Create a team
      const team = await createTestTeam(ownerId, 'Restricted Team');

      // Try to add staff not in pool
      const res = await app
        .post(`/api/teams/${team._id}/members`)
        .set('Authorization', `Bearer ${ownerToken}`)
        .send({
          provider: 'google',
          subject: 'unlisted-staff',
          email: 'unlisted@test.com',
          name: 'Unlisted',
        });

      expect(res.status).toBe(403);
      expect(res.body.message).toContain('not in organization approved pool');
    });

    it('should allow adding approved staff when policy is restricted', async () => {
      // Set policy to restricted and add staff to pool
      await app
        .patch(`/api/organizations/${orgId}/policy`)
        .set('Authorization', `Bearer ${ownerToken}`)
        .send({ staffPolicy: 'restricted' });

      await app
        .post(`/api/organizations/${orgId}/staff`)
        .set('Authorization', `Bearer ${ownerToken}`)
        .send({ provider: 'google', subject: 'approved-one' });

      // Create a team
      const team = await createTestTeam(ownerId, 'Approved Team');

      // Add approved staff — should succeed
      const res = await app
        .post(`/api/teams/${team._id}/members`)
        .set('Authorization', `Bearer ${ownerToken}`)
        .send({
          provider: 'google',
          subject: 'approved-one',
          email: 'approved@test.com',
          name: 'Approved',
        });

      expect(res.status).toBe(201);
    });

    it('should always allow adding staff when policy is open', async () => {
      // Policy defaults to 'open'
      const team = await createTestTeam(ownerId, 'Open Team');

      const res = await app
        .post(`/api/teams/${team._id}/members`)
        .set('Authorization', `Bearer ${ownerToken}`)
        .send({
          provider: 'google',
          subject: 'anyone-at-all',
          email: 'anyone@test.com',
          name: 'Anyone',
        });

      expect(res.status).toBe(201);
    });

    it('should always allow solo managers (no org) to add anyone', async () => {
      // Create a separate manager with no org
      const { manager: solo, token: soloToken } = await createAuthenticatedManager({ email: 'solo@test.com' });
      const team = await createTestTeam(solo._id, 'Solo Team');

      const res = await app
        .post(`/api/teams/${team._id}/members`)
        .set('Authorization', `Bearer ${soloToken}`)
        .send({
          provider: 'google',
          subject: 'freelance-staff',
          email: 'freelance@test.com',
          name: 'Freelance',
        });

      expect(res.status).toBe(201);
    });
  });
});
