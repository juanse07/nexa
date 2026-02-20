import { isInFreeMonth, getFreeMonthEndDate, isReadOnly, getAccessLevel } from '../../utils/subscriptionUtils';

describe('subscriptionUtils', () => {
  describe('getFreeMonthEndDate', () => {
    it('returns createdAt + 30 days when no override', () => {
      const createdAt = new Date('2026-02-01T00:00:00Z');
      const result = getFreeMonthEndDate({ createdAt, free_month_end_override: undefined });
      const expected = new Date('2026-03-03T00:00:00Z'); // Feb has 28 days, +30 = Mar 3
      expect(result.getTime()).toBe(expected.getTime());
    });

    it('returns override date when set', () => {
      const createdAt = new Date('2025-01-01T00:00:00Z');
      const override = new Date('2026-04-01T00:00:00Z');
      const result = getFreeMonthEndDate({ createdAt, free_month_end_override: override });
      expect(result.getTime()).toBe(override.getTime());
    });
  });

  describe('isInFreeMonth', () => {
    it('returns true for user created today', () => {
      const user = { createdAt: new Date(), free_month_end_override: undefined };
      expect(isInFreeMonth(user)).toBe(true);
    });

    it('returns true for user created 29 days ago', () => {
      const createdAt = new Date(Date.now() - 29 * 24 * 60 * 60 * 1000);
      const user = { createdAt, free_month_end_override: undefined };
      expect(isInFreeMonth(user)).toBe(true);
    });

    it('returns false for user created 31 days ago', () => {
      const createdAt = new Date(Date.now() - 31 * 24 * 60 * 60 * 1000);
      const user = { createdAt, free_month_end_override: undefined };
      expect(isInFreeMonth(user)).toBe(false);
    });

    it('returns true when override is in the future', () => {
      const createdAt = new Date('2025-01-01T00:00:00Z'); // very old
      const override = new Date(Date.now() + 5 * 24 * 60 * 60 * 1000); // 5 days from now
      const user = { createdAt, free_month_end_override: override };
      expect(isInFreeMonth(user)).toBe(true);
    });

    it('returns false when override is in the past', () => {
      const createdAt = new Date('2025-01-01T00:00:00Z');
      const override = new Date(Date.now() - 1 * 24 * 60 * 60 * 1000); // yesterday
      const user = { createdAt, free_month_end_override: override };
      expect(isInFreeMonth(user)).toBe(false);
    });
  });

  describe('isReadOnly', () => {
    it('returns false for pro active user', () => {
      const user = {
        subscription_tier: 'pro' as const,
        subscription_status: 'active' as const,
        createdAt: new Date('2024-01-01'),
        free_month_end_override: undefined,
      };
      expect(isReadOnly(user)).toBe(false);
    });

    it('returns false for premium active user', () => {
      const user = {
        subscription_tier: 'premium' as const,
        subscription_status: 'active' as const,
        createdAt: new Date('2024-01-01'),
        free_month_end_override: undefined,
      };
      expect(isReadOnly(user)).toBe(false);
    });

    it('returns false for free user in free month', () => {
      const user = {
        subscription_tier: 'free' as const,
        subscription_status: 'free_month' as const,
        createdAt: new Date(), // just created
        free_month_end_override: undefined,
      };
      expect(isReadOnly(user)).toBe(false);
    });

    it('returns true for free user after free month', () => {
      const user = {
        subscription_tier: 'free' as const,
        subscription_status: 'expired' as const,
        createdAt: new Date('2024-01-01'), // old
        free_month_end_override: undefined,
      };
      expect(isReadOnly(user)).toBe(true);
    });

    it('returns true for pro cancelled user after free month', () => {
      const user = {
        subscription_tier: 'pro' as const,
        subscription_status: 'cancelled' as const,
        createdAt: new Date('2024-01-01'), // old
        free_month_end_override: undefined,
      };
      expect(isReadOnly(user)).toBe(true);
    });

    it('returns false for migrated user with fresh override', () => {
      const user = {
        subscription_tier: 'free' as const,
        subscription_status: 'free_month' as const,
        createdAt: new Date('2024-01-01'), // very old
        free_month_end_override: new Date(Date.now() + 15 * 24 * 60 * 60 * 1000), // 15 days from now
      };
      expect(isReadOnly(user)).toBe(false);
    });
  });

  describe('getAccessLevel', () => {
    it('returns full for active pro user', () => {
      const user = {
        subscription_tier: 'pro' as const,
        subscription_status: 'active' as const,
        createdAt: new Date('2024-01-01'),
        free_month_end_override: undefined,
      };
      expect(getAccessLevel(user)).toBe('full');
    });

    it('returns read_only for expired free user', () => {
      const user = {
        subscription_tier: 'free' as const,
        subscription_status: 'expired' as const,
        createdAt: new Date('2024-01-01'),
        free_month_end_override: undefined,
      };
      expect(getAccessLevel(user)).toBe('read_only');
    });
  });
});
