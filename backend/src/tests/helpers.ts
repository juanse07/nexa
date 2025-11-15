/**
 * Test helper utilities for AI function testing
 */

import mongoose from 'mongoose';
import { ClientModel } from '../models/client';
import { RoleModel } from '../models/role';
import { ManagerModel } from '../models/manager';

/**
 * Create a mock manager ID for testing
 */
export function createMockManagerId(): mongoose.Types.ObjectId {
  return new mongoose.Types.ObjectId();
}

/**
 * Create a test manager in the database
 */
export async function createTestManager() {
  const manager = await ManagerModel.create({
    provider: 'google',
    subject: `test-${Date.now()}`,
    email: `test-${Date.now()}@example.com`,
    name: 'Test Manager',
    first_name: 'Test',
    last_name: 'Manager',
  });

  return manager;
}

/**
 * Create a test client in the database
 */
export async function createTestClient(managerId: mongoose.Types.ObjectId, name: string = 'Test Client') {
  const client = await ClientModel.create({
    managerId,
    name,
  });

  return client;
}

/**
 * Create a test role in the database
 */
export async function createTestRole(managerId: mongoose.Types.ObjectId, name: string = 'Test Role') {
  const role = await RoleModel.create({
    managerId,
    name,
  });

  return role;
}

/**
 * Clean up all test data
 */
export async function cleanupTestData() {
  await Promise.all([
    ClientModel.deleteMany({}),
    RoleModel.deleteMany({}),
    ManagerModel.deleteMany({}),
  ]);
}

/**
 * Assert that a MongoDB document was created
 */
export function assertDocumentCreated(document: any) {
  expect(document).toBeDefined();
  expect(document._id).toBeDefined();
  expect(document.createdAt).toBeDefined();
  expect(document.updatedAt).toBeDefined();
}

/**
 * Assert that two dates are approximately equal (within 1 second)
 */
export function assertDatesApproximatelyEqual(date1: Date, date2: Date) {
  const diff = Math.abs(date1.getTime() - date2.getTime());
  expect(diff).toBeLessThan(1000); // Within 1 second
}
