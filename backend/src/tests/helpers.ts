/**
 * Test helper utilities
 */

import mongoose from 'mongoose';
import jwt from 'jsonwebtoken';
import request from 'supertest';
import { ClientModel } from '../models/client';
import { RoleModel } from '../models/role';
import { ManagerModel } from '../models/manager';
import { UserModel } from '../models/user';
import { EventModel } from '../models/event';
import { TariffModel } from '../models/tariff';
import { TeamModel } from '../models/team';
import { createServer } from '../index';

const TEST_JWT_SECRET = 'test-jwt-secret-for-testing';

/**
 * Generate a signed JWT for testing
 */
export function generateTestToken(claims: Record<string, any>): string {
  return jwt.sign(claims, TEST_JWT_SECRET, { algorithm: 'HS256', expiresIn: '1h' });
}

/**
 * Create an authenticated manager in the DB and return manager + token
 */
export async function createAuthenticatedManager(overrides: Record<string, any> = {}) {
  const manager = await ManagerModel.create({
    provider: 'google',
    subject: `test-mgr-${Date.now()}-${Math.random().toString(36).slice(2)}`,
    email: `mgr-${Date.now()}@test.com`,
    name: 'Test Manager',
    first_name: 'Test',
    last_name: 'Manager',
    ...overrides,
  });
  const token = generateTestToken({
    sub: manager.subject,
    provider: manager.provider,
    email: manager.email,
    managerId: manager._id.toString(),
  });
  return { manager, token };
}

/**
 * Create an authenticated staff user in the DB and return user + token
 */
export async function createAuthenticatedStaffUser(overrides: Record<string, any> = {}) {
  const user = await UserModel.create({
    provider: 'google',
    subject: `test-staff-${Date.now()}-${Math.random().toString(36).slice(2)}`,
    email: `staff-${Date.now()}@test.com`,
    name: 'Test Staff',
    ...overrides,
  });
  const token = generateTestToken({
    sub: user.subject,
    provider: user.provider,
    email: user.email,
  });
  return { user, token };
}

/**
 * Create a test event in the DB
 */
export async function createTestEvent(managerId: mongoose.Types.ObjectId, overrides: Record<string, any> = {}) {
  const roles = overrides.roles || [
    { role: 'Bartender', count: 3 },
    { role: 'Server', count: 5 },
  ];
  const accepted_staff = overrides.accepted_staff || [];
  // Compute role_stats from roles and accepted_staff
  const role_stats = roles.map((r: any) => {
    const taken = accepted_staff.filter((s: any) => s.role === r.role && s.response === 'accepted').length;
    return {
      role: r.role,
      capacity: r.count,
      taken,
      remaining: Math.max(r.count - taken, 0),
      is_full: r.count - taken <= 0 && r.count > 0,
    };
  });

  const event = await EventModel.create({
    managerId,
    client_name: 'Test Client',
    event_name: 'Test Event',
    shift_name: 'Test Shift',
    date: new Date('2025-12-20'),
    start_time: '18:00',
    end_time: '23:00',
    venue_name: 'Test Venue',
    venue_address: '123 Test St',
    city: 'Denver',
    state: 'CO',
    status: 'draft',
    roles,
    accepted_staff,
    role_stats,
    ...overrides,
    // Override role_stats if explicitly provided
    ...(overrides.role_stats ? { role_stats: overrides.role_stats } : { role_stats }),
  });
  return event;
}

/**
 * Create a test tariff in the DB
 */
export async function createTestTariff(
  managerId: mongoose.Types.ObjectId,
  clientId: mongoose.Types.ObjectId,
  roleId: mongoose.Types.ObjectId,
  overrides: Record<string, any> = {}
) {
  const tariff = await TariffModel.create({
    managerId,
    clientId,
    roleId,
    rate: 25,
    ...overrides,
  });
  return tariff;
}

/**
 * Create a test team in the DB
 */
export async function createTestTeam(managerId: mongoose.Types.ObjectId, name: string = 'Test Team') {
  const team = await TeamModel.create({
    managerId,
    name,
  });
  return team;
}

/**
 * Get a supertest-wrapped Express app for HTTP tests
 */
export async function getTestApp() {
  const app = await createServer();
  return request(app);
}

// Legacy helpers (preserved from original)
export function createMockManagerId(): mongoose.Types.ObjectId {
  return new mongoose.Types.ObjectId();
}

export async function createTestClient(managerId: mongoose.Types.ObjectId, name: string = 'Test Client') {
  return ClientModel.create({ managerId, name });
}

export async function createTestRole(managerId: mongoose.Types.ObjectId, name: string = 'Test Role') {
  return RoleModel.create({ managerId, name });
}

export async function cleanupTestData() {
  await Promise.all([
    ClientModel.deleteMany({}),
    RoleModel.deleteMany({}),
    ManagerModel.deleteMany({}),
  ]);
}

export function assertDocumentCreated(document: any) {
  expect(document).toBeDefined();
  expect(document._id).toBeDefined();
  expect(document.createdAt).toBeDefined();
  expect(document.updatedAt).toBeDefined();
}

export function assertDatesApproximatelyEqual(date1: Date, date2: Date) {
  const diff = Math.abs(date1.getTime() - date2.getTime());
  expect(diff).toBeLessThan(1000);
}
