import { UserDocument } from '../models/user';

const THIRTY_DAYS_MS = 30 * 24 * 60 * 60 * 1000;

/**
 * Get the date when the user's free month ends.
 * Uses free_month_end_override if set, otherwise createdAt + 30 days.
 */
export function getFreeMonthEndDate(user: Pick<UserDocument, 'createdAt' | 'free_month_end_override'>): Date {
  if (user.free_month_end_override) {
    return new Date(user.free_month_end_override);
  }
  return new Date(new Date(user.createdAt).getTime() + THIRTY_DAYS_MS);
}

/**
 * Check if a user is currently within their free month.
 */
export function isInFreeMonth(user: Pick<UserDocument, 'createdAt' | 'free_month_end_override'>): boolean {
  const endDate = getFreeMonthEndDate(user);
  return new Date() < endDate;
}

/**
 * Check if a user is in read-only mode (cannot perform write actions).
 * A user is NOT read-only if they have an active pro/premium subscription OR are in their free month.
 */
export function isReadOnly(user: Pick<UserDocument, 'subscription_tier' | 'subscription_status' | 'createdAt' | 'free_month_end_override'>): boolean {
  // Pro/premium with active status always have full access
  const tier = user.subscription_tier || 'free';
  const status = user.subscription_status || 'free_month';

  if ((tier === 'pro' || tier === 'premium') && (status === 'active' || status === 'trial')) {
    return false;
  }

  // Everyone else is read-only
  return true;
}

/**
 * Get the user's access level.
 */
export function getAccessLevel(user: Pick<UserDocument, 'subscription_tier' | 'subscription_status' | 'createdAt' | 'free_month_end_override'>): 'full' | 'read_only' {
  return isReadOnly(user) ? 'read_only' : 'full';
}
