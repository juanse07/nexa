import { Request, Response, NextFunction } from 'express';
import mongoose from 'mongoose';
import { TeamMemberModel } from '../models/teamMember';
import { ManagerModel } from '../models/manager';

export interface AuthenticatedRequest extends Request {
  authUser?: {
    provider: string;
    sub: string;
    email?: string;
    name?: string;
    picture?: string;
    managerId?: string;
  };
  user?: {
    provider: string;
    sub: string;
    email?: string;
    name?: string;
    picture?: string;
    managerId?: string;
  };
  // Cache for authorization results to avoid duplicate queries
  _authCache?: {
    managerId?: mongoose.Types.ObjectId;
    accessibleUsers?: Set<string>; // Format: "provider:subject"
  };
}

/**
 * Verifies if a manager has access to a specific user through team membership.
 *
 * @param managerId - The MongoDB ObjectId of the manager
 * @param provider - OAuth provider of the user (google, apple)
 * @param subject - OAuth subject identifier of the user
 * @returns Promise<boolean> - True if manager has access, false otherwise
 */
export async function canAccessUser(
  managerId: mongoose.Types.ObjectId,
  provider: string,
  subject: string
): Promise<boolean> {
  try {
    // Query TeamMember collection to check if user is an active member of any of this manager's teams
    const membership = await TeamMemberModel.findOne({
      managerId: managerId,
      provider: provider,
      subject: subject,
      status: 'active'
    }).lean();

    return !!membership;
  } catch (error) {
    console.error('Error checking user access:', error);
    return false;
  }
}

/**
 * Gets all accessible user identities for a manager.
 * Returns a Set of "provider:subject" strings for efficient lookup.
 *
 * @param managerId - The MongoDB ObjectId of the manager
 * @returns Promise<Set<string>> - Set of accessible user identity keys
 */
export async function getAccessibleUsers(
  managerId: mongoose.Types.ObjectId
): Promise<Set<string>> {
  try {
    const members = await TeamMemberModel.find({
      managerId: managerId,
      status: 'active'
    }, {
      provider: 1,
      subject: 1
    }).lean();

    const identities = new Set<string>();
    for (const member of members) {
      identities.add(`${member.provider}:${member.subject}`);
    }

    return identities;
  } catch (error) {
    console.error('Error getting accessible users:', error);
    return new Set();
  }
}

/**
 * Middleware that requires manager authentication.
 * Resolves manager document and caches it in request for downstream use.
 */
export async function requireManagerAuth(
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
): Promise<void> {
  try {
    const authUser = req.authUser || req.user;

    if (!authUser) {
      res.status(401).json({
        error: 'Authentication required',
        message: 'Please sign in to continue'
      });
      return;
    }

    // Check if request has manager authentication
    if (!authUser.managerId) {
      res.status(403).json({
        error: 'Manager authentication required',
        message: 'This endpoint requires manager-level access. Please authenticate using manager login endpoints.'
      });
      return;
    }

    // Resolve manager document by managerId from JWT (more efficient and secure)
    const managerObjectId = new mongoose.Types.ObjectId(authUser.managerId);
    const manager = await ManagerModel.findById(managerObjectId);

    if (!manager) {
      res.status(403).json({
        error: 'Manager profile not found',
        message: 'Please sign in again using the manager app.'
      });
      return;
    }

    // Verify JWT claims match the manager document (prevent token tampering)
    if (manager.provider !== authUser.provider || manager.subject !== authUser.sub) {
      res.status(403).json({
        error: 'Manager authentication mismatch',
        message: 'Please sign in again.'
      });
      return;
    }

    // Cache manager ID for authorization checks
    req._authCache = {
      managerId: manager._id as mongoose.Types.ObjectId
    };

    next();
  } catch (error) {
    console.error('Manager auth middleware error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
}

/**
 * Helper to get cached manager ID from request.
 * Should be used after requireManagerAuth middleware.
 */
export function getCachedManagerId(req: AuthenticatedRequest): mongoose.Types.ObjectId | null {
  return req._authCache?.managerId || null;
}

/**
 * Helper to get or populate the accessible users cache.
 */
export async function getOrCacheAccessibleUsers(
  req: AuthenticatedRequest
): Promise<Set<string>> {
  if (!req._authCache) {
    req._authCache = {};
  }

  if (!req._authCache.accessibleUsers) {
    const managerId = getCachedManagerId(req);
    if (!managerId) {
      return new Set();
    }
    req._authCache.accessibleUsers = await getAccessibleUsers(managerId);
  }

  return req._authCache.accessibleUsers;
}
