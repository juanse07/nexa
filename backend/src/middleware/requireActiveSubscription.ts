import { Request, Response, NextFunction } from 'express';
import { UserModel } from '../models/user';
import { isReadOnly, isInFreeMonth, getFreeMonthEndDate } from '../utils/subscriptionUtils';
import { cache, CacheKeys, CacheTTL } from '../services/cacheService';

/**
 * Middleware that blocks write actions for staff users in read-only mode.
 * Managers (identified by managerId in JWT) are always allowed through.
 * Must be placed AFTER requireAuth in the middleware chain.
 *
 * Caches subscription tier lookup in Redis to avoid hitting MongoDB on every request.
 */
export function requireActiveSubscription(req: Request, res: Response, next: NextFunction) {
  const authUser = (req as any).user;
  if (!authUser?.provider || !authUser?.sub) {
    return res.status(401).json({ message: 'Unauthorized' });
  }

  // Managers use their own subscription model — skip check
  if (authUser.managerId) {
    return next();
  }

  const userKey = `${authUser.provider}:${authUser.sub}`;

  // Try cache first, then MongoDB
  cache.get(CacheKeys.subscriptionTier(userKey))
    .then((cached: any) => {
      if (cached) {
        // Use cached subscription data
        if (cached.readOnly) {
          return res.status(403).json({
            readOnly: true,
            message: 'Active subscription required',
            freeMonth: cached.freeMonth,
          });
        }
        return next();
      }

      // Cache miss — load from MongoDB
      return UserModel.findOne({ provider: authUser.provider, subject: authUser.sub })
        .select('subscription_tier subscription_status createdAt free_month_end_override')
        .lean()
        .then((user) => {
          if (!user) {
            return res.status(404).json({ message: 'User not found' });
          }

          const readOnly = isReadOnly(user);
          const freeMonthEnd = getFreeMonthEndDate(user);
          const cacheData = {
            readOnly,
            freeMonth: {
              active: isInFreeMonth(user),
              endDate: freeMonthEnd.toISOString(),
            },
          };

          // Cache the result (fire-and-forget)
          cache.set(CacheKeys.subscriptionTier(userKey), cacheData, CacheTTL.SUBSCRIPTION).catch(() => {});

          if (readOnly) {
            return res.status(403).json({
              readOnly: true,
              message: 'Active subscription required',
              freeMonth: cacheData.freeMonth,
            });
          }

          next();
        });
    })
    .catch((err) => {
      console.error('[requireActiveSubscription] Error:', err);
      return res.status(500).json({ message: 'Failed to check subscription status' });
    });
}
