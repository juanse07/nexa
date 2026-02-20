import { Request, Response, NextFunction } from 'express';
import { UserModel } from '../models/user';
import { isReadOnly, isInFreeMonth, getFreeMonthEndDate } from '../utils/subscriptionUtils';

/**
 * Middleware that blocks write actions for staff users in read-only mode.
 * Managers (identified by managerId in JWT) are always allowed through.
 * Must be placed AFTER requireAuth in the middleware chain.
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

  // Load staff user and check subscription state
  UserModel.findOne({ provider: authUser.provider, subject: authUser.sub })
    .select('subscription_tier subscription_status createdAt free_month_end_override')
    .lean()
    .then((user) => {
      if (!user) {
        return res.status(404).json({ message: 'User not found' });
      }

      if (isReadOnly(user)) {
        const freeMonthEnd = getFreeMonthEndDate(user);
        return res.status(403).json({
          readOnly: true,
          message: 'Active subscription required',
          freeMonth: {
            active: false,
            endDate: freeMonthEnd.toISOString(),
          },
        });
      }

      next();
    })
    .catch((err) => {
      console.error('[requireActiveSubscription] Error:', err);
      return res.status(500).json({ message: 'Failed to check subscription status' });
    });
}
