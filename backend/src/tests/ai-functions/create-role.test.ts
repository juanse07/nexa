/**
 * Unit tests for create_role AI function
 * Tests the create_role function from src/routes/ai.ts
 */

import mongoose from 'mongoose';
import { RoleModel } from '../../models/role';
import { createMockManagerId, assertDocumentCreated } from '../helpers';

describe('create_role function', () => {
  let managerId: mongoose.Types.ObjectId;

  beforeEach(() => {
    managerId = createMockManagerId();
  });

  describe('Successful creation', () => {
    it('should successfully create a role with valid data', async () => {
      const roleName = 'Server';

      const created = await RoleModel.create({
        managerId,
        name: roleName,
      });

      assertDocumentCreated(created);
      expect(created.managerId.toString()).toBe(managerId.toString());
      expect(created.name).toBe(roleName);
      expect(created.normalizedName).toBe(roleName.toLowerCase());
    });

    it('should auto-generate normalizedName correctly', async () => {
      const roleName = 'Head Bartender';

      const created = await RoleModel.create({
        managerId,
        name: roleName,
      });

      expect(created.normalizedName).toBe('head bartender');
    });

    it('should trim whitespace from role name', async () => {
      const roleName = '   Executive Chef   ';

      const created = await RoleModel.create({
        managerId,
        name: roleName,
      });

      expect(created.name).toBe(roleName.trim());
      expect(created.normalizedName).toBe('executive chef');
    });

    it('should save to roles collection', async () => {
      const created = await RoleModel.create({
        managerId,
        name: 'Sommelier',
      });

      const found = await RoleModel.findById(created._id);
      expect(found).toBeDefined();
      expect(found?.name).toBe('Sommelier');
    });

    it('should set timestamps (createdAt, updatedAt)', async () => {
      const created = await RoleModel.create({
        managerId,
        name: 'Captain',
      });

      expect(created.createdAt).toBeInstanceOf(Date);
      expect(created.updatedAt).toBeInstanceOf(Date);
      expect(created.createdAt.getTime()).toBeLessThanOrEqual(created.updatedAt.getTime());
    });
  });

  describe('Validation errors', () => {
    it('should reject duplicate role (same name, case-insensitive)', async () => {
      const roleName = 'Bartender';

      // Create first role
      await RoleModel.create({
        managerId,
        name: roleName,
      });

      // Try to create duplicate with same name (different case)
      await expect(
        RoleModel.create({
          managerId,
          name: 'BARTENDER',
        })
      ).rejects.toThrow();
    });

    it('should require name field', async () => {
      await expect(
        RoleModel.create({
          managerId,
          // @ts-expect-error Testing missing required field
          name: undefined,
        })
      ).rejects.toThrow();
    });

    it('should require valid managerId ObjectId', async () => {
      await expect(
        RoleModel.create({
          // @ts-expect-error Testing invalid managerId
          managerId: 'invalid-id',
          name: 'Server',
        })
      ).rejects.toThrow();
    });
  });

  describe('Database constraints', () => {
    it('should create unique index on managerId + normalizedName', async () => {
      const roleName = 'Server';

      // Create role for manager 1
      await RoleModel.create({
        managerId,
        name: roleName,
      });

      // Same name for different manager should succeed
      const differentManagerId = createMockManagerId();
      const created = await RoleModel.create({
        managerId: differentManagerId,
        name: roleName,
      });

      expect(created.managerId.toString()).toBe(differentManagerId.toString());
    });

    it('should handle case-insensitive duplicates correctly', async () => {
      const roleName = 'Event Coordinator';

      // Create first role
      await RoleModel.create({
        managerId,
        name: roleName,
      });

      // Try variations of case
      await expect(
        RoleModel.create({
          managerId,
          name: 'event coordinator', // All lowercase
        })
      ).rejects.toThrow();

      await expect(
        RoleModel.create({
          managerId,
          name: 'EVENT COORDINATOR', // All uppercase
        })
      ).rejects.toThrow();
    });
  });
});
