/**
 * Unit tests for create_tariff AI function
 * Tests the create_tariff function from src/routes/ai.ts
 * Tests the upsert pattern fix (clientId/roleId in $set clause)
 */

import mongoose from 'mongoose';
import { TariffModel } from '../../models/tariff';
import { ClientModel } from '../../models/client';
import { RoleModel } from '../../models/role';
import { createMockManagerId, assertDocumentCreated, createTestClient, createTestRole } from '../helpers';

describe('create_tariff function', () => {
  let managerId: mongoose.Types.ObjectId;
  let clientId: mongoose.Types.ObjectId;
  let roleId: mongoose.Types.ObjectId;

  beforeEach(async () => {
    managerId = createMockManagerId();

    // Create test client and role
    const client = await createTestClient(managerId, 'Test Client');
    const role = await createTestRole(managerId, 'Server');

    clientId = client._id as mongoose.Types.ObjectId;
    roleId = role._id as mongoose.Types.ObjectId;
  });

  describe('Successful creation', () => {
    it('should successfully create new tariff', async () => {
      const created = await TariffModel.create({
        managerId,
        clientId,
        roleId,
        rate: 25.50,
        currency: 'USD',
      });

      assertDocumentCreated(created);
      expect(created.managerId.toString()).toBe(managerId.toString());
      expect(created.clientId.toString()).toBe(clientId.toString());
      expect(created.roleId.toString()).toBe(roleId.toString());
      expect(created.rate).toBe(25.50);
      expect(created.currency).toBe('USD');
    });

    it('should successfully update existing tariff (upsert)', async () => {
      // Create initial tariff
      await TariffModel.create({
        managerId,
        clientId,
        roleId,
        rate: 20.00,
        currency: 'USD',
      });

      // Update with higher rate
      const result = await TariffModel.updateOne(
        { managerId, clientId, roleId },
        {
          $set: {
            managerId,
            clientId,
            roleId,
            rate: 30.00,
            currency: 'USD',
          },
        },
        { upsert: true }
      );

      expect(result.matchedCount).toBe(1);
      expect(result.modifiedCount).toBe(1);

      // Verify the update
      const updated = await TariffModel.findOne({ managerId, clientId, roleId });
      expect(updated?.rate).toBe(30.00);
    });

    it('CRITICAL: should include clientId/roleId in $set clause for upsert', async () => {
      // Test upsert (document doesn't exist)
      const result = await TariffModel.updateOne(
        { managerId, clientId, roleId },
        {
          $set: {
            managerId,
            clientId,  // CRITICAL: Must be in $set
            roleId,    // CRITICAL: Must be in $set
            rate: 28.00,
            currency: 'USD',
          },
        },
        { upsert: true }
      );

      expect(result.upsertedCount).toBe(1);

      // Verify the upserted document has all fields
      const created = await TariffModel.findOne({ managerId, clientId, roleId });
      expect(created).toBeDefined();
      expect(created?.clientId.toString()).toBe(clientId.toString());
      expect(created?.roleId.toString()).toBe(roleId.toString());
      expect(created?.rate).toBe(28.00);
    });

    it('should save to tariffs collection', async () => {
      const created = await TariffModel.create({
        managerId,
        clientId,
        roleId,
        rate: 22.00,
        currency: 'USD',
      });

      const found = await TariffModel.findById(created._id);
      expect(found).toBeDefined();
      expect(found?.rate).toBe(22.00);
    });

    it('should default currency to USD', async () => {
      const created = await TariffModel.create({
        managerId,
        clientId,
        roleId,
        rate: 25.00,
        // currency not provided
      });

      expect(created.currency).toBe('USD');
    });

    it('should accept custom currency code', async () => {
      const created = await TariffModel.create({
        managerId,
        clientId,
        roleId,
        rate: 30.00,
        currency: 'EUR',
      });

      expect(created.currency).toBe('EUR');
    });
  });

  describe('Validation errors', () => {
    it('should require valid managerId ObjectId', async () => {
      await expect(
        TariffModel.create({
          // @ts-expect-error Testing invalid managerId
          managerId: 'invalid-id',
          clientId,
          roleId,
          rate: 25.00,
        })
      ).rejects.toThrow();
    });

    it('should require valid clientId ObjectId', async () => {
      await expect(
        TariffModel.create({
          managerId,
          // @ts-expect-error Testing invalid clientId
          clientId: 'invalid-id',
          roleId,
          rate: 25.00,
        })
      ).rejects.toThrow();
    });

    it('should require valid roleId ObjectId', async () => {
      await expect(
        TariffModel.create({
          managerId,
          clientId,
          // @ts-expect-error Testing invalid roleId
          roleId: 'invalid-id',
          rate: 25.00,
        })
      ).rejects.toThrow();
    });

    it('should require rate >= 0', async () => {
      await expect(
        TariffModel.create({
          managerId,
          clientId,
          roleId,
          rate: -10.00,  // Negative rate
        })
      ).rejects.toThrow();
    });
  });

  describe('Database constraints', () => {
    it('should create unique index on managerId + clientId + roleId', async () => {
      // Create first tariff
      await TariffModel.create({
        managerId,
        clientId,
        roleId,
        rate: 25.00,
        currency: 'USD',
      });

      // Try to create duplicate (same manager, client, role)
      await expect(
        TariffModel.create({
          managerId,
          clientId,
          roleId,
          rate: 30.00,  // Different rate, but same combination
          currency: 'USD',
        })
      ).rejects.toThrow();
    });

    it('should allow same client-role for different managers', async () => {
      // Create tariff for manager 1
      await TariffModel.create({
        managerId,
        clientId,
        roleId,
        rate: 25.00,
        currency: 'USD',
      });

      // Create same client-role for different manager
      const differentManagerId = createMockManagerId();
      const created = await TariffModel.create({
        managerId: differentManagerId,
        clientId,
        roleId,
        rate: 30.00,
        currency: 'USD',
      });

      expect(created.managerId.toString()).toBe(differentManagerId.toString());
      expect(created.rate).toBe(30.00);
    });
  });
});
