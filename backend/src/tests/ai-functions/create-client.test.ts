/**
 * Unit tests for create_client AI function
 * Tests the create_client function from src/routes/ai.ts
 */

import mongoose from 'mongoose';
import { ClientModel } from '../../models/client';
import { createMockManagerId, assertDocumentCreated, createTestClient } from '../helpers';

// Import the function we're testing (we'll call it through the model directly)
// Since the function is part of the route handler, we'll test the underlying logic

describe('create_client function', () => {
  let managerId: mongoose.Types.ObjectId;

  beforeEach(() => {
    managerId = createMockManagerId();
  });

  describe('Successful creation', () => {
    it('should successfully create a client with valid data', async () => {
      const clientName = 'Epicurean Catering';

      const created = await ClientModel.create({
        managerId,
        name: clientName,
      });

      assertDocumentCreated(created);
      expect(created.managerId.toString()).toBe(managerId.toString());
      expect(created.name).toBe(clientName);
      expect(created.normalizedName).toBe(clientName.toLowerCase());
    });

    it('should auto-generate normalizedName correctly', async () => {
      const clientName = 'TEST Client Company';

      const created = await ClientModel.create({
        managerId,
        name: clientName,
      });

      expect(created.normalizedName).toBe('test client company');
    });

    it('should trim whitespace from client name', async () => {
      const clientName = '   Whitespace Client   ';

      const created = await ClientModel.create({
        managerId,
        name: clientName,
      });

      expect(created.name).toBe(clientName.trim());
      expect(created.normalizedName).toBe('whitespace client');
    });

    it('should save to clients collection', async () => {
      const created = await ClientModel.create({
        managerId,
        name: 'Collection Test Client',
      });

      const found = await ClientModel.findById(created._id);
      expect(found).toBeDefined();
      expect(found?.name).toBe('Collection Test Client');
    });

    it('should set timestamps (createdAt, updatedAt)', async () => {
      const created = await ClientModel.create({
        managerId,
        name: 'Timestamp Client',
      });

      expect(created.createdAt).toBeInstanceOf(Date);
      expect(created.updatedAt).toBeInstanceOf(Date);
      expect(created.createdAt.getTime()).toBeLessThanOrEqual(created.updatedAt.getTime());
    });
  });

  describe('Validation errors', () => {
    it('should reject duplicate client (same name, case-insensitive)', async () => {
      const clientName = 'Duplicate Client';

      // Create first client
      await ClientModel.create({
        managerId,
        name: clientName,
      });

      // Try to create duplicate with same name (different case)
      await expect(
        ClientModel.create({
          managerId,
          name: 'DUPLICATE CLIENT',
        })
      ).rejects.toThrow();
    });

    it('should require name field', async () => {
      await expect(
        ClientModel.create({
          managerId,
          // @ts-expect-error Testing missing required field
          name: undefined,
        })
      ).rejects.toThrow();
    });

    it('should require valid managerId ObjectId', async () => {
      await expect(
        ClientModel.create({
          // @ts-expect-error Testing invalid managerId
          managerId: 'invalid-id',
          name: 'Test Client',
        })
      ).rejects.toThrow();
    });
  });

  describe('Database constraints', () => {
    it('should create unique index on managerId + normalizedName', async () => {
      const clientName = 'Index Test Client';

      // Create client for manager 1
      await ClientModel.create({
        managerId,
        name: clientName,
      });

      // Same name for different manager should succeed
      const differentManagerId = createMockManagerId();
      const created = await ClientModel.create({
        managerId: differentManagerId,
        name: clientName,
      });

      expect(created.managerId.toString()).toBe(differentManagerId.toString());
    });

    it('should handle case-insensitive duplicates correctly', async () => {
      const clientName = 'Case Sensitive Client';

      // Create first client
      await ClientModel.create({
        managerId,
        name: clientName,
      });

      // Try variations of case
      await expect(
        ClientModel.create({
          managerId,
          name: 'case sensitive client', // All lowercase
        })
      ).rejects.toThrow();

      await expect(
        ClientModel.create({
          managerId,
          name: 'CASE SENSITIVE CLIENT', // All uppercase
        })
      ).rejects.toThrow();
    });
  });
});
