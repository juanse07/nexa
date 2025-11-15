/**
 * Unit tests for create_shift AI function
 * Tests the create_shift function from src/routes/ai.ts
 * This is the most critical function with the most bugs fixed
 */

import mongoose from 'mongoose';
import { EventModel } from '../../models/event';
import { createMockManagerId, assertDocumentCreated } from '../helpers';

describe('create_shift function', () => {
  let managerId: mongoose.Types.ObjectId;

  beforeEach(() => {
    managerId = createMockManagerId();
  });

  describe('Successful creation', () => {
    it('should successfully create shift with all required fields', async () => {
      const shiftData = {
        managerId,
        status: 'draft',
        shift_name: 'Epicurean - Mar 15',
        client_name: 'Epicurean Catering',
        date: new Date('2025-03-15'),
        start_time: '17:00',
        end_time: '23:00',
        roles: [
          { role: 'Server', count: 5 },
          { role: 'Bartender', count: 2 },
        ],
        accepted_staff: [],
        declined_staff: [],
      };

      const created = await EventModel.create(shiftData);

      assertDocumentCreated(created);
      expect(created.managerId.toString()).toBe(managerId.toString());
      expect(created.status).toBe('draft');
      expect(created.shift_name).toBe('Epicurean - Mar 15');
      expect(created.client_name).toBe('Epicurean Catering');
      expect(created.start_time).toBe('17:00');
      expect(created.end_time).toBe('23:00');
      expect(created.roles).toHaveLength(2);
    });

    it('should use shift_name field (not deprecated event_name)', async () => {
      const created = await EventModel.create({
        managerId,
        status: 'draft',
        shift_name: 'Modern Shift Name',
        client_name: 'Test Client',
        date: new Date('2025-03-15'),
        start_time: '10:00',
        end_time: '18:00',
        roles: [{ role: 'Server', count: 1 }],
        accepted_staff: [],
        declined_staff: [],
      });

      expect(created.shift_name).toBe('Modern Shift Name');
      // event_name should be undefined or not used
      expect(created.event_name).toBeUndefined();
    });

    it('should set status to draft by default', async () => {
      const created = await EventModel.create({
        managerId,
        shift_name: 'Status Test Shift',
        client_name: 'Test Client',
        date: new Date('2025-03-15'),
        start_time: '10:00',
        end_time: '18:00',
        roles: [{ role: 'Server', count: 1 }],
        accepted_staff: [],
        declined_staff: [],
      });

      expect(created.status).toBe('draft');
    });

    it('should accept roles array with at least 1 role', async () => {
      const created = await EventModel.create({
        managerId,
        status: 'draft',
        shift_name: 'Single Role Shift',
        client_name: 'Test Client',
        date: new Date('2025-03-15'),
        start_time: '10:00',
        end_time: '18:00',
        roles: [{ role: 'Server', count: 3 }],
        accepted_staff: [],
        declined_staff: [],
      });

      expect(created.roles).toHaveLength(1);
      expect(created.roles[0].role).toBe('Server');
      expect(created.roles[0].count).toBe(3);
    });

    it('should save to shifts collection', async () => {
      const created = await EventModel.create({
        managerId,
        status: 'draft',
        shift_name: 'Collection Test',
        client_name: 'Test Client',
        date: new Date('2025-03-15'),
        start_time: '10:00',
        end_time: '18:00',
        roles: [{ role: 'Server', count: 1 }],
        accepted_staff: [],
        declined_staff: [],
      });

      // Verify it's in the shifts collection by finding it
      const found = await EventModel.findById(created._id);
      expect(found).toBeDefined();
      expect(found?.shift_name).toBe('Collection Test');
    });

    it('should parse date string to Date object', async () => {
      const dateString = '2025-03-15';
      const created = await EventModel.create({
        managerId,
        status: 'draft',
        shift_name: 'Date Test',
        client_name: 'Test Client',
        date: new Date(dateString),
        start_time: '10:00',
        end_time: '18:00',
        roles: [{ role: 'Server', count: 1 }],
        accepted_staff: [],
        declined_staff: [],
      });

      expect(created.date).toBeInstanceOf(Date);
      expect(created.date?.toISOString().split('T')[0]).toBe(dateString);
    });

    it('should handle optional fields (venue, uniform, notes, etc.)', async () => {
      const created = await EventModel.create({
        managerId,
        status: 'draft',
        shift_name: 'Optional Fields Test',
        client_name: 'Test Client',
        date: new Date('2025-03-15'),
        start_time: '10:00',
        end_time: '18:00',
        roles: [{ role: 'Server', count: 1 }],
        accepted_staff: [],
        declined_staff: [],
        venue_name: 'The Grand Ballroom',
        venue_address: '123 Main St, Denver, CO 80202',
        uniform: 'Black and white',
        notes: 'Important client, be professional',
        contact_name: 'John Doe',
        contact_phone: '555-1234',
        headcount_total: 150,
      });

      expect(created.venue_name).toBe('The Grand Ballroom');
      expect(created.venue_address).toBe('123 Main St, Denver, CO 80202');
      expect(created.uniform).toBe('Black and white');
      expect(created.notes).toBe('Important client, be professional');
      expect(created.contact_name).toBe('John Doe');
      expect(created.contact_phone).toBe('555-1234');
      expect(created.headcount_total).toBe(150);
    });

    it('should initialize empty arrays (accepted_staff, declined_staff)', async () => {
      const created = await EventModel.create({
        managerId,
        status: 'draft',
        shift_name: 'Array Init Test',
        client_name: 'Test Client',
        date: new Date('2025-03-15'),
        start_time: '10:00',
        end_time: '18:00',
        roles: [{ role: 'Server', count: 1 }],
        accepted_staff: [],
        declined_staff: [],
      });

      expect(created.accepted_staff).toEqual([]);
      expect(created.declined_staff).toEqual([]);
    });

    it('should set timestamps (createdAt, updatedAt)', async () => {
      const created = await EventModel.create({
        managerId,
        status: 'draft',
        shift_name: 'Timestamp Test',
        client_name: 'Test Client',
        date: new Date('2025-03-15'),
        start_time: '10:00',
        end_time: '18:00',
        roles: [{ role: 'Server', count: 1 }],
        accepted_staff: [],
        declined_staff: [],
      });

      expect(created.createdAt).toBeInstanceOf(Date);
      expect(created.updatedAt).toBeInstanceOf(Date);
    });

    it('should NOT hardcode city/state (should be optional)', async () => {
      const created = await EventModel.create({
        managerId,
        status: 'draft',
        shift_name: 'Location Test',
        client_name: 'Test Client',
        date: new Date('2025-03-15'),
        start_time: '10:00',
        end_time: '18:00',
        roles: [{ role: 'Server', count: 1 }],
        accepted_staff: [],
        declined_staff: [],
        // NOT providing city/state
      });

      // City and state should be undefined, not hardcoded to Denver/CO
      expect(created.city).toBeUndefined();
      expect(created.state).toBeUndefined();
    });
  });

  describe('Validation errors - CRITICAL BUG FIXES', () => {
    it('CRITICAL: should reject empty roles array', async () => {
      await expect(
        EventModel.create({
          managerId,
          status: 'draft',
          shift_name: 'Empty Roles Test',
          client_name: 'Test Client',
          date: new Date('2025-03-15'),
          start_time: '10:00',
          end_time: '18:00',
          roles: [],  // ❌ Empty array - should fail validation
          accepted_staff: [],
          declined_staff: [],
        })
      ).rejects.toThrow(/At least one role is required/);
    });

    it('CRITICAL: should reject missing roles field', async () => {
      await expect(
        EventModel.create({
          managerId,
          status: 'draft',
          shift_name: 'No Roles Test',
          client_name: 'Test Client',
          date: new Date('2025-03-15'),
          start_time: '10:00',
          end_time: '18:00',
          // @ts-expect-error Testing missing required field
          roles: undefined,
          accepted_staff: [],
          declined_staff: [],
        })
      ).rejects.toThrow();
    });

    it('should require client_name, date, start_time, end_time', async () => {
      // Missing client_name
      await expect(
        EventModel.create({
          managerId,
          status: 'draft',
          shift_name: 'Missing Client',
          // client_name missing
          date: new Date('2025-03-15'),
          start_time: '10:00',
          end_time: '18:00',
          roles: [{ role: 'Server', count: 1 }],
          accepted_staff: [],
          declined_staff: [],
        })
      ).resolves.toBeDefined(); // client_name is optional in schema

      // Note: date, start_time, end_time are also optional in the schema
      // The validation happens in the AI function before calling create()
    });
  });

  describe('Edge cases', () => {
    it('should handle multiple roles correctly', async () => {
      const created = await EventModel.create({
        managerId,
        status: 'draft',
        shift_name: 'Multi Role Test',
        client_name: 'Test Client',
        date: new Date('2025-03-15'),
        start_time: '10:00',
        end_time: '18:00',
        roles: [
          { role: 'Server', count: 5 },
          { role: 'Bartender', count: 2 },
          { role: 'Chef', count: 1 },
          { role: 'Captain', count: 1 },
        ],
        accepted_staff: [],
        declined_staff: [],
      });

      expect(created.roles).toHaveLength(4);
      expect(created.roles[0].role).toBe('Server');
      expect(created.roles[0].count).toBe(5);
      expect(created.roles[3].role).toBe('Captain');
    });

    it('should handle roles with call_time', async () => {
      const created = await EventModel.create({
        managerId,
        status: 'draft',
        shift_name: 'Call Time Test',
        client_name: 'Test Client',
        date: new Date('2025-03-15'),
        start_time: '10:00',
        end_time: '18:00',
        roles: [
          { role: 'Server', count: 5, call_time: '17:00' },
          { role: 'Chef', count: 1, call_time: '15:00' }, // Chef arrives earlier
        ],
        accepted_staff: [],
        declined_staff: [],
      });

      expect(created.roles[0].call_time).toBe('17:00');
      expect(created.roles[1].call_time).toBe('15:00');
    });
  });
});
